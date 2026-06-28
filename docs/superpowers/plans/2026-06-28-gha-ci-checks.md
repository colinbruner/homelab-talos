# GitHub Actions CI Checks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a single GitHub Actions workflow that lints shell/YAML/markdown, validates Talos configs and kustomize manifests, and scans for secrets — blocking PRs to `main`.

**Architecture:** One `.github/workflows/ci.yml` with four parallel jobs (`lint`, `kustomize`, `talos-validate`, `secret-scan`). Existing files are first made lint-clean (config + a one-time format pass) so the very first CI run is green. The Talos version becomes a single source of truth in `consts.sh`, read by both scripts and CI.

**Tech Stack:** GitHub Actions, bash, shellcheck, shfmt, yamllint, markdownlint-cli2, actionlint, kustomize, talosctl, gitleaks.

## Global Constraints

- **Line endings:** LF only (`\n`), never CRLF. Enforced by `.editorconfig` and a CI check.
- **Talos version source of truth:** `DEFAULT_TALOS_VERSION` in `scripts/lib/consts.sh` (current value `v1.13.5`). CI reads it; do not hardcode the Talos version elsewhere.
- **Kubernetes version:** `DEFAULT_KUBERNETES_VERSION="1.36.2"` already in `consts.sh`.
- **Node set (9):** `control-01 control-02 control-03 worker-01 worker-02 worker-03 worker-04 worker-05 worker-06`.
- **shfmt canonical formatting:** driven by `.editorconfig` (`indent_style = space`, `indent_size = 2` for `*.sh`); run shfmt with no `-i`/`-ci` flags so it reads `.editorconfig`.
- **Triggers:** `pull_request` → `main`, `push` → `main`, `workflow_dispatch`. Not all branches.
- **Pinned third-party actions:** pin every `uses:` to a release tag.
- **Generated `config/` is gitignored** and self-populated by `generate-config.sh` (including throwaway `secrets.yaml`) on the ephemeral runner — never commit it.

---

### Task 1: Add `DEFAULT_TALOS_VERSION` to consts.sh

**Files:**
- Modify: `scripts/lib/consts.sh`

**Interfaces:**
- Produces: shell variable `DEFAULT_TALOS_VERSION="v1.13.5"` sourced from `scripts/lib/consts.sh`; also greppable as a line matching `^DEFAULT_TALOS_VERSION="..."`. Task 6 (talos-validate job) reads this value.

- [ ] **Step 1: Add the variable**

In `scripts/lib/consts.sh`, directly below the existing `DEFAULT_KUBERNETES_VERSION="1.36.2"` line, add:

```bash
# Talos OS version — single source of truth for upgrade-talos.sh defaults and CI.
DEFAULT_TALOS_VERSION="v1.13.5"
```

- [ ] **Step 2: Verify the variable is sourceable and greppable**

Run:
```bash
grep -E '^DEFAULT_TALOS_VERSION="v[0-9]+\.[0-9]+\.[0-9]+"$' scripts/lib/consts.sh
( SCRIPTPATH=scripts/lib; . scripts/lib/consts.sh; echo "TALOS=$DEFAULT_TALOS_VERSION" )
```
Expected: the grep prints the line; the second command prints `TALOS=v1.13.5`.

- [ ] **Step 3: Verify shellcheck is still clean on consts.sh**

Run: `shellcheck -x scripts/lib/consts.sh`
Expected: no output, exit 0.

- [ ] **Step 4: Commit**

```bash
git add scripts/lib/consts.sh
git commit -m "feat: add DEFAULT_TALOS_VERSION to consts.sh as single source of truth"
```

---

### Task 2: Make shell scripts lint-clean (.editorconfig, .shellcheckrc, shfmt, shellcheck)

**Files:**
- Create: `.editorconfig`
- Create: `.shellcheckrc`
- Modify: `scripts/*.sh`, `scripts/lib/consts.sh`, `resources/install.sh` (formatting + quoting only)

**Interfaces:**
- Produces: a repo where `shfmt -d .` and `shellcheck -x` (all scripts) exit 0. Task 4's `lint` job depends on this being clean.
- Consumes: `DEFAULT_TALOS_VERSION` exists (Task 1) — leave it intact during edits.

- [ ] **Step 1: Install shfmt locally**

Run: `command -v shfmt >/dev/null || brew install shfmt`
Expected: `shfmt` is on PATH afterward (`shfmt --version` prints a version).

- [ ] **Step 2: Create `.editorconfig`**

Create `.editorconfig` with exactly:

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true

[*.sh]
indent_style = space
indent_size = 2

