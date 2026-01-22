#!/usr/bin/env bash
#
# bash-logger installation script
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/GingerGraham/bash-logger/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/GingerGraham/bash-logger/main/install.sh | bash -s -- --user
#   curl -fsSL https://raw.githubusercontent.com/GingerGraham/bash-logger/main/install.sh | sudo bash -s -- --system

set -euo pipefail

# Configuration
REPO_OWNER="GingerGraham"
REPO_NAME="bash-logger"
GITHUB_REPO="${REPO_OWNER}/${REPO_NAME}"
LIBRARY_FILE="logging.sh"
VERSION_FILE=".bash-logger-version"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default installation mode
INSTALL_MODE="user"
PREFIX=""
AUTO_RC=false
BACKUP=true

# Functions
info() {
    echo -e "${BLUE}==>${NC} $*"
}

success() {
    echo -e "${GREEN}==>${NC} $*"
}

warn() {
    echo -e "${YELLOW}Warning:${NC} $*"
}

error() {
    echo -e "${RED}Error:${NC} $*" >&2
    exit 1
}

usage() {
    cat << EOF
bash-logger installation script

Usage:
    curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/main/install.sh | bash [OPTIONS]

Options:
    --user              Install for current user only (default)
    --system            Install system-wide (requires root)
    --prefix PATH       Custom installation prefix
    --auto-rc           Automatically add source line to shell RC file
    --no-backup         Skip backing up existing installation
    --help              Show this help message

Examples:
    # User installation
    curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/main/install.sh | bash

    # System installation
    curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/main/install.sh | sudo bash -s -- --system

    # Custom prefix
    curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/main/install.sh | bash -s -- --prefix ~/tools

    # Update without backup
    curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/main/install.sh | bash -s -- --no-backup

EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --user)
                INSTALL_MODE="user"
                shift
                ;;
            --system)
                INSTALL_MODE="system"
                shift
                ;;
            --prefix)
                if [[ -z "${2:-}" ]]; then
                    error "--prefix requires a non-empty path argument"
                fi
                if [[ "$2" == --* ]]; then
                    error "--prefix requires a path argument, not an option"
                fi
                PREFIX="$2"
                INSTALL_MODE="custom"
                shift 2
                ;;
            --auto-rc)
                AUTO_RC=true
                shift
                ;;
            --no-backup)
                BACKUP=false
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                error "Unknown option: $1. Use --help for usage information."
                ;;
        esac
    done
}

check_root() {
    if [[ $INSTALL_MODE == "system" ]] && [[ $EUID -ne 0 ]]; then
        error "System-wide installation requires root privileges. Use sudo."
    fi
}

get_latest_release() {
    info "Fetching latest release information..." >&2

    # Try to get the latest release tag from GitHub API
    local release_info
    if command -v curl >/dev/null 2>&1; then
        # Try IPv4 first, then fallback to default
        release_info=$(curl -4 --connect-timeout 10 --max-time 30 -fsSL "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" 2>/dev/null || \
                      curl --connect-timeout 10 --max-time 30 -fsSL "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" 2>/dev/null || \
                      echo "")
    elif command -v wget >/dev/null 2>&1; then
        release_info=$(wget --timeout=30 --dns-timeout=10 --connect-timeout=10 -qO- "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" 2>/dev/null || echo "")
    else
        error "Neither curl nor wget found. Please install one of them."
    fi

    if [[ -z "$release_info" ]]; then
        error "Failed to fetch release information from GitHub. Check your network connection."
    fi

    # Extract tag name
    local tag
    tag=$(printf '%s\n' "$release_info" | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)

    if [[ -z "$tag" ]]; then
        error "Could not determine latest release tag."
    fi

    echo "$tag"
}

check_existing_installation() {
    if [[ -f "${INSTALL_DIR}/${VERSION_FILE}" ]]; then
        local current_version
        current_version=$(cat "${INSTALL_DIR}/${VERSION_FILE}")
        echo "$current_version"
    elif [[ -f "${INSTALL_DIR}/${LIBRARY_FILE}" ]]; then
        # Installation exists but no version file (pre-versioning install)
        echo "unknown"
    else
        echo ""
    fi
}

backup_existing_installation() {
    local backup_dir
    backup_dir="${INSTALL_DIR}.backup-$(date +%Y%m%d-%H%M%S)"

    info "Creating backup at ${backup_dir}..." >&2

    if cp -r "$INSTALL_DIR" "$backup_dir" 2>/dev/null; then
        success "Backup created successfully" >&2
        echo "$backup_dir"
    else
        warn "Failed to create backup, continuing anyway..." >&2
        echo ""
    fi
}

