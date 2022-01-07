#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/common.sh

pushd $(dirname "$0")/..

RollCallBridgeAddress=$(deploy RollCallBridge 0x4361d0F75A0186C05f971c566dC6bEa5957483fD)
echo "RollCallBridge deployed to: $RollCallBridgeAddress"

SimpleRollCallGovernorAddress=$(deploy SimpleRollCallGovernor "Paper Governor" "[781B575CA559263eb232B854195D6dC0AB720105]" "[0000000000000000000000000000000000000000000000000000000000000000]" $RollCallBridgeAddress)
echo "SimpleRollCallGovernor deployed to: $SimpleRollCallGovernorAddress"
