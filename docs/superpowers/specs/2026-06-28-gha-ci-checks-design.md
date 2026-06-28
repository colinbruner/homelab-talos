# GitHub Actions CI Checks — Design

**Date:** 2026-06-28
**Status:** Approved
**Branch:** `simplify-talos-config` (work to be branched from here)

## Problem

The repository has **no CI**. It manages a Talos Linux Kubernetes cluster via
hand-authored bash scripts, static Talos YAML patches, kustomize manifests, and
markdown docs. Nothing currently guards against:

- Bash bugs/footguns or formatting drift in the lifecycle scripts.
- Broken Talos config patches that only fail when applied to a real node.
- Accidentally committed secrets (`config/secrets.yaml`, `talosconfig`, `kubeconfig`).
- YAML / kustomize / line-ending / markdown hygiene regressions.

## Goal

Add a single GitHub Actions workflow that runs fast (~1–2 min), gives one
green/red signal per concern, and blocks PRs to `main` on failure.

## Architecture

**One workflow file, multiple parallel jobs.** `.github/workflows/ci.yml`.

- **Triggers:** `pull_request` → `main`, `push` → `main`, `workflow_dispatch`.
- **Concurrency:** group keyed on ref, `cancel-in-progress: true`.
- **Runner:** `ubuntu-latest`, each job starts with `actions/checkout`.
- Marketplace actions are pinned (tag or SHA) for the gnarly tools; simple tools
  installed inline.

### Jobs

#### 1. `lint`

Each step independent (use `if: always()` chaining or separate steps so all run):

- **shellcheck** — `scripts/*.sh`, `scripts/lib/*.sh`, `resources/*.sh`
  (`ludeeus/action-shellcheck`, pinned).
- **shfmt** — `-d` diff mode, hard fail, same file set. Requires a one-time
  `shfmt -w` pass on existing scripts so they start green.
- **yamllint** — `patches/` and `resources/`, with a repo `.yamllint.yaml`
  config, hard fail. Requires a one-time cleanup pass on existing YAML.
- **LF line-ending check** — fails if any tracked text file contains CRLF
  (enforces the CLAUDE.md LF rule).
- **actionlint** — lints `ci.yml` itself.
- **markdownlint** — `docs/` and root `*.md`, with a permissive
  `.markdownlint.yaml` (and a one-time cleanup pass if needed).

#### 2. `kustomize`

- `kustomize build resources/` and `kustomize build resources/metrics-server/`
  to prove the manifests assemble. Build-only (no kubeconform schema layer).

#### 3. `talos-validate`

The highest-value check.

1. Add `DEFAULT_TALOS_VERSION=v1.13.5` to `scripts/lib/consts.sh` as the single
   source of truth for the Talos version.
2. CI reads `DEFAULT_TALOS_VERSION` and installs that pinned `talosctl`.
3. Runs `generate-config.sh -n <node>` for all 9 nodes (control-01..03,
   worker-01..06). The script self-generates throwaway secrets in the ephemeral
   runner, so no real secrets are needed.
4. Runs `talosctl validate -m metal` on each generated config
   (`config/control-*.yaml`, `config/workers/worker-*.yaml`).

#### 4. `secret-scan`

- `gitleaks/gitleaks-action` (pinned), scanning the repo/diff so secret files
  can never land even if `.gitignore` is fumbled.

## Decisions (locked)

- **Workflow structure:** one `ci.yml`, parallel jobs (Approach A).
- **Talos version source of truth:** `DEFAULT_TALOS_VERSION` in `consts.sh`.
- **Lint strictness:** hard fail on shfmt + yamllint; one-time format pass on
  existing files so the first CI run is green.
- **Triggers:** `main` + PRs (not all branches).
- **Kustomize:** build-only (no kubeconform).

## Non-Goals

- kubeconform / schema validation of rendered manifests.
- Running CI on every branch push.
- Applying configs to real nodes from CI.
- Auto-formatting/auto-fixing in CI (checks only; fixes happen locally).

## Risks / Notes

- `talosctl validate -m metal` must accept configs generated with throwaway
  secrets — verify the validate mode and flags against the pinned talosctl.
- `generate-config.sh` writes into gitignored `config/` — fine on an ephemeral
  runner.
- The one-time `shfmt -w` / yamllint cleanup must be a reviewable, behavior-
  preserving commit (formatting only).
- `kustomize build` on `resources/metrics-server/` may pull a remote base;
  confirm network access is available on the runner.
