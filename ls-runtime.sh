#!/bin/bash

########################################################################################################################
# Listet die deployten Artefakte.
########################################################################################################################
# shellcheck disable=SC2154,SC2059

. ./configure.sh

execute_api_request_with_retry "api/v1/IntegrationRuntimeArtifacts"

if [ "$RESPONSE_CODE" = 200 ]; then
  COUNT=$(jq -r '.d.results | length' <<< "$RESPONSE")
  printf "%s total artifacts\n" "$COUNT"
  if [ "$COUNT" -gt 0 ]; then printf "${white}"; fi
  for k in $(jq -r '.d.results | keys | .[]' <<< "$RESPONSE"); do
    if [ -z "$first_line" ]; then
      printf "%s\t%s\t%s\t%s\t%s\t%s${none}\n" "Id" "Type" "Status" "Version" "Deployed at" "Deployed by"
      first_line=1
    fi
    value=$(jq -r ".d.results[$k]" <<< "$RESPONSE")
    id=$(jq -r .Id <<< "$value")
    type=$(jq -r .Type <<< "$value")
    status=$(jq -r .Status <<< "$value")
    version=$(jq -r .Version <<< "$value")
    deplOn=$(jq -r .DeployedOn <<< "$value" | cut -c 7-16)
    deplOn=$(format_time "$deplOn")
    deplBy=$(jq -r .DeployedBy <<< "$value")
    printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$id" "$type" "$status" "$version" "$deplOn" "$deplBy"
  done | column -t -s$'\t'
fi