#!/bin/bash
parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
pushd "$parent_path"
compose_file="../compose/media_server/compose.yaml"
trap 'docker compose -f $compose_file down plextraktsync;popd; exit 1' EXIT HUP INT TERM
docker compose -f $compose_file run --rm plextraktsync sync && \
docker compose -f $compose_file down plextraktsync
