#!/bin/bash -eux
cwd=$(pwd)

ls -la

cp build-file/dp-otel-collector dp-otel-collector/otel-collector
cp key-file/ftb.tar.gz.asc dp-otel-collector

pushd dp-ci/gpg-keys/ci
  echo "decrypting CI privkey"
  echo $PRIVATE_KEY_PASSPHRASE | gpg --batch --passphrase-fd 0 privkey.asc
  gpg --import pubkey privkey
popd


pushd dp-otel-collector
    chmod 755 otel-collector
    gpg -d ftb.tar.gz.asc > ftb.tar.gz

    tar -xvf ftb.tar.gz
popd

cp -r dp-otel-collector/* build