#!/usr/bin/env bash

set -euo pipefail

readonly component_id="org.kde.plasma.serverstatus"
readonly package_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/package"
readonly data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
readonly notifyrc_source="${package_dir}/contents/notifications/${component_id}.notifyrc"
readonly desktop_source="${package_dir}/contents/notifications/${component_id}.desktop"
readonly notifyrc_target="${data_home}/knotifications6/${component_id}.notifyrc"
readonly desktop_target="${data_home}/applications/${component_id}.desktop"

restart_plasmashell=true

for arg in "$@"; do
	case "$arg" in
		--no-restart)
			restart_plasmashell=false
			;;
		*)
			echo "Unknown option: $arg" >&2
			echo "Usage: $0 [--no-restart]" >&2
			exit 1
			;;
	esac
done

if ! command -v kpackagetool6 >/dev/null 2>&1; then
	echo "kpackagetool6 is required" >&2
	exit 1
fi

if kpackagetool6 --type Plasma/Applet --show "$component_id" >/dev/null 2>&1; then
	kpackagetool6 --type Plasma/Applet --upgrade "$package_dir"
else
	kpackagetool6 --type Plasma/Applet --install "$package_dir"
fi

install -Dm644 "$notifyrc_source" "$notifyrc_target"
install -Dm644 "$desktop_source" "$desktop_target"

if command -v update-desktop-database >/dev/null 2>&1; then
	update-desktop-database "$data_home/applications"
fi

if command -v kbuildsycoca6 >/dev/null 2>&1; then
	kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
fi

echo "Installed ${component_id}"
echo "  notifyrc: ${notifyrc_target}"
echo "  desktop:  ${desktop_target}"

if $restart_plasmashell; then
	systemctl --user restart plasma-plasmashell.service
fi
