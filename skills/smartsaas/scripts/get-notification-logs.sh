#!/usr/bin/env bash
# Usage: get-notification-logs.sh [scope]
# Get notification logs. scope: user (default) | company
# Requires: SMARTSAAS_BASE_URL, SMARTSAAS_API_KEY
set -e
BASE="${SMARTSAAS_BASE_URL}"
KEY="${SMARTSAAS_API_KEY}"
if [ -z "$BASE" ] || [ -z "$KEY" ]; then
  echo "Error: SMARTSAAS_BASE_URL and SMARTSAAS_API_KEY must be set."
  exit 1
fi
SCOPE="${1:-user}"
CURL_OPTS="-s"; case "$BASE" in *localhost*|*127.0.0.1*) CURL_OPTS="-sk" ;; esac
if [ "$SCOPE" = "company" ]; then
  ENDPOINT="${BASE}/api/notification-logs/company"
else
  ENDPOINT="${BASE}/api/notification-logs/user"
fi
RES=$(curl $CURL_OPTS -w "\n%{http_code}" -X GET "$ENDPOINT" \
  -H "Authorization: Bearer $KEY")
HTTP=$(echo "$RES" | tail -n1)
BODY_RES=$(echo "$RES" | sed '$d')
if [ "$HTTP" -ge 200 ] && [ "$HTTP" -lt 300 ]; then
  echo "$BODY_RES"
else
  echo "Failed (HTTP $HTTP): $BODY_RES"
  exit 1
fi
