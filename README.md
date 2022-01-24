# RollCall

RollCall is a set of cross chain governance solutions

- **RollCallExecutor**: Manage mainnet treasury from a governance on a rollup.
- **RollCallVoter**: Voting on mainnet governance proposals on a rollup.

## Quickstart

Install foundry

```
cargo install --git https://github.com/gakonst/foundry --bin forge --locked
```

Run tests

```
forge test --force --verbosity 4
```

## RollCallExecutor

Manage Ethereum mainnet (Layer 1) treasury from a governance on an Optimistic Rollups (Layer 2).

### Goals

1. Provide path for incremental migration of DAO Governance from Layer 1 to Layer 2.

### Sequence Diagram

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

## RollCallVoter

Voting on Ethereum mainnet (Layer 1) governance proposals on an Optimistic Rollups (Layer 2).

To do so, Layer 1 governance's implementation provides a set of weight mappings (`mapping(address => uint256)`) which are used to compute a voters weight. When a proposal is created, the storage root of the block is bridged to Layer 2 and voters can submit votes on Layer 2 using storage proofs.

### Goals

1. Reduce the overhead for participating in governance by reducing voting gas costs
2. Enable onchain governance for tokens which do not already support the snapshot functionality.
3. Provide a modular framework for governance voting, where vote weights can be pulled from one or more sources and is not limited to token voting exclusively.

### Sequence Diagram

```
┌──────┐                                          ┌──────────┐     ┌────────┐
│Client│                                          │L1Governor│     │L2 Voter│
└──┬───┘                                          └───┬──────┘     └────────┘
   │                                                  │                 │
   │ propose(...)                                     │                 │
   ├─────────────────────────────────────────────────►│                 │
   │                                                  │                 │
   │                                                  │ bridge proposal │
   │                                                  │────────────────►│
   │                                                  │                 │
   │ activate (proposal id, blockheaders)             │                 │
   ├──────────────────────────────────────────────────┼────────────────►│
   │                                                  │                 │
   │                                                  │                 │
   │ vote (proposal id, storage proof, support)       │                 │
   ├──────────────────────────────────────────────────┼────────────────►│
   │                                                  │                 │
   │                                                  │                 │
   │ queue (proposal id)                              │                 │
   ├──────────────────────────────────────────────────┼────────────────►│
   │                                                  │                 │
   │                                                  │  bridge votes   │
   │                                                  │◄────────────────│
   │                                                  │                 │
   │ execute(proposal id)                             │                 │
   ├─────────────────────────────────────────────────►│                 │
   │                                                  │                 │
```

### Deployment



## Generating Storage Proofs

Install [Golang](https://go.dev/doc/install).

Run the generate script with the desired contract, voter address, and mapping storage slot

```
go run src/test/data/generate.go -contract 0x7ae1d57b58fa6411f32948314badd83583ee0e8c -voter 0xba740c9035fF3c24A69e0df231149c9cd12BAe07 -slot 0
```
