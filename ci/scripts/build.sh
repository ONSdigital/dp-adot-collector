#!/bin/bash -eux

pushd dp-adot-collector
  make build
  cp Dockerfile.concourse ../build
popd

cp config.yml build