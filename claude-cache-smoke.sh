#!/usr/bin/env bash
# claude-cache-smoke.sh
# Quick test for Anthropic Prompt Caching.
# Requirements: bash, curl, jq
#
# Usage:
#   ANTHROPIC_API_KEY=sk-... ./claude-cache-smoke.sh path/to/BIG_SYSTEM_PROMPT.txt
# Optional env:
#   MODEL=claude-sonnet-4              # any caching-supported model
#   TTL=5m                             # '5m' (default) or '1h'
#   ANTHROPIC_API_URL=https://api.anthropic.com/v1/messages

set -euo pipefail

if ! command -v jq >/dev/null; then
  echo "Please install jq (https://stedolan.github.io/jq/)" >&2
  exit 1
fi

: "${ANTHROPIC_API_KEY:?Set ANTHROPIC_API_KEY in env}"
MODEL="${MODEL:-claude-sonnet-4}"
TTL="${TTL:-5m}"
API_URL="${ANTHROPIC_API_URL:-https://api.anthropic.com/v1/messages}"

PROMPT_FILE="${1:-}"
if [[ -z "${PROMPT_FILE}" || ! -f "${PROMPT_FILE}" ]]; then
  echo "Usage: ANTHROPIC_API_KEY=... $0 path/to/BIG_SYSTEM_PROMPT.txt" >&2
  exit 1
fi

# Read and JSON-escape your big system prompt
SYS_PROMPT_JSON=$(jq -Rs '.' < "${PROMPT_FILE}")

# Small user question that can vary between calls—prefix stays identical so the cache should hit.
USER_QUESTION="In one short sentence, say 'ready'."

build_payload() {
  # Produces a JSON request body with:
  # - system[0]: small instructions (not cached)
  # - system[1]: your huge prompt, with cache_control (this is the cached breakpoint)
  # Per Anthropic docs, cache prefixes include tools->system->messages up to the block with cache_control.
  cat <<JSON
{
  "model": "${MODEL}",
  "max_tokens": 64,
  "system": [
    { "type": "text", "text": "You are a helpful assistant. Follow the provided spec exactly." },
    {
      "type": "text",
      "text": ${SYS_PROMPT_JSON},
      "cache_control": { "type": "ephemeral", "ttl": "${TTL}" }
    }
  ],
  "messages": [
    { "role": "user", "content": [{"type":"text","text":"${USER_QUESTION}"}] }
  ]
}
JSON
}

call_api() {
  local label="$1"
  local payload
  payload=$(build_payload)

  local start_ts end_ts
  start_ts=$(date +%s%3N)
  local resp
  resp=$(curl -sS "${API_URL}" \
    -H "content-type: application/json" \
    -H "x-api-key: ${ANTHROPIC_API_KEY}" \
    -H "anthropic-version: 2023-06-01" \
    -d "${payload}")
  end_ts=$(date +%s%3N)

  # Emit a compact line with timing + cache usage fields.
  # According to the API reference, these fields are in .usage:
  #   .usage.cache_creation_input_tokens
  #   .usage.cache_read_input_tokens
  #   .usage.input_tokens
  #   .usage.output_tokens
  # Also print a short preview of Claude's text for sanity.
  local dur_ms=$((end_ts - start_ts))
  local creation read input output text
  creation=$(jq -r '.usage.cache_creation_input_tokens // 0' <<<"$resp")
  read=$(jq -r '.usage.cache_read_input_tokens // 0' <<<"$resp")
  input=$(jq -r '.usage.input_tokens // 0' <<<"$resp")
  output=$(jq -r '.usage.output_tokens // 0' <<<"$resp")
  text=$(jq -r '.content[0].text // ""' <<<"$resp" | head -c 80)

  echo "[$label] ${dur_ms}ms | create:${creation} read:${read} in:${input} out:${output} | resp: ${text}"

  # Return the raw response to caller via global var
  REPLY="$resp"
}

echo "=== Claude Prompt Caching Smoke Test ==="
echo "Model: ${MODEL} | TTL: ${TTL}"
echo "Prompt file: ${PROMPT_FILE}"
echo "----------------------------------------"

# First call: should WRITE cache (creation > 0, read = 0)
call_api "FIRST"
first_resp="$REPLY"

# Small pause just to avoid rate spikes
sleep 1

# Second call (identical prefix): should READ from cache (read > 0)
call_api "SECOND"
second_resp="$REPLY"

first_create=$(jq -r '.usage.cache_creation_input_tokens // 0' <<<"$first_resp")
first_read=$(jq -r '.usage.cache_read_input_tokens // 0' <<<"$first_resp")
second_create=$(jq -r '.usage.cache_creation_input_tokens // 0' <<<"$second_resp")
second_read=$(jq -r '.usage.cache_read_input_tokens // 0' <<<"$second_resp")

echo "----------------------------------------"
if [[ "$first_create" -gt 0 && "$first_read" -eq 0 && "$second_read" -gt 0 ]]; then
  echo "✅ Cache working: first call wrote the cache; second call read ${second_read} tokens from cache."
else
  echo "❌ Cache did NOT behave as expected."
  echo "   First call:  create=${first_create}, read=${first_read}"
  echo "   Second call: create=${second_create}, read=${second_read}"
  echo "Hints:"
  echo "  • Ensure the cached block is IDENTICAL between calls (same file bytes)."
  echo "  • Keep user message the same OR ensure the cached prefix is unchanged."
  echo "  • TTL default is 5 minutes; you can set TTL=1h for longer windows."
  echo "  • Use a model that supports caching."
fi
