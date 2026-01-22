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
    tag=$(echo "$release_info" | grep -oP '"tag_name":\s*"\K[^"]+' || echo "")

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

    # Verify the library file exists
    if [[ ! -f "${temp_dir}/${LIBRARY_FILE}" ]]; then
        error "Library file ${LIBRARY_FILE} not found in release archive"
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

install_files() {
    local temp_dir=$1
    local new_version=$2

    info "Installing to ${INSTALL_DIR}..."

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

    # Determine RC file based on shell
    if [[ -n "${BASH_VERSION:-}" ]]; then
        rc_file="${HOME}/.bashrc"
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
        rc_file="${HOME}/.zshrc"
    else
        warn "Unknown shell. Skipping RC file update."
        return
    fi

    # Check if already present
    if grep -qF "$source_line" "$rc_file" 2>/dev/null; then
        info "Source line already present in $rc_file"
        return
    fi

    if [[ $AUTO_RC == true ]]; then
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
    trap 'if [[ -n "${temp_dir:-}" ]] && [[ -d "$temp_dir" ]]; then rm -rf "$temp_dir"; fi' EXIT

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

main "$@"