#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/common.sh

pushd $(dirname "$0")/..

RollCallVoterAddress=$(deploy src/RollCallVoter.sol:RollCallVoter 0x4361d0F75A0186C05f971c566dC6bEa5957483fD)
echo "RollCallVoter deployed to: $RollCallVoterAddress"
