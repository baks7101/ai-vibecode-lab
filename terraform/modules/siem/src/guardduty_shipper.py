"""
GuardDuty -> OpenSearch shipper.

Triggered by EventBridge when GuardDuty produces a finding. Indexes the finding
into OpenSearch so threat detections are searchable alongside CloudTrail and
app/Falco logs (single pane of glass).

Same auth model as the CloudTrail shipper: master creds from Secrets Manager.
"""
import os
import json
import base64
import urllib.request
import boto3

OPENSEARCH_ENDPOINT = os.environ["OPENSEARCH_ENDPOINT"]
OPENSEARCH_SECRET_ID = os.environ["OPENSEARCH_SECRET_ID"]
INDEX = os.environ.get("OPENSEARCH_INDEX", "guardduty")

secrets = boto3.client("secretsmanager")
_auth_header = None


def _get_auth_header():
    global _auth_header
    if _auth_header is None:
        raw = secrets.get_secret_value(SecretId=OPENSEARCH_SECRET_ID)["SecretString"]
        creds = json.loads(raw)
        user = creds.get("master-user") or creds.get("username")
        pwd = creds.get("master-password") or creds.get("password")
        token = base64.b64encode(f"{user}:{pwd}".encode()).decode()
        _auth_header = f"Basic {token}"
    return _auth_header


def handler(event, context):
    # EventBridge delivers the GuardDuty finding in event["detail"].
    finding = event.get("detail", event)

    url = f"https://{OPENSEARCH_ENDPOINT}/{INDEX}/_doc"
    body = json.dumps(finding).encode()
    req = urllib.request.Request(
        url, data=body, method="POST",
        headers={"Content-Type": "application/json", "Authorization": _get_auth_header()},
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        resp.read()
        ftype = finding.get("type", "unknown")
        sev = finding.get("severity", "?")
        print(f"[SIEM] Indexed GuardDuty finding into '{INDEX}': {ftype} (severity {sev})")

    return {"statusCode": 200}
