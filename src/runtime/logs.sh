#!/bin/bash

########################################################################################################################
# Lädt das letzte ljs_trace Log herunter und zeigt es an.
########################################################################################################################
# shellcheck disable=SC2046

. configure.sh

execute_api_request_with_retry "api/v1/LogFiles"
tmpFile=$TMPDIR/_log.gz
if [ "$RESPONSE_CODE" = 200 ]; then
  read -r name application <<< $(jq -r '.d.results | last | .Name, .Application' <<< "$RESPONSE")
  execute_api_request_with_retry \
    "api/v1/LogFiles(Name='$name',Application='$application')/%24value" \
    GET \
    false \
    "-o$tmpFile"
  gzip -d < "$tmpFile"
  rm "$tmpFile"
fi