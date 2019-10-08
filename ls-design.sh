#!/bin/sh

########################################################################################################################
# Listet die Design-time Artifacts im Workspace.
# Wenn ein Argument angegeben ist, wird das als Packagename interpretiert und nur die Artefakte des
# Packages ausgegeben. Ansonsten werden die Artefakte aller Packages ausgegeben.
# Im Moment muss diese Funktion über Eingabe des Passworts authentisiert werden (kein OAuth möglich)
########################################################################################################################

. ./login.sh

get_dta_by_package() {
  execute_api_request 'itspaces/odata/1.0/workspace.svc/ContentPackages('"'""$1""'"')/Artifacts?$format=json'

  COUNT=$(jq -r '.d.results | length' <<< "$RESPONSE")
  printf "%s total artifacts\n" "$COUNT"
  if [ "$COUNT" -gt 0 ]; then printf ${white}; fi
  for k in $(jq -r '.d.results | keys | .[]' <<< "$RESPONSE"); do
    if [ -z "$first_line" ]; then
      printf "%s\t%s\t%s\t%s\t%s${none}\n" "Name" "Type" "Version" "Created at" "Created by"
      first_line=1
    fi
    value=$(jq -r ".d.results[$k]" <<< "$RESPONSE")
    metadata=$(jq -r .__metadata <<< "$value")
    id=$(jq -r .id <<< "$metadata")
    type=$(jq -r .Type <<< "$value")
    name=$(jq -r .Name <<< "$value")
    reg_id=$(jq -r .reg_id <<< "$value")
    version=$(jq -r .Version <<< "$value")
    created_at=$(jq -r .CreatedAt <<< "$value" | cut -c 7-16)
    created_at=$(format_time "$created_at")
    created_by=$(jq -r .CreatedBy <<< "$value")
    printf "%s\t%s\t%s\t%s\t%s\n" "$name" "$type" "$version" "$created_at" "$created_by"
  done | column -t -s$'\t'
}

if [ -n "$1" ]; then
    get_dta_by_package "$1"
else
  PACKAGE_NAMES=$(. ./ls-packages.sh | tail -n +3 | sed -n 's/^\([^ ]*\) .*/\1/p')
  for k in $PACKAGE_NAMES; do
    printf "Package: ${white}%s\n${none}" "$k"
    get_dta_by_package "$k"
  done
fi