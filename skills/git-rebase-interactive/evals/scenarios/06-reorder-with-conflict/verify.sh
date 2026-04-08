#!/bin/bash
# Verify scenario 06: Reorder with conflict
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../lib/verify-helpers.sh"

repo_dir="$1"

check_no_rebase_in_progress "$repo_dir"
check_commit_count "$repo_dir" 3
check_commit_messages "$repo_dir" \
    "feat: add separator param to parse" \
    "feat: add format function" \
    "feat: add parse function"

# Final file should have all functionality
check_file_contains "$repo_dir" "src/utils.py" "def parse(text, separator=None)"
check_file_contains "$repo_dir" "src/utils.py" "def format_output(data)"
check_file_contains "$repo_dir" "src/utils.py" "text.split(separator)"

verify_summary
