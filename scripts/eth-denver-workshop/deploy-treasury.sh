#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/../common.sh

pushd $(dirname "$0")/../..

ARGS=${@:1}

export TreasuryAddress=$(deploy Treasury "$ARGS" --rpc-url "$KOVAN_RPC" --private-key "$ETH_PRIVATE_KEY")
echo "Treasury deployed to: $TreasuryAddress"
