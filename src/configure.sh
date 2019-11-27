#!/bin/bash

########################################################################################################################
# Definition allgemeiner Funktionen und Analyse der Kommandozeilenoptionen.
# Der Aufrufer kann eine Funktion "handle_option" für das Behandeln zusätzlicher Optionen bereitstellen.
# Diese Funktion setzt die Variable SHIFT_COUNT, wenn der Parameter behandelt wurde.
########################################################################################################################

# shellcheck disable=SC2034
white='\033[1;37m'
none='\033[0m'
SCPI_OAUTH_CLIENT_ID='***REMOVED***'

print_options() {
  printf "Options: -a <account_id>\n" 1>&2
  printf "\t -o <oauth_prefix>\n" 1>&2
  printf "\t -c <client_id:secret>\n" 1>&2
  for var in "$@"; do
    printf "\t %s\n" "$var" 1>&2
  done
  printf "\t -? | --help\tshow this help\n"
}

save_config() {
  (printf "ACCOUNT_ID=%s\n" "$ACCOUNT_ID"; \
    printf "OAUTH_PREFIX=%s\n" "$OAUTH_PREFIX"; \
    printf "USER=%s\n" "$USER"; \
    printf "OAUTH_TOKEN_BITBUCKET=%s\n" "$OAUTH_TOKEN_BITBUCKET"; \
    printf "OAUTH_TOKEN_SCPI=%s\n" "$OAUTH_TOKEN_SCPI"; \
    printf "XCSRFTOKEN=%s\n" "$XCSRFTOKEN") > "$CONFIG_FILE"
}

# Parameter: <query>
#            [<method>]
#            [true wenn XCSRFToken benötigt wird, default false]
#            zusätzliche curl optionen
execute_api_request() {
  : > "$CONFIG_DIR/cookies"
  if [ "$3" = true ]; then
    . getXCSRFToken.sh
  fi
  [ -n "$2" ] && method="$2" || method='GET'
  [ -n "$4" ] && additional="$4" || additional='-g'
  RESPONSE=$(curl -s \
    -X "$method" \
    -H Accept:application/json \
    -H Content-Type:application/json \
    -H "X-CSRF-Token:$XCSRFTOKEN" \
    "$AUTH" \
    -b "$CONFIG_DIR/cookies" \
    -w "%{response_code}" \
    $additional \
    "$TMN_URL/$1")
  RESPONSE_CODE=$(printf "%s" "${RESPONSE: -3}")
  if [[ "$RESPONSE_CODE" = 20* ]]; then
    RESPONSE="${RESPONSE%???}"
  elif [ "$RESPONSE_CODE" != 401 ]; then
    printf "Error Response Code: %s\n" "$RESPONSE_CODE" 1>&2
  fi
}

execute_api_request_with_retry() {
  execute_api_request "$@"
  if [ "$RESPONSE_CODE" = 401 ]; then
    printf "Session expired, logging in...\n" 1>&2
    . getOAuthToken.sh 0 "https://oauthasservices-$OAUTH_PREFIX.eu2.hana.ondemand.com/oauth2/api/v1" "$SCPI_OAUTH_CLIENT_ID"
    execute_api_request "$@"
  fi
}

set_default_folder() {
  [ -n "$GIT_BASE_DIR" ] && FOLDER="$GIT_BASE_DIR/iflow_${ARTIFACT_ID}" || FOLDER="../iflow_${ARTIFACT_ID}"
}

CONFIG_DIR=~/.scpi
CONFIG_FILE=$CONFIG_DIR/config

mkdir -p "$CONFIG_DIR"
if [ -f $CONFIG_FILE ]; then
  # shellcheck source=hello
  . $CONFIG_FILE
fi
AUTH="-HAuthorization:Bearer $OAUTH_TOKEN_SCPI"

if [ -n "${COMP_WORDS[0]}" ]; then
  TMN_URL="https://$ACCOUNT_ID-tmn.hci.eu2.hana.ondemand.com"
  return;
fi
BASE_DIR=$(dirname "$0")

ARGS=("$@")

for i in "${!ARGS[@]}"; do
  ARG="${ARGS[$i]}"
  # ggf. wurde eine Erweiterungsfunktion übergeben
  if [ -n "$(LC_ALL=C type -t handle_option)" ] && [ "$(type -t handle_option)" = function ]; then
    SHIFT_COUNT=0
    handle_option "$ARG"
    shift $SHIFT_COUNT
  fi
  if [ "$ARG" = "-a" ]; then
    ACCOUNT_ID="${ARGS[$i + 1]}"
    shift 2
  elif [ "$ARG" = "-o" ]; then
    OAUTH_PREFIX="${ARGS[$i + 1]}"
    shift 2
  elif [ "$ARG" = "-c" ]; then
    CLIENT_CREDS="${ARGS[$i + 1]}"
    shift 2
  elif [ "$ARG" = "--help" ] || [ "$ARG" = "-?" ]; then
      shift
      if [ -n "$(LC_ALL=C type -t print_usage)" ]; then
        print_usage "$ARG"
      else
        print_options "$@"
      fi
      exit 0
  fi
done

if [ -z "$ACCOUNT_ID" ]; then
  printf "An Account ID must be specified.\n" 1>&2
  exit 1
fi
if [ -z "$OAUTH_PREFIX" ]; then
  printf "The OAuth prefix must be specified.\n" 1>&2
  exit 1
fi

# für die Skripte, die das benötigen
ARTIFACT_VERSION="active"

if [ -n "$1" ]; then
  ARTIFACT_ID=$1
  if [ -n "$2" ]; then
    FOLDER=$2
  else
    set_default_folder
    if [ -n "$3" ]; then
      ARTIFACT_VERSION=$3
    fi
  fi
elif [ -n "$(LC_ALL=C type -t print_usage)" ]; then
  print_usage
fi

TMN_URL="https://$ACCOUNT_ID-tmn.hci.eu2.hana.ondemand.com"
