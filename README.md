# Windrose Dedicated Server — Linux Setup
## Slackware 15.0 x86_64 | Wine + LinuxGSM-style management

> **Official Guide:** https://playwindrose.com/dedicated-server-guide/  
> **Note:** Windrose Dedicated Server (`AppID 4129620`) is a **Windows-only** application and a **free Steam app** (no game purchase required).  
> This setup runs it on Linux via Wine, managed by a LinuxGSM-compatible script.

---

## Quick Start

```bash
# 1. One-time root setup (creates user, installs deps, deploys scripts)
sudo bash windrose-setup.sh

# 2. Install server files as windrose user
sudo -u windrose /home/windrose/windroseserver install

# 3. Start the server
sudo -u windrose /home/windrose/windroseserver start

# 4. Check status and get invite code
sudo -u windrose /home/windrose/windroseserver details
```

---

## Files in This Directory

| File | Purpose |
|---|---|
| `windrose-setup.sh` | **Run as root.** Creates user, installs deps, deploys everything. |
| `windroseserver` | **The manager script.** Mirrors LinuxGSM interface exactly. |
| `WINDROSE-SERVER-NOTES.md` | Live deployment notes — what was fixed, current state, commands. |
| `README.md` | This file. |

---

## Manager Script Commands

```bash
/home/windrose/windroseserver <command>
```

| Command | Short | Description |
|---|---|---|
| `start` | `st` | Start the server |
| `stop` | `sp` | Stop the server |
| `restart` | `r` | Restart the server |
| `monitor` | `m` | Check health; restart if down |
| `details` | `dt` | Show status, ports, config |
| `console` | `c` | Attach to tmux console (Ctrl+B, D to detach) |
| `debug` | `d` | Start in foreground (for troubleshooting) |
| `logs` | `l` | Tail server logs |
| `install` | `i` | Download server via SteamCMD + Wine setup |
| `update` | `u` | Update server files |
| `validate` | `v` | Validate server files |
| `backup` | `b` | Backup world save data |
| `configure` | `cfg` | Edit config in $EDITOR |
| `winesetup` | `ws` | Re-initialize Wine prefix |

---

## Directory Structure (LinuxGSM-compatible)

```
/home/windrose/
├── windroseserver              ← Main manager script
├── WINDROSE-SERVER-NOTES.md    ← Live deployment notes
├── windrose-setup.sh           ← Root installer (deployed here by setup)
├── lgsm/
│   └── config-lgsm/
│       └── windroseserver/
│           ├── _default.cfg        ← DO NOT EDIT (reference defaults)
│           ├── windroseserver.cfg  ← Your settings go here
│           ├── secrets-windroseserver.cfg  ← Steam credentials (chmod 600)
│           └── common.cfg          ← Settings shared across instances
├── serverfiles/                ← Game server files (installed by SteamCMD)
│   ├── WindroseServer.exe          ← DO NOT launch this directly (see below)
│   └── R5/
│       ├── Binaries/Win64/
│       │   └── WindroseServer-Win64-Shipping.exe  ← REAL server binary
│       ├── ServerDescription.json  ← Created on first run (has invite code)
│       └── Saved/
│           └── Logs/R5.log         ← Primary game log
├── log/
│   ├── server/                 ← Wine/stdout logs (windroseserver-server.log)
│   └── script/                 ← Manager script logs
├── backup/                     ← World backups (tar.gz)
└── .wine/                      ← Wine prefix (WINEPREFIX)
    └── drive_c/users/windrose/AppData/Local/R5/Saved/SaveProfiles/
        └── Default/RocksDB/<version>/Worlds/  ← World save data
```

> [!IMPORTANT]
> **Do NOT launch `WindroseServer.exe` directly.** The root EXE is a Windows
> prerequisite bootstrapper. Under headless Wine it silently waits for a hidden
> VC++ redistributable prompt and never actually starts the game server.
> The manager script automatically launches the correct binary:
> `R5/Binaries/Win64/WindroseServer-Win64-Shipping.exe`

---

## Configuration

### Main Config (`lgsm/config-lgsm/windroseserver/windroseserver.cfg`)

