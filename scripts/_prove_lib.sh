# shellcheck shell=bash
# Shared helpers for scripts/prove-*.sh (source only; not executable).

prove_header() {
  local stage="$1" title="$2"
  echo
  echo "────────────────────────────────────────"
  echo " Stage $stage · $title"
  echo "────────────────────────────────────────"
}

prove_ok() {
  printf '  ✓ %s\n' "$*"
}

prove_fail() {
  printf '  ✗ %s\n' "$*" >&2
}

prove_info() {
  printf '    %s\n' "$*"
}

prove_check() {
  # prove_check "label" command...
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    prove_ok "$label"
  else
    prove_fail "$label"
    return 1
  fi
}

prove_eq() {
  # prove_eq "label" "$got" "$want"
  local label="$1" got="$2" want="$3"
  if [[ "$got" == "$want" ]]; then
    prove_ok "$label ($got)"
  else
    prove_fail "$label (got '$got', want '$want')"
    return 1
  fi
}

prove_contains() {
  # prove_contains "label" "$haystack" "$needle"
  local label="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    prove_ok "$label"
  else
    prove_fail "$label (missing '$needle')"
    prove_info "$haystack"
    return 1
  fi
}

prove_tf_region() {
  local tfvars="$1"
  local region=ap-southeast-2
  if [[ -f "$tfvars" ]]; then
    region="$(awk -F'"' '/aws_region/ {print $2; exit}' "$tfvars" || echo ap-southeast-2)"
  fi
  printf '%s' "$region"
}

prove_ssm_run() {
  # prove_ssm_run REGION INSTANCE_ID COMMANDS_JSON_FILE
  # Prints remote stdout; returns non-zero if SSM status != Success.
  local region="$1" instance_id="$2" params_file="$3"
  local cmd_id status i stdout stderr

  printf '    waiting for SSM on %s' "$instance_id"
  cmd_id="$(aws ssm send-command \
    --region "$region" \
    --instance-ids "$instance_id" \
    --document-name "AWS-RunShellScript" \
    --parameters "file://$params_file" \
    --output text \
    --query 'Command.CommandId')"

  status=Pending
  for i in $(seq 1 45); do
    status="$(aws ssm get-command-invocation \
      --region "$region" \
      --command-id "$cmd_id" \
      --instance-id "$instance_id" \
      --query 'Status' \
      --output text 2>/dev/null || echo Pending)"
    case "$status" in
      Success|Failed|Cancelled|TimedOut) printf '\n'; break ;;
    esac
    printf '.'
    sleep 2
  done

  stdout="$(aws ssm get-command-invocation \
    --region "$region" \
    --command-id "$cmd_id" \
    --instance-id "$instance_id" \
    --query 'StandardOutputContent' \
    --output text 2>/dev/null || true)"
  stderr="$(aws ssm get-command-invocation \
    --region "$region" \
    --command-id "$cmd_id" \
    --instance-id "$instance_id" \
    --query 'StandardErrorContent' \
    --output text 2>/dev/null || true)"

  if [[ -n "${stdout//[[:space:]]/}" && "$stdout" != "None" ]]; then
    while IFS= read -r line; do
      [[ -n "$line" ]] && prove_info "$line"
    done <<<"$stdout"
  fi
  if [[ -n "${stderr//[[:space:]]/}" && "$stderr" != "None" ]]; then
    while IFS= read -r line; do
      [[ -n "$line" ]] && prove_info "(stderr) $line"
    done <<<"$stderr"
  fi

  if [[ "$status" != "Success" ]]; then
    prove_fail "SSM command $status (id $cmd_id)"
    return 1
  fi
}

prove_pass() {
  echo
  printf '  PASS · %s\n' "$*"
  echo
}

prove_die() {
  prove_fail "$*"
  echo
  printf '  FAIL · verification stopped\n' >&2
  echo
  exit 1
}
