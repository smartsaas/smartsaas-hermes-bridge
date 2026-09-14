#!/usr/bin/env bash
# Read the signed-in user's connected mailbox (count → list → get).
# Usage:
#   ./read-user-mail.sh '{"mode":"count"}'
#   ./read-user-mail.sh '{"mode":"list","query":"is:unread","maxResults":5}'
#   ./read-user-mail.sh '{"mode":"get","messageId":"..."}'
set -euo pipefail
BODY="${1:-{\"mode\":\"count\"}}"
BASE="${SMARTSAAS_API_BASE:-https://api.smartsaas.pro}"
RES=$(curl -sS -X POST \
  -H "Authorization: Bearer ${SMARTSAAS_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "${BODY}" \
  "${BASE}/api/protected/mail/read")
echo "$RES"
