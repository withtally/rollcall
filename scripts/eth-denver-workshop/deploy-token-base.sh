#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/../common.sh

pushd $(dirname "$0")/../..

RPC="https://eth-kovan.alchemyapi.io/v2/dLtG6qAIvETZ7OKf4hoILCfKTN3rsRaK"
ARGS=${@:1}

L1VotingERC20Address=$(deploy L1VotingERC20 "$ARGS" --constructor-args "$NAME" "$SYMBOL" --rpc-url "$RPC" --private-key "$ETH_PRIVATE_KEY")
echo "L1VotingERC20 deployed to: $L1VotingERC20Address"