download_release() {
    local tag=$1
    local temp_dir=$2

    info "Downloading bash-logger ${tag}..."

    local download_url="https://github.com/${GITHUB_REPO}/archive/refs/tags/${tag}.tar.gz"

    if command -v curl >/dev/null 2>&1; then
        # Try IPv4 first with shorter timeout, then fallback
        if ! curl -4 --connect-timeout 10 --max-time 60 -fsSL "$download_url" -o "${temp_dir}/release.tar.gz" 2>/dev/null; then
            info "IPv4 download failed, retrying with default settings..." >&2
            curl --connect-timeout 10 --max-time 60 -fsSL "$download_url" -o "${temp_dir}/release.tar.gz" || error "Failed to download release"
        fi
    elif command -v wget >/dev/null 2>&1; then
        wget --timeout=60 --dns-timeout=10 --connect-timeout=10 -qO "${temp_dir}/release.tar.gz" "$download_url" || error "Failed to download release"
    fi

    info "Extracting files..."
    tar -xzf "${temp_dir}/release.tar.gz" -C "$temp_dir" --strip-components=1 || error "Failed to extract release"

    # Verify the library file exists in the expected location.
    # If not, attempt a fallback extraction without --strip-components
    # to handle unexpected archive structures more gracefully.
    if [[ ! -f "${temp_dir}/${LIBRARY_FILE}" ]]; then
        info "Expected ${LIBRARY_FILE} in archive root not found, checking full archive structure..."

        local alt_extract_dir
        alt_extract_dir="${temp_dir}/full_extract"
        mkdir -p "$alt_extract_dir"

        if ! tar -xzf "${temp_dir}/release.tar.gz" -C "$alt_extract_dir"; then
            error "Failed to extract release when checking archive structure"
        fi

        local found_library
        # Use '|| true' so that an empty result does not cause the script to exit due to 'set -e'
        found_library=$(find "$alt_extract_dir" -type f -name "${LIBRARY_FILE}" | head -n 1 || true)

        if [ -z "$found_library" ]; then
            error "Library file ${LIBRARY_FILE} not found in release archive (unexpected archive structure)"
        fi

        cp "$found_library" "${temp_dir}/${LIBRARY_FILE}" || error "Failed to copy library file from archive"
    fi
}

determine_install_paths() {
    case $INSTALL_MODE in
        user)
            INSTALL_PREFIX="${HOME}/.local"
            ;;
        system)
            INSTALL_PREFIX="/usr/local"
            ;;
        custom)
            INSTALL_PREFIX="$PREFIX"
            ;;
    esac

    INSTALL_DIR="${INSTALL_PREFIX}/lib/bash-logger"
    DOC_DIR="${INSTALL_PREFIX}/share/doc/bash-logger"
}

check_install_prefix_writable() {
    # Ensure we have a prefix to validate
    if [ -z "${INSTALL_PREFIX:-}" ]; then
        error "INSTALL_PREFIX is not set"
    fi

    # If the prefix already exists, it itself must be writable
    if [ -e "$INSTALL_PREFIX" ]; then
        if [ ! -w "$INSTALL_PREFIX" ]; then
            error "No write permission to INSTALL_PREFIX (${INSTALL_PREFIX})"
        fi
        return
    fi

    # For a non-existent prefix, find the nearest existing directory
    local probe_dir
    probe_dir=$(dirname "$INSTALL_PREFIX")
    while [ ! -d "$probe_dir" ] && [ "$probe_dir" != "/" ]; do
        probe_dir=$(dirname "$probe_dir")
    done

    # The directory under which we will create the prefix must be writable
    if [ ! -w "$probe_dir" ]; then
        error "No write permission to create INSTALL_PREFIX under ${probe_dir}"
    fi
}

install_files() {
    local temp_dir=$1
    local new_version=$2

    info "Installing to ${INSTALL_DIR}..."

    # Verify write permissions before creating directories
    check_install_prefix_writable
    # Create directories
    mkdir -p "$INSTALL_DIR" || error "Failed to create ${INSTALL_DIR}"
    mkdir -p "$DOC_DIR" || error "Failed to create ${DOC_DIR}"

    # Install library
    if ! install -m 644 "${temp_dir}/${LIBRARY_FILE}" "${INSTALL_DIR}/${LIBRARY_FILE}"; then
        error "Failed to install ${LIBRARY_FILE}"
    fi

    # Install version file
    if ! echo "$new_version" > "${INSTALL_DIR}/${VERSION_FILE}"; then
        error "Failed to create version file"
    fi

    # Install documentation
    for doc in README.md LICENSE CHANGELOG.md; do
        if [[ -f "${temp_dir}/${doc}" ]]; then
            if ! install -m 644 "${temp_dir}/${doc}" "${DOC_DIR}/"; then
                warn "Failed to install ${doc}, continuing..."
            fi
        fi
    done

    success "Installation complete!"
}

