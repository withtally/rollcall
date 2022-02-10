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
# Export private key to simplify the scripts
export ETH_PUBLIC_KEY=0xeb93Dbc9238901d2C28f2C523A61b7d2e93DcE19
export ETH_PRIVATE_KEY=020d80f7ed3351219c496dcc4c5bf8a981c207d531310c8d0992bdea8cf02be3
```

Import your private key into metamask: https://metamask.zendesk.com/hc/en-us/articles/360015489331-How-to-import-an-Account

Get some testnet funds using the address generated above, be sure to "Drip additional networks": https://faucet.paradigm.xyz/

If you need more funds, email me your address at tarrence@withtally.com

### Setup env

```sh
export KOVAN_RPC="https://eth-kovan.alchemyapi.io/v2/dLtG6qAIvETZ7OKf4hoILCfKTN3rsRaK"
export OPTIMISM_KOVAN_RPC="https://kovan.optimism.io/"
```

Now we're ready!

### Deploying a governance compatible ERC20 Token

Deploy the `L1VotingERC20` contract. This contract implemented [ERC20Votes.sol](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/ERC20Votes.sol), which enables onchain governance. It is necessary to avoid several different governance attacks.

```sh
NAME="RollCallDAO" SYMBOL="DAO" ./deploy-token.sh
export L1_TOKEN_ADDRESS=<L1VotingERC20Address>
```

### Deploying the treasury

Next, we'll deploy a treasury to manage the DAOs assets. The treasury is a simple smart contract that holds our assets and can be controlled by the DAO.

```sh
./deploy-treasury.sh
export TREASURY_ADDRESS=<TreasuryAddress>
```

### Distribute some funds

Now lets mint some tokens to the treasury:

```sh
cast send "$L1_TOKEN_ADDRESS" 'mint(address,uint256)' "$TREASURY_ADDRESS" 1000000000000000000000000 --private-key $ETH_PRIVATE_KEY --rpc-url $KOVAN_RPC
```

And some to ourself:

```sh
cast send "$L1_TOKEN_ADDRESS" 'mint(address,uint256)' "$ETH_PUBLIC_KEY" 1000000000000000000000000 --private-key $ETH_PRIVATE_KEY --rpc-url $KOVAN_RPC
```

Wow. We're rich now.

### Deploying Governance to Optimism

Next up, we want to deploy a Governor contract to Optimism that we can use to create and vote on proposals that will ultimately get executed on Layer 1.

The first thing we'll need it a Layer 2 token to vote with. To support thing, we'll need to deploy a Layer 2 ERC20 token that supports voting and will hold bridged token state.

```sh
NAME="RollCallDAO" SYMBOL="DAO" ./deploy-l2-token.sh
export L2_TOKEN_ADDRESS=<L2VotingERC20Address>
```

Now we can deploy our Governance which will be controlled by the bridged ERC20 tokens:

```sh
./deploy-governor.sh
export GOVERNOR_ADDRESS=<GovernorAddress>
```

### Setting up the governance bridge

In order to execute a proposal from Layer 2, we'll need to setup a contract to "receive" the transaction on Layer 1. For that, we can use the RollCallExecutor. This contract will own the treasury and make sure that only proposals passed by the Layer 2 governance can interact with it.

```sh
./deploy-exector.sh
export EXECUTOR_ADDRESS=<ExectorAddress>
```

Next, we'll set the executor as pending admin of the treasury which we'll finalize using our Layer 2 DAO.

```sh
cast send $TREASURY_ADDRESS 'setPendingAdmin(address)' $EXECUTOR_ADDRESS --private-key $ETH_PRIVATE_KEY --rpc-url $KOVAN_RPC
```

### Bridging tokens to Optimsim

Now that we have token contracts on both sides, we can leverage the optimism bridge to send them from Layer 1 to Layer 2.

First, we'll approve the Layer 1 Bridge to access our tokens:

```sh
cast send "$L1_TOKEN_ADDRESS" 'approve(address,uint256)' 0x22F24361D548e5FaAfb36d1437839f080363982B 1000000000000000000000000 --private-key $ETH_PRIVATE_KEY --rpc-url $KOVAN_RPC
```

Next, we'll bridge 'em over:

```sh
cast send 0x22F24361D548e5FaAfb36d1437839f080363982B 'depositERC20(address,address,uint256,uint32,bytes)' "$L1_TOKEN_ADDRESS" "$L2_TOKEN_ADDRESS" 1000000000000000000000000 2000000 0x --private-key $ETH_PRIVATE_KEY --rpc-url $KOVAN_RPC
```

Give it a couple mins, then you should be able to see them show up on the other side:

```sh
echo https://kovan-optimistic.etherscan.io/token/$L2_TOKEN_ADDRESS
```

✨ MAGIC ✨

#### Creating a proposal on L2

Alright, we're getting close! Let's create a proposal for the Layer 2 Governance to take control of the Layer 1 treasury.

For this, we're going to encode some calldata to pass the executor functions. There will be a few nested calls to make it all happen, lets walk through them:

```sh
# Get the calldata for the accept pending admin call, in this case, just the function selector
cast calldata 'acceptPendingAdmin()'
# Get the calldata for the executor, which will call the pending admin function to take control.
cast calldata 'execute(address,bytes)' $TREASURY_ADDRESS $(cast calldata 'acceptPendingAdmin()')
# Get the calldata for the Layer 2 CrossDomainBridge which will bridge our execution bundle to Layer 1.
cast calldata 'sendMessage(address,bytes,uint32)' $EXECUTOR_ADDRESS $(cast calldata 'execute(address,bytes)' $TREASURY_ADDRESS $(cast calldata 'acceptPendingAdmin()')) 1000000
```

Alright, lets put it all together:

```sh
cast send "$GOVERNOR_ADDRESS" 'propose(address[],uint256[],bytes[],string)' '[0x4200000000000000000000000000000000000007]' '[0]' "[$(cast calldata 'sendMessage(address,bytes,uint32)' $EXECUTOR_ADDRESS $(cast calldata 'execute(address,bytes)' $TREASURY_ADDRESS $(cast calldata 'acceptPendingAdmin()')) 1000000)]" 'Accept pending admin' --private-key $ETH_PRIVATE_KEY --rpc-url $OPTIMISM_KOVAN_RPC
```

cast send 0xd770a3f3f45a3661625f4a173828679fc893c28d 'propose(address[],uint256[],bytes[],string)' '[4200000000000000000000000000000000000007]' '[0]' '[3dbb202b000000000000000000000000102df41f25ad04cf4a97b96728f9dd0073212d33000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000000841cff79cd000000000000000000000000f330b5d17cb34bbdb1453efbb8592c2c220e164700000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000004709920c10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000]' 'Accept pending admin' --private-key 020d80f7ed3351219c496dcc4c5bf8a981c207d531310c8d0992bdea8cf02be3 --rpc-url https://kovan.optimism.io/