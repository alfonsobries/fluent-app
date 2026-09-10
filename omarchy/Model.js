.pragma library

// Pure helpers for the Fluent Omarchy panel. Qt-free so node can unit-test it.

var DEFAULT_CHORD = "CTRL + ALT + SHIFT"

var PROVIDERS = [
  { id: "openai", label: "OpenAI" },
  { id: "claude", label: "Claude" },
  { id: "gemini", label: "Gemini" },
  { id: "grok", label: "Grok" }
]

var READY_PHRASES = [
  "Rewriting in place",
  "Keeping your voice",
  "One shortcut, done",
  "Staying out of the way",
  "Talking to your key"
]

function providerLabel(id) {
  for (var i = 0; i < PROVIDERS.length; i++) {
    if (PROVIDERS[i].id === id) return PROVIDERS[i].label
  }
  return "OpenAI"
}

function enabledActions(actions) {
  var list = Array.isArray(actions) ? actions : []
  var out = []
  for (var i = 0; i < list.length; i++) {
    if (list[i] && list[i].enabled !== false) out.push(list[i])
  }
  return out
}

// QML treats `.id` as reserved on objects, so the panel must never read
// `action.id`. This helper runs in real JS where the JSON field is visible.
function actionId(action) {
  if (!action) return ""
  if (action.actionId) return String(action.actionId)
  if (action.id) return String(action.id)
  return ""
}

function actionById(actions, id) {
  var needle = String(id || "")
  if (!needle) return null
  var list = Array.isArray(actions) ? actions : []
  for (var i = 0; i < list.length; i++) {
    if (actionId(list[i]) === needle) return list[i]
  }
  return null
}

function actionIndexById(actions, id) {
  var needle = String(id || "")
  var list = Array.isArray(actions) ? actions : []
  for (var i = 0; i < list.length; i++) {
    if (actionId(list[i]) === needle) return i
  }
  return -1
}

function actionByKey(actions, key) {
  var letter = String(key || "").toUpperCase()
  var list = enabledActions(actions)
  for (var i = 0; i < list.length; i++) {
    if (String(list[i].key || "").toUpperCase() === letter) return list[i]
  }
  return null
}

function formatHotkey(chord, key) {
  var letter = String(key || "").trim().toUpperCase()
  if (!letter) return ""
  var parts = String(chord || DEFAULT_CHORD).trim()
  return parts + " + " + letter
}

function clampIndex(index, length) {
  if (!(length > 0)) return -1
  if (index < 0) return 0
  if (index > length - 1) return length - 1
  return index
}

function wrapIndex(index, length, delta) {
  if (!(length > 0)) return -1
  var next = index + delta
  if (next < 0) return length - 1
  if (next > length - 1) return 0
  return next
}

function plain(value, maxLen) {
  var limit = maxLen || 240
  var text = String(value || "")
  var out = ""
  for (var i = 0; i < text.length && out.length < limit; i++) {
    var ch = text.charAt(i)
    var code = text.charCodeAt(i)
    if (ch === "<" || ch === ">" || ch === "&") continue
    if (code < 32 || (code >= 127 && code < 160)) continue
    if (code === 0x202A || code === 0x202B || code === 0x202C || code === 0x202D || code === 0x202E) continue
    if (code === 0x2066 || code === 0x2067 || code === 0x2068 || code === 0x2069) continue
    out += ch
  }
  return out
}

function promptPreview(prompt, maxLen) {
  var limit = maxLen || 56
  var text = String(prompt || "").replace(/\s+/g, " ").trim()
  if (!text) return "No prompt yet"
  if (text.length <= limit) return text
  return text.slice(0, limit - 1) + "…"
}

function processingLabel(actionName) {
  var name = String(actionName || "").toLowerCase()
  if (name === "translate") return "Translating"
  if (name === "improve writing") return "Improving"
  if (name === "fix grammar") return "Fixing grammar"
  if (name === "summarize") return "Summarizing"
  if (name === "make professional") return "Rewriting"
  if (name) return name.charAt(0).toUpperCase() + name.slice(1)
  return "Working"
}

function heroTitle(snapshot) {
  if (!snapshot) return "Fluent"
  return "Fluent"
}

function heroMeta(snapshot, state, phrase, errorMessage) {
  if (state === "processing") {
    var name = snapshot && snapshot.runningName ? snapshot.runningName : "selection"
    return "Rewriting " + String(name).toLowerCase()
  }
  if (state === "failed") return String(errorMessage || "Something went wrong")
  if (state === "completed") return "Pasted in place"
  if (!snapshot || !snapshot.hasCurrentKey) return "Add an API key to start"
  if (snapshot.binds && snapshot.binds.installed === false) return "Shortcuts not installed"
  return phrase || READY_PHRASES[0]
}

function heroDetail(snapshot) {
  if (!snapshot) return ""
  var id = snapshot.provider || "openai"
  for (var i = 0; i < (snapshot.providers || []).length; i++) {
    if (snapshot.providers[i].id === id) return snapshot.providers[i].displayName || snapshot.providers[i].id
  }
  return providerLabel(id)
}

function parseDump(raw) {
  if (!raw) return null
  if (String(raw).length > 65536) return null
  try {
    var parsed = JSON.parse(raw)
    if (!parsed || typeof parsed !== "object") return null
    if (Array.isArray(parsed.actions) && parsed.actions.length > 64) return null
    if (Array.isArray(parsed.providers) && parsed.providers.length > 16) return null
    return parsed
  } catch (e) {
    return null
  }
}

function parseRunResult(raw) {
  var parsed = parseDump(raw)
  if (!parsed) return { ok: false, error: "invalid_response", message: "Invalid response from Fluent." }
  return parsed
}

function emptySnapshot() {
  return {
    provider: "openai",
    providers: [],
    actions: [],
    hotkeyChord: DEFAULT_CHORD,
    panelKey: "F",
    hasCurrentKey: false,
    binds: { installed: false, collisions: [] }
  }
}