[*.{yaml,yml}]
indent_style = space
indent_size = 2
```

- [ ] **Step 3: Create `.shellcheckrc`**

Create `.shellcheckrc` with exactly:

```ini
# Follow sourced files (e.g. scripts/lib/consts.sh) during analysis.
external-sources=true
source-path=SCRIPTDIR
```

- [ ] **Step 4: Format all shell scripts with shfmt (reads .editorconfig)**

Run: `shfmt -w scripts/*.sh scripts/lib/*.sh resources/*.sh`
Then review the diff: `git diff --stat`
Expected: only whitespace/formatting changes (indentation, spacing). No logic changes.

- [ ] **Step 5: Fix remaining shellcheck findings (quoting)**

Run: `shellcheck -x scripts/*.sh scripts/lib/*.sh resources/*.sh`
For every `SC2086` ("Double quote to prevent globbing and word splitting"), wrap the flagged expansion in double quotes. Example transformations:

```bash
# before
. ${SCRIPTPATH}/lib/consts.sh
talosctl ... -n $NODE_IP $EXTRA_ARGS --file ${TARGET_OUTPUT_DIR}/${NODE_NAME}.yaml
# after
. "${SCRIPTPATH}"/lib/consts.sh
talosctl ... -n "$NODE_IP" $EXTRA_ARGS --file "${TARGET_OUTPUT_DIR}/${NODE_NAME}.yaml"
```

Note: `$EXTRA_ARGS` in `generate-config.sh` intentionally word-splits (it holds `--force` and may hold more). Leave `$EXTRA_ARGS` unquoted and silence just that line with a targeted directive immediately above it:

```bash
# shellcheck disable=SC2086 # EXTRA_ARGS is a flag list that must word-split
```

Do not change program behavior — only add quotes (and the one targeted disable for `$EXTRA_ARGS`).

- [ ] **Step 6: Verify shellcheck and shfmt are clean**

Run:
```bash
shellcheck -x scripts/*.sh scripts/lib/*.sh resources/*.sh; echo "shellcheck exit=$?"
shfmt -d scripts/*.sh scripts/lib/*.sh resources/*.sh; echo "shfmt exit=$?"
```
Expected: both print `exit=0` with no findings/diff.

- [ ] **Step 7: Sanity-check a script still runs its usage path**

Run: `bash scripts/generate-config.sh 2>&1 | head -1 || true`
Expected: prints the `Usage: ...` line (no syntax error / unbound-variable crash).

- [ ] **Step 8: Commit**

```bash
git add .editorconfig .shellcheckrc scripts resources/install.sh
git commit -m "style: add editorconfig/shellcheckrc and make shell scripts lint-clean"
```

---

### Task 3: Add YAML and markdown lint configs (and make repo pass)

**Files:**
- Create: `.yamllint.yaml`
- Create: `.markdownlint.yaml`
- Modify (only if needed): files under `patches/`, `resources/`, `docs/`, root `*.md`

**Interfaces:**
- Produces: a repo where `yamllint -c .yamllint.yaml patches resources` and `markdownlint-cli2 "**/*.md"` exit 0. Task 4's `lint` job depends on this.

- [ ] **Step 1: Create `.yamllint.yaml`**

Create `.yamllint.yaml` with exactly:

```yaml
---
extends: default

rules:
  line-length:
    max: 120
    level: error
  document-start: disable
  comments:
    min-spaces-from-content: 1
  truthy:
    check-keys: false
```

- [ ] **Step 2: Verify yamllint passes on patches and resources**

Run: `yamllint -c .yamllint.yaml patches resources; echo "exit=$?"`
Expected: `exit=0` with no output. (The config raises the line-length limit to 120, disables the optional `---` document-start, and relaxes comment spacing, so the existing files pass as-is. If any unexpected finding appears, fix that specific file minimally — e.g. wrap a >120-char line — and re-run.)

- [ ] **Step 3: Create `.markdownlint.yaml`**

Create `.markdownlint.yaml` with exactly:

```yaml
---
# Permissive baseline — docs use long lines, inline HTML, and duplicate headings.
default: true
MD013: false   # line-length
MD033: false   # inline HTML
MD024:
  siblings_only: true   # allow duplicate headings in different sections
MD041: false   # first line need not be a top-level heading
```

- [ ] **Step 4: Install markdownlint-cli2 and verify docs pass**

Run:
```bash
command -v markdownlint-cli2 >/dev/null || brew install markdownlint-cli2
markdownlint-cli2 "**/*.md" "#node_modules"; echo "exit=$?"
```
Expected: `exit=0`. If a doc fails on a rule that is clearly a real formatting slip (e.g. `MD009` trailing spaces, `MD047` missing final newline), fix that file minimally and re-run. If a rule is noisy/stylistic for these docs, disable it by adding `MDxxx: false` to `.markdownlint.yaml` and re-run.

- [ ] **Step 5: Commit**

