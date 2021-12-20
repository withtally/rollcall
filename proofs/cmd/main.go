package main

import (
	"context"
	"encoding/json"
	"flag"
	"log"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/vocdoni/storage-proofs-eth-go/helpers"
	"github.com/vocdoni/storage-proofs-eth-go/token"
	"github.com/vocdoni/storage-proofs-eth-go/token/erc20"
	"github.com/vocdoni/storage-proofs-eth-go/token/mapbased"
	"github.com/vocdoni/storage-proofs-eth-go/token/minime"
)

const timeout = 60 * time.Second

func main() {
	web3 := flag.String("web3", "https://web3.dappnode.net", "web3 RPC endpoint URL")
	contract := flag.String("contract", "", "ERC20 contract address")
	holder := flag.String("holder", "", "address of the token holder")
	contractType := flag.String("type", "mapbased", "ERC20 contract type (mapbased, minime)")
	height := flag.Int64("height", 0, "ethereum height (0 becomes last block)")
	flag.Parse()

	var contractAddr common.Address
	if err := contractAddr.UnmarshalText([]byte(*contract)); err != nil {
		log.Fatal(err)
	}
	var holderAddr common.Address
	if err := holderAddr.UnmarshalText([]byte(*holder)); err != nil {
		log.Fatal(err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	rpcCli, err := rpc.DialContext(ctx, *web3)
	if err != nil {
		log.Fatal(err)
	}
	ts, err := erc20.New(ctx, rpcCli, contractAddr)
	if err != nil {
		log.Fatal(err)
	}
	tokenData, err := ts.GetTokenData(ctx)
	if err != nil {
		log.Fatal(err)
	}
	decimals := int(tokenData.Decimals)

	balance, err := ts.Balance(ctx, holderAddr)
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("contract:%v holder:%v balance:%s", contractAddr, holderAddr,
		balance.FloatString(decimals))
	if balance.Cmp(big.NewRat(0, 1)) == 0 {
		log.Println("no amount for holder")
		return
	}

	var ttype int
	switch *contractType {
	case "mapbased":
		ttype = token.TokenTypeMapbased
	case "minime":
		ttype = token.TokenTypeMinime
	default:
		log.Fatalf("token type not supported %s", *contractType)
	}

	t, err := token.New(ctx, rpcCli, ttype, contractAddr)
	if err != nil {
		log.Fatal(err)
	}
	slot, amount, err := t.DiscoverSlot(ctx, holderAddr)
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("storage data -> slot: %d amount: %s", slot, amount.FloatString(decimals))

	var blockNum *big.Int
	if *height > 0 {
		blockNum = new(big.Int).SetInt64(*height)
	} else {
		blockNumUint64, err := ts.EthCli.BlockNumber(ctx)
		if err != nil {
			log.Fatal(err)
		}
		blockNum = new(big.Int).SetUint64(blockNumUint64)
	}
	sproof, err := t.GetProof(ctx, holderAddr, blockNum, slot)
	if err != nil {
		log.Fatalf("cannot get proof: %v", err)
	}

	switch ttype {
	case token.TokenTypeMinime:
		balance, fullBalance, block := minime.ParseMinimeValue(
			sproof.StorageProof[0].Value,
			int(tokenData.Decimals),
		)
		log.Printf("balance on block %v: %s", block, balance.FloatString(decimals))
		log.Printf("hex balance: %x\n", fullBalance.Bytes())
		log.Printf("storage root: %x\n", sproof.StorageHash)
		if err := minime.VerifyProof(
			holderAddr,
			sproof.StorageHash,
			sproof.StorageProof,
			slot,
			fullBalance,
			block,
		); err != nil {
			log.Fatal(err)
		}
	case token.TokenTypeMapbased:
		balance, fullBalance := helpers.ValueToBalance(
			sproof.StorageProof[0].Value,
			int(tokenData.Decimals),
		)
		log.Printf("mapbased balance on block %v: %s", blockNum,
			balance.FloatString(decimals))
		if err := mapbased.VerifyProof(
			holderAddr,
			sproof.StorageHash,
			sproof.StorageProof[0],
			slot,
			fullBalance,
			nil,
		); err != nil {
			log.Fatal(err)
		}
	default:
		log.Fatal("token type not supported")
	}

	sproofBytes, err := json.MarshalIndent(sproof, "", " ")
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("%s\n", sproofBytes)
	log.Println("proof is valid!")
}
