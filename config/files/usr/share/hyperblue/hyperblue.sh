# Copyright (C) 2025 Theros <https://github.com/therosin>
#
# This file is part of hyperblue.
#
# hyperblue is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# hyperblue is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with hyperblue.  If not, see <https://www.gnu.org/licenses/>.

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
