#!/bin/sh

########################################################################################################################
# Deployt das angegebene Design-Time-Artefakt, welches sich im Design-Time-Workspace befinden muss.
########################################################################################################################

print_usage() {
  printf "Usage: %s [options] <artifact_id> [version, default=active]\n" "$(basename "$0")" 1>&2
  print_options
  printf "Please specifiy the artifact to deploy.\n" 1>&2
  exit 1
}

. configure.sh

[ "$2" != "" ] && version="$2" || version='active'
execute_api_request_with_retry \
  "api/v1/DeployIntegrationDesigntimeArtifact?Id='$1'&Version='$version'" \
  POST \
  true
if [ "$RESPONSE_CODE" = 202 ]; then
  printf "Artifact %s triggered for deployment.\n" "$ARTIFACT_ID" 1>&2
fi
