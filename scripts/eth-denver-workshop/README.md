# eth-denver-workshop

## Setup

### Install foundry

First run the command below to get `foundryup`, the Foundry toolchain installer:

```sh
curl -L https://foundry.paradigm.xyz | bash
```

Then, in a new terminal session or after reloading your `PATH`, run it to get the latest `forge` and `cast` binaries:

```sh
foundryup
```

### Create a wallet

```sh
> cast wallet new
Successfully created new keypair.
Address: 0xeb93Dbc9238901d2C28f2C523A61b7d2e93DcE19.
Private Key: 020d80f7ed3351219c496dcc4c5bf8a981c207d531310c8d0992bdea8cf02be3.
```

```sh
# !IMPORTANT: DONT DO THIS AT HOME!
# Export private key to simplify the scripts
export ETH_PRIVATE_KEY=020d80f7ed3351219c496dcc4c5bf8a981c207d531310c8d0992bdea8cf02be3
```

Import your private key into metamask: https://metamask.zendesk.com/hc/en-us/articles/360015489331-How-to-import-an-Account

Get some testnet funds using the address generated above, be sure to "Drip additional networks": https://faucet.paradigm.xyz/

If you need more funds, email me your address at tarrence@withtally.com

Now we're ready!

## Deploying our Token

```sh
NAME="RollCallDAO" SYMBOL="DAO" ./deploy-token-base.sh
```