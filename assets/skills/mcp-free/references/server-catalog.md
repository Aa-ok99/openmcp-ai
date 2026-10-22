# Free MCP Server Catalog

Servers that add capability without a per-call fee. **Local** entries run on the machine over
stdio. **Remote** entries reach a free tier over HTTP, usually through OAuth.

## Find servers officially

The MCP project now keeps only a handful of reference servers. Everything else was archived and
most npm packages under `@modelcontextprotocol/server-*` were marked deprecated.

- Browse published servers: <https://registry.modelcontextprotocol.io/>
- Reference servers repository: <https://github.com/modelcontextprotocol/servers>
- Archived servers: <https://github.com/modelcontextprotocol/servers-archived>

**Always check for deprecation before installing:**

```sh
npm view <pkg> deprecated        # prints a message when the package is unsupported
npm view <pkg> version
```

A deprecated package still installs and still runs. It just no longer receives fixes, and npm
prints a warning on every launch that clutters the MCP startup logs.

Status column: **verified** = installed and smoke-tested on this machine. **checked** = package
name and version confirmed to resolve, not installed here.

## Maintained reference servers

These seven are the only ones the MCP steering group still maintains.

| Server | Package | Version | Runtime | Arguments / env |
| --- | --- | --- | --- | --- |
| filesystem | `@modelcontextprotocol/server-filesystem` | 2.0.0 | npm | Allowed directory path, positional |
| memory | `@modelcontextprotocol/server-memory` | 2.0.0 | npm | `MEMORY_FILE_PATH` optional |
| sequential thinking | `@modelcontextprotocol/server-sequential-thinking` | 2.0.0 | npm | none |
| everything | `@modelcontextprotocol/server-everything` | 2.0.0 | npm | none |
| fetch | `mcp-server-fetch` | 2026.10.19 | Python | none |
| time | `mcp-server-time` | 2026.10.19 | Python | none |
| git | `mcp-server-git` | 2026.10.19 | Python | `--repository <path>` |

Notes:

- **filesystem** is scoped to the paths you give it. Confirm the scope with
  `list_allowed_directories` rather than assuming. **verified** on this machine.
- **memory** persists a knowledge graph across sessions. Point `MEMORY_FILE_PATH` at a file to
  keep it.
- **sequential thinking** is a reasoning scaffold with no dependencies. Cheap to run.
- **everything** is the reference implementation used to test a client. It exercises prompts,
  resources, and tools, which makes it the fastest way to prove a transport works.
- **fetch** and **time** are Python. See the Python note below.

## Deprecated and archived

Do not install these. The npm packages are marked deprecated and the upstream code moved to
`servers-archived`.

| Deprecated package | Use instead |
| --- | --- |
| `@modelcontextprotocol/server-brave-search` | `@brave/brave-search-mcp-server` (2.1.4, maintained by Brave) |
| `@modelcontextprotocol/server-slack` | `@zencoderai/slack-mcp-server` (0.0.1, maintained by Zencoder) |
| `@modelcontextprotocol/server-github` | The hosted GitHub MCP endpoint, OAuth, see remote table |
| `@modelcontextprotocol/server-postgres` | Archived. Use a community server or the MCP Registry |
| `@modelcontextprotocol/server-sqlite` | Archived |
| `@modelcontextprotocol/server-redis` | Archived |
| `@modelcontextprotocol/server-sentry` | Archived, and Sentry ships its own remote MCP |
| `@modelcontextprotocol/server-gitlab` | Archived |
| `@modelcontextprotocol/server-puppeteer` | `@playwright/mcp` |

`npm view @modelcontextprotocol/server-postgres deprecated` returns
`Package no longer supported.` for every entry in this table.

## Other local servers

