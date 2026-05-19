#!/bin/sh

# Remove carriage returns from values loaded from env-style files.
strip_cr() {
    printf '%s' "$1" | sed 's/\r//g'
}

# Apply env-file cleanup to a variable in place while preserving its name.
sanitize_env_var() {
    var_name="$1"
    var_value=$(eval "printf '%s' \"\${$var_name}\"")
    sanitized_value=$(strip_cr "$var_value")
    escaped_value=$(printf '%s' "$sanitized_value" | sed "s/'/'\\''/g")
    eval "$var_name='$escaped_value'"
}

# Start an ssh-agent if one is not already available for key-based auth.
ensure_ssh_agent() {
    if [ -z "$SSH_AGENT_PID" ]; then
        eval "$(ssh-agent -s)"
    fi
}

# Check that file exists and is readable
check_file_readable() {
    file_path="$1"
    description="$2"

    if [ ! -r "$file_path" ]; then
        printf 'ERROR: %s not found or unreadable: %s\n' "$description" "$file_path" >&2
        exit 1
    fi
}

# Load SFTP_* settings from a config file into a named prefix.
load_sftp_config() {
    config_file="$1"
    prefix="$2"

    case "$config_file" in
        */*) . "$config_file" ;;
        *) . "./$config_file" ;;
    esac

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

    eval "${prefix}_HOST=\$SFTP_HOST"
    eval "${prefix}_USER=\$SFTP_USER"
    eval "${prefix}_PORT=\$SFTP_PORT"
    eval "${prefix}_PASSWORD=\$SFTP_PASSWORD"
    eval "${prefix}_DIR=\$SFTP_DIR"
    eval "${prefix}_PRIVATE_KEY=\$SFTP_PRIVATE_KEY"
    eval "${prefix}_PASSPHRASE=\$SFTP_PASSPHRASE"

    unset SFTP_HOST SFTP_USER SFTP_PORT SFTP_PASSWORD SFTP_DIR SFTP_PRIVATE_KEY SFTP_PASSPHRASE
}

# Load values from .env and sanitize known variables without renaming them.
load_env_file() {
    check_file_readable "/app/.env" "env file"

    # shellcheck source=/dev/null
    . "/app/.env"

    for var_name in \
        REMOTE_SFTP_NAME REMOTE_SFTP_HOST REMOTE_SFTP_PORT REMOTE_SFTP_USER \
        REMOTE_SFTP_PASSWORD REMOTE_SFTP_PRIVATE_KEY REMOTE_SFTP_PASSPHRASE REMOTE_INPUT_DIR \
        INTERNAL_SFTP_NAME INTERNAL_SFTP_HOST INTERNAL_SFTP_PORT INTERNAL_SFTP_USER \
        INTERNAL_SFTP_PASSWORD INTERNAL_SFTP_PRIVATE_KEY INTERNAL_SFTP_PASSPHRASE \
        INTERNAL_INPUT_DIR INTERNAL_WORKING_DIR CONFIG_FILE FILE_DECRYPTION_KEY \
        FILE_DECRYPTION_PASSPHRASE
    do
        sanitize_env_var "$var_name"
    done
}

# Resolve a connection prefix into plain variables used by the command builders.
resolve_sftp_connection() {
    prefix="$1"

    HOST=$(eval "printf '%s' \"\${${prefix}_HOST}\"")
    USER=$(eval "printf '%s' \"\${${prefix}_USER}\"")
    PORT=$(eval "printf '%s' \"\${${prefix}_PORT}\"")
    PASSWORD=$(eval "printf '%s' \"\${${prefix}_PASSWORD}\"")
    PRIVATE_KEY=$(eval "printf '%s' \"\${${prefix}_PRIVATE_KEY}\"")
    PASSPHRASE=$(eval "printf '%s' \"\${${prefix}_PASSPHRASE}\"")
}

# Build the current shell's positional parameters as the sftp command to run.
build_sftp_command() {
    prefix="$1"

    resolve_sftp_connection "$prefix"

    if [ -n "$PASSWORD" ]; then
        set -- sshpass -p "$PASSWORD" sftp -P "$PORT"
    else
        set -- sftp -P "$PORT"
    fi

    if [ -n "$PRIVATE_KEY" ]; then
        set -- "$@" -i "$PRIVATE_KEY"
        printf "Private Key"
        printf "$*"

        if [ -n "$PASSPHRASE" ]; then
            sshpass -P "Enter passphrase" -p "$PASSPHRASE" ssh-add "$PRIVATE_KEY"
        fi
    fi

    set -- "$@" -o PubkeyAcceptedAlgorithms=+ssh-rsa -o StrictHostKeyChecking=accept-new "$USER@$HOST"

    unset HOST USER PORT PASSWORD PRIVATE_KEY PASSPHRASE
}

# Build and run an SFTP batch command for the given prefix using stdin as input.
run_sftp_batch() {
    prefix="$1"

    resolve_sftp_connection "$prefix"

    if [ -n "$PASSWORD" ]; then
        set -- sshpass -p "$PASSWORD" sftp -P "$PORT"
    else
        set -- sftp -P "$PORT"
    fi

    if [ -n "$PRIVATE_KEY" ]; then
        set -- "$@" -i "$PRIVATE_KEY"

        if [ -n "$PASSPHRASE" ]; then
            sshpass -P "Enter passphrase" -p "$PASSPHRASE" ssh-add "$PRIVATE_KEY"
        fi
    fi

    "$@" -o PubkeyAcceptedAlgorithms=+ssh-rsa -o StrictHostKeyChecking=accept-new "$USER@$HOST"
    status=$?

    unset HOST USER PORT PASSWORD PRIVATE_KEY PASSPHRASE

    return $status
}

# Upload the current temporary log file to the internal SFTP log path and remove it locally.
upload_log_file() {
    run_sftp_batch "INTERNAL_SFTP" <<EOF
put "$LOG_TMP_FILE" "$INTERNAL_LOG_PATH"
exit
EOF

    rm -f "$LOG_TMP_FILE"
}