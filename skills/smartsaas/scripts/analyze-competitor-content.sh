#!/usr/bin/env bash
# Usage: analyze-competitor-content.sh <competitorId> [analysisJson]
# Trigger AI content analysis for a competitor.
# analysisJson: optional {"contentType":"social","depth":"full"}
# Requires: SMARTSAAS_BASE_URL, SMARTSAAS_API_KEY
set -e
BASE="${SMARTSAAS_BASE_URL}"
KEY="${SMARTSAAS_API_KEY}"
if [ -z "$BASE" ] || [ -z "$KEY" ]; then
  echo "Error: SMARTSAAS_BASE_URL and SMARTSAAS_API_KEY must be set."
  exit 1
fi
COMPETITOR_ID="$1"
ANALYSIS_JSON="${2:-{}}"
if [ -z "$COMPETITOR_ID" ]; then
  echo "Error: competitorId (first argument) is required."
  exit 1
fi
CURL_OPTS="-s"; case "$BASE" in *localhost*|*127.0.0.1*) CURL_OPTS="-sk" ;; esac
RES=$(curl $CURL_OPTS -w "\n%{http_code}" -X POST "${BASE}/api/competitors/${COMPETITOR_ID}/analyze-content" \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d "$ANALYSIS_JSON")
HTTP=$(echo "$RES" | tail -n1)
BODY_RES=$(echo "$RES" | sed '$d')
if [ "$HTTP" -ge 200 ] && [ "$HTTP" -lt 300 ]; then
  echo "Competitor content analysis triggered."
  echo "$BODY_RES"
else
  echo "Failed (HTTP $HTTP): $BODY_RES"
  exit 1
fi
