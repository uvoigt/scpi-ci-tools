#!/bin/bash

########################################################################################################################
# Dient dem upload des angegebenen Design-time Artefacts in den  Workspace der Cloud-Plattform.
#
# Da ein reiner upload (edit) vom API nicht unterstützt wird, löscht dieses Skript zuerst das Artefakt (delete)
# und legt es dann erneut an (create).
########################################################################################################################

print_usage() {
  printf "Usage: %s [options] <artifact_id>\n" "$(basename "$0")" 1>&2
  print_options
  printf "Please specifiy the artifact to upload.\n" 1>&2
  exit 1
}

. configure.sh

execute_api_request_with_retry "api/v1/IntegrationDesigntimeArtifacts(Id='$ARTIFACT_ID',Version='active')"
if [ "$RESPONSE_CODE" = 200 ]; then
  # shellcheck disable=SC2046
  read -r PACKAGE_ID ARTIFACT_NAME <<< $(jq -r '.d.PackageId, .d.Name' <<< "$RESPONSE")
  bash "$BASE_DIR/delete.sh" "$ARTIFACT_ID" "active"
  bash "$BASE_DIR/create.sh" "$ARTIFACT_ID" "$PACKAGE_ID" "$ARTIFACT_NAME"
elif [ "$RESPONSE_CODE" = 404 ]; then
  printf "Artifact %s is not available, please us create instead.\n" "$ARTIFACT_ID" 1>&2
fi