#!/bin/sh

# Parse required command-line parameters:
#   --server <source-config-file>
SOURCE_SFTP=""

# Run sftp-common script to load helper functions
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/sftp-common.sh"

# Ensure ssh-agent is running
ensure_ssh_agent

while [ $# -gt 0 ]; do
    case "$1" in
        --server)
            shift
            if [ -z "$1" ]; then
                printf 'ERROR: --server requires a file path\n' >&2
                exit 1
            fi
            SOURCE_SFTP="$1"
            ;;
        --server=*)
            SOURCE_SFTP="${1#*=}"
            ;;
        *)
            printf 'ERROR: unknown argument: %s\n' "$1" >&2
            exit 1
            ;;
    esac
    shift
done

if [ -z "$SOURCE_SFTP" ]; then
    printf 'ERROR: --server is required\n' >&2
    exit 1
fi

check_file_readable "$SOURCE_SFTP" "source config file"

load_sftp_config "$SOURCE_SFTP" "SOURCE"

# Construct command to connect to SFTP and return connection status
build_sftp_command "SOURCE"

# Run SFTP command and test connection
"$@" <<EOF
exit
EOF
if [ $? -ne 0 ]; then
    printf 'ERROR: failed to connect to SFTP server %s:%s\n' "$SOURCE_HOST" "$SOURCE_PORT" >&2
    exit 1
else
    printf 'Successfully connected to SFTP server %s:%s\n' "$SOURCE_HOST" "$SOURCE_PORT"
fi
