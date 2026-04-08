#!/bin/bash
# Scenario 01: Simple fixup — absorb a fix commit into a feature commit
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../lib/setup-helpers.sh"

repo_dir=$(create_test_repo "01-fixup")

make_commit "$repo_dir" "src/greet.py" \
'def greet(name):
    return f"Hello, {name}"' \
    "feat: add greeting module"

# This fix should be absorbed into the feat commit
write_file_and_commit "$repo_dir" "src/greet.py" "fix: handle empty name" << 'EOF'
def greet(name):
    if not name:
        return "Hello, stranger"
    return f"Hello, {name}"
EOF

make_commit "$repo_dir" "README.md" "# Greeting Module" "chore: add README"

echo "$repo_dir"
