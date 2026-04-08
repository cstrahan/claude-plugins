#!/bin/bash
# Wraps claude -p invocation for eval scenarios

# Usage: run_agent <repo_dir> <prompt_file> <output_file> <skill_path> [model]
run_agent() {
    local repo_dir="$1"
    local prompt_file="$2"
    local output_file="$3"
    local skill_path="$4"
    local model="${5:-sonnet}"

    local task_prompt
    task_prompt=$(cat "$prompt_file")

    local full_prompt="You have access to a git repository at ${repo_dir}.

IMPORTANT: Before doing anything else, read the skill file at ${skill_path}.
It contains critical guidance for performing git interactive rebases programmatically
in Claude Code. Read it thoroughly before planning your approach.

Then examine the repository's commit history and file contents.

YOUR TASK:
${task_prompt}

WHEN FINISHED:
Write a REASONING section explaining:
1. What approach you chose and why
2. Any difficulties or confusion you encountered
3. Whether the skill file's guidance was clear and sufficient"

    # Write prompt to a temp file to avoid shell quoting issues
    local prompt_tmp
    prompt_tmp=$(mktemp)
    printf '%s' "$full_prompt" >| "$prompt_tmp"

    # --disable-slash-commands: no skills pre-loaded (agent reads SKILL.md manually)
    # --dangerously-skip-permissions: no interactive prompts
    # --tools: only Bash and Read (no Edit/Write — rebases are done via bash)
    # env -u CLAUDECODE: allow nested claude invocation
    env -u CLAUDECODE claude -p \
        --disable-slash-commands \
        --dangerously-skip-permissions \
        --output-format json \
        --model "$model" \
        --max-budget-usd 1.00 \
        --add-dir "$repo_dir" \
        --add-dir "$(dirname "$skill_path")" \
        --tools "Bash,Read" \
        < "$prompt_tmp" \
        > "$output_file" 2>&1

    local exit_code=$?
    rm -f "$prompt_tmp"
    return $exit_code

    return $?
}

# Extract the text result from claude -p JSON output
extract_result_text() {
    local output_file="$1"
    python3 -c "
import json, sys
try:
    data = json.load(open(sys.argv[1]))
    if isinstance(data, dict) and 'result' in data:
        print(data['result'])
    elif isinstance(data, dict) and 'content' in data:
        for block in data['content']:
            if block.get('type') == 'text':
                print(block['text'])
    else:
        print(json.dumps(data, indent=2))
except Exception as e:
    print(f'Error parsing output: {e}', file=sys.stderr)
    sys.exit(1)
" "$output_file"
}
