#!/bin/bash

########################################################################################################################
# Listet die Packages im Workspace.
# Im Moment muss diese Funktion über Eingabe des Passworts authentisiert werden (kein OAuth möglich)
########################################################################################################################

. ./login.sh

execute_api_request 'itspaces/odata/1.0/workspace.svc/ContentPackages?$format=json'

# shellcheck disable=SC2154,SC2059
if [ "$RESPONSE_CODE" = 200 ]; then
  COUNT=$(jq -r '.d.results | length' <<< "$RESPONSE")
  printf "%s total artifacts\n" "$COUNT"
  if [ "$COUNT" -gt 0 ]; then printf "${white}"; fi
  for k in $(jq -r '.d.results | keys | .[]' <<< "$RESPONSE"); do
    if [ -z "$first_line" ]; then
      printf "%s\t%s\t%s\t%s${none}\n" "Name" "Version" "Created at" "Created by"
      first_line=1
    fi
    value=$(jq -r ".d.results[$k]" <<< "$RESPONSE")
    metadata=$(jq -r .__metadata <<< "$value")
    id=$(jq -r .id <<< "$metadata")
    type=$(jq -r .Type <<< "$value")
    tech_name=$(jq -r .TechnicalName <<< "$value")
    reg_id=$(jq -r .reg_id <<< "$value")
    version=$(jq -r .Version <<< "$value")
    created_at=$(jq -r .CreatedAt <<< "$value" | cut -c 7-16)
    created_at=$(format_time "$created_at")
    created_by=$(jq -r .CreatedBy <<< "$value")
    printf "%s\t%s\t%s\t%s\n" "$tech_name" "$version" "$created_at" "$created_by"
  done | column -t -s$'\t'
fi
