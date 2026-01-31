#!/bin/bash
#
# run_demos.sh - Wrapper script to run logging demos
#
# Usage:
#   ./run_demos.sh              # Interactive menu
#   ./run_demos.sh all          # Run all demos
#   ./run_demos.sh log-levels   # Run specific demo
#   ./run_demos.sh --list       # List available demos

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define available demos
declare -A DEMOS=(
    ["log-levels"]="demo_log_levels.sh|Log Levels|Demonstrates different log levels and filtering"
    ["formatting"]="demo_formatting.sh|Log Formatting|Shows various log format options"
    ["timezone"]="demo_timezone.sh|Timezone Settings|UTC vs local time in logs"
    ["journal"]="demo_journal.sh|Journal Logging|Systemd journal integration"
    ["colors"]="demo_colors.sh|Color Settings|Color output configuration"
    ["stderr"]="demo_stderr.sh|Stderr Levels|Control stdout vs stderr output"
    ["combined"]="demo_combined.sh|Combined Features|Multiple features working together"
    ["quiet"]="demo_quiet.sh|Quiet Mode|Suppress console output"
    ["config"]="demo_config.sh|Configuration Files|Load settings from INI files"
    ["script-name"]="demo_script_name.sh|Script Name|Custom script names and phase identification"
)

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "\n${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Function to list available demos
list_demos() {
    print_header "Available Demos"
    echo -e "${YELLOW}Demo Name${NC}       ${YELLOW}Description${NC}"
    echo "--------------------------------------------------------"
    for key in $(echo "${!DEMOS[@]}" | tr ' ' '\n' | sort); do
        IFS='|' read -r script title description <<< "${DEMOS[$key]}"
        printf "%-15s %s\n" "$key" "$description"
    done
    echo
}

# Function to run a single demo
run_demo() {
    local demo_key="$1"

    if [[ ! -v "DEMOS[$demo_key]" ]]; then
        print_error "Unknown demo: $demo_key"
        echo "Use --list to see available demos"
        return 1
    fi

    IFS='|' read -r script title description <<< "${DEMOS[$demo_key]}"
    local demo_path="${SCRIPT_DIR}/${script}"

    if [[ ! -f "$demo_path" ]]; then
        print_error "Demo script not found: $demo_path"
        return 1
    fi

    print_header "Running: $title"
    print_info "$description"
    echo

    if bash "$demo_path"; then
        print_success "Demo completed: $title"
        return 0
    else
        print_error "Demo failed: $title"
        return 1
    fi
}

# Function to run all demos
run_all_demos() {
    local failed_demos=()
    local success_count=0
    local total_count=${#DEMOS[@]}

    print_header "Running All Demos"

    for key in $(echo "${!DEMOS[@]}" | tr ' ' '\n' | sort); do
        if run_demo "$key"; then
            ((success_count++))
        else
            failed_demos+=("$key")
        fi
        echo
        echo "--------------------------------------------------------"
    done

    print_header "Demo Summary"
    echo -e "Total demos: $total_count"
    echo -e "${GREEN}Successful: $success_count${NC}"

    if [[ ${#failed_demos[@]} -gt 0 ]]; then
        echo -e "${RED}Failed: ${#failed_demos[@]}${NC}"
        echo -e "${RED}Failed demos: ${failed_demos[*]}${NC}"
        return 1
    else
        print_success "All demos completed successfully!"
        return 0
    fi
}

# Function to show interactive menu
show_menu() {
    print_header "Bash Logger Demo Suite"
    echo "Select a demo to run:"
    echo

    local i=1
    local keys=()
    for key in $(echo "${!DEMOS[@]}" | tr ' ' '\n' | sort); do
        IFS='|' read -r script title description <<< "${DEMOS[$key]}"
        printf "%2d) %-15s - %s\n" "$i" "$title" "$description"
        keys+=("$key")
        ((i++))
    done

    echo
    echo " a) Run all demos"
    echo " l) List demo names (for command line use)"
    echo " q) Quit"
    echo

    read -rp "Enter your choice: " choice

    case "$choice" in
        [0-9]|[0-9][0-9])
            local index=$((choice - 1))
            if [[ $index -ge 0 && $index -lt ${#keys[@]} ]]; then
                run_demo "${keys[$index]}"
                echo
                read -rp "Press Enter to continue..."
                show_menu
            else
                print_error "Invalid selection"
                sleep 1
                show_menu
            fi
            ;;
        a|A)
            run_all_demos
            echo
            read -rp "Press Enter to continue..."
            show_menu
            ;;
        l|L)
            list_demos
            read -rp "Press Enter to continue..."
            show_menu
            ;;
        q|Q)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            print_error "Invalid selection"
            sleep 1
            show_menu
            ;;
    esac
}

# Main script logic
main() {
    case "${1:-}" in
        --list|-l)
            list_demos
            ;;
        --help|-h)
            echo "Usage: $0 [option|demo-name]"
            echo
            echo "Options:"
            echo "  --list, -l     List available demos"
            echo "  --help, -h     Show this help message"
            echo "  all            Run all demos"
            echo "  <demo-name>    Run specific demo"
            echo
            echo "If no argument is provided, an interactive menu will be shown."
            echo
            list_demos
            ;;
        all)
            run_all_demos
            ;;
        "")
            show_menu
            ;;
        *)
            run_demo "$1"
            ;;
    esac
}

main "$@"
