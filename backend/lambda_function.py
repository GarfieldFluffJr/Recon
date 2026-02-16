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
    return get_upload_url()
  elif "/analyze" in path:
    body = json.loads(event.get("body", "{}"))
    return analyze(body)
  else:
    return make_response(404, {"error", "Not found"})
  
  