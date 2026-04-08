#!/bin/bash
# Scenario 05: Squash with custom message
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../lib/setup-helpers.sh"

repo_dir=$(create_test_repo "05-squash")

make_commit "$repo_dir" "src/auth.py" \
'def login(user, password):
    pass' \
    "wip: start auth module"

write_file_and_commit "$repo_dir" "src/auth.py" "wip: add token generation" << 'EOF'
def login(user, password):
    pass

def generate_token(user):
    return "token_" + user
EOF

write_file_and_commit "$repo_dir" "src/auth.py" "wip: add token validation" << 'EOF'
def login(user, password):
    pass

def generate_token(user):
    return "token_" + user

def validate_token(token):
    return token.startswith("token_")
EOF

make_commit "$repo_dir" "src/logger.py" \
'def log(msg):
    print(f"[LOG] {msg}")' \
    "feat: add logging"

echo "$repo_dir"
