#!/bin/bash

########################################################################################################################
# Legt ein Repository an bzw. setzt weitere Git-Operationen um.
########################################################################################################################

BITBUCKET_URL="https://api.bitbucket.org/2.0"
BITBUCKET_OAUTH_KEY='***REMOVED***'
TEAM=***REMOVED***
PROJECT_KEY=***REMOVED***
REPO_NAME=$(basename "$FOLDER")
REPO_NAME_LOWER=$(echo "$REPO_NAME" | awk '{print tolower($0)}')

retry() {
  OK_RESPONSE=$2
  $1
  if [ "$RESPONSE_CODE" = 401 ]; then
    printf "Session expired, logging in...\n" 1>&2
    . getOAuthToken.sh bitbucket "https://bitbucket.org/site/oauth2" "$BITBUCKET_OAUTH_KEY"
    $1
    if [ "$RESPONSE_CODE" != "$OK_RESPONSE" ]; then
      printf "Error Response Code: %s\n" "$RESPONSE_CODE" 1>&2
    fi
  fi
}

create_repo() {
  internal_create_repo() {
    if [ ${#REPO_NAME_LOWER} -ge 62 ]; then
      REPO_NAME_LOWER=$(printf "%s" "$REPO_NAME_LOWER" | cut -c-62)
      printf "The slug (ID) of your repository will be trimmed to a length of %s\n" 62 1>&2
    fi

    RESPONSE=$(curl -s \
      -H "Content-Type: application/json" \
      -w "%{http_code}" \
      -d '{"scm": "git", "project": {"key": "'"$PROJECT_KEY"'"}, "name": "'"$REPO_NAME"'", "is_private": true, "fork_policy": "no_public_forks"}' \
      "$BITBUCKET_URL/repositories/$TEAM/$REPO_NAME_LOWER?access_token=$OAUTH_TOKEN_BITBUCKET")

    RESPONSE_CODE=$(printf "%s" "${RESPONSE: -3}")

   # klappt nicht, nur get und delete erlaubt
   # curl "https://$BITBUCKET_URL/repositories/$TEAM/$REPO_NAME/downloads/avatar.png -F avatar.png=@file.png -H 'Content-Type: multipart/form-data'"
   # alte Version: https://metacpan.org/pod/WebService::BitbucketServer::Core::V1#upload_project_avatar
  }
  retry internal_create_repo 200
}

enable_pipelines() {
  internal_enable_pipelines() {
    RESPONSE=$(curl -s -X PUT \
      -H "Content-Type: application/json" \
      -w "%{http_code}" \
      -d '{"enabled": true}' \
      "$BITBUCKET_URL/repositories/$TEAM/$REPO_NAME_LOWER/pipelines_config?access_token=$OAUTH_TOKEN_BITBUCKET")
    RESPONSE_CODE=$(printf "%s" "${RESPONSE: -3}")
  }
  retry internal_enable_pipelines 200
}

create_variable() {
  THE_REPO=$1
  KEY=$2
  VALUE=$3
  [ -n "$4" ] && SECURED=true || SECURED=false
  internal_create_variable() {
    RESPONSE=$(curl -s \
      -H "Content-Type: application/json" \
      -w "%{http_code}" \
      -d '{"key": "'"$KEY"'", "value": "'"$VALUE"'", "secured": '"$SECURED"'}' \
      "$BITBUCKET_URL/repositories/$TEAM/$THE_REPO/pipelines_config/variables/?access_token=$OAUTH_TOKEN_BITBUCKET")
    RESPONSE_CODE=$(printf "%s" "${RESPONSE: -3}")
  }
  retry internal_create_variable 201
}

rename_environment() {
  FROM=$1
  TO=$2
  RESPONSE=$(curl -s "$BITBUCKET_URL/repositories/$TEAM/$REPO_NAME_LOWER/environments/?access_token=$OAUTH_TOKEN_BITBUCKET")
  UUID=$(jq -r '.values[] | select(.name=="'"$FROM"'") | .uuid' <<< "$RESPONSE" | sed 's/{/%7b/' | sed 's/}/%7d/')

  RESPONSE=$(curl -s \
    -H "Content-Type: application/json" \
    -w "%{http_code}" \
    -d '{"change":{"name":"'"$TO"'"}}' \
    "$BITBUCKET_URL/repositories/$TEAM/$REPO_NAME_LOWER/environments/$UUID/changes/?access_token=$OAUTH_TOKEN_BITBUCKET")
  RESPONSE_CODE=$(printf "%s" "${RESPONSE: -3}")
  if [ "$RESPONSE_CODE" != 202 ]; then
    printf "Error Response Code: %s\n" "$RESPONSE_CODE" 1>&2
  fi
}

trigger_pipeline() {
  RESPONSE=$(curl -s \
    -H "Content-Type: application/json" \
    -d '{"target":{"type": "pipeline_ref_target", "ref_type": "branch", "ref_name": "develop",
      "selector": { "type": "custom", "pattern": "create-variables" }},
      "variables": [{
        "key": "Repo",
        "value": "'"$REPO_NAME_LOWER"'"}]}' \
      "$BITBUCKET_URL/repositories/$TEAM/***REMOVED***/pipelines/?access_token=$OAUTH_TOKEN_BITBUCKET")
}