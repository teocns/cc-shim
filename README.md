<div align="center">

# cc-shim

**One `claude` on your PATH. Everything else plugs in.**

Route it&nbsp; ◦ &nbsp;Hand it a token&nbsp; ◦ &nbsp;Append a system prompt&nbsp; ◦ &nbsp;Never break the launch

[Install](#install) • [How it works](#how-it-works) • [Write a fragment](#write-a-fragment) • [Reference](docs/reference.md) • [cc-gateway](https://github.com/teocns/cc-gateway)

[![ci](https://github.com/teocns/cc-shim/actions/workflows/ci.yml/badge.svg)](https://github.com/teocns/cc-shim/actions/workflows/ci.yml)
![node](https://img.shields.io/badge/node-%E2%89%A5%2022.13-339933?logo=node.js&logoColor=white)
![dependencies](https://img.shields.io/badge/dependencies-0-blue)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)
![platforms](https://img.shields.io/badge/macOS%20·%20Linux%20·%20Windows-lightgrey)

</div>

---

Every tool that wants to change how Claude Code starts ships its own `claude` wrapper, and the last
one installed wins. cc-shim takes that slot once. Tools drop small **fragments** into a folder
instead; cc-shim runs them, then hands over to the real `claude`.

## How it works

```
claude "fix the tests"
  └─ cc-shim
       1. find the real claude
       2. run ~/.config/cc-shim/conf.d/*         each one sets env vars for this launch
       3. append ~/.config/cc-shim/system-prompt.md
       4. hand over to claude                    always reached, even if a fragment breaks
```

With an empty `conf.d`, it is a plain passthrough.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/teocns/cc-shim/main/install.sh | sh
```

Then, in a new shell: `cc-shim doctor`.

<details>
<summary>While the repo is private · Windows · uninstall</summary>

```sh
# private repo: the same installer, through gh
gh api repos/teocns/cc-shim/contents/install.sh -H "Accept: application/vnd.github.raw" | sh

# remove: the wrapper goes, your conf.d stays
curl -fsSL https://raw.githubusercontent.com/teocns/cc-shim/main/install.sh | sh -s -- --uninstall
```

On Windows, unpack a [release](https://github.com/teocns/cc-shim/releases) and run
`node cc-shim.mjs install`.
</details>

## Write a fragment

A fragment is a file in `~/.config/cc-shim/conf.d/`. Whatever it puts in the environment, `claude`
gets.

```js
// ~/.config/cc-shim/conf.d/10-work-token.mjs
process.env.CLAUDE_CODE_OAUTH_TOKEN = "sk-ant-oat01-…"
process.env.CC_SHIM_CLAIM = "work-token"     // later fragments don't run
```

```sh
cc-shim status                                                 # what runs, in what order
cc-shim fragment ~/.config/cc-shim/conf.d/10-work-token.mjs    # what it would set, as JSON
```

Fragments run in name order. `.mjs` works everywhere; `.sh` works on macOS and Linux. Rename one to
`*.off` to switch it off. A worked example: [`conf.d.example/`](conf.d.example/).

## Why cc-shim

- 🧩 **One slot, many tools.** A gateway, a token switcher and your own tweaks all live side by side.
- 🪂 **It cannot break `claude`.** A fragment that throws, exits, hangs or has a syntax error is skipped. `claude` still starts.
- 📝 **A standing system prompt.** Put text in `system-prompt.md` and every launch appends it.
- 🎯 **Pick an account per launch.** With [cc-gateway](https://github.com/teocns/cc-gateway): `claude --account work`.
- 🖥 **macOS, Linux, native Windows.** One Node file, no dependencies, no bash required.

## Commands

| | |
|---|---|
| `cc-shim install` · `uninstall [--purge]` | put the wrapper first on PATH, or take it away |
| `cc-shim status` | the real claude, the fragments, what runs |
| `cc-shim doctor` | PATH order, leftovers, fragment syntax |
| `cc-shim fragment FILE` | run one fragment as a launch would; print what it sets |
| `CC_SHIM_DISABLE=1 claude` | skip every fragment, this once |

Everything else (the fragment contract, `--account`, how the real claude is found, every
environment variable, known limits): **[docs/reference.md](docs/reference.md)**.

<details>
<summary>Inside the agentic kit</summary>

The same file is `ak shim` there, and the kit's gateway routes every `claude` through a fragment.
</details>

## License

[MIT](LICENSE) © 2026 teocns.
