#!/bin/bash

if [[ -z "${ACRYL_SOURCED_COMMON_UTILS}" ]]; then
    readonly ACRYL_SOURCED_COMMON_UTILS=1

    # Color codes
    RED='\033[31m'
    GREEN='\033[32m'
    YELLOW='\033[33m'
    BLUE='\033[34m'
    PURPLE='\033[35m'
    CYAN='\033[36m'
    WHITE='\033[37m'
    
    BOLD='\033[1m'
    UNDERLINE='\033[4m'
    RESET='\033[0m'

    # Colored echo with newline
    cecho() {
        local message=${1:-""}
        local color=${2:-$PURPLE}
        echo -e "${color}${message}${RESET}"
    }

    # Colored echo without newline
    cnecho() {
        local message=${1:-""}
        local color=${2:-$PURPLE}
        echo -n -e "${color}${message}${RESET}"
    }

    # Styled messages
    info() {
        cecho "${INFO_TAG} $1" $CYAN
    }

    warn() {
        cecho "${WARN_TAG} $1" $YELLOW
    }

    error() {
        cecho "${ERROR_TAG} $1" $RED
    }

    success() {
        cecho "${SUCCESS_TAG} $1" $GREEN
    }

    headline() {
        cecho "======== $1 ========" $BOLD$BLUE
    }

    # Simulate terminal "takeover" (for dramatic pause)
    take_term() {
        local delay=${TAKE_TERM_SECONDS:-2}
        sleep "$delay"
    }

    # Check sudo access with friendly output
    check_sudo() {
        info "Confirming sudo access..."
        if ! sudo -v; then
            error "Sudo access is required. Exiting..."
            exit 1
        else
            success "Sudo access confirmed!"
        fi
    }

    # Spinner
    start_spinner() {
      local delay=0.1
      local spinstr='|/-\'
      while true; do
        for (( i=0; i<${#spinstr}; i++ )); do
          echo -ne "${CYAN}[INFO] Installing... ${spinstr:$i:1} ${RESET}\r"
          sleep $delay
        done
      done
    }

    stop_spinner() {
      if kill "$1" > /dev/null 2>&1; then
        wait "$1" 2>/dev/null
        # 줄을 지우고 OK 메시지 출력
        echo -ne "\r\033[K${GREEN}[OK] Installation complete!${RESET}\n"
      fi
    } 
else
    # Already sourced
    return
fi
