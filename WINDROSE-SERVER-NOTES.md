# Windrose Dedicated Server Notes

This host runs the Windrose Dedicated Server on Slackware 15 using Wine, Xvfb,
tmux, SteamCMD, and a LinuxGSM-style manager script.

## Current Status

- Server manager: `/home/windrose/windroseserver`
- Server files: `/home/windrose/serverfiles`
- Active server binary: `/home/windrose/serverfiles/R5/Binaries/Win64/WindroseServer-Win64-Shipping.exe`
- Wine prefix: `/home/windrose/.wine`
- tmux session: `windroseserver`
- Server name: `Valhalla Server`
- Invite code at last verification: `3215fd85`
- Password: configured in `/home/windrose/lgsm/config-lgsm/windroseserver/windroseserver.cfg`
- Max players: `4`
- P2P proxy address: `127.0.0.1`
- Auto-monitor cron: `*/5 * * * * /home/windrose/windroseserver monitor > /dev/null 2>&1`

The server has been verified working. The game log showed:

- `CoopProxy. Change state. WaitingForRegistration => Registered`
- `Initialized as an R5P2P listen server`
- `Server. Change state LoadedIslandData => WaitingForFirstAccount`

`netstat` does not show UDP `7777/7778` as normal Linux listeners. Windrose uses
its R5 P2P socket layer, so the better success signals are the invite code,
`ServerDescription.json`, and the R5 log entries above.

## Normal Commands

Run these as the `windrose` user from `/home/windrose`.

```bash
./windroseserver start
./windroseserver stop
./windroseserver restart
./windroseserver details
./windroseserver logs
./windroseserver console
./windroseserver monitor
```

Useful checks:

```bash
tmux ls
ps -fu windrose
tail -f /home/windrose/serverfiles/R5/Saved/Logs/R5.log
tail -f /home/windrose/log/server/windroseserver-server.log
cat /proc/sys/vm/mmap_min_addr
crontab -l
```

## Important Paths

- Main manager script: `/home/windrose/windroseserver`
- Root setup script: `/home/windrose/windrose-setup.sh`
- Main config: `/home/windrose/lgsm/config-lgsm/windroseserver/windroseserver.cfg`
- Secrets config: `/home/windrose/lgsm/config-lgsm/windroseserver/secrets-windroseserver.cfg`
- Generated server description: `/home/windrose/serverfiles/R5/ServerDescription.json`
- Unreal/game log: `/home/windrose/serverfiles/R5/Saved/Logs/R5.log`
- Manager log: `/home/windrose/log/script/windroseserver-script.log`
- Captured Wine/stdout log: `/home/windrose/log/server/windroseserver-server.log`
- Save data under Wine: `/home/windrose/.wine/drive_c/users/windrose/AppData/Local/R5/Saved/SaveProfiles`
- SteamCMD: `/home/windrose/.steam/steamcmd/steamcmd.sh`

## What Was Fixed

### 1. Wine low-memory mapping on Slackware

Wine initially printed:

```text
preloader: Warning: failed to reserve range 0000000000010000-0000000000110000
```

The host had:

```bash
/proc/sys/vm/mmap_min_addr = 98304
```

Wine needs to reserve starting at `0x10000`, which is decimal `65536`.
The working setting is:

```bash
sysctl -w vm.mmap_min_addr=65536
echo 'vm.mmap_min_addr = 65536' > /etc/sysctl.d/99-windrose-wine.conf
```

The manager now checks this before `start`, `debug`, and `winesetup`, and fails
with a clear message if the value is too high.

### 2. Hidden VC++ redistributable prompt

The original launch target was:

```text
/home/windrose/serverfiles/WindroseServer.exe
```

That file is not the real UE server. It is a Windows prerequisite bootstrapper.
Under headless Wine/Xvfb it opened a hidden dialog titled `Error` asking for:

```text
Microsoft Visual C++ 2015-2022 Redistributable (x64)
```

The process looked alive in tmux, but it never created `ServerDescription.json`,
opened the game world, or emitted useful server logs.

