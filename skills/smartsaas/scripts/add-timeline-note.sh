#!/usr/bin/env bash
# Usage: add-timeline-note.sh <dataId> <noteJson>
# Add a note to a data record's timeline. noteJson: {"content":"...", "type":"note"}
# Requires: SMARTSAAS_BASE_URL, SMARTSAAS_API_KEY
set -e
BASE="${SMARTSAAS_BASE_URL}"
KEY="${SMARTSAAS_API_KEY}"
if [ -z "$BASE" ] || [ -z "$KEY" ]; then
  echo "Error: SMARTSAAS_BASE_URL and SMARTSAAS_API_KEY must be set."
  exit 1
fi
DATA_ID="$1"
NOTE_JSON="$2"
if [ -z "$DATA_ID" ] || [ -z "$NOTE_JSON" ]; then
  echo "Error: dataId and noteJson are required."
  exit 1
fi
CURL_OPTS="-s"; case "$BASE" in *localhost*|*127.0.0.1*) CURL_OPTS="-sk" ;; esac
RES=$(curl $CURL_OPTS -w "\n%{http_code}" -X POST "${BASE}/api/timeline/${DATA_ID}/notes" \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d "$NOTE_JSON")
HTTP=$(echo "$RES" | tail -n1)
BODY_RES=$(echo "$RES" | sed '$d')
if [ "$HTTP" -ge 200 ] && [ "$HTTP" -lt 300 ]; then
  echo "Timeline note added."
  echo "$BODY_RES"
else
  echo "Failed (HTTP $HTTP): $BODY_RES"
  exit 1
fi
