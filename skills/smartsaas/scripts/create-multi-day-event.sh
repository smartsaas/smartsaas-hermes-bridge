#!/usr/bin/env bash
# Usage: create-multi-day-event.sh <calendarId> <title> <startDate> <endDate> [description] [location] [allDay]
# Creates a multi-day calendar event with recurrence options
# Required: calendarId, title, startDate, endDate
# Optional: description, location, allDay (true/false, default: true)
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

CALENDAR_ID="$1"
TITLE="$2"
START_DATE="$3"
END_DATE="$4"
DESCRIPTION="${5:-}"
LOCATION="${6:-}"
ALL_DAY="${7:-true}"

if [ -z "$CALENDAR_ID" ] || [ -z "$TITLE" ] || [ -z "$START_DATE" ] || [ -z "$END_DATE" ]; then
  echo "Error: calendarId, title, startDate, and endDate are required."
  echo "Usage: create-multi-day-event.sh <calendarId> <title> <startDate> <endDate> [description] [location] [allDay]"
  exit 1
fi

JSON_BODY="{\"calendarId\":\"${CALENDAR_ID}\",\"title\":\"${TITLE}\",\"startDate\":\"${START_DATE}\",\"endDate\":\"${END_DATE}\",\"allDay\":${ALL_DAY}}"
if [ -n "$DESCRIPTION" ]; then
  JSON_BODY="${JSON_BODY},\"description\":\"${DESCRIPTION}\""
fi
if [ -n "$LOCATION" ]; then
  JSON_BODY="${JSON_BODY},\"location\":\"${LOCATION}\""
fi

RES=$(curl $CURL_OPTS -w "\n%{http_code}" -X POST "${BASE}/api/calendar/create-multi-day-event" \
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
