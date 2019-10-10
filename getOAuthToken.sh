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
########################################################################################################################

TOKEN_TYPE=$1
TOKEN_ENDPOINT=$2
if [ "$TOKEN_TYPE" = 0 ]; then
  RESPONSE_TYPE=code
  PORT=56789
else
  RESPONSE_TYPE=token
  PORT=45678
fi

handle_response() {
  RESPONSE=$1
  OAUTH_TOKEN_SCPI=$(echo "${RESPONSE%???}" | jq -r .access_token)
  RESPONSE_CODE=$(printf "%s" "${RESPONSE: -3}")
  if [ "$RESPONSE_CODE" != "200" ]; then
    printf "Cannot get OAuth token: %s\n" "$RESPONSE_CODE" 1>&2
    exit 1
  fi
  AUTH="-H Authorization:Bearer $OAUTH_TOKEN_SCPI"
}


if [ "$CLIENT_CREDS" != "" ]; then
  handle_response $(curl -s -X POST -w "%{http_code}" -u"$CLIENT_CREDS" "$TOKEN_ENDPOINT/token?grant_type=client_credentials")
else
  CLIENT_ID=$3
  URL="$TOKEN_ENDPOINT/authorize?response_type=$RESPONSE_TYPE&client_id=$CLIENT_ID"
  if [ ! -f nweb/nweb ]; then
    gcc nweb/nweb23.c -o nweb/nweb
  fi
  rm nweb/nweb.log 2> /dev/null
  nweb/nweb $PORT nweb
  if command -v xdg-open > /dev/null
  then
    xdg-open "$URL"
  elif command -v gnome-open > /dev/null
  then
    gnome-open "$URL"
  elif command -v open > /dev/null
  then
    open "$URL"
  fi
  unset CODE
  while [ "$CODE" = "" ]; do
    CODE=$(sed -n 's/.*GET \/index.html\?code=\([^\ ]*\)\ .*/\1/p' nweb/nweb.log)
    sleep 1
  done
  killall nweb

  if [ "$TOKEN_TYPE" = 0 ]; then
    handle_response $(curl -s -X POST -w "%{http_code}" "$TOKEN_ENDPOINT/token?grant_type=authorization_code&code=$CODE&client_id=$CLIENT_ID")
  else
    OAUTH_TOKEN_BITBUCKET=$CODE
  fi
fi

save_config
