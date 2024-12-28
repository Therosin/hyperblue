#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
# You should have this in every custom script, to ensure that your completed
# builds actually ran successfully without any errors!
set -oue pipefail
echo "Installing Lite-XL..."

curl -LO https://github.com/lite-xl/lite-xl/releases/download/v2.1.7/lite-xl-v2.1.7-addons-linux-x86_64-portable.tar.gz

if tar -xzf lite-xl-v2.1.7-addons-linux-x86_64-portable.tar.gz -C /opt; then
    echo "Extraction successful."
else
    echo "Error: Extraction failed." >&2
    exit 1
fi

if [ -d /opt/lite-xl ]; then
    echo "Directory /opt/lite-xl exists."
else
    echo "Error: Directory /opt/lite-xl was not created." >&2
    exit 1
fi

if chown -R root:root /opt/lite-xl && chmod -R 755 /opt/lite-xl; then
    echo "Permissions set successfully."
else
    echo "Error: Failed to set permissions." >&2
    exit 1
fi

if ! grep -q '/opt/lite-xl' /etc/profile; then
    if echo 'export PATH=/opt/lite-xl:$PATH' | tee -a /etc/profile > /dev/null; then
        echo "PATH updated successfully."
    else
        echo "Error: Failed to update PATH." >&2
        exit 1
    fi
fi

if rm -f lite-xl-v2.1.7-addons-linux-x86_64-portable.tar.gz; then
    echo "Cleanup successful."
else
    echo "Error: Cleanup failed." >&2
fi

echo "Lite XL installed system-wide. You may need to restart your session to update the PATH."
