#!/bin/sh

########################################################################################################################
# Löscht das angegebene Design-time Artefact aus dem  Workspace der Cloud-Plattform.
#
# Das ggf. existierende lokale Verzeichnis bleibt unberührt.
########################################################################################################################

print_usage() {
  printf "Usage: %s [options] <artifact_id> [version, default=active]\n" "$(basename "$0")" 1>&2
  print_options
  printf "Please specifiy the artifact to delete.\n" 1>&2
  exit 1
}

. configure.sh

[ -n "$FOLDER" ] && ARTIFACT_VERSION="$FOLDER"

execute_api_request_with_retry \
  "api/v1/IntegrationDesigntimeArtifacts(Id='$ARTIFACT_ID',Version='$ARTIFACT_VERSION')" \
  DELETE \
  true
if [ "$RESPONSE_CODE" = 200 ]; then
  printf "Artifact %s deleted.\n" "$ARTIFACT_ID" 1>&2
fi