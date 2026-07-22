pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int defaultDebounceMs: 50
    property int commandTimeoutMs: 4000
    property var _procDebouncers: ({})

    function runCommand(id, command, callback, debounceMs) {
        const wait = (typeof debounceMs === "number" && debounceMs >= 0) ? debounceMs : defaultDebounceMs
        let procId = id ? id : Math.random()

        if (!_procDebouncers[procId]) {
            const t = Qt.createQmlObject('import QtQuick; Timer { repeat: false }', root)
            t.triggered.connect(function() { _launchProc(procId) })
            _procDebouncers[procId] = { timer: t, command: command, callback: callback, waitMs: wait, running: false, pending: false }
        } else {
            _procDebouncers[procId].command = command
            _procDebouncers[procId].callback = callback
            _procDebouncers[procId].waitMs = wait
        }

        const entry = _procDebouncers[procId]
        entry.timer.interval = entry.waitMs
        entry.timer.restart()
    }

    function _launchProc(id) {
        const entry = _procDebouncers[id]
        if (!entry) return
        if (entry.running) {
            entry.pending = true
            return
        }

        entry.running = true

        const proc = Qt.createQmlObject('import Quickshell.Io; Process { running: false }', root)
        const out = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', proc)
        const err = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', proc)
        const timeout = Qt.createQmlObject('import QtQuick; Timer { repeat: false }', proc)

        proc.stdout = out
        proc.stderr = err
        proc.command = entry.command

        let capturedOut = ""
        let completed = false

        out.streamFinished.connect(function() {
            capturedOut = out.text || ""
        })

        proc.exited.connect(function(code) {
            capturedOut = out.text || capturedOut || ""
            complete(code)
        })

        timeout.interval = root.commandTimeoutMs
        timeout.triggered.connect(function() {
            try { proc.running = false } catch (_) {}
            complete(-1)
        })

        function complete(exitCodeValue) {
            if (completed) return
            completed = true
            timeout.stop()
            entry.running = false
            if (typeof entry.callback === "function") {
                try { entry.callback(capturedOut, exitCodeValue) } catch (e) { console.warn("runCommand callback error:", e) }
            }
            try { proc.destroy() } catch (_) {}

            if (entry.pending) {
                entry.pending = false
                entry.timer.interval = entry.waitMs
                entry.timer.restart()
            }
        }

        proc.running = true
        timeout.start()
    }
}
