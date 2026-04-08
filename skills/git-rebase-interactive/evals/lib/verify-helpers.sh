#!/bin/bash
# Shared functions for verifying rebase results

VERIFY_PASS=0
VERIFY_FAIL=0

pass() {
    VERIFY_PASS=$((VERIFY_PASS + 1))
    echo "  PASS: $1"
}

fail() {
    VERIFY_FAIL=$((VERIFY_FAIL + 1))
    echo "  FAIL: $1"
}

# Check no rebase in progress
check_no_rebase_in_progress() {
    local repo_dir="$1"
    if [ -d "${repo_dir}/.git/rebase-merge" ] || [ -d "${repo_dir}/.git/rebase-apply" ]; then
        fail "Rebase still in progress"
    else
        pass "No rebase in progress"
    fi
}

# Check exact commit count from HEAD to root
check_commit_count() {
    local repo_dir="$1" expected="$2"
    local actual
    actual=$(git -C "$repo_dir" rev-list --count HEAD)
    if [ "$actual" -eq "$expected" ]; then
        pass "Commit count: $actual"
    else
        fail "Expected $expected commits, got $actual"
    fi
}

# Check commit messages match (newest first)
# Usage: check_commit_messages <repo_dir> "newest msg" "second newest" ...
check_commit_messages() {
    local repo_dir="$1"; shift
    local i=0
    for expected_msg in "$@"; do
        local actual_msg
        actual_msg=$(git -C "$repo_dir" log --format=%s --skip=$i -1)
        if [ "$actual_msg" = "$expected_msg" ]; then
            pass "Commit $i message: $actual_msg"
        else
            fail "Commit $i message: expected '$expected_msg', got '$actual_msg'"
        fi
        i=$((i + 1))
    done
}

# Check file content at HEAD matches expected string
check_file_content() {
    local repo_dir="$1" file="$2" expected="$3"
    local actual
    actual=$(git -C "$repo_dir" show "HEAD:$file" 2>/dev/null) || {
        fail "File $file does not exist at HEAD"
        return
    }
    if [ "$actual" = "$expected" ]; then
        pass "File $file content at HEAD"
    else
        fail "File $file content mismatch at HEAD"
        echo "    Expected: $(echo "$expected" | head -3)..."
        echo "    Actual:   $(echo "$actual" | head -3)..."
    fi
}

# Check file content at HEAD~N
check_file_content_at() {
    local repo_dir="$1" offset="$2" file="$3" expected="$4"
    local actual ref="HEAD~${offset}"
    [ "$offset" -eq 0 ] && ref="HEAD"
    actual=$(git -C "$repo_dir" show "${ref}:${file}" 2>/dev/null) || {
        fail "File $file does not exist at $ref"
        return
    }
    if [ "$actual" = "$expected" ]; then
        pass "File $file content at $ref"
    else
        fail "File $file content mismatch at $ref"
        echo "    Expected: $(echo "$expected" | head -3)..."
        echo "    Actual:   $(echo "$actual" | head -3)..."
    fi
}

# Check file does NOT exist at HEAD
check_file_not_exists() {
    local repo_dir="$1" file="$2"
    if git -C "$repo_dir" show "HEAD:$file" >/dev/null 2>&1; then
        fail "File $file should not exist at HEAD but does"
    else
        pass "File $file correctly absent at HEAD"
    fi
}

# Check file contains a substring at HEAD
check_file_contains() {
    local repo_dir="$1" file="$2" substring="$3"
    local content
    content=$(git -C "$repo_dir" show "HEAD:$file" 2>/dev/null) || {
        fail "File $file does not exist at HEAD"
        return
    }
    if echo "$content" | grep -qF "$substring"; then
        pass "File $file contains '$substring'"
    else
        fail "File $file does not contain '$substring'"
    fi
}

# Check file contains a substring at HEAD~N
check_file_contains_at() {
    local repo_dir="$1" offset="$2" file="$3" substring="$4"
    local content ref="HEAD~${offset}"
    [ "$offset" -eq 0 ] && ref="HEAD"
    content=$(git -C "$repo_dir" show "${ref}:${file}" 2>/dev/null) || {
        fail "File $file does not exist at $ref"
        return
    }
    if echo "$content" | grep -qF "$substring"; then
        pass "File $file contains '$substring' at $ref"
    else
        fail "File $file does not contain '$substring' at $ref"
    fi
}

# Print summary and exit with appropriate code
verify_summary() {
    echo ""
    echo "Results: $VERIFY_PASS passed, $VERIFY_FAIL failed"
    [ "$VERIFY_FAIL" -eq 0 ]
}
