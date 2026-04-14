#!/bin/bash
# ============================================================
# windrose-setup.sh — One-Shot Root Installer
# Mirrors the LinuxGSM server setup approach:
#   - Creates dedicated 'windrose' system user
#   - Installs Wine, Xvfb, SteamCMD, winetricks
#   - Deploys windroseserver script under the windrose user
#   - Installs systemd service for boot persistence
#   - Hands off to 'windrose' user for the actual game install
#
# Usage: sudo bash windrose-setup.sh
# Platform: Slackware Linux 15.0 x86_64 with multilib
# ============================================================

set -euo pipefail

# --- Color Codes ---
red="\e[0;31m"; green="\e[0;32m"; yellow="\e[0;33m"
lightblue="\e[1;34m"; lightcyan="\e[1;36m"; white="\e[1;37m"; default="\e[0m"

fn_print_ok()   { echo -e "[ ${green}OK${default} ] $*"; }
fn_print_info() { echo -e "[ ${lightcyan}INFO${default} ] $*"; }
fn_print_warn() { echo -e "[ ${yellow}WARN${default} ] $*"; }
fn_print_fail() { echo -e "[ ${red}FAIL${default} ] $*"; }
fn_print_head() { echo -e "\n${lightcyan}--- $* ---${default}"; }

# --- Configuration ---
WINDROSE_USER="windrose"
WINDROSE_HOME="/home/${WINDROSE_USER}"
INSTALL_DIR="${WINDROSE_HOME}"
SCRIPT_SOURCE="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")")"

# ============================================================
# Preflight Checks
# ============================================================
fn_check_root() {
	if [ "$(id -u)" -ne 0 ]; then
		fn_print_fail "This script must be run as root."
		echo "       Usage: sudo bash windrose-setup.sh"
		exit 1
	fi
}

fn_check_os() {
	fn_print_head "Checking OS"
	if [ -f /etc/os-release ]; then
		source /etc/os-release
		fn_print_info "Detected: ${PRETTY_NAME}"
		if [[ "${ID}" != "slackware" ]]; then
			fn_print_warn "This script is designed for Slackware Linux."
			fn_print_warn "Other distros may work but are untested."
			read -rp "Continue anyway? [y/N]: " confirm
			[[ "${confirm}" =~ ^[Yy]$ ]] || exit 1
		fi
	fi
	if [ "$(uname -m)" != "x86_64" ]; then
		fn_print_fail "This script requires x86_64 architecture."
		exit 1
	fi
	fn_print_ok "OS check passed."
}

fn_check_multilib() {
	fn_print_head "Checking multilib (required for Wine)"
	if [ -d /usr/lib64 ] && [ -d /usr/lib ]; then
		# Check for 32-bit glibc as an indicator of working multilib
		if ldconfig -p 2>/dev/null | grep -q "lib/i386"; then
			fn_print_ok "Multilib appears configured."
		elif ls /lib/i386-linux-gnu 2>/dev/null | grep -q libc; then
			fn_print_ok "Multilib appears configured."
		else
			fn_print_warn "32-bit libraries may not be present."
			fn_print_info "Wine on Slackware requires multilib."
			fn_print_info "If Wine install fails, verify your multilib setup."
			fn_print_info "Slackware multilib: https://alien.slackbook.org/wiki/slackonly:multilib"
		fi
	fi
}

# ============================================================
# User Creation
# ============================================================
fn_create_user() {
	fn_print_head "Creating '${WINDROSE_USER}' user"
	if id "${WINDROSE_USER}" &>/dev/null; then
		fn_print_info "User '${WINDROSE_USER}' already exists."
	else
		useradd -m -s /bin/bash "${WINDROSE_USER}"
		fn_print_ok "User '${WINDROSE_USER}' created (home: ${WINDROSE_HOME})."
	fi

	# Create standard LinuxGSM-style directory structure
	mkdir -p "${INSTALL_DIR}/lgsm/config-lgsm/windroseserver"
	mkdir -p "${INSTALL_DIR}/log/server"
	mkdir -p "${INSTALL_DIR}/log/script"
	mkdir -p "${INSTALL_DIR}/serverfiles"
	mkdir -p "${INSTALL_DIR}/backup"
	mkdir -p "${INSTALL_DIR}/lgsm/tmp"
	chown -R "${WINDROSE_USER}:${WINDROSE_USER}" "${INSTALL_DIR}"
	fn_print_ok "Directory structure created."
}

