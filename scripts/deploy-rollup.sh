#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/common.sh

pushd $(dirname "$0")/..

ARGS=${@:1}

RollCallVoterAddress=$(deploy src/RollCallVoter.sol:RollCallVoter "$ARGS" --constructor-args "RollCallVoter" --constructor-args 0x4200000000000000000000000000000000000007 --constructor-args 0xa8e18091a031973fd374c7cc33ec7297bb7e3afd)
echo "RollCallVoter deployed to: $RollCallVoterAddress"
