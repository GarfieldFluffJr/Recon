import json
import boto3
import os 
import uuid 
from datetime import datetime 

s3 = boto3.client("s3")
bedrock = boto3.client("bedrock-runtime", region_name="us_east-1")

BUCKET = os.environ.get("S3_BUCKET")

def lambda_handler(event, context):
  path = event.get("rawPath", "")
  
  if "/upload-url" in path:
    return get_upload_url() # Generate presigned upload URL
  elif "/analyze" in path:
    body = json.loads(event.get("body", "{}")) # Parse the JSON body
    return analyze(body) # Run Nova Lite analysis
  else:
    return make_response(404, {"error", "Not found"})

# Format the return value so API Gateway understands
def make_response(status_code, body):
  return {
    "statusCode": status_code,
    "headers": {
      "Content-Type": "application/json",
      "Access=Control-Allow_Origin": "*"
    },
    "body": json.dumps(body)
  }
  
  