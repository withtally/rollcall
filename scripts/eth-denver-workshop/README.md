# EthDenver Workshop

In this exercise, we'll deploy a [treasury](../../src/Treasury.sol) contract to mainnet and a [L2Governor DAO](../../src/standards/L2Governor.sol) contract to [Optimism](https://www.optimism.io/). We will then control the mainnet treasury with the Governor on Optimism. The goal is to demonstrate a hybrid model where a protocol can exist on mainnet but be managed from a rollup, enabling cheaper participation in governance decisions.

## Sequence Diagram

```
┌──────┐                                         ┌──────────┐     ┌───────────┐
│Client│                                         │L2Governor│     │L1 Executor│
└──┬───┘                                         └────┬─────┘     └───────────┘
   │                                                  │                 │
   │ propose(...)                                     │                 │
   ├─────────────────────────────────────────────────►│                 │
   │                                                  │                 │
   │ vote (...)                                       │                 │
   ├─────────────────────────────────────────────────►│                 │
   │                                                  │                 │
   │ queue (...)                                      │                 │
   ├─────────────────────────────────────────────────►│                 │
   │                                                  │                 │
   │ execute(...)                                     │                 │
   ├─────────────────────────────────────────────────►│                 │
   │                                                  │                 │
   │                                                  │ bridge execute  │
   │                                                  │────────────────►│
```

## Getting Started

### Install foundry

First run the command below to get `foundryup`, the Foundry toolchain installer:

```sh
curl -L https://foundry.paradigm.xyz | bash
```

Then, in a new terminal session or after reloading your `PATH`, run it to get the latest `forge` and `cast` binaries:

```sh
foundryup
```

### Setup Exercise

Clone this repo

```sh
git clone git@github.com:withtally/rollcall.git
# install dependencies
forge install
# move to workshop folder
cd scripts/eth-denver-workshop/
```

#### `libusb` error when running `forge`/`cast`

If you are using the binaries as released, you may see the following error on MacOS:

```
dyld: Library not loaded: /usr/local/opt/libusb/lib/libusb-1.0.0.dylib
```

In order to fix this, you must install `libusb` like so:

```sh
brew install libusb
```

### Create a wallet

```sh
> cast wallet new
Successfully created new keypair.
Address: <public key>
Private Key: <private key>
```

Replace `<public key>` and `<private key>` with the output of the `cast wallet new` command above. Be sure to remove the trailing period.

```sh
# Export private key to simplify the scripts
export ETH_PUBLIC_KEY=<public key>
export ETH_PRIVATE_KEY=<private key>
```

Import your private key into metamask: https://metamask.zendesk.com/hc/en-us/articles/360015489331-How-to-import-an-Account

Get some testnet funds using the address generated above, be sure to "Drip additional networks": https://faucet.paradigm.xyz/

If you need more funds, dm me your address at https://twitter.com/tarrenceva

### Setup environment

```sh
export KOVAN_RPC="https://eth-kovan.alchemyapi.io/v2/dLtG6qAIvETZ7OKf4hoILCfKTN3rsRaK"
export OPTIMISM_KOVAN_RPC="https://kovan.optimism.io/"
```

Now we're ready!

### Deploying a governance compatible ERC20 Token

Deploy the `L1VotingERC20` contract. This contract implemented [ERC20Votes.sol](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/ERC20Votes.sol), which enables onchain governance. It is necessary to avoid several different governance attacks.

```sh
NAME="RollCallDAO" SYMBOL="DAO" ./deploy-l1-token.sh
export L1_TOKEN_ADDRESS=<L1VotingERC20Address>
```

## Workshop

### Deploying the treasury

Next, we'll deploy a treasury to manage the DAOs assets. The treasury is a simple smart contract that holds our assets and can be controlled by the DAO.

```sh
./deploy-l1-treasury.sh
export TREASURY_ADDRESS=<TreasuryAddress>
```

### Distribute some funds

Now lets mint some tokens to the treasury:

```sh
cast send "$L1_TOKEN_ADDRESS" 'mint(address,uint256)' "$TREASURY_ADDRESS" 1000000000000000000000000 --private-key $ETH_PRIVATE_KEY --rpc-url $KOVAN_RPC --confirmations 1
```

