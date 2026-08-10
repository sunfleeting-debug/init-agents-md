#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/helpers.sh"

DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Create a temp scripts dir with one valid and one invalid script
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

cat > "$TMPDIR/valid.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo hello
EOF
chmod +x "$TMPDIR/valid.sh"

cat > "$TMPDIR/invalid.sh" <<'EOF'
#!/usr/bin/env bash
if [ x = y
EOF
chmod +x "$TMPDIR/invalid.sh"

# Valid script: exit 0
# NOTE: scripts are invoked via `bash ...` — on Windows/Git Bash git stores
# them without the exec bit (mode 100644), so direct execution is not reliable.
bash "$DIR/scripts/dry-run-validate.sh" "$TMPDIR/valid.sh" > /dev/null
assert_eq "$?" "0" "valid script: validation passes"

# Invalid script: exit non-zero
# NOTE: no set +e / set -e dance needed — this test runs with set -uo pipefail
# (no -e), so rc=$? after a failing command is safe.
bash "$DIR/scripts/dry-run-validate.sh" "$TMPDIR/invalid.sh" > /dev/null 2>&1
rc=$?
[ "$rc" -ne 0 ] && pass "invalid script: validation fails" || fail "invalid script: validation should fail (rc=$rc)"

# Check 3: tool-on-PATH checks emit stable output lines. The temp script only
# references the tool in a comment so the --help dry run has no side effects.
# npm is on PATH in any Git Bash environment — assert the OK line for it.
cat > "$TMPDIR/tools-ok.sh" <<'EOF'
#!/usr/bin/env bash
# this script runs npm
echo ok
EOF
OUT=$(bash "$DIR/scripts/dry-run-validate.sh" "$TMPDIR/tools-ok.sh")
assert_contains "$OUT" "OK: npm is on PATH" "Check 3: npm on PATH reported OK"

# WARN line for the first checked tool genuinely absent on this machine
# (PATH contents vary across environments, so pick the tool at runtime).
for absent in gradle pytest yarn; do
    if ! command -v "$absent" > /dev/null 2>&1; then
        cat > "$TMPDIR/tools-warn.sh" <<EOF
#!/usr/bin/env bash
# this script runs $absent
echo ok
EOF
        OUT=$(bash "$DIR/scripts/dry-run-validate.sh" "$TMPDIR/tools-warn.sh")
        assert_contains "$OUT" "WARN: $absent not on PATH (script may fail at runtime)" "Check 3: absent $absent reported WARN"
        break
    fi
done
