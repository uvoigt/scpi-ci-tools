#!/bin/bash
# shellcheck disable=SC2207,SC2012
debug=false

_available_configs() {
  extensions=$(find "$CONFIG_DIR" -maxdepth 1 -type f -name 'config.*' | sed -E 's/.+[\./]([^/\.]+)/\1/')
  COMPREPLY=($(compgen -W "$extensions" "$second"))
}

_local_folders() {
  COMPREPLY=($(compgen -d -- "$1"))
}

_local_artifacts() {

  artifacts=()
  artifactFolders=($(ls -d "$GIT_BASE_DIR"/iflow_*))

  for folder in "${artifactFolders[@]}"; do
    artifactLine=($(perl -0777 -wpe 's/\r?\n //g' "$folder/META-INF/MANIFEST.MF" | grep ^Bundle-SymbolicName ))
    artifacts+=($(tr -d ';' <<< "${artifactLine[1]}"))
  done
  COMPREPLY=($(compgen -W "${artifacts[*]}" "$third"))
}

_remote_design_packages() {
  execute_api_request "api/v1/IntegrationPackages"
  if [ "$RESPONSE_CODE" = 200 ]; then
    ids=$(jq -r '.d.results[] | .Id' <<< "$RESPONSE")
    COMPREPLY=($(compgen -W "$ids" "$1"))
  fi
}

_remote_design_artifacts() {
  execute_api_request "api/v1/IntegrationPackages"
  if [ "$RESPONSE_CODE" = 200 ]; then
    ids=$(jq -r '.d.results[] | .Id' <<< "$RESPONSE")
    artifacts=()
    for id in $ids; do
      execute_api_request "api/v1/IntegrationPackages('$id')/IntegrationDesigntimeArtifacts"
      if [ "$RESPONSE_CODE" = 200 ]; then
        artifacts+=($(jq -r '.d.results[] | .Id' <<< "$RESPONSE"))
      fi
    done
    COMPREPLY=($(compgen -W "${artifacts[*]}" "$third"))
  fi
}

_remote_runtime_artifacts() {
  execute_api_request "api/v1/IntegrationRuntimeArtifacts"
  if [ "$RESPONSE_CODE" = 200 ]; then
    ids=$(jq -r '.d.results[] | .Id' <<< "$RESPONSE")
    COMPREPLY=($(compgen -W "$ids" "$1"))
  fi
}

_remote_runtime_endpoints() {
  execute_api_request "api/v1/ServiceEndpoints?%24filter=Name%20eq%20'$1'&%24expand=EntryPoints&%24format=json"
  if [ "$RESPONSE_CODE" = 200 ]; then
    urls=$(jq -r '.d.results[] | .EntryPoints.results[] | .Url' <<< "$RESPONSE")
    local IFS=$'\n'
    COMPREPLY=($(compgen -P "'" -S "'" -W "$urls" "$2"))
  fi
}

_queues() {
  execute_api_request "api/v1/Queues"
  if [ "$RESPONSE_CODE" = 200 ]; then
    queues=$(jq -r '.d.results[] | .Name' <<< "$RESPONSE")
    COMPREPLY=($(compgen -W "$queues" "$1"))
  fi
}

_log_node_code() {
  execute_api_request "api/v1/LogFiles?%24filter=LogFileType%20eq%20'$1'"
  if [ "$RESPONSE_CODE" = 200 ]; then
    array=($(jq -r '.d | .results |= sort_by(.LastModified) | .results | reverse | .[0]?.Name, .[1]?.Name' <<< "$RESPONSE"))
    words=()
    for i in "${array[@]}"; do
      read -ra parts <<< "${i//_/ }"
      words+=("${parts[2]}")
    done
    COMPREPLY=($(compgen -W "${words[*]}" "$fourth"))
  fi
}

_handleOptionCompletion() {
  length=${#COMP_WORDS[@]}
  case $1 in
  messages)
    case $2 in
    -n)
      _remote_runtime_artifacts "${COMP_WORDS[$length - 1]}"
      ;;
    -s)
      COMPREPLY=($(compgen -W 'FAILED RETRY COMPLETED PROCESSING ESCALATED' "${COMP_WORDS[$length - 1]}"))
      ;;
    esac
    ;;
  esac
}

_scpi_completions()
{
  . configure.sh

  array=()
  for i in "${COMP_WORDS[@]}"; do
    if [[ "$i" = -* ]]; then
      option=$i
    else
      if [ -n "$option" ]; then
        case $option in
          -[aoc])
            unset option
            continue
            ;;
          -[fp])
            unset option
        esac
      fi
      array+=("$i")
    fi
  done

  if [ "$0" = "compgen" ]; then
    array+=("")
  fi

  [ $debug = true ] && printf "Option: %s\n" "$option" >> ~/scpi.log

  if [ -n "$option" ]; then
    if (( ${#array[@]} >= 4 )); then
      _handleOptionCompletion "${array[2]}" "$option"
    fi
    unset option
    return
  fi

  first=${array[1]}
  second=${array[2]}
  third=${array[3]}
  fourth=${array[4]}
  fifth=${array[5]}
  case ${#array[@]} in
  2)
    COMPREPLY=($(compgen -W 'config design runtime' "$first"))
    ;;
  3)
    case $first in
    config)
      _available_configs
      ;;
    design)
      COMPREPLY=($(compgen -W "artifacts packages create delete deploy download upload" "$second"))
      ;;
    runtime)
      COMPREPLY=($(compgen -W "artifacts deploy undeploy errors logs messages call queue" "$second"))
    esac
    ;;
  4)
    case $first in
    design)
      case $second in
      artifacts)
        _remote_design_packages "$third"
        ;;
      create|upload)
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
        _remote_runtime_artifacts "$third"
        ;;
      logs)
        COMPREPLY=($(compgen -W "trace http" "$third"))
        ;;
      queue)
        _queues "$third"
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
        ;;
      queue)
        COMPREPLY=($(compgen -W "show delete retry" "$fourth"))
        ;;
      logs)
        _log_node_code "$third" "$fourth"
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
