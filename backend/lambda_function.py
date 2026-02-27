import json
import boto3
from botocore.config import Config
from openai import OpenAI
import os
import uuid
import time
from datetime import datetime, timezone

s3 = boto3.client("s3", region_name="us-east-1", endpoint_url="https://s3.us-east-1.amazonaws.com", config=Config(signature_version="s3v4"))
transcribe = boto3.client("transcribe", region_name="us-east-1")
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

# Transcribe video audio using Amazon Transcribe with auto language detection
def transcribe_video(video_key):
  job_name = f"recon-{uuid.uuid4()}"
  media_uri = f"s3://{BUCKET}/{video_key}"

  print(f"Starting Transcribe job: {job_name} for {media_uri}")

  try:
    transcribe.start_transcription_job(
      TranscriptionJobName=job_name,
      Media={"MediaFileUri": media_uri},
      IdentifyLanguage=True,
      OutputBucketName=BUCKET,
      OutputKey=f"transcripts/{job_name}.json"
    )

    # Poll until complete (timeout after 120s)
    for _ in range(60):
      status = transcribe.get_transcription_job(TranscriptionJobName=job_name)
      job_status = status["TranscriptionJob"]["TranscriptionJobStatus"]

      if job_status == "COMPLETED":
        print(f"Transcribe job completed: {job_name}")
        break
      elif job_status == "FAILED":
        reason = status["TranscriptionJob"].get("FailureReason", "Unknown")
        print(f"Transcribe job failed: {reason}")
        return None, None

      time.sleep(2)
    else:
      print("Transcribe job timed out after 120s")
      return None, None

    # Fetch the transcript result from S3
    transcript_key = f"transcripts/{job_name}.json"
    result_obj = s3.get_object(Bucket=BUCKET, Key=transcript_key)
    result_json = json.loads(result_obj["Body"].read().decode("utf-8"))

    # Extract transcript text
    transcript_text = ""
    for result in result_json.get("results", {}).get("transcripts", []):
      transcript_text += result.get("transcript", "")

    # Extract detected language
    detected_language = None
    lang_codes = result_json.get("results", {}).get("language_identification", [])
    if lang_codes:
      # Pick the highest-score language
      best = max(lang_codes, key=lambda x: float(x.get("score", 0)))
      detected_language = best.get("code", None)

    # Also check top-level language code
    if not detected_language:
      detected_language = status["TranscriptionJob"].get("LanguageCode")

    print(f"Transcribe result: lang={detected_language}, text length={len(transcript_text)}")

    # Clean up transcript file from S3
    try:
      s3.delete_object(Bucket=BUCKET, Key=transcript_key)
    except Exception:
      pass

    return transcript_text.strip(), detected_language

  except Exception as e:
    print(f"Transcribe error: {e}")
    return None, None


# Receive data from iOS app, transcribe with Amazon Transcribe, analyze with Nova Pro
def analyze(body):
  video_key = body.get("videoKey", "") # after calling get_upload_url for temporary s3 upload url
  apple_transcript = body.get("transcript", "") # fallback
  gps = body.get("gps", {})
  duration = body.get("duration", 0)

  if not video_key:
    return make_response(400, {"error": "videoKey is required"})

  # Step 1: Transcribe video audio with Amazon Transcribe (auto language detection)
  transcribe_text, detected_language = transcribe_video(video_key)

  if transcribe_text:
    transcript = transcribe_text
    transcript_source = "transcribe"
    print(f"Using Amazon Transcribe transcript (lang: {detected_language})")
  else:
    transcript = apple_transcript
    transcript_source = "apple"
    detected_language = None
    print("Falling back to Apple on-device transcript")

  # Step 2: Download and base64 encode video for Nova
  import base64
  tmp_path = f"/tmp/{uuid.uuid4()}.mov"
  s3.download_file(BUCKET, video_key, tmp_path)

  with open(tmp_path, "rb") as f:
    video_data = base64.b64encode(f.read()).decode()

  os.remove(tmp_path)

  # Step 3: Analyze video with Nova Pro
  prompt = build_analysis_prompt(transcript, gps, duration, detected_language, transcript_source)

  try:
    nova_response = nova_client.chat.completions.create(
      model="nova-lite-v1",
      messages=[
        {
          "role": "user",
          "content": [
            {"type": "text", "text": prompt},
            {"type": "file", "file": {"file_data": video_data}}
          ]
        }
      ],
      extra_body={
        "system_tools": ["nova_grounding"]
      }
    )

    result_text = nova_response.choices[0].message.content
    print(f"Nova raw response: {result_text[:2000]}")
    report = parse_nova_response(result_text)

    # Add metadata
    report["location"] = gps
    report["videoKey"] = video_key
    report["timestamp"] = datetime.now(timezone.utc).isoformat()
    report["duration"] = duration
    report["transcriptSource"] = transcript_source
    if detected_language:
      report["detectedLanguage"] = detected_language

    return make_response(200, report)

  except Exception as e:
    print(f"Error analyzing video: {e}")
    return make_response(500, {"error": str(e)})

  
