import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Ui
import qs.Commons
import "Model.js" as Model

// Story popup: headline list for a chosen feed with article/thread opening.
// Data comes from the shared service via BarWidget.injectPanel.
Panel {
    id: root
    moduleName: "io.github.iampoul.hackernews"
    manageIpc: false

    property var anchorItem: null
    property var hostWidget: null
    property var service: null
    property var persistSettings: null

    readonly property string label: root.service && root.service.hasStories ? root.service.feedLabel : ""
    readonly property string activeFeed: root.service ? Model.sanitizeFeed(root.service.feed) : "top"

    function open() {
        root.controller.show()
    }

    function close() {
        root.controller.hide()
    }

    function toggle() {
        if (root.opened) root.close()
        else root.open()
    }

    function setFeed(feed) {
        if (root.service) root.service.setFeed(feed)
    }

    function refresh() {
        if (root.service) root.service.refresh(true)
    }

    function openStory(story, forceThread) {
        if (!story) return
        if (root.bar) {
            root.bar.run("omarchy launch browser " + Util.shellQuote(Model.storyUrl(story, forceThread)))
        }
    }

    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.hostWidget || root
        bar: root.bar
        open: root.opened
        contentWidth: Style.space(560)
        contentHeight: Style.space(640)

        Rectangle {
            anchors.fill: parent
            color: root.bar ? root.bar.background : "#11111b"
            radius: 10
            border.color: root.bar ? Qt.darker(root.bar.foreground, 1.8) : "#313244"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Style.space(6)
                spacing: Style.space(2)

                // Header: title, feed tabs, refresh
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(40)

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Style.space(10)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Hacker News"
                        color: root.bar ? root.bar.foreground : "white"
                        font.family: root.bar ? root.bar.fontFamily : "monospace"
                        font.pixelSize: Style.font.title
                        font.bold: true
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(6)

                        Repeater {
                            model: Model.feedList()

                            delegate: TabButton {
                                required property string modelData
                                text: Model.feedLabel(modelData)
                                checked: modelData === root.activeFeed

                                onClicked: root.setFeed(modelData)

                                contentItem: Text {
                                    text: parent.text
                                    color: parent.checked ? "#ff6600" : (root.bar ? Qt.darker(root.bar.foreground, 1.4) : "#a6adc8")
                                    font.family: root.bar ? root.bar.fontFamily : "monospace"
                                    font.pixelSize: Style.font.bodySmall
                                    font.bold: parent.checked
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                background: Rectangle {
                                    implicitWidth: Style.space(52)
                                    implicitHeight: Style.space(26)
                                    radius: Style.space(6)
                                    color: parent.hovered
                                        ? Qt.rgba(1, 1, 1, 0.06)
                                        : (parent.checked ? Qt.rgba(1, 0.4, 0, 0.14) : "transparent")
                                    border.color: parent.checked
                                        ? Qt.rgba(1, 0.4, 0, 0.35)
                                        : "transparent"
                                    border.width: 1
                                }
                            }
                        }
                    }

                    Button {
                        anchors.right: parent.right
                        anchors.rightMargin: Style.space(4)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf01b"
                        tooltipText: "Refresh"
                        foreground: root.bar ? Qt.darker(root.bar.foreground, 1.2) : "#a6adc8"
                        fontSize: Style.font.bodySmall
                        accent: "#ff6600"

                        onClicked: root.refresh()
                    }
                }

                PanelSeparator { Layout.fillWidth: true }

                // Story list (fills remaining height)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"

                    ListView {
                        id: storyList
                        anchors.fill: parent
                        anchors.margins: Style.space(2)
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: contentHeight > height
                        spacing: 1
                        model: root.service && root.service.hasStories ? root.service.stories : []

                        delegate: StoryRow {
                            required property var modelData
                            story: modelData
                            enabled: root.service !== null && !root.service.loading

                            onOpenRequested: function(story, forceThread) {
                                root.openStory(story, forceThread)
                            }
                        }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: Style.space(8)
                        visible: (root.service === null) || (root.service && !root.service.hasStories)

                        Text {
                            text: {
                                if (!root.service) return "Service unavailable"
                                if (root.service.loading) return "Loading Hacker News…"
                                if (root.service.error) return root.service.error
                                return "No stories yet"
                            }
                            color: root.bar ? Qt.darker(root.bar.foreground, 1.5) : "#9399b2"
                            font.family: root.bar ? root.bar.fontFamily : "monospace"
                            font.pixelSize: Style.font.bodySmall
                        }
                    }
                }

                PanelSeparator { Layout.fillWidth: true }

                // Footer: updated age + hint
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(28)

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Style.space(10)
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.service && root.service.hasStories
                            ? "Updated " + root.service.ageLabel + " · " + root.service.stories.length + " stories"
                            : ""
                        color: root.bar ? Qt.darker(root.bar.foreground, 1.4) : "#a6adc8"
                        font.family: root.bar ? root.bar.fontFamily : "monospace"
                        font.pixelSize: Style.font.caption
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: Style.space(10)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "click: article · shift+click: thread"
                        color: root.bar ? Qt.darker(root.bar.foreground, 1.4) : "#a6adc8"
                        font.family: root.bar ? root.bar.fontFamily : "monospace"
                        font.pixelSize: Style.font.caption
                    }
                }
            }
        }
    }

    component StoryRow: Item {
        id: row

        property var story: null
        signal openRequested(var story, bool forceThread)

        width: parent.width
        height: Style.space(64)

        Rectangle {
            id: hoverBg
            anchors.fill: parent
            radius: Style.space(6)
            color: hoverArea.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
        }

        Column {
            id: textCol
            anchors.fill: parent
            anchors.leftMargin: Style.space(12)
            anchors.rightMargin: Style.space(12)
            anchors.topMargin: Style.space(8)
            anchors.bottomMargin: Style.space(8)
            spacing: Style.space(2)

            Text {
                width: parent.width
                clip: true
                maximumLineCount: 2
                elide: Text.ElideRight
                wrapMode: Text.Wrap
                text: row.story && row.story.title ? row.story.title : ""
                color: root.bar ? root.bar.foreground : "white"
                font.family: root.bar ? root.bar.fontFamily : "monospace"
                font.pixelSize: Style.font.bodySmall
            }

            Text {
                width: parent.width
                text: {
                    var s = row.story
                    if (!s) return ""
                    var parts = []
                    if (s.score > 0) parts.push("▲ " + s.score)
                    if (s.by) parts.push(s.by)
                    if (s.comments > 0) parts.push(s.comments + " comments")
                    var age = Model.relativeTime(s.time)
                    if (age) parts.push(age)
                    return parts.join(" · ")
                }
                color: root.bar ? Qt.darker(root.bar.foreground, 1.4) : "#a6adc8"
                font.family: root.bar ? root.bar.fontFamily : "monospace"
                font.pixelSize: Style.font.caption
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            hoverEnabled: true

            onClicked: function(mouse) {
                if (!row.story) return
                if (mouse.button === Qt.MiddleButton) {
                    row.openRequested(row.story, true)
                } else if (mouse.button === Qt.LeftButton) {
                    row.openRequested(row.story, (mouse.modifiers & Qt.ShiftModifier) !== 0)
                }
            }
        }
    }
}