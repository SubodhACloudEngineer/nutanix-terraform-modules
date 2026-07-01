#!/usr/bin/env bash
# import-migrated-vms.sh
#
# Batch-imports VMs migrated by Nutanix Move into the Terraform state file.
# Usage:
#   ./scripts/import-migrated-vms.sh \
#     --manifest   "import-manifest.json" \
#     --working-dir "." \
#     [--dry-run]
#
# Manifest format (JSON array):
#   [
#     {
#       "terraform_address": "module.hob_as_0013.nutanix_virtual_machine.this[0]",
#       "vm_uuid":           "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
#       "vm_name":           "hob-as-0013"
#     }
#   ]
#
# Exit codes:
#   0 — all imports succeeded (or dry-run completed)
#   1 — one or more imports failed

set -euo pipefail

# ── Argument parsing ──────────────────────────────────────────────────────────
MANIFEST=""
WORKING_DIR="."
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest)    MANIFEST="$2";     shift 2 ;;
    --working-dir) WORKING_DIR="$2";  shift 2 ;;
    --dry-run)     DRY_RUN=true;      shift   ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$MANIFEST" ]]; then
  echo "Usage: $0 --manifest FILE [--working-dir DIR] [--dry-run]" >&2
  exit 1
fi

if [[ ! -f "$MANIFEST" ]]; then
  echo "Error: manifest file not found: ${MANIFEST}" >&2
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo "Error: python3 is required but not found in PATH." >&2
  exit 1
fi

if ! command -v terraform &>/dev/null; then
  echo "Error: terraform is required but not found in PATH." >&2
  exit 1
fi

# ── Parse manifest ────────────────────────────────────────────────────────────
# Emit tab-separated lines: terraform_address\tvm_uuid\tvm_name
ENTRIES=$(python3 -c "
import json, sys

with open('${MANIFEST}') as f:
    entries = json.load(f)

if not isinstance(entries, list):
    print('Error: manifest must be a JSON array', file=sys.stderr)
    sys.exit(1)

for e in entries:
    addr  = e.get('terraform_address', '')
    uuid  = e.get('vm_uuid', '')
    name  = e.get('vm_name', '')
    if not addr or not uuid or not name:
        print(f'Error: missing field in entry: {e}', file=sys.stderr)
        sys.exit(1)
    print(f'{addr}\t{uuid}\t{name}')
")

TOTAL=0
SUCCEEDED=0
FAILED=0

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  Nutanix Move → Terraform State Import"
if [[ "$DRY_RUN" == "true" ]]; then
  echo "  Mode: DRY RUN (no changes will be made)"
fi
echo "  Manifest: ${MANIFEST}"
echo "  Working dir: ${WORKING_DIR}"
echo "══════════════════════════════════════════════════════════════"
echo ""

# ── Process each entry ────────────────────────────────────────────────────────
while IFS=$'\t' read -r TF_ADDRESS VM_UUID VM_NAME; do
  TOTAL=$((TOTAL + 1))

  echo "→ Importing ${VM_NAME} (${TF_ADDRESS}) UUID: ${VM_UUID}"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [DRY RUN] Would run: terraform import '${TF_ADDRESS}' '${VM_UUID}'"
    SUCCEEDED=$((SUCCEEDED + 1))
  else
    if terraform -chdir="${WORKING_DIR}" import \
         "${TF_ADDRESS}" "${VM_UUID}" 2>&1; then
      echo "  ✓ Imported successfully"
      SUCCEEDED=$((SUCCEEDED + 1))
    else
      echo "  ✗ Import FAILED — check that the resource block exists in main.tf and the UUID is correct"
      FAILED=$((FAILED + 1))
    fi
  fi

  echo ""
done <<< "$ENTRIES"

# ── Summary ───────────────────────────────────────────────────────────────────
echo "══════════════════════════════════════════════════════════════"
echo "  Import complete. ${SUCCEEDED} succeeded, ${FAILED} failed."
echo "══════════════════════════════════════════════════════════════"
echo ""
echo "Next step: run 'terraform plan' to review configuration drift."
echo "Migrated VMs will show category differences — apply to enforce HLD tags."
echo ""

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi

exit 0
