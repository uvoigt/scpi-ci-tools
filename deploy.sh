#!/bin/sh

########################################################################################################################
# Deployt das angegebene Artefakt.
########################################################################################################################

. ./configure.sh

if [ "$1" != "" ]; then
  [ "$2" != "" ] && version="$2" || version='active'
  execute_api_request_with_retry \
    "api/v1/DeployIntegrationDesigntimeArtifact?Id='$1'&Version='$version'" \
    POST \
    true
else
  printf "Please specifiy the artifact to deploy.\n" 1>&2
  exit 1
fi