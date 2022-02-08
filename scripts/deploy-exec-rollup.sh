#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/common.sh

pushd $(dirname "$0")/..

ARGS=${@:1}

L1SimpleRollCallGovernorAddress=$(deploy L1SimpleRollCallGovernor "$ARGS" --constructor-args "$TOKEN" 1 45818 0 10)
echo "L1SimpleRollCallGovernor deployed to: $L1SimpleRollCallGovernorAddress"
