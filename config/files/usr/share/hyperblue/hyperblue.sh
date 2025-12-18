#!/usr/bin/env bash
set -oue pipefail

copy_user_configs() {
    echo "Ensure all users have new skeleton files from /etc/skel only if they do not have a .config/hyperblue directory."
    for user in $(awk -F: '$3 >= 1000 && $3 < 60000 {print $1}' /etc/passwd); do
        user_home=$(getent passwd "$user" | cut -d: -f6)
        if [ -d "$user_home" ]; then
            if [ -d "$user_home/.config/hyperblue" ]; then
                echo "User $user already has a .config/hyperblue directory. Skipping..."
            else
                echo "Copying skeleton files to $user_home"
                cp -rn /etc/skel/. "$user_home/"
                mkdir -p "$user_home/.config/hyperblue"
                cp /usr/share/hyperblue/user_config/hyperblue.conf "$user_home/.config/hyperblue/"
                chown -R "$user":"$user" "$user_home"
                echo "Setup done for $user"
            fi
        else
            echo "Home directory $user_home does not exist for user $user, skipping..."
        fi
    done
}

first_run="/etc/hyperblue/first_run"
if [ ! -f "$first_run" ]; then
    echo "First run detected. Running initial setup..."
    copy_user_configs

    touch "$first_run"
else
    echo "Skipping initial setup..."
fi
