#!/bin/bash

########################################################################################################################
# Zeigt die messages logs an.
########################################################################################################################
# shellcheck disable=SC2154,SC2059

# shellcheck disable=SC2034
handle_option() {
  if [ "$1" = "-n" ]; then
    messageNum=$2
    SHIFT_COUNT=2
  fi
}

print_usage() {
  if [ -n "$1" ]; then
    printf "Usage: %s [options] [-n <last n messages>, default=10] | [<message_Id>]\n" "$(basename "$0")" 1>&2
    print_options
    exit 1
  fi
}

. configure.sh

[ -z "$messageNum" ] && messageNum=10
if [ -n "$1" ]; then
  execute_api_request_with_retry "api/v1/MessageProcessingLogErrorInformations('$1')/%24value"
  if [ "$RESPONSE_CODE" = 200 ]; then
    printf "${white}Log Details\n${none}"
    printf "%s\n" "$RESPONSE"
  fi
  execute_api_request_with_retry "api/v1/MessageProcessingLogs('$1')/Attachments"
  if [ "$RESPONSE_CODE" = 200 ]; then
    printf "${white}Attachments\n${none}"
    values=$(jq -r '.d.results[] | "\(.Id) \(.Name)"' <<< "$RESPONSE")
    array=() && while IFS=$'\n' read -r value; do array+=("$value"); done <<< "$values"
    for i in "${array[@]}"; do
      printf "%s\n" "${i:62}"
      execute_api_request_with_retry "api/v1/MessageProcessingLogAttachments('$(echo "$i" | cut -d' ' -f1)')/%24value"
      if [ "$RESPONSE_CODE" = 200 ]; then
        printf "%s\n" "$RESPONSE"
      fi
    done
  fi
else
  execute_api_request_with_retry "api/v1/MessageProcessingLogs?%24orderby=LogStart%20desc&%24top=$messageNum"

  if [ "$RESPONSE_CODE" = 200 ]; then
    COUNT=$(jq -r '.d.results | length' <<< "$RESPONSE")
    printf "%s total messages\n" "$COUNT"
    if [ "$COUNT" -gt 0 ]; then
      printf "${white}"
    # | sort -k2h -t'.' -t' ' -k2h -k1h)
      values=$(jq -r '.d.results[] | "\(.IntegrationFlowName)\t\(.LogStart | capture("(?<a>[0-9]{10})(?<b>[0-9]{3})") | (.a | tonumber | strflocaltime("%d.%m %Y %H:%M:%S") + ".") + .b)\t\(.LogEnd | capture("(?<a>[0-9]{10})(?<b>[0-9]{3})") | (.a | tonumber | strflocaltime("%d.%m %Y %H:%M:%S") + ".") + .b)\t\(.Status)\t\(.MessageGuid)"' <<< "$RESPONSE")
      array=() && while IFS=$'\n' read -r value; do array+=("$value"); done <<< "$values"
      ( printf "%s\t%s\t%s\t%s\t%s${none}\n" "Artifact" "Start" "End" "Status" "MessageId"
        for i in "${array[@]}"; do
          printf "%s\n" "$i"
        done
      ) | column -t -s$'\t'
    fi
  fi
fi