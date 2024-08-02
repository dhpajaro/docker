#!/bin/bash
parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
pushd "$parent_path"
compose_file="../compose/media_server/compose.yaml"
trap 'docker compose -f $compose_file down watchstate;popd; exit 1' EXIT HUP INT TERM
docker compose -f $compose_file up watchstate -d && \
docker exec -ti watchstate console state:import -v && \
docker exec -ti watchstate console state:export -vvif -s jellyfin && \
docker compose -f $compose_file down watchstate
