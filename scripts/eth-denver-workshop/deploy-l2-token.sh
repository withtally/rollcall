#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/../common.sh

pushd $(dirname "$0")/../..

ARGS=${@:1}

ensure OPTIMISM_KOVAN_RPC
ensure ETH_PRIVATE_KEY
ensure L1_TOKEN_ADDRESS

L2VotingERC20Address=$(deploy L2VotingERC20 "$ARGS" --constructor-args "$L1_TOKEN_ADDRESS" "$NAME" "$SYMBOL" --rpc-url "$OPTIMISM_KOVAN_RPC" --private-key "$ETH_PRIVATE_KEY")
echo "L2VotingERC20 deployed to: $L2VotingERC20Address"
