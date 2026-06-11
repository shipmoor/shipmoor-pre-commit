# Changelog

All notable changes to the Shipmoor pre-commit hooks are documented here. The
`rev:` a consumer pins in `.pre-commit-config.yaml` is a tag from this repo.

## [Unreleased]

_Nothing yet._

## [v0.1.0] - 2026-06-11

### Added
- Initial release of the `shipmoor/shipmoor-pre-commit` hook repo.
- `shipmoor-scan` — structural scan of the staged change (Community, free).
- `shipmoor-scan-changed` — scan staged **and** unstaged changes.
- `shipmoor-intent` — Pro Intent-Drift claim check on the staged change.
- Wrapper installs the `shipmoor` CLI: latest stable by default, or pinned via
  `--shipmoor-version=X` / `$SHIPMOOR_VERSION`. Versions are cached per-version
  under `~/.cache/shipmoor-pre-commit/` so commits don't re-download.
- Offline, deterministic `bats` test suite + `shellcheck` + manifest validation
  in CI (Linux and macOS).
