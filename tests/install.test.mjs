// install.sh end to end, POSIX only: pack a release, install it into a scratch HOME,
// find the wrapper and the wired rc, uninstall, and nothing of the shim is left but conf.d.
import { test } from "node:test"
import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import fs from "node:fs"
import os from "node:os"
import path from "node:path"
import { fileURLToPath } from "node:url"

const SRC = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")
const posix = process.platform !== "win32"

test("install.sh: a packed release installs, and --uninstall takes it all back but conf.d", { skip: !posix && "the installer is POSIX sh" }, () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "cc-shim-install-"))
  const home = path.join(tmp, "home")
  fs.mkdirSync(home)
  const env = { PATH: process.env.PATH, HOME: home, SHELL: "/bin/zsh" }
  const run = (cmd, args) => spawnSync(cmd, args, { cwd: SRC, env, encoding: "utf8" })
  try {
    const packed = run("sh", ["scripts/pack.sh", "--out", path.join(tmp, "dist")])
    assert.equal(packed.status, 0, packed.stderr)
    const version = JSON.parse(fs.readFileSync(path.join(SRC, "package.json"), "utf8")).version
    const tarball = path.join(tmp, "dist", `cc-shim-${version}.tar.gz`)

    const installed = run("sh", ["install.sh", "--from", tarball])
    assert.equal(installed.status, 0, installed.stderr)
    assert.match(installed.stdout, /verified {2}sha256 /)
    const shimDir = path.join(home, ".local", "share", "cc-shim")
    for (const f of ["claude", "cc-shim", "cc-shim.mjs", "_brand.sh"]) assert.ok(fs.existsSync(path.join(shimDir, f)), f)
    assert.equal(fs.readlinkSync(path.join(shimDir, "releases", "current")), version)
    assert.match(fs.readFileSync(path.join(home, ".zshenv"), "utf8"), /cc-shim/)

    const removed = run("sh", ["install.sh", "--uninstall"])
    assert.equal(removed.status, 0, removed.stderr)
    assert.ok(!fs.existsSync(path.join(shimDir, "claude")))
    assert.ok(!fs.existsSync(path.join(shimDir, "releases")))
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true })
  }
})
