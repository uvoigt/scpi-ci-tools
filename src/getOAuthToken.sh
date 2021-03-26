#!/bin/bash

########################################################################################################################
# Hier gibt es zwei Modi:
# 1. Das Skript wird in einer CI-Pipeline verwendet. Dann wird über den OAuth-Endpoint zuerst ein OAuth-Token
#    geholt, welches im Weiteren zur Authentisierung verwendet wird. Der OAuth-Client wird über CLIENT_CREDS
#    an der Kommandozeile mitgegeben.
# 2. Der lokale Benutzer ruft das Skript auf. Wenn noch kein OAuth-Token existiert, wird ein Auth-Code unter Verwendung
#    des OAuth-Clients für Authorization-Code geholt. Dafür wird kurzzeitig lokal ein kleiner Web-Server gestartet und
#    der übermittelte Code aus dem Log gelesen. Mit diesem Code wird dann das OAuth-Token geholt.
#
# Parameter des Skriptes
# <0 für SCPI, 1 für BITBUCKET>
# <TOKEN Endpoint>
# <Client ID>
# <Variablenname> für das ermittelte Token, wenn gesetzt, wird das Speichern des Tokens unterbunden, default leer
########################################################################################################################

# shellcheck disable=SC2034
debug=false
TOKEN_TYPE=$1
TOKEN_ENDPOINT=$2
__resultvar=$4
if [ "$TOKEN_TYPE" = 0 ]; then
  RESPONSE_TYPE=code
  PORT=56789
else
  RESPONSE_TYPE=token
  PORT=45678
fi

tokenOk=
handle_response() {
  local token
  token=$(echo "${1%???}" | jq -r .access_token)
  refreshToken=$(echo "${1%???}" | jq -r .refresh_token)
  if [ -n "$__resultvar" ]; then
    eval "$__resultvar='$token'"
  else
    OAUTH_TOKEN_SCPI=$token
    OAUTH_REFRESH_TOKEN_SCPI=$refreshToken
    [ $debug = true ] && printf "Response access token: %s\n" "$OAUTH_TOKEN_SCPI" 1>&2
    [ $debug = true ] && printf "Response refresh token: %s\n" "$OAUTH_REFRESH_TOKEN_SCPI" 1>&2
  fi
  RESPONSE_CODE=$(printf "%s" "${1: -3}")
  if [ "$RESPONSE_CODE" != 200 ]; then
    printf "Cannot get OAuth token: %s\n" "${1%???}" 1>&2
    if [ -n "$2" ]; then
      tokenOk="no"
      return
    else
      exit 1
    fi
  fi
  tokenOk=
  if [ "$TOKEN_TYPE" = 0 ]; then
    AUTH="-HAuthorization:Bearer $token"
  else
    OAUTH_TOKEN_BITBUCKET=$token
  fi
}

get_auth_code() {
  URL="$TOKEN_ENDPOINT/authorize?response_type=$RESPONSE_TYPE&client_id=$CLIENT_ID"
  if [ ! -f "$CONFIG_DIR/nweb" ]; then
    gcc "$BASE_DIR/../../nweb/nweb23.c" -o "$CONFIG_DIR/nweb"
    cp "$BASE_DIR/../../nweb/index.html" "$CONFIG_DIR/"
  fi
  rm "$CONFIG_DIR/nweb.log" 2> /dev/null
  "$CONFIG_DIR/nweb" $PORT "$CONFIG_DIR"
  if command -v xdg-open > /dev/null; then
    xdg-open "$URL"
  elif command -v gnome-open > /dev/null; then
    gnome-open "$URL"
  elif command -v x-www-browser > /dev/null; then
    x-www-browser "$URL"
  elif command -v cygstart > /dev/null; then
    cygstart "$URL"
  elif command -v open > /dev/null; then
    open "$URL"
  fi
  unset CODE
  while [ "$CODE" = "" ]; do
    [ "$(uname)" = Darwin ] || disableExt='--posix'
    CODE=$(sed $disableExt -n 's/.*GET \/index.html\?code=\([^\ ]*\)\ .*/\1/p' "$CONFIG_DIR/nweb.log")
    sleep 1
  done
  killall nweb
}

if [ -n "$CLIENT_CREDS" ]; then
  if [ "$TOKEN_TYPE" = 0 ]; then
    handle_response "$(curl -s -X POST -w '%{response_code}' -u "$CLIENT_CREDS" "$TOKEN_ENDPOINT/token?grant_type=client_credentials")"
  else
    handle_response "$(curl -s -w '%{response_code}' -u "$CLIENT_CREDS" "$TOKEN_ENDPOINT/access_token" -d grant_type=client_credentials)"
  fi
else
  CLIENT_ID=$3
  if [ "$TOKEN_TYPE" = 0 ]; then
    [ $debug = true ] && printf "Attempt to refresh access token\n" 1>&2
    handle_response "$(curl -s -w '%{http_code}' "$TOKEN_ENDPOINT/token" -d "grant_type=refresh_token&refresh_token=$OAUTH_REFRESH_TOKEN_SCPI&client_id=$CLIENT_ID")" 'check'
    [ $debug = true ] && printf "Result from handle_response: %s\n" "$tokenOk" 1>&2
    if [ "$tokenOk" = "no" ]; then
      get_auth_code
      handle_response "$(curl -s -w '%{http_code}' "$TOKEN_ENDPOINT/token" -d "grant_type=authorization_code&code=$CODE&client_id=$CLIENT_ID")"
    fi
  else
    get_auth_code
    OAUTH_TOKEN_BITBUCKET=$CODE
  fi
fi

if [ -z "$__resultvar" ]; then
  save_config
fi
