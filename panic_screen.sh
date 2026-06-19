#!/bin/sh
# panic_screen.sh — view / switch the drm_panic screen formatter at runtime.
#
# drm_panic (CONFIG_DRM_PANIC) can draw one of three things when the kernel
# dies. This toggles it live via /sys/module/drm/parameters/panic_screen.
# The setting is a module parameter, so it resets to the kernel default on
# reboot. To make a choice permanent, add drm.panic_screen=<mode> to your
# kernel command line instead.
#
#   user     - short "system crashed, please reboot" message (minimal)
#   kmsg     - the last lines of dmesg, as plain text
#   qr_code  - a QR code encoding the panic info + report URL
#
# Usage:
#   ./panic_screen.sh                 # interactive menu
#   ./panic_screen.sh status          # just print the current mode
#   ./panic_screen.sh user|kmsg|qr_code   # set directly (non-interactive)

set -eu

PARAM=/sys/module/drm/parameters/panic_screen
MODES="user kmsg qr_code"

die() { echo "error: $*" >&2; exit 1; }

[ -e "$PARAM" ] || die "$PARAM not found — is CONFIG_DRM_PANIC enabled and drm loaded?"

current() { cat "$PARAM"; }

# Write needs root; re-exec through sudo only for the actual write.
set_mode() {
	mode=$1
	case " $MODES " in
		*" $mode "*) ;;
		*) die "invalid mode '$mode' (pick: $MODES)";;
	esac

	if [ -w "$PARAM" ] && [ "$(id -u)" = 0 ]; then
		printf '%s' "$mode" > "$PARAM"
	else
		printf '%s' "$mode" | sudo tee "$PARAM" >/dev/null
	fi
	echo "panic_screen is now: $(current)"
}

# Non-interactive paths.
if [ $# -ge 1 ]; then
	case $1 in
		status|-s|--status) echo "current panic_screen: $(current)"; exit 0;;
		user|kmsg|qr_code)  set_mode "$1"; exit 0;;
		-h|--help)
			sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
		*) die "unknown argument '$1' (try: status, user, kmsg, qr_code)";;
	esac
fi

# Interactive menu.
cur=$(current)
echo "Current drm_panic screen: $cur"
echo
echo "  1) user     - short 'please reboot' message (minimal)"
echo "  2) kmsg     - last lines of dmesg, plain text"
echo "  3) qr_code  - QR code with panic info + report URL"
echo "  q) quit (no change)"
echo
printf 'Choose [1-3/q]: '
read -r choice

case $choice in
	1) set_mode user;;
	2) set_mode kmsg;;
	3) set_mode qr_code;;
	q|Q|"") echo "no change (still: $cur)";;
	*) die "invalid choice '$choice'";;
esac
