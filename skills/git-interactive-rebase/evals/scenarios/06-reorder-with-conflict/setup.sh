#!/bin/bash
# Scenario 06: Reorder commits that cause a conflict
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../lib/setup-helpers.sh"

repo_dir=$(create_test_repo "06-conflict-reorder")

make_commit "$repo_dir" "src/utils.py" \
'def parse(text):
    return text.strip()' \
    "feat: add parse function"

# Modifies parse to add a parameter — depends on commit 1
write_file_and_commit "$repo_dir" "src/utils.py" "feat: add separator param to parse" << 'EOF'
def parse(text, separator=None):
    text = text.strip()
    if separator:
        return text.split(separator)
    return text
EOF

# Adds a new function below parse — context depends on commit 2's version
write_file_and_commit "$repo_dir" "src/utils.py" "feat: add format function" << 'EOF'
def parse(text, separator=None):
    text = text.strip()
    if separator:
        return text.split(separator)
    return text

def format_output(data):
    return str(data).upper()
EOF

echo "$repo_dir"
