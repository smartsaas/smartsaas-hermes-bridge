#!/usr/bin/env bash
# Usage: create-lead.sh <leadJson>
# Creates a CRM lead. leadJson: {"name":"...", "email":"...", "phone":"...", "company":"...", "campaignId":"..."}
# Requires: SMARTSAAS_BASE_URL, SMARTSAAS_API_KEY
set -e
BASE="${SMARTSAAS_BASE_URL}"
KEY="${SMARTSAAS_API_KEY}"
if [ -z "$BASE" ] || [ -z "$KEY" ]; then
  echo "Error: SMARTSAAS_BASE_URL and SMARTSAAS_API_KEY must be set."
  exit 1
fi
LEAD_JSON="$1"
if [ -z "$LEAD_JSON" ]; then
  echo "Error: leadJson (first argument) is required."
  exit 1
fi
CURL_OPTS="-s"; case "$BASE" in *localhost*|*127.0.0.1*) CURL_OPTS="-sk" ;; esac
RES=$(curl $CURL_OPTS -w "\n%{http_code}" -X POST "${BASE}/api/sales/create-lead" \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d "$LEAD_JSON")
HTTP=$(echo "$RES" | tail -n1)
BODY_RES=$(echo "$RES" | sed '$d')
if [ "$HTTP" -ge 200 ] && [ "$HTTP" -lt 300 ]; then
  echo "Lead created."
  echo "$BODY_RES"
else
  echo "Failed (HTTP $HTTP): $BODY_RES"
  exit 1
fi
