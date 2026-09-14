#!/usr/bin/env bash
# Usage: delete-competitor.sh <competitorId>
# Delete a competitor.
# Requires: SMARTSAAS_BASE_URL, SMARTSAAS_API_KEY
set -e
BASE="${SMARTSAAS_BASE_URL}"
KEY="${SMARTSAAS_API_KEY}"
if [ -z "$BASE" ] || [ -z "$KEY" ]; then
  echo "Error: SMARTSAAS_BASE_URL and SMARTSAAS_API_KEY must be set."
  exit 1
fi
COMPETITOR_ID="$1"
if [ -z "$COMPETITOR_ID" ]; then
  echo "Error: competitorId (first argument) is required."
  exit 1
fi
CURL_OPTS="-s"; case "$BASE" in *localhost*|*127.0.0.1*) CURL_OPTS="-sk" ;; esac
RES=$(curl $CURL_OPTS -w "\n%{http_code}" -X DELETE "${BASE}/api/competitors/${COMPETITOR_ID}" \
  -H "Authorization: Bearer $KEY")
HTTP=$(echo "$RES" | tail -n1)
BODY_RES=$(echo "$RES" | sed '$d')
if [ "$HTTP" -ge 200 ] && [ "$HTTP" -lt 300 ]; then
  echo "Competitor deleted."
  echo "$BODY_RES"
else
  echo "Failed (HTTP $HTTP): $BODY_RES"
  exit 1
fi
