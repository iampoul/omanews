import QtQuick
import qs.Ui
import qs.Commons
import "Model.js" as Model

// Bar pill: "HN · <current headline>", rotating through the cached stories
// from the Hacker News service. Left-click opens the story panel, middle-click
// (or Shift+left-click) opens the current story, Shift+middle-click cycles the
// feed. Hidden entirely while the service has nothing to show.
BarWidget {
    id: root
    moduleName: "io.github.iampoul.hackernews"

    property var service: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
    property int tickerIndex: 0
    property bool busy: false

    readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

    function open() {
        if (panelLoader.item) panelLoader.item.open()
    }

    function close() {
        if (panelLoader.item) panelLoader.item.close()
    }

    function togglePanel() {
        if (panelLoader.item) panelLoader.item.toggle()
    }

    readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

    function closeForPopoutSwitch() {
        if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
    }

    function injectPanel() {
        var target = panelLoader.item
        if (!target) return
        target.bar = root.bar
        target.settings = root.settings
        target.anchorItem = pill
        target.hostWidget = root
        target.service = root.service
    }

    onBarChanged: {
        root.service = root.bar && root.bar.shell ? root.bar.shell.serviceFor(root.moduleName) : null
        injectPanel()
    }

    onSettingsChanged: {
        root.maybeApplyTimers()
        root.configureService()
        injectPanel()
    }

    Component.onCompleted: {
        root.maybeApplyTimers()
        root.configureService()
    }

    onServiceChanged: {
        injectPanel()
        root.configureService()
    }

    function configureService() {
        if (root.service && typeof root.service.configure === "function")
            root.service.configure(root.settings)
    }

    function maybeApplyTimers() {
        tickerTimer.interval = Model.tickerMs(root.setting("tickerSeconds", 6))
        if (!tickerTimer.running) tickerTimer.start()
    }

    function storyList() {
        return root.service && root.service.hasStories ? root.service.stories : []
    }

    function currentStory() {
        var list = root.storyList()
        if (list.length === 0) return null
        return list[root.tickerIndex % list.length]
    }

    function advance() {
        var list = root.storyList()
        if (list.length > 0) root.tickerIndex = (root.tickerIndex + 1) % list.length
    }

    function nextFeed() {
        if (!root.service) return
        var feeds = Model.feedList()
        var current = feeds.indexOf(Model.sanitizeFeed(root.service.feed))
        var next = feeds[(current + 1) % feeds.length]
        root.service.setFeed(next)
    }

    function openStory(forceThread) {
        var story = root.currentStory()
        if (!story || !root.bar) return
        root.bar.run("omarchy launch browser " + Util.shellQuote(Model.storyUrl(story, forceThread)))
    }

    Timer {
        id: tickerTimer
        interval: Model.tickerMs(root.setting("tickerSeconds", 6))
        repeat: true
        onTriggered: {
            if (!root.busy) cycleAnimation.restart()
        }
    }

    SequentialAnimation {
        id: cycleAnimation
        running: false
        NumberAnimation { target: titleText; property: "opacity"; to: 0; duration: 130 }
        ScriptAction {
            script: {
                if (root.storyList().length > 0) root.advance()
            }
        }
        NumberAnimation { target: titleText; property: "opacity"; to: 1; duration: 130 }
    }

    visible: panelLoader.item
        ? panelLoader.item.label !== "" || root.service !== null
        : root.service !== null
    implicitWidth: pill.implicitWidth + Style.space(12)
    implicitHeight: Math.max(pill.implicitHeight + Style.space(6), root.barSize)

    Loader {
        id: panelLoader
        active: true
        source: Qt.resolvedUrl("Panel.qml")
        visible: false
        onLoaded: {
            root.injectPanel()
            Qt.callLater(root.injectPanel)
        }
    }

    Row {
        id: pill
        anchors.centerIn: parent
        spacing: Style.space(6)

        Text {
            id: brandText
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf1d4"
            color: "#ff6600"
            font.family: root.bar ? root.bar.fontFamily : "monospace"
            font.pixelSize: Style.font.caption
        }

        Text {
            id: feedText
            anchors.verticalCenter: parent.verticalCenter
            text: root.service ? root.service.feedLabel : "HN"
            color: root.bar ? Qt.darker(root.bar.foreground, 1.3) : "#a6adc8"
            font.family: root.bar ? root.bar.fontFamily : "monospace"
            font.pixelSize: Style.font.caption
            font.bold: true
        }

        Text {
            id: titleText
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(root.maxTitleWidth, implicitWidth)
            clip: true
            maximumLineCount: 1
            elide: Text.ElideRight
            text: {
                var story = root.currentStory()
                if (story) return story.title
                if (root.service && root.service.loading && root.service.stories.length === 0) return "loading…"
                if (root.service && root.service.error && root.service.stories.length === 0) return "unavailable"
                return ""
            }
            color: root.bar ? (root.service && root.service.stories.length === 0 ? Qt.darker(root.bar.foreground, 1.4) : root.bar.foreground) : "white"
            font.family: root.bar ? root.bar.fontFamily : "monospace"
            font.pixelSize: Style.font.bodySmall
            opacity: 1
        }

        Text {
            id: scoreText
            anchors.verticalCenter: parent.verticalCenter
            text: {
                var story = root.currentStory()
                return story && story.score > 0 ? "▲ " + story.score : ""
            }
            color: root.bar ? Qt.darker(root.bar.foreground, 1.2) : "#9399b2"
            font.family: root.bar ? root.bar.fontFamily : "monospace"
            font.pixelSize: Style.font.caption
        }
    }

    readonly property int maxTitleWidth: Math.max(120, Style.space(300))

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        hoverEnabled: true

        onClicked: function(mouse) {
            if (mouse.button === Qt.MiddleButton) {
                if (mouse.modifiers & Qt.ShiftModifier) root.nextFeed()
                else root.openStory(false)
            } else if (mouse.button === Qt.LeftButton) {
                if (mouse.modifiers & Qt.ShiftModifier) root.openStory(true)
                else root.togglePanel()
            }
        }
    }
}