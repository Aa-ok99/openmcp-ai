---
name: MCP Free
description: Install, configure, verify, and troubleshoot free MCP servers in OpenCode V2 - servers that cost nothing to run and need no paid API key. Use when adding an MCP server, when a server fails to connect or stays pending, when picking between local and remote MCP, or when auditing an existing MCP setup.
---

# Free MCP Servers in OpenCode

Deploy MCP servers that add capability at zero running cost: local stdio servers launched by a
package already on the machine, or remote servers whose free tier is reached through OAuth rather
than a paid key.

"Free" here means no per-call fee and no paid API key required to function. It does not claim the
upstream project is free in every sense.

## Choosing local or remote

| | Local (stdio) | Remote (HTTP) |
| --- | --- | --- |
| Transport | Child process over stdio | Streamable HTTP |
| Config | `type: "local"` + `command` | `type: "remote"` + absolute `url` |
| Auth | None, unless the tool needs its own key | OAuth by default |
| Cost | Zero | Free tier, or zero |
| Failure modes | Missing binaries, missing OS libs, slow first launch | Token refresh, network, account limits |
| Best for | Filesystem, git, browsers, local databases | Docs search, issue trackers, hosted APIs |

Prefer local. It is the only category that is reliably free, works offline, and has no
token-refresh failure mode.

## Install workflow

Do not skip step 2. It prevents the most common failure there is.

1. **Pick the server.** Consult `references/server-catalog.md`. Confirm the package actually
   resolves, and check whether it is deprecated:

   ```sh
   npm view <pkg> version
   npm view <pkg> deprecated
   ```

   A wrong package name surfaces as `failed: MCP server process exited with code 1`, never as a
   useful error. A deprecated package installs and runs fine but no longer receives fixes, and npm
   prints a warning on every launch that clutters the startup logs. Most of the original
   `@modelcontextprotocol/server-*` line is deprecated; only filesystem, memory, sequential
   thinking, everything, fetch, time, and git are still maintained.

2. **Pre-install the package and its runtime dependencies.** The server process starts under a
   timeout, and npx resolving a package on first run is slow enough to blow it.

   ```sh
   npm install -g <pkg>              # install permanently
   npx -y <pkg> --help               # or warm the npx cache
   ```

   For anything that launches a browser, install the browser and the OS shared libraries for the
   exact version the MCP package pins - not the latest release.

3. **Add it.** Prefer the CLI; it merges into the existing config instead of replacing it.

   ```sh
   opencode mcp add <name> --global -- <command...>
   opencode mcp list
   ```

   Use `--global` for servers used across projects; omit it for a single project. A project entry
   lands in `<project>/opencode.json(c)` and is only visible when OpenCode runs from that
   directory.

4. **Tune the timeouts.** Local servers that launch a browser or a VM need more than the 30 s
   default.

   ```jsonc
   { "mcp": { "timeout": { "startup": 120000, "catalog": 60000, "execution": 600000 } } }
   ```

5. **Verify the connection.** `opencode mcp list` prints one line per server:

   ```text
   ✓ filesystem  connected
   ○ slowish     pending
   ○ turned-off  disabled
   ✗ broken      failed: Connection closed: MCP server process exited with code 1
   ```

   `connected` means the handshake succeeded. It does not mean the tools work. A server that never
   appears in the list at all is usually missing its `type` field, which is dropped silently.

6. **Smoke-test a real tool.** Call one tool through the MCP interface and confirm it returns real
   output. A server can connect and still fail on every call - a browser server that cannot launch
   its browser is exactly that case.

   Only report success after this step passes. Configuration text on disk proves nothing.

## Config reference (V2)

