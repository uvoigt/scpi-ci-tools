#!/bin/bash

########################################################################################################################
# Zeigt die messages logs an.
########################################################################################################################
# shellcheck disable=SC2154,SC2059

trap "exit 1" TERM
PID=$$

applyTime() {
  if [ ${#1} = 10 ]; then
    echo "$1T$2"
  elif [ ${#1} = 19 ]; then
    echo "$1"
  else
    printf "Irregular date: %s\n" "$1" 1>&2
    kill -s TERM $PID
  fi
}

applyFilter() {
  if [ -n "$filter" ]; then
    filter="$filter%20and%20$1"
  else
    filter=$1
  fi
}

handle_option() {
  if [[ "$1" = -* ]]; then
    optValue=${1:1}
    if [ "$optValue" = n ]; then
      applyFilter "IntegrationFlowName%20eq%20'$2'"
      SHIFT_COUNT=2
    elif [ "$optValue" = t ]; then
      applyFilter "LogStart%20ge%20datetime'$(applyTime "$2" 00:00:00)'%20and%20LogEnd%20le%20datetime'$(applyTime "$3" 23:59:59)'"
      SHIFT_COUNT=3
    elif [ "$optValue" = s ]; then
      applyFilter "Status%20eq%20'$2'"
      messageStatus=$2
      SHIFT_COUNT=2
    elif [ "$optValue" = f ]; then
      filterText=$2
      SHIFT_COUNT=2
    elif [ "$optValue" = an ]; then
      filterAttachment=$2
      SHIFT_COUNT=2
    elif [ "$optValue" = exec ]; then
      filterCommand=$2
      SHIFT_COUNT=2
    elif [ "$optValue" = exat ]; then
      commandAttachment=$2
      SHIFT_COUNT=2
    else
      messageNum=$optValue
      # shellcheck disable=SC2034
      SHIFT_COUNT=1
    fi
  fi
}

print_usage() {
  if [ -n "$1" ]; then
    printf "Usage: %s [options] | [<message_Id>]\n" "$(basename "$0")" 1>&2
    print_options "-<number> list the number of last messages, default=10" \
      "-n <name> filter by artifact" \
      "-s <status> filter by status, valid values are FAILED, RETRY, COMPLETED, PROCESSING, ESCALATED" \
      "-t <time> <time> filter by start and end time, format is 2019-12-24T08:05:00 or 2019-12-24" \
      "-f <text> filter by text within attachments (potentially time consuming!)" \
      "-an <name> when filtering by text within attachments look into attachments with that name only" \
      "-exec <command> when filtering by text within attachments the command is applied to the attachments and the output is displayed" \
      "-exat <name> when a command is applied, apply it to the attachment with that name"
    exit 0
  fi
}

# messageGuid displayResults attachmentNameToFilter onlyFirstAttachmentWithTheName
get_attachments() {
  execute_api_request_with_retry "api/v1/MessageProcessingLogs('$1')/Attachments"
  if [ "$RESPONSE_CODE" = 200 ]; then
    if [ "$2" = true ]; then
      printf "${white}Attachments\n${none}"
    fi
    values=$(jq -r '.d.results[] | "\(.Id) \(.Name)"' <<< "$RESPONSE")
    array=() && while IFS=$'\n' read -r value; do array+=("$value"); done <<< "$values"
    for i in "${array[@]}"; do
      if [ "$2" = true ]; then
        printf "${white}Name${none} %s\n" "${i:62}"
      fi
      if [ -n "$3" ] && [ "$3" != "${i:62}" ]; then
        continue
      fi
      execute_api_request "api/v1/MessageProcessingLogAttachments('$(echo "$i" | cut -d' ' -f1)')/%24value" GET false "" 404
      if [ "$RESPONSE_CODE" = 200 ]; then
        if [ "$2" = true ]; then
          printf "%s\n" "$RESPONSE"
        else
          echo "$RESPONSE"
          if [ -n "$4" ]; then
            break
          fi
        fi
      fi
    done
  fi
}

. configure.sh

[ -z "$messageNum" ] && messageNum=10
if [ -n "$1" ]; then
  execute_api_request_with_retry "api/v1/MessageProcessingLogs('$1')"
  if [ "$RESPONSE_CODE" = 404 ]; then
    printf "No messages found for %s\n" "$1"
    exit 1
  fi
  # shellcheck disable=SC2046
  read -r name status <<< $(jq -r '.d | .IntegrationFlowName, .Status' <<< "$RESPONSE")
  printf "${white}Artifact${none} %s\n" "$name"
  printf "${white}Status${none} %s\n" "$status"

  execute_api_request_with_retry "api/v1/MessageProcessingLogErrorInformations('$1')/%24value"
  if [ "$RESPONSE_CODE" = 200 ]; then
    printf "${white}Error Details\n${none}"
    printf "%s\n" "$RESPONSE"
  fi

# weitere... /CustomHeaderProperties /MessageStoreEntries /AdapterAttributes /Runs
  get_attachments "$1" true
else
  nextUrl="MessageProcessingLogs?%24inlinecount=allpages&%24orderby=LogStart%20desc"
  if [ -n "$filter" ]; then
    nextUrl="$nextUrl&%24filter=$filter"
  fi
  if [ -z "$filterText" ];then
    nextUrl="$nextUrl&%24top=$messageNum"
  fi
  while (( "$messageNum" > 0 )); do
    execute_api_request_with_retry "api/v1/$nextUrl"

    if [ "$RESPONSE_CODE" = 200 ]; then
      # shellcheck disable=SC2046
      read -r COUNT next <<< $(jq -r '.d | .__count, .__next' <<< "$RESPONSE")
      [ -n "$filterAttachment" ] && [ "$messageStatus" = "RETRY" ] && onlyFirst=true
      if [ -n "$filterText" ]; then # search in attachments
        if [ -z "$firstPass" ]; then
          messageArg=all
          [ -n "$filterAttachment" ] && messageArg="'$filterAttachment'"
          [ -n "$onlyFirst" ] && messageArg="only the first occurrence of '$filterAttachment'"
          printf "Searching in %s attachments of %s messages\n" "$messageArg" "$COUNT"
          messageNum=$COUNT
        fi
        values=$(jq -r '.d.results[] | .MessageGuid' <<< "$RESPONSE")
        array=() && while IFS=$'\n' read -r value; do array+=("$value"); done <<< "$values"
        for i in "${array[@]}"; do
          attachment=$(get_attachments "${i:(-28)}" false "$filterAttachment" "$onlyFirst")
          if [[ $attachment == *"$filterText"* ]]; then
            if [ -n "$filterCommand" ]; then
              if [ -n "$commandAttachment" ]; then
                attachment=$(get_attachments "${i:(-28)}" false "$commandAttachment" "$onlyFirst")
              fi
              i=$(eval "$filterCommand" <<< "$attachment")
            fi
            printf "%s\n" "$i"
          fi
        done
      else # print message log entries
        if [ -z "$firstPass" ]; then
          printf "%s total messages\n" "$COUNT"
        fi
        if [ "$COUNT" -gt 0 ]; then
          # | sort -k2h -t'.' -t' ' -k2h -k1h)
          values=$(jq -r '.d.results[] | "\(.IntegrationFlowName)\t\(.LogStart | capture("(?<a>[0-9]{10})(?<b>[0-9]{3})") | (.a | tonumber | strflocaltime("%d.%m %Y %H:%M:%S") + ".") + .b)\t\(.LogEnd | capture("(?<a>[0-9]{10})(?<b>[0-9]{3})") | (.a | tonumber | strflocaltime("%d.%m %Y %H:%M:%S") + ".") + .b)\t\(.Status)\t\(.MessageGuid)"' <<< "$RESPONSE")
          array=() && while IFS=$'\n' read -r value; do array+=("$value"); done <<< "$values"
          [ -z "$firstPass" ] && printf "${white}"
          ( [ -z "$firstPass" ] && printf "%s\t%s\t%s\t%s\t%s${none}\n" "Artifact" "Start" "End" "Status" "MessageId"
            for i in "${array[@]}"; do
              printf "%s\n" "$i"
            done
          ) | column -t -s$'\t'
        fi
      fi
      if [ "$next" != null ]; then
        nextUrl=$next
        nextUrl="${nextUrl/top=$messageNum/top=$((messageNum - 1000))}"
        messageNum=$((messageNum - 1000))
        firstPass=false
      else
        break
      fi
    else
      break
    fi
  done
fi