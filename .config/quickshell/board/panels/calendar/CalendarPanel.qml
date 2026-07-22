import QtQuick
import Quickshell
import "../../board"

Rectangle {
    id: root
    
    readonly property real scaledFontSize: Math.min(width, height) * 0.04
    readonly property real scaledSpacing: Math.min(width, height) * 0.02

    property bool showEventDetails: false
    property date selectedDate: systemClock.date
    property var selectedDateEvents: []
    property bool hasEvents: selectedDateEvents && selectedDateEvents.length > 0

    function weekStartJs() {
        return Qt.locale().firstDayOfWeek % 7
    }

    function startOfWeek(dateObj) {
        const d = new Date(dateObj)
        const jsDow = d.getDay()
        const diff = (jsDow - weekStartJs() + 7) % 7
        d.setDate(d.getDate() - diff)
        return d
    }

    function endOfWeek(dateObj) {
        const d = new Date(dateObj)
        const jsDow = d.getDay()
        const add = (weekStartJs() + 6 - jsDow + 7) % 7
        d.setDate(d.getDate() + add)
        return d
    }

    function updateSelectedDateEvents() {
        if (CalendarService && CalendarService.khalAvailable) {
            const events = CalendarService.getEventsForDate(selectedDate)
            selectedDateEvents = events
        } else {
            selectedDateEvents = []
        }
    }

    function loadEventsForMonth() {
        if (!CalendarService || !CalendarService.khalAvailable) {
            return
        }

        const firstOfMonth = new Date(calendarGrid.displayDate.getFullYear(),
                                      calendarGrid.displayDate.getMonth(), 1)
        const lastOfMonth  = new Date(calendarGrid.displayDate.getFullYear(),
                                      calendarGrid.displayDate.getMonth() + 1, 0)

        const startDate = startOfWeek(firstOfMonth)
        startDate.setDate(startDate.getDate() - 7)

        const endDate = endOfWeek(lastOfMonth)
        endDate.setDate(endDate.getDate() + 7)

        CalendarService.loadEvents(startDate, endDate)
    }

    function dayHasEvents(dayDate) {
        return Boolean(CalendarService && CalendarService.khalAvailable && CalendarService.hasEventsForDate(dayDate))
    }

    onSelectedDateChanged: updateSelectedDateEvents()
    Component.onCompleted: {
        loadEventsForMonth()
        updateSelectedDateEvents()
    }

    Connections {
        function onEventsByDateChanged() {
            updateSelectedDateEvents()
        }

        function onKhalAvailableChanged() {
            if (CalendarService && CalendarService.khalAvailable) {
                loadEventsForMonth()
            }
            updateSelectedDateEvents()
        }

        target: CalendarService
        enabled: CalendarService !== null
    }

    radius: Theme.cornerRadius
    color: Theme.color236
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: Theme.borderWidth

    Column {
        anchors.fill: parent
        anchors.margins: scaledSpacing * 2
        spacing: scaledSpacing * 2
        
        Row {
            width: parent.width
            height: scaledFontSize * 2
            visible: !showEventDetails
            
            Rectangle {
                width: scaledFontSize * 2
                height: scaledFontSize * 2
                radius: Theme.cornerRadius
                color: prevMonthArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "<"
                    font.family: "IosevkaTerm Nerd Font Mono"
                    font.pixelSize: scaledFontSize
                    color: Theme.primary
                }

                MouseArea {
                    id: prevMonthArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        let newDate = new Date(calendarGrid.displayDate)
                        newDate.setMonth(newDate.getMonth() - 1)
                        calendarGrid.displayDate = newDate
                        loadEventsForMonth()
                    }
                }
            }

            StyledText {
                width: parent.width - scaledFontSize * 4
                height: scaledFontSize * 2
                text: calendarGrid.displayDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                font.pixelSize: scaledFontSize * 1.3
                color: Theme.surfaceText
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            Rectangle {
                width: scaledFontSize * 2
                height: scaledFontSize * 2
                radius: Theme.cornerRadius
                color: nextMonthArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: ">"
                    font.family: "IosevkaTerm Nerd Font Mono"
                    font.pixelSize: scaledFontSize
                    color: Theme.primary
                }

                MouseArea {
                    id: nextMonthArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        let newDate = new Date(calendarGrid.displayDate)
                        newDate.setMonth(newDate.getMonth() + 1)
                        calendarGrid.displayDate = newDate
                        loadEventsForMonth()
                    }
                }
            }
        }
        
        Row {
            width: parent.width
            height: scaledFontSize * 1.5
            visible: !showEventDetails

            Repeater {
                model: {
                    const days = []
                    const loc = Qt.locale()
                    const qtFirst = loc.firstDayOfWeek
                    for (let i = 0; i < 7; ++i) {
                        const qtDay = ((qtFirst - 1 + i) % 7) + 1
                        days.push(loc.dayName(qtDay, Locale.ShortFormat))
                    }
                    return days
                }

                Rectangle {
                    width: parent.width / 7
                    height: scaledFontSize * 1.5
                    color: "transparent"

                    StyledText {
                        anchors.centerIn: parent
                        text: modelData
                        font.pixelSize: scaledFontSize
                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                        font.weight: Font.Medium
                    }
                }
            }
        }
        
        Grid {
            id: calendarGrid
            visible: !showEventDetails
            
            property date displayDate: systemClock.date
            property date selectedDate: systemClock.date
            
            readonly property date firstDay: {
                const firstOfMonth = new Date(displayDate.getFullYear(), displayDate.getMonth(), 1)
                return startOfWeek(firstOfMonth)
            }

            width: parent.width
            height: parent.height - scaledFontSize * 2 - scaledFontSize * 1.5 - scaledSpacing * 4
            columns: 7
            rows: 5

            Repeater {
                model: 35

                Rectangle {
                    readonly property date dayDate: {
                        const date = new Date(parent.firstDay)
                        date.setDate(date.getDate() + index)
                        return date
                    }
                    readonly property bool isCurrentMonth: dayDate.getMonth() === calendarGrid.displayDate.getMonth()
                    readonly property bool isToday: dayDate.toDateString() === new Date().toDateString()
                    readonly property bool isSelected: dayDate.toDateString() === calendarGrid.selectedDate.toDateString()

                    width: parent.width / 7
                    height: parent.height / 5
                    color: "transparent"

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 4, parent.height - 4)
                        height: width
                        color: isToday ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : dayArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                        radius: width / 2

                        StyledText {
                            anchors.centerIn: parent
                            text: dayDate.getDate()
                            font.pixelSize: scaledFontSize
                            color: isToday ? Theme.primary : isCurrentMonth ? Theme.surfaceText : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.4)
                            font.weight: isToday ? Font.Medium : Font.Normal
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottomMargin: scaledFontSize * (4 / 14)
                            width: scaledFontSize * 0.8
                            height: scaledFontSize * 0.14
                            radius: height * 0.5
                            visible: root.dayHasEvents(dayDate)
                            color: isToday ? Qt.lighter(Theme.primary, 1.3) : Theme.primary
                            opacity: isToday ? 0.9 : 0.7
                        }
                    }

                    MouseArea {
                        id: dayArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.dayHasEvents(dayDate)) {
                                root.selectedDate = dayDate
                                root.showEventDetails = true
                            }
                        }
                    }
                }
            }
        }
    }

    SystemClock {
        id: systemClock
        precision: SystemClock.Hours
    }
}
