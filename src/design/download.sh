#!/bin/bash

########################################################################################################################
# Lädt das angegebene Design-time Artefakt herunter und extrahiert es.
# Wenn ein Argument angegeben wurde, in das angegebene Verzeichnis,
# ansonsten wird der Verzeichnisname aus dem Artefaktnamen abgeleitet.
########################################################################################################################

# shellcheck disable=SC2034,SC2140
handle_option() {
  if [ "$1" = "-p" ]; then
    PUSH_REPO="true"
    SHIFT_COUNT=1
  fi
}

print_usage() {
  printf "Usage: %s [options] <artifact_id> [target_folder, default=../iflow_<artifact_id>] [version, default=active]\n" "$(basename "$0")" 1>&2
  print_options "-p pushes the downloaded artifact to the Git repo (newly created if it does not yet exist)"
  printf "Please specifiy the artifact to download.\n" 1>&2
  exit 1
}

. configure.sh

ZIP_FILE_NAME="$ARTIFACT_ID"_"$ARTIFACT_VERSION.zip"

printf "Downloading artifact %s to folder %s\n" "$ARTIFACT_ID" "$FOLDER" 1>&2
execute_api_request_with_retry \
  "api/v1/IntegrationDesigntimeArtifacts(Id='$ARTIFACT_ID',Version='$ARTIFACT_VERSION')/%24value" \
  GET \
  false \
  "-o$ZIP_FILE_NAME"
if [ "$RESPONSE_CODE" = 200 ]; then
  mkdir "$FOLDER" 2> /dev/null
  unzip -d "$FOLDER" "$ZIP_FILE_NAME"
fi
rm "$ZIP_FILE_NAME"

# Lade externalized parameter configurations
execute_api_request_with_retry \
  "api/v1/IntegrationDesigntimeArtifacts(Id='$ARTIFACT_ID',Version='$ARTIFACT_VERSION')/Configurations"
if [ "$RESPONSE_CODE" = 200 ]; then
  COUNT=$(jq -r '.d.results | length' <<< "$RESPONSE")
  if [ "$COUNT" -gt 0 ]; then
    # fancy syntax mit named capturing group, hier werden Leerzeichen escaped
    values=$(jq -r '.d.results[] | "\(.ParameterKey | gsub("(?<a>[ ])"; "\\\(.a)"))=\(.ParameterValue | gsub("(?<a>[ ])"; "\\\(.a)"))"' <<< "$RESPONSE" | sort)
    echo "$values" > "$FOLDER/src/main/resources/parameters.prop"
  fi
fi

if [ -n "$PUSH_REPO" ]; then
  . bitbucket.sh
  if [ ! -d "$FOLDER/.git"  ]; then
    printf "Waiting for readiness of the repository...\n" 1>&2
    create_repo
    enable_pipelines
    trigger_pipeline
    rename_environment Test Development
    rename_environment Staging Test
    while [ "$NUM_VARIABLES" != 3 ]; do
      sleep 2
      get_number_of_variables "$REPO_NAME_LOWER"
    done
  fi
  pushd "$FOLDER" > /dev/null || exit 1
  if [ ! -d .git  ]; then
    git init
    git remote add origin "https://bitbucket.org/$TEAM/$REPO_NAME_LOWER.git"
    git checkout -b develop
    echo ".DS_Store" > .gitignore
    echo "/.idea" >> .gitignore
    echo "*.iml" >> .gitignore
    cp "$BASE_DIR/../resources/bitbucket-pipelines.yml" .
    git add .
    git commit -m "initial";
    git push --set-upstream origin develop
  else
    git checkout develop
    git pull
    git commit -a
    git push
  fi
  popd > /dev/null || exit 1
fi