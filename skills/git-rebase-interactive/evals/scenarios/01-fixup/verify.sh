#!/bin/bash
# Verify scenario 01: Simple fixup
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../lib/verify-helpers.sh"

repo_dir="$1"

check_no_rebase_in_progress "$repo_dir"
check_commit_count "$repo_dir" 2
check_commit_messages "$repo_dir" \
    "chore: add README" \
    "feat: add greeting module"

# The fixup should have merged the empty-name guard into the feat commit
check_file_contains_at "$repo_dir" 1 "src/greet.py" "if not name"
check_file_contains_at "$repo_dir" 1 "src/greet.py" "Hello, stranger"
check_file_contains_at "$repo_dir" 1 "src/greet.py" 'def greet(name)'

# README should be at HEAD
check_file_content "$repo_dir" "README.md" "# Greeting Module"

verify_summary
