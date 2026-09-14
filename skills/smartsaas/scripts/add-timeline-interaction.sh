#!/usr/bin/env bash
# Usage: add-timeline-interaction.sh <dataId> <interactionJson>
# Record an interaction on a data record's timeline.
# interactionJson: {"type":"call|email|meeting", "summary":"...", "date":"2025-01-01T10:00:00Z"}
# Requires: SMARTSAAS_BASE_URL, SMARTSAAS_API_KEY
set -e
BASE="${SMARTSAAS_BASE_URL}"
KEY="${SMARTSAAS_API_KEY}"
if [ -z "$BASE" ] || [ -z "$KEY" ]; then
  echo "Error: SMARTSAAS_BASE_URL and SMARTSAAS_API_KEY must be set."
  exit 1
fi
DATA_ID="$1"
INTERACTION_JSON="$2"
if [ -z "$DATA_ID" ] || [ -z "$INTERACTION_JSON" ]; then
  echo "Error: dataId and interactionJson are required."
  exit 1
fi
CURL_OPTS="-s"; case "$BASE" in *localhost*|*127.0.0.1*) CURL_OPTS="-sk" ;; esac
RES=$(curl $CURL_OPTS -w "\n%{http_code}" -X POST "${BASE}/api/timeline/${DATA_ID}/interactions" \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d "$INTERACTION_JSON")
HTTP=$(echo "$RES" | tail -n1)
BODY_RES=$(echo "$RES" | sed '$d')
if [ "$HTTP" -ge 200 ] && [ "$HTTP" -lt 300 ]; then
  echo "Timeline interaction recorded."
  echo "$BODY_RES"
else
  echo "Failed (HTTP $HTTP): $BODY_RES"
  exit 1
fi