Servers live under `mcp.servers`, never directly under `mcp`.

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "servers": {
      "my-server": {
        "type": "local",
        "command": ["npx", "-y", "example-mcp-server"],
        "cwd": ".",
        "environment": { "MCP_API_KEY": "{env:MCP_API_KEY}" },
        "timeout": { "catalog": 60000 },
        "disabled": false,
        "codemode": true
      }
    }
  }
}
```

Fields that bite:

- **`mcp.servers`, not `mcp.<name>`.** V1 placed server names directly under `mcp`. A V1-shaped
  block is silently ignored.
- **`type` is required.** `"local"` or `"remote"`.
- **`disabled`, not `enabled`.** To keep a server configured but disconnected, set `disabled: true`.
- **`{env:NAME}` for secrets.** Shell syntax like `$NAME` is not expanded inside JSON strings. A
  missing variable becomes an empty string, which surfaces later as an authentication failure rather
  than a config error.
- **Overrides replace the whole object.** A higher-precedence config swaps out the entire server
  with the same name. Repeat every required field in the override, or use a distinct name.
- **OAuth is on by default for remote servers.** Set `oauth: false` only when the server
  exclusively uses an API-key header.
- **`protocol` accepts `legacy` (default), `auto`, or `2026-07-28`.** Probe with `auto` only for
  servers that need it; each probe spawns an extra process.

## Naming and exposure

- A tool is exposed as `<server>_<tool>`, normalized: every character outside `A-Za-z0-9_-`
  becomes `_`. Server `context 7` plus tool `resolve.library/id` becomes
  `context_7_resolve_library_id`.
- Under the default Code Mode, tools are grouped per server and reached as
  `tools.<server>.<tool>(...)` from `execute`. Call `search()` when the exact path is unknown.
- Tool names are stable across sessions, so they are safe to hard-code in skill text and in
  permission rules.

## Permissions

Restrict a server's tools without disconnecting it:

```jsonc
{
  "permissions": [
    { "action": "filesystem_*", "resource": "*", "effect": "deny" },
    { "action": "playwright_browser_evaluate", "resource": "*", "effect": "ask" }
  ]
}
```

- The action is `<server>_<tool>` with the same normalization; the resource is `*` for MCP tools.
  A `filesystem_*` pattern covers every tool that server exposes.
- MCP resources use the actions `opencode_list_mcp_resources` and `opencode_read_mcp_resource`,
  with resources `<server>` and `<server>:<uri>`.
- Denying the `execute` action removes Code Mode, which is a different lever from denying one
  server's tools.

## Rules learned the hard way

Each of these cost real debugging time. Apply them preemptively.

1. **Prefer the bundled browser over the Chrome channel.** `@playwright/mcp` defaults to the `chrome`
   channel and looks for `/opt/google/chrome/chrome`. Without Google Chrome installed it fails with
   `Chromium distribution 'chrome' is not found`. Pass `--browser chromium` to use Playwright's own
   build.
2. **Headless machines need `--headless`.** The browser server runs headed by default and cannot
   start without a display.
3. **Running as root needs `--no-sandbox`.** Chromium's sandbox cannot initialise as root.
4. **`--isolated` keeps the profile in memory.** Nothing is written to disk, so there is no state to
   clean up and nothing leaks between runs.
5. **Browser binaries need their OS libraries.** After installing the browser, install the shared
   libraries too, or the launch dies with `error while loading shared libraries: libnspr4.so`.
6. **Match the browser build to the package.** The browser revision is tied to the `playwright-core`
   version the MCP package pins. Installing the browser with a different Playwright release can
   install a revision the server does not expect.
7. **Config edits hot-reload.** Changing `opencode.json` restarts the affected MCP server on its
   own. There is no need to restart the OpenCode service.
8. **`opencode mcp list` is location-sensitive.** It reports the servers for the current directory's
   project plus the global ones. Run it from the same directory the session uses.
9. **Never run `opencode mcp auth` from a non-interactive shell.** It starts an OAuth flow whose
   authorization link can be swallowed by background process output. Ask the user to run `/mcps` in
   the TUI, or `opencode mcp auth <name>` themselves.
10. **Package managers differ.** Python MCP servers such as `mcp-server-git` are not npm packages.
    Without `uv`/`uvx`/`pipx`, install them into a virtualenv and point `command` at the venv
    binary.
11. **Python servers need a real interpreter.** A virtualenv path in `command` must point at the
    venv's own interpreter, not the system `python3`, or the server's dependencies are missing at
    runtime.
12. **A server missing `type` is dropped silently.** It never appears in `opencode mcp list` and
    produces no warning. Diff the configured server names against the listed names to catch it.
13. **The first read of a new project location races the config watcher.** Right after creating a
    project config, `opencode mcp list` can report `No MCP servers configured` even though the file
    is on disk. Retry after a short delay before concluding the config is wrong.
14. **Check for deprecation before installing.** `npm view <pkg> deprecated` is one command. A
    deprecated MCP package still runs, so nothing else will warn you.
15. **The MCP project archived most of its reference servers.** Only filesystem, memory, sequential
    thinking, everything, fetch, time, and git are still maintained. Brave Search moved to
    `@brave/brave-search-mcp-server`, Slack to `@zencoderai/slack-mcp-server`, and GitHub to the
    hosted remote endpoint. Browse <https://registry.modelcontextprotocol.io/> for the current
    set.

## Reporting

State, for every server:

- name and scope - global or project
- command or URL
- auth method, and whether a credential is still outstanding
- the `opencode mcp list` status
- the smoke test result - which tool was called and what it returned

Report `pending` as pending and `failed` as failed. Never describe a server as working on the
strength of its configuration block alone.

## Reference

- `references/server-catalog.md` - free servers, exact install commands, required arguments, known
  status on this machine
- `references/troubleshooting.md` - error text to root cause to fix
- `scripts/check-mcp.sh` - health check and config audit for every reachable server
