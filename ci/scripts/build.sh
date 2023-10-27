#!/bin/bash -eux
cwd=$(pwd)

ls -la

cp build-file/dp-adot-collector dp-adot-collector/adot-collector
cp key-file/ftb.tar.gz.asc dp-adot-collector

pushd dp-ci/gpg-keys/ci
  echo "decrypting CI privkey"
  echo $PRIVATE_KEY_PASSPHRASE | gpg --batch --passphrase-fd 0 privkey.asc
  gpg --import pubkey privkey
popd


pushd dp-adot-collector
    chmod 755 adot-collector
    gpg -d ftb.tar.gz.asc > ftb.tar.gz

    tar -xvf ftb.tar.gz
popd

cp -r dp-adot-collector/* build