#!/usr/bin/env bash
# Script Name: manmoun.sh
# ID: SCR-ID-20260327181002-O6LWBKKWYK
# Assigned with: n/a
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: manmount.sh

# automount-drives.sh

# Mount drives by UUID to fixed mount points

set -euo pipefail

# ----- config -----
USER_NAME="${SUDO_USER:-$USER}"
USER_ID="$(id -u "$USER_NAME")"
GROUP_ID="$(id -g "$USER_NAME")"

declare -A MOUNTS=(
  ["1234-ABCD-5678-EF90"]="/mnt/data"
  ["12A34B56C78D90EF"]="/mnt/media"
  ["1A2B-3C4D"]="/mnt/archive"
)

# ----- helpers -----
get_fs_type() {
  local uuid="$1"
  blkid -o value -s TYPE "/dev/disk/by-uuid/$uuid"
}

is_mounted() {
  local mount_point="$1"
  mountpoint -q "$mount_point"
}

mount_drive() {
  local uuid="$1"
  local mount_point="$2"
  local dev="/dev/disk/by-uuid/$uuid"

  if [[ ! -e "$dev" ]]; then
    echo "Missing device for UUID: $uuid"
    return 1
  fi

  mkdir -p "$mount_point"

  if is_mounted "$mount_point"; then
    echo "Already mounted: $mount_point"
    return 0
  fi

  local fstype
  fstype="$(get_fs_type "$uuid")"

  case "$fstype" in
    ext4|ext3|ext2)
      mount -t "$fstype" "$dev" "$mount_point"
      ;;
    ntfs|ntfs3)
      mount -t ntfs3 -o "uid=$USER_ID,gid=$GROUP_ID" "$dev" "$mount_point"
      ;;
    exfat)
      mount -t exfat -o "uid=$USER_ID,gid=$GROUP_ID" "$dev" "$mount_point"
      ;;
    vfat|fat|fat32)
      mount -t vfat -o "uid=$USER_ID,gid=$GROUP_ID,umask=022" "$dev" "$mount_point"
      ;;
    *)
      echo "Unsupported or unknown filesystem '$fstype' for UUID: $uuid"
      return 1
      ;;
  esac

  echo "Mounted $uuid -> $mount_point ($fstype)"
}

main() {
  if [[ $EUID -ne 0 ]]; then
    echo "Run this script with sudo."
    exit 1
  fi

  local uuid
  for uuid in "${!MOUNTS[@]}"; do
    mount_drive "$uuid" "${MOUNTS[$uuid]}"
  done
}

main "$@"
