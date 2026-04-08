#!/bin/bash
# Verify scenario 10: Anchor & Pivot
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../lib/verify-helpers.sh"

repo_dir="$1"

check_no_rebase_in_progress "$repo_dir"
check_commit_count "$repo_dir" 3

# Check commit messages
check_commit_messages "$repo_dir" \
    "feat: add pagination to list_items with updated tests" \
    "test: add tests for current list_items behavior" \
    "feat: add items API"

# ANCHOR commit (HEAD~1): should have test file but NO implementation changes
# src/api.py at HEAD~1 should be the ORIGINAL (no pagination)
check_file_contains_at "$repo_dir" 1 "src/api.py" "def list_items(db)"
# Should NOT have offset/limit in the anchor's api.py
if git -C "$repo_dir" show "HEAD~1:src/api.py" | grep -q "offset"; then
    fail "Anchor's src/api.py should not have pagination (offset)"
else
    pass "Anchor's src/api.py has no pagination"
fi

# Anchor should have tests that assert OLD behavior
check_file_contains_at "$repo_dir" 1 "tests/test_api.py" "list_items"
# The anchor tests should reference the old return type (list, not dict)
anchor_tests=$(git -C "$repo_dir" show "HEAD~1:tests/test_api.py")
if echo "$anchor_tests" | grep -qE "(isinstance.*list|not.*dict|returns.*list)"; then
    pass "Anchor tests assert old behavior (list return type)"
else
    # Also accept tests that just don't reference dict/pagination
    if echo "$anchor_tests" | grep -q "offset"; then
        fail "Anchor tests should not reference pagination (offset)"
    else
        pass "Anchor tests don't reference pagination"
    fi
fi

# PIVOT commit (HEAD): should have BOTH implementation changes and updated tests
check_file_contains "$repo_dir" "src/api.py" "offset"
check_file_contains "$repo_dir" "src/api.py" "limit"
check_file_contains "$repo_dir" "tests/test_api.py" "pagination"

# The pivot's tests should be different from the anchor's tests
pivot_tests=$(git -C "$repo_dir" show "HEAD:tests/test_api.py")
if [ "$anchor_tests" = "$pivot_tests" ]; then
    fail "Pivot tests should differ from anchor tests"
else
    pass "Pivot tests differ from anchor tests"
fi

verify_summary
