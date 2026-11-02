#!/usr/bin/env bash
#
# firetv-debloat.sh - debloat, OTA-block and custom-launcher setup for Fire TV
# sticks over ADB. No root, no exploit.
#
# Usage:
#   ./firetv-debloat.sh 192.168.1.50 debloat
#   ./firetv-debloat.sh 192.168.1.50 launcher --apk ~/projectivy.apk
#   ./firetv-debloat.sh 192.168.1.50 ota
#   ./firetv-debloat.sh 192.168.1.50 all --apk ~/projectivy.apk
#   ./firetv-debloat.sh 192.168.1.50 restore
#   ./firetv-debloat.sh 192.168.1.50 status
#
# Add --dry-run to print the commands without touching the device.
set -euo pipefail

PORT=5555
DRY_RUN=0
APK=""

# Packages that are safe to disable on Fire OS 7 (tested on AFTSS / Fire TV
# Stick 3rd gen, Fire OS 7.7.1.7). Deliberately NOT included:
#   com.amazon.imp  - identity/accounts; disabling it causes a crash loop
#   com.amazon.tv.launcher / com.amazon.firehomestarter - protected
DEBLOAT_PKGS=(
  com.amazon.hybridadidservice
  com.amazon.kso.blackbird
  com.amazon.media.recommendations
  com.amazon.tv.acr
  com.amazon.tv.fw.metrics
  com.amazon.wirelessmetrics.service
  com.amazon.perfc
  com.amazon.perfcollection
  com.amazon.tv.developer.dataservice
  com.amazon.hedwig
  com.amazon.stillwatching.activity
  com.amazon.shoptv.client
  com.amazon.shoptv.firetv.client
  com.amazon.minitv.android.app
  com.amazon.bueller.music
  com.amazon.bueller.photos
  com.amazon.tahoe
  com.amazon.ceviche
  com.amazon.gamehub
  com.amazon.storm.lightning.tutorial
  com.amazon.tmm.tutorial
  com.amazon.sneakpeek
  com.amazon.logan
  com.amazon.katoch
  com.amazon.tv.support
  com.amazon.tv.releasenotes
  com.amazon.dummy.alarmclock
  com.amazon.dummy.calendar
  com.amazon.dummy.contacts
  com.amazon.dummy.gallery
  com.amazon.dummy.music
  com.amazon.dummy.settings
)

OTA_PKGS=(
  com.amazon.device.software.ota
  com.amazon.device.software.ota.override
  com.amazon.tv.forcedotaupdater.v2
)

PROJECTIVY=com.spocky.projengmenu
PROJECTIVY_HOME=com.spocky.projengmenu/com.spocky.projengmenu.ui.home.MainActivity
PROJECTIVY_A11Y=${PROJECTIVY}/com.spocky.projengmenu.services.ProjectivyAccessibilityService
PROJECTIVY_LISTENER=${PROJECTIVY}/com.spocky.projengmenu.services.notification.NotificationListener
AMAZON_HOME=com.amazon.tv.launcher/com.amazon.tv.launcher.ui.HomeActivity_vNext

DEVICE=""

usage() {
  sed -n '3,/^# Add --dry-run/p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

log()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Run a shell command on the device (or just print it in dry-run mode).
dsh() {
  if [ "$DRY_RUN" = 1 ]; then
    log "[dry-run] adb -s $DEVICE shell $*"
    return 0
  fi
  adb -s "$DEVICE" shell "$@"
}

pkg_installed() {
  adb -s "$DEVICE" shell pm list packages 2>/dev/null | grep -qx "package:$1"
}

pkg_disabled() {
  adb -s "$DEVICE" shell pm list packages -d 2>/dev/null | grep -qx "package:$1"
}

disable_pkg() {
  local pkg=$1
  if ! pkg_installed "$pkg"; then
    log "  skip  $pkg (not installed)"
    return 0
  fi
  if [ "$DRY_RUN" = 0 ] && pkg_disabled "$pkg"; then
    log "  ok    $pkg (already disabled)"
    return 0
  fi
  if dsh "pm disable-user --user 0 $pkg" >/dev/null 2>&1; then
    log "  off   $pkg"
  else
    log "  keep  $pkg (protected by Fire OS)"
  fi
}

enable_pkg() {
  local pkg=$1
  if pkg_installed "$pkg"; then
    if dsh "pm enable $pkg" >/dev/null 2>&1; then
      log "  on    $pkg"
    else
      warn "could not enable $pkg"
    fi
  fi
}

connect_device() {
  log "Connecting to $DEVICE ..."
  adb connect "$DEVICE" >/dev/null 2>&1 || true
  local i state
  for i in $(seq 1 30); do
    state=$(adb -s "$DEVICE" get-state 2>/dev/null || true)
    case "$state" in
      device) log "Connected."; return 0 ;;
      unauthorized)
        die "Device is unauthorized. Accept the 'Allow USB debugging' dialog on the TV, then rerun." ;;
    esac
    sleep 2
  done
  die "Could not connect to $DEVICE. Enable ADB debugging: Settings > My Fire TV > About (7 taps) > Developer options."
}

