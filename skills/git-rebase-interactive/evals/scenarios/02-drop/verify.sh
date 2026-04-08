#!/bin/bash
# Verify scenario 02: Drop a commit
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../lib/verify-helpers.sh"

repo_dir="$1"

check_no_rebase_in_progress "$repo_dir"
check_commit_count "$repo_dir" 2
check_commit_messages "$repo_dir" \
    "feat: add subtract" \
    "feat: add math utils"

# debug.py should not exist
check_file_not_exists "$repo_dir" "src/debug.py"

# math.py should have both functions at HEAD
check_file_contains "$repo_dir" "src/math.py" "def add(a, b)"
check_file_contains "$repo_dir" "src/math.py" "def subtract(a, b)"

verify_summary
