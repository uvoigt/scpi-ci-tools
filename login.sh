#!/bin/sh

########################################################################################################################
# Eingabe von Benutzer und Passwort für Basic Auth
########################################################################################################################

if [ -n "$PASSWORD" ]; then return; fi

. ./configure.sh

CONFIG_USER=$USER
read -rp "Username [$USER]:" USER 1>&2
read -rsp Password: PASSWORD 1>&2
USER=${USER:-$CONFIG_USER}

printf "\n" 1>&2
AUTH="-u$USER:$PASSWORD"

save_config
