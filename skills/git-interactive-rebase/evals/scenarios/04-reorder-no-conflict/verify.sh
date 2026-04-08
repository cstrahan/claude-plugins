#!/bin/bash
# Verify scenario 04: Reorder (no conflict)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../lib/verify-helpers.sh"

repo_dir="$1"

check_no_rebase_in_progress "$repo_dir"
check_commit_count "$repo_dir" 3
check_commit_messages "$repo_dir" \
    "feat: add product model" \
    "feat: add order model" \
    "feat: add user model"

# All files should exist
check_file_contains "$repo_dir" "src/models/user.py" "class User"
check_file_contains "$repo_dir" "src/models/product.py" "class Product"
check_file_contains "$repo_dir" "src/models/order.py" "class Order"

verify_summary
