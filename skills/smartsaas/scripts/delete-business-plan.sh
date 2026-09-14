#!/usr/bin/env bash
# Usage: delete-business-plan.sh <planId>
# Delete a business plan. Permission: business_plans:write
# Requires: SMARTSAAS_BASE_URL, SMARTSAAS_API_KEY
set -e
BASE="${SMARTSAAS_BASE_URL}"
KEY="${SMARTSAAS_API_KEY}"
if [ -z "$BASE" ] || [ -z "$KEY" ]; then
  echo "Error: SMARTSAAS_BASE_URL and SMARTSAAS_API_KEY must be set."
  exit 1
fi
CURL_OPTS="-s"; case "$BASE" in *localhost*|*127.0.0.1*) CURL_OPTS="-sk" ;; esac
PLAN_ID="$1"
if [ -z "$PLAN_ID" ]; then
  echo "Error: planId (first argument) is required."
  exit 1
fi
RES=$(curl $CURL_OPTS -w "\n%{http_code}" -X DELETE "${BASE}/api/protected/business-plans/${PLAN_ID}" -H "Authorization: Bearer $KEY")
HTTP=$(echo "$RES" | tail -n1)
BODY_RES=$(echo "$RES" | sed '$d')
if [ "$HTTP" -ge 200 ] && [ "$HTTP" -lt 300 ]; then
  echo "Business plan deleted: $PLAN_ID"
  echo "$BODY_RES"
else
  echo "Failed (HTTP $HTTP): $BODY_RES"
  exit 1
fi
