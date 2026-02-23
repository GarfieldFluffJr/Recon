import json
import boto3
from botocore.config import Config
from openai import OpenAI
import os 
import uuid 
from datetime import datetime, timezone

s3 = boto3.client("s3", region_name="us-east-1", endpoint_url="https://s3.us-east-1.amazonaws.com", config=Config(signature_version="s3v4"))   
nova_client = OpenAI(
  api_key=os.environ.get("NOVA_API_KEY"),
  base_url="https://api.nova.amazon.com/v1"
)

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

# Receive data from iOS app, transcribe with Sonic, analyze with Nova 2 Lite
def analyze(body):
  video_key = body.get("videoKey", "") # after calling get_upload_url for temporary s3 upload url
  apple_transcript = body.get("transcript", "") # fallback
  gps = body.get("gps", {})
  duration = body.get("duration", 0)

  if not video_key:
    return make_response(400, {"error": "videoKey is required"})

  # Download video from S3 to /tmp for base64 encoding
  import base64
  tmp_path = f"/tmp/{uuid.uuid4()}.mov"
  s3.download_file(BUCKET, video_key, tmp_path)

  # Step 1: Try Nova 2 Sonic transcription, fall back to Apple
  transcript = apple_transcript
  transcript_source = "apple"
  try:
    sonic_transcript = transcribe_with_sonic(tmp_path)
    if sonic_transcript:
      transcript = sonic_transcript
      transcript_source = "sonic"
      print("Using Nova Sonic transcript")
    else:
      print("Sonic returned empty, using Apple transcript")
  except Exception as e:
    print(f"Sonic transcription failed, using Apple transcript: {e}")

  # Step 2: Base64 encode the video for Nova 2 Lite
  with open(tmp_path, "rb") as f:
    video_data = base64.b64encode(f.read()).decode()

  # Clean up temp file
  os.remove(tmp_path)

  # Step 3: Analyze video with Nova 2 Lite
  prompt = build_analysis_prompt(transcript, gps, duration)

  try:
    nova_response = nova_client.chat.completions.create(
      model="nova-2-lite-v1",
      messages=[
        {
          "role": "user",
          "content": [
            {"type": "text", "text": prompt},
            {"type": "file", "file": {"file_data": video_data}}
          ]
        }
      ]
    )

    result_text = nova_response.choices[0].message.content
    report = parse_nova_response(result_text)

    # Add metadata
    report["location"] = gps
    report["videoKey"] = video_key
    report["timestamp"] = datetime.now(timezone.utc).isoformat()
    report["duration"] = duration
    report["transcriptSource"] = transcript_source

    return make_response(200, report)

  except Exception as e:
    print(f"Error analyzing video: {e}")
    return make_response(500, {"error": str(e)})

# Transcribe audio from video using Nova 2 Sonic
# Takes a local file path (already downloaded from S3)
def transcribe_with_sonic(file_path):
  with open(file_path, "rb") as audio_file:
    transcript = nova_client.audio.transcriptions.create(
      model="nova-2-sonic-v1",
      file=audio_file
    )
  return transcript.text
  
def build_analysis_prompt(transcript, gps, duration):
  latitude = gps.get("latitude", "Unknown")
  longitude = gps.get("longitude", "Unknown")
  
  return f"""
    You are an emergency incident video analyzer assisting 911 dispatch and first responders.

    Analyze the provided video carefully. This report will be viewed by emergency personnel and must prioritize factual, observable, responder-relevant information.

    VIDEO METADATA:
    - Duration: {duration} seconds
    - GPS Coordinates (device reported): {latitude}, {longitude}
    - Visible on-screen timestamp may be present in the video.

    SPEECH TRANSCRIPT:
    ---
    {transcript}
    ---

    CRITICAL INSTRUCTIONS:
    - Only report information that is clearly visible or audible.
    - Do NOT guess or assume details that are not supported by evidence.
    - If something is unclear, state that it is unclear.
    - Extract timestamps from the burned-in video time when visible.
    - Prioritize responder-useful details (hazards, injuries, weapons, fire spread, traffic flow, etc.).
    - Identify environmental clues (street signs, business names, intersections, landmarks).
    - Highlight escalation indicators (smoke thickening, physical violence, worsening condition).

    Respond with ONLY a valid JSON object (no extra text) using EXACTLY this structure:

    {{
      "incidentType": "Fire | Vehicle Accident | Medical Emergency | Hazard | Altercation | Suspicious Activity | Infrastructure Damage | Other",
      "severity": "Low | Medium | High | Critical",
      "confidenceLevel": "Low | Medium | High",
      "locationDetails": {{
        "visibleStreetNames": ["street name if visible"],
        "visibleBusinessNames": ["business/store names if visible"],
        "landmarks": ["nearby landmark"],
        "intersectionDescription": "description if identifiable"
      }},
      "timeline": [
        {{
          "timestamp": "HH:MM:SS if visible",
          "event": "description of key event"
        }}
      ],
      "peopleInvolved": {{
        "approximateCount": "number or unknown",
        "visibleInjuries": ["injury observations"],
        "descriptions": ["clothing, distinguishing features if relevant"]
      }},
      "hazardsObserved": [
        "fire, smoke, weapon, leaking fluid, downed power line, aggressive behavior, blocked roadway, etc."
      ],
      "transcriptHighlights": [
        "important spoken phrase 1",
        "important spoken phrase 2"
      ],
      "description": "2-4 sentence clear, factual summary prioritizing responder awareness.",
      "recommendedActions": [
        "specific action for dispatch or responders"
      ]
    }}
  """

# Clean Nova's response
def parse_nova_response(text):
  cleaned = text.strip()
  
  # Remove markdown code block if present
  if cleaned.startswith("```"):
    cleaned = cleaned.split("\n", 1)[1].rsplit("```", 1)[0].strip()
    
  try:
    return json.loads(cleaned)
  except json.JSONDecodeError:
    # If parsing fails, wrap raw text in a basic structure
    return {
      "parseError": True,
      "incidentType": "Unknown",
      "severity": "Unknown",
      "confidenceLevel": "Low",
      "locationDetails": {
        "visibleStreetNames": [],
        "visibleBusinessNames": [],
        "landmarks": [],
        "intersectionDescription": "Unknown"
      },
      "timeline": [],
      "peopleInvolved": {
        "approximateCount": "Unknown",
        "visibleInjuries": [],
        "descriptions": []
      },
      "hazardsObserved": [],
      "transcriptHighlights": [],
      "description": cleaned,
      "recommendedActions": []
    }