# ============================================================
# Dependency Installation (Slackware-specific)
# ============================================================
fn_install_wine() {
	fn_print_head "Checking Wine"

	if command -v wine64 &>/dev/null; then
		local wine_ver
		wine_ver="$(wine64 --version 2>&1)"
		fn_print_info "Wine already installed: ${wine_ver}"
		return 0
	fi

	fn_print_info "Wine not found. Attempting installation..."
	fn_print_info "Slackware Wine installation options:"
	echo ""
	echo -e "  ${white}Option 1 (Recommended): SlackBuilds.org${default}"
	echo "    Source: https://slackbuilds.org/repository/15.0/system/wine/"
	echo "    Requires: sbopkg or manual SlackBuild compilation"
	echo ""
	echo -e "  ${white}Option 2: WineHQ Repository${default}"
	echo "    Not natively supported on Slackware — requires manual adaptation"
	echo ""
	echo -e "  ${white}Option 3: Slackware-current packages${default}"
	echo "    Check: https://slackware.nl/slackware-current/slackware64/extra/"
	echo ""

	# Attempt sbopkg automated install if available
	if command -v sbopkg &>/dev/null; then
		fn_print_info "sbopkg detected. Attempting: sbopkg -i wine"
		read -rp "Attempt sbopkg Wine install? [y/N]: " do_sbopkg
		if [[ "${do_sbopkg}" =~ ^[Yy]$ ]]; then
			sbopkg -B -i wine || {
				fn_print_warn "sbopkg Wine install failed or incomplete."
				fn_print_warn "Please install Wine manually and re-run this script."
			}
		fi
	else
		fn_print_warn "sbopkg not found. Wine must be installed manually."
		fn_print_warn "After installing Wine, re-run this script."
		echo ""
		echo "Manual SlackBuild process:"
		echo "  1. Download from: https://slackbuilds.org/repository/15.0/system/wine/"
		echo "  2. cd wine-slackbuild-directory"
		echo "  3. sh wine.SlackBuild"
		echo "  4. installpkg /tmp/wine*.t?z"
		echo "  5. Re-run this setup script."
		echo ""
		read -rp "Wine not installed. Continue setup anyway? [y/N]: " cont
		[[ "${cont}" =~ ^[Yy]$ ]] || exit 1
	fi
}

fn_install_winetricks() {
	fn_print_head "Checking winetricks"
	if command -v winetricks &>/dev/null; then
		fn_print_ok "winetricks is available."
		return 0
	fi

	fn_print_info "Installing winetricks..."
	local wt_url="https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks"
	if curl -fsSL "${wt_url}" -o /usr/local/bin/winetricks; then
		chmod +x /usr/local/bin/winetricks
		fn_print_ok "winetricks installed to /usr/local/bin/winetricks"
	else
		fn_print_warn "Failed to download winetricks. Server may still work without it."
		fn_print_info "Manual install: https://github.com/Winetricks/winetricks"
	fi
}

fn_install_xvfb() {
	fn_print_head "Checking Xvfb (virtual framebuffer)"
	if command -v Xvfb &>/dev/null; then
		fn_print_ok "Xvfb is available."
		return 0
	fi

	fn_print_warn "Xvfb not found."
	fn_print_info "Xvfb is required — Unreal Engine 5 servers need a display even headless."
	echo ""
	echo "On Slackware, Xvfb is part of xorg-server:"
	echo "  Check: ls /usr/bin/Xvfb"
	echo "  If missing, reinstall: installpkg xorg-server-*.t?z"
	echo "  Or upgrade to -current repo which may include xvfb-run"
	echo ""
	echo "xvfb-run wrapper (needed by the manager script):"
	echo "  If xvfb-run is missing but Xvfb is present, we can create a wrapper."
	echo ""

	if command -v Xvfb &>/dev/null && ! command -v xvfb-run &>/dev/null; then
		fn_print_info "Xvfb found but xvfb-run missing. Creating xvfb-run wrapper..."
		cat > /usr/local/bin/xvfb-run << 'XVFBRUN'
#!/bin/bash
# Minimal xvfb-run wrapper for Slackware
# Usage: xvfb-run [-a] [-s options] command [args...]
display=:99
while getopts "as:" opt; do
    case $opt in
        a) display=":$(shuf -i 100-399 -n 1)" ;;
        s) Xvfb_opts="$OPTARG" ;;
    esac
