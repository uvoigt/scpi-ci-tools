#!/bin/bash

########################################################################################################################
# Legt ein Repository an bzw. setzt weitere Git-Operationen um.
########################################################################################################################

BITBUCKET_URL="https://api.bitbucket.org/2.0"
BITBUCKET_OAUTH_KEY='***REMOVED***'
TEAM=***REMOVED***
PROJECT_KEY=FSCPI
REPO_NAME=$(basename "$FOLDER")
REPO_SLUG=$(echo "$REPO_NAME" | awk '{print tolower($0)}')

retry() {
  OK_RESPONSE=$2
  $1
  if [ "$RESPONSE_CODE" = 401 ]; then
    printf "Session expired, logging in...\n" 1>&2
    . getOAuthToken.sh bitbucket "https://bitbucket.org/site/oauth2" "$BITBUCKET_OAUTH_KEY"
    $1
  fi
  if [ "$RESPONSE_CODE" != "$OK_RESPONSE" ]; then
    printf "Error Response Code: %s\n" "$RESPONSE_CODE" 1>&2
  fi
}

create_repo() {
  internal_create_repo() {
    if [ ${#REPO_SLUG} -ge 62 ]; then
      REPO_SLUG=$(printf "%s" "$REPO_SLUG" | cut -c-62)
      printf "The slug (ID) of your repository will be trimmed to a length of %s\n" 62 1>&2
    fi

    RESPONSE=$(curl -s \
      -H "Content-Type: application/json" \
      -w "%{http_code}" \
      -d '{"scm": "git", "project": {"key": "'"$PROJECT_KEY"'"}, "name": "'"$REPO_NAME"'", "is_private": true, "fork_policy": "no_public_forks"}' \
      "$BITBUCKET_URL/repositories/$TEAM/$REPO_SLUG?access_token=$OAUTH_TOKEN_BITBUCKET")

    RESPONSE_CODE=$(printf "%s" "${RESPONSE: -3}")

   # klappt nicht, nur get und delete erlaubt
   # curl "https://$BITBUCKET_URL/repositories/$TEAM/$REPO_NAME/downloads/avatar.png -F avatar.png=@file.png -H 'Content-Type: multipart/form-data'"
   # alte Version: https://metacpan.org/pod/WebService::BitbucketServer::Core::V1#upload_project_avatar
  }
  retry internal_create_repo 200
}

# Erstellt einen Pull-Request für das Repository/Branch und merged ihn danach
# param: repo
# param: source
# param: test
merge_iflow_repositories() {
  local SOURCE=$1
  local DEST=$2
  SINGLE_SLUG=$3
  internal_merge_repo() {
    if [ -n "$SINGLE_SLUG" ]; then
      slugs=("$SINGLE_SLUG")
    else
      get_iflow_slugs
    fi
    for slug in "${slugs[@]}"; do
      RESPONSE=$(curl -s \
        -H "Content-Type: application/json" \
        -w "%{http_code}" \
        -d '{"title": "Pipeline: move from '"$SOURCE"' to '"$DEST"'", "source": {"branch": { "name": "'"$SOURCE"'"}}, "destination": {"branch": {"name": "'"$DEST"'"}}}' \
        "$BITBUCKET_URL/repositories/$TEAM/$slug/pullrequests?access_token=$OAUTH_TOKEN_BITBUCKET")

      RESPONSE_CODE=$(printf "%s" "${RESPONSE: -3}")
      if [ "$RESPONSE_CODE" = 201 ]; then
        RESPONSE="${RESPONSE%???}"
        local prId
        prId=$(jq -r '.id' <<< "$RESPONSE")
        # nun mergen
        RESPONSE=$(curl -s \
          -H "Content-Type: application/json" \
          -w "%{http_code}" \
          -d '{"message": "Pipeline: move from '"$SOURCE"' to '"$DEST"'", "merge_strategy": "fast_forward"}' \
          "$BITBUCKET_URL/repositories/$TEAM/$slug/pullrequests/$prId/merge?access_token=$OAUTH_TOKEN_BITBUCKET")
        RESPONSE_CODE=$(printf "%s" "${RESPONSE: -3}")
        if [ "$RESPONSE_CODE" = 200 ]; then
          printf "Merged pull request %s %s\n" "$prId" "$slug" 1>&2
        else
          RESPONSE="${RESPONSE%???}"
          printf "Error when merging %s of %s: %s\n" "$prId" "$slug" "$RESPONSE" 1>&2
        fi
      elif [ "$RESPONSE_CODE" = 400 ]; then
        RESPONSE="${RESPONSE%???}"
        msg=$(jq -r '.error.message' <<< "$RESPONSE")
        if [ "$msg" != "There are no changes to be pulled" ]; then
          printf "Error creating pull request for %s: %s\n" "$slug" "$RESPONSE" 1>&2
        fi
        RESPONSE_CODE=200
      fi
    done
  }
  retry internal_merge_repo 200
}

enable_pipelines() {
  internal_enable_pipelines() {
    RESPONSE=$(curl -s -X PUT \
      -H "Content-Type: application/json" \
      -w "%{http_code}" \
      -d '{"enabled": true}' \
      "$BITBUCKET_URL/repositories/$TEAM/$REPO_SLUG/pipelines_config?access_token=$OAUTH_TOKEN_BITBUCKET")
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

update_variable() {
  THE_REPO=$1
  KEY=$2
  VALUE=$3
  [ -n "$4" ] && SECURED=true || SECURED=false
  internal_update_variable() {
    # zuerst die uuid
    RESPONSE=$(curl -s \
      -w "%{http_code}" \
      "$BITBUCKET_URL/repositories/$TEAM/$THE_REPO/pipelines_config/variables/?access_token=$OAUTH_TOKEN_BITBUCKET")
    RESPONSE_CODE=$(printf "%s" "${RESPONSE: -3}")
    if [ "$RESPONSE_CODE" = 200 ]; then
      RESPONSE="${RESPONSE%???}"
      UUID=$(jq -r '.values[] | select(.key=="'"$KEY"'") | .uuid' <<< "$RESPONSE" | sed 's/{/%7b/' | sed 's/}/%7d/')
      RESPONSE=$(curl -s -X PUT \
        -H "Content-Type: application/json" \
        -w "%{http_code}" \
        -d '{"key": "'"$KEY"'", "value": "'"$VALUE"'", "secured": '"$SECURED"'}' \
        "$BITBUCKET_URL/repositories/$TEAM/$THE_REPO/pipelines_config/variables/$UUID?access_token=$OAUTH_TOKEN_BITBUCKET")
      RESPONSE_CODE=$(printf "%s" "${RESPONSE: -3}")
    fi
  }
  retry internal_update_variable 200
}

get_number_of_variables() {
  THE_REPO=$1
  internal_get_number_of_variables() {
    RESPONSE=$(curl -s \
      -w "%{http_code}" \
      "$BITBUCKET_URL/repositories/$TEAM/$THE_REPO/pipelines_config/variables/?access_token=$OAUTH_TOKEN_BITBUCKET")
    RESPONSE_CODE=$(printf "%s" "${RESPONSE: -3}")
  }
  retry internal_get_number_of_variables 200
  RESPONSE="${RESPONSE%???}"
  # shellcheck disable=SC2034
  NUM_VARIABLES=$(jq -r '.values | length' <<< "$RESPONSE")
}

# default merge strategy: fast-forward (gibt im Moment kein API)
# branch permissions auf staging und release
configure_branching_settings() {
  THE_REPO=$1
  internal_configure_branching_settings() {
    create_restriction() {
      RESPONSE=$(curl -s \
        -H "Content-Type: application/json" \
        -w "%{http_code}" \
        -d "$1" \
        "$BITBUCKET_URL/repositories/$TEAM/$THE_REPO/branch-restrictions?access_token=$OAUTH_TOKEN_BITBUCKET")
      RESPONSE_CODE=$(printf "%s" "${RESPONSE: -3}")
      [ "$RESPONSE_CODE" = 409 ] && RESPONSE_CODE=201 # restriction gibt es bereits
    }
    create_restriction '{"kind": "push", "branch_match_kind": "glob", "pattern": "staging"}'
    create_restriction '{"kind": "delete", "branch_match_kind": "glob", "pattern": "staging"}'
    create_restriction '{"kind": "force", "branch_match_kind": "glob", "pattern": "staging"}'
    create_restriction '{"kind": "require_approvals_to_merge", "branch_match_kind": "glob", "pattern": "staging", "value": 1}'
    create_restriction '{"kind": "require_passing_builds_to_merge", "branch_match_kind": "glob", "pattern": "staging", "value": 1}'
    create_restriction '{"kind": "require_tasks_to_be_completed", "branch_match_kind": "glob", "pattern": "staging"}'

    create_restriction '{"kind": "push", "branch_match_kind": "glob", "pattern": "integration"}'
    create_restriction '{"kind": "delete", "branch_match_kind": "glob", "pattern": "integration"}'
    create_restriction '{"kind": "force", "branch_match_kind": "glob", "pattern": "integration"}'
    create_restriction '{"kind": "require_approvals_to_merge", "branch_match_kind": "glob", "pattern": "integration", "value": 1}'
    create_restriction '{"kind": "require_passing_builds_to_merge", "branch_match_kind": "glob", "pattern": "integration", "value": 1}'
    create_restriction '{"kind": "require_tasks_to_be_completed", "branch_match_kind": "glob", "pattern": "integration"}'

    create_restriction '{"kind": "push", "branch_match_kind": "branching_model", "branch_type": "release"}'
    create_restriction '{"kind": "delete", "branch_match_kind": "branching_model", "branch_type": "release"}'
    create_restriction '{"kind": "force", "branch_match_kind": "branching_model", "branch_type": "release"}'
    create_restriction '{"kind": "require_approvals_to_merge", "branch_match_kind": "branching_model", "branch_type": "release", "value": 1}'
    create_restriction '{"kind": "require_passing_builds_to_merge", "branch_match_kind": "branching_model", "branch_type": "release", "value": 1}'
    create_restriction '{"kind": "require_tasks_to_be_completed", "branch_match_kind": "branching_model", "branch_type": "release"}'
  }
  retry internal_configure_branching_settings 201
}

get_iflow_slugs() {
    RESPONSE=$(curl -s \
      -w "%{http_code}" \
      "$BITBUCKET_URL/repositories/$TEAM?q=full_name+%7E+%22iflow_%22&access_token=$OAUTH_TOKEN_BITBUCKET")
    slugs=()
    while true; do
      RESPONSE_CODE=$(printf "%s" "${RESPONSE: -3}")
      if [ "$RESPONSE_CODE" != 200 ]; then
        if [ "$RESPONSE_CODE" != 401 ]; then
          printf "Error Response Code: %s\n" "$RESPONSE_CODE" 1>&2
        fi
        break
      fi
      RESPONSE="${RESPONSE%???}"
      # shellcheck disable=SC2207
      slugs+=($(jq -r '.values[] | .slug' <<< "$RESPONSE"))
      next=$(jq -r '.next' <<< "$RESPONSE")
      if [ "$next" = null ]; then
        break
      fi
      RESPONSE=$(curl -s -w "%{http_code}" "$next")
    done
}

update_iflow_repositories() {
  SINGLE_SLUG=$1
  internal_update_iflow_repositories() {
    # im Moment liegen die alle im Verzeichnis src/resources
    filesToUpdate=(bitbucket-pipelines.yml src/main/resources/script/tools.groovy src/main/resources/script/mappingFunctions.groovy)
    if [ -n "$SINGLE_SLUG" ]; then
      slugs=("$SINGLE_SLUG")
    else
      get_iflow_slugs
    fi
    for slug in "${slugs[@]}"; do
      printf "\n" 1>&2
      # variable aktualisieren!
      update_variable "$slug" DEPLOY_CONFIG "$DEPLOY_CONFIG" true
      if [ "$RESPONSE_CODE" = 200 ]; then
        printf "Variable DEPLOY_CONFIG has been updated in %s\n" "$slug" 1>&2
      fi
      # branch settings
      configure_branching_settings "$slug"
      printf "Configured branch settings of %s\n" "$slug" 1>&2
      for remotePath in "${filesToUpdate[@]}"; do
        fileName=$(basename "$remotePath")
        localPath="$BASE_DIR/resources/$fileName"
        if [ ! -f "$localPath" ]; then
            continue
        fi
        tmpFile=$TMPDIR/_remote
        RESPONSE=$(curl -s \
          -w "%{http_code}" \
          -o "$tmpFile" \
          "$BITBUCKET_URL/repositories/$TEAM/$slug/src/develop/$remotePath?access_token=$OAUTH_TOKEN_BITBUCKET")
        RESPONSE_CODE=$(printf "%s" "${RESPONSE: -3}")
        if [ "$RESPONSE_CODE" = 200 ]; then
          if cmp -s "$tmpFile" "$localPath"; then
            RESPONSE_CODE=201 # falls alles identisch ist
            continue
          fi
        elif [ "$RESPONSE_CODE" != 404 ]; then
          printf "Error Response Code: %s\n" "$RESPONSE_CODE" 1>&2
          continue
        fi
        formParams+=" -F $remotePath=@$localPath"
        printf "Attempting to update %s/%s\n" "$slug" "$remotePath"  1>&2
      done
      if [ -n "$formParams" ]; then
        # shellcheck disable=SC2086
        RESPONSE=$(curl -s \
          -w "%{http_code}" \
          $formParams \
          -F message='Update from pipeline' \
          "$BITBUCKET_URL/repositories/$TEAM/$slug/src?access_token=$OAUTH_TOKEN_BITBUCKET")
        RESPONSE_CODE=$(printf "%s" "${RESPONSE: -3}")
        unset formParams
      fi
    done
  }
  retry internal_update_iflow_repositories 201
}

add_environment() {
  TYPE=$1
  NAME=$2

  RESPONSE=$(curl -s \
    -H "Content-Type: application/json" \
    -w "%{http_code}" \
    -d '{"environment_type":{"name":"'"$TYPE"'"},"name":"'"$NAME"'"}' \
    "$BITBUCKET_URL/repositories/$TEAM/$REPO_SLUG/environments/?access_token=$OAUTH_TOKEN_BITBUCKET")
  RESPONSE_CODE=$(printf "%s" "${RESPONSE: -3}")
  if [ "$RESPONSE_CODE" != 201 ]; then
    printf "Error Response Code: %s\n" "$RESPONSE_CODE" 1>&2
  fi
}

rename_environment() {
  FROM=$1
  TO=$2
  RESPONSE=$(curl -s "$BITBUCKET_URL/repositories/$TEAM/$REPO_SLUG/environments/?access_token=$OAUTH_TOKEN_BITBUCKET")
  UUID=$(jq -r '.values[] | select(.name=="'"$FROM"'") | .uuid' <<< "$RESPONSE" | sed 's/{/%7b/' | sed 's/}/%7d/')

  RESPONSE=$(curl -s \
    -H "Content-Type: application/json" \
    -w "%{http_code}" \
    -d '{"change":{"name":"'"$TO"'"}}' \
    "$BITBUCKET_URL/repositories/$TEAM/$REPO_SLUG/environments/$UUID/changes/?access_token=$OAUTH_TOKEN_BITBUCKET")
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
        "value": "'"$REPO_SLUG"'"}]}' \
      "$BITBUCKET_URL/repositories/$TEAM/***REMOVED***/pipelines/?access_token=$OAUTH_TOKEN_BITBUCKET")
}