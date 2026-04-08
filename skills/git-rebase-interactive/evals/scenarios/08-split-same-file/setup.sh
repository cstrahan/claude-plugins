#!/bin/bash
# Scenario 08: Split changes within the same file
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../lib/setup-helpers.sh"

repo_dir=$(create_test_repo "08-split-samefile")

make_commit "$repo_dir" "src/calc.py" \
'def add(a, b):
    return a + b' \
    "feat: add calculator with add function"

# This commit does two things: renames add->sum AND adds multiply
# These should be split into separate commits
write_file_and_commit "$repo_dir" "src/calc.py" "refactor+feat: rename add to sum and add multiply" << 'EOF'
def sum(a, b):
    return a + b

def multiply(a, b):
    return a * b
EOF

echo "$repo_dir"
