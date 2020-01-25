#!/bin/bash

########################################################################################################################
# Listet die deployten Artefakte.
########################################################################################################################
# shellcheck disable=SC2154,SC2059

. configure.sh

execute_api_request_with_retry "api/v1/IntegrationRuntimeArtifacts"

if [ "$RESPONSE_CODE" = 200 ]; then
  COUNT=$(jq -r '.d.results | length' <<< "$RESPONSE")
  printf "%s total artifacts\n" "$COUNT"
  if [ "$COUNT" -gt 0 ]; then
    printf "${white}"
    values=$(jq -r '.d.results[] | "\(.Id)\t\(.Type)\t\(.Status)\t\(.Version)\t\(.DeployedOn[6:16] | tonumber | strflocaltime("%d.%m %Y %H:%M:%S"))\t\(.DeployedBy)"' <<< "$RESPONSE" | sort)
    ( printf "%s\t%s\t%s\t%s\t%s\t%s${none}\n" "Id" "Type" "Status" "Version" "Deployed at" "Deployed by"
      printf "%s\n" "$values"
    ) | column -t -s$'\t'
  fi
fi