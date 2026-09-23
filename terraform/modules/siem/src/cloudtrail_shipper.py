"""
CloudTrail -> OpenSearch shipper.

Triggered by S3 when CloudTrail drops a new .json.gz log file. Reads the file,
parses the CloudTrail records, and bulk-indexes them into OpenSearch so they're
searchable alongside the app/Falco logs (single pane of glass).

Authenticates to OpenSearch with the master user creds (from Secrets Manager),
passed in as env vars by Terraform. For a larger setup you'd map a scoped FGAC
backend role instead; master creds are pragmatic for a single-node lab SIEM.
"""
import os
import json
import gzip
import base64
import urllib.request
import boto3

OPENSEARCH_ENDPOINT = os.environ["OPENSEARCH_ENDPOINT"]      # e.g. search-xxx.eu-west-2.es.amazonaws.com
OPENSEARCH_SECRET_ID = os.environ["OPENSEARCH_SECRET_ID"]    # Secrets Manager id holding {username,password}
INDEX = os.environ.get("OPENSEARCH_INDEX", "cloudtrail")

s3 = boto3.client("s3")
secrets = boto3.client("secretsmanager")

# Cache the creds across warm invocations.
_auth_header = None


def _get_auth_header():
    global _auth_header
    if _auth_header is None:
        raw = secrets.get_secret_value(SecretId=OPENSEARCH_SECRET_ID)["SecretString"]
        creds = json.loads(raw)
        # secret keys are hyphenated in this project (master-user / master-password)
        user = creds.get("master-user") or creds.get("username")
        pwd = creds.get("master-password") or creds.get("password")
        token = base64.b64encode(f"{user}:{pwd}".encode()).decode()
        _auth_header = f"Basic {token}"
    return _auth_header


def _bulk_index(records):
    """Send records to OpenSearch via the _bulk API."""
    if not records:
        return
    lines = []
    for r in records:
        lines.append(json.dumps({"index": {"_index": INDEX}}))
        lines.append(json.dumps(r))
    body = ("\n".join(lines) + "\n").encode()

    url = f"https://{OPENSEARCH_ENDPOINT}/_bulk"
    req = urllib.request.Request(
        url, data=body, method="POST",
        headers={"Content-Type": "application/x-ndjson", "Authorization": _get_auth_header()},
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        result = json.loads(resp.read())
        if result.get("errors"):
            print(f"[SIEM] Some records failed to index: {json.dumps(result)[:500]}")
        else:
            print(f"[SIEM] Indexed {len(records)} CloudTrail records into '{INDEX}'")


def handler(event, context):
    for rec in event.get("Records", []):
        bucket = rec["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(rec["s3"]["object"]["key"])
        print(f"[SIEM] Processing s3://{bucket}/{key}")

        obj = s3.get_object(Bucket=bucket, Key=key)
        raw = gzip.decompress(obj["Body"].read())
        payload = json.loads(raw)

        # CloudTrail files contain {"Records": [ ...events... ]}
        events = payload.get("Records", [])
        _bulk_index(events)

    return {"statusCode": 200}
