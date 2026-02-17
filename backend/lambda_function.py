import json
import boto3
import os 
import uuid 
from datetime import datetime, timezone

s3 = boto3.client("s3")
bedrock = boto3.client("bedrock-runtime", region_name="us-east-1")

BUCKET = os.environ.get("S3_BUCKET")

def lambda_handler(event, context):
  path = event.get("rawPath", "")
  
  if "/upload-url" in path:
    return get_upload_url() # Generate presigned upload URL
  elif "/analyze" in path:
    body = json.loads(event.get("body", "{}")) # Parse the JSON body
    return analyze(body) # Run Nova Lite analysis
  else:
    return make_response(404, {
      "error": "Not found"
    })

# Format the return value so API Gateway understands
def make_response(status_code, body):
  return {
    "statusCode": status_code,
    "headers": {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*"
    },
    "body": json.dumps(body)
  }

def get_upload_url():
  video_key = f"videos/{uuid.uuid4()}.mov"
  upload_url = s3.generate_presigned_url(
    "put_object",
    Params={
      "Bucket": BUCKET,
      "Key": video_key,
      "ContentType": "video/quicktime"
    },
    ExpiresIn=300
  )
  
  return make_response(200, {
    "uploadUrl": upload_url,
    "videoKey": video_key
  })

# Receive data from iOS app and calls Nova Lite
def analyze(body):
  video_key = body.get("videoKey", "") # after calling get_upload_url for temporary s3 upload url
  apple_transcript = body.get("transcript", "")
  gps = body.get("gps", {})
  duration = body.get("duration", 0)
  
  if not video_key:
    return make_response(400, {
      "error": "videoKey is required"
    })
  
  # TODO: Nove Sonic transcription
  transcript = apple_transcript # Use apple for now, integrate sonic later
  
  s3_uri = f"s3://{BUCKET}/{video_key}"
  
  prompt = build_analysis_prompt(transcript, gps, duration)
  
  try:
    nova_response = bedrock.converse(
      modelId="amazon.nova-2-lite-v1:0",
      messages=[
        {
          "role": "user",
          "content": [
            {
              "video": {
                "format": "mov",
                "source": {
                  "s3Location": {
                    "uri": s3_uri,
                    "bucketOwner": os.environ.get("AWS_ACCOUNT_ID", "")
                  }
                }
              }
            },
            {
              "text": prompt
            }
          ]
        }
      ]
    )
    
    result_text = nova_response["output"]["message"]["content"][0]["text"]
    report = parse_nova_response(result_text)
    
    # Add metadata
    report["location"] = gps
    report["videoKey"] = video_key
    report["timestamp"] = datetime.now(timezone.utc).isoformat()
    report["duration"] = duration
    
    return make_response(200, report)
  
  except Exception as e:
    print(f"Error analyzing video: {e}")
    return make_response(500, {
      "error": str(e)
    })
  