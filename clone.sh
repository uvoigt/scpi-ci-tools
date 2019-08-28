#!/bin/sh

########################################################################################################################
# Lädt das angegebene Artefakt herunter und extrahiert es.
# Wenn ein Argument angegeben wurde, in das angegebene Verzeichnis,
# ansonsten wird der Verzeichnisname aus dem Artefaktnamen abgeleitet.
########################################################################################################################

. ./configure.sh

ARTIFACT_VERSION="active" #1.0.0

if [ "$1" != "" ]; then
  ARTIFACT_ID=$1
  if [ "$2" != "" ]; then
    FOLDER=$2
  else
    FOLDER="${ARTIFACT_ID}"
    if [ "$3" != "" ]; then
      ARTIFACT_VERSION=$3
    fi
  fi
else
  printf "Usage: %s [options] <artifact_id> [target_folder, default=artifact_id] [version, default=active]\n" "$0" 1>&2
  print_options
  printf "Please specifiy the artifact to clone.\n" 1>&2
  exit 1
fi

. ./getSessionToken.sh

ZIP_FILE_NAME="$ARTIFACT_ID"_"$ARTIFACT_VERSION.zip"

printf "Downloading artifact %s from account %s to folder %s\n" "$ARTIFACT_ID" "$ACCOUNT_ID" "$FOLDER" 1>&2
RESPONSE=$(curl -sL \
     -H X-CSRF-Token:$XCSRFTOKEN \
     -u $USER:$PASSWORD \
     -o "$ZIP_FILE_NAME" \
     -w %{http_code} \
     "$TENANT_HOST/IntegrationDesigntimeArtifacts(Id='$ARTIFACT_ID',Version='$ARTIFACT_VERSION')/"'$value')
if [ $RESPONSE == "200" ]; then
  mkdir "$FOLDER" 2> /dev/null
  unzip -d "$FOLDER" "$ZIP_FILE_NAME"
else
  printf "Error downloading %s: %s\n" "$ARTIFACT_ID" "$RESPONSE" 1>&2
fi
  rm "$ZIP_FILE_NAME"