```bash
git add .yamllint.yaml .markdownlint.yaml patches resources docs ./*.md
git commit -m "style: add yamllint/markdownlint configs and make repo lint-clean"
```

---

### Task 4: Create `ci.yml` with the `lint` job

**Files:**
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Produces: workflow `CI` with triggers/concurrency and job `lint`. Later tasks (5, 6, 7) append jobs `kustomize`, `talos-validate`, `secret-scan` to the same `jobs:` map.
- Consumes: clean shell/YAML/markdown state and configs from Tasks 2–3.

- [ ] **Step 1: Install actionlint locally (for verification)**

Run: `command -v actionlint >/dev/null || brew install actionlint`
Expected: `actionlint --version` prints a version.

- [ ] **Step 2: Create `.github/workflows/ci.yml`**

Create `.github/workflows/ci.yml` with exactly:

```yaml
---
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  workflow_dispatch:

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  lint:
    name: lint (shell / yaml / markdown)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: shellcheck
        uses: ludeeus/action-shellcheck@2.0.0
        env:
          SHELLCHECK_OPTS: -x

      - name: shfmt
        uses: mfinelli/setup-shfmt@v3
      - name: shfmt diff check
        run: shfmt -d scripts resources

      - name: yamllint
        uses: ibiqlik/action-yamllint@v3
        with:
          config_file: .yamllint.yaml
          file_or_dir: patches resources

      - name: markdownlint
        uses: DavidAnson/markdownlint-cli2-action@v16
        with:
          globs: |
            **/*.md
            #node_modules

      - name: line endings (LF only)
        run: |
          if git -c core.quotepath=off grep -lI $'\r' -- . ; then
            echo "::error::CRLF line endings detected in the files above"
            exit 1
          fi
          echo "All tracked text files use LF."

      - name: actionlint
        uses: raven-actions/actionlint@v2
```

- [ ] **Step 3: Validate the workflow with actionlint**

Run: `actionlint .github/workflows/ci.yml; echo "exit=$?"`
Expected: `exit=0`, no output.

- [ ] **Step 4: Locally reproduce each lint step to confirm it would pass**

Run:
```bash
shellcheck -x scripts/*.sh scripts/lib/*.sh resources/*.sh && echo "shellcheck OK"
shfmt -d scripts resources && echo "shfmt OK"
yamllint -c .yamllint.yaml patches resources && echo "yamllint OK"
markdownlint-cli2 "**/*.md" "#node_modules" && echo "markdownlint OK"
git -c core.quotepath=off grep -lI $'\r' -- . ; echo "crlf grep exit=$? (1 = none found = good)"
```
Expected: each prints its `OK`; the CRLF grep prints `exit=1` (no matches = clean).

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add CI workflow with shell/yaml/markdown lint job"
```

---

### Task 5: Add the `kustomize` job

**Files:**
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: existing `jobs:` map from Task 4.
- Produces: job `kustomize` that runs `kustomize build resources/`.

- [ ] **Step 1: Append the `kustomize` job**

In `.github/workflows/ci.yml`, add this job under `jobs:` (after the `lint` job, same indentation level as `lint`):

```yaml
  kustomize:
    name: kustomize build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: install kustomize
        run: |
          curl -sfL "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
          sudo install -m 0755 kustomize /usr/local/bin/kustomize
          kustomize version

      - name: build manifests
        run: |
          # resources/ recurses into metrics-server (which pulls remote bases).
          kustomize build resources/ > /dev/null
          echo "kustomize build succeeded"
```

- [ ] **Step 2: Validate the workflow with actionlint**

Run: `actionlint .github/workflows/ci.yml; echo "exit=$?"`
Expected: `exit=0`.

- [ ] **Step 3: Locally reproduce the build**

Run: `kustomize build resources/ > /dev/null && echo "build OK"`
Expected: prints `build OK` (requires network for the remote bases).

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add kustomize build job"
```

---

### Task 6: Add the `talos-validate` job

**Files:**
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: `DEFAULT_TALOS_VERSION` line in `scripts/lib/consts.sh` (Task 1); `scripts/generate-config.sh`.
- Produces: job `talos-validate` that generates all 9 node configs and runs `talosctl validate -m metal` on each.

- [ ] **Step 1: Confirm the local talosctl validate syntax**

Run (locally, talosctl is installed):
```bash
talosctl validate --help 2>&1 | grep -E -- '-c|--config|-m|--mode'
```
Expected: confirms `-c/--config <file>` and `-m/--mode <metal>` flags exist. (If the flag names differ in the pinned version, adjust the commands in Step 2 to match.)

- [ ] **Step 2: Append the `talos-validate` job**

In `.github/workflows/ci.yml`, add this job under `jobs:` (after `kustomize`):

