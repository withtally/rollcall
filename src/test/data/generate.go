package main

import (
	"context"
	"log"
	"math/big"

	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/vocdoni/storage-proofs-eth-go/ethstorageproof"
)

func main() {
	ctx := context.Background()

	ethRPC, err := rpc.Dial("https://eth-mainnet.alchemyapi.io/v2/MdZcimFJ2yz2z6pw21UYL-KNA0zmgX-F")
	if err != nil {
		log.Fatalf("dailing eth rpc: %+v", err)
	}

	ethClient := ethclient.NewClient(ethRPC)

	contract := "0x7ae1d57b58fa6411f32948314badd83583ee0e8c"
	keys := []string{"0x9f9913eb00db1630cca84a7a1706a631e771278c4f0ef0d2bdce02e5911598b6"}
	height := big.NewInt(13843551)

	block, err := ethClient.BlockByNumber(ctx, height)
	if err != nil {
		log.Fatalf("getting block: %+v", err)
	}

	var resp ethstorageproof.StorageProof
	if err := ethRPC.Call(
		&resp,
		"eth_getProof",
		contract,
		keys,
		hexutil.EncodeBig(height),
	); err != nil {
		log.Fatalf("getting storage proof: %+v", err)
	}

	resp.StateRoot = block.Root()
	resp.Height = block.Header().Number

	encoded, err := rlp.EncodeToBytes(resp.StorageProof)
	if err != nil {
		log.Fatalf("rlp encoding storage proof: %+v", err)
	}

	hex := hexutil.Encode(encoded)
	println(hex)
}
