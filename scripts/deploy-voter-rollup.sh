#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/common.sh

pushd $(dirname "$0")/..

ARGS=${@:1}

L2VoterAddress=$(deploy src/L2Voter.sol:L2Voter "$ARGS" --constructor-args "$ROLLCALL_BRIDGE")
echo "L2Voter deployed to: $L2VoterAddress"
