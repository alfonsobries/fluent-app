import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.alfonsobries.fluent"
  ipcTarget: "io.github.alfonsobries.fluent"
  manageIpc: false

  property var snapshot: Model.emptySnapshot()
  property string runState: "idle"
  property string errorMessage: ""
  property string runningName: ""
  property string runningId: ""
  property string focusSection: "actions"
  property int actionIndex: 0
  property int providerIndex: 0
  property bool cursorActive: false
  property bool editing: false
  property bool adding: false
  property string editId: ""
  property string editName: ""
  property string editKey: ""
  property string editPrompt: ""
  property bool editEnabled: true
  property bool confirmRemove: false
  property string keyDraft: ""
  property int phraseIndex: 0
  property bool mutating: false
  property string _runStdout: ""
  property string _runStderr: ""

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var actions: snapshot && snapshot.actions ? snapshot.actions : []
  readonly property var enabledActions: Model.enabledActions(actions)
  readonly property var providers: snapshot && snapshot.providers ? snapshot.providers : []
  readonly property bool hasKey: snapshot && snapshot.hasCurrentKey === true
  readonly property bool bindsInstalled: snapshot && snapshot.binds && snapshot.binds.installed === true
  readonly property bool busy: runState === "processing" || mutating || runProc.running || mutateProc.running
  readonly property string pluginDir: pluginDirectory()
  readonly property string pythonBin: "python3"
  readonly property string scriptPath: pluginDir + "/bin/fluent.py"
  readonly property string heroPhrase: Model.READY_PHRASES[phraseIndex % Model.READY_PHRASES.length]
  readonly property string currentProviderId: snapshot && snapshot.provider ? snapshot.provider : "openai"
  readonly property var providerOptions: {
    var out = []
    for (var i = 0; i < providers.length; i++)
      out.push({ value: providers[i].id, label: providerShort(providers[i]) })
    if (out.length === 0) {
      out = [
        { value: "openai", label: "OpenAI" },
        { value: "claude", label: "Claude" },
        { value: "gemini", label: "Gemini" },
        { value: "grok", label: "Grok" }
      ]
    }
    return out
  }
  readonly property color barIconColor: {
    if (runState === "failed") return urgent
    if (!hasKey) return dim
    return barForeground
  }

  function pluginDirectory() {
    var url = Qt.resolvedUrl(".").toString()
    if (url.indexOf("file://") === 0) url = url.substring(7)
    if (url.indexOf("localhost/") === 0) url = url.substring(9)
    if (url.length > 1 && url.charAt(url.length - 1) === "/")
      url = url.substring(0, url.length - 1)
    return url
  }

  function providerShort(provider) {
    if (!provider) return ""
    var name = String(provider.displayName || provider.id || "")
    if (name.indexOf("OpenAI") === 0) return "OpenAI"
    if (name.indexOf("Anthropic") === 0) return "Claude"
    if (name.indexOf("Google") === 0) return "Gemini"
    if (name.indexOf("xAI") === 0) return "Grok"
    return name
  }

  function currentKeyHint() {
    for (var i = 0; i < providers.length; i++) {
      if (providers[i].id === currentProviderId) return providers[i].keyHint || ""
    }
    return ""
  }

  function applySnapshot(raw) {
    var parsed = Model.parseDump(raw)
    if (!parsed) return
    snapshot = parsed
    if (actionIndex >= actions.length) actionIndex = Math.max(0, actions.length - 1)
    for (var i = 0; i < providers.length; i++) {
      if (providers[i].id === currentProviderId) {
        providerIndex = i
        break
      }
    }
    if (!hasKey) focusSection = "key"
    else if (!editing && focusSection === "key" && actions.length > 0) focusSection = "actions"
  }

  function refresh() {
    if (configProc.running) return
    configProc.command = [pythonBin, scriptPath, "config", "dump"]
    configProc.running = true
  }

  function mutate(args) {
    if (mutateProc.running) return
    mutating = true
    var command = [pythonBin, scriptPath]
    for (var i = 0; i < args.length; i++) command.push(args[i])
    mutateProc.command = command
    mutateProc.running = true
  }

  function runAction(actionId) {
    if (runProc.running) return
    var action = Model.actionById(actions, actionId)
    if (!action) {
      errorMessage = "Unknown action."
      runState = "failed"
      return
    }
    if (!hasKey) {
      errorMessage = "Configure an API key for " + Model.heroDetail(snapshot) + "."
      runState = "failed"
      focusSection = "key"
      if (!opened) open()
      return
    }
    runningId = action.id
    runningName = action.name
    errorMessage = ""
    _runStdout = ""
    _runStderr = ""
    runState = "processing"
    runProc.command = [pythonBin, scriptPath, "run", "--action", action.id]
    runProc.running = true
  }

  function runSelected() {
    if (actions.length === 0) return
    var action = actions[Math.max(0, Math.min(actionIndex, actions.length - 1))]
    if (action) runAction(action.id)
  }

  function setProvider(id) {
    mutate(["config", "set", "--provider", id])
  }

  function saveKey() {
    var value = String(keyField.text || keyDraft || "").trim()
    if (!value) return
    mutate(["config", "set-key", "--provider", currentProviderId, "--key", value])
    keyField.text = ""
    keyDraft = ""
  }

  function installBinds() {
    mutate(["binds", "install"])
  }

  function removeBinds() {
    mutate(["binds", "remove"])
  }

  function startAdd() {
    adding = true
    editing = true
    confirmRemove = false
    editId = "custom-" + Date.now()
    editName = "New action"
    editKey = ""
    editPrompt = ""
    editEnabled = true
    focusSection = "edit"
    Qt.callLater(function() { nameField.forceActiveFocus(); nameField.selectAll() })
  }

  function startEdit() {
    if (actions.length === 0) return
    var action = actions[Math.max(0, Math.min(actionIndex, actions.length - 1))]
    if (!action) return
    adding = false
    editing = true
    confirmRemove = false
    editId = action.id
    editName = action.name
    editKey = action.key || ""
    editPrompt = action.prompt || ""
    editEnabled = action.enabled !== false
    focusSection = "edit"
    Qt.callLater(function() { nameField.forceActiveFocus(); nameField.selectAll() })
  }

  function cancelEdit() {
    editing = false
    adding = false
    confirmRemove = false
    focusSection = "actions"
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
  }

  function saveEdit() {
    var args = [
      "config", "set-action",
      "--id", editId,
      "--name", editName,
      "--key", editKey,
      "--prompt", editPrompt
    ]
    if (editEnabled) args.push("--enabled")
    else args.push("--disabled")
    mutate(args)
    cancelEdit()
  }

  function removeEdit() {
    if (!confirmRemove) {
      confirmRemove = true
      return
    }
    mutate(["config", "delete-action", "--id", editId])
    cancelEdit()
  }

  function ensureCursor() {
    if (editing) {
      focusSection = "edit"
      return
    }
    if (!hasKey) {
      focusSection = "key"
      return
    }
    if (focusSection === "actions" && actions.length === 0) focusSection = "providers"
    if (actionIndex >= actions.length) actionIndex = Math.max(0, actions.length - 1)
    if (providerIndex >= providerOptions.length) providerIndex = Math.max(0, providerOptions.length - 1)
  }

  function moveCursor(dx, dy) {
    cursorActive = true
    ensureCursor()
    if (editing) return
    if (focusSection === "providers" && dx !== 0) {
      providerIndex = Model.wrapIndex(providerIndex, providerOptions.length, dx)
      return
    }
    if (dy === 0) return
    var order = sectionOrder()
    var at = order.indexOf(focusSection)
    if (at < 0) at = 0
    if (focusSection === "actions" && actions.length > 0) {
      var next = actionIndex + dy
      if (next >= 0 && next < actions.length) {
        actionIndex = next
        scrollCursorIntoView()
        return
      }
    }
    var nextSection = order[Math.max(0, Math.min(order.length - 1, at + dy))]
    focusSection = nextSection
    if (focusSection === "actions" && dy < 0) actionIndex = Math.max(0, actions.length - 1)
    if (focusSection === "actions" && dy > 0) actionIndex = 0
    scrollCursorIntoView()
  }

  function sectionOrder() {
    var order = []
    if (actions.length > 0) order.push("actions")
    order.push("providers")
    order.push("key")
    order.push("binds")
    return order
  }

  function activateCursor() {
    ensureCursor()
    if (focusSection === "actions") runSelected()
    else if (focusSection === "providers") {
      if (providerOptions.length > 0) setProvider(providerOptions[providerIndex].value)
    } else if (focusSection === "key") {
      keyField.forceActiveFocus()
    } else if (focusSection === "binds") {
      if (bindsInstalled) removeBinds()
      else installBinds()
    }
  }

  function setActionCursor(index) {
    cursorActive = true
    editing = false
    focusSection = "actions"
    actionIndex = index
    scrollCursorIntoView()
  }

  function scrollItemIntoView(item) {
    if (!panelFlick || !item) return
    Qt.callLater(function() {
      if (!item) return
      var margin = Style.space(6)
      var point = item.mapToItem(panelFlick.contentItem, 0, 0)
      var top = point.y
      var bottom = top + item.height
      var viewTop = panelFlick.contentY
      var viewBottom = viewTop + panelFlick.height
      var maxY = Math.max(0, panelFlick.contentHeight - panelFlick.height)
      if (top < viewTop + margin) panelFlick.contentY = Math.max(0, top - margin)
      else if (bottom > viewBottom - margin) panelFlick.contentY = Math.min(maxY, bottom + margin - panelFlick.height)
    })
  }

  function scrollCursorIntoView() {
    if (focusSection === "actions" && actionColumn && actionIndex >= 0 && actionIndex < actionColumn.children.length)
      scrollItemIntoView(actionColumn.children[actionIndex])
  }

  function handleTextKey(t) {
    if (editing) return
    if (t === "n" || t === "N") { startAdd(); return }
    if (t === "e" || t === "E") { startEdit(); return }
    if (t === "k" || t === "K") {
      focusSection = "key"
      keyField.forceActiveFocus()
      return
    }
    if (t === "i" || t === "I") { installBinds(); return }
    var action = Model.actionByKey(actions, t)
    if (action) runAction(action.id)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    cursorActive = false
    confirmRemove = false
    if (panelFlick) panelFlick.contentY = 0
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Component.onCompleted: refresh()

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(); return "ok" }
    function run(action: string): void { root.runAction(action) }
    function status(): string { return root.runState }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: root.hasKey ? "Fluent" : "Fluent — add an API key"
    active: root.runState === "failed"
    iconComponent: Component {
      Item {
        FluentIcon {
          anchors.centerIn: parent
          iconSize: Style.space(12)
          color: root.barIconColor
          busy: root.runState === "processing"
          dimmed: !root.hasKey && root.runState !== "processing"
        }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.editing || keyField.activeFocus
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.moveCursor(dx, dy)
      }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) { root.handleTextKey(t) }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            id: hero
            width: parent.width
            title: "Fluent"
            detail: Model.heroDetail(root.snapshot)
            meta: Model.heroMeta({
              hasCurrentKey: root.hasKey,
              binds: root.snapshot.binds,
              runningName: root.runningName,
              provider: root.currentProviderId,
              providers: root.providers
            }, root.runState, root.heroPhrase, root.errorMessage)
            foreground: root.runState === "failed" ? root.urgent : root.foreground
            fontFamily: root.fontFamily
            iconOpacity: root.hasKey ? 1.0 : 0.55
            iconComponent: Component {
              FluentIcon {
                iconSize: Style.font.display
                color: root.runState === "failed" ? root.urgent : root.foreground
                busy: root.runState === "processing"
                dimmed: !root.hasKey
              }
            }
          }

          Text {
            visible: root.runState === "failed" && root.errorMessage !== ""
            width: parent.width
            text: root.errorMessage
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Column {
            visible: root.editing
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: root.adding ? "NEW ACTION" : "EDIT ACTION"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            TextField {
              id: nameField
              width: parent.width
              placeholderText: "Name"
              text: root.editName
              foreground: root.foreground
              font.family: root.fontFamily
              onTextChanged: root.editName = text
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) { root.cancelEdit(); event.accepted = true }
              }
            }

            TextField {
              id: keyLetterField
              width: Style.space(70)
              placeholderText: "Key"
              text: root.editKey
              foreground: root.foreground
              font.family: root.fontFamily
              onTextChanged: {
                var letter = text.toUpperCase().replace(/[^A-Z]/g, "")
                if (letter.length > 1) letter = letter.charAt(0)
                if (letter !== text) text = letter
                root.editKey = letter
              }
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) { root.cancelEdit(); event.accepted = true }
              }
            }

            Text {
              width: parent.width
              visible: root.editKey !== ""
              text: Model.formatHotkey(root.snapshot.hotkeyChord || "CTRL + ALT + SHIFT", root.editKey)
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            TextField {
              id: promptField
              width: parent.width
              placeholderText: "Prompt"
              text: root.editPrompt
              foreground: root.foreground
              font.family: root.fontFamily
              onTextChanged: root.editPrompt = text
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) { root.cancelEdit(); event.accepted = true }
                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier)) {
                  root.saveEdit()
                  event.accepted = true
                }
              }
            }

            Toggle {
              width: parent.width
              label: "Enabled"
              checked: root.editEnabled
              foreground: root.foreground
              onClicked: root.editEnabled = !root.editEnabled
            }

            Row {
              spacing: Style.space(8)

              Button {
                text: "Save"
                foreground: root.foreground
                onClicked: root.saveEdit()
              }

              Button {
                text: "Cancel"
                foreground: root.foreground
                bordered: true
                onClicked: root.cancelEdit()
              }

              Button {
                visible: !root.adding
                text: root.confirmRemove ? "Confirm remove" : "Remove"
                foreground: root.urgent
                onClicked: root.removeEdit()
              }
            }
          }

          Column {
            visible: !root.editing
            width: parent.width
            spacing: Style.space(10)

            Row {
              width: parent.width
              PanelSectionHeader {
                text: "ACTIONS"
                foreground: root.foreground
                fontFamily: root.fontFamily
                width: parent.width - addButton.implicitWidth
              }
              PanelActionButton {
                id: addButton
                iconText: "󰐕"
                tooltipText: "New action"
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.startAdd()
              }
            }

            Text {
              visible: root.actions.length === 0
              width: parent.width
              text: "No actions yet."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
            }

            Column {
              id: actionColumn
              visible: root.actions.length > 0
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: root.actions
                ActionRow {
                  required property var modelData
                  required property int index
                  width: actionColumn.width
                  action: modelData
                  rowIndex: index
                }
              }
            }
          }

          PanelSeparator {
            visible: !root.editing
            foreground: root.foreground
          }

          Column {
            visible: !root.editing
            width: parent.width
            spacing: Style.spacing.labelGap

            PanelSectionHeader {
              text: "PROVIDER"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            ButtonGroup {
              id: providerGroup
              width: parent.width
              options: root.providerOptions
              value: root.currentProviderId
              foreground: root.foreground
              fontFamily: root.fontFamily
              cursorIndex: root.cursorActive && root.focusSection === "providers" ? root.providerIndex : -1
              onChanged: function(value) { root.setProvider(value) }
              onHovered: function(index, isHovered) {
                if (!isHovered) return
                root.cursorActive = true
                root.focusSection = "providers"
                root.providerIndex = index
              }
            }
          }

          Column {
            visible: !root.editing
            width: parent.width
            spacing: Style.spacing.labelGap

            PanelSectionHeader {
              text: "API KEY"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              visible: root.currentKeyHint() !== ""
              width: parent.width
              text: "Saved " + root.currentKeyHint()
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              TextField {
                id: keyField
                width: parent.width - saveKeyButton.implicitWidth - parent.spacing
                password: true
                placeholderText: root.hasKey ? "Replace key" : "Paste API key"
                foreground: root.foreground
                font.family: root.fontFamily
                hasCursor: root.cursorActive && root.focusSection === "key" && !activeFocus
                onTextChanged: root.keyDraft = text
                onAccepted: root.saveKey()
                Keys.onPressed: function(event) {
                  if (event.key === Qt.Key_Escape) {
                    keyField.focus = false
                    if (keyCatcher) keyCatcher.forceActiveFocus()
                    event.accepted = true
                  }
                }
                onHoveredChanged: {
                  if (hovered) {
                    root.cursorActive = true
                    root.focusSection = "key"
                  }
                }
              }

              Button {
                id: saveKeyButton
                text: "Save"
                foreground: root.foreground
                opacity: String(keyField.text || "").trim() !== "" ? 1 : 0.45
                onClicked: root.saveKey()
              }
            }
          }

          Column {
            visible: !root.editing
            width: parent.width
            spacing: Style.spacing.labelGap

            PanelSectionHeader {
              text: "SHORTCUTS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            CursorSurface {
              id: bindsRow
              width: parent.width
              hasCursor: root.cursorActive && root.focusSection === "binds"
              foreground: root.foreground
              implicitHeight: bindsLabel.implicitHeight + Style.spacing.rowPaddingX * 2

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                  root.cursorActive = true
                  root.focusSection = "binds"
                }
                onClicked: root.bindsInstalled ? root.removeBinds() : root.installBinds()
              }

              Column {
                id: bindsLabel
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                spacing: Style.space(2)

                Text {
                  width: parent.width
                  text: root.bindsInstalled ? "Remove Ctrl+Alt+Shift shortcuts" : "Install Ctrl+Alt+Shift shortcuts"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  wrapMode: Text.WordWrap
                }

                Text {
                  width: parent.width
                  text: "T translate · O improve · G grammar · S summarize · P professional · F this panel"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WordWrap
                }
              }
            }
          }
        }
      }
    }
  }

  Timer {
    interval: 2800
    running: root.opened && root.runState === "idle" && root.hasKey
    repeat: true
    onTriggered: root.phraseIndex = (root.phraseIndex + 1) % Model.READY_PHRASES.length
  }

  Timer {
    id: completedReset
    interval: 1800
    repeat: false
    onTriggered: if (root.runState === "completed") root.runState = "idle"
  }

  Process {
    id: configProc
    stdout: StdioCollector { id: configOut; waitForEnd: true }
    stderr: StdioCollector { id: configErr; waitForEnd: true }
    onExited: function(code) {
      var text = String(configOut.text || "")
      if (code === 0) root.applySnapshot(text)
    }
  }

  Process {
    id: mutateProc
    stdout: StdioCollector { id: mutateOut; waitForEnd: true }
    stderr: StdioCollector { id: mutateErr; waitForEnd: true }
    onExited: function(code) {
      root.mutating = false
      var text = String(mutateOut.text || "")
      var parsed = Model.parseDump(text)
      if (parsed && parsed.ok === false) {
        root.errorMessage = parsed.message || "Could not save settings."
        root.runState = "failed"
        return
      }
      if (code === 0 && parsed) {
        root.applySnapshot(text)
        if (root.runState === "failed" && root.hasKey) {
          root.runState = "idle"
          root.errorMessage = ""
        }
      } else {
        root.refresh()
      }
    }
  }

  Process {
    id: runProc
    stdout: StdioCollector {
      id: runOut
      waitForEnd: true
      onStreamFinished: root._runStdout = text
    }
    stderr: StdioCollector {
      id: runErr
      waitForEnd: true
      onStreamFinished: root._runStderr = text
    }
    onExited: function(code) {
      var text = String(runOut.text || root._runStdout || "")
      var err = String(runErr.text || root._runStderr || "")
      var parsed = Model.parseRunResult(text)
      if (parsed && parsed.ok) {
        root.runState = "completed"
        root.errorMessage = ""
        completedReset.restart()
      } else {
        root.runState = "failed"
        var message = parsed && parsed.message ? parsed.message : ""
        if (!message) {
          var line = err.replace(/^\s+|\s+$/g, "").split("\n").pop()
          message = line || "Could not rewrite the selection."
        }
        root.errorMessage = message
      }
    }
  }

  component ActionRow: CursorSurface {
    id: actionRow
    property var action: null
    property int rowIndex: 0
    readonly property bool on: action && action.enabled !== false

    hasCursor: root.cursorActive && root.focusSection === "actions" && root.actionIndex === rowIndex && !root.editing
    foreground: root.foreground
    implicitHeight: actionContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: actionRow.on && !root.busy ? Qt.PointingHandCursor : Qt.ArrowCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onEntered: root.setActionCursor(actionRow.rowIndex)
      onClicked: function(mouse) {
        root.setActionCursor(actionRow.rowIndex)
        if (mouse.button === Qt.RightButton) root.startEdit()
        else if (actionRow.on) root.runAction(actionRow.action.id)
      }
    }

    RowLayout {
      id: actionContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: actionRow.action ? actionRow.action.name : ""
          color: actionRow.on ? root.foreground : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          visible: actionRow.action && actionRow.action.key
          text: Model.formatHotkey(root.snapshot.hotkeyChord || "CTRL + ALT + SHIFT", actionRow.action ? actionRow.action.key : "")
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      Text {
        visible: actionRow.action && actionRow.action.key
        text: actionRow.action ? String(actionRow.action.key) : ""
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
        Layout.alignment: Qt.AlignVCenter
      }
    }
  }
}
