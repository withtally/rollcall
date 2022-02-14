#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/../common.sh

pushd $(dirname "$0")/../..

ARGS=${@:1}

SimpleGovernorAddress=$(deploy SimpleGovernor "$ARGS" --constructor-args "$L2_TOKEN_ADDRESS" 1 30 0 10 --rpc-url "$OPTIMISM_KOVAN_RPC" --private-key "$ETH_PRIVATE_KEY")
echo "SimpleGovernor deployed to: $SimpleGovernorAddress"
