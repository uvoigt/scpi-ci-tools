#!/bin/sh

########################################################################################################################
# Undeployt das angegebene Artefakt aus der Runtime.
########################################################################################################################

print_usage() {
  printf "Usage: %s [options] <artifact_id>\n" "$(basename "$0")" 1>&2
  print_options
  printf "Please specifiy the artifact to undeploy.\n" 1>&2
  exit 1
}

. configure.sh

execute_api_request_with_retry \
  "api/v1/IntegrationRuntimeArtifacts(Id='$ARTIFACT_ID')" \
  DELETE \
  true

if [ "$RESPONSE_CODE" = 202 ]; then
  printf "Artifact %s triggered for undeployment.\n" "$ARTIFACT_ID" 1>&2
fi