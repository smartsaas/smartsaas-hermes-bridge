#!/usr/bin/env bash
# Usage: update-calendar-entry.sh <entryId> <title> <startDate> <endDate> [calendarId] [description] [location]
# Updates an existing calendar entry
# Required: entryId, title, startDate, endDate
# Optional: calendarId, description, location, allDay, participants
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

ENTRY_ID="$1"
TITLE="$2"
START_DATE="$3"
END_DATE="$4"
CALENDAR_ID="${5:-}"
DESCRIPTION="${6:-}"
LOCATION="${7:-}"

if [ -z "$ENTRY_ID" ] || [ -z "$TITLE" ] || [ -z "$START_DATE" ] || [ -z "$END_DATE" ]; then
  echo "Error: entryId, title, startDate, and endDate are required."
  echo "Usage: update-calendar-entry.sh <entryId> <title> <startDate> <endDate> [calendarId] [description] [location]"
  exit 1
fi

JSON_BODY="{\"calendar\":{\"_id\":\"${ENTRY_ID}\",\"title\":\"${TITLE}\",\"startDate\":\"${START_DATE}\",\"endDate\":\"${END_DATE}\"}"
if [ -n "$CALENDAR_ID" ]; then
  JSON_BODY="${JSON_BODY},\"calendarId\":\"${CALENDAR_ID}\""
fi
if [ -n "$DESCRIPTION" ]; then
  JSON_BODY="${JSON_BODY},\"description\":\"${DESCRIPTION}\""
fi
if [ -n "$LOCATION" ]; then
  JSON_BODY="${JSON_BODY},\"location\":\"${LOCATION}\""
fi
JSON_BODY="${JSON_BODY}}"

RES=$(curl $CURL_OPTS -w "\n%{http_code}" -X PUT "${BASE}/api/calendar/update-calendar-entry" \
  -H "Authorization: Bearer ${KEY}" -H "Content-Type: application/json" \
  -d "$JSON_BODY")
HTTP=$(echo "$RES" | tail -n1)
BODY_RES=$(echo "$RES" | sed '$d')
if [ "$HTTP" -ge 200 ] && [ "$HTTP" -lt 300 ]; then
  echo "$BODY_RES"
else
  echo "Failed (HTTP $HTTP): $BODY_RES"
  exit 1
fi
