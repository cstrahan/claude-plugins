#!/bin/bash
# Scenario 02: Drop a commit
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../lib/setup-helpers.sh"

repo_dir=$(create_test_repo "02-drop")

make_commit "$repo_dir" "src/math.py" \
'def add(a, b):
    return a + b' \
    "feat: add math utils"

# Accidental debug commit — should be dropped
make_commit "$repo_dir" "src/debug.py" \
'print("debug mode active")' \
    "DEBUG: temporary logging"

write_file_and_commit "$repo_dir" "src/math.py" "feat: add subtract" << 'EOF'
def add(a, b):
    return a + b

def subtract(a, b):
    return a - b
EOF

echo "$repo_dir"
