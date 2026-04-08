#!/bin/bash
# Shared functions for creating test repos

create_test_repo() {
    local name="$1"
    local repo_dir
    repo_dir=$(mktemp -d "/tmp/rebase-eval-${name}-XXXXXX")
    git -C "$repo_dir" init --quiet
    git -C "$repo_dir" config user.email "test@eval.local"
    git -C "$repo_dir" config user.name "Test User"
    echo "$repo_dir"
}

# Create a file and commit it
# Usage: make_commit <repo_dir> <file> <content> <message>
make_commit() {
    local repo_dir="$1" file="$2" content="$3" message="$4"
    mkdir -p "$repo_dir/$(dirname "$file")"
    printf '%s\n' "$content" >| "$repo_dir/$file"
    git -C "$repo_dir" add "$file"
    git -C "$repo_dir" commit -m "$message" --quiet
}

# Append content to a file and commit
# Usage: append_and_commit <repo_dir> <file> <content> <message>
append_and_commit() {
    local repo_dir="$1" file="$2" content="$3" message="$4"
    printf '\n%s\n' "$content" >> "$repo_dir/$file"
    git -C "$repo_dir" add "$file"
    git -C "$repo_dir" commit -m "$message" --quiet
}

# Write exact content to a file and commit (for multi-line content via heredoc)
# Usage: write_file_and_commit <repo_dir> <file> <message> <<'EOF' ... EOF
write_file_and_commit() {
    local repo_dir="$1" file="$2" message="$3"
    mkdir -p "$repo_dir/$(dirname "$file")"
    cat >| "$repo_dir/$file"
    git -C "$repo_dir" add "$file"
    git -C "$repo_dir" commit -m "$message" --quiet
}
