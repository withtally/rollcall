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

ExecutorAddress=$(deploy Executor "$ARGS" --constructor-args "$CDM" "$TIMELOCK" "$DAO")
echo "Executor deployed to: $ExecutorAddress"
