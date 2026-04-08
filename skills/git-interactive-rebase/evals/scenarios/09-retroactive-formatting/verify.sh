#!/bin/bash
# Verify scenario 09: Retroactive formatting
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../lib/verify-helpers.sh"

repo_dir="$1"

check_no_rebase_in_progress "$repo_dir"
check_commit_count "$repo_dir" 4

# Check that each commit with math.py has formatted code
# Formatted means: "def add(a, b)" not "def add(a,b)"
for offset in 0 1 2; do
    ref="HEAD~${offset}"
    content=$(git -C "$repo_dir" show "${ref}:src/math.py" 2>/dev/null)
    if echo "$content" | grep -q "def add(a,b)"; then
        fail "src/math.py at $ref is NOT formatted (missing space after comma)"
    else
        pass "src/math.py at $ref is formatted"
    fi
    if echo "$content" | grep -q "return a+b"; then
        fail "src/math.py at $ref is NOT formatted (missing spaces around +)"
    else
        pass "src/math.py at $ref has formatted operators"
    fi
done

# Check commit messages are preserved
check_commit_messages "$repo_dir" \
    "feat: add multiply" \
    "feat: add subtract" \
    "feat: add math module" \
    "chore: add formatter script"

verify_summary
