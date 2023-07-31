#!/bin/bash

set -e -o pipefail

[[ ${CLS_LOCAL} != true ]] && PATH="/opt/tessellate/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin"

BASENAME="${0##*/}"

AWS_REGION=${AWS_REGION:-us-east-2}

usage () {
  if [ "${#@}" -ne 0 ]; then
    echo "* ${*}"
    echo
  fi
  cat <<ENDUSAGE
Usage:

${BASENAME} --help

  - or -

${BASENAME} --lot <lot> --manifest <uri>
ENDUSAGE

  exit 2
}

error_exit () {
  EXIT_CODE=$?
  echo "${BASENAME} - ${1}" >&2
  exit ${EXIT_CODE}
}

PARAMS=""
while (( "$#" )); do
  case "$1" in
    --lot)
      if [ -n "$2" ]; then
        LOT=$2
        shift 2
      else
        echo "Error: Argument for $1 is missing" >&2
        exit 1
      fi
      ;;
    --manifest)
      if [ -n "$2" ]; then
        SOURCE_MANIFEST_URI=$2
        shift 2
      else
        echo "Error: Argument for $1 is missing" >&2
        exit 1
      fi
      ;;
    *)
      PARAMS="$PARAMS $1"
      shift
      ;;
  esac
done
eval set -- "$PARAMS"

SINK_URI=$(echo ${CLS_ARC_PROPS_JSON} | jq -r '.sinks.main.pathURI')
SINK_MANIFEST_TEMPLATE=$(echo ${CLS_ARC_PROPS_JSON} | jq -r '.sinkManifestTemplates.main')

echo ${SOURCE_MANIFEST_URI}
echo ${SINK_URI}
echo ${SINK_MANIFEST_TEMPLATE}

tess \
    --pipeline ingest.json \
    --input-manifest ${SOURCE_MANIFEST_URI} \
    --input-manifest-lot ${LOT} \
    --output ${SINK_URI} \
    --output-manifest-template ${SINK_MANIFEST_TEMPLATE} \
    --output-manifest-lot ${LOT} \
    -v
