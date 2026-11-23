#!/usr/bin/env bun
// Redacted gitleaks scan using the checksum-pinned .local/bin/gitleaks binary.
// GITLEAKS_LOG_OPTS selects a commit range (pull request diff); unset scans all history.
const range = process.env.GITLEAKS_LOG_OPTS?.trim();
const args = [
  "git",
  "--redact",
  "--no-banner",
  ...(range ? ["--log-opts", range] : []),
  ".",
];
const result = Bun.spawnSync([".local/bin/gitleaks", ...args], {
  stdout: "inherit",
  stderr: "inherit",
});
process.exit(result.exitCode ?? 1);
