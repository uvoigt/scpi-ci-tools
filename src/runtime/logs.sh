#!/bin/bash

########################################################################################################################
# Lädt das letzte ljs_trace Log herunter und zeigt es an.
########################################################################################################################
# shellcheck disable=SC2046

. configure.sh

# %24orderby=LastModified&%24top=1   the API is buggy, no sort no skip or top
# therefore order with jq
execute_api_request_with_retry "api/v1/LogFiles?%24filter=LogFileType%20eq%20'trace'"
tmpFile=$TMPDIR/_log.gz
if [ "$RESPONSE_CODE" = 200 ]; then
  read -r name application <<< $(jq -r '.d | .results |= sort_by(.LastModified) | .results | last | .Name, .Application' <<< "$RESPONSE")
  execute_api_request_with_retry \
    "api/v1/LogFiles(Name='$name',Application='$application')/%24value" \
    GET \
    false \
    "-o$tmpFile"
  gzip -d < "$tmpFile"
  rm "$tmpFile"
fi