#! /bin/bash

# Configuration
export KOVAN_RPC=https://eth-kovan.alchemyapi.io/v2/dLtG6qAIvETZ7OKf4hoILCfKTN3rsRaK
export OPTIMISM_KOVAN_RPC=https://kovan.optimism.io/

# Optimism contract addresses taken from 
# https://github.com/ethereum-optimism/optimism/tree/develop/packages/contracts/deployments/kovan
export Proxy__OVM_L1StandardBridge=0x22F24361D548e5FaAfb36d1437839f080363982B
export Proxy__OVM_L1CrossDomainMessenger=0x4361d0F75A0186C05f971c566dC6bEa5957483fD
export L2CrossDomainMessenger=0x4200000000000000000000000000000000000007

echo Creating a new wallet

cast wallet new > /tmp/wallet.$$

export ETH_ADDRESS=`cat /tmp/wallet.$$ | awk '/Address:/ {print $2}' | sed 's/\.//' `
export ETH_PRIVATE_KEY=`cat /tmp/wallet.$$ | awk '/Private Key:/ {print $3}' | sed 's/\.//'`

rm /tmp/wallet.$$

echo
echo Please go to https://faucet.paradigm.xyz/ to fund address $ETH_ADDRESS
echo Select Drip on additional networks to get Optimistic Kovan ETH too

while [ `cast balance --rpc-url $OPTIMISM_KOVAN_RPC $ETH_ADDRESS` -eq 0 ] 
do 
   sleep 10
   echo Waiting for https://faucet.paradigm.xyz/ to fund $ETH_ADDRESS
done

echo 
echo Please import your wallet to Metamask
echo Follow the directions at https://metamask.zendesk.com/hc/en-us/articles/360015489331-How-to-import-an-Account
echo Your private key is 0x$ETH_PRIVATE_KEY
echo And then press Enter here
read

echo Creating an ERC20 voting token on L1
export NAME=RollCallDAO
export SYMBOL=DAO
export L1_TOKEN_ADDRESS=`forge create L1VotingERC20 --constructor-args "$NAME" $SYMBOL \
      --rpc-url $KOVAN_RPC --private-key $ETH_PRIVATE_KEY \
      | awk '/Deployed to:/ {print $3}'`
echo L1 Voting ERC20 Address: $L1_TOKEN_ADDRESS


echo
echo Deploying a treasury contract on L1
export TREASURY_ADDRESS=`forge create Treasury \
      --rpc-url $KOVAN_RPC --private-key $ETH_PRIVATE_KEY \
      | awk '/Deployed to:/ {print $3}'`
echo L1 Treasury Address: $TREASURY_ADDRESS


echo
echo Minting some voting tokens for ourselves
cast send $L1_TOKEN_ADDRESS 'mint(address,uint256)' $ETH_ADDRESS \
    1000000000000000000000000 --private-key $ETH_PRIVATE_KEY --rpc-url $KOVAN_RPC 

echo
echo Minting some tokens for the treasury
cast send $L1_TOKEN_ADDRESS 'mint(address,uint256)' $TREASURY_ADDRESS \
    1000000000000000000000000 --private-key $ETH_PRIVATE_KEY --rpc-url $KOVAN_RPC


echo
echo Creating an ERC20 voting token on L2
export L2_TOKEN_ADDRESS=`forge create L2VotingERC20 --constructor-args $L1_TOKEN_ADDRESS \
    "$NAME" $SYMBOL --rpc-url $OPTIMISM_KOVAN_RPC --private-key $ETH_PRIVATE_KEY \
      | awk '/Deployed to:/ {print $3}'`
echo L2 Voting ERC20 Address: $L2_TOKEN_ADDRESS



echo
echo Transfering the wallet\'s DAO control tokens on L2
echo Step 1. Approve the bridge to spend tokens for us
cast send $L1_TOKEN_ADDRESS 'approve(address,uint256)' $Proxy__OVM_L1StandardBridge \
    1000000000000000000000000 --private-key $ETH_PRIVATE_KEY --rpc-url $KOVAN_RPC 


echo Step 2. Call the bridge to actually transfer the tokens to L2
cast send $Proxy__OVM_L1StandardBridge 'depositERC20(address,address,uint256,uint32,bytes)' \
    $L1_TOKEN_ADDRESS $L2_TOKEN_ADDRESS 1000000000000000000000000 2000000 0x \
    --private-key $ETH_PRIVATE_KEY --rpc-url $KOVAN_RPC



echo
echo Waiting for the tokens to arrive on L2
while [ `cast call --rpc-url $OPTIMISM_KOVAN_RPC $L2_TOKEN_ADDRESS 'balanceOf(address)' $ETH_ADDRESS` = "0x0000000000000000000000000000000000000000000000000000000000000000" ] 
do 
   sleep 10
   echo Still waiting for the tokens to arrive at L2
done


echo
echo Delegate voting to ourselves
cast send $L2_TOKEN_ADDRESS 'delegate(address)' $ETH_ADDRESS \
    --private-key $ETH_PRIVATE_KEY --rpc-url $OPTIMISM_KOVAN_RPC \
    --legacy
