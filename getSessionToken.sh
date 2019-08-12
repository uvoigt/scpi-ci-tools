#!/bin/sh

. ./configure.sh

CONFIG_USER=$USER
read -p "Username [$USER]:" USER
read -sp Password: PASSWORD
USER=${USER:-$CONFIG_USER}

echo # new line

TMN_URL="https://$ACCOUNT_ID-tmn.hci.eu2.hana.ondemand.com/api/v1"

echo "Fetching X-CSRF-Token..."
XCSRFTOKEN=$(curl -is -H X-CSRF-Token:Fetch -u $USER:$PASSWORD \
    $TMN_URL | grep X-CSRF-Token | cut -c 15-46)

save_config
