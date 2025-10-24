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

# System Command Setup

### Set up a custom scripts library
_If you have performed these steps before, you can skip them_
1. Create `customscripts.sh` to add "customscripts" to the system PATH
1. Create the customscripts directory at `/usr/customscripts`

```
sudo bash -c 'echo "export PATH=\$PATH:/usr/customscripts" > /etc/profile.d/customscripts.sh'
sudo chmod 644 /etc/profile.d/customscripts.sh
sudo mkdir -p /usr/customscripts
```

### Copy `net-renew` into the custom scripts library
The following commands will:
1. Copy `net-renew.sh` into customscripts as `net-renew` (removes the .sh extension for cleaner command naming)
1. Make `net-renew` executable
1. Update the current session's PATH variable
1. Restart the shell

```
sudo cp bash/net-renew/net-renew.sh /usr/customscripts/net-renew 
sudo chmod 755 /usr/customscripts/net-renew
source /etc/profile.d/customscripts.sh
exec bash -l
which net-renew
```

# Notes and caveats
- This will likely interrupt network connectivity briefly. Use caution if you're connected via SSH.
- The script uses available system tools; if your distribution uses a different network manager, adapt accordingly.
- Tested with common Debian/Ubuntu and systemd-based systems.

License: MIT