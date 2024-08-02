#!/bin/bash
docker run --rm -ti -v /var/run/docker.sock:/var/run/docker.sock  --name ctop quay.io/vektorlab/ctop:latest
