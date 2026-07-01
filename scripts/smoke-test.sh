#!/usr/bin/env bash
# smoke-test.sh
#
# Post-provisioning smoke tests called by Stage 4 of the CI/CD pipeline.
# Usage:
#   ./scripts/smoke-test.sh \
#     --vm-name   "hob-as-0013" \
#     --vm-ip     "10.0.1.50" \
#     --os-type   "windows" \
#     --is-override "false"
#
# Exit codes:
#   0 — all tests passed or skipped
#   1 — one or more tests failed

set -euo pipefail

# ── Argument parsing ──────────────────────────────────────────────────────────
VM_NAME=""
VM_IP=""
OS_TYPE=""
IS_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vm-name)     VM_NAME="$2";     shift 2 ;;
    --vm-ip)       VM_IP="$2";       shift 2 ;;
    --os-type)     OS_TYPE="$2";     shift 2 ;;
    --is-override) IS_OVERRIDE="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$VM_NAME" || -z "$OS_TYPE" || -z "$IS_OVERRIDE" ]]; then
  echo "Usage: $0 --vm-name NAME --vm-ip IP --os-type TYPE --is-override BOOL" >&2
  exit 1
fi

TEST1_RESULT=""
TEST2_RESULT=""

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  Nutanix VM Smoke Tests"
echo "  VM: ${VM_NAME}  OS: ${OS_TYPE}  IP: ${VM_IP:-<none>}"
echo "══════════════════════════════════════════════════════════════"
echo ""

# ── TEST 1: VM Naming Convention ─────────────────────────────────────────────
echo "TEST 1 — VM Naming Convention Check"

if [[ "$IS_OVERRIDE" == "true" ]]; then
  echo "~ SKIP — vm_name_override used, naming convention check skipped"
  TEST1_RESULT="SKIP"
else
  # Pattern: {3 lowercase letters}-{2 lowercase letters}-{4 digits}
  if [[ "$VM_NAME" =~ ^[a-z]{3}-[a-z]{2}-[0-9]{4}$ ]]; then
    echo "✓ PASS — VM name matches convention: ${VM_NAME}"
    TEST1_RESULT="PASS"
  else
    echo "✗ FAIL — VM name does not match expected pattern {SITE}-{CODE}-{NNNN}: ${VM_NAME}"
    TEST1_RESULT="FAIL"
  fi
fi

echo ""

# ── TEST 2: IP Reachability ───────────────────────────────────────────────────
echo "TEST 2 — IP Reachability Check"

if [[ -z "$VM_IP" || "$VM_IP" == "null" ]]; then
  echo "~ SKIP — no IP address available yet (VM may still be booting)"
  TEST2_RESULT="SKIP"
else
  case "$OS_TYPE" in
    windows)   PORT=3389 ;;
    linux)     PORT=22   ;;
    appliance)
      echo "~ SKIP — appliance OS type, reachability check not applicable"
      TEST2_RESULT="SKIP"
      PORT=""
      ;;
    *)
      echo "~ SKIP — unknown OS type '${OS_TYPE}', skipping reachability check"
      TEST2_RESULT="SKIP"
      PORT=""
      ;;
  esac

  if [[ -n "$PORT" ]]; then
    MAX_RETRIES=5
    RETRY_DELAY=10
    SUCCESS=false

    for attempt in $(seq 1 "$MAX_RETRIES"); do
      echo "  Attempt ${attempt}/${MAX_RETRIES}: checking ${VM_IP}:${PORT} ..."

      if timeout 5 bash -c "cat < /dev/null > /dev/tcp/${VM_IP}/${PORT}" 2>/dev/null \
         || nc -zw5 "${VM_IP}" "${PORT}" 2>/dev/null; then
        SUCCESS=true
        break
      fi

      if [[ "$attempt" -lt "$MAX_RETRIES" ]]; then
        echo "  Not reachable yet, waiting ${RETRY_DELAY}s ..."
        sleep "$RETRY_DELAY"
      fi
    done

    if [[ "$SUCCESS" == "true" ]]; then
      echo "✓ PASS — ${VM_IP}:${PORT} is reachable"
      TEST2_RESULT="PASS"
    else
      echo "✗ FAIL — ${VM_IP}:${PORT} not reachable after ${MAX_RETRIES} attempts. VM may still be completing first boot."
      TEST2_RESULT="FAIL"
    fi
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  Results Summary"
echo "══════════════════════════════════════════════════════════════"
printf "  %-40s %s\n" "TEST 1 — Naming convention:" "${TEST1_RESULT}"
printf "  %-40s %s\n" "TEST 2 — IP reachability:"   "${TEST2_RESULT}"
echo "══════════════════════════════════════════════════════════════"
echo ""

# Exit 1 if any test failed
if [[ "$TEST1_RESULT" == "FAIL" || "$TEST2_RESULT" == "FAIL" ]]; then
  exit 1
fi

exit 0
