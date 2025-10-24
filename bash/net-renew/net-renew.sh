#!/usr/bin/env bash
set -euo pipefail

# renew-net.sh
# Portable script to "renew" the network interface (similar to `ipconfig /renew` on Windows).
# Tries NetworkManager (nmcli), dhclient/dhcpcd, ifdown/ifup, then falls back to ip link down/up + dhclient.

usage() {
  cat <<EOF
Usage: $0 [-i IFACE] [-y] [-h]

Options:
  -i IFACE   Specify network interface to renew (auto-detected if omitted)
  -y         Assume yes; don't prompt (useful in scripts or to skip SSH warning)
  -h         Show this help

Notes:
  - This script may disconnect you temporarily. If you're connected over SSH,
    it will warn before proceeding unless -y is provided.
  - Most operations require root; the script will use sudo where appropriate.
EOF
}

log() { printf '%s\n' "$*" >&2; }

# Print network device details
print_device_details() {
  local iface="$1"
  log "Network device details for $iface:"
  printf "    IPv4 Address: %s\n" "$(ip -4 addr show dev "$iface" | grep -w inet | awk '{print $2}')"
  printf "    IPv6 Address: %s\n" "$(ip -6 addr show dev "$iface" | grep -w inet6 | awk '{print $2}')"
}

# detect default interface using 'ip'
detect_iface() {
  local iface=""
  if command -v ip >/dev/null 2>&1; then
    iface=$(ip route get 8.8.8.8 2>/dev/null | awk '/dev/ {for(i=1;i<=NF;i++){if($i=="dev"){print $(i+1); exit}}}') || true
    if [ -z "$iface" ]; then
      iface=$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}') || true
    fi
  fi
  # fallback to parsing /proc/net/route for a non-loopback if nothing found
  if [ -z "$iface" ]; then
    while read -r line; do
      iface_candidate=$(awk '{print $1}' <<<"$line")
      [ "$iface_candidate" = "Iface" ] && continue
      # skip loopback
      if [ "$iface_candidate" != "lo" ]; then
        iface=$iface_candidate
        break
      fi
    done < /proc/net/route
  fi
  printf '%s' "$iface"
}

ASSUME_YES=0
INTERFACE=""

while getopts ":i:yh" opt; do
  case "$opt" in
    i) INTERFACE="$OPTARG" ;;
    y) ASSUME_YES=1 ;;
    h) usage; exit 0 ;;
    :) log "Missing argument for -$OPTARG"; usage; exit 2 ;;
    *) usage; exit 2 ;;
  esac
done

if [ -z "$INTERFACE" ]; then
  INTERFACE=$(detect_iface)
fi

if [ -z "$INTERFACE" ]; then
  log "Could not detect network interface. Provide one with -i INTERFACE.";
  exit 2
fi

# Warn if running over SSH
if [ -n "${SSH_CONNECTION:-}" ] || [ -n "${SSH_TTY:-}" ]; then
  if [ "$ASSUME_YES" -ne 1 ]; then
    log "Warning: You're connected over SSH. Renewing the interface may drop your connection."
    read -r -p "Continue? [y/N] " ans
    case "$ans" in
      [Yy]*) ;;
      *) log "Aborted by user."; exit 2 ;;
    esac
  fi
fi

log "Renewing interface: $INTERFACE"

# Print initial device details
print_device_details "$INTERFACE"

try_nmcli() {
  if command -v nmcli >/dev/null 2>&1; then
    log "Using NetworkManager (nmcli) to reconnect $INTERFACE"
    sudo nmcli device disconnect "$INTERFACE" || true
    sleep 1
    if sudo nmcli device connect "$INTERFACE"; then
      log "nmcli: reconnect succeeded"
      log "Network renewal complete. Current device details:"
      print_device_details "$INTERFACE"
      return 0
    else
      log "nmcli: reconnect failed"
      return 1
    fi
  fi
  return 2
}

try_dhclient() {
  if command -v dhclient >/dev/null 2>&1; then
    log "Using dhclient to release/renew DHCP on $INTERFACE"
    sudo dhclient -r "$INTERFACE" || true
    sleep 1
    if sudo dhclient "$INTERFACE"; then
      log "dhclient: success"
      log "Network renewal complete. Current device details:"
      print_device_details "$INTERFACE"
      return 0
    else
      log "dhclient: failed"
      return 1
    fi
  fi
  return 2
}

try_dhcpcd() {
  if command -v dhcpcd >/dev/null 2>&1; then
    log "Using dhcpcd to stop/start DHCP on $INTERFACE"
    sudo dhcpcd -k "$INTERFACE" || true
    sleep 1
    if sudo dhcpcd "$INTERFACE"; then
      log "dhcpcd: success"
      log "Network renewal complete. Current device details:"
      print_device_details "$INTERFACE"
      return 0
    else
      log "dhcpcd: failed"
      return 1
    fi
  fi
  return 2
}

try_ifdown_ifup() {
  if command -v ifdown >/dev/null 2>&1 && command -v ifup >/dev/null 2>&1; then
    log "Using ifdown/ifup on $INTERFACE"
    sudo ifdown --force "$INTERFACE" || true
    sleep 1
    if sudo ifup "$INTERFACE"; then
      log "ifdown/ifup: success"
      log "Network renewal complete. Current device details:"
      print_device_details "$INTERFACE"
      return 0
    else
      log "ifdown/ifup: failed"
      return 1
    fi
  fi
  return 2
}

try_ip_link_down_up() {
  if command -v ip >/dev/null 2>&1; then
    log "Falling back to 'ip link' down/up on $INTERFACE"
    sudo ip link set dev "$INTERFACE" down
    sleep 1
    sudo ip link set dev "$INTERFACE" up
    sleep 2
    # try to obtain DHCP lease if possible
    if command -v dhclient >/dev/null 2>&1; then
      sudo dhclient "$INTERFACE" || true
    fi
    log "ip link down/up attempted"
    return 0
  fi
  return 2
}

# Try methods in order; return success if any of them succeed (exit code 0)
if try_nmcli; then exit 0; fi
if try_dhclient; then exit 0; fi
if try_dhcpcd; then exit 0; fi
if try_ifdown_ifup; then exit 0; fi
if try_ip_link_down_up; then exit 0; fi

log "All methods tried and none reported success. Check the system's network manager and DHCP client."
exit 1