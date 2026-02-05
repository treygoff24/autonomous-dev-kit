#!/usr/bin/env bash
#
# Run fixed canary evals for harness regression tracking.
# Prints the generated report path on stdout.
#

set -euo pipefail

EVAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$EVAL_DIR/../.." && pwd)"
CASES_FILE="$EVAL_DIR/cases.json"
REPORT_DIR="${CANARY_REPORT_DIR:-$EVAL_DIR/reports}"

mkdir -p "$REPORT_DIR"

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
report_name="$(date -u +"%Y%m%d-%H%M%S").json"
report_path="$REPORT_DIR/$report_name"
git_sha=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")

results_json="[]"

while IFS= read -r case_row; do
    case_id=$(echo "$case_row" | jq -r '.id')
    description=$(echo "$case_row" | jq -r '.description')
    command=$(echo "$case_row" | jq -r '.command')

    set +e
    (cd "$REPO_ROOT" && bash -lc "$command") > /dev/null 2>&1
    exit_code=$?
    set -e

    if [[ "$exit_code" -eq 0 ]]; then
        status="pass"
    else
        status="fail"
    fi

    results_json=$(echo "$results_json" | jq \
        --arg id "$case_id" \
        --arg description "$description" \
        --arg command "$command" \
        --arg status "$status" \
        --argjson exit_code "$exit_code" \
        '. + [{
            id: $id,
            description: $description,
            command: $command,
            status: $status,
            exit_code: $exit_code
        }]')
done < <(jq -c '.cases[]' "$CASES_FILE")

total=$(echo "$results_json" | jq 'length')
passed=$(echo "$results_json" | jq '[.[] | select(.status == "pass")] | length')
failed=$((total - passed))

if [[ "$total" -eq 0 ]]; then
    pass_rate=0
else
    pass_rate=$(awk -v p="$passed" -v t="$total" 'BEGIN { printf "%.2f", (p / t) * 100 }')
fi

jq -n \
    --arg timestamp "$timestamp" \
    --arg git_sha "$git_sha" \
    --argjson total "$total" \
    --argjson passed "$passed" \
    --argjson failed "$failed" \
    --argjson pass_rate "$pass_rate" \
    --argjson results "$results_json" \
    '{
        timestamp: $timestamp,
        git_sha: $git_sha,
        summary: {
            total: $total,
            passed: $passed,
            failed: $failed,
            pass_rate: $pass_rate
        },
        results: $results
    }' > "$report_path"

echo "$report_path"