update_rc_file() {
    local source_line="source ${INSTALL_DIR}/${LIBRARY_FILE}"
    local rc_file=""

    # Determine RC file based on user's login shell, not the interpreter running this script
    local shell_path="${SHELL:-}"

    # Fallback: try to get shell from passwd entry if SHELL is not set
    if [ -z "$shell_path" ]; then
        shell_path="$(getent passwd "${USER:-}" 2>/dev/null | cut -d: -f7 || true)"
    fi

    # Fallback: parse /etc/passwd directly if getent did not return a shell
    if [ -z "$shell_path" ] && [ -r /etc/passwd ] && [ -n "${USER:-}" ]; then
        shell_path="$(grep "^${USER}:" /etc/passwd 2>/dev/null | cut -d: -f7 || true)"
    fi

    case "$shell_path" in
        */bash)
            rc_file="${HOME}/.bashrc"
            ;;
        */zsh)
            rc_file="${HOME}/.zshrc"
            ;;
        *)
            warn "Unknown shell. Skipping RC file update."
            return
            ;;
    esac
    # Check if already present
    if grep -qF "$source_line" "$rc_file" 2>/dev/null; then
        info "Source line already present in $rc_file"
        return
    fi

    if [[ $AUTO_RC == true ]]; then
        # Check if RC file exists before appending
        if [[ ! -f "$rc_file" ]]; then
            info "RC file $rc_file does not exist and will be created"
        fi
        info "Adding source line to $rc_file"
        echo "" >> "$rc_file"
        echo "# bash-logger" >> "$rc_file"
        echo "$source_line" >> "$rc_file"
        success "Added source line to $rc_file"
    else
        info "To use bash-logger in your shell, add this line to $rc_file:"
        echo ""
        echo "    $source_line"
        echo ""
    fi
}

show_usage_instructions() {
    local is_update=$1
    local old_version=$2
    local new_version=$3

    echo ""
    if [[ $is_update == true ]]; then
        success "bash-logger has been updated!"
        if [[ -n "$old_version" ]]; then
            info "Previous version: ${old_version}"
        fi
        info "New version: ${new_version}"
    else
        success "bash-logger has been installed!"
        info "Version: ${new_version}"
    fi
    echo ""

    info "To use in your scripts, add:"
    echo "    source ${INSTALL_DIR}/${LIBRARY_FILE}"
    echo ""

    if [[ $AUTO_RC != true ]]; then
        info "To use in your shell, add to your RC file:"
        echo "    source ${INSTALL_DIR}/${LIBRARY_FILE}"
        echo ""
        info "Or run the installer with --auto-rc to do this automatically."
        echo ""
    fi

    info "Documentation installed to: ${DOC_DIR}"
    echo ""
}

main() {
    parse_args "$@"
    check_root
    determine_install_paths

    # Check for existing installation
    local existing_version
    existing_version=$(check_existing_installation)

    # Get latest release (or specified version)
    local latest_tag
    if [[ -n "${INSTALL_VERSION:-}" ]]; then
        latest_tag="$INSTALL_VERSION"
        info "Installing specified version: ${latest_tag}"
    else
        latest_tag=$(get_latest_release)
        info "Latest release: ${latest_tag}"
    fi

    # Check if same version is already installed
    if [[ -n "$existing_version" ]] && [[ "$existing_version" == "$latest_tag" ]]; then
        success "bash-logger ${latest_tag} is already installed"
        info "Installation location: ${INSTALL_DIR}"
        info "Documentation location: ${DOC_DIR}"
        echo ""
        info "To reinstall, first uninstall with:"
        if [[ $INSTALL_MODE == "system" ]]; then
            echo "    sudo rm -rf ${INSTALL_DIR} ${DOC_DIR}"
        else
            echo "    rm -rf ${INSTALL_DIR} ${DOC_DIR}"
        fi
        echo ""
        exit 0
    fi

    # Create temporary directory
    local temp_dir
    temp_dir=$(mktemp -d)
    trap 'if [[ -n "${temp_dir:-}" ]] && [[ -d "${temp_dir}" ]]; then rm -rf "$temp_dir"; fi' EXIT

    # Handle existing installation (different version)
    local is_update=false
    local backup_path=""
    if [[ -n "$existing_version" ]]; then
        is_update=true
        info "Found existing installation: ${existing_version}"
        info "Upgrading to: ${latest_tag}"

        if [[ $BACKUP == true ]]; then
            backup_path=$(backup_existing_installation)
        fi
    fi

    download_release "$latest_tag" "$temp_dir"
    install_files "$temp_dir" "$latest_tag"

    # Only update RC for user installations and new installs
    if [[ $INSTALL_MODE == "user" ]] && [[ $is_update == false ]]; then
        update_rc_file
    fi

    show_usage_instructions "$is_update" "$existing_version" "$latest_tag"

    # Show backup location if created
    if [[ -n "$backup_path" ]]; then
        info "Previous installation backed up to: ${backup_path}"
        echo ""
    fi
}

# Only run main if not in test mode
if [[ "${INSTALL_SH_TEST_MODE:-false}" != "true" ]]; then
    main "$@"
fi