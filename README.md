# shipmoor-pre-commit

[pre-commit](https://pre-commit.com) hooks for the **Shipmoor** CLI — local-first
code-integrity for the agentic era. The hook scans the code your AI agent writes
(hallucinated dependencies, placeholder/stub code, quality regressions) **before**
it lands in a commit. It runs entirely on your machine: no source ever leaves your
laptop, and there is no Shipmoor cloud.

The wrapper installs the `shipmoor` CLI for you — the **latest stable build by
default**, or a **pinned version** — caches it, and runs `shipmoor scan` against
the staged change.

> Requires macOS (Apple Silicon) or Linux (amd64/arm64), matching the Shipmoor CLI.
> `curl`, `tar`, and `python3` must be available (they almost always are on CI).

## Quick start

Add this to your project's `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/shipmoor/shipmoor-pre-commit
    rev: v0.1.0            # pin the *hook* version; see "Versioning" below
    hooks:
      - id: shipmoor-scan
```

Then:

```bash
pre-commit install        # wire it into your Git hooks
pre-commit run shipmoor-scan --all-files   # try it once
```

On the first commit the wrapper downloads the latest Shipmoor CLI into a per-user
cache (`~/.cache/shipmoor-pre-commit/…`); subsequent commits reuse it.

## Hooks

| id | What it runs | Tier |
| --- | --- | --- |
| `shipmoor-scan` | `shipmoor scan --staged --fail-on high` | Community (free) |
| `shipmoor-scan-changed` | `shipmoor scan --changed --fail-on high` (staged **and** unstaged) | Community (free) |
| `shipmoor-intent` | `shipmoor scan --staged …` Intent-Drift claim check | Pro (licensed) |

If you don't pass a scope flag, the wrapper defaults to `--staged` so only the
content about to be committed is inspected.

## Pinning the Shipmoor CLI version

By default the hook installs the **latest** stable CLI. To pin a specific CLI
version, pass `--shipmoor-version` through the hook's `args` (note that setting
`args` replaces the hook's defaults, so re-state the flags you want):

```yaml
repos:
  - repo: https://github.com/shipmoor/shipmoor-pre-commit
    rev: v0.1.0
    hooks:
      - id: shipmoor-scan
        args: [--shipmoor-version=0.4.0, --fail-on, high]
```

Equivalently, set `SHIPMOOR_VERSION=0.4.0` in the environment. A leading `v` is
tolerated (`v0.4.0` == `0.4.0`). Each pinned version is cached separately, so you
can switch versions without re-downloading.

### Two different "versions"

- **`rev:`** pins *this hook repo* (the wrapper + `pre-commit autoupdate` target).
- **`--shipmoor-version`** pins *the Shipmoor CLI binary* the wrapper installs.

They are independent: you can stay on a fixed CLI while taking wrapper updates,
or vice-versa.

## Configuration

All knobs are optional.

| Flag / env | Default | Purpose |
| --- | --- | --- |
| `--shipmoor-version=X` / `SHIPMOOR_VERSION` | latest | Pin the CLI version. |
| `--shipmoor-channel=X` / `SHIPMOOR_CHANNEL` | `stable` | Release channel. |
| `--fail-on {none,critical,high,medium}` | (CLI default) | Severity that fails the commit. |
| `SHIPMOOR_PRE_COMMIT_HOME` | `~/.cache/shipmoor-pre-commit` | Cache root for installed CLIs. |
| `SHIPMOOR_PRE_COMMIT_REFRESH=1` | off | Re-fetch latest even if cached (no effect when pinned). |
| `SHIPMOOR_PRE_COMMIT_USE_SYSTEM=1` | off | Use a `shipmoor` already on `PATH` (only when unpinned). |
| `SHIPMOOR_INSTALL_URL` | `https://dl.shipmoor.dev/install.sh` | Override the installer source. |

Any other argument is forwarded straight to `shipmoor scan` — e.g.
`args: [--fail-on, critical, --no-color]`.

## Intent-Drift claim check (Pro)

The `shipmoor-intent` hook needs a licensed CLI (`shipmoor login`) and an intent
source. The most ergonomic option in a commit flow is a session transcript or a
`.shipmoor/intent.txt` file:

```yaml
      - id: shipmoor-intent
        args: [--staged, --session, .shipmoor/session.jsonl]
```

See the CLI's `docs/intent-drift.md` for how intent is supplied and gated.

## How install/caching works

1. Resolve the requested version (arg → env → latest) and channel.
2. Look in `~/.cache/shipmoor-pre-commit/<version|latest>/<channel>/bin/shipmoor`.
   - **Pinned**: reuse only if the cached binary reports that exact version.
   - **Latest**: reuse the cached build unless `SHIPMOOR_PRE_COMMIT_REFRESH=1`
     (so commits don't hit the network every time).
3. Otherwise fetch `dl.shipmoor.dev/install.sh` and run it with
   `SHIPMOOR_INSTALL_DIR`/`SHIPMOOR_LIB_DIR` pointed at the cache (checksum-verified
   by the installer). If the install fails but a cached binary exists, fall back to it.
4. `exec shipmoor scan <scope> <your args>`.

## Development

```bash
shellcheck bin/shipmoor-pre-commit
bats tests/                 # offline, deterministic (no network, no real CLI)
```

The test suite stubs both the installer and the CLI, so it never touches the
network or installs the real binary. See [`tests/`](tests/).

### Releasing

1. Move the changes from `## [Unreleased]` into a dated section in
   [`CHANGELOG.md`](CHANGELOG.md): `## [vX.Y.Z] - YYYY-MM-DD`.
2. Commit, then tag and push:
   ```bash
   git tag -a vX.Y.Z -m vX.Y.Z && git push origin main vX.Y.Z
   ```
3. The [`release`](.github/workflows/release.yml) workflow publishes a GitHub
   release whose notes are the matching `CHANGELOG.md` section. Tags with a
   `-` suffix (e.g. `v1.0.0-rc.1`) are marked as pre-releases automatically.

## License

MIT — see [LICENSE](LICENSE). The Shipmoor CLI it installs has its own license
(Community core open, commercial features entitlement-gated).
