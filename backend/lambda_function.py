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

  # Use Apple's on-device transcript
  transcript = apple_transcript

  # Base64 encode the video for Nova 2 Lite
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
    report["transcriptSource"] = "apple"

    return make_response(200, report)

  except Exception as e:
    print(f"Error analyzing video: {e}")
    return make_response(500, {"error": str(e)})

  
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

    SPEECH TRANSCRIPT (device on-device recognition — may only support English or the device's default language):
    ---
    {transcript}
    ---

    CRITICAL INSTRUCTIONS:

    GENERAL ANALYSIS RULES:
    - Only report information that is clearly visible or audible.
    - Do NOT guess, assume, or infer details not directly supported by evidence.
    - If something is unclear, explicitly state that it is unclear.
    - Prioritize responder-useful details (hazards, injuries, weapons, fire behavior, traffic flow, structural damage, medical distress, escalation indicators).
    - Identify environmental clues (street signs, business names, intersections, landmarks, building numbers).
    - Highlight escalation indicators (smoke thickening, physical violence, worsening medical condition, weapon brandishing, spreading fire).
    - Provide a thorough, detailed description (4-6 sentences minimum) covering the scene, environment, weather (if visible), lighting conditions, people, actions, and hazards.

    VIDEO LAYOUT RULE:
    - The video uses a picture-in-picture layout: the main (larger) view is the rear-facing camera, and the small overlay in the top-right corner is the front-facing camera showing the person recording.
    - This is the normal recording format.
    - Do NOT comment on the split-screen or PiP layout.
    - Do NOT describe the person in the small overlay or mention their position on screen.

    TIMELINE REQUIREMENTS:
    - Use the burned-in timestamp visible in the bottom-left corner of the video.
    - The format is HH:MM:SS and represents actual time of day.
    - Do NOT use relative timestamps like 00:00:00.
    - Include an entry for EVERY significant moment, escalation, or major observable change.

    PEOPLE REQUIREMENTS:
    - List ALL visible individuals in the main scene.
    - Provide approximate count (or state unknown).
    - Describe approximate location in scene (e.g., near vehicle, inside store entrance, on sidewalk).
    - Include observable clothing, distinguishing features, and actions.
    - Only report visible injuries — do not speculate.

    MULTILINGUAL & TEXT DETECTION REQUIREMENTS:
    - The provided transcript was generated by on-device speech recognition that only supports English (or the device's default language). It may be inaccurate or incomplete for non-English speech.
    - When the spoken language in the video audio differs from the transcript language, PRIORITIZE what you hear in the video audio and see as visible text over the transcript text.
    - Automatically detect the primary spoken language from the video audio.
    - Detect any additional spoken languages from the video audio.
    - Detect visible written language from street signs, storefronts, uniforms, vehicles, or warning labels.
    - Translate all non-English speech and visible text into clear English.
    - When quoting transcriptHighlights, include BOTH:
        1) The original phrase (as heard in the audio, not from the transcript)
        2) The English translation in parentheses
    - If the transcript and video audio conflict, trust the video audio.
    - If translation confidence is low or audio/text is unclear, state that it is unclear instead of guessing.
    - Do NOT omit important non-English speech.
    - If multiple interpretations of a phrase are possible, choose the most literal translation.
    - Do NOT soften or reinterpret urgent or threatening language.

    Respond with ONLY a valid JSON object (no extra text) using EXACTLY this structure:

    {{
      "incidentType": "Fire | Vehicle Accident | Medical Emergency | Hazard | Altercation | Suspicious Activity | Infrastructure Damage | Other",
      "severity": "Low | Medium | High | Critical",
      "confidenceLevel": "Low | Medium | High",
      "languageAnalysis": {{
        "primarySpokenLanguage": "English | French | Spanish | etc. | Unknown",
        "otherLanguagesDetected": ["language if present"],
        "visibleTextLanguages": ["languages detected in signage or written text"],
        "translationConfidence": "Low | Medium | High"
      }},
      "locationDetails": {{
        "visibleStreetNames": ["street name if visible"],
        "visibleBusinessNames": ["business/store names if visible"],
        "landmarks": ["nearby landmark"],
        "intersectionDescription": "description if identifiable"
      }},
      "timeline": [
        {{
          "timestamp": "HH:MM:SS from burned-in video timestamp",
          "event": "description of key event"
        }}
      ],
      "peopleInvolved": {{
        "approximateCount": "number or unknown",
        "visibleInjuries": ["injury observations"],
        "descriptions": [
          "person description including clothing, approximate location, and actions"
        ]
      }},
      "hazardsObserved": [
        "fire, smoke, weapon, leaking fluid, downed power line, aggressive behavior, blocked roadway, etc."
      ],
      "transcriptHighlights": [
        "Original phrase (English translation)"
      ],
      "description": "4-6 sentence detailed, factual summary covering the scene, environment, people, actions, hazards, and escalation indicators. Prioritize responder awareness.",
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
      "languageAnalysis": {
        "primarySpokenLanguage": "Unknown",
        "otherLanguagesDetected": [],
        "visibleTextLanguages": [],
        "translationConfidence": "Low"
      },
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