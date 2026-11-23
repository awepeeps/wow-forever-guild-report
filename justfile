set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

install:
    bun install --frozen-lockfile

tools:
    bun scripts/install-tools.ts

fmt:
    bun run format

fmt-check:
    bun run format:check

lint:
    bun run lint
    actionlint
    zizmor .github/workflows

typecheck:
    bun run typecheck

test:
    bun run test

audit:
    bun run audit

secrets:
    bun scripts/check-publication.ts
    bun scripts/secrets.ts

check: fmt-check lint typecheck test audit

hooks:
    git config --local core.hooksPath .githooks

agent-files:
    bun scripts/agent-files.ts

env-check:
    bun x --no-install varlock load

demo:
    DISCORD_MAP_FILE=examples/discord-map.json bun run cli export --config examples/roster.json --out output/demo

import-csv input output=".local/roster.json":
    bun run cli import --input {{quote(input)}} --out {{quote(output)}}

export config=".local/roster.json" out="output/export":
    bun run cli export --config {{quote(config)}} --out {{quote(out)}}

refresh config=".local/roster.json" out="output/roster" recipe_map="":
    bun run cli refresh --config {{quote(config)}} --out {{quote(out)}} {{if recipe_map == "" { "" } else { "--recipe-map " + quote(recipe_map) }}}

recipe-map build output=".local/recipe-map.json":
    bun run cli recipe-map --build {{quote(build)}} --out {{quote(output)}}

sheets snapshot="output/roster/snapshot.json":
    bun run cli sheets --snapshot {{quote(snapshot)}}

# Requires explicit authorization to update the configured Google spreadsheet.
# Manual refresh/publish cycles should use this command while its timer is enabled.
daily:
    @mkdir -p -m 700 .local
    flock --nonblock --conflict-exit-code 75 .local/daily-refresh.lock bun scripts/daily-refresh.ts
