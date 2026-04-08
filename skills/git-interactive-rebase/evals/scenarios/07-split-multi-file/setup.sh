#!/bin/bash
# Scenario 07: Split a multi-file commit into separate commits
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../lib/setup-helpers.sh"

repo_dir=$(create_test_repo "07-split-multi")

make_commit "$repo_dir" "README.md" "# My Project" "init: add README"

# Single commit adds two unrelated files — should be split
mkdir -p "$repo_dir/src"
printf '%s\n' 'def parse(text):
    return text.split()' >| "$repo_dir/src/parser.py"
printf '%s\n' 'def format_text(text):
    return text.strip().title()' >| "$repo_dir/src/formatter.py"
git -C "$repo_dir" add src/parser.py src/formatter.py
git -C "$repo_dir" commit -m "feat: add parser and formatter" --quiet

echo "$repo_dir"
