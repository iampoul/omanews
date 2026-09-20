#!/usr/bin/env bash
# Fetch a Hacker News feed + story details from the official public API.
#   fetch-feed.sh <top|best|new> [count]
# Prints one JSON document:
#   { "feed": "<feed>", "fetchedAt": <unix>, "stories": [ item, ... ] }
set -u

base="https://hacker-news.firebaseio.com/v0"
feed="${1:-top}"
count="${2:-30}"
ua="OmarchyHN/1.0 (+https://github.com/iampoul/omanews)"
curlopts=(--silent --show-error --connect-timeout 3 --max-time 10
  -H "Accept: application/json" -A "$ua")

case "$feed" in
  top) suffix="topstories" ;;
  best) suffix="beststories" ;;
  new) suffix="newstories" ;;
  *)
    printf '{"stories":[],"error":"unknown feed: %s"}\n' "$feed" >&2
    exit 2
    ;;
esac

ids=$(curl "${curlopts[@]}" "$base/$suffix.json" | jq -r ".[0:$count][]" 2>/dev/null)
if [ -z "$ids" ]; then
  printf '{"stories":[],"error":"empty feed response"}\n'
  exit 0
fi

out="[]"
while IFS= read -r id; do
  [ -n "$id" ] || continue
  item=$(curl "${curlopts[@]}" "$base/item/$id.json" 2>/dev/null || printf 'null')
  out=$(printf '%s' "$out" | jq --argjson item "$item" '. + [$item]')
done <<< "$ids"

printf '%s' "$out" | jq \
  --arg feed "$feed" \
  --argjson fetchedAt "$(date +%s)" \
  '{ feed: $feed, fetchedAt: $fetchedAt,
     stories: [ .[] | select(. != null and (.type == "story" or .type == "job")) ] }'