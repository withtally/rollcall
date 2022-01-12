#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/common.sh

pushd $(dirname "$0")/..

# forge create RollCallBridge --constructor-args 0x4361d0F75A0186C05f971c566dC6bEa5957483fD --rpc-url https://eth-kovan.g.alchemy.com/v2/m-suB_sgPaMFttpSJMU9QWo60c1yxnlG
# kovan: 0xa8e18091a031973fd374c7cc33ec7297bb7e3afd
RollCallBridgeAddress=$(deploy RollCallBridge 0x4361d0F75A0186C05f971c566dC6bEa5957483fD)
echo "RollCallBridge deployed to: $RollCallBridgeAddress"

# forge create SimpleRollCallGovernor --constructor-args "Paper Governor" --constructor-args "[781B575CA559263eb232B854195D6dC0AB720105]" --constructor-args "[0000000000000000000000000000000000000000000000000000000000000000]" --constructor-args 0xa8e18091a031973fd374c7cc33ec7297bb7e3afd --rpc-url https://eth-kovan.g.alchemy.com/v2/m-suB_sgPaMFttpSJMU9QWo60c1yxnlG
# kovan: 0x477b0595edf0fb14748d28352ecf72ba19b50698
SimpleRollCallGovernorAddress=$(deploy SimpleRollCallGovernor "Paper Governor" "[781B575CA559263eb232B854195D6dC0AB720105]" "[0000000000000000000000000000000000000000000000000000000000000000]" $RollCallBridgeAddress)
echo "SimpleRollCallGovernor deployed to: $SimpleRollCallGovernorAddress"