And some to ourself:

```sh
cast send "$L1_TOKEN_ADDRESS" 'mint(address,uint256)' "$ETH_PUBLIC_KEY" 1000000000000000000000000 --private-key $ETH_PRIVATE_KEY --rpc-url $KOVAN_RPC --confirmations 1
```

Wow. We're rich now.

### Deploying Governance to Optimism

Next up, we want to deploy a Governor contract to Optimism that we can use to create and vote on proposals that will ultimately get executed on Layer 1.

The first thing we'll need is a Layer 2 token to vote with. To support this, we'll deploy a ERC20 voting token that will hold bridged token state.

```sh
NAME="RollCallDAO" SYMBOL="DAO" ./deploy-l2-token.sh
export L2_TOKEN_ADDRESS=<L2VotingERC20Address>
```

Now we can deploy our Governance which will be controlled by the bridged ERC20 tokens:

```sh
./deploy-l2-governor.sh
export GOVERNOR_ADDRESS=<GovernorAddress>
```

### Setting up the governance bridge

In order to execute a proposal from Layer 2, we'll setup a contract to "receive" the transaction on Layer 1. For that, we can use the Executor. This contract will own the treasury and make sure that only proposals passed by the Layer 2 governance can interact with it.

```sh
./deploy-l1-exector.sh
export EXECUTOR_ADDRESS=<ExectorAddress>
```

Next, we'll set the executor as the pending admin of the treasury which we'll finalize using our Layer 2 DAO.

```sh
cast send $TREASURY_ADDRESS 'setPendingAdmin(address)' $EXECUTOR_ADDRESS --private-key $ETH_PRIVATE_KEY --rpc-url $KOVAN_RPC --confirmations 1
```

### Bridging tokens to Optimism

Now that we have token contracts on both sides, we can leverage the optimism bridge to send them from Layer 1 to Layer 2.

First, we'll approve the Layer 1 Bridge to access our tokens:

```sh
cast send "$L1_TOKEN_ADDRESS" 'approve(address,uint256)' 0x22F24361D548e5FaAfb36d1437839f080363982B 1000000000000000000000000 --private-key $ETH_PRIVATE_KEY --rpc-url $KOVAN_RPC --confirmations 1
```

Next, we'll bridge 'em over:

```sh
cast send 0x22F24361D548e5FaAfb36d1437839f080363982B 'depositERC20(address,address,uint256,uint32,bytes)' "$L1_TOKEN_ADDRESS" "$L2_TOKEN_ADDRESS" 1000000000000000000000000 2000000 0x --private-key $ETH_PRIVATE_KEY --rpc-url $KOVAN_RPC --confirmations 1
```

Give it a couple mins, then you should be able to see them show up on the other side:

```sh
open https://kovan-optimistic.etherscan.io/token/$L2_TOKEN_ADDRESS#balances
```

✨ MAGIC ✨

Finally, lets delegate them to ourselves so we can use them for voting:

```sh
cast send $L2_TOKEN_ADDRESS 'delegate(address)' $ETH_PUBLIC_KEY --private-key $ETH_PRIVATE_KEY --rpc-url $OPTIMISM_KOVAN_RPC --chain optimism-kovan --confirmations 1
```

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

Alright, let's put it all together:

```sh
cast send "$GOVERNOR_ADDRESS" 'propose(address[],uint256[],bytes[],string)' '[4200000000000000000000000000000000000007]' '[0]' "[$(cast calldata 'sendMessage(address,bytes,uint32)' $EXECUTOR_ADDRESS $(cast calldata 'execute(address,bytes)' $TREASURY_ADDRESS $(cast calldata 'acceptPendingAdmin()')) 1000000 | cut -c 3-)]" 'Accept pending admin' --private-key $ETH_PRIVATE_KEY --rpc-url $OPTIMISM_KOVAN_RPC --chain optimism-kovan --confirmations 1
```

Get the proposal id:

