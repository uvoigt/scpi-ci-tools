#!/bin/bash

########################################################################################################################
# Listet die Design-time Artifacts im Workspace.
# Wenn ein Argument angegeben ist, wird das als Packagename interpretiert und nur die Artefakte des
# Packages ausgegeben. Ansonsten werden die Artefakte aller Packages ausgegeben.
########################################################################################################################

print_usage() {
  if [ -n "$1" ]; then
    printf "Usage: %s [options] [package_id]\n" "$(basename "$0")" 1>&2
    print_options
  fi
}

. configure.sh

# shellcheck disable=SC2154,SC2059
get_dta_by_package() {
  execute_api_request_with_retry "api/v1/IntegrationPackages('$1')/IntegrationDesigntimeArtifacts"

  if [ "$RESPONSE_CODE" = 200 ]; then
    COUNT=$(jq -r '.d.results | length' <<< "$RESPONSE")
    printf "%s total artifacts\n" "$COUNT"
    if [ "$COUNT" -gt 0 ]; then
      printf "${white}"
      values=$(jq -r '.d.results[] | "\(.Name)\t\(.Version)"' <<< "$RESPONSE" | sort)
      ( printf "%s\t%s\t%s${none}\n" "Name" "Version"
        printf "%s\n" "$values"
      ) | column -t -s$'\t'
    fi
  fi
}

if [ -n "$1" ]; then
    get_dta_by_package "$1"
else
  execute_api_request_with_retry 'api/v1/IntegrationPackages'
  if [ "$RESPONSE_CODE" = 200 ]; then
    values=$(jq -r '.d.results[] | "\(.Id)\n\( .Name)"' <<< "$RESPONSE")
    array=() && while IFS=$'\n' read -r value; do array+=("$value"); done <<< "$values"
    for i in "${!array[@]}"; do
      if (( i % 2 == 0 )); then
        printf "Package: ${white}%s\n${none}" "${array[$i + 1]}"
        get_dta_by_package "${array[$i]}"
      fi
    done
  fi
fi