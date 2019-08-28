#!/bin/sh

########################################################################################################################
# Zippt das angegebene Artefakt und lädt es in die Cloud-Plattform.
# Wenn ein Argument angegeben wurde, in das angegebene Verzeichnis,
# ansonsten wird der Verzeichnisname aus dem Artefaktnamen abgeleitet.
########################################################################################################################

TODO nicht fertig
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
  echo "Usage: $0 <artifact_id> [target_folder, default=artifact_id] [version, default=active]"
  echo "Please specifiy the artifact to clone."
  exit 1
fi

. ./getSessionToken.sh

ZIP_FILE_NAME="$ARTIFACT_ID_$ARTIFACT_VERSION.zip"

echo "Downloading artifact $ARTIFACT_ID to folder $FOLDER"
curl -sL \
     -H X-CSRF-Token:$XCSRFTOKEN \
     -u $USER:$PASSWORD \
     --output "$ZIP_FILE_NAME" \
     "$TENANT_HOST/IntegrationDesigntimeArtifacts(Id='$ARTIFACT_ID',Version='$ARTIFACT_VERSION')/"'$value'
mkdir $FOLDER 2> /dev/null
unzip -d $FOLDER $ZIP_FILE_NAME
rm $ZIP_FILE_NAME
