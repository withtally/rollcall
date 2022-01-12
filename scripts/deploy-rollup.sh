#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/common.sh

pushd $(dirname "$0")/..

# forge create RollCallVoter --constructor-args "RollCallVoter" --constructor-args 0x4200000000000000000000000000000000000007 --constructor-args 0xa8e18091a031973fd374c7cc33ec7297bb7e3afd
# Kovan Optimism: 0xa157ff42c849599d5448329bf8b05c6513ef8681
RollCallVoterAddress=$(deploy src/RollCallVoter.sol:RollCallVoter 0x4361d0F75A0186C05f971c566dC6bEa5957483fD)
echo "RollCallVoter deployed to: $RollCallVoterAddress"
