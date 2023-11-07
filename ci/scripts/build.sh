#!/bin/bash -eux

pushd dp-adot-collector
  cp Dockerfile.concourse ../build
  cp config.yml ../build
popd

