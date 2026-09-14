#!/usr/bin/env bash
# Usage: list-datasets.sh [parentId] [page] [limit] [sortBy] [sortOrder]
#   page default 1, limit default 10, sortBy default updatedAt, sortOrder asc|desc default desc
# Requires: SMARTSAAS_BASE_URL, SMARTSAAS_API_KEY
set -e
BASE="${SMARTSAAS_BASE_URL}"
KEY="${SMARTSAAS_API_KEY}"
if [ -z "$BASE" ] || [ -z "$KEY" ]; then
  echo "Error: SMARTSAAS_BASE_URL and SMARTSAAS_API_KEY must be set."
  exit 1
fi
# Allow self-signed certs for localhost only; prod keeps full SSL verification
CURL_OPTS="-s"; case "$BASE" in *localhost*|*127.0.0.1*) CURL_OPTS="-sk" ;; esac
PARENT_ID="$1"
PAGE="${2:-1}"
LIMIT="${3:-10}"
SORT_BY="${4:-updatedAt}"
SORT_ORDER="${5:-desc}"
URL="${BASE}/api/protected/data/folders"
ARGS="page=${PAGE}&limit=${LIMIT}&sortBy=${SORT_BY}&sortOrder=${SORT_ORDER}"
[ -n "$PARENT_ID" ] && ARGS="${ARGS}&parentId=${PARENT_ID}"
URL="${URL}?${ARGS}"
RES=$(curl $CURL_OPTS -w "\n%{http_code}" -X GET "$URL" -H "Authorization: Bearer $KEY")
HTTP=$(echo "$RES" | tail -n1)
BODY_RES=$(echo "$RES" | sed '$d')
if [ "$HTTP" -ge 200 ] && [ "$HTTP" -lt 300 ]; then
  echo "$BODY_RES"
else
  echo "Failed (HTTP $HTTP): $BODY_RES"
  exit 1
fi
