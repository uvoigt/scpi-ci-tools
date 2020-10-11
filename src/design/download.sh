#!/bin/bash

########################################################################################################################
# Lädt das angegebene Design-time Artefakt herunter und extrahiert es.
# Wenn ein Argument angegeben wurde, in das angegebene Verzeichnis,
# ansonsten wird der Verzeichnisname aus dem Artefaktnamen abgeleitet.
########################################################################################################################

# shellcheck disable=SC2034,SC2140
handle_option() {
  if [ "$1" = "-p" ] || [ "$1" = "-ps" ]; then
    PUSH_REPO="true"
    [ "$1" = "-ps" ] && SSH_URL=true
    SHIFT_COUNT=1
  fi
  if [ "$1" = "-f" ]; then
    OVERWRITE="true"
    SHIFT_COUNT=1
  fi
}

print_usage() {
  printf "Usage: %s [options] <artifact_id> [target_folder, default=../iflow_<artifact_id>] [version, default=active]\n" "$(basename "$0")" 1>&2
  print_options "-p pushes the downloaded artifact to the Git repo (newly created if it does not yet exist)" \
    "-ps uses SSH URL instead HTTP URL when creating the Git repo" \
    "-f doesn't prompt with overwrite warning if the artifact already exists locally"
  printf "Please specify the artifact to download.\n" 1>&2
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
  if [ -n "$OVERWRITE" ]; then
    unzip -o -d "$FOLDER" "$ZIP_FILE_NAME"
  else
    unzip -d "$FOLDER" "$ZIP_FILE_NAME"
  fi

  find "$FOLDER" -type f ! -path '*.idea/*' \( -iname \*.edmx -o -iname \*.mmap -o -iname \*.xsd -o -iname \*.xml \) \
    -exec sh -c 'i="$1"; echo Formatting: "$i"; xmllint --format "$i" --output "$i"' _ {} \;

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
    configure_branching_settings "$REPO_SLUG"
    while [ "$NUM_VARIABLES" != 3 ]; do
      sleep 2
      get_number_of_variables "$REPO_SLUG"
    done
  fi
  pushd "$FOLDER" > /dev/null || exit 1
  if [ ! -d .git  ]; then
    [ -n "$SSH_URL" ] && repoUrl="git@bitbucket.org:$TEAM/$REPO_SLUG.git" || repoUrl="https://bitbucket.org/$TEAM/$REPO_SLUG.git"
    git init
    git remote add origin "$repoUrl"
    git checkout -b develop
    echo ".DS_Store" > .gitignore
    echo "/.idea" >> .gitignore
    echo "*.iml" >> .gitignore
    cp "$BASE_DIR/../resources/bitbucket-pipelines.yml" .
    cp -n "$BASE_DIR/../resources/README.md" .
#    mkdir src/main/resources/script 2> /dev/null
#    cp "$BASE_DIR/../resources/tools.groovy" src/main/resources/script/
#    cp "$BASE_DIR/../resources/mappingFunctions.groovy" src/main/resources/script/
    # shellcheck disable=SC2207
    artifactLine=($(perl -0777 -wpe 's/\r?\n //g' META-INF/MANIFEST.MF | grep ^Bundle-SymbolicName ))
    ARTIFACT_NAME=$(echo "${artifactLine[1]}" | tr -d ';')
    # the artifact name should not contain a slash!
    if [ "$(uname)" = Darwin ]; then
      sed -i '' "s/{ARTIFACT_NAME}/$ARTIFACT_NAME/" README.md
    else
      sed -i "s/{ARTIFACT_NAME}/$ARTIFACT_NAME/" README.md
    fi
    git add .
    git commit -m "initial";
    git push --set-upstream origin develop
  else
    git checkout develop
    git pull
    git add .
    git commit -a
    git push
  fi
  popd > /dev/null || exit 1
fi