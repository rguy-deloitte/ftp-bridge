#!/bin/sh

# Parse required command-line parameters:
#   --source <source-config-file>
#   --target <target-config-file>
SOURCE_SFTP=""
TARGET_SFTP=""

# Create temp directory for ftp-bridge file transfer
mkdir -p /tmp/ftp-bridge/

# Run sftp-common script to load helper functions
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/sftp-common.sh"

# Ensure ssh-agent is running
ensure_ssh_agent

while [ $# -gt 0 ]; do
    case "$1" in
        --source)
            shift
            if [ -z "$1" ]; then
                printf 'ERROR: --source requires a file path\n' >&2
                exit 1
            fi
            SOURCE_SFTP="$1"
            ;;
        --source=*)
            SOURCE_SFTP="${1#*=}"
            ;;
        --target)
            shift
            if [ -z "$1" ]; then
                printf 'ERROR: --target requires a file path\n' >&2
                exit 1
            fi
            TARGET_SFTP="$1"
            ;;
        --target=*)
            TARGET_SFTP="${1#*=}"
            ;;
        *)
            printf 'ERROR: unknown argument: %s\n' "$1" >&2
            exit 1
            ;;
    esac
    shift
done

if [ -z "$SOURCE_SFTP" ] || [ -z "$TARGET_SFTP" ]; then
    printf 'ERROR: both --source and --target are required\n'
    printf 'ERROR: both --source and --target are required\n' >&2
    exit 1
fi

check_file_readable "$SOURCE_SFTP" "source config file"
check_file_readable "$TARGET_SFTP" "target config file"

load_sftp_config "$SOURCE_SFTP" "SOURCE"
load_sftp_config "$TARGET_SFTP" "TARGET"

download_source_files() {
    printf '%s\n' "Copying files from $SOURCE_DIR to /tmp/ftp-bridge/ and removing them from source"
    run_sftp_batch "SOURCE" <<EOF
get -r "$SOURCE_DIR"/* /tmp/ftp-bridge/
rm "$SOURCE_DIR"/*
exit
EOF
}

upload_target_files() {
    printf '%s\n' "Uploading files from /tmp/ftp-bridge/ to $TARGET_DIR"
    run_sftp_batch "TARGET" <<EOF
put -r /tmp/ftp-bridge/* $TARGET_DIR
exit
EOF
}

download_source_files
upload_target_files

rm -f /tmp/ftp-bridge/*

printf '%s\n' "All files moved successfully"
