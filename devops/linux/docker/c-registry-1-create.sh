#!/bin/bash

set -e
set -u

source ./conf.env
source ./conf/images/conf-hub-images.sh

sudo rm -r -f ${PWD}/data-registry
mkdir -p ${PWD}/data-registry

echo "PLACEMENT_REGISTRY: ${PLACEMENT_REGISTRY}"

# Plain container bound to loopback: the Docker daemon pulls from localhost:5000, nothing else may reach it.
docker rm -f registry 2>/dev/null || true
docker run -d --name registry --restart unless-stopped --memory=64m \
  -p 127.0.0.1:5000:5000 \
  -v ${PWD}/data-registry:/var/lib/registry \
  $REGISTRY_IMAGE
