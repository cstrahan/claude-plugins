#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_PATH="$(cd "$SCRIPT_DIR/.." && pwd)/SKILL.md"
RESULTS_DIR="$SCRIPT_DIR/results"
SCENARIOS_DIR="$SCRIPT_DIR/scenarios"

source "$SCRIPT_DIR/lib/setup-helpers.sh"
source "$SCRIPT_DIR/lib/run-agent.sh"
source "$SCRIPT_DIR/lib/verify-helpers.sh"

# Parse args
SCENARIOS="${1:-all}"
MODEL="${2:-sonnet}"

mkdir -p "$RESULTS_DIR"

run_scenario() {
    local scenario_dir="$1"
    local scenario_name
    scenario_name=$(basename "$scenario_dir")
    local result_dir="$RESULTS_DIR/$scenario_name"
    rm -rf "$result_dir"
    mkdir -p "$result_dir"

    echo "========================================"
    echo "Running: $scenario_name"
    echo "========================================"

    # Phase 1: Setup — create the temp repo
    echo "  Setting up repo..."
    local repo_dir
    repo_dir=$(bash "$scenario_dir/setup.sh")
    echo "  Repo: $repo_dir"

    # Capture initial state for debugging
    git -C "$repo_dir" log --oneline > "$result_dir/initial-log.txt"
    echo "  Initial commits:"
    sed 's/^/    /' "$result_dir/initial-log.txt"

    # Phase 2: Run agent
    echo "  Running agent (model: $MODEL)..."
    local agent_start agent_end agent_duration
    agent_start=$(date +%s)
    run_agent "$repo_dir" "$scenario_dir/prompt.txt" "$result_dir/agent-output.json" "$SKILL_PATH" "$MODEL" || true
    local agent_exit=$?
    agent_end=$(date +%s)
    agent_duration=$((agent_end - agent_start))
    echo "  Agent finished in ${agent_duration}s (exit: $agent_exit)"

    # Extract readable output
    extract_result_text "$result_dir/agent-output.json" > "$result_dir/agent-transcript.txt" 2>/dev/null || true

    # Capture final state
    git -C "$repo_dir" log --oneline > "$result_dir/final-log.txt" 2>/dev/null || echo "(no commits)" > "$result_dir/final-log.txt"
    echo "  Final commits:"
    sed 's/^/    /' "$result_dir/final-log.txt"

    # Phase 3: Verify
    echo "  Verifying..."
    bash "$scenario_dir/verify.sh" "$repo_dir" 2>&1 | tee "$result_dir/verify-output.txt"

    # Phase 4: Record result — check verify output for any FAIL lines
    local status="pass"
    if grep -q "^  FAIL:" "$result_dir/verify-output.txt"; then
        status="fail"
    fi
    local verify_exit=0
    [ "$status" = "fail" ] && verify_exit=1

    cat > "$result_dir/result.json" << RESULT_EOF
{
  "scenario": "$scenario_name",
  "status": "$status",
  "agent_exit": $agent_exit,
  "verify_exit": $verify_exit,
  "duration_seconds": $agent_duration,
  "model": "$MODEL"
}
RESULT_EOF

    echo "  Result: $status"
    echo ""

    # Phase 5: Cleanup temp repo
    rm -rf "$repo_dir"
}

# Collect scenarios to run
scenarios=()
if [ "$SCENARIOS" = "all" ]; then
    for d in "$SCENARIOS_DIR"/*/; do
        [ -f "$d/setup.sh" ] || continue
        scenarios+=("$d")
    done
else
    IFS=',' read -ra names <<< "$SCENARIOS"
    for name in "${names[@]}"; do
        scenarios+=("$SCENARIOS_DIR/$name")
    done
fi

if [ ${#scenarios[@]} -eq 0 ]; then
    echo "No scenarios found."
    exit 1
fi

echo "Running ${#scenarios[@]} scenario(s) with model: $MODEL"
echo "Skill: $SKILL_PATH"
echo ""

# Run scenarios
for scenario in "${scenarios[@]}"; do
    run_scenario "$scenario"
done

# Aggregate summary
echo "========================================"
echo "Summary"
echo "========================================"
pass=0; fail=0; total=0
for result_file in "$RESULTS_DIR"/*/result.json; do
    [ -f "$result_file" ] || continue
    total=$((total + 1))
    name=$(basename "$(dirname "$result_file")")
    status=$(python3 -c "import json; print(json.load(open('$result_file'))['status'])")
    duration=$(python3 -c "import json; print(json.load(open('$result_file'))['duration_seconds'])")
    if [ "$status" = "pass" ]; then
        pass=$((pass + 1))
        echo "  PASS  ${name} (${duration}s)"
    else
        fail=$((fail + 1))
        echo "  FAIL  ${name} (${duration}s)"
    fi
done
echo ""
echo "Total: $total  Pass: $pass  Fail: $fail"
