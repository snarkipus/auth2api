# AGENTS.md

## Commands
- Use npm; `package-lock.json` is the lockfile. Install with `npm install`.
- `npm run build` runs `tsc` and is the typecheck; output is generated in ignored `dist/`.
- `npm test` runs all `tests/*.test.ts` with `tsx --test` and mocked upstreams.
- Focus tests with `npx tsx --test tests/codex.test.ts` or `npx tsx --test --test-name-pattern "reload" tests/codex.test.ts`.
- `npm run test:smoke` only runs `tests/smoke.test.ts`; README mentions this, but it is not the full suite.
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
