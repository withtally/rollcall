#!/usr/bin/env bash

set -eo pipefail

export ETH_RPC_URL=https://eth-kovan.alchemyapi.io/v2/${ALCHEMY_API_KEY}

forge create RollCallBridge --constructor-args 0x4361d0F75A0186C05f971c566dC6bEa5957483fD