#!/bin/bash

########################################################################################################################
# Legt ein Repository an bzw. setzt weitere Git-Operationen um.
########################################################################################################################

BITBUCKET_URL="https://api.bitbucket.org/2.0"
TEAM=***REMOVED***
PROJECT_KEY=***REMOVED***
REPO_NAME=$(basename "$FOLDER")
REPO_NAME_LOWER=$(echo "$REPO_NAME" | awk '{print tolower($0)}')

create_repo() {
  RESPONSE=$(curl -s \
    -H "Content-Type: application/json" \
    -w "%{http_code}" \
    -d '{"scm": "git", "project": {"key": "'"$PROJECT_KEY"'"}, "name": "'"$REPO_NAME"'", "is_private": true, "fork_policy": "no_public_forks"}' \
    "$BITBUCKET_URL/repositories/$TEAM/$REPO_NAME_LOWER?access_token=$OAUTH_TOKEN_BITBUCKET")

  RESPONSE_CODE=$(printf "%s" "${RESPONSE: -3}")
  if [ "$RESPONSE_CODE" != 200 ]; then
    printf "Error Response Code: %s\n" "$RESPONSE_CODE" 1>&2
  fi

 # klappt nicht, nur get und delete erlaubt
 # curl "https://$BITBUCKET_URL/repositories/$TEAM/$REPO_NAME/downloads/avatar.png -F avatar.png=@file.png -H 'Content-Type: multipart/form-data'"
 # alte Version: https://metacpan.org/pod/WebService::BitbucketServer::Core::V1#upload_project_avatar
}

create_repo_with_retry() {
  create_repo
  if [[ "$RESPONSE_CODE" = 40* ]]; then
    . getOAuthToken.sh bitbucket "https://bitbucket.org/site/oauth2" ***REMOVED***
    create_repo
  fi
}