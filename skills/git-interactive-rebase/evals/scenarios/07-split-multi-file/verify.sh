#!/bin/bash
# Verify scenario 07: Split multi-file commit
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../lib/verify-helpers.sh"

repo_dir="$1"

check_no_rebase_in_progress "$repo_dir"
check_commit_count "$repo_dir" 3
check_commit_messages "$repo_dir" \
    "feat: add formatter" \
    "feat: add parser" \
    "init: add README"

# Each split commit should touch exactly one file
# Parser commit (HEAD~1) should have parser.py but not formatter.py
check_file_contains_at "$repo_dir" 1 "src/parser.py" "def parse"
# formatter.py should NOT exist at HEAD~1
if git -C "$repo_dir" show "HEAD~1:src/formatter.py" >/dev/null 2>&1; then
    fail "src/formatter.py should not exist at HEAD~1 (parser commit)"
else
    pass "src/formatter.py correctly absent at HEAD~1"
fi

# Formatter commit (HEAD) should have both files
check_file_contains "$repo_dir" "src/formatter.py" "def format_text"
check_file_contains "$repo_dir" "src/parser.py" "def parse"

verify_summary
