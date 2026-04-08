#!/bin/bash
# Scenario 03: Reword multiple commit messages
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../lib/setup-helpers.sh"

repo_dir=$(create_test_repo "03-reword")

make_commit "$repo_dir" "src/config.py" \
'DEFAULT_PORT = 8080
DEFAULT_HOST = "localhost"' \
    "add stuff"

make_commit "$repo_dir" "src/server.py" \
'from config import DEFAULT_PORT, DEFAULT_HOST

def start():
    print(f"Starting on {DEFAULT_HOST}:{DEFAULT_PORT}")' \
    "more stuff"

echo "$repo_dir"
