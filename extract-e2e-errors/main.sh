#!/bin/bash
# Extract E2E test errors from GitHub Actions run
# Usage: ./extract-e2e-errors.sh [RUN_ID] [TEST_TYPE] [APPLICATION] [ENVIRONMENT] [ATTEMPT]
# 
# Interactive mode: Run without arguments to get prompted for each option
# Non-interactive: Pass arguments directly
#
# Examples:
#   ./extract-e2e-errors.sh                                       # interactive mode
#   ./extract-e2e-errors.sh 21502793220                           # all failures (latest attempt)
#   ./extract-e2e-errors.sh 21502793220 js-api                    # js-api only
#   ./extract-e2e-errors.sh 21502793220 js-api schedule           # js-api schedule app
#   ./extract-e2e-errors.sh 21502793220 all all all 2             # attempt 2

REPO="garoon-private/garoon"

# Available options
TEST_TYPES=("all" "js-api" "rest-api" "soap-api" "acceptance" "mobile")
ENVIRONMENTS=("all" "cloud" "on-premises" "cloud-for-neco")
APPLICATIONS=("all" "schedule" "workflow" "mail" "message" "bulletin" "board" "cabinet" "report" "phone" "space" "timecard" "presence" "notification" "portal" "address" "system" "others")

# Helper function to display menu and get selection
select_option() {
  local prompt="$1"
  shift
  local options=("$@")
  local PS3="$prompt "
  
  select opt in "${options[@]}"; do
    if [ -n "$opt" ]; then
      if [ "$opt" = "all" ]; then
        echo ""
      else
        echo "$opt"
      fi
      break
    else
      echo "Invalid selection. Please try again." >&2
    fi
  done
}