cmd_debloat() {
  log "Debloating ads, telemetry, tutorials and unused Amazon apps:"
  local pkg
  for pkg in "${DEBLOAT_PKGS[@]}"; do disable_pkg "$pkg"; done
  log "Done. Revert with: $0 $DEVICE restore"
}

cmd_ota() {
  log "Disabling Fire OS over-the-air updates:"
  local pkg
  for pkg in "${OTA_PKGS[@]}"; do disable_pkg "$pkg"; done
  log "Note: no more Fire OS updates, including security fixes."
}

cmd_launcher() {
  if [ -n "$APK" ]; then
    [ -f "$APK" ] || die "APK not found: $APK"
    log "Installing $APK ..."
    if [ "$DRY_RUN" = 1 ]; then
      log "[dry-run] adb -s $DEVICE install -r -g $APK"
    else
      adb -s "$DEVICE" install -r -g "$APK" >/dev/null || die "Install failed"
    fi
  fi
  if [ "$DRY_RUN" = 0 ] && ! pkg_installed "$PROJECTIVY"; then
    die "Projectivy is not installed. Pass --apk /path/to/projectivy.apk (get it from APKMirror or Play Store)."
  fi

  log "Setting Projectivy as preferred home ..."
  dsh "cmd package set-home-activity --user 0 $PROJECTIVY_HOME" >/dev/null || warn "set-home-activity reported an error"
  log "Granting notification listener ..."
  dsh "cmd notification allow_listener $PROJECTIVY_LISTENER" >/dev/null || warn "notification listener not granted"
  log "Enabling Projectivy accessibility service ..."
  dsh "settings put secure enabled_accessibility_services $PROJECTIVY_A11Y"
  dsh "settings put secure accessibility_enabled 1"

  log ""
  log "Last step is manual, on the TV:"
  log "  Projectivy > gear icon > Ajustes de Projectivy > General >"
  log "  turn ON 'Reemplazar el launcher actual' (Replace current launcher)."
  log "That is what makes the remote HOME button return to Projectivy."
}

cmd_restore() {
  log "Re-enabling every package this script may have disabled:"
  local pkg
  for pkg in "${DEBLOAT_PKGS[@]}" "${OTA_PKGS[@]}"; do enable_pkg "$pkg"; done
  ensure_amazon_home
  log "Done. Projectivy itself is not uninstalled."
}

ensure_amazon_home() {
  if [ "$DRY_RUN" = 0 ] && ! pkg_installed com.spocky.projengmenu; then
    return 0
  fi
  log "Restoring Amazon launcher as home ..."
  dsh "cmd package set-home-activity --user 0 $AMAZON_HOME" >/dev/null || true
  dsh "settings put secure enabled_accessibility_services ''" || true
}

cmd_status() {
  log "Device: $(adb -s "$DEVICE" shell getprop ro.product.model | tr -d '\r')"
  log "Fire OS: $(adb -s "$DEVICE" shell getprop ro.build.version.name | tr -d '\r')"
  log "Disabled packages: $(adb -s "$DEVICE" shell pm list packages -d | wc -l | tr -d ' ')"
  log "Accessibility services: $(adb -s "$DEVICE" shell settings get secure enabled_accessibility_services | tr -d '\r')"
  log "Projectivy installed: $(pkg_installed "$PROJECTIVY" && echo yes || echo no)"
}

main() {
  local cmd="debloat"
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) DRY_RUN=1 ;;
      --apk) shift; APK=${1:-} ;;
      -h|--help) usage 0 ;;
      debloat|launcher|ota|restore|status|all) cmd=$1 ;;
      *:*) DEVICE=$1 ;;
      *.*.*.*) DEVICE="$1:$PORT" ;;
      *) die "Unknown argument: $1" ;;
    esac
    shift
  done

  [ -n "$DEVICE" ] || usage 1
  connect_device

  case "$cmd" in
    debloat) cmd_debloat ;;
    ota) cmd_ota ;;
    launcher) cmd_launcher ;;
    restore) cmd_restore ;;
    status) cmd_status ;;
    all) cmd_debloat; cmd_ota; cmd_launcher ;;
  esac
}

main "$@"