def build_analysis_prompt(transcript, gps, duration, detected_language=None, transcript_source="apple"):
  latitude = gps.get("latitude", "Unknown")
  longitude = gps.get("longitude", "Unknown")

  # Build language context
  lang_info = ""
  if detected_language:
    lang_info = f"\n    - Detected audio language (auto-detected): {detected_language}"

  # Build transcript header based on source
  if transcript_source == "transcribe":
    transcript_header = f"SPEECH TRANSCRIPT (Amazon Transcribe, auto-detected language: {detected_language or 'unknown'})"
  else:
    transcript_header = "SPEECH TRANSCRIPT (Apple on-device, device default language only; may be inaccurate for non-English audio)"

  return f"""
    You are an emergency incident video analyzer assisting 911 dispatch and first responders.

    Analyze the provided video carefully. This report will be viewed by emergency personnel and must prioritize factual, observable, responder-relevant information.

    VIDEO METADATA:
    - Duration: {duration} seconds
    - GPS Coordinates (device reported): {latitude}, {longitude}
    - Visible on-screen timestamp may be present in the video.{lang_info}

    {transcript_header}:
    ---
    {transcript}
    ---

    CRITICAL INSTRUCTIONS:

    GENERAL EVIDENCE RULES:
    - Only report information that is clearly visible or audible.
    - Do NOT guess, assume, or infer details not directly supported by evidence.
    - If something is unclear, explicitly state that it is unclear.
    - Prioritize responder-useful details (hazards, injuries, weapons, fire behavior, traffic flow, structural damage, medical distress, escalation indicators).
    - Identify environmental clues (street signs, business names, intersections, landmarks, building numbers).
    - Highlight escalation indicators (smoke thickening, physical violence, worsening medical condition, weapon brandishing, spreading fire).
    - Provide a thorough, detailed description (4–6 sentences minimum) covering the scene, environment, weather if visible, lighting conditions, people, actions, and hazards.

    VIDEO LAYOUT RULE:
    - The video uses a picture-in-picture layout: the main (larger) view is the rear-facing camera, and the small overlay in the top-right corner is the front-facing camera showing the person recording.
    - This is the normal recording format.
    - Do NOT comment on the split-screen layout.
    - Do NOT describe the person in the small overlay or mention their position on screen.

    SOURCE RELIABILITY & CONFLICT RESOLUTION RULES:
    - The provided transcript may be inaccurate, auto-translated, partially mistranscribed, or in a different language than the actual audio.
    - Always prioritize evidence in this order:
        1) Direct visual evidence from the video
        2) Clearly audible speech from the video
        3) Visible written text in the video (signage, storefronts, uniforms, vehicles, warnings)
        4) The provided transcript (lowest priority)

    - If the transcript conflicts with audible speech or visible evidence, rely on the video/audio.
    - If the transcript language differs from the audible language, treat the audible language as primary.
    - If the transcript appears nonsensical, mistranscribed, incomplete, or contradictory, mark it as unreliable and rely on audio/video instead.
    - Never fabricate meaning to reconcile conflicting sources.
    - If both transcript and audio are unclear, state that speech content is unclear.

    TIMELINE REQUIREMENTS:
    - Use the burned-in timestamp visible in the bottom-left corner of the video.
    - The format is HH:MM:SS and represents actual time of day.
    - Do NOT use relative timestamps like 00:00:00.
    - Include an entry for EVERY significant moment, escalation, injury, hazard appearance, or major observable change.

    PEOPLE REQUIREMENTS:
    - List ALL visible individuals in the main scene.
    - Provide approximate count (or state unknown).
    - Describe approximate location in scene (e.g., near vehicle, inside store entrance, on sidewalk).
    - Include observable clothing, distinguishing features, and actions.
    - Only report visible injuries — do not speculate.

    MULTILINGUAL & TEXT DETECTION REQUIREMENTS:
    - The video and transcript may contain speech or visible text in ANY language.
    - You MUST understand and translate non-English content, not just identify the language.
    - Detect the primary spoken language from the audio.
    - Detect any additional spoken languages.
    - Detect visible written language from signs, storefronts, uniforms, vehicles, or warning labels.
    - Actually read and translate all non-English visible text (Chinese, Arabic, Korean, Japanese, Spanish, French, etc.) into English. Do not just say "Chinese characters detected" — read what they say.
    - Actually listen to and translate all non-English speech into English. Do not just say "non-English speech detected" — translate the words.
    - When quoting transcriptHighlights, include BOTH:
        1) The original phrase
        2) The English translation in parentheses
    - If you genuinely cannot translate specific words, quote the original and state the specific words you could not translate. Do not dismiss entire passages.
    - Do NOT soften, reinterpret, or downplay urgent or threatening language.
    - If multiple interpretations are possible, choose the most literal translation.
    - The language of the content must NOT affect severity. Base severity on the actual meaning of what is said and what is visible, regardless of language.

    Respond with ONLY a valid JSON object (no extra text) using EXACTLY this structure:

    {{
      "incidentType": "Fire | Vehicle Accident | Medical Emergency | Hazard | Altercation | Suspicious Activity | Infrastructure Damage | Other",
      "severity": "Low | Medium | High | Critical",
      "confidenceLevel": "Low | Medium | High",
      "transcriptReliability": {{
        "status": "Reliable | Partially Reliable | Unreliable | Not Provided",
        "notes": "brief explanation if unreliable or conflicting"
      }},
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
      "transcriptReliability": {
        "status": "Not Provided",
        "notes": "Parse error"
      },
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