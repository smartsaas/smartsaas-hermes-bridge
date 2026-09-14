#!/usr/bin/env bash
# Usage: update-agent-rules.sh <agentId> <rulesJson>
# Update rules/instructions for a specific agent.
# rulesJson: {"rules":"...", "constraints":[...], "personas":[...]}
# Requires: SMARTSAAS_BASE_URL, SMARTSAAS_API_KEY
set -e
BASE="${SMARTSAAS_BASE_URL}"
KEY="${SMARTSAAS_API_KEY}"
if [ -z "$BASE" ] || [ -z "$KEY" ]; then
  echo "Error: SMARTSAAS_BASE_URL and SMARTSAAS_API_KEY must be set."
  exit 1
fi
AGENT_ID="$1"
RULES_JSON="$2"
if [ -z "$AGENT_ID" ] || [ -z "$RULES_JSON" ]; then
  echo "Error: agentId and rulesJson are required."
  exit 1
fi
CURL_OPTS="-s"; case "$BASE" in *localhost*|*127.0.0.1*) CURL_OPTS="-sk" ;; esac
RES=$(curl $CURL_OPTS -w "\n%{http_code}" -X PUT "${BASE}/api/agents/${AGENT_ID}/rules" \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d "$RULES_JSON")
HTTP=$(echo "$RES" | tail -n1)
BODY_RES=$(echo "$RES" | sed '$d')
if [ "$HTTP" -ge 200 ] && [ "$HTTP" -lt 300 ]; then
  echo "Agent rules updated."
  echo "$BODY_RES"
else
  echo "Failed (HTTP $HTTP): $BODY_RES"
  exit 1
fi
