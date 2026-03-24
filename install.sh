#!/usr/bin/env bash

set -euo pipefail

REPO_SLUG="${REPO_SLUG:-tyrel/tray-indicators}"
REPO_BRANCH="${REPO_BRANCH:-main}"

log() {
    printf '==> %s\n' "$*"
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

SOURCE_ROOT=""
TEMP_ROOT=""

cleanup() {
    if [[ -n "${TEMP_ROOT}" && -d "${TEMP_ROOT}" ]]; then
        rm -rf "${TEMP_ROOT}"
    fi
}

trap cleanup EXIT

resolve_source_root() {
    local script_dir=""

    if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi

    if [[ -n "${script_dir}" && -f "${script_dir}/apps/resource-usage-tray/resource-usage-tray" ]]; then
        SOURCE_ROOT="${script_dir}"
        return
    fi

    require_cmd curl
    require_cmd tar

    TEMP_ROOT="$(mktemp -d)"
    log "Downloading ${REPO_SLUG}@${REPO_BRANCH}"
    curl -fsSL "https://codeload.github.com/${REPO_SLUG}/tar.gz/refs/heads/${REPO_BRANCH}" \
        | tar -xz -C "${TEMP_ROOT}" --strip-components=1
    SOURCE_ROOT="${TEMP_ROOT}"
}

install_apt_deps() {
    local packages=(
        python3
        python3-pip
        python3-gi
        python3-psutil
        gir1.2-ayatanaappindicator3-0.1
        gir1.2-notify-0.7
        libnotify-bin
    )
    local missing=()
    local pkg=""

    if ! command -v apt-get >/dev/null 2>&1; then
        die "this installer currently targets Ubuntu/Debian systems with apt-get"
    fi

    for pkg in "${packages[@]}"; do
        if ! dpkg -s "${pkg}" >/dev/null 2>&1; then
            missing+=("${pkg}")
        fi
    done

    if (( ${#missing[@]} == 0 )); then
        return
    fi

    log "Installing Ubuntu packages: ${missing[*]}"
    if [[ "${EUID}" -eq 0 ]]; then
        apt-get update
        apt-get install -y "${missing[@]}"
        return
    fi

    require_cmd sudo
    sudo apt-get update
    sudo apt-get install -y "${missing[@]}"
}

install_python_deps() {
    log "Installing Python user packages"
    python3 -m pip install --user --upgrade websocket-client
}

install_files() {
    local bin_dir="${HOME}/.local/bin"
    local share_dir="${HOME}/.local/share/obs-tray-indicator/icons"
    local systemd_user_dir="${HOME}/.config/systemd/user"

    mkdir -p "${bin_dir}" "${share_dir}" "${systemd_user_dir}"

    install -m 755 \
        "${SOURCE_ROOT}/apps/resource-usage-tray/resource-usage-tray" \
        "${bin_dir}/resource-usage-tray"
    install -m 755 \
        "${SOURCE_ROOT}/apps/obs-tray-indicator/obs-tray-indicator" \
        "${bin_dir}/obs-tray-indicator"
    install -m 644 \
        "${SOURCE_ROOT}/apps/obs-tray-indicator/icons/"*.svg \
        "${share_dir}/"
    install -m 644 \
        "${SOURCE_ROOT}/apps/obs-tray-indicator/obs-tray-indicator.service" \
        "${systemd_user_dir}/obs-tray-indicator.service"
    install -m 644 \
        "${SOURCE_ROOT}/apps/resource-usage-tray/resource-usage-tray.service" \
        "${systemd_user_dir}/resource-usage-tray.service"

    rm -f "${HOME}/.config/autostart/resource-usage-tray.desktop"
}

start_services() {
    if ! command -v systemctl >/dev/null 2>&1; then
        return
    fi

    log "Reloading user systemd units"
    systemctl --user daemon-reload || true
    systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR XDG_CURRENT_DESKTOP || true
    systemctl --user enable --now obs-tray-indicator.service || true
    systemctl --user enable --now resource-usage-tray.service || true
}

print_success() {
    cat <<EOF

Installed:
  - ${HOME}/.local/bin/resource-usage-tray
  - ${HOME}/.local/bin/obs-tray-indicator

One-line installer:
  curl -fsSL https://raw.githubusercontent.com/${REPO_SLUG}/${REPO_BRANCH}/install.sh | bash
EOF
}

main() {
    resolve_source_root
    install_apt_deps
    install_python_deps
    install_files
    start_services
    print_success
}

main "$@"