| Server | Package | Version | Arguments / env | Notes |
| --- | --- | --- | --- | --- |
| playwright | `@playwright/mcp` | 0.0.83 | `--browser chromium --headless --no-sandbox --isolated` | **verified.** See the browser section. |
| playwright (alt) | `@executeautomation/playwright-mcp-server` | 1.0.12 | - | Community alternative to `@playwright/mcp`. |
| brave search | `@brave/brave-search-mcp-server` | 2.1.4 | `BRAVE_API_KEY` | Official replacement. Brave's free tier covers a small monthly quota. |
| slack | `@zencoderai/slack-mcp-server` | 0.0.1 | `SLACK_BOT_TOKEN`, `SLACK_TEAM_ID` | Community maintained. Verify the expected environment variable names before relying on them. |
| remote bridge | `mcp-remote` | 0.15.2 | `--transport sse <url>` | Runs a remote server over stdio. For servers that only speak SSE. |

## Python servers

`mcp-server-fetch`, `mcp-server-time`, and `mcp-server-git` are PyPI packages. The upstream docs
recommend `uvx`, but this machine has no `uv`, `uvx`, or `pipx`. Install into a virtualenv instead:

```sh
python3 -m venv /root/.local/share/mcp-venvs/git
/root/.local/share/mcp-venvs/git/bin/pip install mcp-server-git
```

```jsonc
{
  "mcp": {
    "servers": {
      "git": {
        "type": "local",
        "command": ["/root/.local/share/mcp-venvs/git/bin/mcp-server-git", "--repository", "/root/repo"]
      }
    }
  }
}
```

Point `command` at the venv's own binary, never the system `python3`, or the server's dependencies
are missing at runtime.

Installing `uv` gives a shorter command and automatic version pinning:

```sh
curl -LsSf https://astral.sh/uv/install.sh | sh
```

```jsonc
{ "command": ["uvx", "mcp-server-git", "--repository", "/root/repo"] }
```

## Remote servers on a free tier

| Server | URL | Auth | Notes |
| --- | --- | --- | --- |
| context7 | `https://mcp.context7.com/mcp` | OAuth | Library documentation lookup. Works on the free tier without a key. |
| github | `https://api.githubcopilot.com/mcp/` | OAuth | The hosted GitHub MCP endpoint. Free for public repos. |
| sentry | `https://mcp.sentry.dev/mcp` | OAuth | Free for open-source projects; needs a token for private ones. |

Remote servers use OAuth by default. Sign in through the TUI (`/mcps`), not through a shell.

## Browser servers need three things

`@playwright/mcp` is the most common source of setup failures. In order:

1. **The right browser.** The server defaults to the `chrome` channel and looks for
   `/opt/google/chrome/chrome`. Pass `--browser chromium` to use the bundled Playwright build.

   ```sh
   npm view @playwright/mcp version
   npx -y @playwright/mcp@<version> install-browser
   ```

   Match the version to the one the package pins. The browser revision is tied to the
   `playwright-core` version in its dependency tree, and the browser lives in the npx cache at
   `~/.npm/_npx/<hash>/node_modules/playwright-core`. Installing through that exact copy guarantees
   a matching revision:

   ```sh
   node ~/.npm/_npx/<hash>/node_modules/playwright-core/cli.js install chromium
   ```

2. **The OS shared libraries.** Chromium needs them or it cannot start:

   ```sh
   node ~/.npm/_npx/<hash>/node_modules/playwright-core/cli.js install-deps chromium
   ```

3. **The right flags.** `--headless` for machines without a display, `--no-sandbox` when running as
   root, `--isolated` to keep the profile in memory.

Full working command:

```jsonc
{
  "mcp": {
    "servers": {
      "playwright": {
        "type": "local",
        "command": ["npx", "-y", "@playwright/mcp", "--browser", "chromium", "--headless", "--no-sandbox", "--isolated"]
      }
    }
  }
}
```

## Cost and context

- MCP tools consume model context. Add only the servers the task needs.
- Under Code Mode the tool schemas load lazily. A server with dozens of tools costs less than its
  schema size suggests, but each call still returns output into the transcript.
- A local server that is never called costs nothing but a process.
- Reference servers are explicitly reference implementations, not production-grade. Evaluate them
  against your own security requirements before exposing them to write operations.
