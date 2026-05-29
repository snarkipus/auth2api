# AGENTS.md

## Commands
- Use npm; `package-lock.json` is the lockfile. Install with `npm install`.
- `npm run build` runs `tsc` and is the typecheck; output is generated in ignored `dist/`.
- `npm test` runs all `tests/*.test.ts` with `tsx --test` and mocked upstreams.
- Focus tests with `npx tsx --test tests/codex.test.ts` or `npx tsx --test --test-name-pattern "reload" tests/codex.test.ts`.
- `npm run test:smoke` only runs `tests/smoke.test.ts`; README mentions this, but it is not the full suite.
- `npm run test:e2e:responses` runs live `/v1/responses` non-streaming and streaming checks against `BASE_URL` (default `http://127.0.0.1:8317`) with `MODEL` defaulting to `gpt-5.5`; it reads the first API key from `config.yaml` unless `API_KEY` is set and consumes upstream quota.
- `npm run prettier` rewrites only `src/**/*.ts` and `tests/**/*.ts`; there is no lint script.
- Dev server: `npm run dev`. Built server: `npm run build && npm start`.
- Login flows use the app entrypoint: `npm run login`, or provider-specific `tsx src/index.ts --login --provider=codex|cursor`.

## Architecture
- Main CLI/server entrypoint is `src/index.ts`; it either runs login flows or starts Express via `createServer` in `src/server.ts`.
- Provider construction and model routing are centralized in `src/providers/registry.ts`; update this with provider/model-family routing changes.
- OpenAI-compatible endpoints live in `src/handlers/openai.ts`; Anthropic Messages endpoints live in `src/handlers/anthropic.ts`.
- Cross-format conversion is split between `src/upstream/translator.ts` for Anthropic/OpenAI paths and `src/upstream/responses-translator.ts` for Codex Responses translations.
- Provider-specific upstream behavior is in `src/upstream/anthropic-api.ts`, `src/upstream/codex-api.ts`, and `src/upstream/cursor-api.ts`.
- OAuth/token storage is provider-aware under `src/auth/` plus `src/accounts/manager.ts`; token filenames are `claude-*`, `codex-*`, and `cursor-*` JSON files in `auth-dir`.

## Runtime Gotchas
- `config.yaml` is local and ignored. If missing, `loadConfig()` auto-generates an API key and writes `config.yaml` with mode `0600`.
- Default host is `127.0.0.1` when config `host` is empty; default port is `8317`.
- Docker runs `node dist/index.js --config=/config/config.yaml`; when using the `/data` volume, set `auth-dir: "/data"` in the mounted config.
- `/health` is unauthenticated; `/v1/*` and `/admin/*` require either `Authorization: Bearer` or `x-api-key`.
- `/admin/reload` is upsert-only: removed token files remain in memory until restart.

## Provider Quirks
- Routing is model-name based: `claude-*` and `opus`/`sonnet`/`haiku` use Anthropic; `gpt-5*`, `o\d*`, and `codex-*` use Codex; `cursor-*` and `cr/*` force Cursor.
- Cursor-exclusive mode is special: if only Cursor has accounts, all model names route to Cursor so Claude/OpenAI clients work without `cursor-` prefixes.
- Codex requests are normalized to its ChatGPT backend requirements: upstream `stream:true`, `store:false`, `instructions`, and stripped `max_output_tokens` / `parallel_tool_calls`.
- Cursor support is reverse-engineered and streaming-first; `/v1/messages` through Cursor responds as Anthropic SSE even when the client requested non-streaming.
- Request fingerprint/version knobs are in `config.example.yaml` under `cloaking`; Codex and Cursor version gates may be fixed by config edits, not code changes.

## Local Files
- Do not commit `config.yaml`, `.env`, `dist/`, `node_modules/`, logs, or OAuth token files from `auth-dir`.

<!-- BEGIN BEADS INTEGRATION -->
## Issue Tracking with bd (beads)

**IMPORTANT**: This project uses **bd (beads)** for ALL issue tracking. Do NOT use markdown TODOs, task lists, or other tracking methods.

### Why bd?

- Dependency-aware: Track blockers and relationships between issues
- Git-friendly: Dolt-powered version control with native sync
- Agent-optimized: JSON output, ready work detection, discovered-from links
- Prevents duplicate tracking systems and confusion

### Quick Start

**Check for ready work:**

```bash
bd ready --json
```

**Create new issues:**

```bash
bd create "Issue title" --description="Detailed context" -t bug|feature|task -p 0-4 --json
bd create "Issue title" --description="What this issue is about" -p 1 --deps discovered-from:bd-123 --json
```

**Claim and update:**

```bash
bd update <id> --claim --json
bd update bd-42 --priority 1 --json
```

**Complete work:**

```bash
bd close bd-42 --reason "Completed" --json
```

### Issue Types

- `bug` - Something broken
- `feature` - New functionality
- `task` - Work item (tests, docs, refactoring)
- `epic` - Large feature with subtasks
- `chore` - Maintenance (dependencies, tooling)

### Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

### Workflow for AI Agents

1. **Check ready work**: `bd ready` shows unblocked issues
2. **Claim your task atomically**: `bd update <id> --claim`
3. **Work on it**: Implement, test, document
4. **Discover new work?** Create linked issue:
   - `bd create "Found bug" --description="Details about what was found" -p 1 --deps discovered-from:<parent-id>`
5. **Complete**: `bd close <id> --reason "Done"`

### Quality
- Use `--acceptance` and `--design` fields when creating issues
- Use `--validate` to check description completeness

### Lifecycle
- `bd defer <id>` / `bd supersede <id>` for issue management
- `bd stale` / `bd orphans` / `bd lint` for hygiene
- `bd human <id>` to flag for human decisions
- `bd formula list` / `bd mol pour <name>` for structured workflows

### Auto-Sync

bd automatically syncs via Dolt:

- Each write auto-commits to Dolt history
- Use `bd dolt push`/`bd dolt pull` for remote sync
- No manual export/import needed!

### Important Rules

- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag for programmatic use
- ✅ Link discovered work with `discovered-from` dependencies
- ✅ Check `bd ready` before asking "what should I work on?"
- ❌ Do NOT create markdown TODO lists
- ❌ Do NOT use external issue trackers
- ❌ Do NOT duplicate tracking systems

For more details, see README.md and docs/QUICKSTART.md.

## Session Completion

**When ending a work session**, complete the steps below. `origin` should point to the writable fork `snarkipus/auth2api`; keep `upstream` pointed at `AmazingAng/auth2api` for syncing.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - Attempt when credentials/permissions are available:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed, and pushed when remote access is available
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is not fully shared until `git push` succeeds
- Do not force-push or rewrite upstream history to work around permission errors
- If push fails due to auth/permission issues, report the failure and provide the local commit hash for handoff
- If push fails for a resolvable non-permission issue, resolve and retry

<!-- END BEADS INTEGRATION -->
