#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/../common.sh

pushd $(dirname "$0")/../..

ARGS=${@:1}

ensure KOVAN_RPC
ensure ETH_PRIVATE_KEY
ensure NAME
ensure SYMBOL

export L1VotingERC20Address=$(deploy L1VotingERC20 "$ARGS" --constructor-args "$NAME" "$SYMBOL" --rpc-url "$KOVAN_RPC" --private-key "$ETH_PRIVATE_KEY")
echo "L1VotingERC20 deployed to: $L1VotingERC20Address"
