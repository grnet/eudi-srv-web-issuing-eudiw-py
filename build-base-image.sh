#!/bin/bash

REGISTRY=registry.docker.grnet.gr

usage_string="usage:

$ ./$(basename "$0") --tag TAG [-d DOCKERFILE] [--push] [--prod] [--no-push]

Build base image and optionally push to docker registry (${REGISTRY})

Name of image results from the Dockerfile after replacing the \"Dockerfile\"
prefix with \"eudi\" and \".\"'s with \"-\", and then tagging it. If to be
pushed, it is further tagged thrice with respect to the registry: with the
provided tag, with the provided tag plus current timestamp, and as \"latest\".

For example, building from \"Dockerfile.base.dev\" with \"--tag test\"
produces the following tagged image:

    eudi-base-dev:test

If in push mode, the following tagged images are further created:

    ${REGISTRY}/eudi-base-dev:test
    ${REGISTRY}/eudi-base-dev:test-20211228164642
    ${REGISTRY}/eudi-base-dev:latest

Arguments (required)
  -t, --tag     Docker tag (same for all images)

Options:
  --dockerfile FILE   Dockerfile to build from. Default: Dockerfile.base.dev
  --push              Push images to registry after build
  --no-push           Annules --push
  -h, --help          Show help message and exit

Examples
  ./$(basename "$0") --tag test
  ./$(basename "$0") --tag test --push
  ./$(basename "$0") --tag debug --no-push
  ./$(basename "$0") --tag ci --push --prod
"

usage() { echo -n "$usage_string" 1>&2; }


tag_for_registry() {

    image=$1
    tag=$2
    timestamp=$3

    echo "Tagging image ${image}:${tag} for registry"

    docker image tag ${image}:${tag} ${REGISTRY}/${image}:${tag}
    docker image tag ${image}:${tag} ${REGISTRY}/${image}:${tag}-${timestamp}
    docker image tag ${image}:${tag} ${REGISTRY}/${image}:latest
}


build_image() {

    dockerfile=$1
    tag=$2
    timestamp=$3
    image=eudi-$(echo $dockerfile | awk -F'.' '{st = index($0, ".");
    print substr($0, st + 1)}' | tr '.' '-')

    echo "Building image ${image}:${tag} from ${dockerfile}"

    export DOCKER_DEFAULT_PLATFORM=linux/amd64
    docker image build \
        -t ${image}:${tag} \
        -f ${dockerfile} \
        .

    if [ ${DO_PUSH} == true ] && [ ${NO_PUSH} == false ]; then
        tag_for_registry $image $tag $timestamp
    fi
}

push_image() {

    image=$1
    tag=$2
    timestamp=$3

    echo "Pushing image ${image} to registry"

    docker push ${REGISTRY}/${image}:${tag}
    docker push ${REGISTRY}/${image}:${tag}-${timestamp}
    docker push ${REGISTRY}/${image}:latest
}


set -e

DOCKERFILE=Dockerfile.base.dev

DO_PUSH=false
NO_PUSH=false

dockerfiles=${DOCKERFILES}

while [[ $# -gt 0 ]]
do
    arg="$1"
    case $arg in
        -t|--tag)
            TAG=$2
            shift
            shift
            ;;
        --dockerfile)
            DOCKERFILE=$2
            shift
            shift
            ;;
        --push)
            DO_PUSH=true
            shift
            ;;
        --no-push)
            NO_PUSH=true
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

if [[ -z ${TAG} ]]; then
    echo "[-] No tag provided"
    usage
    exit 1
fi

timestamp=${TIMESTAMP:-`date '+%Y%m%d%H%M%S'`}    # '+%s' for unix time

build_image $DOCKERFILE $TAG $timestamp

if [ ${DO_PUSH} == true ] && [ ${NO_PUSH} == false ]; then
    docker login ${REGISTRY}
    push_image $image $TAG $timestamp
    docker logout ${REGISTRY}
fi
