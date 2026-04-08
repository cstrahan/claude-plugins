#!/bin/bash
# Verify scenario 03: Reword multiple commits
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../lib/verify-helpers.sh"

repo_dir="$1"

check_no_rebase_in_progress "$repo_dir"
check_commit_count "$repo_dir" 2
check_commit_messages "$repo_dir" \
    "feat: add server module" \
    "feat: add default configuration"

# File contents should be unchanged
check_file_contains "$repo_dir" "src/config.py" "DEFAULT_PORT = 8080"
check_file_contains "$repo_dir" "src/server.py" "from config import"

verify_summary
