// Parsing and formatting helpers for the Hacker News plugin.
// Pure functions only; no QML dependencies. Mirrors the omarchy plugin
// convention of keeping logic in a <name>Model.js next to the QML files.

var _entityMap = {
  amp: "&",
  lt: "<",
  gt: ">",
  quot: '"',
  apos: "'"
}

// Decode the HTML entities HN uses in titles and text (e.g. &quot; &#x27;).
function decodeEntities(s) {
  if (s === undefined || s === null) return ""
  return String(s)
    .replace(/&#x([0-9a-fA-F]{1,6});?/g, function(_m, hex) {
      var cp = parseInt(hex, 16)
      return isFinite(cp) && cp > 0 ? String.fromCodePoint(cp) : ""
    })
    .replace(/&#([0-9]{1,7});?/g, function(_m, dec) {
      var cp = parseInt(dec, 10)
      return isFinite(cp) && cp > 0 ? String.fromCodePoint(cp) : ""
    })
    .replace(/&([a-zA-Z][a-zA-Z0-9]{1,11});/g, function(_m, name) {
      var lower = name.toLowerCase()
      return _entityMap[lower] !== undefined ? _entityMap[lower] : _m
    })
    .replace(/[ \t]+/g, " ")
    .replace(/^\s+|\s+$/g, "")
}

function threadUrl(item) {
  var id = item && item.id !== undefined ? item.id : ""
  return "https://news.ycombinator.com/item?id=" + id
}

// Open target for a story. Articles without a url (Ask/Show) always open the
// HN thread; forceThread forces the thread for everything.
function storyUrl(item, forceThread) {
  if (!item) return ""
  var url = typeof item.url === "string" && item.url.trim() !== "" ? item.url.trim() : ""
  if (forceThread || url === "") return threadUrl(item)
  return url
}

function feedList() {
  return [ "top", "best", "new" ]
}

function sanitizeFeed(feed) {
  var f = String(feed || "top")
  return feedList().indexOf(f) >= 0 ? f : "top"
}

function feedLabel(feed) {
  switch (sanitizeFeed(feed)) {
    case "best": return "Best"
    case "new": return "New"
    default: return "Top"
  }
}

function feedLocationLabel(feed) {
  switch (sanitizeFeed(feed)) {
    case "best": return "Best of Hacker News"
    case "new": return "Newest submissions"
    default: return "Top of Hacker News"
  }
}

// Normalize one raw HN item into a compact story object.
function normalizeStory(item) {
  if (!item || typeof item !== "object") return null
  if (item.deleted === true || item.dead === true) return null
  if (item.type !== "story" && item.type !== "job") return null
  if (item.id === undefined || item.id === null) return null

  var url = typeof item.url === "string" && item.url.trim() !== "" ? item.url.trim() : ""
  return {
    id: item.id,
    type: item.type,
    title: decodeEntities(item.title),
    url: url,
    threadUrl: threadUrl(item),
    score: typeof item.score === "number" ? item.score : (typeof item.score === "string" ? parseInt(item.score, 10) || 0 : 0),
    by: typeof item.by === "string" ? item.by : "",
    comments: typeof item.descendants === "number" ? item.descendants : (typeof item.descendants === "string" ? parseInt(item.descendants, 10) || 0 : 0),
    time: typeof item.time === "number" ? item.time : (typeof item.time === "string" ? parseInt(item.time, 10) || 0 : 0)
  }
}

// Parse the raw JSON emitted by fetch-feed.sh, filtering invalid/dead items.
function parseFeedPayload(raw, fallbackFeed) {
  var fallback = {
    feed: sanitizeFeed(fallbackFeed),
    fetchedAt: Date.now() / 1000,
    error: "",
    stories: []
  }
  var payload
  try {
    payload = JSON.parse(String(raw || "{}"))
  } catch (exception) {
    return fallback
  }
  if (!payload || typeof payload !== "object") return fallback

  var out = {
    feed: sanitizeFeed(payload.feed),
    fetchedAt: typeof payload.fetchedAt === "number" ? payload.fetchedAt : Date.now() / 1000,
    error: typeof payload.error === "string" ? payload.error : "",
    stories: []
  }
  var list = Array.isArray(payload.stories) ? payload.stories : []
  for (var i = 0; i < list.length; i++) {
    var story = normalizeStory(list[i])
    if (story) out.stories.push(story)
  }
  return out
}

// Collapse consecutive duplicate titles (HN reposts the same URL to the top).
function dedupeStories(stories) {
  if (!Array.isArray(stories)) return []
  var seen = {}
  var out = []
  for (var i = 0; i < stories.length; i++) {
    var key = String(stories[i].url || stories[i].threadUrl || stories[i].title)
    if (seen[key] === true) continue
    seen[key] = true
    out.push(stories[i])
  }
  return out
}

// "5m ago" / "2h ago" / "3d ago" from a unix timestamp.
function relativeTime(unixSeconds, nowSeconds) {
  if (unixSeconds === undefined || unixSeconds === null || isNaN(unixSeconds) || unixSeconds <= 0) return ""
  var now = typeof nowSeconds === "number" ? nowSeconds : Date.now() / 1000
  var seconds = Math.max(0, now - unixSeconds)
  if (seconds < 60) return "just now"
  var minutes = Math.round(seconds / 60)
  if (minutes < 60) return minutes + "m ago"
  var hours = Math.round(minutes / 60)
  if (hours < 24) return hours + "h ago"
  var days = Math.round(hours / 24)
  return days + "d ago"
}

// Ticker rotation interval in ms from a seconds setting (positive clamp).
function tickerMs(seconds) {
  var s = Number(seconds)
  if (!isFinite(s) || s <= 0) s = 6
  return Math.round(s * 1000)
}

function truncateTitle(title, maxLength) {
  var s = String(title || "")
  var n = Math.max(10, Number(maxLength) || 48)
  if (s.length <= n) return s
  return s.slice(0, n - 1).replace(/\s+\S*$/, "") + "…"
}

if (typeof module !== "undefined") {
  module.exports = {
    decodeEntities: decodeEntities,
    threadUrl: threadUrl,
    storyUrl: storyUrl,
    feedList: feedList,
    sanitizeFeed: sanitizeFeed,
    feedLabel: feedLabel,
    feedLocationLabel: feedLocationLabel,
    normalizeStory: normalizeStory,
    parseFeedPayload: parseFeedPayload,
    dedupeStories: dedupeStories,
    relativeTime: relativeTime,
    tickerMs: tickerMs,
    truncateTitle: truncateTitle
  }
}