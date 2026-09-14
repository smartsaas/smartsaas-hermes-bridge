#!/usr/bin/env bash
# Usage: create-project.sh <title> [description] [bodyJson]
#   Shape from Projects.mjs: required title, description, status, start_date; optional end_date, work_packages (with task_list).
#   Arg3 bodyJson: optional extra fields (e.g. work_packages with tasks). Merged with required fields.
# Requires: SMARTSAAS_BASE_URL, SMARTSAAS_API_KEY
set -e
BASE="${SMARTSAAS_BASE_URL}"
KEY="${SMARTSAAS_API_KEY}"
if [ -z "$BASE" ] || [ -z "$KEY" ]; then
  echo "Error: SMARTSAAS_BASE_URL and SMARTSAAS_API_KEY must be set."
  exit 1
fi
# Allow self-signed certs for localhost only; prod keeps full SSL verification
CURL_OPTS="-s"; case "$BASE" in *localhost*|*127.0.0.1*) CURL_OPTS="-sk" ;; esac
TITLE="$1"
DESC="${2:-}"
BODY_JSON="${3:-}"
if [ -z "$TITLE" ]; then
  echo "Error: title (first argument) is required."
  exit 1
fi
# Build payload from Projects.mjs: required title, description, status, start_date; optional end_date (+1yr), work_packages
START_DATE=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
BODY=$(printf '%s' "$BODY_JSON" | python3 -c "
import sys, json
from datetime import datetime, timedelta
title, desc, start_date = sys.argv[1], sys.argv[2], sys.argv[3]
extra_str = sys.stdin.read().strip()
extra = json.loads(extra_str) if extra_str and extra_str.startswith('{') else {}
start_dt = datetime.fromisoformat(start_date.replace('Z', '+00:00'))
end_dt = start_dt + timedelta(days=365)
end_date = end_dt.strftime('%Y-%m-%dT%H:%M:%S.000Z')
payload = {'title': title, 'description': desc, 'status': 'active', 'start_date': start_date, 'end_date': end_date}
if extra:
    for k, v in extra.items():
        if k not in ('title', 'description', 'status', 'start_date'):
            payload[k] = v
        elif k == 'end_date':
            payload['end_date'] = v
print(json.dumps(payload))
" "$TITLE" "$DESC" "$START_DATE")
RES=$(curl $CURL_OPTS -w "\n%{http_code}" -X POST "${BASE}/api/protected/projects" \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" -d "$BODY")
HTTP=$(echo "$RES" | tail -n1)
BODY_RES=$(echo "$RES" | sed '$d')
if [ "$HTTP" -ge 200 ] && [ "$HTTP" -lt 300 ]; then
  echo "Project created: $TITLE"
  echo "$BODY_RES"
else
  echo "Failed (HTTP $HTTP): $BODY_RES"
  exit 1
fi
