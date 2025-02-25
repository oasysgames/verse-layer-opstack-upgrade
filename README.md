# verse-layer-opstack-upgrade

Helper repository for upgrades from legacy Optimism to OPStack.

## Glossary
### Builder Wallet

Sometimes called `Verse Owner Wallet`. This is the wallet used to deploy the legacy Optimism contract set to L1. It will be used to deploy the OPStack contract set to L1 as well.

### Legacy Node (Verse v0)

The node on which Legacy Optimism, which is on major version zero. The Legacy Node must remain running as a `Historical Node` after upgrading to OPStack. Historical Nodes provide users with pre-upgrade chain data (balances, trace data, etc.).

### OPStack Node (Verse v1)

This is a new node for running OPStack. It is recommended to use a separate instance from the legacy node.

OPStack node requires a disk size of about 30% of the legacy node because it creates a lightweight replica of the legacy Optimism. For example, if the size of the `data/l2geth` directory on the legacy node is 100 GB, the OPStack node will need about 30 GB.

> [!IMPORTANT]
> Replication can take tens of hours, so early setup is recommended.
>
> For example, in the case of SandVerse provided by Oasys (number of blocks: 7.5 million, l2geth data size: 28GB), when the legacy node and the OPStack node were deployed in the same region and zone on GCP, the replication took about 5 hours. Note that replication is not parallelized, so there is no advantage to using high iops storage.

## Upgrade Process

### Preparation Tasks

The following tasks do not involve service downtime and can be done in advance:
1. Setup the OPStack node
1. Setup the Replica
1. Transfer of ownership of legacy contracts
1. Upgrade Explorer to v6

### Simulation

Simulate the upgrade to ensure it proceeds correctly and estimate service downtime.
1. Simulate L2 Data Migration

### Tasks on Upgrade Day

The following tasks require service downtime, so maintenance time is needed. Maintenance time will require 3-6 hours.
1. Change configuration and Blocking new transactions of the legacy node
1. Pause L1 bridge contracts
1. Waiting for L1 deposits
1. Waiting for L2 rollups
1. Waiting for replication
1. Stop the replica
1. Deployment of the OPStack contracts to L1
1. Downloading of OPStack configuration files
1. L2 data migration
1. Change configuration of the legacy node
1. Launch of the OPStack
1. Start Verse Verifier

## Preparation Tasks
### Setup the OPStack node

It is recommended to set up a replica on another server where the legacy verse-layer-optimism is running, as the new verse-layer-opstack will be built on the same server where the replica is set up. The new server's storage size must be at least twice the size of the current l2geth usage, as we recommend taking a snapshot of it during the upgrade procedure.

