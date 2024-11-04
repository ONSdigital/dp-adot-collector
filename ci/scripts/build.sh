#!/bin/bash -eux

pushd dp-adot-collector

  if [[ "$APPLICATION" == "dp-adot-collector-lb" ]]; then
      cp Dockerfile-lb.concourse ../build/Dockerfile.concourse
      cp config-lb.yml ../build
  elif [[ "$APPLICATION" == "dp-adot-collector" ]]; then
      cp Dockerfile.concourse ../build
      cp config-aggregator.yml ../build
  fi

popd

