#!/bin/bash

########################################################################################################################
# Lädt das letzte ljs_trace oder http Log herunter und zeigt es an.
########################################################################################################################
# shellcheck disable=SC2046

print_usage() {
  if [ -n "$1" ]; then
    printf "Usage: %s [<http|trace> <node_code>]\n" "$(basename "$0")" 1>&2
    print_options "http - shows the http log, else the trace log" \
      "node_code - the short hand code of the node - if not specified, the latest is displayed"
    exit 0
  fi
}

. configure.sh

# %24orderby=LastModified&%24top=1   the API is buggy, no sort no skip or top
# therefore order with jq

[ "$1" = http ] && logType=http || logType=trace

execute_api_request_with_retry "api/v1/LogFiles?%24filter=LogFileType%20eq%20'$logType'"
tmpFile=$TMPDIR/_log.gz
if [ "$RESPONSE_CODE" = 200 ]; then
  if [ -n "$2" ]; then
    read -ra array <<< $(jq -r '.d | .results |= sort_by(.LastModified) | .results | reverse | .[0]?.Name, .[0]?.Application, .[1]?.Name, .[1]?.Application' <<< "$RESPONSE")
    for i in "${!array[@]}"; do
      if [[ "${array[$i]}" =~ $2 ]]; then
        name=${array[$i]}
        application=${array[$i+1]}
        break
      fi
    done
  else
    read -r name application <<< $(jq -r '.d | .results |= sort_by(.LastModified) | .results | last | .Name, .Application' <<< "$RESPONSE")
  fi
  execute_api_request_with_retry \
    "api/v1/LogFiles(Name='$name',Application='$application')/%24value" \
    GET \
    false \
    "-o$tmpFile"
  gzip -d < "$tmpFile"
  rm "$tmpFile"
fi