#!/bin/bash -eux

pushd dp-adot-collector
  cp Dockerfile.concourse ../build
popd

cp config.yml build