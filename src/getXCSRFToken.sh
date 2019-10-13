#!/bin/sh

########################################################################################################################
# Holt ein X-CSRF-Token und speichert die Konfiguration.
########################################################################################################################

rm -f "$CONFIG_DIR/cookies"
# shellcheck disable=SC2034
XCSRFTOKEN=$(curl -isc "$CONFIG_DIR/cookies" -b "$CONFIG_DIR/cookies" -H X-CSRF-Token:Fetch "$AUTH" "$TMN_URL/api/v1" | grep X-CSRF-Token | cut -c 15-46)

save_config
