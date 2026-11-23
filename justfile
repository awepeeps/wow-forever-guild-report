set shell := ["bash", "-euo", "pipefail", "-c"]
set positional-arguments

default:
    @just --list

install:
    bun install --frozen-lockfile

tools:
    bun scripts/install-tools.ts

# Biome ignores an unsupported path, so the list is filtered before the call.
# Format the given files, or the whole repository when none are given.
fmt *files:
    #!/usr/bin/env bash
    set -euo pipefail
    if (( ! $# )); then
        bun run format
        exit 0
    fi
    supported=()
    for file in "$@"; do
        case "$file" in
            *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.mts|*.cts|*.json|*.jsonc|*.md|*.css|*.yml|*.yaml)
                supported+=("$file")
                ;;
        esac
    done
    if (( ${#supported[@]} )); then
        bun run biome -- check --write -- "${supported[@]}"
    fi

fmt-check:
    bun run format:check

# Workflows are linted too because `lint` is a CI context.
# Lint the given files, or the whole repository when none are given.
lint *files:
    #!/usr/bin/env bash
    set -euo pipefail
    if (( $# )); then
        bun run biome -- check -- "$@"
        exit 0
    fi
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

# Staged secret scan; gitleaks never prints a finding value.
[private]
secrets-staged:
    gitleaks git --staged --redact --no-banner

# Reject env files, private keys, kubeconfigs and files over 5 MB.
forbidden-files *files:
    #!/usr/bin/env bash
    set -euo pipefail
    bun scripts/forbidden-files.ts "$@"

# actionlint and zizmor over the given workflows, or every workflow.
workflows *files:
    #!/usr/bin/env bash
    set -euo pipefail
    if (( $# )); then
        actionlint -- "$@"
        zizmor --quiet "$@"
    else
        actionlint
        zizmor --quiet .github/workflows
    fi

# shellcheck over the given scripts; nothing to do when none are given.
shellcheck *files:
    #!/usr/bin/env bash
    set -euo pipefail
    if (( $# )); then
        shellcheck --severity=warning --external-sources -- "$@"
    fi

# Advisory Conventional Commit check (C2.4); never fails the commit.
commit-msg file:
    bun scripts/commit-msg.ts {{ quote(file) }}

# Refuse a push to a protected branch and scan the exact pushed range (C7.10).
[private]
hook-pre-push:
    bun scripts/hook.ts pre-push

# The suite alone takes 31 s, so this covers formatting, lint and types.
# Fast subset for pre-push (C7.10), under 30 seconds.
pre-push-check: fmt-check lint typecheck

# Refresh locked dependencies when a manifest changed (post-checkout, post-merge).
deps-refresh:
    bun scripts/deps-refresh.ts mise.toml bun.lock

# Owner job `owner-public-data`: this is a public repository, so the scan runs.
public-data-staged:
    bun scripts/public-data.ts --staged

check: fmt-check lint typecheck test audit

# Refuses a global or foreign core.hooksPath; migrates only `.githooks`.
# Enable the shared Lefthook hooks without changing global Git settings.
hooks:
    #!/usr/bin/env bash
    set -euo pipefail

    command -v lefthook >/dev/null || {
        printf 'lefthook is not installed; run `mise install` first.\n' >&2
        exit 1
    }

    global=$(git config --global --get core.hooksPath || true)
    if [[ -n "$global" ]]; then
        printf 'A global core.hooksPath is set (%s); lefthook install refuses it.\n' "$global" >&2
        printf 'Remove it yourself, or use `lefthook install --force` only if you really mean it.\n' >&2
        exit 1
    fi

    existing=$(git config --get core.hooksPath || true)
    case "$existing" in
        ""|.githooks) ;;
        *)
            printf 'core.hooksPath is %s; integrate it manually.\n' "$existing" >&2
            exit 1
            ;;
    esac

    if [[ "$existing" == ".githooks" ]]; then
        git config --unset-all --local core.hooksPath
    fi

    lefthook install
    # A failed remote sync only warns in 2.2.2 and still exits 0, so assert the
    # shared jobs loaded before declaring success.
    dump=$(lefthook dump)
    if ! grep -q 'name: core-' <<<"$dump" || ! grep -q 'name: owner-' <<<"$dump"; then
        printf 'The shared hook config did not load; check access to the awepeeps/.github repository.\n' >&2
        exit 1
    fi
    hookdir=$(git rev-parse --path-format=absolute --git-path hooks)
    if [[ ! -x "$hookdir/pre-commit" || ! -x "$hookdir/pre-push" ]]; then
        printf 'Lefthook did not write the pre-commit and pre-push shims.\n' >&2
        exit 1
    fi
    printf 'Shared Lefthook hooks installed; no global settings changed.\n'

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
