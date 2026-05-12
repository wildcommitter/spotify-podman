#!/bin/bash
#
# Installer for containerized Spotify (Wayland + PipeWire)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BIN_DIR="${HOME}/.local/bin"
DESKTOP_DIR="${HOME}/.local/share/applications"
LOG_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/spotify-podman"
IMAGE_NAME="spotify"

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m✓\033[0m  %s\n' "$*"; }
warn()  { printf '\033[1;33m!\033[0m  %s\n' "$*" >&2; }
error() { printf '\033[1;31m✗\033[0m  %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------

info "Running pre-flight checks"

command -v podman >/dev/null 2>&1 \
    || error "podman is not installed. Install it first (e.g. 'sudo pacman -S podman' on CachyOS)."

for f in Containerfile spotify-podman spotify-podman.desktop; do
    [ -f "${SCRIPT_DIR}/${f}" ] \
        || error "Missing required file: ${f} (expected in ${SCRIPT_DIR})"
done

if command -v desktop-file-validate >/dev/null 2>&1; then
    desktop-file-validate "${SCRIPT_DIR}/spotify-podman.desktop" \
        || error "spotify-podman.desktop failed validation"
    ok "Desktop file is valid"
else
    warn "desktop-file-validate not found; skipping syntax check"
fi

case ":${PATH}:" in
    *":${BIN_DIR}:"*)
        ok "${BIN_DIR} is in PATH"
        ;;
    *)
        warn "${BIN_DIR} is not in PATH (terminal launches will need full path)."
        warn "  Add to your shell rc: export PATH=\"\$HOME/.local/bin:\$PATH\""
        ;;
esac

# ---------------------------------------------------------------------------
# Build the container image
# ---------------------------------------------------------------------------

info "Building Podman image '${IMAGE_NAME}' (this may take a few minutes)"
podman build -t "${IMAGE_NAME}" "${SCRIPT_DIR}" \
    || error "podman build failed"
ok "Image built"

# ---------------------------------------------------------------------------
# Install the launcher script
# ---------------------------------------------------------------------------

info "Installing launcher script to ${BIN_DIR}"
mkdir -p "${BIN_DIR}"
install -m 0755 "${SCRIPT_DIR}/spotify-podman" "${BIN_DIR}/spotify-podman"
ok "Installed ${BIN_DIR}/spotify-podman"

# ---------------------------------------------------------------------------
# Install the desktop entry with absolute paths
# ---------------------------------------------------------------------------

info "Installing desktop entry to ${DESKTOP_DIR}"
mkdir -p "${DESKTOP_DIR}"
mkdir -p "${LOG_DIR}"

PODMAN_BIN="$(command -v podman)"

# Simple substitution: just swap relative names for absolute paths.
# Logging is handled inside spotify-podman itself, so Exec= stays simple
# and the desktop spec is happy.
sed \
    -e "s|^Exec=spotify-podman|Exec=${BIN_DIR}/spotify-podman|" \
    -e "s|^TryExec=spotify-podman$|TryExec=${BIN_DIR}/spotify-podman|" \
    -e "s|^Exec=podman |Exec=${PODMAN_BIN} |" \
    "${SCRIPT_DIR}/spotify-podman.desktop" \
    > "${DESKTOP_DIR}/spotify-podman.desktop"
chmod 0644 "${DESKTOP_DIR}/spotify-podman.desktop"

if command -v desktop-file-validate >/dev/null 2>&1; then
    desktop-file-validate "${DESKTOP_DIR}/spotify-podman.desktop" \
        || error "Installed desktop file failed validation"
fi
ok "Installed ${DESKTOP_DIR}/spotify-podman.desktop"

# ---------------------------------------------------------------------------
# Refresh the application database
# ---------------------------------------------------------------------------

if command -v update-desktop-database >/dev/null 2>&1; then
    info "Refreshing desktop database"
    update-desktop-database "${DESKTOP_DIR}" 2>/dev/null || true
    ok "Desktop database refreshed"
else
    warn "update-desktop-database not found; the menu entry may take a moment to appear"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

cat <<EOF

$(ok "Installation complete")

Launch from the application menu, or run from a terminal:
    spotify-podman

The launcher logs every invocation to:
    ${LOG_DIR}/launch.log

To uninstall:
    rm -f "${BIN_DIR}/spotify-podman"
    rm -f "${DESKTOP_DIR}/spotify-podman.desktop"
    rm -rf "${LOG_DIR}"
    podman image rm ${IMAGE_NAME}
    podman volume rm spotify-config spotify-cache  # also wipes login state

EOF
