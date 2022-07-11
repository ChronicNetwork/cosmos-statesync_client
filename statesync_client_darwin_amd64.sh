#!/bin/bash
# Based on the work of Joe (Chorus-One) for Microtick - https://github.com/microtick/bounties/tree/main/statesync
# You need config in two peers (avoid seed servers) this values in app.toml:
#     [state-sync]
#     snapshot-interval = 1000
#     snapshot-keep-recent = 10
# Pruning should be fine tuned also, for this testings is set to nothing
#     pruning = "nothing"

set -e
export DATE_BACKUP=`date +"%d_%m_%Y-%H_%M"`

# Change for your custom chain
BINARY="https://github.com/ChronicNetwork/cht/releases/download/v.1.1.0/cht_darwin64"
GENESIS=""
APP="CHTD: ~/.cht"
echo "Welcome to the StateSync script. This script will backup your config, move the current .cht folder to .old_cht, sync the last state and restore the previous config. 
You should have a crypted backup of your wallet keys, your node keys and your validator keys, anyway the script will make a clear backup of the last two. Ensure that you can restore your wallet keys if is needed."
read -p "$APP folder, your keys and config will be erased, a backup will be made, PROCED (y/n)? " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
  # Chronic Network State Sync client config.
  echo ##################################################
  echo " Making a backup from .cht config files if exist"
  echo ##################################################
  cd ~
  if [ -d ~/.cht ];
  then
    echo "There is a CHTD folder there... taking a backup and moving to .old_cht"
    tar cvfz cht_folder_backup_$DATE_BACKUP.tgz --exclude=".cht/data/cs.wal" --exclude=".cht/data/application.db" --exclude=".cht/data/blockstore.db" --exclude=".cht/data/evidence.db" --exclude=".cht/data/snapshots" --exclude=".cht/data/state.db"   --exclude=".cht/data/tx_index.db" .cht/*
    mv .cht .old_cht
  fi
  if [ -f ~/chtd ];
  then
    rm -f chtd_darwin_arm64 #deletes a previous downloaded binary
  fi
  wget -nc $BINARY
  chmod +x cht_darwin_arm64
  mv cht_darwin_arm64 chtd
  ./cht init New_peer --chain-id bitcanna-1
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
  #DOMAIN_3=seed1.bitcanna.io     # If you want to use domain names 
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
  s|^(seeds[[:space:]]+=[[:space:]]+).*$|\1\"xxxxxx:26656\"|" $HOME/.cht/config/config.toml

 
  sed -E -i -s 's/minimum-gas-prices = \".*\"/minimum-gas-prices = \"0.001ucgas\"/' $HOME/.cht/config/app.toml

  ./chtd tendermint unsafe-reset-all
  ./chtd start
   echo 
   echo Waiting 10 seconds... your backup will be restored with your previous data.... and CHTD will start again to test it.
   sleep 10
  tar -xzvf cht_folder_backup_$DATE_BACKUP.tgz
   ./chtd start
   echo If your node is synced considerate to create a service file. Be careful, your backup file is not crypted!
   echo If process was sucessful you can delete .old_cht
fi