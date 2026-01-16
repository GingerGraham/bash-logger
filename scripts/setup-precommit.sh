#!/usr/bin/env bash
#
# setup-precommit.sh - Easy pre-commit setup for bash-logger contributors
#
# This script helps contributors set up pre-commit hooks without any prior knowledge.
# It handles all the installation and configuration automatically.
#
# Usage:
#   ./scripts/setup-precommit.sh
#
# What it does:
#   1. Checks for Python and pip (required dependencies)
#   2. Installs pre-commit framework
#   3. Installs git hooks from .pre-commit-config.yaml
#   4. Verifies everything is working
#   5. Provides helpful tips for using pre-commit

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Helper functions
print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

print_step() {
    echo ""
    echo -e "${BLUE}→ $1${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Main setup
main() {
    print_header "Pre-commit Setup for Bash Logger"

    echo ""
    echo "This script will help you set up pre-commit hooks to ensure code quality"
    echo "before you commit. You'll be able to catch issues locally before submitting PRs!"
    echo ""

    # Check for Python
    print_step "Checking for Python..."
    if ! command_exists python3 && ! command_exists python; then
        print_error "Python 3 is required but not installed"
        echo "Please install Python 3 from https://www.python.org/"
        exit 1
    fi

    local python_cmd="python3"
    if ! command_exists python3; then
        python_cmd="python"
    fi

    print_success "Python found: $($python_cmd --version)"

    # Check for pip
    print_step "Checking for pip..."
    local pip_cmd=""
    if command_exists pip3; then
        pip_cmd="pip3"
    elif command_exists pip; then
        pip_cmd="pip"
    else
        print_error "pip is required but not installed"
        echo "Please install pip. It usually comes with Python 3."
        exit 1
    fi

    print_success "pip found: $($pip_cmd --version)"

    # Install pre-commit
    print_step "Installing pre-commit framework..."
    if command_exists pre-commit; then
        print_info "pre-commit is already installed: $(pre-commit --version)"
    else
        echo "Installing pre-commit via pip..."
        if $pip_cmd install --user pre-commit; then
            print_success "pre-commit installed successfully"
        else
            print_error "Failed to install pre-commit"
            echo "Try running: $pip_cmd install --user pre-commit"
            exit 1
        fi

        # Check if pre-commit is now in PATH
        if ! command_exists pre-commit; then
            # Try to find it in common pip user install locations
            local user_bin="$HOME/.local/bin"
            if [[ -f "$user_bin/pre-commit" ]]; then
                export PATH="$user_bin:$PATH"
                print_info "Added $user_bin to PATH"
            else
                print_error "pre-commit not found in PATH after installation"
                echo "Please add your Python user bin directory to your PATH"
                echo "Common locations: ~/.local/bin, ~/Library/Python/*/bin"
                exit 1
            fi
        fi
    fi

    # Verify .pre-commit-config.yaml exists
    print_step "Checking configuration file..."
    if [[ ! -f "$PROJECT_ROOT/.pre-commit-config.yaml" ]]; then
        print_error ".pre-commit-config.yaml not found"
        exit 1
    fi
    print_success ".pre-commit-config.yaml found"

    # Install git hooks
    print_step "Installing git pre-commit hooks..."
    cd "$PROJECT_ROOT"

    if pre-commit install && pre-commit install --hook-type commit-msg; then
        print_success "Git hooks installed successfully"
    else
        print_error "Failed to install git hooks"
        exit 1
    fi

    # Run hooks on existing files (optional)
    print_step "Would you like to run hooks on all existing files? (optional)"
    echo "This will check all files for any issues that exist today."
    echo ""

    read -p "Run hooks on all files? (y/n) [n]: " -r run_all
    if [[ $run_all == "y" || $run_all == "Y" ]]; then
        echo ""
        print_info "Running hooks on all files... this may take a moment..."
        if pre-commit run --all-files; then
            print_success "All checks passed!"
        else
            print_info "Some issues were found. Please review and fix them."
            print_info "You can run: pre-commit run --all-files"
            echo ""
        fi
    fi

    # Success message
    print_header "Setup Complete!"
    echo ""
    print_success "Pre-commit hooks are now active!"
    echo ""
    echo "What happens next:"
    echo "  • Hooks will run automatically before each commit"
    echo "  • If checks fail, commit will be blocked until issues are fixed"
    echo "  • Hooks check: Bash syntax, Markdown formatting, Tests"
    echo ""
    echo "Useful commands:"
    echo "  • Run hooks manually: pre-commit run --all-files"
    echo "  • Skip hooks for a commit: git commit --no-verify"
    echo "  • Update hooks: pre-commit autoupdate"
    echo ""
    echo "For more info, see: docs/PRE-COMMIT.md"
    echo ""
}

# Run main function
main "$@"
