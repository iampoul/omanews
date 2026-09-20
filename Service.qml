import QtQuick
import Quickshell.Io
import "Model.js" as Model

// Background service for Hacker News: polls the official HN API through
// fetch-feed.sh and caches the story list. The bar widget and panel read
// from this single instance (bar.shell.serviceFor("io.github.iampoul.hackernews")).
Item {
    id: root

    property var settings: ({})
    property string feed: "top"
    property var stories: []
    property bool loading: false
    property string error: ""
    property date fetchedAt: new Date(0)
    property int retryMinutes: 1
    property bool refreshPending: false
    property int requestGeneration: 0

    readonly property bool hasStories: Array.isArray(stories) && stories.length > 0
    readonly property bool stale: hasStories && Date.now() - fetchedAt.getTime() > refreshIntervalMs * 2
    readonly property string ageLabel: hasStories ? Model.relativeTime(fetchedAt.getTime() / 1000) : ""
    readonly property string feedLabel: Model.feedLabel(feed)

    readonly property int refreshIntervalMs: Math.max(60, parseInt(root.setting("refreshMinutes", 5), 10) || 5) * 60 * 1000
    readonly property int storyCount: Math.max(1, Math.min(100, parseInt(root.setting("storyCount", 30), 10) || 30))

    function setting(key, fallback) {
        var value = settings && settings[key]
        return value === undefined || value === null ? fallback : value
    }

    function configure(nextSettings) {
        settings = nextSettings || ({})
        refreshTimer.interval = refreshIntervalMs
        refreshTimer.restart()
        if (loading) {
            refreshPending = true
            return
        }
        refresh(false)
    }

    function setFeed(next) {
        var resolved = Model.sanitizeFeed(next)
        if (resolved === root.feed && hasStories) return
        root.feed = resolved
        if (hasStories) return
        refresh(true)
    }

    function refresh(manual) {
        if (loading) {
            refreshPending = true
            refreshTimer.restart()
            return
        }
        if (manual && hasStories && Date.now() < fetchedAt.getTime() + refreshIntervalMs) return
        loading = true
        error = ""
        requestGeneration += 1
        fetchRequest.generation = requestGeneration
        fetchRequest.exec([
            Qt.resolvedUrl("fetch-feed.sh").toString().replace("file://", ""),
            root.feed,
            String(root.storyCount)
        ])
    }

    function runPendingRefresh() {
        if (!refreshPending || loading) return
        refreshPending = false
        refresh(true)
    }

    function refreshFailed(message) {
        error = message
        loading = false
        if (hasStories) {
            refreshTimer.interval = Math.max(60, refreshIntervalMs)
            refreshTimer.restart()
        } else {
            retryMinutes = 1
            refreshTimer.interval = retryMinutes * 60 * 1000
            refreshTimer.restart()
            retryMinutes = Math.min(retryMinutes * 5, 60)
        }
    }

    function refreshSucceeded() {
        loading = false
        error = ""
        retryMinutes = 1
        refreshTimer.interval = refreshIntervalMs
        refreshTimer.restart()
    }

    Timer {
        id: refreshTimer
        interval: refreshIntervalMs
        repeat: true
        onTriggered: root.refresh(false)
    }

    Process {
        id: fetchRequest
        property int generation: -1
        stdout: StdioCollector { id: fetchBody; waitForEnd: true }
        stderr: StdioCollector { id: fetchStderr; waitForEnd: true }
        onExited: (exitCode) => {
            root.loading = false
            if (generation !== root.requestGeneration) {
                root.runPendingRefresh()
                return
            }
            if (exitCode !== 0) {
                root.refreshFailed(fetchStderr.text.trim() || "Hacker News request failed.")
                root.runPendingRefresh()
                return
            }
            var parsed = Model.parseFeedPayload(fetchBody.text, root.feed)
            if (parsed.stories.length === 0) {
                root.refreshFailed(parsed.error || "No stories returned.")
                root.runPendingRefresh()
                return
            }
            root.feed = parsed.feed
            root.stories = Model.dedupeStories(parsed.stories)
            root.fetchedAt = new Date(parsed.fetchedAt * 1000)
            console.log("omarchy-hackernews: loaded", root.stories.length, "stories from feed", root.feed)
            root.refreshSucceeded()
            root.runPendingRefresh()
        }
    }
}