# Check if running interactively (no arguments provided)
if [ $# -eq 0 ]; then
  echo "=== E2E Error Extraction ==="
  echo ""
  
  # Prompt for RUN_ID
  read -p "Enter GitHub Actions Run ID: " RUN_ID
  if [ -z "$RUN_ID" ]; then
    echo "Error: Run ID is required."
    exit 1
  fi
  
  # Prompt for ATTEMPT
  read -p "Enter attempt number (leave empty for latest): " ATTEMPT
  
  # Prompt for TEST_TYPE
  echo ""
  echo "Select TEST TYPE:"
  TEST_TYPE=$(select_option "Choose test type:" "${TEST_TYPES[@]}")
  
  # Prompt for ENVIRONMENT
  echo ""
  echo "Select ENVIRONMENT:"
  ENVIRONMENT=$(select_option "Choose environment:" "${ENVIRONMENTS[@]}")
  
  # Prompt for APPLICATION
  echo ""
  echo "Select APPLICATION:"
  APPLICATION=$(select_option "Choose application:" "${APPLICATIONS[@]}")
  
  echo ""
  echo "----------------------------------------"
  echo "Configuration:"
  echo "  Run ID:      $RUN_ID"
  echo "  Attempt:     ${ATTEMPT:-latest}"
  echo "  Test Type:   ${TEST_TYPE:-all}"
  echo "  Environment: ${ENVIRONMENT:-all}"
  echo "  Application: ${APPLICATION:-all}"
  echo "----------------------------------------"
  echo ""
  read -p "Proceed with these settings? (Y/n): " confirm
  if [[ "$confirm" =~ ^[Nn] ]]; then
    echo "Aborted."
    exit 0
  fi
else
  # Non-interactive mode - use command line arguments
  RUN_ID="${1:-}"
  TEST_TYPE="${2:-}"   # js-api, rest-api, soap-api, acceptance, mobile
  APPLICATION="${3:-}" # schedule, workflow, mail, message, etc.
  ENVIRONMENT="${4:-}" # cloud, on-premises, cloud-for-neco
  ATTEMPT="${5:-}"     # attempt number (1, 2, 3, etc.)
  
  if [ -z "$RUN_ID" ]; then
    echo "Usage: $0 [RUN_ID] [TEST_TYPE] [APPLICATION] [ENVIRONMENT] [ATTEMPT]"
    echo ""
    echo "Run without arguments for interactive mode."
    echo ""
    echo "TEST_TYPE:   js-api, rest-api, soap-api, acceptance, mobile (or 'all')"
    echo "APPLICATION: schedule, workflow, mail, message, bulletin, board, cabinet,"
    echo "             report, phone, space, timecard, presence, notification, portal (or 'all')"
    echo "ENVIRONMENT: cloud, on-premises, cloud-for-neco (or 'all')"
    echo "ATTEMPT:     attempt number (1, 2, 3...) or empty for latest"
    echo ""
    echo "Examples:"
    echo "  $0                             # interactive mode"
    echo "  $0 12345                       # all failures (latest attempt)"
    echo "  $0 12345 js-api                # js-api all apps all envs"
    echo "  $0 12345 js-api schedule       # js-api schedule all envs"
    echo "  $0 12345 all all all 2         # attempt 2, all filters"
    exit 1
  fi
  
  # Handle "all" keyword in non-interactive mode
  [ "$TEST_TYPE" = "all" ] && TEST_TYPE=""
  [ "$APPLICATION" = "all" ] && APPLICATION=""
  [ "$ENVIRONMENT" = "all" ] && ENVIRONMENT=""
fi

# Build attempt flag for gh commands
ATTEMPT_FLAG=""
if [ -n "$ATTEMPT" ]; then
  ATTEMPT_FLAG="--attempt $ATTEMPT"
fi

if [ -n "$ATTEMPT" ]; then
  OUTPUT_DIR="e2e-errors-${RUN_ID}-attempt${ATTEMPT}"
else
  OUTPUT_DIR="e2e-errors-${RUN_ID}"
fi
LOGS_DIR="$OUTPUT_DIR/logs"
mkdir -p "$LOGS_DIR"

echo "=== E2E Error Extraction ==="
echo "Run: $RUN_ID (attempt: ${ATTEMPT:-latest})"
echo "Filter: type=${TEST_TYPE:-all} env=${ENVIRONMENT:-all} app=${APPLICATION:-all}"
echo ""

# Build jq filter
build_filter() {
  local filter='.jobs[] | select(.conclusion == "failure")'
  filter="$filter | select(.name | test(\"\\\\(\\\\d+\\\\)\"))"

  if [ -n "$TEST_TYPE" ]; then
    filter="$filter | select(.name | test(\" $TEST_TYPE \"))"
  fi

  if [ -n "$ENVIRONMENT" ]; then
    filter="$filter | select(.name | test(\"^e2e-test-$ENVIRONMENT \"))"
  fi

  filter="$filter | {name: .name, id: .databaseId}"
  echo "$filter"
}

echo "Fetching failed jobs..."
gh run view "$RUN_ID" --repo "$REPO" $ATTEMPT_FLAG --json jobs --jq "$(build_filter)" > "$OUTPUT_DIR/failed-jobs.json"

if [ ! -s "$OUTPUT_DIR/failed-jobs.json" ]; then
  echo "No matching failed jobs found."
  exit 0
fi

# Show job summary
echo ""
echo "=== Failed Jobs ==="
jq -r '.name' "$OUTPUT_DIR/failed-jobs.json" | while read -r name; do
  env=$(echo "$name" | sed -E 's/^e2e-test-([^ ]+) .*/\1/')
  type=$(echo "$name" | grep -oE '(js-api|rest-api|soap-api|acceptance|mobile)' | head -1)
  idx=$(echo "$name" | grep -oE '\([0-9]+\)' | tr -d '()')
  printf "  %-20s %-12s (%s)\n" "$env" "$type" "$idx"
done

echo ""

# Fetch logs and track container per test
job_ids=$(jq -r '.id' "$OUTPUT_DIR/failed-jobs.json")

> "$OUTPUT_DIR/all-failed-tests-with-container.txt"
> "$LOGS_DIR/.fetched"  # Track fetched logs to avoid duplicates

for job_id in $job_ids; do
  job_name=$(jq -r "select(.id == $job_id) | .name" "$OUTPUT_DIR/failed-jobs.json")

  env=$(echo "$job_name" | sed -E 's/^e2e-test-([^ ]+) .*/\1/')
  type=$(echo "$job_name" | grep -oE '(js-api|rest-api|soap-api|acceptance|mobile)' | head -1)
  idx=$(echo "$job_name" | grep -oE '\([0-9]+\)' | tr -d '()')

  container="${env}/${type}(${idx})"
  log_file="$LOGS_DIR/${env}_${type}_${idx}.log"

  # Skip if already fetched
  if grep -q "^${env}_${type}_${idx}$" "$LOGS_DIR/.fetched" 2>/dev/null; then
    echo "Skip (dup): $container"
  else
    echo "Fetching: $container..."
    gh api "repos/$REPO/actions/jobs/$job_id/logs" > "$log_file" 2>/dev/null || true
    echo "${env}_${type}_${idx}" >> "$LOGS_DIR/.fetched"
  fi

  # Extract failures with container info
  grep "FAILED in" "$log_file" 2>/dev/null | while read -r line; do
    test_path=$(echo "$line" | sed -E 's/.*file:\/\/\///' | sed -E 's/ \([0-9]+ retries?\)//')
    if [ -n "$test_path" ]; then
      echo "$container|$test_path"
    fi
  done >> "$OUTPUT_DIR/all-failed-tests-with-container.txt"
done

# Sort and dedupe
sort -u "$OUTPUT_DIR/all-failed-tests-with-container.txt" -o "$OUTPUT_DIR/all-failed-tests-with-container.txt"

# Apply application filter
if [ -n "$APPLICATION" ]; then
  grep "|$APPLICATION/" "$OUTPUT_DIR/all-failed-tests-with-container.txt" > "$OUTPUT_DIR/filtered-tests.txt" || true
  cp "$OUTPUT_DIR/filtered-tests.txt" "$OUTPUT_DIR/all-failed-tests-with-container.txt"
fi

total=$(wc -l < "$OUTPUT_DIR/all-failed-tests-with-container.txt" | tr -d ' ')
echo ""
echo "=== Total: $total failed tests ==="

# Group by application
echo ""
echo "=== Failures by Application ==="

# Known apps list
known_apps="schedule workflow mail message bulletin board cabinet report phone space timecard presence notification portal address system"
known_apps_regex=$(echo "$known_apps" | tr ' ' '|')

for app in $known_apps others; do
  # Skip if filtering by specific app that's not this one
  if [ -n "$APPLICATION" ] && [ "$APPLICATION" != "$app" ]; then
    continue
  fi

  if [ "$app" = "others" ]; then
    count=$(grep -cvE "\\|(${known_apps_regex})/" "$OUTPUT_DIR/all-failed-tests-with-container.txt" 2>/dev/null | tr -d '[:space:]' || echo "0")
  else
    count=$(grep -c "|$app/" "$OUTPUT_DIR/all-failed-tests-with-container.txt" 2>/dev/null | tr -d '[:space:]' || echo "0")
  fi
  [ -z "$count" ] && count=0

  if [ "$count" -gt 0 ]; then
    echo ""
    echo "[$app] $count tests:"
    if [ "$app" = "others" ]; then
      grep -vE "\\|(${known_apps_regex})/" "$OUTPUT_DIR/all-failed-tests-with-container.txt" | while IFS='|' read -r container path; do
        printf "  %-35s %s\n" "$container" "$path"
      done | head -30
    else
      grep "|$app/" "$OUTPUT_DIR/all-failed-tests-with-container.txt" | while IFS='|' read -r container path; do
        printf "  %-35s %s\n" "$container" "$path"
      done | head -30
    fi
    if [ "$count" -gt 30 ]; then
      echo "  ... and $((count - 30)) more"
    fi
  fi
done

# Create summary
summary_file="$OUTPUT_DIR/summary.txt"
{
  echo "=== E2E Test Failure Summary ==="
  echo "Run: $RUN_ID (attempt: ${ATTEMPT:-latest})"
  if [ -n "$ATTEMPT" ]; then
    echo "URL: https://github.com/$REPO/actions/runs/$RUN_ID/attempts/$ATTEMPT"
  else
    echo "URL: https://github.com/$REPO/actions/runs/$RUN_ID"
  fi
  echo "Date: $(date)"
  echo "Filter: type=${TEST_TYPE:-all} env=${ENVIRONMENT:-all} app=${APPLICATION:-all}"
  echo ""
  echo "=== Failed Jobs ==="
  jq -r '.name' "$OUTPUT_DIR/failed-jobs.json" | while read -r name; do
    env=$(echo "$name" | sed -E 's/^e2e-test-([^ ]+) .*/\1/')
    type=$(echo "$name" | grep -oE '(js-api|rest-api|soap-api|acceptance|mobile)' | head -1)
    idx=$(echo "$name" | grep -oE '\([0-9]+\)' | tr -d '()')
    printf "%-20s %-12s (%s)\n" "$env" "$type" "$idx"
  done
  echo ""
  echo "=== Total: $total failed tests ==="
  echo ""
  echo "Format: CONTAINER | TEST_PATH"
  echo ""

  known_apps_regex=$(echo "$known_apps" | tr ' ' '|')
  
  for app in $known_apps others; do
    # Skip if filtering by specific app that's not this one
    if [ -n "$APPLICATION" ] && [ "$APPLICATION" != "$app" ]; then
      continue
    fi

    if [ "$app" = "others" ]; then
      count=$(grep -cvE "\\|(${known_apps_regex})/" "$OUTPUT_DIR/all-failed-tests-with-container.txt" 2>/dev/null | tr -d '[:space:]' || echo "0")
    else
      count=$(grep -c "|$app/" "$OUTPUT_DIR/all-failed-tests-with-container.txt" 2>/dev/null | tr -d '[:space:]' || echo "0")
    fi
    [ -z "$count" ] && count=0

    if [ "$count" -gt 0 ]; then
      echo ""
      echo "=== [$app] $count tests ==="
      if [ "$app" = "others" ]; then
        grep -vE "\\|(${known_apps_regex})/" "$OUTPUT_DIR/all-failed-tests-with-container.txt" | while IFS='|' read -r container path; do
          printf "%-35s %s\n" "$container" "$path"
        done
      else
        grep "|$app/" "$OUTPUT_DIR/all-failed-tests-with-container.txt" | while IFS='|' read -r container path; do
          printf "%-35s %s\n" "$container" "$path"
        done
      fi
    fi
  done
} > "$summary_file"

# Clean up intermediate files (keep only summary.txt and logs/)
rm -f "$OUTPUT_DIR/failed-jobs.json"
rm -f "$OUTPUT_DIR/all-failed-tests-with-container.txt"
rm -f "$OUTPUT_DIR/filtered-tests.txt"

echo ""
echo "=== Done ==="
echo "Output: $OUTPUT_DIR/"
echo "  summary.txt  - Full summary with all details"
echo "  logs/        - Raw job logs"