```sh
cast call "$GOVERNOR_ADDRESS" 'hashProposal(address[],uint256[],bytes[],bytes32)(uint256)' '[4200000000000000000000000000000000000007]' '[0]' "[$(cast calldata 'sendMessage(address,bytes,uint32)' $EXECUTOR_ADDRESS $(cast calldata 'execute(address,bytes)' $TREASURY_ADDRESS $(cast calldata 'acceptPendingAdmin()')) 1000000 | cut -c 3-)]" $(cast keccak 'Accept pending admin') --rpc-url $OPTIMISM_KOVAN_RPC --chain optimism-kovan
export PROPOSAL_ID=<proposal id>
```

Next we'll vote to support the proposal:

```sh
cast send "$GOVERNOR_ADDRESS" 'castVote(uint256,uint8)' $PROPOSAL_ID 1 --private-key $ETH_PRIVATE_KEY --rpc-url $OPTIMISM_KOVAN_RPC --chain optimism-kovan --confirmations 1
```

Lets check the proposal state:

```sh
cast call "$GOVERNOR_ADDRESS"  'state(uint256)(uint8)' $PROPOSAL_ID --rpc-url $OPTIMISM_KOVAN_RPC --chain optimism-kovan
```

States:
   Pending:    0
   Active:     1
   Canceled:   2
   Defeated:   3
   Succeeded:  4
   Queued:     5
   Expired:    6
   Executed:   7

Once it has passed (state 4), we can execute the proposal:

```sh
cast send "$GOVERNOR_ADDRESS" 'execute(address[],uint256[],bytes[],bytes32)' '[4200000000000000000000000000000000000007]' '[0]' "[$(cast calldata 'sendMessage(address,bytes,uint32)' $EXECUTOR_ADDRESS $(cast calldata 'execute(address,bytes)' $TREASURY_ADDRESS $(cast calldata 'acceptPendingAdmin()')) 1000000 | cut -c 3-)]" $(cast keccak 'Accept pending admin') --private-key $ETH_PRIVATE_KEY --rpc-url $OPTIMISM_KOVAN_RPC --chain optimism-kovan --confirmations 1
```

Now our transaction is on its way back to mainnet. For Kovan, this takes 60 seconds. The final step will be executing the bridged transaction on mainnet:

To finalize it, we can use Etherscans L2 to L1 Relay:

https://kovan-optimistic.etherscan.io/messagerelayer

Copy the transaction hash from above, make sure your metamask has an account with eth and has kovan network selected, and click execute.

Finally, we can verify that our treasury is now controlled by the executor which is controlled by the Layer 2 DAO.

```sh
cast call "$TREASURY_ADDRESS" 'admin()(address)' --rpc-url="$KOVAN_RPC"
echo $EXECUTOR_ADDRESS
```

Whew. We're done! You now have a treasury on Layer 1 that you can manage with a DAO on Layer 2. This means proposal creation and voting can be done fast and cheap!

## Follow up

### Layer 2 Treasury

As a follow up exercise, lets use what we've learned to deploy a Layer 2 Treasury that can be managed by the governor and transfer our Layer 1 tokens to it.

#### Deploying a Layer 2 Treasury

Duplicate the `deploy-l1-treasury.sh`, creating `deploy-l2-treasury.sh`, and modify the RPC to point to optimism.

#### Configure ownership

First, set the pending admin of the layer 2 treasury to `$GOVERNOR_ADDRESS`. Then, create a proposal for governor to accept the admin. This proposal will be similar to [the previous proposal](https://github.com/withtally/rollcall/tree/main/scripts/eth-denver-workshop#creating-a-proposal-on-l2) that took ownership of the layer 1 treasury, however, it doesn't need to go through the bridge.

#### Bridging the tokens

Next, bridge the layer 1 treasury tokens to layer 2. In order to do this, we can create a proposal, similar to the original accept admin proposal for the layer 1 treasury, but with [two execution payloads that approve and then bridge the tokens to our layer 2 treasury](https://github.com/withtally/rollcall/tree/main/scripts/eth-denver-workshop#bridging-tokens-to-optimism).

## NFT Airdrop

Thanks for joining us! As a reward, we're giving out a free Optimism based NFT.

![tallyxoptimsim](../../.github/assets/tallyxoptimism.gif)
