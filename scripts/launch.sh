#!/usr/bin/env bash

# Waybar Launch & Reload Script
# Designed for elegant, robust, and clean restarts/reloads of Waybar.

# Colors for premium terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if waybar is installed
if ! command -v waybar &> /dev/null; then
    log_error "Waybar is not installed or not in PATH."
    exit 1
fi

# Function to perform a hot reload (SIGUSR2)
hot_reload() {
    if pgrep -x waybar > /dev/null; then
        log_info "Sending SIGUSR2 to running Waybar instances for hot reload..."
        killall -SIGUSR2 waybar
        log_success "Waybar configuration and style reloaded successfully!"
    else
        log_warning "Waybar is not currently running. Launching new instance..."
        launch_waybar
    fi
}

# Function to perform a full restart (kill & launch)
restart_waybar() {
    log_info "Terminating existing Waybar instances..."
    killall -q waybar

    # Wait until the processes have been shut down (up to 3 seconds)
    local timeout=30
    while pgrep -x waybar >/dev/null; do
        sleep 0.1
        ((timeout--))
        if [ "$timeout" -le 0 ]; then
            log_warning "Waybar did not terminate gracefully, forcing kill..."
            killall -9 waybar &>/dev/null
            break
        fi
    done

    launch_waybar
}

# Function to launch Waybar
launch_waybar() {
    log_info "Launching Waybar in the background..."
    
    # Path to config files in the parent directory of the script
    local SCRIPT_DIR
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local WAYBAR_DIR
    WAYBAR_DIR="$(dirname "$SCRIPT_DIR")"
    local CONFIG="$WAYBAR_DIR/config.jsonc"
    local STYLE="$WAYBAR_DIR/style.css"

    # Use local config/style if they exist and are not empty
    local ARGS=()
    if [ -s "$CONFIG" ]; then
        ARGS+=("-c" "$CONFIG")
    fi
    if [ -s "$STYLE" ]; then
        ARGS+=("-s" "$STYLE")
    fi

    # Launch waybar in background and redirect output to a log file
    waybar "${ARGS[@]}" > /tmp/waybar.log 2>&1 &
    
    # Wait a tiny bit to check if it launched successfully
    sleep 0.3
    if pgrep -x waybar > /dev/null; then
        log_success "Waybar launched successfully!"
        log_info "Logs are available at /tmp/waybar.log"
    else
        log_error "Failed to start Waybar. Check /tmp/waybar.log for details:"
        if [ -f /tmp/waybar.log ]; then
            tail -n 10 /tmp/waybar.log
        fi
        exit 1
    fi
}

# Determine action based on argument
ACTION=${1:-"restart"}

case "$ACTION" in
    "reload"|"hot-reload"|"-r")
        hot_reload
        ;;
    "restart"|"-s")
        restart_waybar
        ;;
    "kill"|"stop"|"-k")
        log_info "Stopping Waybar..."
        killall -q waybar
        log_success "Waybar stopped."
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [action]"
        echo "Actions:"
        echo "  restart     Stop running Waybar instances and start a new one (default)"
        echo "  reload      Send SIGUSR2 to running Waybar to hot-reload config/style"
        echo "  kill        Stop all running Waybar instances"
        echo "  help        Show this help message"
        ;;
    *)
        log_error "Unknown action: $ACTION"
        echo "Use '$0 help' for usage instructions."
        exit 1
        ;;
esac
