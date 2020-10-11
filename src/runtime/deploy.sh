#!/bin/bash

########################################################################################################################
# Zippt das angegebene Artefakt und deployt es in die Cloud-Plattform.
# Wenn ein Argument angegeben wurde, aus dem angegebenen Verzeichnis,
# ansonsten wird der Verzeichnisname aus dem Artefaktnamen abgeleitet.
#
########################################################################################################################

print_usage() {
  printf "Usage: %s [options] <artifact_id> [target_folder, default=../iflow_<artifact_id>]\n" "$(basename "$0")" 1>&2
  print_options
  printf "Please specify the artifact to deploy.\n" 1>&2
  exit 1
}

. configure.sh

ZIP_FILE_NAME=$(uuidgen)
ZIP_FILE_NAME=${ZIP_FILE_NAME:0:8}.zip
ZIP_FILE_PATH=$TMPDIR/$ZIP_FILE_NAME

pushd "$FOLDER" > /dev/null || exit 1
zip -r "$ZIP_FILE_PATH" "." -x "*.git*" -x "*/.*" -x ".*" -x "bitbucket-pipelines.yml"
popd > /dev/null || exit 1

execute_api_request_with_retry \
  "api/v1/IntegrationRuntimeArtifacts" \
  POST \
  true \
  '--data-binary @'"$ZIP_FILE_PATH"

rm "$ZIP_FILE_PATH"

if [ "$RESPONSE_CODE" = 202 ]; then
  printf "Artifact %s triggered for deployment.\n" "$ARTIFACT_ID" 1>&2
fi