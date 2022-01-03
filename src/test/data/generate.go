package main

import (
	"context"
	"flag"
	"log"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/ethereum/go-ethereum/rpc"
)

type StorageProof struct {
	Height       *big.Int        `json:"height"`
	Address      common.Address  `json:"address"`
	Balance      *hexutil.Big    `json:"balance"`
	CodeHash     common.Hash     `json:"codeHash"`
	Nonce        hexutil.Uint64  `json:"nonce"`
	StateRoot    common.Hash     `json:"stateRoot"`
	StorageHash  common.Hash     `json:"storageHash"`
	StorageProof []StorageResult `json:"storageProof"`
}

type StorageResult struct {
	Key   string   `json:"key"`
	Value string   `json:"value"`
	Proof []string `json:"proof"`
}

var slot = flag.Int64("slot", 0, "storage slot for proof")
var contract = flag.String("contract", "", "contract address for proof")
var voter = flag.String("voter", "", "voter address for proof")

func main() {
	flag.Parse()
	ctx := context.Background()

	ethRPC, err := rpc.Dial("https://eth-mainnet.alchemyapi.io/v2/MdZcimFJ2yz2z6pw21UYL-KNA0zmgX-F")
	if err != nil {
		log.Fatalf("dailing eth rpc: %+v", err)
	}

	ethClient := ethclient.NewClient(ethRPC)

	address := common.HexToAddress(*voter)
	key := crypto.Keccak256Hash(
		common.LeftPadBytes(address[:], 32),
		common.LeftPadBytes(big.NewInt(*slot).Bytes(), 32),
	)

	println("Storage Key:\n", key.Hex())

	keys := []string{key.Hex()}

	height := big.NewInt(13843553)

	block, err := ethClient.BlockByNumber(ctx, height)
	if err != nil {
		log.Fatalf("getting block: %+v", err)
	}

	var resp StorageProof
	if err := ethRPC.Call(
		&resp,
		"eth_getProof",
		common.HexToAddress(*contract),
		keys,
		hexutil.EncodeBig(height),
	); err != nil {
		log.Fatalf("getting storage proof: %+v", err)
	}

	resp.StateRoot = block.Root()
	resp.Height = block.Header().Number

	var target [][][]byte
	for _, p := range resp.StorageProof[0].Proof {
		bz, err := hexutil.Decode(p)
		if err != nil {
			log.Fatalf("decoding node hex: %+v", err)
		}
		var val [][]byte
		if err := rlp.DecodeBytes(bz, &val); err != nil {
			log.Fatalf("decoding node rlp: %+v", err)
		}
		target = append(target, val)
	}

	encoded, err := rlp.EncodeToBytes(target)
	if err != nil {
		log.Fatalf("encoding rlp: %+v", err)
	}

	hex := hexutil.Encode(encoded)
	println("Proof:\n", hex)
}
