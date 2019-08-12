#!/bin/sh

########################################################################################################################
# Lädt das angegebene Artefakt herunter und extrahiert es.
# Wenn ein Argument angegeben wurde, in das angegebene Verzeichnis,
# ansonsten wird der Verzeichnisname aus dem Artefaktnamen abgeleitet.
########################################################################################################################

. ./getSessionToken.sh

ARTIFACT_ID="Submit_Order"
ARTIFACT_VERSION="active" #1.0.0

ZIP_FILE_NAME="$ARTIFACT_ID_$ARTIFACT_VERSION.zip"

if [ "$1" != "" ]; then
  FOLDER=$1
else
  FOLDER="${ARTIFACT_ID}"
fi

echo "Downloading artifact $ARTIFACT_ID to folder $FOLDER"
curl -sL \
     -H X-CSRF-Token:$XCSRFTOKEN \
     -u $USER:$PASSWORD \
     --output "$ZIP_FILE_NAME" \
     "$TENANT_HOST/IntegrationDesigntimeArtifacts(Id='$ARTIFACT_ID',Version='$ARTIFACT_VERSION')/"'$value'
mkdir $FOLDER 2> /dev/null
unzip -d $FOLDER $ZIP_FILE_NAME
rm $ZIP_FILE_NAME
