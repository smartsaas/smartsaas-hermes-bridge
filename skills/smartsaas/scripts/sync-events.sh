#!/usr/bin/env bash
# Usage: sync-events.sh <events_json>
# Syncs calendar events (batch insert)
# Required: events_json (JSON array of calendar entries)
# Requires: SMARTSAAS_BASE_URL, SMARTSAAS_API_KEY
set -e

BASE="${SMARTSAAS_BASE_URL}"
KEY="${SMARTSAAS_API_KEY}"
if [ -z "$BASE" ] || [ -z "$KEY" ]; then
  echo "Error: SMARTSAAS_BASE_URL and SMARTSAAS_API_KEY must be set."
  exit 1
fi

CURL_OPTS="-s"
case "$BASE" in *localhost*|*127.0.0.1*) CURL_OPTS="-sk" ;; esac

EVENTS_JSON="$1"

if [ -z "$EVENTS_JSON" ]; then
  echo "Error: events_json is required."
  echo "Usage: sync-events.sh '<JSON_ARRAY_OF_EVENTS>'"
  exit 1
fi

RES=$(curl $CURL_OPTS -w "\n%{http_code}" -X POST "${BASE}/api/calendar/sync-events" \
  -H "Authorization: Bearer ${KEY}" -H "Content-Type: application/json" \
  -d "$EVENTS_JSON")
HTTP=$(echo "$RES" | tail -n1)
BODY_RES=$(echo "$RES" | sed '$d')
if [ "$HTTP" -ge 200 ] && [ "$HTTP" -lt 300 ]; then
  echo "$BODY_RES"
else
  echo "Failed (HTTP $HTTP): $BODY_RES"
  exit 1
fi
