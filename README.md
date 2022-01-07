# RollCall

RollCall is a cross chain voting solution which supports voting on Ethereum mainnet (Layer 1) governance proposals on Optimistic Rollups (Layer 2).

To do so, Layer 1 governance's implementation provides a set of weight mappings (`mapping(address => uint256)`) which are used to compute a voters weight. When a proposal is creating, the storage root of the block is bridged to Layer 2 and voters can submit votes on Layer 2 using storage proofs.

## Goals

1. Reduce the overhead for participating in governance by reducing voting gas costs
2. Enable onchain governance for tokens which do not already support the snapshot functionality.
3. Provide a modular framework for governance voting, where vote weights can be pulled from one or more sources and is not limited to token voting exclusively.

## Quickstart

Install foundry

```
cargo install --git https://github.com/gakonst/foundry --bin forge --locked
```

Run tests

```
forge test --force --verbosity 4
```

## Generating Storage Proofs

Install [Golang](https://go.dev/doc/install).

Run the generate script with the desired contract, voter address, and mapping storage slot

```
go run src/test/data/generate.go -contract 0x7ae1d57b58fa6411f32948314badd83583ee0e8c -voter 0xba740c9035fF3c24A69e0df231149c9cd12BAe07 -slot 0
```
