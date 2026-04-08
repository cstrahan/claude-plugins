#!/bin/bash
# Scenario 09: Retroactive formatting across multiple commits
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../lib/setup-helpers.sh"

repo_dir=$(create_test_repo "09-retro-format")

# Create a simple formatter script in the repo
mkdir -p "$repo_dir/tools"
cat >| "$repo_dir/tools/format.sh" << 'FORMATTER'
#!/bin/bash
# Simple Python formatter: spaces around operators, after commas in defs
for f in "$@"; do
    [ -f "$f" ] || continue
    python3 -c "
import re, sys
c = open(sys.argv[1]).read()
c = re.sub(r'def (\w+)\((\w+),(\w+)\)', r'def \1(\2, \3)', c)
c = re.sub(r'def (\w+)\((\w+),(\w+),(\w+)\)', r'def \1(\2, \3, \4)', c)
c = re.sub(r'return (\w+)\+(\w+)', r'return \1 + \2', c)
c = re.sub(r'return (\w+)-(\w+)', r'return \1 - \2', c)
c = re.sub(r'return (\w+)\*(\w+)', r'return \1 * \2', c)
open(sys.argv[1], 'w').write(c)
" "$f"
done
FORMATTER
chmod +x "$repo_dir/tools/format.sh"
git -C "$repo_dir" add tools/format.sh
git -C "$repo_dir" commit -m "chore: add formatter script" --quiet

# Unformatted commits
make_commit "$repo_dir" "src/math.py" \
'def add(a,b):
    return a+b' \
    "feat: add math module"

write_file_and_commit "$repo_dir" "src/math.py" "feat: add subtract" << 'EOF'
def add(a,b):
    return a+b

def subtract(a,b):
    return a-b
EOF

write_file_and_commit "$repo_dir" "src/math.py" "feat: add multiply" << 'EOF'
def add(a,b):
    return a+b

def subtract(a,b):
    return a-b

def multiply(a,b):
    return a*b
EOF

echo "$repo_dir"
