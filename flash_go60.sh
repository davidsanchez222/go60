#!/usr/bin/env bash
set -euo pipefail

RIGHT_VOLUME="GO60RHBOOT"
LEFT_VOLUME="GO60LHBOOT"
DOWNLOADS_DIR="$HOME/Downloads"
POLL_INTERVAL=1

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

find_newest_uf2() {
  find "$DOWNLOADS_DIR" -maxdepth 1 -type f -iname '*.uf2' -print0 |
    xargs -0 stat -f '%m %N' 2>/dev/null |
    sort -nr |
    head -n 1 |
    cut -d' ' -f2-
}

wait_for_volume() {
  local volume_name="$1"
  local volume_path="/Volumes/$volume_name"

  log "Waiting for $volume_name..."
  while [[ ! -d "$volume_path" ]]; do
    sleep "$POLL_INTERVAL"
  done
  log "$volume_name detected."
}

wait_for_eject() {
  local volume_name="$1"
  local volume_path="/Volumes/$volume_name"

  log "Waiting for $volume_name to eject..."
  while [[ -d "$volume_path" ]]; do
    sleep "$POLL_INTERVAL"
  done
  log "$volume_name ejected."
}

copy_latest_uf2_to_volume() {
  local volume_name="$1"
  local volume_path="/Volumes/$volume_name"
  local uf2_file

  uf2_file="$(find_newest_uf2)"

  if [[ -z "${uf2_file:-}" || ! -f "$uf2_file" ]]; then
    log "No .uf2 file found in $DOWNLOADS_DIR"
    exit 1
  fi

  log "Using UF2: $uf2_file"
  log "Copying to $volume_name..."
  cp "$uf2_file" "$volume_path/"
  sync
  log "Copy finished for $volume_name."
}

wait_for_volume "$RIGHT_VOLUME"
copy_latest_uf2_to_volume "$RIGHT_VOLUME"
wait_for_eject "$RIGHT_VOLUME"

wait_for_volume "$LEFT_VOLUME"
copy_latest_uf2_to_volume "$LEFT_VOLUME"
wait_for_eject "$LEFT_VOLUME"

log "Left half complete. Done."
