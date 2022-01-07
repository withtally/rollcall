#!/usr/bin/env bash

set -eo pipefail

if [[ ${DEBUG} ]]; then
    set -x
fi

ETH_KEYSTORE=$(echo $ETH_KEYSTORE)
ETH_KEYSTORE_PASSWORD=$(echo $ETH_KEYSTORE_PASSWORD)

# Call as `ETH_FROM=0x... ETH_RPC_URL=<url> deploy ContractName arg1 arg2 arg3`
# (or omit the env vars if you have already set them)
deploy() {
    NAME=$1
    ARGS=${@:2}

    ADDRESS=$(forge create $NAME --constructor-args $ARGS --rpc-url $ETH_RPC_URL --keystore $ETH_KEYSTORE --password $ETH_KEYSTORE_PASSWORD | grep 'Deployed to:' | sed 's/^.*: //')

    echo $ADDRESS
}
