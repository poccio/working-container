#!/bin/bash
set -euo pipefail

user="${1:?usage: create-user.sh <username>}"

# adduser --no-create-home --home /home/${user} ${user}
adduser --home "/home/${user}" "${user}"
chown -R "${user}:${user}" "/home/${user}"

usermod -aG docker "${user}"
usermod -aG sudo "${user}"

sudo -i -u "${user}" bash -i << 'EOF_USER'

cd

curl -LsSf https://astral.sh/uv/install.sh | sh

# install node via nvm
if [ ! -d .nvm ]; then
    curl --silent -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    source ~/.bashrc
    nvm install 22
    nvm alias default 22
    nvm use default
fi

EOF_USER
