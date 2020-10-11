#!/bin/sh

########################################################################################################################
# Wechselt die SCPI config zum angegebenen System im ersten Parameter
########################################################################################################################

. configure.sh

if [ -n "$1" ]; then
  if [ "$1" = "$CONFIG_ENV" ]; then
    printf "Already at config '%s'\n" "$CONFIG_ENV" 1>&2
  else
    CONFIG_ENV=$1
    save_config
    echo "Switched to config '$1'"
  fi
else
  printf "Current config is '%s'\n" "$CONFIG_ENV" 1>&2
fi