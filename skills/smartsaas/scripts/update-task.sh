#!/usr/bin/env bash
# Usage: update-task.sh <projectId> <taskId> <patchJson>
# PATCH task fields (e.g. status, title). Use for progress updates.
# Example: update-task.sh <projectId> <taskId> '{"status":"in_progress","summary":"50% done"}'
# Permission: projects:write
# Requires: SMARTSAAS_BASE_URL, SMARTSAAS_API_KEY
set -e
BASE="${SMARTSAAS_BASE_URL}"
KEY="${SMARTSAAS_API_KEY}"
if [ -z "$BASE" ] || [ -z "$KEY" ]; then
  echo "Error: SMARTSAAS_BASE_URL and SMARTSAAS_API_KEY must be set."
  exit 1
fi
CURL_OPTS="-s"; case "$BASE" in *localhost*|*127.0.0.1*) CURL_OPTS="-sk" ;; esac
PROJECT_ID="$1"
TASK_ID="$2"
PATCH_JSON="$3"
if [ -z "$PROJECT_ID" ] || [ -z "$TASK_ID" ] || [ -z "$PATCH_JSON" ]; then
  echo "Error: projectId, taskId, and patchJson (all three arguments) are required."
  echo "Example: update-task.sh <projectId> <taskId> '{\"status\":\"done\",\"task_title\":\"Updated title\"}'"
  exit 1
fi
RES=$(curl $CURL_OPTS -w "\n%{http_code}" -X PATCH "${BASE}/api/protected/projects/${PROJECT_ID}/tasks/${TASK_ID}" \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" -d "$PATCH_JSON")
HTTP=$(echo "$RES" | tail -n1)
BODY_RES=$(echo "$RES" | sed '$d')
if [ "$HTTP" -ge 200 ] && [ "$HTTP" -lt 300 ]; then
  echo "Task $TASK_ID updated."
  echo "$BODY_RES"
else
  echo "Failed (HTTP $HTTP): $BODY_RES"
  exit 1
fi
