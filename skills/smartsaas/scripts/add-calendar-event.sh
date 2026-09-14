#!/usr/bin/env bash
# Usage: add-calendar-event.sh <title> <startDate> <endDate> [calendarId] [description] [location]
# Creates a calendar event with full parameters
# Required: title, startDate, endDate (ISO format: 2025-03-15T14:00:00)
# Optional: calendarId, description, location, allDay, participants (JSON array)
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

TITLE="$1"
START_DATE="$2"
END_DATE="$3"
CALENDAR_ID="${4:-}"
DESCRIPTION="${5:-}"
LOCATION="${6:-}"

if [ -z "$TITLE" ] || [ -z "$START_DATE" ] || [ -z "$END_DATE" ]; then
  echo "Error: title, startDate, and endDate are required."
  echo "Usage: add-calendar-event.sh <title> <startDate> <endDate> [calendarId] [description] [location]"
  exit 1
fi

# Build JSON body
JSON_BODY="{\"calendar\":{\"title\":\"${TITLE}\",\"startDate\":\"${START_DATE}\",\"endDate\":\"${END_DATE}\"}"
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

RES=$(curl $CURL_OPTS -w "\n%{http_code}" -X POST "${BASE}/api/calendar/add-calendar-entry" \
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
