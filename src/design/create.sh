#!/bin/bash

########################################################################################################################
# Zippt das angegebene Artefakt und lädt es als Design-time Artifact in den Workspace der Cloud-Plattform.
# Wenn ein Argument angegeben wurde, aus dem angegebenen Verzeichnis,
# ansonsten wird der Verzeichnisname aus dem Artefaktnamen abgeleitet.
#
# Ein update auf einem existierenden I-Flow ist nicht möglich.
########################################################################################################################

print_usage() {
  printf "Usage: %s [options] <artifact_id> <package_id> [artifact_name, default=artifact_id] [folder, default=../iflow_<artifact_id>]\n" "$(basename "$0")" 1>&2
  print_options
  printf "Please specify the artifact and package to create it in.\n" 1>&2
  exit 1
}

. configure.sh

if [ -n "$2" ]; then
  PACKAGE_ID=$2
  if [ -n "$4" ]; then
    FOLDER=$4
  else
    set_default_folder
  fi
  if [ -n "$3" ]; then
    ARTIFACT_NAME=$3
  else
    artifactLine=$(perl -0777 -wpe 's/\r?\n //g' "$FOLDER/META-INF/MANIFEST.MF" | grep ^Bundle-Name)
    ARTIFACT_NAME=${artifactLine:13} && ARTIFACT_NAME=${ARTIFACT_NAME%${ARTIFACT_NAME##*[![:space:]]}}
  fi
else
  print_usage
fi

printf "Packaging and uploading artifact %s from folder %s\n" "$ARTIFACT_ID" "$FOLDER" 1>&2
CONTENT=$(pushd "$FOLDER" > /dev/null || exit 1; zip -r - "." -x "*.git*" -x "*/.*" -x ".*" -x "bitbucket-pipelines.yml" | base64; popd > /dev/null || exit 1)

REQUEST_DATA_FILE=$TMPDIR/$(uuidgen)
echo '{"Name":"'"$ARTIFACT_NAME"'","Id":"'"$ARTIFACT_ID"'","PackageId":"'"$PACKAGE_ID"'","ArtifactContent":"'"$CONTENT"'"}' > "$REQUEST_DATA_FILE"

execute_api_request_with_retry \
  "api/v1/IntegrationDesigntimeArtifacts" \
  POST \
  true \
  '-d @'"$REQUEST_DATA_FILE"
rm "$REQUEST_DATA_FILE"
if [ "$RESPONSE_CODE" = 201 ]; then
  printf "Artifact %s created in package %s.\n" "$ARTIFACT_ID" "$PACKAGE_ID" 1>&2
elif [ "$RESPONSE_CODE" = 500 ]; then
  RESPONSE="${RESPONSE%???}"
  printf "%s\n" "$(jq -r '.error.message.value' <<< "$RESPONSE")"
else
  printf "%s\n" "$RESPONSE"
fi