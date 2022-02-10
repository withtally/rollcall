#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/../common.sh

pushd $(dirname "$0")/../..

ARGS=${@:1}

RollCallExecutorAddress=$(deploy RollCallExecutor "$ARGS" --constructor-args 0x4361d0F75A0186C05f971c566dC6bEa5957483fD "$GOVERNOR_ADDRESS" --rpc-url "$KOVAN_RPC" --private-key "$ETH_PRIVATE_KEY")
echo "RollCallExecutor deployed to: $RollCallExecutorAddress"
