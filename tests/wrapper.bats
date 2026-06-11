#!/usr/bin/env bats
#
# Offline, deterministic tests for bin/shipmoor-pre-commit.
#
# Neither the real installer nor the real CLI is ever invoked:
#   * SHIPMOOR_PRE_COMMIT_HOME points at a temp cache.
#   * A fake `shipmoor` binary is seeded into that cache (it echoes its args),
#     so cache_is_fresh() reuses it instead of installing.
#   * For the install path, SHIPMOOR_INSTALL_URL points at a local stub install
#     script (fetched via file://) that drops a fake binary into the cache.

setup() {
  WRAPPER="${BATS_TEST_DIRNAME}/../bin/shipmoor-pre-commit"
  TMP="$(mktemp -d)"
  export SHIPMOOR_PRE_COMMIT_HOME="$TMP/cache"
  # Keep the environment from leaking a pin/channel into the wrapper.
  unset SHIPMOOR_VERSION SHIPMOOR_CHANNEL SHIPMOOR_PRE_COMMIT_USE_SYSTEM \
    SHIPMOOR_PRE_COMMIT_REFRESH
}

teardown() {
  rm -rf "$TMP"
}

# Seed a fake CLI for a given version-key/channel. The stub prints its args so
# we can assert on what `scan` was called with, and answers `version` so a
# pinned cache looks fresh.
seed_cli() {
  local verkey="$1" channel="${2:-stable}" reported="${3:-0.0.0}"
  local bindir="$SHIPMOOR_PRE_COMMIT_HOME/$verkey/$channel/bin"
  mkdir -p "$bindir"
  cat >"$bindir/shipmoor" <<EOF
#!/usr/bin/env bash
if [ "\$1" = "version" ]; then echo "shipmoor $reported"; exit 0; fi
echo "SCAN_ARGS:\$*"
EOF
  chmod +x "$bindir/shipmoor"
}

@test "defaults scope to --staged and forwards --fail-on" {
  seed_cli latest stable
  run "$WRAPPER" --fail-on high
  [ "$status" -eq 0 ]
  [[ "$output" == *"SCAN_ARGS:scan --staged --fail-on high"* ]]
}

@test "an option value is not mistaken for a scan target" {
  # The `high` in `--fail-on high` is a value, so --staged must still be added.
  seed_cli latest stable
  run "$WRAPPER" --no-color --fail-on high --output rep.json
  [ "$status" -eq 0 ]
  [[ "$output" == *"SCAN_ARGS:scan --staged --no-color --fail-on high --output rep.json"* ]]
}

@test "explicit scope is respected (no injected --staged)" {
  seed_cli latest stable
  run "$WRAPPER" --changed --fail-on critical
  [ "$status" -eq 0 ]
  [[ "$output" == *"SCAN_ARGS:scan --changed --fail-on critical"* ]]
  [[ "$output" != *"--staged"* ]]
}

@test "a bare target counts as scope" {
  seed_cli latest stable
  run "$WRAPPER" src/
  [ "$status" -eq 0 ]
  [[ "$output" == *"SCAN_ARGS:scan src/"* ]]
  [[ "$output" != *"--staged"* ]]
}

@test "pinned version reuses the matching cached binary" {
  seed_cli 0.4.0 stable 0.4.0
  run "$WRAPPER" --shipmoor-version=0.4.0 --fail-on high
  [ "$status" -eq 0 ]
  [[ "$output" == *"SCAN_ARGS:scan --staged --fail-on high"* ]]
  [[ "$output" != *"installing shipmoor"* ]]
}

@test "leading v on a pinned version is stripped" {
  seed_cli 0.4.0 stable 0.4.0
  run "$WRAPPER" --shipmoor-version v0.4.0
  [ "$status" -eq 0 ]
  [[ "$output" == *"SCAN_ARGS:scan --staged"* ]]
  [[ "$output" != *"installing shipmoor"* ]]
}

@test "pin with the wrong cached version triggers a (stubbed) install" {
  # Cache claims 0.3.0 but we ask for 0.4.0 -> cache is stale -> install runs.
  seed_cli 0.4.0 stable 0.3.0
  make_stub_installer
  run "$WRAPPER" --shipmoor-version=0.4.0 --fail-on high
  [ "$status" -eq 0 ]
  [[ "$output" == *"installing shipmoor 0.4.0"* ]]
  [[ "$output" == *"SCAN_ARGS:scan --staged --fail-on high"* ]]
}

@test "install path runs when nothing is cached" {
  make_stub_installer
  run "$WRAPPER" --fail-on medium
  [ "$status" -eq 0 ]
  [[ "$output" == *"installing shipmoor latest"* ]]
  [[ "$output" == *"SCAN_ARGS:scan --staged --fail-on medium"* ]]
}

@test "fails clearly when install is impossible and no cache exists" {
  export SHIPMOOR_INSTALL_URL="file://$TMP/does-not-exist.sh"
  run "$WRAPPER" --fail-on high
  [ "$status" -ne 0 ]
  [[ "$output" == *"could not install shipmoor"* ]]
}

@test "system binary is used when opted in and unpinned" {
  local sysdir="$TMP/sysbin"
  mkdir -p "$sysdir"
  cat >"$sysdir/shipmoor" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "version" ]; then echo "shipmoor 9.9.9"; exit 0; fi
echo "SYSTEM_SCAN:$*"
EOF
  chmod +x "$sysdir/shipmoor"
  PATH="$sysdir:$PATH" SHIPMOOR_PRE_COMMIT_USE_SYSTEM=1 run "$WRAPPER" --fail-on high
  [ "$status" -eq 0 ]
  [[ "$output" == *"SYSTEM_SCAN:scan --staged --fail-on high"* ]]
}

# Build a stub installer that the wrapper fetches via file:// and runs. It
# mimics install.sh: it reads SHIPMOOR_INSTALL_DIR and drops a fake binary there.
make_stub_installer() {
  local installer="$TMP/install.sh"
  cat >"$installer" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$SHIPMOOR_INSTALL_DIR"
cat >"$SHIPMOOR_INSTALL_DIR/shipmoor" <<'BIN'
#!/usr/bin/env bash
if [ "$1" = "version" ]; then echo "shipmoor ${SHIPMOOR_VERSION:-latest}"; exit 0; fi
echo "SCAN_ARGS:$*"
BIN
chmod +x "$SHIPMOOR_INSTALL_DIR/shipmoor"
EOF
  export SHIPMOOR_INSTALL_URL="file://$installer"
}