Clone the [verse-layer-opstack](https://github.com/oasysgames/verse-layer-opstack) repository.
```shell
git clone https://github.com/oasysgames/verse-layer-opstack.git

cd verse-layer-opstack
```

Generate a JWT secret for authentication between op-node and op-geth. This secret does not require backup.
```shell
openssl rand -hex 32 > assets/jwt.txt
```

Create an environment variables file.
```shell
# Sample for Oasys mainnet
cp .env.sample.mainnet .env

# Sample for Oasys testnet
cp .env.sample.testnet .env
```

Copy the following environment variables from the `verse-layer-optimism/.env` file of the legacy node.
```shell
OP_CHAIN_ID=<Set the same chain ID as `L2_CHAIN_ID` in the legacy node>

OP_PROPOSER_ADDR=<Set the same address as `PROPOSER_ADDRESS` in the legacy node>
OP_PROPOSER_KEY=<Set the same secret key as `PROPOSER_KEY` in the legacy node>

OP_BATCHER_ADDR=<Set the same address as `SEQUENCER_ADDRESS` in the legacy node>
OP_BATCHER_KEY=<Set the same secret key as `SEQUENCER_KEY` in the legacy node>

MR_FINALIZER_ADDR=<Set the same address as `MESSAGE_RELAYER_ADDRESS` in the legacy node>
MR_FINALIZER_KEY=<Set the same secret key as `MESSAGE_RELAYER_KEY` in the legacy node>

VERIFY_SUBMITTER_ADDR=<Set the same address as `verse submitter(oasvlfy)` in the legacy node>
VERIFY_SUBMITTER_KEY=<Set the same secret key as `verse submitter(oasvlfy)` in the legacy node>

OP_ETH_RPC_HTTP_PORT=<Set the same port number as `L2GETH_HTTP_PORT` in the legacy node>
OP_ETH_RPC_WS_PORT=<Set the same port number as `L2GETH_WS_PORT` in the legacy node>
```

Other environment variables will be set after deploying OPStack contracts.

### Setup the Replica

Setup the replica of the legacy Optimism.

Clone this `verse-layer-opstack-upgrade` repository directly under the `verse-layer-opstack` directory of the OPStack node you just setup.
```shell
cd /path/to/verse-layer-opstack

git clone https://github.com/oasysgames/verse-layer-opstack-upgrade.git

cd verse-layer-opstack-upgrade
```

Create an environment variables file.
```shell
# Sample for Oasys mainnet
cp .env.sample.mainnet .env

# Sample for Oasys testnet
cp .env.sample.testnet .env
```

Set the following environment variables.
```shell
L2_CHAIN_ID=<L2 Chain ID>
ORIGIN_RPC_URL=<URL of legacy l2geth rpc>
ORIGIN_DTL_URL=<URL of legacy data-transport-layer endpoint>
```

Copy the following files from the `verse-layer-optimism/assets` directory on the legacy node to the `verse-layer-opstack-upgrade/assets` directory on the OPStack node:
- addresses.json
- genesis.json
- contractupdate.json
  - Only overwrite this file if it exists in the legacy node.

Start the replica.
```shell
docker compose up -d replica
```

If the `New block` logs are being output, synchronization is progressing.
```shell
docker compose logs -f replica

# Outputs
replica-1  | INFO [04-20|07:05:18.663] Syncing transaction batch range          start=0 end=70
replica-1  | INFO [04-20|07:05:18.665] New block                                index=0     l1-timestamp=1713092618 l1-blocknumber=45 tx-hash=0x24ffe16b2cbb111f4170b59e8c1125227b08ef08d482546eaaaca5666d728dce queue-orign=sequencer gas=21000 fees=0 elapsed=540.167µs
replica-1  | INFO [04-20|07:05:18.668] New block                                index=1     l1-timestamp=1713092629 l1-blocknumber=45 tx-hash=0xcab3d8a811aa6512d707817fff5bdd7cb6417fef515cd1ddbf397790fa7f6052 queue-orign=sequencer gas=21000 fees=0 elapsed=228.167µs
```

Check that the hash and state root of the genesis block (number = 0) match. When `Synchronized` is displayed, the genesis block was synchronized with the origin. If they do not match, the copied genesis.json may be incorrect.
```shell
docker compose run op-migrate /upgrade/scripts/check-replica.sh 0

# Output
origin : number=0 hash=0x530a5da1ef2f8473e47d302b99f3ae45adc928d9fdf700d882033e3115f1778a state=0x6bf09cb1f0cf9d836e48ce309a18cd815ee1fb36fa6909324346b013bbb27935
replica: number=0 hash=0x530a5da1ef2f8473e47d302b99f3ae45adc928d9fdf700d882033e3115f1778a state=0x6bf09cb1f0cf9d836e48ce309a18cd815ee1fb36fa6909324346b013bbb27935
Synchronized
```

The replica should remain running until the day of the upgrade.

### Transfer of ownership of legacy contracts
To proceed with the upgrade, the ownership of some legacy contracts must be transferred to the [`L1BuildAgent`](../../packages/contracts-bedrock/src/oasys/L1/build/L1BuildAgent.sol) provided by Oasys.

**L1BuildAgent Contract Address**
- Oasys Mainnet: `0x85D92cD5d9b7942f2Ed0d02C6b5120E9D43C52aA`
- Oasys Testnet: `0x85D92cD5d9b7942f2Ed0d02C6b5120E9D43C52aA`

> [!CAUTION]
> Please be very careful as the transfer of ownership is irrevocable. An incorrect transfer will result in permanent loss of control of the L2.

**Legacy Contracts that Require Ownership Transfer**
| Conttract | Transfer method | ABI |
| - | - | - |
| AddressManager   | `transferOwnership(address newOwner)` | [Lib_AddressManager.json](./docs/abi/Lib_AddressManager.json) |
| L1StandardBridge | `setOwner(address _owner)`            | [L1ChugSplashProxy.json](./docs/abi/L1ChugSplashProxy.json) |
| L1ERC721Bridge   | `setOwner(address _owner)`            | [L1ChugSplashProxy.json](./docs/abi/L1ChugSplashProxy.json) |

Addresses of legacy contracts is taken from `verse-layer-opstack-upgrade/assets/addresses.json`.
```shell
cd /path/to/verse-layer-opstack/verse-layer-opstack-upgrade

# AddressManager
jq -r .Lib_AddressManager assets/addresses.json

# L1StandardBridge
jq -r .Proxy__OVM_L1StandardBridge assets/addresses.json

# L1ERC721Bridge
jq -r .Proxy__OVM_L1ERC721Bridge assets/addresses.json
```
If you have completed the transfer, ensure the ownership was transferred correctly by running the check script:
```shell
cd /path/to/verse-layer-opstack/verse-layer-opstack-upgrade

# Run the script
docker compose run op-migrate /upgrade/scripts/check-owner-transfer.sh
```
If the output contains `Failure`, it indicates the transfer failed. Otherwise, it succeeded.

### Upgrade Explorer to v6
Upgrade Explorer to v6 (if your current version is v5).
- Setup instructions: [Explorer v6 Setup Guide](https://docs.oasys.games/docs/verse-developer/how-to-build-verse/explorer)
- Guide explains how to add the Stats page (optional but recommended): [Charts and Stats](https://docs.oasys.games/docs/verse-developer/how-to-build-verse/stats)
- Guide explains how to add the Bridge page (optional): [Bridge](https://docs.oasys.games/docs/verse-developer/how-to-build-verse/bridge)

## Simulation
### Simulate L2 Data Migration
L2 data migraiton is the most uncertain task, so make sure this is succeed. addinotaly this is the most time consuming task. so we masure the time to estime downtime.

#### 1. Stop Replica container
Stop the replica container on the OPStack node. This may take some time as the StateTrie is pruned. Even in such cases, please wait for the container to stop normally instead of forcing it to quit. Once pruning is complete, the following log will be output:
```shell
cd /path/to/verse-layer-opstack/verse-layer-opstack-upgrade

docker compose stop replica
```
Log Output:
```shell
docker compose logs --tail=100 replica

# Output
replica-1  | INFO [04-21|06:48:52.049] Transaction pool stopped
replica-1  | INFO [04-21|06:48:52.049] Stopping sync service
```

#### 2. Migrate Data
Backup all replica data to a temporary directory.
> [!WARNING]
> Ensure that you have enough disk space to backup replica data. The required disk size is equivalent to the size of the `./data` folder.
```shell
rsync -av --progress ./data/ /path/to/tmp
```
Generate dummy configuration files:
```shell
# Make the script executable
chmod +x ./scripts/generate-dummy-configs.sh

# Run the script
./scripts/generate-dummy-configs.sh
```
Migrate legacy chain data output by the replica for OPStack.
```shell
# Print starting time
TZ='UTC' date +"%m-%d|%H:%M:%S"

docker compose run op-migrate /upgrade/scripts/data-migrate.sh
```
When `checked withdrawals` is displayed, the migration is successful.
```shell
INFO [04-21|08:21:58.723] checked withdrawals
```
Calculate the elapsed time from the logged time. Adding 30 minutes serves as a guideline for downtime.
> Downtime: 30 minutes + L2 data migration elapsed time.

#### 3. Restore Data
Clear the generated data:
```shell
# Delete outputs
rm -r ./data

# Delete configuration files
rm ../assets/addresses.json
rm ../assets/deploy-config.json
rm ../assets/rollup.json
```
Move the backed-up data from the temporary directory back to the original location.
```shell
mv /path/to/tmp ./data
```
Start the replica again to resume syncing.
```shell
docker compose start replica
```

## Tasks on Upgrade Day
Before proceeding with the L2 upgrade, you should inform two parties:
- The Bridge Service Provider (e.g., Tealswap)
  - Inform them about the downtime. During the L2 upgrade, all L1 to L2 bridge transactions will be forcibly reverted.
- Oasys Dev Team
  - To activate instant verify right after your verse launch, Oasys will prepare the infrastructure settings. Inform the Oasys team about the schedule.

### 1. [Legacy Node] Change configuration and Blocking new transactions of the legacy node
Change the `data-transport-layer` container of the legacy node to a container image for the upgrading. Additionally, enable access control on the `l2geth` container to blocking transactions and prevent new blocks from being created.

Create `verse-layer-optimism/docker-compose.override.yml` file on the legacy node. If it already exists, add the differences.
```yaml
services:
  data-transport-layer:
    image: ghcr.io/oasysgames/oasys-optimism/data-transport-layer:op-migrate

  l2geth:
    image: ghcr.io/oasysgames/oasys-optimism/l2geth:op-migrate
    environment:
      ACL_CONFIG: /assets/acl.yml
```

Create access control configuration file `./assets/acl.yml`. If it already exists, replace its contents.
```yaml
from: []
```

Stop and start the containers to reflect the changes. **Do not use `docker compose restart` command.**
```shell
docker compose stop data-transport-layer l2geth
docker compose up -d data-transport-layer l2geth
```

Check if the `acl.yml` has been loaded.
```shell
docker compose logs -f --tail=10000 l2geth | grep 'Reload access control config'

# Output
l2geth-1  | INFO [04-20|08:20:57.450] Reload access control config             md5hash=4ad59fbe28b0482602e30eb0f0088217
```

### 2. [Builder Wallet] Pause L1 bridge contracts
Before proceeding with this, even though it is optional, it is highly recommended to wait until all L2-to-L1 withdrawals have been relayed. To confirm this, follow these steps:
```shell
docker compose run op-migrate /upgrade/scripts/check-withdrawal-relay.sh
```
If the script outputs a `Success` message, the process is okay. Otherwise, it has failed. Wait for one minute and then re-run the script.

Additionally, ensure that the message-relayer has verified the latest L2 height. To verify this, check the log of the message-relayer:
```shell
docker compose logs --tail=100 message-relayer | grep 'relayer sent multicall'

# Output sample
# message-relayer-1  | {"level":30,"time":1714631870038,"msg":"checking L2 block 7564066"}
```

To pause L1 bridge transaction, transact the `pauseLegacyL1CrossDomainMessenger(uint256 _chainId, address addressManager)` method of the L1BuildAgent contract from the Builder Wallet to pausing L1 bridge contracts. The parameter `_chainId` is the L2 chain ID and the parameter `addressManager` is the address of the AddressManager contract. Download the  [L1BuildAgent ABI](./docs/abi/IL1BuildAgent.json) here.

### 3. [OPStack Node] Waiting for L1 deposits
Wait for all deposit transactions sent to the L1 bridge contract to be bridged to the legacy node.
```shell
cd /path/to/verse-layer-opstack/verse-layer-opstack-upgrade

docker compose run op-migrate /upgrade/scripts/check-deposits.sh origin
```

When `All deposits have been batch submitted` is displayed, all L1 deposits have been bridged to the Legacy Node.
```shell
INFO [04-21|06:28:42.844] Checking L2 block                        number=662
INFO [04-21|06:28:42.845] Checking L2 block                        number=661
INFO [04-21|06:28:42.847] Deposit found                            l2-block=661 l1-block=3383 queue-index=253
INFO [04-21|06:28:42.847] Found final deposit in l2geth            queue-index=253
INFO [04-21|06:28:42.848] Remaining deposits that must be submitted count=0
INFO [04-21|06:28:42.848] All deposits have been batch submitted
```

Similarly, wait for L1 deposits to be bridged to the replica.
```shell
docker compose run op-migrate /upgrade/scripts/check-deposits.sh replica
```

### 4. [OPStack Node] Waiting for L2 rollups
Wait for all L2 blocks to be rolled up to the L1.
```shell
cd /path/to/verse-layer-opstack/verse-layer-opstack-upgrade

docker compose run op-migrate /upgrade/scripts/check-rollups.sh
```

When `All batches have been submitted` is displayed, all L2 blocks have been rolled up to L1.
```
INFO [04-21|06:35:21.603] Waiting for CanonicalTransactionChain
INFO [04-21|06:35:21.603] Waiting for StateCommitmentChain
INFO [04-21|06:35:21.604] Total elements matches block number      name=StateCommitmentChain count=847
INFO [04-21|06:35:21.604] Total elements matches block number      name=CanonicalTransactionChain count=847
INFO [04-21|06:35:21.604] All batches have been submitted
```

### 5. [OPStack Node] Waiting for replication
Wait for the legacy node and the replica to fully synchronize.
```shell
cd /path/to/verse-layer-opstack/verse-layer-opstack-upgrade

docker compose run op-migrate /upgrade/scripts/check-replica.sh
```

When `Synchronized` is displayed, the replica is fully synchronized with the origin.
```shell
origin : number=847 state=0xc7e84c57135bb52773f7f195885835e87d8ffdd67bdd3ace5ca8b79cac7fc529
replica: number=847 state=0xc7e84c57135bb52773f7f195885835e87d8ffdd67bdd3ace5ca8b79cac7fc529
Synchronized
```

### 6. [OPStack Node] Stop the replica
Stop the replica container on the OPStack node.
```shell
cd /path/to/verse-layer-opstack/verse-layer-opstack-upgrade

docker compose stop replica
```

Stopping may take some time as the StateTrie is pruned. Even in such cases, **In this case, please wait for the container to stop normally instead of killing it.** When pruning is complete, the following log is output:
```shell
docker compose logs --tail=100 replica

# Output
replica-1  | INFO [04-21|06:48:52.041] Persisted trie from memory database      nodes=1769 size=175.24KiB time=15.116166ms gcnodes=11698 gcsize=2.50MiB gctime=17.113675ms livenodes=3912 livesize=805.33KiB
replica-1  | INFO [04-21|06:48:52.041] Writing cached state to disk             block=846 hash=ee42ff…abee94 root=cea030…ace2d6
replica-1  | INFO [04-21|06:48:52.041] Persisted trie from memory database      nodes=3    size=659.00B   time=458.167µs   gcnodes=0     gcsize=0.00B   gctime=0s          livenodes=3909 livesize=804.69KiB
replica-1  | INFO [04-21|06:48:52.041] Writing cached state to disk             block=720 hash=90bb0a…1fb888 root=de7b24…e909e3
replica-1  | INFO [04-21|06:48:52.045] Persisted trie from memory database      nodes=746  size=87.53KiB  time=3.928417ms  gcnodes=0     gcsize=0.00B   gctime=0s          livenodes=3163 livesize=717.16KiB
replica-1  | INFO [04-21|06:48:52.049] Blockchain manager stopped
replica-1  | INFO [04-21|06:48:52.049] Transaction pool stopped
replica-1  | INFO [04-21|06:48:52.049] Stopping sync service
```

Once the replica is successfully stopped, delete the container.
```shell
docker compose rm -f replica
```

### 7. [Builder Wallet] Deployment of the OPStack contracts to L1
> [!CAUTION]
> Once you complete this process, reverting to the legacy Verse becomes challenging. The only option would be to complete the entire upgrade process.

From the Builder Wallet, transact the `build(uint256 chainId, BuildConfig calldata cfg)` method of the L1BuildAgent to deploy OPStack contracts to L1. Pay close attention to the order of the `BuildConfig calldata cfg` parameters. See here for more details on the parameters:
- [Oasys Docs](https://docs.oasys.games/docs/verse-developer/how-to-build-verse/optional-configs#verse-contracts-build-configuration)
- [Contract Code](https://github.com/oasysgames/oasys-opstack/blob/4f2f04d/packages/contracts-bedrock/src/oasys/L1/build/interfaces/IL1BuildAgent.sol#L5-L51)

| Parameter | Type | Description |
| - | - | - |
| chainId                               | uint256 | L2 Chain ID |
| cfg.finalSystemOwner                  | address | Owner of the OPStack contracts, typically specified as the Builder Wallet. |
| cfg.l2OutputOracleProposer            | address | Wallet that performs state roll-ups. Set the `OP_PROPOSER_ADDR`. |
| cfg.l2OutputOracleChallenger          | address | Wallet that removes state roll-ups, typically specified as the Builder Wallet. |
| cfg.batchSenderAddress                | address | Wallet that performs roll-ups of TX data. Set the `OP_BATCHER_ADDR`. |
| cfg.p2pSequencerAddress               | address | Set the `P2P_SEQUENCER_ADDR`. |
| cfg.messageRelayer                    | address | Wallet that relays bridge messages from L2 to L1. Set the `MR_FINALIZER_ADDR`. |
| cfg.l2BlockTime                       | uint256 | Set the interval between L2 blocks, between 2 and 7 seconds. |
| cfg.l2GasLimit                        | uint64  | Maximum gas for an L2 block. Set `30000000` if no particular preference. |
| cfg.l2OutputOracleSubmissionInterval  | uint256 | Interval of L2 blocks between state roll-ups. Set `80` if no particular preference. |
| cfg.finalizationPeriodSeconds         | uint256 | Number of seconds until state roll-ups are finalized. Set `604800`(7 days) if no preference. |
| cfg.l2OutputOracleStartingBlockNumber | uint256 | Starting block number of OPStack L2. Obtain this with the command below. |
| cfg.l2OutputOracleStartingTimestamp   | uint256 | Starting timestamp of OPStack L2 first block. Obtain this with the command below. |

The `cfg.l2OutputOracleStartingBlockNumber` and `cfg.l2OutputOracleStartingTimestamp` are obtained by execute this command on the OPStack node.
```shell
cd /path/to/verse-layer-opstack/verse-layer-opstack-upgrade

docker compose run op-migrate /upgrade/scripts/l2oo-starting-block.sh

# Output
l2OutputOracleStartingBlockNumber: 848
l2OutputOracleStartingTimestamp  : 1713686734
```

### 8. [OPStack Node] Downloading of OPStack configuration files
Once the contract set has been successfully deployed, download `deploy-config.json` and `addresses.json` from the [Verse Build Tool](https://tools-fe.oasys.games/check-verse). Wallet extensions (such as Metamask) should be connected to the Oasys mainnet or testnet.

Copy the downloaded files to the `verse-layer-opstack/assets` directory on the OPStack node.

### 9. [OPStack Node] L2 data migration
Migrate legacy chain data output by the replica for OPStack.
```shell
cd /path/to/verse-layer-opstack/verse-layer-opstack-upgrade

docker compose run op-migrate /upgrade/scripts/data-migrate.sh
```

When `checked withdrawals` is displayed, the migration was successful.
```shell
INFO [04-21|08:21:58.723] checked L1Block
INFO [04-21|08:21:58.723] recomputing witness data
INFO [04-21|08:21:58.723] checking legacy eth fixed storage slots
INFO [04-21|08:21:58.723] checked legacy eth
INFO [04-21|08:21:58.727] computed withdrawal storage slots        migrated=360              invalid=0
INFO [04-21|08:21:58.733] checked withdrawals
```

Run the check command just to be sure. If you see `checked withdrawals` in the same way, you have succeeded.
```shell
docker compose run op-migrate /upgrade/scripts/check-data-migrate.sh
```

Once the migration was successful, move the migrated data directory to the `data/op-geth` directory on the OPStack project.
```shell
cd /path/to/verse-layer-opstack

# Create if it does not exist
mkdir data

mv verse-layer-opstack-upgrade/data data/op-geth
```

> [!IMPORTANT]
> Backup the chain data after migration. This is used when setting up replica nodes. It is recommended to obtain disk snapshots of the OPStack node. When creating an archive, be mindful of the available disk space.
> ```shell
> # Create archive
> tar -czf op-geth_migrated.tgz -C data/op-geth/ .
> ```

Be careful not to end up with a directory path like `data/op-geth/data`. **Correct Directory Structure:**
```shell
ls -l data/op-geth

# Output
total 768
drwxr-xr-x  8 user  users     256  4 22 12:22 geth
drwx------  3 user  users      96  4 22 12:16 keystore
-rwxr-xr-x  1 user  users  381041  4 22 12:16 state-dump.txt
```

Also, ensure that the `verse-layer-opstack/assets/rollup.json` file has been generated.
```shell
ls -l assets/rollup.json

# Output
-rwxr-xr-x  1 user  users  1065  4 22 12:28 assets/rollup.json
```

### 10. [Legacy Node] Change configuration of the legacy node
Add the environment variable `ETH1_SYNC_SERVICE_ENABLE: 'false'` to the `verse-layer-optimism/docker-compose.override.yml` of the legacy node. This way, l2geth can be running without need for the data-transport-layer.
```shell
services:
  data-transport-layer:
    image: ghcr.io/oasysgames/oasys-optimism/data-transport-layer:op-migrate

  l2geth:
    image: ghcr.io/oasysgames/oasys-optimism/l2geth:op-migrate
    environment:
      ACL_CONFIG: /assets/acl.yml
      ETH1_SYNC_SERVICE_ENABLE: 'false'  # <- like this
```

Stop all containers on the legacy node and restart only the l2geth container. After the upgrade, the legacy node will operate as a `Historical Node`, so containers other than l2geth are not required.
```shell
docker compose down
docker compose up -d l2geth
```

### 11. [OPStack Node] Launch of the OPStack
Check the `verse-layer-opstack/assets` directory of the OPStack node for the presence of the required configuration files.
- jwt.txt
- addresses.json
- deploy-config.json
- rollup.json

**Please share the above `addresses.json` and `rollup.json`, and addionally `op-geth_migrated.tgz` with the Oasys Dev team** to activate instant verification.

Create `verse-layer-opstack/docker-compose.override.yml` and add an environment variable to enable `Historical Node`.
```yaml
services:
  op-geth:
    environment:
      GETH_ROLLUP_HISTORICALRPC: <URL of legacy l2geth rpc>
```

Add any missing environment variables to the .env file. Obtain contract addresses from the `verse-layer-opstack/assets/addresses.json.`
```shell
# address of the `L2OutputOracleProxy` contract on L1
OP_L2OO_ADDR=
# address of the `AddressManager` contract on L1
OP_AM_ADDR=
# address of the `L1CrossDomainMessengerProxy` contract on L1
OP_L1CDM_ADDR=
# address of the `L1StandardBridgeProxy` contract on L1
OP_L1BRIDGE_ADDR=
# address of the `OptimismPortalProxy` contract on L1
OP_PORTAL_ADDR=
```

Apply all the hardforks by following the corresponding section in the official technical documentation: [Hardfork](https://docs.oasys.games/docs/verse-developer/how-to-build-verse/upgrade-verse#hardfork)

Launch the `op-geth` and `op-node` containers.
```shell
docker compose up -d op-geth op-node
```

If configured correctly, L2 blocks will be generated at the interval specified in `cfg.l2BlockTime` at the time of contract deployment.
```shell
docker compose logs -f --tail=100 op-geth

# Output
op-geth-1  | INFO [04-21|08:39:48.952] Stopping work on payload                 id=0x273b7c4af4036d30 reason=delivery
op-geth-1  | INFO [04-21|08:39:48.957] Imported new potential chain segment     number=170,743 hash=50b004..c8a88e blocks=1 txs=1 mgas=0.047 elapsed=3.588ms     mgasps=13.055  snapdiffs=2.31MiB    triedirty=0.00B
op-geth-1  | INFO [04-21|08:39:48.958] Chain head was updated                   number=170,743 hash=50b004..c8a88e root=d4bc95..b7f03f elapsed="314.666µs"
op-geth-1  | INFO [04-21|08:39:49.008] Starting work on payload                 id=0x7085fa059a5f525b
op-geth-1  | INFO [04-21|08:39:49.008] Updated payload                          id=0x7085fa059a5f525b number=170,744 hash=664974..d2b1f4 txs=1 withdrawals=0 gas=46841 fees=0 root=cf458c..350bcc elapsed="358.334µs"
```

Also, start all other containers.
```shell
docker compose up -d op-batcher op-proposer op-message-relayer
```

This completes the upgrade to OPStack.

After upgrading, the `verse-layer-opstack-upgrade` directory is not needed and may be deleted.
```shell
cd /path/to/verse-layer-opstack

rm -rf verse-layer-opstack-upgrade
```

### 12. [OPStack Node] Start Verse Verifier
After the Oasys team completes the infrastructure setup, start the verse verifier.
```shell
docker compose up -d verse-verifier
```

## Troubleshooting

### How to resolve the `Cannot recover OVM Context` error when setting up a replica?
The block signer key (`BLOCK_SIGNER_KEY`) configured in the .env file does not match the one set in the origin node. Please verify the `BLOCK_SIGNER_KEY` in the verse-layer-optimism .env file and ensure they are identical.

---
### How to resolve the `DTL_SHUTOFF_BLOCK` error when executing the check-deposits.sh script?
You may have forgotten to call the `pauseLegacyL1CrossDomainMessenger` function of L1BuildAgent. This step should be performed just before running the check-deposits.sh script.

---
### How to resolve the following permission error when starting op-node and op-geth?
```sh
# example error of op-geth
op-geth-1  | ERROR[02-17|10:43:11.002] Failed to persist node key: open /data/geth/nodekey: permission denied
op-geth-1  | WARN [02-17|10:43:11.002] Failed to watch keystore folder          path=/data/keystore err="permission denied"
```

This issue occurs due to insufficient permissions for the Docker user. The simplest way to fix this (though not the most secure practice) is to grant read and write access to all users:
```sh
cd verse-layer-opstack
chmod -R a+rwX ./data
```
