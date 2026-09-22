#!/usr/bin/env bash
# Fetch a Hacker News feed + story details from the official public API.
#   fetch-feed.sh <top|best|new> [count]
# Prints one JSON document:
#   { "feed": "<feed>", "fetchedAt": <unix>, "stories": [ item, ... ] }
#
# Response sizes are capped *while data is received*, not after:
#   - per-response ceilings (max_feed_bytes / max_item_bytes) enforced with
#     `head -c` during streaming (covers chunked or oversized bodies) and with
#     `curl --max-filesize` when Content-Length is known;
#   - an aggregate ceiling (max_total_bytes) across the feed and every item.
# Reaching a ceiling fails closed: the run aborts with an error and no partial
# body is parsed. Bodies are staged in a temp dir and items are slurped once.
set -u
set -o pipefail

base="https://hacker-news.firebaseio.com/v0"
feed="${1:-top}"
count="${2:-30}"
ua="OmarchyHN/1.0 (+https://github.com/iampoul/omanews)"

# Hard ceilings (bytes). 100 is the maximum stories per run, so the aggregate
# ceiling can always serve a full run but bounds memory to a few MiB.
max_feed_bytes=$((256 * 1024))                 # top/best/new id list
max_item_bytes=$((32 * 1024))                  # one story/job document
max_total_bytes=$((max_feed_bytes + 100 * max_item_bytes))
received_total=0

curlopts=(--silent --show-error --connect-timeout 3 --max-time 10
  -H "Accept: application/json" -A "$ua")

# count feeds a jq subscript only after it is known to be a plain integer.
case "$count" in ''|*[!0-9]*) count=30 ;; esac
count=$((10#$count))
[ "$count" -ge 1 ] || count=1
[ "$count" -le 100 ] || count=100

case "$feed" in
  top) suffix="topstories" ;;
  best) suffix="beststories" ;;
  new) suffix="newstories" ;;
  *)
    printf '{"stories":[],"error":"unknown feed: %s"}\n' "$feed" >&2
    exit 2
    ;;
esac

work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT
body="$work/body"
items="$work/items.ndjson"
: > "$items"

fail() {
  printf 'fetch-feed.sh: %s\n' "$1" >&2
  exit 2
}

# fetch_capped <url> <limit>: download at most <limit> bytes (further clamped
# to the remaining aggregate budget) into $body.
#   0 = complete response below both ceilings
#   1 = transport failure (partial body must be ignored)
#   2 = a ceiling was reached (fail closed)
fetch_capped() {
  local url="$1" limit="$2" remaining rc got
  remaining=$((max_total_bytes - received_total))
  [ "$remaining" -gt 0 ] || return 2
  [ "$limit" -le "$remaining" ] || limit="$remaining"

  : > "$body"
  # head -c stops the transfer at the ceiling while bytes are streaming in,
  # even when the server never declares a size; --max-filesize rejects an
  # oversized Content-Length up front (curl exit 63).
  curl "${curlopts[@]}" --max-filesize "$limit" "$url" 2>/dev/null |
    head -c "$limit" > "$body"
  rc=$?
  got=$(wc -c < "$body" 2>/dev/null)
  got=${got//[!0-9]/}
  got=${got:-0}
  received_total=$((received_total + got))
  # A body that filled the ceiling may be truncated: fail closed.
  [ "$got" -lt "$limit" ] || return 2
  [ "$rc" -ne 63 ] || return 2
  [ "$rc" -eq 0 ] || return 1
  return 0
}

fetch_capped "$base/$suffix.json" "$max_feed_bytes"
rc=$?
if [ "$rc" -eq 2 ]; then
  fail "feed response exceeded byte limit"
fi

ids=""
if [ "$rc" -eq 0 ]; then
  ids=$(jq -r ".[0:$count][]" "$body" 2>/dev/null)
fi
if [ -z "$ids" ]; then
  printf '{"stories":[],"error":"empty feed response"}\n'
  exit 0
fi

while IFS= read -r id; do
  # ids are numeric; ignore anything else in a malformed feed.
  case "$id" in ''|*[!0-9]*) continue ;; esac

  fetch_capped "$base/item/$id.json" "$max_item_bytes"
  rc=$?
  if [ "$rc" -eq 2 ]; then
    fail "item $id response exceeded byte limit"
  fi
  [ "$rc" -eq 0 ] || continue

  # Accept complete JSON objects only; truncated or non-object bodies
  # (garbage, `null` items) are dropped, never parsed partially.
  if jq -e 'type == "object"' "$body" >/dev/null 2>&1; then
    jq -c '.' "$body" >> "$items"
  fi
done <<< "$ids"

jq -s --arg feed "$feed" --argjson fetchedAt "$(date +%s)" \
  '{ feed: $feed, fetchedAt: $fetchedAt,
     stories: [ .[] | select(. != null and (.type == "story" or .type == "job")) ] }' \
  "$items"