The x64 VC++ runtime was installed directly into the Wine prefix:

```bash
curl -L --fail --output /home/windrose/.cache/winetricks/vcrun2022/vc_redist.x64.exe https://aka.ms/vs/17/release/vc_redist.x64.exe
WINEPREFIX=/home/windrose/.wine WINEARCH=win64 xvfb-run -a wine /home/windrose/.cache/winetricks/vcrun2022/vc_redist.x64.exe /install /quiet /norestart
```

`winetricks -q --force vcrun2022` failed because it tried the x86 installer
first and aborted before the x64 installer. The direct x64 installer succeeded.

### 3. Bypass the bootstrapper

The manager now launches the real server binary directly:

```text
/home/windrose/serverfiles/R5/Binaries/Win64/WindroseServer-Win64-Shipping.exe
```

The generated launcher command is effectively:

```bash
WINEDEBUG=-all \
WINEPREFIX=/home/windrose/.wine \
WINEARCH=win64 \
xvfb-run -a wine /home/windrose/serverfiles/R5/Binaries/Win64/WindroseServer-Win64-Shipping.exe \
  -PORT=7777 -QUERYPORT=7778 -log -MULTIHOME=0.0.0.0
```

### 4. ServerDescription sync

Windrose creates and uses:

```text
/home/windrose/serverfiles/R5/ServerDescription.json
```

The manager now syncs these settings from `windroseserver.cfg` into that JSON
before launch:

- `ServerName`
- `Password`
- `IsPasswordProtected`
- `MaxPlayerCount`
- `P2pProxyAddress`

This matters because Windrose rewrites or keeps its own JSON. After the sync,
`./windroseserver details` confirmed:

- password protection enabled
- server name `Valhalla Server`
- max players `4`
- invite code `3215fd85`

## Connection Notes

Players connect in-game using:

```text
Play -> Connect to Server -> invite code
```

Current invite code:

```text
3215fd85
```

If internet players cannot connect, update:

```bash
/home/windrose/lgsm/config-lgsm/windroseserver/windroseserver.cfg
```

Change:

```bash
p2pproxyaddress="127.0.0.1"
```

to the server's public IP, then restart:

```bash
/home/windrose/windroseserver restart
```

## Troubleshooting

### Server says RUNNING but no invite code

Check whether the manager is launching the shipping binary:

```bash
ps -fu windrose | grep -i Windrose
```

Good:

```text
WindroseServer-Win64-Shipping.exe
```

Bad:

```text
WindroseServer.exe
```

If it is the root `WindroseServer.exe`, the server is probably stuck on the
hidden VC++ prompt.

### Hidden Wine dialog in Xvfb

Find the Xvfb display/auth path from `ps -fu windrose`, then inspect:

```bash
DISPLAY=:99 XAUTHORITY=/tmp/xvfb-run.XYZ/Xauthority xwininfo -root -tree
DISPLAY=:99 XAUTHORITY=/tmp/xvfb-run.XYZ/Xauthority import -window root /tmp/windrose-xvfb.png
```

The earlier bad state showed a window titled `Error` from `windroseserver.exe`.

### mmap failure

Check:

```bash
cat /proc/sys/vm/mmap_min_addr
```

The value must be `65536` or lower. This setup uses `65536`.

### Check real game health

The strongest health log lines are in:

```bash
/home/windrose/serverfiles/R5/Saved/Logs/R5.log
```

Look for:

```text
Initialized as an R5P2P listen server
WaitingForFirstAccount
```

### Re-enable monitor cron

If it was disabled during maintenance:

```bash
(crontab -l 2>/dev/null; echo '*/5 * * * * /home/windrose/windroseserver monitor > /dev/null 2>&1') | awk '!seen[$0]++' | crontab -
```

## Hardware Note

The server is running acceptably on older hardware. Startup has visible CPU load
and logs may show slow DB/world loading warnings, but the final verified state is
healthy: world loaded, P2P listen server initialized, and the server is waiting
for the first account/player.
