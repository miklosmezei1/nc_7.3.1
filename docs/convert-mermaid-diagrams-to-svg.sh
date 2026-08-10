#!/usr/bin/env bash

set -e

case "$1" in
	--podman)
		CMD=podman
		ARGS="--userns"
		;;
	-*)
		echo "Usage: $(basename $0) [--podman]"
		echo "Specifying '--podman' makes the script use podman instead of docker."
		exit 1
		;;
	*)
		CMD=docker
		ARGS=""
esac

CONTAINER_IMAGE=ghcr.io/mermaid-js/mermaid-cli/mermaid-cli
$CMD pull $CONTAINER_IMAGE

cleanup() {
  rm -fv tmp.md
  rm -rf .cache
}

trap 'cleanup; exit 1' INT TERM EXIT

for file in *.mermaid; do
	echo "Processing '$file'"
	OUTPUT_FILE="${file/%.mermaid/.svg}"
	$CMD run --rm --user $(id -u):$(id -g) -v "${PWD}:/data:z" $CONTAINER_IMAGE --input "$file" --output "$OUTPUT_FILE" --outputFormat svg
done
