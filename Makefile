# include .env file and export its env vars
include .env

deploy-mainnet: export ETH_RPC_URL = $(call network,eth-mainnet)
deploy-mainnet:; @./scripts/deploy-base.sh

deploy-opt-mainnet:export ETH_RPC_URL = $(call network,opt-mainnet)
deploy-opt-mainnet:; @./scripts/deploy-rollup.sh

deploy-kovan: export ETH_RPC_URL = $(call network,eth-kovan)
deploy-kovan:; @./scripts/deploy-base.sh

deploy-opt-kovan: export ETH_RPC_URL = $(call network,opt-kovan)
deploy-opt-kovan:; @./scripts/deploy-rollup.sh

# Returns the URL to deploy to a hosted node.
# Requires the ALCHEMY_API_KEY env var to be set.
# The first argument determines the network (mainnet / rinkeby / ropsten / kovan / goerli)
define network
https://$1.g.alchemy.com/v2/${ALCHEMY_API_KEY}
endef
