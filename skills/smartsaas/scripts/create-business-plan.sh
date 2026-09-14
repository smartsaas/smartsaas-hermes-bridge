#!/usr/bin/env bash
# Usage: create-business-plan.sh <planJson>
# Create a business plan on behalf of the user. Permission: business_plans:write
# Example: create-business-plan.sh '{"title":"Q1 2025 Plan","description":"..."}'
# Requires: SMARTSAAS_BASE_URL, SMARTSAAS_API_KEY
set -e
BASE="${SMARTSAAS_BASE_URL}"
KEY="${SMARTSAAS_API_KEY}"
if [ -z "$BASE" ] || [ -z "$KEY" ]; then
  echo "Error: SMARTSAAS_BASE_URL and SMARTSAAS_API_KEY must be set."
  exit 1
fi
CURL_OPTS="-s"; case "$BASE" in *localhost*|*127.0.0.1*) CURL_OPTS="-sk" ;; esac
BODY="${1:-{}}"
if [ -z "$BODY" ] || [ "$BODY" = "{}" ]; then
  echo "Error: plan JSON (first argument) is required. Example: create-business-plan.sh '{\"title\":\"My Plan\"}'"
  exit 1
fi
RES=$(curl $CURL_OPTS -w "\n%{http_code}" -X POST "${BASE}/api/protected/business-plans" \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" -d "$BODY")
HTTP=$(echo "$RES" | tail -n1)
BODY_RES=$(echo "$RES" | sed '$d')
if [ "$HTTP" -ge 200 ] && [ "$HTTP" -lt 300 ]; then
  echo "Business plan created."
  echo "$BODY_RES"
else
  echo "Failed (HTTP $HTTP): $BODY_RES"
  exit 1
fi
