# MCP Troubleshooting

Match the error text, find the cause, apply the fix.

## Quick table

| Error | Cause | Fix |
| --- | --- | --- |
| `Chromium distribution 'chrome' is not found at /opt/google/chrome/chrome` | Browser server defaults to the Chrome channel, which is not installed | Add `--browser chromium` |
| `error while loading shared libraries: libnspr4.so` | Browser installed, OS libraries missing | `playwright-core install-deps chromium` |
| `Target page, context or browser has been closed` | Browser process died during launch | Read the `[pid=...] [err]` line in the same message for the real cause |
| `Connection closed: MCP server process exited with code 1` | The command failed on startup | Run the exact `command` array by hand; the package name is usually wrong |
| Server stays `pending` | Startup timeout hit | Raise `mcp.timeout.startup`, or pre-install the package so npx does not resolve it at launch |
| Server shows `○ disabled` | `disabled: true` in the config | Expected. Remove the flag to re-enable it. |
| Server never appears in the list | Missing or invalid `type` field | Add `"type": "local"` or `"type": "remote"`. A server without `type` is dropped silently. |
| Server shows `needs authentication` | Remote server wants OAuth | Sign in through `/mcps` in the TUI |
| `opencode mcp list` shows nothing | Wrong directory, or the location has not finished loading | Run it from the directory the session uses. A brand new project config can take a moment to register - retry before assuming the config is broken. |
| Server connects but every call fails | Tool-level failure the handshake does not cover | Smoke-test one tool and read the error |
| Auth fails with an empty key | `{env:VAR}` resolved to an empty string | Export the variable, or point `{file:...}` at a secrets file |
| Changes to `opencode.json` have no effect | Edited a config the location does not read | Confirm the path; a project config only applies under its own directory |

## Reading a browser failure

A browser launch failure is reported as a generic error with the real cause embedded:

```
Error: async initializeServer: Target page, context or browser has been closed
Browser logs:
<launching> /root/.cache/ms-playwright/chromium-1247/chrome-linux-arm64/chrome ...
<launched> pid=15783
[pid=15783][err] .../chrome: error while loading shared libraries: libnspr4.so: cannot open shared object file
```

Work through it in order:

1. Find the `[pid=...][err]` line. That is the actual failure. The first line is only the wrapper.
2. `cannot open shared object file` - install the OS libraries.
3. `No usable sandbox` or a sandbox error - add `--no-sandbox`.
4. `Missing X server` or a display error - add `--headless`.
5. `exited with code N` with no other output - run the command by hand:

   ```sh
   npx -y @playwright/mcp --browser chromium --headless --no-sandbox --isolated
   ```

   It speaks MCP over stdio, so it will appear to hang. That is expected. The point is whether it
   prints anything to stderr before hanging.

## Reproducing a server by hand

Most local servers are stdio programs. Running them directly isolates MCP from the problem:

```sh
# exactly the array from the config
npx -y @modelcontextprotocol/server-filesystem /root

# check a package exists and is runnable
npx -y @modelcontextprotocol/server-memory --help

# find the npx cache entry for a pinned package
ls ~/.npm/_npx/*/node_modules/<pkg>/package.json
```

A server that exits immediately with code 1 and no output is almost always a bad package name or a
missing required argument.

## Status vocabulary

`opencode mcp list` prints exactly one of these per server:

| Symbol | State | Meaning |
| --- | --- | --- |
| `✓` | `connected` | Transport handshake succeeded. Tools may still fail. |
| `○` | `pending` | Still starting, or the startup timeout expired. |
| `○` | `disabled` | Configured with `disabled: true`. Intentionally not connected. |
| `✗` | `failed: <reason>` | The server could not start or the handshake failed. |

A server that is configured but missing from the list entirely was dropped because its `type` field
was absent or invalid.

`connected` is not proof that the tools work. Always smoke-test.

## Log location

```sh
tail -200 ~/.local/share/opencode/log/opencode.log
```

Filter for the server and the role:

```sh
grep -iE "mcp|playwright" ~/.local/share/opencode/log/opencode.log | tail -20
grep "role=server" ~/.local/share/opencode/log/opencode.log | tail -20
```

Useful lines:

- `mcp connected server=<name> tools=<count>` - handshake succeeded, and the count tells you how
  many tools the server exposed.
- `spawning process command=...` - the exact command line OpenCode ran. Compare it against the
  config.
- `skills rescanned`, `watcher started` - shows which directories are being watched for config and
  skill changes.

Redact API keys, authorization headers, and file contents before sharing log excerpts.

## Permissions blocking a call

A server can be connected and its tools still blocked.

```jsonc
{
  "permissions": [
    { "action": "filesystem_*", "resource": "*", "effect": "deny" }
  ]
}
```

Check for a matching rule when a tool call is rejected without an obvious cause. The action is the
normalized `<server>_<tool>` name. Denying `execute` removes Code Mode and every MCP tool reached
through it.

## Resetting a server

1. Disconnect and reconnect through `/mcps` in the TUI.
2. Confirm the config entry is still present - disconnecting does not remove configuration.
3. To stop a server from connecting while keeping it configured, set `disabled: true`.
4. To remove it entirely, delete the entry from the global or project config where it was added.
5. For OAuth, `opencode mcp logout <name>` clears the stored credential so the next connect starts
   a fresh sign-in.

## Startup timing

The first launch of an npx-based server pays for package resolution and extraction. That can exceed
the 30 s default startup timeout and leave the server in `pending`.

Two fixes, both worth applying:

```sh
# warm the cache so the first launch is fast
npx -y <pkg> --help
```

```jsonc
{ "mcp": { "timeout": { "startup": 120000 } } }
```

A server that reaches `connected` once stays connected. `pending` after a successful first launch
means the timeout is still too tight for this machine.

## Deprecated packages

A deprecated package still installs, still runs, and still connects. The only symptom is an npm
warning on every launch, which is easy to miss in the MCP startup logs:

```
Connection closed: MCP server process exited with code 1: npm WARN deprecated
@modelcontextprotocol/server-brave-search@0.6.2: Package no longer supported.
```

Check before installing:

```sh
npm view <pkg> deprecated
```

Most of the original `@modelcontextprotocol/server-*` line is deprecated. The MCP steering group
now maintains only seven reference servers:

| Server | Package | Runtime |
| --- | --- | --- |
| filesystem | `@modelcontextprotocol/server-filesystem` | npm |
| memory | `@modelcontextprotocol/server-memory` | npm |
| sequential thinking | `@modelcontextprotocol/server-sequential-thinking` | npm |
| everything | `@modelcontextprotocol/server-everything` | npm |
| fetch | `mcp-server-fetch` | Python |
| time | `mcp-server-time` | Python |
| git | `mcp-server-git` | Python |

Replacements for the archived ones:

| Archived | Replacement |
| --- | --- |
| brave-search | `@brave/brave-search-mcp-server` |
| slack | `@zencoderai/slack-mcp-server` |
| github | Hosted endpoint `https://api.githubcopilot.com/mcp/`, OAuth |
| puppeteer | `@playwright/mcp` |
| postgres, sqlite, redis, sentry, gitlab | Browse <https://registry.modelcontextprotocol.io/> |

## A new location does not load instantly

Right after writing a project config, the first status read can come back empty:

```
No MCP servers configured
```

The config watcher has not registered the new location yet. Wait a couple of seconds and read it
again before changing anything. `scripts/check-mcp.sh` already retries three times for this case.

A project config is location-scoped. `opencode mcp list` run from a different directory reports a
different set of servers than the running session uses. Always audit from the session's working
directory.
