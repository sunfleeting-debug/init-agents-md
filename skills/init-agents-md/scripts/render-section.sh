#!/usr/bin/env bash
# Render a template file by substituting {{placeholder}} tokens from JSON data.
# Usage: render-section.sh <template-path> <data>
#   <data> may be a JSON literal string or a path to a JSON file (e.g. from
#   process substitution: render-section.sh <tmpl> <(echo "$DATA")).
# Output: rendered template to stdout
# Exit codes: 0 = rendered, 1 = template/python error, 2 = usage error

set -uo pipefail

if [ $# -lt 2 ]; then
    echo "Usage: render-section.sh <template> <data>" >&2
    exit 2
fi

TMPL="$1"
DATA="$2"

if [ ! -f "$TMPL" ]; then
    echo "render-section.sh: template not found: $TMPL" >&2
    exit 1
fi

# Windows bash may pass MSYS (/e/...) or backslash (E:\...) template paths that
# native Windows Python cannot open (MSYS only rewrites argument paths, not
# strings); cygpath -m normalizes both to E:/... mixed mode. On POSIX cygpath
# is absent, so TMPL is used as passed (already /-separated).
if command -v cygpath > /dev/null 2>&1; then
    TMPL=$(cygpath -m "$TMPL")
fi

if ! command -v python3 > /dev/null && ! command -v python > /dev/null; then
    echo "render-section.sh: python not found on PATH" >&2
    exit 1
fi
PY=python3
command -v python3 > /dev/null || PY=python

# $DATA may be a JSON literal string OR a path to a JSON file (process
# substitution passes something like /dev/fd/63). Check the shape first: a
# JSON literal starts with {, [, or ", so it can never be mistaken for a path
# (a cwd file named `true`/`null`/`123` would otherwise be read as data).
# Everything else — including /dev/fd/NN, which starts with / — falls through
# to a -r check, so a pipe works. File contents are read here in bash so native
# Python never has to open an MSYS /dev/fd/... path; the JSON text is handed
# to Python via an env var (not argv) so quotes and Chinese characters cannot
# break parsing.
case "$DATA" in
    '{'*|'['*|'"'*)
        DATA_JSON="$DATA"
        ;;
    *)
        if [ -r "$DATA" ]; then
            DATA_JSON=$(cat "$DATA")
        else
            DATA_JSON="$DATA"
        fi
        ;;
esac

# Template path also travels via env var (not argv), matching the
# detect-python.sh convention: no interpolation, no escaping concerns.
TMPL_FILE="$TMPL" DATA_JSON="$DATA_JSON" $PY - <<'PYEOF'
import os, re, json, sys

# Native Windows Python writes piped stdout in the ANSI code page (e.g. GBK on
# Chinese systems), which mangles template UTF-8 text; force UTF-8 everywhere.
sys.stdout.reconfigure(encoding='utf-8', newline='\n')
sys.stderr.reconfigure(encoding='utf-8')

tmpl_path = os.environ['TMPL_FILE']
try:
    with open(tmpl_path, 'r', encoding='utf-8') as f:
        text = f.read()
except OSError as e:
    print(f"render-section.sh: cannot read template: {tmpl_path}: {e}", file=sys.stderr)
    sys.exit(1)

try:
    data = json.loads(os.environ['DATA_JSON'])
except json.JSONDecodeError as e:
    print(f"render-section.sh: invalid JSON in data argument: {e}", file=sys.stderr)
    sys.exit(1)

# A non-object JSON value (array/string/number/bool/null) has no .get(); reject
# it with a clean message rather than leaking a Python traceback.
if not isinstance(data, dict):
    print(f"render-section.sh: expected a JSON object for data, got: {type(data).__name__}", file=sys.stderr)
    sys.exit(1)


def repl(m):
    key = m.group(1).strip()
    val = data.get(key)
    if val is None:
        # NOTE: keys missing from data keep their {{token}} in the output
        # (whitespace-normalized to {{key}}). This is intentional — templates
        # may contain tokens the caller never supplies, and those tokens are
        # not consumed downstream anyway.
        return f"{{{{{key}}}}}"
    return str(val)


# Match {{ key }} with optional whitespace.
print(re.sub(r"\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}", repl, text))
PYEOF
