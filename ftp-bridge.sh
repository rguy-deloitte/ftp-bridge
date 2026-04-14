#!/bin/sh

# Parse required command-line parameters:
#   --source <source-config-file>
#   --target <target-config-file>
SOURCE_SFTP=""
TARGET_SFTP=""
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
    printf 'ERROR: both --source and --target are required\n' >&2
    exit 1
fi

if [ ! -r "$SOURCE_SFTP" ]; then
    printf 'ERROR: source config file not found or unreadable: %s\n' "$SOURCE_SFTP" >&2
    exit 1
fi

if [ ! -r "$TARGET_SFTP" ]; then
    printf 'ERROR: target config file not found or unreadable: %s\n' "$TARGET_SFTP" >&2
    exit 1
fi

load_sftp_config() {
    config_file="$1"
    prefix="$2"

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

    if [ "$prefix" = "SFTP1" ]; then
        SFTP1_HOST="$SFTP_HOST"
        SFTP1_USER="$SFTP_USER"
        SFTP1_PORT="$SFTP_PORT"
        SFTP1_PASS="$SFTP_PASS"
        SFTP1_DIR="$SFTP_DIR"
        SFTP1_KEY_PATH="$SFTP_KEY_PATH"
        SFTP1_PASSPHRASE="$SFTP_PASSPHRASE"
    else
        SFTP2_HOST="$SFTP_HOST"
        SFTP2_USER="$SFTP_USER"
        SFTP2_PORT="$SFTP_PORT"
        SFTP2_PASS="$SFTP_PASS"
        SFTP2_DIR="$SFTP_DIR"
        SFTP2_KEY_PATH="$SFTP_KEY_PATH"
        SFTP2_PASSPHRASE="$SFTP_PASSPHRASE"
    fi

    unset SFTP_HOST SFTP_USER SFTP_PORT SFTP_PASS SFTP_DIR SFTP_KEY_PATH SFTP_PASSPHRASE
}

load_sftp_config "$SOURCE_SFTP" "SFTP1"
load_sftp_config "$TARGET_SFTP" "SFTP2"

# Download all files from SFTP1 to local directory
if [ -n "$SFTP1_KEY_PATH" ]; then
    sshpass -P "Enter passphrase" -p "$SFTP1_PASSPHRASE" sftp -P "$SFTP1_PORT" -i "$SFTP1_KEY_PATH" -o PubkeyAcceptedAlgorithms=+ssh-rsa -o StrictHostKeyChecking=accept-new "$SFTP1_USER"@"$SFTP1_HOST" <<EOF
    get -r $SFTP1_DIR ./tmp_1/
    exit
EOF
else
    sshpass -p "$SFTP1_PASS" sftp -P "$SFTP1_PORT" -o StrictHostKeyChecking=accept-new "$SFTP1_USER"@"$SFTP1_HOST" <<EOF
    get -r $SFTP1_DIR ./tmp_1/
    exit
EOF
fi

# Upload all files from local directory to SFTP2 and fetch outbound files from SFTP2 to local directory
if [ -n "$SFTP2_KEY_PATH" ]; then
    sshpass -P "Enter passphrase" -p "$SFTP2_PASSPHRASE" sftp -P "$SFTP2_PORT" -i "$SFTP2_KEY_PATH" -o PubkeyAcceptedAlgorithms=+ssh-rsa -o StrictHostKeyChecking=accept-new "$SFTP2_USER"@"$SFTP2_HOST" <<EOF
    put -r ./tmp_1/* $SFTP2_DIR
    get -r $SFTP2_DIR ./tmp_2/
    exit
EOF
else
    sshpass -p "$SFTP2_PASS" sftp -P "$SFTP2_PORT" -o StrictHostKeyChecking=accept-new "$SFTP2_USER"@"$SFTP2_HOST" <<EOF
    put -r ./tmp_1/* $SFTP2_DIR
    get -r $SFTP2_DIR ./tmp_2/
    exit
EOF
fi

# Upload all files from local directory to SFTP1
if [ -n "$SFTP1_KEY_PATH" ]; then
    sshpass -P "Enter passphrase" -p "$SFTP1_PASSPHRASE" sftp -P "$SFTP1_PORT" -i "$SFTP1_KEY_PATH" -o PubkeyAcceptedAlgorithms=+ssh-rsa -o StrictHostKeyChecking=accept-new "$SFTP1_USER"@"$SFTP1_HOST" <<EOF
    put -r ./tmp_2/* $SFTP1_DIR
    exit
EOF
else
    sshpass -p "$SFTP1_PASS" sftp -P "$SFTP1_PORT" -o StrictHostKeyChecking=accept-new "$SFTP1_USER"@"$SFTP1_HOST" <<EOF
    put -r ./tmp_2/* $SFTP1_DIR
    exit
EOF
fi

rm -rf ./tmp_1/
rm -rf ./tmp_2/