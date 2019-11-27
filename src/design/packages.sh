#!/bin/bash

########################################################################################################################
# Listet die Packages im Workspace.
# Im Moment muss diese Funktion über Eingabe des Passworts authentisiert werden (kein OAuth möglich)
########################################################################################################################

. login.sh

execute_api_request 'itspaces/odata/1.0/workspace.svc/ContentPackages?%24format=json'

# shellcheck disable=SC2154,SC2059
if [ "$RESPONSE_CODE" = 200 ]; then
  COUNT=$(jq -r '.d.results | length' <<< "$RESPONSE")
  printf "%s total artifacts\n" "$COUNT"
  if [ "$COUNT" -gt 0 ]; then
    printf "${white}"
    values=$(jq -r '.d.results[] | "\(.TechnicalName)\t\(.Version)\t\(.CreatedAt[6:16] | tonumber | strflocaltime("%d.%m %Y %H:%M:%S"))\t\(.CreatedBy)"' <<< "$RESPONSE" | sort)
    IFS=$'\n' array=("$values")
    ( printf "%s\t%s\t%s\t%s${none}\n" "Name" "Version" "Created at" "Created by"
      for i in "${array[@]}"; do
        printf "%s\n" "$i"
      done
    ) | column -t -s$'\t'
    echo "$values" | cut -f 1 > "$CONFIG_DIR/packages"
  fi
fi