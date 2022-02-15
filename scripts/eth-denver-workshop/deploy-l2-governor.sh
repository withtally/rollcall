#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/../common.sh

pushd $(dirname "$0")/../..

ARGS=${@:1}

ensure OPTIMISM_KOVAN_RPC
ensure ETH_PRIVATE_KEY
ensure L2_TOKEN_ADDRESS

SimpleL2GovernorAddress=$(deploy SimpleL2Governor "$ARGS" --constructor-args "$L2_TOKEN_ADDRESS" 1 300 0 10 --rpc-url "$OPTIMISM_KOVAN_RPC" --private-key "$ETH_PRIVATE_KEY")
echo "SimpleL2Governor deployed to: $SimpleL2GovernorAddress"
