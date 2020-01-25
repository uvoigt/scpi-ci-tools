#!/bin/bash

########################################################################################################################
# Liest die Deployment-Fehlerinformationen des Runtime-Artefakts
########################################################################################################################
# shellcheck disable=SC2154,SC2059

print_usage() {
  printf "Usage: %s [options] <artifact_id>\n" "$(basename "$0")" 1>&2
  print_options
  printf "Please specifiy the artifact to download errors for.\n" 1>&2
  exit 1
}

. configure.sh

execute_api_request_with_retry "api/v1/IntegrationRuntimeArtifacts('$ARTIFACT_ID')/ErrorInformation/%24value"
if [ "$RESPONSE_CODE" = 204 ]; then
  printf "%s is up and running.\n" "$ARTIFACT_ID"
elif [ "$RESPONSE_CODE" = 200 ]; then
  children="$(jq -r '.. | .message + {"params": (.parameter? | try join(", ") catch "")} | select(.subsystemName != null) | "\(.subsystemName?)\t\(.subsytemPartName?)\t\(.messageText?)\t\(.params)"' <<< "$RESPONSE")"
  printf "${white}"
  ( printf "%s\t%s\t%s\t%s${none}\n" "System" "Part" "Message" "Parameters"
    printf "%s\n" "$children"
  ) | column -t -s$'\t'
fi