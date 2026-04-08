#!/bin/bash
# Verify scenario 08: Split same-file changes
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../lib/verify-helpers.sh"

repo_dir="$1"

check_no_rebase_in_progress "$repo_dir"
check_commit_count "$repo_dir" 3
check_commit_messages "$repo_dir" \
    "feat: add multiply function" \
    "refactor: rename add to sum" \
    "feat: add calculator with add function"

# Original commit: has "add" function
check_file_contains_at "$repo_dir" 2 "src/calc.py" "def add"

# Refactor commit (HEAD~1): has "sum" but NOT "multiply"
check_file_contains_at "$repo_dir" 1 "src/calc.py" "def sum"
if git -C "$repo_dir" show "HEAD~1:src/calc.py" | grep -q "def multiply"; then
    fail "HEAD~1 should not contain multiply (intermediate state)"
else
    pass "HEAD~1 correctly has no multiply function"
fi

# Final commit (HEAD): has both "sum" and "multiply"
check_file_contains "$repo_dir" "src/calc.py" "def sum"
check_file_contains "$repo_dir" "src/calc.py" "def multiply"

verify_summary
