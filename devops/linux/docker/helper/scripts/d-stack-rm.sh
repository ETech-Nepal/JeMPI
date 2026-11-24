#!/bin/bash

#set -e
set -u

pushd .
  SCRIPT_DIR=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
  cd ${SCRIPT_DIR}/../..

  source ./conf.env
  # The shared `frontend` network stays while Caddy/identity-mediator (other stacks) are attached; that is fine, so do not abort callers that run with set -e.
  docker stack rm ${STACK_NAME} || echo "(stack rm reported leftovers, continuing)"
  echo

popd
