# Rollcall Workshop

The best place for a DAO's assets is usually L1, the main Ethereum network.
It is still the central place for defi transactions, to spend assets on what the DAO needs, etc.
Unfortunately, L1 transactions are very expensive which is a disincentive to vote. 
It makes sense for the vote to take place where they can be cheaper, for example [Optimism](https://www.optimism.io/).

Rollcall lets you do exactly that. It lets a DAO hold a vote on Optimism, and then use the results to control a treasury on L1.


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

## Setup

These steps are not really part of Rollcall, but they are the environment setup that lets us use Rollcall. 
As they are standard Ethereum tasks, will automate them to the extent possible.


### Software installation

1. Run the command below to install [the Foundry toolchain](https://github.com/gakonst/foundry):

   ```sh
   curl -L https://foundry.paradigm.xyz | bash
   ```

2. In a new terminal session (or after reloading your `PATH`), run the installer to get the foundry tools.

   ```sh
   foundryup
   ```

3. Clone this repo and install the dependencies:

   ```sh
   git clone https://github.com/withtally/rollcall.git
   cd rollcall
   # install dependencies
   forge install
```

   **Note:** You may see the following error on MacOS:

   ```
   dyld: Library not loaded: /usr/local/opt/libusb/lib/libusb-1.0.0.dylib
   ```

   In order to fix this, install `libusb` and then restart the dependency installation.

   ```sh
   brew install libusb
   forge install
   ```


### Configure the prerequisites

Execute this command:

```sh
. ./setup.sh
```

This command performs multiple necessary setup steps.
You run it with a dot and a space before it to make it run in the context of the current shell, so it will be able to change your environment variables.

The `setup.sh` script performs these tasks:

1. Create a new wallet, a new identity with an address and a private key.
1. Ask the user to go to [the Paradigm faucet](https://faucet.paradigm.xyz/) to provide ETH for the new wallet on both the Kovan test network and the Optimistic Kovan test network.
   Until that ETH is received, the setup script waits.
1. Ask the user to import the new wallet to MetaMask [using these directions](https://metamask.zendesk.com/hc/en-us/articles/360015489331-How-to-import-an-Account) and then press Enter to continue.
1. Create an ERC-20 voting token to represent control of the DAO on L1.
1. Create a DAO Treasury contract on L1 to represent the DAO's assets.
1. Mint DAO control tokens for both the wallet and the treasury.
1. Create an L2 ERC-20 voting token to represent control of the DAO on L2.
1. Transfer the wallet's DAO control tokens to L2.
1. Delegate the wallet's voting tokens to let it vote for itself.


### The L2 governance contract

Now that we have the prerequisites set, we can deploy [the governance contract](https://github.com/withtally/rollcall/blob/main/src/extensions/SimpleL2Governor.sol).
This is where we start using rollcall, so from this point onwards we run the commands ourselves.

1. Deploy the L2 governance contract:

   ```sh
   TEMP_FNAME=/tmp/delme.$$
   forge create SimpleL2Governor \
      --constructor-args $L2_TOKEN_ADDRESS 1 300 0 10 \
      --rpc-url $OPTIMISM_KOVAN_RPC --private-key $ETH_PRIVATE_KEY | tee $TEMP_FNAME
   ```

1. Store the contract address in an environment variable

   ```sh
   export L2_GOVERNANCE_ADDRESS=`cat $TEMP_FNAME | awk  '/Deployed to:/ {print $3}'`
   ```

#### What do the parameters means?

Let's look at [the constructor](https://github.com/withtally/rollcall/blob/main/src/extensions/SimpleL2Governor.sol#L20-L31) to see what the parameters we provider in `--constructor-args` mean.

```solidity
    constructor(
        ERC20Votes _token,
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorumNumeratorValue
    )
        L2Governor("RollCallGovernor")
        L2GovernorSettings(_votingDelay, _votingPeriod, _proposalThreshold)
        L2GovernorVotes(_token)
        L2GovernorVotesQuorumFraction(_quorumNumeratorValue)
    {}
```

| Parameter             | Value             | Meaning |
| --------------------- | ----------------: | - |
| _token                | $L2_TOKEN_ADDRESS | The ERC-20 that entitles an owner to vote in this contract |
| _votingDelay          | 1                 | Delay from when a proposal is received to when it can be voted upon (in seconds) - [see here](https://github.com/withtally/rollcall/blob/main/src/standards/L2Governor.sol#L280-L281)
| _votingPeriod         | 300               | Delay from when voting starts to when it ends (in seconds) - [see here](https://github.com/withtally/rollcall/blob/main/src/standards/L2Governor.sol#L280-L281)
| _proposalThreshold    | 0                 | Number of votes required to allow a voter to propose resolutions - [see here](https://github.com/withtally/rollcall/blob/main/src/standards/L2Governor.sol#L252-L255)
| _quorumNumeratorValue | 10                | The percent of the votes required for the vote to be valid - [see here](https://github.com/withtally/rollcall/blob/main/src/standards/L2GovernorVotesQuorumFraction.sol#L47-L60)

Without the proposal threshold, an attack would buy the equivalent of 1 wei of the voting token and use that to spam with irrelevant proposals.
Without the quorum numerator, it would be possible to hold "stealth votes" when very few voters are aware of them, and pass proposals that don't have sufficient support.


### The governance bridge

A vote on L2 is not going to do any good if the results cannot be communicated back to the treasury on L1.
The next step is to deploy a bridge on L1, called [the executor](https://github.com/withtally/rollcall/blob/main/src/Executor.sol), to accept the results and forward them to the treasury.

1. Deploy the executor contract:

   ```sh
      forge create Executor \
         --constructor-args $Proxy__OVM_L1CrossDomainMessenger $L2_GOVERNANCE_ADDRESS \
         --rpc-url $KOVAN_RPC --private-key $ETH_PRIVATE_KEY | tee $TEMP_FNAME
   ```

1. Store the contract address in an environment variable:

   ```sh
   export EXECUTOR_ADDRESS=`cat $TEMP_FNAME | awk  '/Deployed to:/ {print $3}'`
   ```

1. Tell the treasury that it needs to obey the executor

   ```sh
   cast send $TREASURY_ADDRESS 'setPendingAdmin(address)' $EXECUTOR_ADDRESS \
      --private-key $ETH_PRIVATE_KEY --rpc-url $KOVAN_RPC --confirmations 1
   ```

The executor's parameters are self-explanatory. Only accept calls from Optimism's $Proxy__OVM_L1CrossDomainMessenger (the address is specified in `setup.sh`), and only if their ultimate source on L2 is $L2_GOVERNANCE_ADDRESS.


## Proposals


### Creating a proposal

Ultimately, proposals that pass get a function executed by the treasury contract on L1. 
However, we need to wrap that function call in a message to the executor on L1 (the only contract the treasury obeys), which itself needs to be wrapped in a message to the bridge on L2 so that the bridge on L1 will receive it and forward it to that executor.


1. The proposal is to run [`acceptPendingAdmin()`](https://github.com/withtally/rollcall/blob/main/src/Treasury.sol#L26-L36) on the treasury. 

   ```sh
   TREASURY_CALL=`cast calldata 'acceptPendingAdmin()'`
   echo $TREASURY_CALL
   ```

1. The way to get the executor to relay this message is to use [`execute(address,bytes)`] (https://github.com/withtally/rollcall/blob/main/src/Executor.sol#L20-L30).

   ```sh
   EXECUTOR_CALL=`cast calldata 'execute(address,bytes)' $TREASURY_ADDRESS $TREASURY_CALL`
   echo $EXECUTOR_CALL
   ```

   Notice that you can see the treasury call inside the executor call.

1. The way to get the bridge to relay the message to the executor is to use [`sendMessage(address,bytes,uint32)`](https://github.com/ethereum-optimism/optimism/blob/develop/packages/contracts/contracts/L2/messaging/L2CrossDomainMessenger.sol#L53-L70).

   ```sh
   BRIDGE_CALL=`cast calldata 'sendMessage(address,bytes,uint32)' $EXECUTOR_ADDRESS $EXECUTOR_CALL 1000000`
   echo $BRIDGE_CALL
   ```
   

1. To actually propose the proposal, we need to call [`propose` on the governor contract](https://github.com/withtally/rollcall/blob/main/src/standards/L2Governor.sol#L243-L300).
   This function lets us put multiple calls in the same proposal, so most of the proposal data (except for the description) is in arrays.
   However, we need to remove the `0x` header before the values first.

   ```sh
   BRIDGE_CALL_2=`echo $BRIDGE_CALL | cut -c 3-`
   L2CrossDomainMessenger_2=`echo $L2CrossDomainMessenger | cut -c 3-`
   DESCRIPTION='run pendingAdmin()'
   PROPOSAL=`cast calldata 'propose(address[],uint256[],bytes[],string)' \
      '['$L2CrossDomainMessenger_2']' '[0]' '['$BRIDGE_CALL_2']' $DESCRIPTION`
   echo $PROPOSAL
   ```

1. Finally, we can send out the proposal.
   We could have created the proposal in the `cast send` and saved a step, but this is a workshop and readability is much more important than efficiency.

   ```sh
      cast send $L2_GOVERNANCE_ADDRESS $PROPOSAL --private-key $ETH_PRIVATE_KEY --rpc-url $OPTIMISM_KOVAN_RPC --legacy
   ```

1. To see information about the proposal and to vote on it we need to get the proposal hash.
   There are two ways to do this:

   1. We can call [the governor's `hashProposal` function](https://github.com/withtally/rollcall/blob/main/src/standards/L2Governor.sol#L98-L123):

      ```sh
      cast call $L2_GOVERNANCE_ADDRESS 'hashProposal(address[],uint256[],bytes[],bytes32)' \
         '['$L2CrossDomainMessenger_2']' '[0]' '['$BRIDGE_CALL_2']' \
         `cast keccak $DESCRIPTION` \
         --private-key $ETH_PRIVATE_KEY --rpc-url $OPTIMISM_KOVAN_RPC
      ```

   1. We can also copy at the transaction hash of the previous transaction and search for it on [Etherscan](https://kovan-optimistic.etherscan.io/). 
      Click **Logs (1)**, and the first data field is the proposal hash.
      For example, if you go to [this proposal I submitted previously](https://kovan-optimistic.etherscan.io/tx/0x9e47d7094faf3a55388f3f88138139fff5588361860887e32da9f2b0015f67c3#eventlog), you will see that the policy hash is `04dc4ff05942fd0d3e89a7daaeef42b7da399b0fdd915b9509c7e5d1be4f77a7`

   In either case, please set `$PROPOSAL_ID` to the proposal's hash. We will need this information soon.
   ```sh
   PROPOSAL_ID= <your value goes here, without the leading "0x">
   ```



### Voting on a proposal

Use the [`castVote(uint256,uint8)`](https://github.com/withtally/rollcall/blob/main/src/standards/L2Governor.sol#L384-L395) function.


```sh
VOTE=1
cast send $L2_GOVERNANCE_ADDRESS 'castVote(uint256,uint8)' $PROPOSAL_ID $VOTE --private-key $ETH_PRIVATE_KEY --rpc-url $OPTIMISM_KOVAN_RPC --chain optimism-kovan --confirmations 1
```

The values for the vote are:

| Value | Meaning |
| ----: | ------- |
| 0 | Against |
| 1 | For |
| 2 | Abstain |

### Checking a proposal's state

You check the state of a proposal using:

```sh
cast call $L2_GOVERNANCE_ADDRESS 'state(uint256)' $PROPOSAL_ID --rpc-url $OPTIMISM_KOVAN_RPC
```

Here is the table to interpret the results:

| State      | state($PROPOSAL_ID) result |
| ---------- | -------------------------- |
| Pending    |    0
| Active     |     1
| Canceled   | 2
| Defeated   | 3
| Succeeded  | 4
| Queued     | 5
| Expired    | 6
| Executed   | 7


### After a proposal has passed

Once a proposal has passed (state `4`), you still need to issue two transactions:

1. Tell the governor on L2 to [`execute()`](https://github.com/withtally/rollcall/blob/main/src/standards/L2Governor.sol#L302-L330) the proposal.
   Remember, nothing happens on a blockchain automatically - it is *all* the results of transactions. 

   ```sh
   cast send $L2_GOVERNANCE_ADDRESS 'execute(address[],uint256[],bytes[],bytes32)' \
      '['$L2CrossDomainMessenger_2']' '[0]' '['$BRIDGE_CALL_2']' \
      `cast keccak $DESCRIPTION` \
      --private-key $ETH_PRIVATE_KEY --rpc-url $OPTIMISM_KOVAN_RPC --legacy \
      --gas 2000000
   ```

   Make sure to write down the transaction hash.

1. Once the fault proof window has passed (a minute on Kovan, seven days on the production network), claim the transaction on L1:

   1. Browse to [the message relayer](https://kovan-optimistic.etherscan.io/messagerelayer).
   1. Search for your transaction hash from the previous step. 
   1. Ignore the fact that no tokens are found. Click **Execute** and then **Confirm**.
   1. Approve the transaction in the wallet. 
      This is the reason `setup.sh` asked you to import your private key into your wallet.


To verify the proposal was successfully relayed, make sure that the result of [the treasury's `admin()` method](https://github.com/withtally/rollcall/blob/main/src/Treasury.sol#L26-L36) are the same as the executor's address.

```sh
cast call "$TREASURY_ADDRESS" 'admin()(address)' --rpc-url="$KOVAN_RPC"
echo $EXECUTOR_ADDRESS
```

Whew. We're done! You now have a treasury on Layer 1 that you can manage with a DAO on Layer 2. This means proposal creation and voting can be done fast and cheap!
