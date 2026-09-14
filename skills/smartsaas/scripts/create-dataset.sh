#!/usr/bin/env bash
# Usage: create-dataset.sh <dataTitle> [parentId] [bodyJson]
#   Arg1: dataTitle (required). Arg2: parentId — use "" (empty string) for no parent, NOT the word "parentId".
#   Arg3: bodyJson — full JSON with "dataTitle", "dataSchema": {"fields": [...]}, and optionally "dataTags": ["customers","documents",...].
#   Wrong: create-dataset.sh "Test" parentId '{"dataSchema": "example_schema"}'  (parentId is literal; dataSchema must be object with "fields").
#   Right: create-dataset.sh "Test Dataset" "" '{"dataTitle":"Test Dataset","dataSchema":{"fields":[{"name":"name","type":"string"},{"name":"notes","type":"string"}]}}'
#   IMPORTANT: When bodyJson is omitted, do NOT fall back to a generic schema. The agent must DESIGN dataSchema.fields
#   based on the dataset title and user intent (e.g., "Investor List" → Name, Email, Phone, City, Country).
# Requires: SMARTSAAS_BASE_URL, SMARTSAAS_API_KEY (set in env or openclaw.json skill env)
set -e
BASE="${SMARTSAAS_BASE_URL}"
KEY="${SMARTSAAS_API_KEY}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCHEMA_SPEC_PATH="${SCRIPT_DIR}/defaultSchemaValidationSpec.json"
if [ -z "$BASE" ] || [ -z "$KEY" ]; then
  echo "Error: SMARTSAAS_BASE_URL and SMARTSAAS_API_KEY must be set."
  exit 1
fi
if [ ! -f "$SCHEMA_SPEC_PATH" ]; then
  echo "Error: Schema validation spec not found at $SCHEMA_SPEC_PATH"
  exit 1
fi
# Reject flags: script takes positional args only (no --name, etc.)
if [ -n "$1" ] && [ "${1#-}" != "$1" ]; then
  echo "Error: Positional args only. Usage: create-dataset.sh \"<dataTitle>\" [parentId] [bodyJson]. Do NOT use --name or other flags. Include dataSchema in bodyJson to allow adding items."
  exit 1
fi
# Allow self-signed certs for localhost only; prod keeps full SSL verification
CURL_OPTS="-s"; case "$BASE" in *localhost*|*127.0.0.1*) CURL_OPTS="-sk" ;; esac
TITLE="$1"
PARENT_ID="${2:-}"
BODY_JSON="${3:-}"
# Second arg: use "" for no parent, not the literal word "parentId"
[ "$PARENT_ID" = "parentId" ] || [ "$PARENT_ID" = "parent_id" ] && PARENT_ID=""
if [ -z "$TITLE" ]; then
  echo "Error: dataTitle (first argument) is required."
  exit 1
