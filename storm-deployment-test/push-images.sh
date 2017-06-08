#!/bin/bash
set -ex
tags=${tags:-"centos6"}

if [ -n "${DOCKER_REGISTRY_HOST}" ]; then
  for t in ${tags}; do
    docker tag -f  italiangrid/storm-deployment-test:${t} ${DOCKER_REGISTRY_HOST}/italiangrid/storm-deployment-test:${t}
    docker push ${DOCKER_REGISTRY_HOST}/italiangrid/storm-deployment-test:${t}
  done
fi

if [ -n "${PUSH_TO_DOCKERHUB}" ]; then
  for t in ${tags}; do
    docker push italiangrid/storm-deployment-test:${t}
  done
fi
