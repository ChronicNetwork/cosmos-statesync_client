#!/bin/bash
# Based on the work of Joe (Chorus-One) for Microtick - https://github.com/microtick/bounties/tree/main/statesync
# You need config in two peers (avoid seed servers) this values in app.toml:
#     [state-sync]
#     snapshot-interval = 1000
#     snapshot-keep-recent = 10
# Pruning should be fine tuned also, for this testings is set to nothing
#     pruning = "nothing"

# Let's check if JQ tool is installed
FILE=$(which jq)
 if [ -f "$FILE" ]; then
   echo "JQ is present"
 else
   echo "$FILE JQ tool does not exist, install with: sudo apt install jq"
   exit 1
 fi

set -e

# Change for your custom chain
BINARY="https://github.com/ChronicNetwork/cht/releases/download/v.1.1.0/chtd"
GENESIS="https://raw.githubusercontent.com/ChronicNetwork/net/main/mainnet/v1.1/genesis.json"
APP="CHT: ~/.cht"
echo "Welcome to the StateSync script. This script will download the last binary and it will sync the last state."
echo "DON'T USE WITH A EXISTENT peer/validator config will be erased."
echo "You should have a crypted backup of your wallet keys, your node keys and your validator keys." 
echo "Ensure that you can restore your wallet keys if is needed."
read -p "have you stopped the CHTD service? CTRL + C to exit or any key to continue..."
read -p "$APP folder, your keys and config WILL BE ERASED, it's ok if you want to build a peer/validator for first time, PROCED (y/n)? " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
  # Chronic State Sync client config.
  echo ##################################################
  echo " Making a backup from .cht config files if exist"
  echo ##################################################
  cd ~
  if [ -d ~/.cht ];
  then
    echo "There is a CHT folder there... if you want sync the data in an existent peer/validator try the script: statesync_linux_with_backup.sh"
    exit 1
  else
      echo "New installation...."
  fi

  if [ -f ~/cht ];
   then
    rm -f chtd #deletes a previous downloaded binary
  fi
  wget -nc $BINARY
  chmod +x chtd
  ./chtd init New_peer --chain-id morocco-1
  rm -rf $HOME/.cht/config/genesis.json #deletes the default created genesis
  curl -s $GENESIS > $HOME/.cht/config/genesis.json
  
 
  NODE1_IP=""
  RPC1="http://$NODE1_IP"
  P2P_PORT1=36656
  RPC_PORT1=36657
  
  NODE2_IP=""
  RPC2="http://$NODE2_IP"
  RPC_PORT2=36657
  P2P_PORT2=36656

  #If you want to use a third StateSync Server... 
  #DOMAIN_3=seed1.chronicnetwork.io     # If you want to use domain names 
  #NODE3_IP=$(dig $DOMAIN_1 +short
  #RPC3="http://$NODE3_IP"
  #RPC_PORT3=26657
  #P2P_PORT3=26656

  INTERVAL=1000

  LATEST_HEIGHT=$(curl -s $RPC1:$RPC_PORT1/block | jq -r .result.block.header.height);
  BLOCK_HEIGHT=$((($(($LATEST_HEIGHT / $INTERVAL)) -10) * $INTERVAL)); #Mark addition
  
  if [ $BLOCK_HEIGHT -eq 0 ]; then
    echo "Error: Cannot state sync to block 0; Latest block is $LATEST_HEIGHT and must be at least $INTERVAL; wait a few blocks!"
    exit 1
  fi

  TRUST_HASH=$(curl -s "$RPC1:$RPC_PORT1/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)
  if [ "$TRUST_HASH" == "null" ]; then
    echo "Error: Cannot find block hash. This shouldn't happen :/"
    exit 1
  fi

  NODE1_ID=$(curl -s "$RPC1:$RPC_PORT1/status" | jq -r .result.node_info.id)
  NODE2_ID=$(curl -s "$RPC2:$RPC_PORT2/status" | jq -r .result.node_info.id)
  #NODE3_ID=$(curl -s "$RPC3:$RPC_PORT3/status" | jq -r .result.node_info.id)

  sed -i.bak -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ; \
  s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"http://$NODE1_IP:$RPC_PORT1,http://$NODE2_IP:$RPC_PORT2\"| ; \
  s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$BLOCK_HEIGHT| ; \
  s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"| ; \
  s|^(persistent_peers[[:space:]]+=[[:space:]]+).*$|\1\"${NODE1_ID}@${NODE1_IP}:${P2P_PORT1},${NODE2_ID}@${NODE2_IP}:${P2P_PORT2}\"| ; \
  s|^(seeds[[:space:]]+=[[:space:]]+).*$|\1\"xxxxx:26656\"|" $HOME/.cht/config/config.toml


  sed -E -i -s 's/minimum-gas-prices = \".*\"/minimum-gas-prices = \"0.001ucgas\"/' $HOME/.cht/config/app.toml

  ./chtd unsafe-reset-all
  echo ##################################################################
  echo  "PLEASE HIT CTRL+C WHEN THE CHAIN IS SYNCED, Wait the last block"
  echo ##################################################################
  sleep 5
  ./chtd start
  sed -E -i 's/enable = true/enable = false/' $HOME/.cht/config/config.toml
  echo ##################################################################  
  echo  Run again with: ./chtd start
  echo ##################################################################
  echo If your node is synced considerate to create a service file. 
fi