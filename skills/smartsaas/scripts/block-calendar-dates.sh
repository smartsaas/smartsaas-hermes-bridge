#!/usr/bin/env bash
# Usage: block-calendar-dates.sh <calendarId> <startDate> <endDate> [reason]
# Blocks calendar dates (marks them as unavailable)
# Required: calendarId, startDate, endDate (ISO format or date strings)
# Optional: reason (e.g., "out of office", "meeting", "personal")
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
START_DATE="$2"
END_DATE="$3"
REASON="${4:-Blocked}"

if [ -z "$CALENDAR_ID" ] || [ -z "$START_DATE" ] || [ -z "$END_DATE" ]; then
  echo "Error: calendarId, startDate, and endDate are required."
  echo "Usage: block-calendar-dates.sh <calendarId> <startDate> <endDate> [reason]"
  exit 1
fi

JSON_BODY="{\"calendarId\":\"${CALENDAR_ID}\",\"startDate\":\"${START_DATE}\",\"endDate\":\"${END_DATE}\",\"reason\":\"${REASON}\"}"

RES=$(curl $CURL_OPTS -w "\n%{http_code}" -X POST "${BASE}/api/calendar/block-dates" \
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
