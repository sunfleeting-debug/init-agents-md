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
