#!/bin/sh

# Parse required command-line parameters:
#   --source <source-config-file>
#   --target <target-config-file>
SOURCE_SFTP=""
TARGET_SFTP=""

# Make sure ssh-add is running and has the necessary keys loaded
if ! pgrep -x "ssh-add" > /dev/null
then
    eval "$(ssh-agent -s)"
fi


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

if [ ! -r "$SOURCE_SFTP" ]; then
    printf 'ERROR: source config file not found or unreadable: %s\n' "$SOURCE_SFTP" >&2
    exit 1
fi


load_sftp_config() {
    config_file="$1"

    # shellcheck source=/dev/null
    . "$config_file"

    missing=""
    for key in SFTP_HOST SFTP_USER SFTP_PORT SFTP_DIR; do
        if [ -z "$(eval "printf '%s' \"\$$key\"")" ]; then
            missing="${missing} ${key}"
        fi
    done
    if [ -n "$missing" ]; then
        printf 'ERROR: missing required values in %s:%s\n' "$config_file" "$missing" >&2
        exit 1
    fi
}

load_sftp_config "$SOURCE_SFTP"


# Construct command to connect to SFTP and return connection status

# If password is provided, use sshpass
if [ -n "$SFTP_PASS" ]; then
    set -- sshpass -p "$SFTP_PASS" sftp -P "$SFTP_PORT"
else
    set -- sftp -P "$SFTP_PORT"
fi

if [ -n "$SFTP_KEY_PATH" ]; then
    set -- "$@" -i "$SFTP_KEY_PATH"

    # If passphrase is provided, add it to ssh-add
    if [ -n "$SFTP_PASSPHRASE" ]; then
        sshpass -P "Enter passphrase" -p "$SFTP_PASSPHRASE" ssh-add "$SFTP_KEY_PATH"
    fi
fi

# Build SFTP command
set -- "$@" -o PubkeyAcceptedAlgorithms=+ssh-rsa -o StrictHostKeyChecking=accept-new "$SFTP_USER@$SFTP_HOST"

# Print the command being run for debugging purposes
printf 'Running command: %s\n' "$*"

# Run SFTP command and test connection
"$@" <<EOF
exit
EOF
if [ $? -ne 0 ]; then
    printf 'ERROR: failed to connect to SFTP server %s:%s\n' "$SFTP_HOST" "$SFTP_PORT" >&2
    exit 1
else
    printf 'Successfully connected to SFTP server %s:%s\n' "$SFTP_HOST" "$SFTP_PORT"
fi