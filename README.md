# State Sync - Client Script
Script to bootstrap the syncing when a new peer/validator join to Chronic Network.

## The Problem
When a new peer tries to join a running chain it can take days to fully synchronise and this can take up a huge amount of disk space.

## The Solution
StateSync is a feature which would allow a new node to receive a snapshot of the application state without downloading blocks or going through consensus. Deploying the new State Sync function on StateSync servers could help to boost the synchronizing of new peers/validators. It also reduces the disk space usage. 

Chronic StateSync servers will include this function in mainnet. 

## There are two State Sync scripts: 
* For to sync a new peer/validator: `statesync_client_linux_new.sh`
* For to sync an existent peer/validator: `statesync_client_linux_existing.sh`

# Start to sync a new peer/validator 
We asume you are not running a validator or simple node so far.

1. Install `jq` and download the script:

    ```
    sudo apt install jq
    wget https://raw.githubusercontent.com/ChronicNetwork/cosmos-statesync_client/main/statesync_client_linux_new.sh
    chmod +x statesync_client_linux_new.sh
    ```

2. Then launch the script (CTLR + C to stop it,):
Read carefully the instructions displayed at screen when you run it:
    ```
    ./statesync_client_linux_new.sh
    ```
### When your peer is synced, set up a service file if you hadn't it previously.
3. Move the binary to the system path:
    ```
    sudo mv ./chtd /usr/local/bin/
    ```
4. Setup `chtd` systemd service (copy and paste all to create the file service):
    ```
    cd $HOME
    echo "[Unit]
    Description=Chronic Network Node
    After=network-online.target
    [Service]
    User=${USER}
    ExecStart=$(which chtd) start
    Restart=always
    RestartSec=3
    LimitNOFILE=4096
    [Install]
    WantedBy=multi-user.target
    " >chtd.service
    ```
    
5. Enable and activate the CHTD service.
    ```
    sudo mv chtd.service /lib/systemd/system/
    sudo systemctl enable chtd.service && sudo systemctl start chtd.service
    ```
6. Check the logs to see if it is working:
    ```
    sudo journalctl -u chtd -f
    ``` 

### If you want to run a validator see this guide:
TBD

# Resync an existent peer/validator 

Follow this instructions only if you are running currently a validator/peer.

> It will reduces the disk space usage. From thousands of GB to MB maintaining your config and validator keys!

Follow the instructions at the screen when the script starts.
Be patient, StateSync need some minutes (2 to 4) to fetch the good state.
Press CTRL + C to stop it when you see the peer synced with last block. 

If you are running a validator/peer, this script will save space in disk for you,  will reset your current data and folder and give you the info to resync in several minutes.

> **Very important**, daemon should turned off if is not a clean installation and `jq` tool must be installed in the system.

1. Install `jq` and download the script:

    ```
    sudo apt install jq
    wget https://raw.githubusercontent.com/ChronicNetwork/cosmos-statesync_client/main/statesync_client_linux_existing.sh
    chmod +x statesync_client_linux_existing.sh
    ```

2. Clean the data folder to ensure a fresh resync and a new Address book.
    * Cosmovisor
    ```
    cosmovisor run unsafe-reset-all
    ```
    * chtd daemon
    ```
    chtd unsafe-reset-all
    ```
    
3. Then launch the script to get the StateSync data:
    ```
    ./statesync_client_linux_existing.sh
    ```

4. Follow the instructions of the script, as recap: 
    ```
    a) Replace the settings in `config.toml`
    b) Run the daemon until is synced. Stop it.
    c) Restore your previous settings at `config.toml`
    d) Start again the daemon
    
## DISCLAIMER:
This script is experimental, StateSync is experimental, run it at your own risk, make your own backups of the configuration and do not run it before reading and understanding the contents of the script.


###### tags: `doc` `github`# cosmos-statesync_client
