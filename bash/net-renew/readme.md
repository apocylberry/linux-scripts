net-renew
=========

> [!WARNING]
> Utility was fully vibe coded using GPT-5 mini.  Use at your own risk.

A small portable bash script to "renew" the current network interface on Linux (roughly similar to `ipconfig /renew` on Windows).

What it does
- Auto-detects the default network interface (or accepts -i IFACE)
- Tries these methods in order:
  1. NetworkManager via `nmcli` (disconnect/connect)
  2. `dhclient` (release and renew)
  3. `dhcpcd` (stop/start)
  4. `ifdown`/`ifup`
  5. `ip link set dev DOWN/UP` + attempt `dhclient`

Usage

Run with sudo or a user with passwordless sudo configured for networking commands. The script will call sudo where needed.

Examples:

  # Auto-detect interface and renew
  `sudo ./net-renew.sh`

  # Specify interface
  `sudo ./net-renew.sh -i eth0`

  # Run non-interactively (don't prompt even if you're on SSH)
  `sudo ./net-renew.sh -y`

  # Show detailed progress information
  `sudo ./net-renew.sh -v`

By default, the script shows minimal output (interface name, completion status, and final IP addresses). Use `-v` for verbose mode to see detailed progress information.

Notes and caveats
- Set the executable flag using `chmod +x net-renew.sh`
- This will likely interrupt network connectivity briefly. Use caution if you're connected via SSH.
- The script uses available system tools; if your distribution uses a different network manager, adapt accordingly.
- Tested with common Debian/Ubuntu and systemd-based systems.

License: MIT