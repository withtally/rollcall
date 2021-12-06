# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

install: update npm solc

# dapp deps
update:; dapp update

# npm deps for linting etc.
npm:; yarn install

# install solc version
# example to install other versions: `make solc 0_8_2`
SOLC_VERSION := 0_8_10
solc:; nix-env -f https://github.com/dapphub/dapptools/archive/master.tar.gz -iA solc-static-versions.solc_${SOLC_VERSION}

# Build & test
# build  : export DAPP_LIBRARIES=" src/MetadataBuilder.sol:MetadataBuilder:0xd2761Ee62d8772343070A5dE02C436F788EdF60a"
build  :; ./scripts/build.sh
test   :; dapp test --ffi # enable if you need the `ffi` cheat code on HEVM
clean  :; dapp clean
lint   :; yarn run lint

# Deployment helpers
deploy-base :; @./scripts/deploy-base.sh
deploy-rollup :; @./scripts/deploy-rollup.sh

# mainnet
deploy-mainnet: export ETH_RPC_URL = https://ancient-morning-wave.quiknode.pro/0d888ce1d2caa53e7004a067641c905934ef0efa/
deploy-mainnet: check-api-key deploy-mainnet

# optimism
deploy-optimism: export ETH_RPC_URL = https://opt-mainnet.g.alchemy.com/v2/k8J6YaoTtJVIs4ZxTo26zIPfBiCveX2m
deploy-optimism: check-api-key deploy-l2

# kovan
deploy-kovan: export ETH_RPC_URL = $(call network,kovan)
deploy-kovan: check-api-key deploy-l1

# opt-kovan
deploy-opt-kovan: export ETH_RPC_URL = https://opt-kovan.g.alchemy.com/v2/GAJJKOHOzfVI1jmgOf2OcL--sj4Yyedg
deploy-opt-kovan: check-api-key deploy-l2

check-api-key:
ifndef ALCHEMY_API_KEY
	$(error ALCHEMY_API_KEY is undefined)
endif

# Returns the URL to deploy to a hosted node.
# Requires the ALCHEMY_API_KEY env var to be set.
# The first argument determines the network (mainnet / rinkeby / ropsten / kovan / goerli)
define network
https://eth-$1.alchemyapi.io/v2/${ALCHEMY_API_KEY}
endef