done
shift $((OPTIND-1))
Xvfb ${display} -screen 0 1024x768x24 ${Xvfb_opts:-} &
Xvfb_pid=$!
DISPLAY=${display} "$@"
exitcode=$?
kill $Xvfb_pid 2>/dev/null
exit $exitcode
XVFBRUN
		chmod +x /usr/local/bin/xvfb-run
		fn_print_ok "xvfb-run wrapper created."
	else
		fn_print_warn "Please install xorg-server with Xvfb support."
	fi
}

fn_install_steamcmd_deps() {
	fn_print_head "Checking SteamCMD dependencies"
	# SteamCMD is a 32-bit binary that needs these libs
	local missing_libs=()
	for lib in libGL.so.1 libcurl.so.4; do
		if ! ldconfig -p 2>/dev/null | grep -q "${lib}"; then
			missing_libs+=("${lib}")
		fi
	done
	if [ ${#missing_libs[@]} -gt 0 ]; then
		fn_print_warn "Possibly missing SteamCMD libs: ${missing_libs[*]}"
		fn_print_info "These are typically provided by mesa, curl, and their 32-bit counterparts."
	else
		fn_print_ok "SteamCMD dependencies appear present."
	fi
}

fn_check_tmux() {
	fn_print_head "Checking tmux"
	if command -v tmux &>/dev/null; then
		fn_print_ok "tmux: $(tmux -V)"
	else
		fn_print_fail "tmux not found. Install tmux from Slackware packages."
		exit 1
	fi
}

# ============================================================
# Deploy Manager Script
# ============================================================
fn_deploy_script() {
	fn_print_head "Deploying windroseserver manager script"

	local src="${SCRIPT_SOURCE}/windroseserver"
	local dst="${INSTALL_DIR}/windroseserver"

	if [ ! -f "${src}" ]; then
		fn_print_fail "windroseserver script not found at: ${src}"
		fn_print_info "Ensure windrose-setup.sh is in the same directory as windroseserver."
		exit 1
	fi

	cp "${src}" "${dst}"
	chmod +x "${dst}"
	chown "${WINDROSE_USER}:${WINDROSE_USER}" "${dst}"
	fn_print_ok "Deployed: ${dst}"
}

# ============================================================
# Systemd Service
# ============================================================
fn_install_systemd() {
	fn_print_head "Installing systemd service"

	if ! command -v systemctl &>/dev/null; then
		fn_print_warn "systemctl not found. Skipping systemd service setup."
		fn_print_info "For Slackware SysV init, see: ${INSTALL_DIR}/rc.windrose"
		fn_sysvinit_script
		return 0
	fi

	cat > /etc/systemd/system/windroseserver.service << SVCEOF
[Unit]
Description=Windrose Dedicated Game Server
After=network.target
Wants=network-online.target

[Service]
Type=oneshot
User=${WINDROSE_USER}
Group=${WINDROSE_USER}
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/windroseserver start
ExecStop=${INSTALL_DIR}/windroseserver stop
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal
Restart=no

[Install]
WantedBy=multi-user.target
SVCEOF

	systemctl daemon-reload
	fn_print_ok "systemd service installed: windroseserver.service"
	fn_print_info "Enable on boot: systemctl enable windroseserver"
	fn_print_info "Start now:      systemctl start windroseserver"
}

# ============================================================
# Slackware SysV Init Script (fallback for no systemd)
# ============================================================
fn_sysvinit_script() {
	local rc_script="${INSTALL_DIR}/rc.windrose"
	cat > "${rc_script}" << RCEOF
#!/bin/bash
# /etc/rc.d/rc.windrose — Windrose Server SysV Init Script
# To enable: chmod +x /etc/rc.d/rc.windrose
# To disable: chmod -x /etc/rc.d/rc.windrose
# Add to /etc/rc.d/rc.local: [ -x /etc/rc.d/rc.windrose ] && /etc/rc.d/rc.windrose start

WINDROSE_USER="${WINDROSE_USER}"
WINDROSE_DIR="${INSTALL_DIR}"
SCRIPT="\${WINDROSE_DIR}/windroseserver"

case "\$1" in
    start)
        echo "Starting Windrose server..."
        su - "\${WINDROSE_USER}" -c "\${SCRIPT} start"
        ;;
    stop)
        echo "Stopping Windrose server..."
        su - "\${WINDROSE_USER}" -c "\${SCRIPT} stop"
        ;;
    restart)
        su - "\${WINDROSE_USER}" -c "\${SCRIPT} restart"
        ;;
    status)
        su - "\${WINDROSE_USER}" -c "\${SCRIPT} details"
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart|status}"
        ;;
