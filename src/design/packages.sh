#!/bin/bash

########################################################################################################################
# Listet die Packages im Workspace.
########################################################################################################################

. configure.sh

execute_api_request_with_retry 'api/v1/IntegrationPackages'

# shellcheck disable=SC2154,SC2059
if [ "$RESPONSE_CODE" = 200 ]; then
  COUNT=$(jq -r '.d.results | length' <<< "$RESPONSE")
  printf "%s total packages\n" "$COUNT"
  if [ "$COUNT" -gt 0 ]; then
    printf "${white}"
    values=$(jq -r '.d.results[] | "\(.Name)\t\(if .Version | length == 0 then " " else .Version end)'\
'\t\(.CreationDate[0:10] | tonumber | strflocaltime("%d.%m %Y %H:%M:%S"))'\
'\t\(.CreatedBy)\t\(.ModifiedDate[0:10] | tonumber | strflocaltime("%d.%m %Y %H:%M:%S"))\t\(.ModifiedBy)"' <<< "$RESPONSE" | sort)
    ( printf "%s\t%s\t%s\t%s\t%s\t%s${none}\n" "Name" "Version" "Created at" "Created by" "Modified at" "Modified by"
      printf "%s\n" "$values"
    ) | column -t -s$'\t'
  fi
fi