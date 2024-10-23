#!/bin/bash

usage_string="usage: ./$(basename "$0") [OPTIONS]

Options:
  --build           Build web image before running the application (will also
                    re-build the base image)
  --force-recreate  Recreate containers
  -h, --help        Display help message and exit

Examples:
"

usage() { echo -n "$usage_string" 1>&2; }

DO_BUILD=false
DO_RECREATE=false
compose_args=()

while [[ $# -gt 0 ]]
do
    arg="$1"
    case $arg in
        --build)
            DO_BUILD=true
            compose_args+=($arg)
            shift
            ;;
        --force-recreate)
            DO_RECREATE=true
            compose_args+=($arg)
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "[-] Invalid argument: $arg"
            usage
            exit 1
            ;;
    esac
done

if [ ${DO_BUILD} == true ]; then
    ./build-base-image.sh \
        --tag "local" \
        --no-push
fi

docker compose \
    up \
    $compose_args \
    --remove-orphans
