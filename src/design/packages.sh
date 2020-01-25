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
  printf "%s total packages\n" "$COUNT"
  if [ "$COUNT" -gt 0 ]; then
    printf "${white}"
    values=$(jq -r '.d.results[] | "\(.TechnicalName)\t\(.Version)\t\(.CreatedAt[6:16] | tonumber | strflocaltime("%d.%m %Y %H:%M:%S"))\t\(.CreatedBy)"' <<< "$RESPONSE" | sort)
    ( printf "%s\t%s\t%s\t%s${none}\n" "Name" "Version" "Created at" "Created by"
      printf "%s\n" "$values"
    ) | column -t -s$'\t'
    echo "$values" | cut -f 1 > "$CONFIG_DIR/packages"
  fi
else
  printf "Error Response Code: %s\n" "$RESPONSE_CODE" 1>&2
fi