```yaml
  talos-validate:
    name: talos config validate
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: read pinned talos version
        id: talos
        run: |
          version="$(grep -E '^DEFAULT_TALOS_VERSION="' scripts/lib/consts.sh | cut -d'"' -f2)"
          if [ -z "$version" ]; then
            echo "::error::DEFAULT_TALOS_VERSION not found in scripts/lib/consts.sh"
            exit 1
          fi
          echo "version=$version" >> "$GITHUB_OUTPUT"
          echo "Using talosctl $version"

      - name: install talosctl
        run: |
          version="${{ steps.talos.outputs.version }}"
          url="https://github.com/siderolabs/talos/releases/download/${version}/talosctl-linux-amd64"
          curl -sfL "$url" -o talosctl
          sudo install -m 0755 talosctl /usr/local/bin/talosctl
          talosctl version --client

      - name: generate configs for all nodes
        run: |
          for node in control-01 control-02 control-03 \
                      worker-01 worker-02 worker-03 worker-04 worker-05 worker-06; do
            echo "::group::generate $node"
            ./scripts/generate-config.sh -n "$node"
            echo "::endgroup::"
          done

      - name: validate generated configs
        run: |
          shopt -s nullglob
          configs=(config/control-*.yaml config/workers/worker-*.yaml)
          if [ "${#configs[@]}" -ne 9 ]; then
            echo "::error::expected 9 configs, found ${#configs[@]}: ${configs[*]}"
            exit 1
          fi
          for f in "${configs[@]}"; do
            echo "validating $f"
            talosctl validate -c "$f" -m metal
          done
          echo "all ${#configs[@]} configs valid"
```

- [ ] **Step 3: Validate the workflow with actionlint**

Run: `actionlint .github/workflows/ci.yml; echo "exit=$?"`
Expected: `exit=0`.

- [ ] **Step 4: Locally reproduce generate + validate in a clean temp checkout**

Run (uses a throwaway copy so your real `config/` is untouched):
```bash
tmp="$(mktemp -d)"; git worktree add -q "$tmp" HEAD
( cd "$tmp"
  for node in control-01 control-02 control-03 worker-01 worker-02 worker-03 worker-04 worker-05 worker-06; do
    ./scripts/generate-config.sh -n "$node" >/dev/null
  done
  shopt -s nullglob
  configs=(config/control-*.yaml config/workers/worker-*.yaml)
  echo "found ${#configs[@]} configs"
  for f in "${configs[@]}"; do talosctl validate -c "$f" -m metal; done
  echo "all valid"
)
git worktree remove --force "$tmp"
```
Expected: `found 9 configs`, each validates with no error, prints `all valid`.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add talos config validate job"
```

---

### Task 7: Add the `secret-scan` job

**Files:**
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: existing `jobs:` map.
- Produces: job `secret-scan` running gitleaks over the repo/diff.

- [ ] **Step 1: Append the `secret-scan` job**

In `.github/workflows/ci.yml`, add this job under `jobs:` (after `talos-validate`):

```yaml
  secret-scan:
    name: gitleaks secret scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

- [ ] **Step 2: Validate the full workflow with actionlint**

Run: `actionlint .github/workflows/ci.yml; echo "exit=$?"`
Expected: `exit=0`.

- [ ] **Step 3: Locally confirm the repo is gitleaks-clean**

Run:
```bash
command -v gitleaks >/dev/null || brew install gitleaks
gitleaks detect --source . --redact --no-banner; echo "exit=$?"
```
Expected: `exit=0` ("no leaks found"). If gitleaks flags an example token in `docs/` that is intentionally non-secret, add a `.gitleaks.toml` allowlist entry for that specific path/regex and re-run until clean, then `git add .gitleaks.toml`.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci.yml .gitleaks.toml 2>/dev/null || git add .github/workflows/ci.yml
git commit -m "ci: add gitleaks secret-scan job"
```

---

## Final verification (after all tasks)

- [ ] `actionlint .github/workflows/ci.yml` exits 0.
- [ ] All four local reproductions (lint, kustomize, talos-validate, gitleaks) pass.
- [ ] Push the branch and open a PR to `main`; confirm all four jobs run and go green on the first run.

## Notes / Risks

- `kustomize build` and `talosctl install` require network access (available on `ubuntu-latest`). The metrics-server base pins to `latest`/`main` upstream — an upstream change could turn the kustomize job red independent of this repo; that is an accepted trade-off of the existing manifests.
- `gitleaks-action@v2` is free for public/personal repos; if this repo is in an org that requires a `GITLEAKS_LICENSE`, add it as a secret and pass it via `env`.
- If the pinned `talosctl` changes `validate` flag names, Task 6 Step 1 catches it before the workflow is written.
