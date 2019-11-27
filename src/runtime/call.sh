#!/bin/bash

########################################################################################################################
# Erlaubt es, einen Endpoint des Artefakts aufzurufen. Außerdem sind Funtionen zum Abfragen der Endpoints vorhanden.
########################################################################################################################

print_usage() {
  printf "Usage: %s [options] <artifact_id> [endpoint_url]\n" "$(basename "$0")" 1>&2
  print_options
  printf "Please specifiy the artifact to call.\n" 1>&2
  exit 1
}

. configure.sh

if [ -n "$2" ]; then
  url=$2
else
  execute_api_request_with_retry "api/v1/ServiceEndpoints?%24filter=Name%20eq%20'$ARTIFACT_ID'&%24expand=EntryPoints&%24format=json"
  if [ "$RESPONSE_CODE" = 200 ]; then
    url=$(jq -r '.d.results[] | .EntryPoints.results[] | .Url' <<< "$RESPONSE")
    if [ "$(echo "$url" | wc -l)" -gt 1 ]; then
      printf "The artifact specifies more than one endpoint.\n" 1>&2
      printf "%s\n" "$url"
      exit 1
    fi
  fi
fi
set -x
RESPONSE=$(curl -s -w "%{response_code}" -X POST "$AUTH" -H 'Content-Type: application/json' "$url" -d '{}')=
set +x
echo "Response:$RESPONSE"
if [ "$RESPONSE_CODE" = 200 ]; then
  printf "Artifact endpoint %s has been called.\n" "$1" 1>&2
fi