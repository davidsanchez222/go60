#!/usr/bin/env bash
set -euo pipefail

RIGHT_VOLUME="GO60RHBOOT"
LEFT_VOLUME="GO60LHBOOT"
UF2_DIR="."
POLL_INTERVAL=1
COPY_RETRIES=10
COPY_RETRY_DELAY=1

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

find_newest_uf2() {
  find "$UF2_DIR" -maxdepth 1 -type f -iname '*.uf2' -print0 |
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

wait_for_writable_volume() {
  local volume_name="$1"
  local volume_path="/Volumes/$volume_name"
  local testfile="$volume_path/.write_test_$$"

  log "Waiting for $volume_name to become writable..."
  while true; do
    if [[ -d "$volume_path" ]] && touch "$testfile" 2>/dev/null; then
      rm -f "$testfile"
      log "$volume_name is writable."
      return 0
    fi
    sleep "$POLL_INTERVAL"
  done
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
  local attempt

  uf2_file="$(find_newest_uf2)"

  if [[ -z "${uf2_file:-}" || ! -f "$uf2_file" ]]; then
    log "No .uf2 file found."
    exit 1
  fi

  log "Using UF2: $uf2_file"
  log "Copying to $volume_name..."

  for ((attempt=1; attempt<=COPY_RETRIES; attempt++)); do
    if cp "$uf2_file" "$volume_path/firmware.uf2" 2>/dev/null; then
      sync
      log "Copy finished for $volume_name."
      return 0
    fi

    # If the volume disappeared, the board likely accepted the UF2 and rebooted.
    if [[ ! -d "$volume_path" ]]; then
      log "$volume_name disappeared during copy; assuming flash succeeded."
      return 0
    fi

    log "Copy attempt $attempt failed, but device is still mounted; retrying..."
    sleep "$COPY_RETRY_DELAY"
  done

  # One final check before declaring failure.
  if [[ ! -d "$volume_path" ]]; then
    log "$volume_name disappeared after copy attempts; assuming flash succeeded."
    return 0
  fi

  log "Copy failed and $volume_name is still mounted."
  exit 1
}

wait_for_volume "$RIGHT_VOLUME"
wait_for_writable_volume "$RIGHT_VOLUME"
copy_latest_uf2_to_volume "$RIGHT_VOLUME"
wait_for_eject "$RIGHT_VOLUME"

wait_for_volume "$LEFT_VOLUME"
wait_for_writable_volume "$LEFT_VOLUME"
copy_latest_uf2_to_volume "$LEFT_VOLUME"
wait_for_eject "$LEFT_VOLUME"

log "Left half complete. Done."