```bash
servername="My Windrose Server"
serverpassword=""          # Leave empty for public server
port="7777"
queryport="7778"
maxplayers="10"
# IMPORTANT: Set to your server's public IP so invite codes work over the internet
p2pproxyaddress="203.0.113.42"
startparameters="-log -MULTIHOME=0.0.0.0"
```

The manager syncs `servername`, `serverpassword`, `maxplayers`, and
`p2pproxyaddress` into `ServerDescription.json` before each start, so you
only need to edit `windroseserver.cfg` — not the JSON directly.

### Steam Credentials

The Windrose Dedicated Server is a **free Steam app** — **anonymous login should work**.
You do NOT need to own the game or have a special account.

Only edit `secrets-windroseserver.cfg` if anonymous login fails:

```bash
# Only set these if SteamCMD returns "No subscription"
steamuser="your_dedicated_steam_account"
steampass="your_steam_password"
```

---

## Windrose Server Configuration Files (Official)

Per the [official guide](https://playwindrose.com/dedicated-server-guide/), after the first server run two JSON files are generated.

> **Always stop the server before editing JSON files** — it will overwrite your changes if running.
> 
> **Prefer editing `windroseserver.cfg`** — the manager syncs key settings
> into `ServerDescription.json` automatically on each start.

### `ServerDescription.json` (at `serverfiles/R5/`)

Example from official docs:
```json
{
  "Version": 1,
  "DeploymentId": "0.10.0.0.251-master-9f800c33",
  "ServerDescription_Persistent": {
    "PersistentServerId": "1B80182E460F...",
    "InviteCode": "d6221bb7",
    "IsPasswordProtected": false,
    "Password": "",
    "ServerName": "My Pirate Server",
    "WorldIslandId": "DB57768A...",
    "MaxPlayerCount": 8,
    "P2pProxyAddress": "203.0.113.42"
  }
}
```

> **`P2pProxyAddress`** — Set this to your **server's public IP**. This is how invite codes route players to your server over the internet. For LAN-only, leave as `127.0.0.1`.

> **`InviteCode`** — Read-only; generated by Windrose on first run. Share this with players.

### `WorldDescription.json`

Located at: `<Wine AppData>/R5/Saved/SaveProfiles/Default/RocksDB/<version>/Worlds/<WorldIslandId>/`

Example from official docs:
```json
{
  "Version": 1,
  "WorldDescription": {
    "IslandId": "DB57768A8A7746899683D0EEE91F97BF",
    "WorldName": "isp",
    "WorldPresetType": "Medium",
    "WorldSettings": {
      "BoolParameters": {
        "{\"TagName\": \"WDS.Parameter.Coop.SharedQuests\"}": true,
        "{\"TagName\": \"WDS.Parameter.EasyExplore\"}": false
      },
      "FloatParameters": {
        "{\"TagName\": \"WDS.Parameter.MobHealthMultiplier\"}": 1,
        "{\"TagName\": \"WDS.Parameter.MobDamageMultiplier\"}": 1,
        "{\"TagName\": \"WDS.Parameter.ShipsHealthMultiplier\"}": 1,
        "{\"TagName\": \"WDS.Parameter.ShipsDamageMultiplier\"}": 1,
        "{\"TagName\": \"WDS.Parameter.BoardingDifficultyMultiplier\"}": 1,
        "{\"TagName\": \"WDS.Parameter.Coop.StatsCorrectionModifier\"}": 1,
        "{\"TagName\": \"WDS.Parameter.Coop.ShipStatsCorrectionModifier\"}": 0
      },
      "TagParameters": {
        "{\"TagName\": \"WDS.Parameter.CombatDifficulty\"}": {
          "TagName": "WDS.Parameter.CombatDifficulty.Normal"
        }
      }
    }
  }
}
```

Difficulty presets: `Easy`, `Medium`, `Hard`

---

## Save Data Location (Wine)

On Windows, saves are in:
```
C:\Users\{User}\AppData\Local\R5\Saved\SaveProfiles\
```

Under Wine on Linux, this maps to:
```
/home/windrose/.wine/drive_c/users/windrose/AppData/Local/R5/Saved/SaveProfiles/
```

The `backup` command backs up this path automatically.

---

## Networking

Windrose uses **NAT punch-through with invite codes** by default:
- Players join via the invite code shown in `ServerDescription.json`
- **No port forwarding required** for invite-code connections
- `netstat` will **not** show UDP 7777/7778 as normal Linux listeners — Windrose
  uses its own R5P2P socket layer. This is normal.
- For direct/public access, open these ports in your firewall:

```bash
# iptables example
iptables -A INPUT -p udp --dport 7777 -j ACCEPT  # Game port
iptables -A INPUT -p udp --dport 7778 -j ACCEPT  # Query port
```

---

## Slackware-Specific Notes

### Wine Installation
Wine is not in Slackware 15.0's base packages. Install via:
- **SlackBuilds.org:** https://slackbuilds.org/repository/15.0/system/wine/
- Requires multilib (already set up on this server)

### xvfb-run
If `xvfb-run` is missing but `Xvfb` is present, the setup script creates a
minimal wrapper at `/usr/local/bin/xvfb-run`.

### `vm.mmap_min_addr` — Critical Wine Fix

> [!WARNING]
> Slackware ships with `vm.mmap_min_addr = 98304`. Wine requires this to be
> **`65536` or lower** to reserve the low-memory range it needs. Without this fix,
> Wine prints preloader warnings and the server may fail to initialize correctly.

```bash
# As root — apply immediately:
sysctl -w vm.mmap_min_addr=65536

# Persist across reboots:
echo 'vm.mmap_min_addr = 65536' > /etc/sysctl.d/99-windrose-wine.conf
```

The manager script checks this value before `start`, `debug`, and `winesetup`
and fails with a clear error message if the value is too high.

### Visual C++ 2022 x64 Redistributable

> [!WARNING]
> `winetricks -q vcrun2022` installs the **x86** (32-bit) runtime first and may
> abort before installing the **x64** runtime needed by `WindroseServer-Win64-Shipping.exe`.
> Install the x64 VC++ redistributable **directly**:

```bash
mkdir -p /home/windrose/.cache/winetricks/vcrun2022
curl -L --fail --output /home/windrose/.cache/winetricks/vcrun2022/vc_redist.x64.exe \
  https://aka.ms/vs/17/release/vc_redist.x64.exe

WINEPREFIX=/home/windrose/.wine WINEARCH=win64 \
  xvfb-run -a wine /home/windrose/.cache/winetricks/vcrun2022/vc_redist.x64.exe \
  /install /quiet /norestart
```

### Boot Persistence (SysV — Slackware default)
```bash
# After setup:
cp /home/windrose/rc.windrose /etc/rc.d/rc.windrose
chmod +x /etc/rc.d/rc.windrose

# Add to /etc/rc.d/rc.local:
[ -x /etc/rc.d/rc.windrose ] && /etc/rc.d/rc.windrose start
```

## Updating the Server

> [!WARNING]
> **The server version must match the game client version.** Always update your
> dedicated server when the Windrose game client updates, or players will get
> connection errors.

```bash
sudo -u windrose /home/windrose/windroseserver update
```

Per the official guide, the update flow is automatic via SteamCMD.
Your save data is stored separately (in the Wine AppData path) and is
**not** overwritten by server file updates.

---

## Auto-Monitor via Cron (installed by setup)

The setup script installs a cron job for the `windrose` user that runs
`windroseserver monitor` every 5 minutes. If the server crashes, it restarts
automatically — the same pattern LinuxGSM uses.

View cron:
```bash
sudo crontab -u windrose -l
```

---

## Troubleshooting

### Checking Real Server Health

The strongest health indicators are in the Unreal Engine game log (not the Wine stdout log):

```bash
tail -f /home/windrose/serverfiles/R5/Saved/Logs/R5.log
```

Look for these lines to confirm a healthy, running server:
```
Initialized as an R5P2P listen server
CoopProxy. Change state. WaitingForRegistration => Registered
Server. Change state LoadedIslandData => WaitingForFirstAccount
```

### Server says RUNNING but no invite code

Check the process name in `ps`:
```bash
ps -fu windrose | grep -i windrose
```

**Good** — real UE5 server binary:
```
WindroseServer-Win64-Shipping.exe
```

**Bad** — bootstrapper stuck on hidden VC++ prompt:
```
WindroseServer.exe
```

If you see the bad output, the manager is misconfigured or the `serverexe` variable
is wrong. The correct value is `R5/Binaries/Win64/WindroseServer-Win64-Shipping.exe`.

### Diagnosing hidden Wine dialog in Xvfb

If the process is alive but nothing is happening:
```bash
# Find the Xvfb display from ps output, then:
DISPLAY=:99 XAUTHORITY=/tmp/xvfb-run.XYZ/Xauthority xwininfo -root -tree
DISPLAY=:99 XAUTHORITY=/tmp/xvfb-run.XYZ/Xauthority import -window root /tmp/windrose-xvfb.png
```
An earlier bad state showed a window titled `Error` waiting for VC++ installation.

### vm.mmap_min_addr too high
```bash
cat /proc/sys/vm/mmap_min_addr
# Must be 65536 or lower. Fix:
sysctl -w vm.mmap_min_addr=65536
```

### Server won't start — check debug output
```bash
sudo -u windrose /home/windrose/windroseserver debug
```
This runs Wine in the foreground without tmux, showing all output/errors.

### Wine crashes / DLL errors
```bash
# Re-run Wine prefix setup with vcrun2022 (x64 direct installer)
curl -L --fail -o /tmp/vc_redist.x64.exe https://aka.ms/vs/17/release/vc_redist.x64.exe
WINEPREFIX=/home/windrose/.wine WINEARCH=win64 \
  xvfb-run -a wine /tmp/vc_redist.x64.exe /install /quiet /norestart
```

### SteamCMD fails ("No subscription" or similar)
The Windrose Dedicated Server is a **free app** — anonymous login should work.
If it still fails:
1. Is your server's internet connection working?
2. Check https://store.steampowered.com for Steam outages
3. As a last resort, create a free Steam account and set credentials in `secrets-windroseserver.cfg`

### Invite code not working for remote players
The `P2pProxyAddress` in `ServerDescription.json` must be your server's **public IP**.
Set it in `windroseserver.cfg`:
```bash
p2pproxyaddress="YOUR.PUBLIC.IP.HERE"
```
Then restart the server so the manager syncs it to `ServerDescription.json`.

### UE5 "display" errors
Ensure `xvfb-run` and `Xvfb` are functional:
```bash
xvfb-run -a wine --version
```
Should print the Wine version. If it fails, Xvfb needs fixing.

### Finding your invite code manually
```bash
# After the server has run at least once:
sudo -u windrose /home/windrose/windroseserver details
# Or directly:
cat /home/windrose/serverfiles/R5/ServerDescription.json
```

### Check logs
```bash
# Primary game log (most useful for health checks):
tail -f /home/windrose/serverfiles/R5/Saved/Logs/R5.log

# Manager script actions:
tail -f /home/windrose/log/script/windroseserver-script.log

# Wine/stdout capture:
tail -f /home/windrose/log/server/windroseserver-server.log
```

---

## Technical Notes

- **Server is a free Steam app:** AppID 4129620 is free to everyone — anonymous SteamCMD login should work.
- **SteamCMD platform override:** `@sSteamCmdForcePlatformType windows` downloads the Windows depot on Linux. This is intentional.
- **Real server binary:** `R5/Binaries/Win64/WindroseServer-Win64-Shipping.exe` — NOT the root `WindroseServer.exe` (which is a Windows VC++ bootstrapper).
- **Save data under Wine:** Stored in `WINEPREFIX/drive_c/users/windrose/AppData/Local/R5/` (not in serverfiles).
- **ServerDescription.json location:** `serverfiles/R5/ServerDescription.json` (not the serverfiles root as older docs suggest).
- **P2pProxyAddress:** Must match your server's public IP for internet-facing invite codes to work.
- **netstat won't show 7777/7778:** Windrose uses its R5P2P socket layer. Use the R5.log health lines to confirm the server is up.
- **vm.mmap_min_addr:** Must be ≤ 65536 for Wine preloader on Slackware. Set with `sysctl -w vm.mmap_min_addr=65536`.
- **Wine version:** Recommend Wine Staging 8+ or Wine 9+ for best Unreal Engine 5 compatibility.
- **VC++ x64 runtime:** Must install `vc_redist.x64.exe` directly; winetricks may skip the x64 installer.
- **Version matching:** Server version **must match** game client version. Run `windroseserver update` after every Windrose patch.
- **Performance:** Wine overhead for UE5 server workloads is typically 5–15%.
- **Official Discord:** https://discord.gg/windrose (for game-specific support)
