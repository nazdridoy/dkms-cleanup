#!/bin/bash
#
#  This script is designed to remove leftover DKMS artifacts after upgrading module sources or removing kernels.
#  Please run it as a non-root user for a preliminary check and proceed with caution.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Add logging functions
log_info() {
    local message="$*"
    # First, escape any existing color codes
    message=$(echo "$message" | sed 's/\x1b\[[0-9;]*m//g')
    # Color version numbers first (more specific pattern)
    message=$(echo "$message" | sed 's/[0-9]\+\.[0-9]\+\.[0-9]\+[-.][a-zA-Z0-9-]\+/${MAGENTA}&${NC}/g')
    # Then color paths
    message=$(echo "$message" | sed 's|/[a-zA-Z0-9/_.-]*|${CYAN}&${NC}|g')
    # Evaluate the color variables in the message
    eval "echo -e \"${BLUE}[INFO]${NC} $message\""
}

log_success() {
    local message="$*"
    message=$(echo "$message" | sed 's/\x1b\[[0-9;]*m//g')
    message=$(echo "$message" | sed 's/[0-9]\+\.[0-9]\+\.[0-9]\+[-.][a-zA-Z0-9-]\+/${MAGENTA}&${NC}/g')
    message=$(echo "$message" | sed 's|/[a-zA-Z0-9/_.-]*|${CYAN}&${NC}|g')
    eval "echo -e \"${GREEN}[OK]${NC} $message\""
}

log_warning() {
    local message="$*"
    message=$(echo "$message" | sed 's/\x1b\[[0-9;]*m//g')
    message=$(echo "$message" | sed 's/[0-9]\+\.[0-9]\+\.[0-9]\+[-.][a-zA-Z0-9-]\+/${MAGENTA}&${NC}/g')
    message=$(echo "$message" | sed 's|/[a-zA-Z0-9/_.-]*|${CYAN}&${NC}|g')
    eval "echo -e \"${YELLOW}[WARN]${NC} $message\""
}

log_error() {
    local message="$*"
    message=$(echo "$message" | sed 's/\x1b\[[0-9;]*m//g')
    message=$(echo "$message" | sed 's/[0-9]\+\.[0-9]\+\.[0-9]\+[-.][a-zA-Z0-9-]\+/${MAGENTA}&${NC}/g')
    message=$(echo "$message" | sed 's|/[a-zA-Z0-9/_.-]*|${CYAN}&${NC}|g')
    eval "echo -e \"${RED}[ERROR]${NC} $message\""
}

cleanup_dkms_status() {
    local module=$1
    local version=$2
    local kernel=$3
    local status=$4
    
    if ! [[ -d /lib/modules/$kernel ]]; then
        log_info "Removing DKMS module $module/$version for kernel $kernel (status: $status)"
        if ((EUID == 0)); then
            # Remove the kernel-specific build directory
            rm -rf "/var/lib/dkms/$module/$version/$kernel" 2>/dev/null || true
            
            # Remove the kernel module link if it exists
            rm -f "/var/lib/dkms/$module/kernel-$kernel-x86_64" 2>/dev/null || true
            
            # Try DKMS commands as fallback
            case "$status" in
                "installed")
                    dkms uninstall -m "$module" -v "$version" -k "$kernel" 2>/dev/null || true
                    ;;
                "built")
                    dkms unbuild -m "$module" -v "$version" -k "$kernel" 2>/dev/null || true
                    ;;
            esac
        else
            log_warning "Not root, skipping: 'rm -rf /var/lib/dkms/$module/$version/$kernel'"
            log_warning "Not root, skipping: 'rm -f /var/lib/dkms/$module/kernel-$kernel-x86_64'"
        fi
    fi
}

if ! cd /var/lib/dkms; then
  echo "${0##*/} Cannot enter /var/lib/dkms, aborting.."
  exit 1
fi

# First, clean up DKMS status for non-existent kernels
echo "Cleaning up DKMS status..."
while IFS=', ' read -r line; do
    [[ -z "$line" ]] && continue
    if [[ $line =~ ^([^/]+)/([^,]+),\ *([^,]+),\ *([^:]+):\ *(.+)$ ]]; then
        module="${BASH_REMATCH[1]}"
        version="${BASH_REMATCH[2]}"
        kernel="${BASH_REMATCH[3]}"
        status="${BASH_REMATCH[5]}"
        
        # Clean up status string
        status=${status%% (*}  # Remove anything in parentheses
        status=${status## }    # Remove leading spaces
        status=${status%% }    # Remove trailing spaces
        
        cleanup_dkms_status "$module" "$version" "$kernel" "$status"
    fi
done < <(dkms status)

echo -e "\n${BLUE}Cleaning up DKMS directories...${NC}"
log_info "Entering /var/lib/dkms"

for d in *; do
    log_info "Processing module directory: $d"
    [[ -d "$d" ]] || continue

    cd "$d"
    
    for p in *; do
        [[ "$p" == "original_module" ]] || [[ "$p" == "source" ]] && continue

        # Use locale-independent file type checks instead of locale-dependent "stat -c %F"
        if [[ -L "$p" ]]; then
            # Handle symbolic link
            p2=${p%\-x86_64}
            p2=${p2#kernel-}
            log_info "Found module link for $p2"
            if ! [[ -d /lib/modules/$p2 ]]; then
                log_error "Missing kernel sources /lib/modules/$p2"
                if ((EUID == 0)); then
                    rm -v "$p"
                else
                    log_warning "Not root, skipping: 'rm $p'"
                fi
            else
                log_success "Found kernel sources /lib/modules/$p2"
            fi
        elif [[ -d "$p" ]]; then
            # Handle directory
            log_info "Found directory $p"
            if [[ -e "$p/source" ]]; then
                log_success "Found module sources"
                for kernel_dir in "$p"/*; do
                    [[ -d "$kernel_dir" ]] || continue
                    [[ "$kernel_dir" == "$p/source" ]] && continue
                    # Get just the kernel version from the path
                    kernel_version=$(basename "$kernel_dir")
                    log_info "Checking kernel directory: $kernel_version"
                    if ! [[ -d "/lib/modules/$kernel_version" ]]; then
                        log_error "Kernel $kernel_version no longer exists"
                        if ((EUID == 0)); then
                            rm -rv "$kernel_dir"
                        else
                            log_warning "Not root, skipping: 'rm -r $kernel_dir'"
                        fi
                    else
                        log_success "Kernel $kernel_version exists"
                    fi
                done
            else
                if ! [[ -d /lib/modules/$p ]]; then
                    log_error "Kernel $p no longer exists"
                    if ((EUID == 0)); then
                        rm -rv "$p"
                    else
                        log_warning "Not root, skipping: 'rm -r $p'"
                    fi
                else
                    log_success "Kernel $p exists"
                fi
            fi
        fi
    done
    cd ..
done
