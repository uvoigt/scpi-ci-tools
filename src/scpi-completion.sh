#!/bin/bash
# shellcheck disable=SC2207,SC2012

_local_folders() {
  COMPREPLY=($(compgen -d -- "$1"))
}

_local_artifacts() {
  artifacts=$(ls -d "$GIT_BASE_DIR"/iflow_* | sed 's/.*iflow_//' | paste -sd ' ' -)
  COMPREPLY=($(compgen -W "$artifacts" "$third"))
}

_remote_design_packages() {
  if [ -f "$CONFIG_DIR/packages" ]; then
    packages=$(< "$CONFIG_DIR/packages")
    COMPREPLY=($(compgen -W "$packages" "$1"))
  fi
}

_remote_design_artifacts() {
  if [ -f "$CONFIG_DIR/artifacts" ]; then
    artifacts=$(< "$CONFIG_DIR/artifacts")
    COMPREPLY=($(compgen -W "$artifacts" "$third"))
  fi
}

_remote_runtime_artifacts() {
  execute_api_request "api/v1/IntegrationRuntimeArtifacts"
  if [ "$RESPONSE_CODE" = 200 ]; then
    ids=$(jq -r '.d.results[] | .Id' <<< "$RESPONSE")
    COMPREPLY=($(compgen -W "$ids" "$third"))
  fi
}

_remote_runtime_endpoints() {
  execute_api_request "api/v1/ServiceEndpoints?%24filter=Name%20eq%20'$1'&%24expand=EntryPoints&%24format=json"
  if [ "$RESPONSE_CODE" = 200 ]; then
    urls=$(jq -r '.d.results[] | .EntryPoints.results[] | .Url' <<< "$RESPONSE")
    COMPREPLY=($(compgen -W "$urls" "$2"))
  fi
}

_scpi_completions()
{
  . configure.sh

  first=${COMP_WORDS[1]}
  second=${COMP_WORDS[2]}
  third=${COMP_WORDS[3]}
  fourth=${COMP_WORDS[4]}
  fifth=${COMP_WORDS[5]}
  case ${#COMP_WORDS[@]} in
  2)
    COMPREPLY=($(compgen -W 'design runtime' "$first"))
    ;;
  3)
    case $first in
    design)
      COMPREPLY=($(compgen -W "artifacts packages create delete deploy download" "$second"))
      ;;
    runtime)
      COMPREPLY=($(compgen -W "artifacts deploy undeploy errors call" "$second"))
    esac
    ;;
  4)
    case $first in
    design)
      case $second in
      artifacts)
        _remote_design_packages "$third"
        ;;
      create)
        _local_artifacts
        ;;
      delete|deploy|download)
        _remote_design_artifacts
      esac
      ;;
    runtime)
      case $second in
      deploy)
        _local_artifacts
        ;;
      undeploy|errors|call)
        _remote_runtime_artifacts
      esac
    esac
    ;;
  5)
    case $first in
    design)
      case $second in
      create)
        _remote_design_packages "$fourth"
        ;;
      download)
        _local_folders "$fourth"
      esac
      ;;
    runtime)
      case $second in
      deploy)
        _local_folders "$fourth"
        ;;
      call)
        _remote_runtime_endpoints "$third" "$fourth"
      esac
    esac
    ;;
  6)
    case $first in
    design)
      case $second in
      create)
        _local_folders "$fifth"
      esac
    esac
  esac
}

complete -F _scpi_completions scpi