esac
RCEOF
	chmod +x "${rc_script}"
	chown "${WINDROSE_USER}:${WINDROSE_USER}" "${rc_script}"
	fn_print_ok "SysV init script: ${rc_script}"
	echo ""
	echo "To enable on boot:"
	echo "  cp ${rc_script} /etc/rc.d/rc.windrose"
	echo "  chmod +x /etc/rc.d/rc.windrose"
	echo "  Add to /etc/rc.d/rc.local:"
	echo "    [ -x /etc/rc.d/rc.windrose ] && /etc/rc.d/rc.windrose start"
}

# ============================================================
# Cronjob setup (for monitor command — auto-restart if crashed)
# ============================================================
fn_setup_cron() {
	fn_print_head "Setting up cron monitor (auto-restart on crash)"
	local crontab_entry="*/5 * * * * ${INSTALL_DIR}/windroseserver monitor > /dev/null 2>&1"
	local current_cron
	current_cron="$(crontab -u "${WINDROSE_USER}" -l 2>/dev/null || true)"

	if echo "${current_cron}" | grep -q "windroseserver monitor"; then
		fn_print_info "Cron monitor already configured."
	else
		(echo "${current_cron}"; echo "${crontab_entry}") | crontab -u "${WINDROSE_USER}" -
		fn_print_ok "Cron monitor installed (checks every 5 minutes)."
	fi
}

# ============================================================
# Final Handoff & Instructions
# ============================================================
fn_print_summary() {
	echo ""
	echo -e "${lightcyan}╔══════════════════════════════════════════════════════╗${default}"
	echo -e "${lightcyan}║${white}   Windrose Server Setup Complete!                  ${lightcyan}║${default}"
	echo -e "${lightcyan}╚══════════════════════════════════════════════════════╝${default}"
	echo ""
	echo -e " ${white}Next Steps:${default}"
	echo ""
	echo -e " ${lightblue}1. Switch to windrose user and install the server:${default}"
	echo -e "    ${yellow}sudo -u ${WINDROSE_USER} ${INSTALL_DIR}/windroseserver install${default}"
	echo ""
	echo -e " ${lightblue}2. If install fails with 'No subscription', edit:${default}"
	echo -e "    ${yellow}${INSTALL_DIR}/lgsm/config-lgsm/windroseserver/secrets-windroseserver.cfg${default}"
	echo -e "    Set steamuser and steampass (use a dedicated Steam account!)"
	echo ""
	echo -e " ${lightblue}3. Start the server:${default}"
	echo -e "    ${yellow}sudo -u ${WINDROSE_USER} ${INSTALL_DIR}/windroseserver start${default}"
	echo ""
	echo -e " ${lightblue}4. Check details and get your invite code:${default}"
	echo -e "    ${yellow}sudo -u ${WINDROSE_USER} ${INSTALL_DIR}/windroseserver details${default}"
	echo ""
	echo -e " ${lightblue}5. Enable on boot:${default}"
	if command -v systemctl &>/dev/null; then
		echo -e "    ${yellow}systemctl enable windroseserver${default}"
	else
		echo -e "    ${yellow}cp ${INSTALL_DIR}/rc.windrose /etc/rc.d/rc.windrose${default}"
		echo -e "    ${yellow}chmod +x /etc/rc.d/rc.windrose${default}"
	fi
	echo ""
	echo -e " ${lightblue}Ports to open in firewall (if needed):${default}"
	echo -e "    UDP 7777  (game port)"
	echo -e "    UDP 7778  (query port)"
	echo ""
	echo -e " ${white}Note: Invite codes work without port forwarding (NAT punch-through)${default}"
	echo ""
}

# ============================================================
# Main
# ============================================================
main() {
	echo ""
	echo -e "${lightcyan}╔══════════════════════════════════════════════════════╗${default}"
	echo -e "${lightcyan}║${white}   Windrose Server Setup — Slackware Linux 15.0     ${lightcyan}║${default}"
	echo -e "${lightcyan}╚══════════════════════════════════════════════════════╝${default}"
	echo ""

	fn_check_root
	fn_check_os
	fn_check_multilib
	fn_check_tmux
	fn_create_user
	fn_install_wine
	fn_install_winetricks
	fn_install_xvfb
	fn_install_steamcmd_deps
	fn_deploy_script
	fn_install_systemd
	fn_setup_cron
	fn_print_summary
}

main "$@"
