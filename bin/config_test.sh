#!/bin/bash
# config_test.sh – Exercise the editing functions and cleanup script.
set -euo pipefail

sudo=${sudo-}

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# --------------------------------------------------------------------
# 1. Build fixtures
# --------------------------------------------------------------------
mkdir -p "$work/etc/default" "$work/etc"
cat >"$work/etc/default/limine" <<'EOF'
ESP_PATH="/boot"
KERNEL_CMDLINE[default]+="quiet nowatchdog splash rw rootflags=subvol=/@ root=UUID=833e113b-e610-449f-b785-0d6ef84cf092"
BOOT_ORDER="*, *lts, *fallback, Snapshots"
#COMPRESSION_OPTIONS=()
#COMPRESSION="bzip2"
#COMPRESSION="gzip"
#COMPRESSION="lz4"
#COMPRESSION="lzma"
#COMPRESSION="lzop"
#COMPRESSION="xz"
#COMPRESSION="zstd"
#MODULES_DECOMPRESS="no"
BINARIES=()
FILES=()
HOOKS=(base udev autodetect microcode kms modconf block keyboard keymap consolefont filesystems)
MODULES=(crc32c)
EOF
cp "$work/etc/default/limine" "$work/etc/mkinitcpio.conf"

# --------------------------------------------------------------------
# 2. Source config.sh (defines config_add, config_rm, cleanup_backups)
# --------------------------------------------------------------------
source "$dir/config.sh"

# --------------------------------------------------------------------
# 3. Test config_rm (remove all occurrences)
# --------------------------------------------------------------------
config_rm KERNEL_CMDLINE quiet "$work/etc/default/limine"

# Check that the KERNEL_CMDLINE[default]+= line no longer contains 'quiet'
grep -q 'KERNEL_CMDLINE\[default\]+=".*nowatchdog.*splash.*"' "$work/etc/default/limine" || { echo "FAIL: quiet not removed from KERNEL_CMDLINE[default]+= line"; exit 1; }

# Check that 'quiet' is gone from all non-comment lines
grep -v '^#' "$work/etc/default/limine" | grep -q 'quiet' && { echo "FAIL: quiet still present (all occurrences)"; exit 1; }

# Look for the backup comment (allow leading spaces)
grep -q '^\s*# KERNEL_CMDLINE\[default\]+="quiet nowatchdog splash' "$work/etc/default/limine" || { echo "FAIL: backup comment missing"; exit 1; }

# --------------------------------------------------------------------
# 4. Test config_add (pair)
# --------------------------------------------------------------------
config_add KERNEL_CMDLINE systemd.zram=0 "$work/etc/default/limine"
grep -q 'systemd.zram=0' "$work/etc/default/limine" || { echo "FAIL: pair not added"; exit 1; }

# --------------------------------------------------------------------
# 5. Test config_add (flag)
# --------------------------------------------------------------------
config_add KERNEL_CMDLINE nomodset "$work/etc/default/limine"
grep -q 'nomodset' "$work/etc/default/limine" || { echo "FAIL: flag not added"; exit 1; }

# --------------------------------------------------------------------
# 6. Idempotency test – file content must not change AND no new backup
# --------------------------------------------------------------------
backup_count_before=$(find "$work/etc/default" -maxdepth 1 -name '*.backup.*' | wc -l)
before=$(sha256sum "$work/etc/default/limine" | awk '{print $1}')
config_add KERNEL_CMDLINE nomodset "$work/etc/default/limine"
after=$(sha256sum "$work/etc/default/limine" | awk '{print $1}')
backup_count_after=$(find "$work/etc/default" -maxdepth 1 -name '*.backup.*' | wc -l)
[[ "$before" == "$after" ]] || { echo "FAIL: not idempotent"; exit 1; }
[[ "$backup_count_before" -eq "$backup_count_after" ]] || { echo "FAIL: backup created on idempotent run"; exit 1; }

# --------------------------------------------------------------------
# 7. Test cleanup_backups
# --------------------------------------------------------------------
# Create 10 additional old backups (35 days ago) so that the 60-day file
# is NOT among the 10 most recent and can actually be deleted.
for i in {1..10}; do
    touch -d "35 days ago" "$work/etc/default/limine.backup.old_$i"
done
touch -d "60 days ago" "$work/etc/default/limine.backup.20240101_000000_000000000"
touch -d "today"       "$work/etc/default/limine.backup.$(date +%Y%m%d)_120000_000000000"

cleanup_backups "$work/etc/default"

[[ ! -e "$work/etc/default/limine.backup.20240101_000000_000000000" ]] || { echo "FAIL: 60-day backup not deleted"; exit 1; }
[[ -e "$work/etc/default/limine.backup.$(date +%Y%m%d)_120000_000000000" ]] || { echo "FAIL: today backup deleted"; exit 1; }

echo "All tests passed."
