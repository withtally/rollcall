#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/common.sh

pushd $(dirname "$0")/..

ARGS=${@:1}

RollCallVoterAddress=$(deploy src/RollCallVoter.sol:RollCallVoter "$ARGS" --constructor-args "$ROLLCALL_BRIDGE")
echo "RollCallVoter deployed to: $RollCallVoterAddress"
