#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/common.sh

pushd $(dirname "$0")/..

ARGS=${@:1}

RollCallBridgeAddress=$(deploy RollCallBridge --constructor-args  0x4361d0F75A0186C05f971c566dC6bEa5957483fD)
echo "RollCallBridge deployed to: $RollCallBridgeAddress"

SimpleRollCallGovernorAddress=$(deploy SimpleRollCallGovernor --constructor-args  "Paper Governor" --constructor-args  "[781B575CA559263eb232B854195D6dC0AB720105]" --constructor-args  "[0000000000000000000000000000000000000000000000000000000000000000]" --constructor-args  $RollCallBridgeAddress)
echo "SimpleRollCallGovernor deployed to: $SimpleRollCallGovernorAddress"
