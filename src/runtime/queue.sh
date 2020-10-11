#!/bin/bash

########################################################################################################################
# Setzt Operationen auf JMS-Queues um.
########################################################################################################################
# shellcheck disable=SC2154,SC2059

print_usage() {
  if [ -n "$1" ]; then
    printf "Usage: %s [options] <queue_id> [<cmd> <mpl_id> | <jms_msg_id>] \n" "$(basename "$0")" 1>&2
    printf "Commands: show   - show the message\n"
    printf "          delete - delete the message\n"
    printf "          retry  - retry the message\n"
    print_options
    exit 0
  fi
}

. configure.sh

list_queues() {
  execute_api_request_with_retry "api/v1/Queues"
  if [ "$RESPONSE_CODE" = 200 ]; then
    COUNT=$(jq -r '.d.results | length' <<< "$RESPONSE")
    printf "%s total queues\n" "$COUNT"
    if [ "$COUNT" -gt 0 ]; then
      printf "${white}"
      values=$(jq -r '.d.results[] | "\(.Name)\t\(.NumbOfMsgs)"' <<< "$RESPONSE" | sort)
      ( printf "%s\t%s${none}\n" "Name" "Messages"
        printf "%s\n" "$values"
      ) | column -t -s$'\t'
    fi
  fi
}

retry_queue() {
  execute_api_request_with_retry \
    "api/v1/Queues('$1')" \
    MERGE \
    true
  if [ "$RESPONSE_CODE" = 204 ]; then
    printf "Queue retry triggered\n" 1>&2
  fi
}

list_messages() {
  execute_api_request_with_retry "api/v1/Queues('$1')/Messages"
  if [ "$RESPONSE_CODE" = 200 ]; then
    COUNT=$(jq -r '.d.results | length' <<< "$RESPONSE")
    printf "%s total messages\n" "$COUNT"
    if [ "$COUNT" -gt 0 ]; then
      now=$(($(date +%s) * 1000))
      printf "${white}"
      values=$(jq -r --arg NOW "$now" '.d.results[] | "\(.CreatedAt[0:10] | tonumber | strflocaltime("%d.%m %Y %H:%M:%S"))'\
'\t\(.Msgid)\t\(.Mplid)\t\(if .OverdueAt < $NOW and (.Failed | not) then "Overdue" elif .Failed then "Failed" else "Waiting" end)\t\(.RetryCount)'\
'\t\(if .NextRetry=="0" then " " else .NextRetry[0:10] | tonumber | strflocaltime("%d.%m %Y %H:%M:%S") end)'\
'\t\(.OverdueAt[0:10] | tonumber | strflocaltime("%d.%m %Y %H:%M:%S"))'\
'\t\(.ExpirationDate[0:10] | tonumber | strflocaltime("%d.%m %Y %H:%M:%S"))"' <<< "$RESPONSE" | sort -k2,2gr)
      ( printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s${none}\n" "Created at" "Id" "MPL Id" "Status" "Retry count" "Next retry" "Due at" "Expires at"
        printf "%s\n" "$values"
      ) | column -t -s$'\t'
    fi
  fi
}

internal_get_message() {
  execute_api_request_with_retry "api/v1/Queues('$1')/Messages?timeout=1000000"
  if [ "$RESPONSE_CODE" = 200 ]; then
    [[ "$2" == ID:* ]] && query=Msgid || query=Mplid
    local result
    result=$(jq -r '.d.results[] | select(.'$query'=="'"$2"'") | .Msgid, .Failed' <<< "$RESPONSE")
    msgIdAndStatus=() && while IFS=$'\n' read -r value; do msgIdAndStatus+=("$value"); done <<< "$result"
  fi
  if [ ${#msgIdAndStatus[@]} -lt 2 ]; then
    printf "Message %s not found\n" "$2" 1>&2
    exit 1
  fi
}

download_message() {
  internal_get_message "$1" "$2"
  tmpFile=$TMPDIR/_message.zip
  execute_api_request_with_retry \
    "api/v1/JmsMessages(Msgid='${msgIdAndStatus[0]//:/%3A}',Name='$1',Failed=${msgIdAndStatus[1]})/%24value" \
    GET \
    false \
    "-o$tmpFile"
  if [ "$RESPONSE_CODE" = 200 ]; then
    tmpDir=$TMPDIR/_message
    mkdir -p "$tmpDir"
    unzip -q -d "$tmpDir" "$tmpFile"
    find "$tmpDir" -type f -exec sh -c 'i=$1; printf "$2\n%s\n\n$3" $(basename "$1"); cat $1' _ {} "${white}" "${none}" \;
    rm "$tmpDir"/*
    rm "$tmpFile"
  fi
}

retry_message() {
  internal_get_message "$1" "$2"
  execute_api_request_with_retry \
    "api/v1/JmsMessages(Msgid='${msgIdAndStatus[0]//:/%3A}',Name='$1',Failed=${msgIdAndStatus[1]})" \
    MERGE \
    true
  if [ "$RESPONSE_CODE" = 204 ]; then
    printf "Message retry triggered\n" 1>&2
  else
    RESPONSE="${RESPONSE%???}"
    printf "%s\n" "$RESPONSE" 1>&2
  fi
}

delete_message() {
  internal_get_message "$1" "$2"
  execute_api_request_with_retry \
    "api/v1/JmsMessages(Msgid='${msgIdAndStatus[0]//:/%3A}',Name='$1',Failed=${msgIdAndStatus[1]})" \
    DELETE \
    true
  if [ "$RESPONSE_CODE" = 204 ]; then
    printf "Message deleted\n" 1>&2
  fi
}

queueId=$1
cmd=$2
msgId=$3

if [ -n "$queueId" ]; then
  if [ -n "$cmd" ]; then
    case $cmd in
    delete)
      [ -n "$msgId" ] && delete_message "$queueId" "$msgId" || printf "Queue deletion not implemented\n" 1>&2
      ;;
    show)
      [ -n "$msgId" ] && download_message "$queueId" "$msgId" || printf "Queue display not supported\n" 1>&2
      ;;
    retry)
      if [ -n "$msgId" ]; then retry_message "$queueId" "$msgId"; else retry_queue "$queueId"; fi
      ;;
    *)
      printf "Illegal command %s\n" "$cmd" 1>&2
    esac
  else
    list_messages "$queueId"
  fi
else
  list_queues
fi
