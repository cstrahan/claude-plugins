#!/bin/bash
# Verify scenario 05: Squash with custom message
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../lib/verify-helpers.sh"

repo_dir="$1"

check_no_rebase_in_progress "$repo_dir"
check_commit_count "$repo_dir" 2
check_commit_messages "$repo_dir" \
    "feat: add logging" \
    "feat: add authentication module with token support"

# auth.py at HEAD~1 should have all three functions
check_file_contains_at "$repo_dir" 1 "src/auth.py" "def login"
check_file_contains_at "$repo_dir" 1 "src/auth.py" "def generate_token"
check_file_contains_at "$repo_dir" 1 "src/auth.py" "def validate_token"

# logger.py at HEAD
check_file_contains "$repo_dir" "src/logger.py" "def log"

verify_summary
