#!/bin/sh

# Create a folder to store user's SSH keys if it does not exist.
USER_SSH_KEYS_FOLDER=~/.ssh
[ ! -d $pk_sfcc_requests ] && mkdir -p $USER_SSH_KEYS_FOLDER

# Copy contents from the `pk_sfcc_requests` environment variable
# to the `$USER_SSH_KEYS_FOLDER/authorized_keys` file.
# The environment variable must be set when the container starts.
echo $ > $USER_SSH_KEYS_FOLDER/authorized_keys

# Clear the `SSH_PUBLIC_KEY` environment variable.
unset pk_sfcc_requests

# Start the SSH daemon.
/usr/sbin/sshd -D