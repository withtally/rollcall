#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/common.sh

pushd $(dirname "$0")/..

ARGS=${@:1}

CDM=0x4361d0F75A0186C05f971c566dC6bEa5957483fD
if [[ ${ROLLCALL_MAINNET} ]]; then
    CDM=0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1
fi

BridgeAddress=$(deploy Bridge "$ARGS" --constructor-args "$CDM")
echo "Bridge deployed to: $BridgeAddress"

SimpleRollCallGovernorAddress=$(deploy SimpleRollCallGovernor "$ARGS" --constructor-args "PaperGovernor" --constructor-args "$ROLLCALL_SOURCES" --constructor-args "$ROLLCALL_SLOTS" --constructor-args $BridgeAddress)
echo "SimpleRollCallGovernor deployed to: $SimpleRollCallGovernorAddress"
