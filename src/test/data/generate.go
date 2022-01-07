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
	AccountProof []string        `json:"accountProof"`
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
var height = flag.Int64("height", 13934596, "block height")

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

	keys := []string{key.Hex()}

	blockHeight := big.NewInt(*height)

	header, err := ethClient.HeaderByNumber(ctx, blockHeight)
	if err != nil {
		log.Fatalf("getting block header: %+v", err)
	}

	var resp StorageProof
	if err := ethRPC.Call(
		&resp,
		"eth_getProof",
		common.HexToAddress(*contract),
		keys,
		hexutil.EncodeBig(blockHeight),
	); err != nil {
		log.Fatalf("getting storage proof: %+v", err)
	}

	resp.StateRoot = header.Root
	resp.Height = header.Number

	headerRLP, err := rlp.EncodeToBytes(header)
	if err != nil {
		log.Fatalf("encoding header rlp: %+v", err)
	}

	println("Block Hash:\n", header.Hash().Hex())
	println("Block header:\n", hexutil.Encode(headerRLP))
	println("State Root:\n", resp.StateRoot.Hex())
	println("Storage Hash:\n", resp.StorageHash.Hex())
	println("Storage Key:\n", key.Hex())
	println("Storage Value:\n", resp.StorageProof[0].Value)

	accountProof := make([][][][]byte, 1)
	for _, p := range resp.AccountProof {
		bz, err := hexutil.Decode(p)
		if err != nil {
			log.Fatalf("decoding node hex: %+v", err)
		}
		var val [][]byte
		if err := rlp.DecodeBytes(bz, &val); err != nil {
			log.Fatalf("decoding node rlp: %+v", err)
		}
		accountProof[0] = append(accountProof[0], val)
	}

	accountProofRLP, err := rlp.EncodeToBytes(accountProof)
	if err != nil {
		log.Fatalf("encoding rlp: %+v", err)
	}

	println("Account Proof:\n", hexutil.Encode(accountProofRLP))

	var storageProof [][][]byte
	for _, p := range resp.StorageProof[0].Proof {
		bz, err := hexutil.Decode(p)
		if err != nil {
			log.Fatalf("decoding node hex: %+v", err)
		}
		var val [][]byte
		if err := rlp.DecodeBytes(bz, &val); err != nil {
			log.Fatalf("decoding node rlp: %+v", err)
		}
		storageProof = append(storageProof, val)
	}

	storageProofRLP, err := rlp.EncodeToBytes(storageProof)
	if err != nil {
		log.Fatalf("encoding rlp: %+v", err)
	}

	println("Storage Proof:\n", hexutil.Encode(storageProofRLP))
}