fi
# Always use arg1 (TITLE) for dataTitle so the dataset is never "untitled_folder".
# Build/validate body with Python so dataTitle is guaranteed and schema is normalized by AI rules.
if [ -n "$BODY_JSON" ] && [ "${BODY_JSON#\{}" != "$BODY_JSON" ]; then
  BODY=$(printf '%s' "$BODY_JSON" | python3 -c '
import sys, json
title = sys.argv[1]
parent_id = sys.argv[2] if len(sys.argv) > 2 else ""
spec_path = sys.argv[3] if len(sys.argv) > 3 else ""

def lower_map(d):
    return {str(k).lower(): v for k, v in (d or {}).items()}

with open(spec_path, "r", encoding="utf-8") as f:
    spec = json.load(f)

type_aliases = lower_map(spec.get("typeAliases", {}))
supported_types = set(spec.get("supportedTypes", []))
default_validation = spec.get("defaultValidationByType", {})
title_heuristics = spec.get("titleHeuristics", [])

def infer_type_from_title(field_title):
    field_title_l = str(field_title or "").lower()
    for rule in title_heuristics:
        for token in rule.get("matchAny", []):
            if str(token).lower() in field_title_l:
                return rule.get("assignType"), rule.get("validationOverrides") or {}
    return None, {}

def normalize_type(raw_type, field_title):
    candidate = str(raw_type or "").strip()
    if not candidate:
        inferred_type, inferred_validation = infer_type_from_title(field_title)
        if inferred_type:
            candidate = inferred_type
        else:
            candidate = "string"
        return candidate, inferred_validation
    candidate = type_aliases.get(candidate.lower(), candidate)
    return candidate, {}

data = json.loads(sys.stdin.read())
data["dataTitle"] = title
if parent_id:
    data["parentId"] = parent_id

schema = data.get("dataSchema")
if not isinstance(schema, dict):
    raise SystemExit("Error: bodyJson must include dataSchema object.")
fields = schema.get("fields")
if not isinstance(fields, list) or not fields:
    raise SystemExit("Error: bodyJson dataSchema.fields must be a non-empty array.")

normalized_fields = []
for idx, field in enumerate(fields):
    if not isinstance(field, dict):
        raise SystemExit(f"Error: field at index {idx} must be an object.")
    field_title = field.get("title") or field.get("name") or f"Field {idx+1}"
    normalized_type, inferred_validation = normalize_type(field.get("type"), field_title)
    if normalized_type not in supported_types:
        raise SystemExit(
            f"Error: Unsupported field type `{normalized_type}` for `{field_title}` at index {idx}. "
            f"Allowed types are defined in {spec_path}."
        )

    merged_validation = {}
    merged_validation.update(default_validation.get(normalized_type, {}))
    merged_validation.update(inferred_validation)
    if isinstance(field.get("validation"), dict):
        merged_validation.update(field["validation"])

    new_field = dict(field)
    new_field["title"] = field_title
    new_field["type"] = normalized_type
    if merged_validation:
        new_field["validation"] = merged_validation
    normalized_fields.append(new_field)

schema["fields"] = normalized_fields
schema.setdefault("meta", {})
if isinstance(schema["meta"], dict):
    schema["meta"]["designedBy"] = "ai"
    schema["meta"]["schemaValidationSpecPath"] = spec_path
data["dataSchema"] = schema

print(json.dumps(data, separators=(",", ":")))
' "$TITLE" "$PARENT_ID" "$SCHEMA_SPEC_PATH")
  [ -n "$BODY" ] || { echo "Error: Failed to build request body from bodyJson." >&2; exit 1; }
else
  # Do NOT use a generic default schema. AI should design fields using the schema validation spec.
  echo "Error: dataSchema is required. You must DESIGN dataSchema.fields based on the dataset title and user intent." >&2
  echo "AI schema design must follow: $SCHEMA_SPEC_PATH" >&2
  echo "Example: 'Investor List' → {\"fields\":[{\"name\":\"Name\",\"type\":\"string\"},{\"name\":\"Email\",\"type\":\"string\"},{\"name\":\"Phone\",\"type\":\"string\"},{\"name\":\"City\",\"type\":\"string\"},{\"name\":\"Country\",\"type\":\"string\"}]}" >&2
  echo "Usage: create-dataset.sh \"<dataTitle>\" [parentId] '{\"dataTitle\":\"<title>\",\"dataSchema\":{\"fields\":[...]},\"dataTags\":[\"customers\",\"documents\",...]}'" >&2
  echo "Run get-schema.sh dataset for the expected shape, then build bodyJson with fields appropriate for the dataset." >&2
  exit 1
fi
RES=$(curl $CURL_OPTS -w "\n%{http_code}" -X POST "${BASE}/api/protected/data/folders" \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" -d "$BODY")
HTTP=$(echo "$RES" | tail -n1)
BODY_RES=$(echo "$RES" | sed '$d')
if [ "$HTTP" -ge 200 ] && [ "$HTTP" -lt 300 ]; then
  echo "Dataset created: $TITLE"
  echo "Response (use top-level _id as folderId for add-to-dataset.sh):"
  echo "$BODY_RES"
else
  echo "Failed (HTTP $HTTP): $BODY_RES"
  exit 1
fi
