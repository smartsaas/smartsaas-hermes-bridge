#!/usr/bin/env bash
# Usage: update-agent.sh <agentId> <patchJson>
# Update an AI agent. patchJson: partial agent fields to update.
# Requires: SMARTSAAS_BASE_URL, SMARTSAAS_API_KEY
set -e
BASE="${SMARTSAAS_BASE_URL}"
KEY="${SMARTSAAS_API_KEY}"
if [ -z "$BASE" ] || [ -z "$KEY" ]; then
  echo "Error: SMARTSAAS_BASE_URL and SMARTSAAS_API_KEY must be set."
  exit 1
fi
AGENT_ID="$1"
PATCH_JSON="$2"
if [ -z "$AGENT_ID" ] || [ -z "$PATCH_JSON" ]; then
  echo "Error: agentId and patchJson are required."
  exit 1
fi
CURL_OPTS="-s"; case "$BASE" in *localhost*|*127.0.0.1*) CURL_OPTS="-sk" ;; esac
RES=$(curl $CURL_OPTS -w "\n%{http_code}" -X PUT "${BASE}/api/agents/${AGENT_ID}" \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d "$PATCH_JSON")
HTTP=$(echo "$RES" | tail -n1)
BODY_RES=$(echo "$RES" | sed '$d')
if [ "$HTTP" -ge 200 ] && [ "$HTTP" -lt 300 ]; then
  echo "Agent updated."
  echo "$BODY_RES"
else
  echo "Failed (HTTP $HTTP): $BODY_RES"
  exit 1
fi
