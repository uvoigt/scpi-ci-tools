#!/bin/bash

########################################################################################################################
# Listet die Design-time Artifacts im Workspace.
# Wenn ein Argument angegeben ist, wird das als Packagename interpretiert und nur die Artefakte des
# Packages ausgegeben. Ansonsten werden die Artefakte aller Packages ausgegeben.
# Im Moment muss diese Funktion über Eingabe des Passworts authentisiert werden (kein OAuth möglich)
########################################################################################################################

print_usage() {
  if [ -n "$1" ]; then
    printf "Usage: %s [options] [package_id]\n" "$(basename "$0")" 1>&2
    print_options
  fi
}

. login.sh

# shellcheck disable=SC2154,SC2059
get_dta_by_package() {
  execute_api_request "itspaces/odata/1.0/workspace.svc/ContentPackages('$1')/Artifacts?%24format=json"

  if [ "$RESPONSE_CODE" = 200 ]; then
    COUNT=$(jq -r '.d.results | length' <<< "$RESPONSE")
    printf "%s total artifacts\n" "$COUNT"
    if [ "$COUNT" -gt 0 ]; then
      printf "${white}"
      values=$(jq -r '.d.results[] | "\(.Name)\t\(.Type)\t\(.Version)\t\(.CreatedAt[6:16] | tonumber | strflocaltime("%d.%m %Y %H:%M:%S"))\t\(.CreatedBy)"' <<< "$RESPONSE" | sort)
      IFS=$'\n' array=("$values")
      ( printf "%s\t%s\t%s\t%s\t%s\t%s${none}\n" "Name" "Type" "Version" "Created at" "Created by"
        for i in "${array[@]}"; do
          printf "%s\n" "$i"
        done
      ) | column -t -s$'\t'
      if [ -n "$2" ]; then
        echo "$values" | cut -f 1 >> "$CONFIG_DIR/artifacts"
      fi
    fi
  fi
}

if [ -n "$1" ]; then
    get_dta_by_package "$1"
else
  # shellcheck source=packages.sh
  PACKAGE_NAMES=$(. "$BASE_DIR/packages.sh" | tail -n +3 | sed -n 's/^\([^ ]*\) .*/\1/p')
  : > "$CONFIG_DIR/artifacts"
  for k in $PACKAGE_NAMES; do
    printf "Package: ${white}%s\n${none}" "$k"
    get_dta_by_package "$k" true
  done
  sort -o "$CONFIG_DIR/artifacts" "$CONFIG_DIR/artifacts"
fi