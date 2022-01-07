# include .env file and export its env vars
include .env

deploy-mainnet: export ETH_RPC_URL = $(call network,mainnet)
deploy-mainnet:; @./scripts/deploy-base.sh

deploy-kovan: export ETH_RPC_URL = $(call network,kovan)
deploy-kovan:; @./scripts/deploy-base.sh

# Returns the URL to deploy to a hosted node.
# Requires the ALCHEMY_API_KEY env var to be set.
# The first argument determines the network (mainnet / rinkeby / ropsten / kovan / goerli)
define network
https://eth-$1.alchemyapi.io/v2/${ALCHEMY_API_KEY}
endef