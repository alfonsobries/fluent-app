const fs = require("fs")
const path = require("path")
const vm = require("vm")
const assert = require("assert")

const source = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8")
const context = { console }
vm.createContext(context)
vm.runInContext(source.replace(".pragma library", ""), context)

const M = context

assert.strictEqual(M.providerLabel("claude"), "Claude")
assert.strictEqual(M.providerLabel("nope"), "OpenAI")

const actions = [
  { id: "translate", key: "T", enabled: true },
  { id: "improve", key: "O", enabled: false },
  { id: "grammar", key: "G", enabled: true }
]
assert.strictEqual(JSON.stringify(M.enabledActions(actions).map((a) => a.id)), JSON.stringify(["translate", "grammar"]))
assert.strictEqual(M.actionByKey(actions, "t").id, "translate")
assert.strictEqual(M.actionByKey(actions, "O"), null)
assert.strictEqual(M.actionId({ id: "translate", name: "Translate" }), "translate")
assert.strictEqual(M.actionId({ actionId: "improve", id: "ignored" }), "improve")
assert.strictEqual(M.actionById(actions, "grammar").key, "G")
assert.strictEqual(M.actionById(actions, ""), null)
assert.strictEqual(M.actionIndexById(actions, "improve"), 1)

assert.strictEqual(M.processingLabel("Translate"), "Translating")
assert.strictEqual(M.processingLabel("Make professional"), "Rewriting")
assert.strictEqual(M.processingLabel(""), "Working")
assert.strictEqual(M.formatHotkey("CTRL + ALT + SHIFT", "t"), "CTRL + ALT + SHIFT + T")
assert.strictEqual(M.formatHotkey("CTRL + ALT + SHIFT", ""), "")
assert.strictEqual(M.clampIndex(8, 3), 2)
assert.strictEqual(M.clampIndex(-2, 3), 0)
assert.strictEqual(M.wrapIndex(0, 3, -1), 2)
assert.strictEqual(M.wrapIndex(2, 3, 1), 0)

assert.strictEqual(M.heroMeta({ hasCurrentKey: false }, "idle"), "Add an API key to start")
assert.strictEqual(M.heroMeta({ hasCurrentKey: true, runningName: "Translate" }, "processing"), "Rewriting translate")
assert.strictEqual(M.heroMeta({ hasCurrentKey: true }, "failed", "", "Rate limited. Please wait and try again."), "Rate limited. Please wait and try again.")
assert.strictEqual(M.heroMeta({ hasCurrentKey: true, binds: { installed: false } }, "idle"), "Shortcuts not installed")
assert.strictEqual(M.heroMeta({ hasCurrentKey: true, binds: { installed: true } }, "idle", "Rewriting in place"), "Rewriting in place")

assert.strictEqual(M.heroDetail({ provider: "grok", providers: [{ id: "grok", displayName: "xAI (Grok)" }] }), "xAI (Grok)")
assert.strictEqual(M.parseDump("not-json"), null)
assert.strictEqual(M.parseRunResult("{not").error, "invalid_response")
assert.strictEqual(M.parseRunResult('{"ok":true,"result":"Hi"}').result, "Hi")

console.log("ok")
