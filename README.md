# verse-layer-opstack-upgrade

Helper repository for upgrades from legacy Optimism to OPStack.

## 用語定義
### Builderウォレット

Verse Ownerウォレットとも呼ばれます。レガシーOptimismのコントラクトセットを L1へデプロイする際に使用したウォレットです。OPStackのコントラクトセットをL1へデプロイする際に使用します。

### レガシーノード

既存のレガシーOptimismが稼働しているノードです。レガシーノードはOPStackアップグレード前のチェーンデータ(残高やトレースデータ等)をユーザーに提供するHistorical Nodeとして使用するためアップグレード後も稼働させておく必要があります。

### OPStackノード

OPStackを稼働させる新しいノードです。レガシーノードとは別のインスタンスが推奨されます。また、OPStackノード上にレガシーOptimismのレプリカを作成するためレガシーノードと同量以上のディスク容量を必要とします。ブロック数によりますがレプリケーション完了に数時間から数十時間かかるため早めに構築する事が推奨されます。

## アップグレードの流れ

### 事前作業

以下のタスクはサービス停止を伴わないので事前に行えます。
1. OPStackノードの仮セットアップ
1. レプリカのセットアップ
1. Legacyコントラクトのオーナー転送

### 当日作業

以下のタスクはサービス停止を伴うためメンテナンス時間が必要です。
1. レガシーノードの構成変更とRPCのブロック
1. ブリッジコントラクトの停止
1. デポジットの待機
1. ロールアップの待機
1. レプリケーションの確認
1. レプリカの停止
1. OPStackコントラクトセットをデプロイ
1. OPStack構成ファイルのダウンロード
1. データマイグレーション
1. レガシーノードの構成変更
1. OPStackサービスの起動

## 事前作業
### OPStackノードの仮セットアップ

OPStackノードを仮セットアップします。まず、[verse-layer-opstack](https://github.com/oasysgames/verse-layer-opstack)リポジトリをクローンします。
```shell
git clone https://github.com/oasysgames/verse-layer-opstack.git

cd verse-layer-opstack
```

Generate a JWT secret for authentication between op-node and op-geth. This secret does not require backup.
```shell
openssl rand -hex 32 > assets/jwt.txt
```

環境変数ファイルを作成します。
```shell
# Sample for Oasys mainnet
cp .env.sample.mainnet .env

# Sample for Oasys testnet
cp .env.sample.testnet .env
```

以下の環境変数はレガシーノードの`verse-layer-optimism/.env`ファイルからコピーします。
```shell
OP_CHAIN_ID=<レガシー環境での`L2_CHAIN_ID`と同じチェーンIDをセットしてください>

OP_PROPOSER_ADDR=<レガシー環境での`PROPOSER_ADDRESS`と同じアドレスをセットしてください>
OP_PROPOSER_KEY=<レガシー環境での`PROPOSER_KEY`と同じ秘密鍵をセットしてください>

OP_BATCHER_ADDR=<レガシー環境での`SEQUENCER_ADDRESS`と同じアドレスをセットしてください>
OP_BATCHER_KEY=<レガシー環境での`SEQUENCER_KEY`と同じ秘密鍵をセットしてください>

MR_PROVER_ADDR=<レガシー環境での`MESSAGE_RELAYER_ADDRESS`と同じアドレスをセットしてください>
MR_PROVER_KEY=<レガシー環境での`MESSAGE_RELAYER_KEY`と同じ秘密鍵をセットしてください>
MR_FINALIZER_ADDR=<レガシー環境での`MESSAGE_RELAYER_ADDRESS`と同じアドレスをセットしてください>
MR_FINALIZER_KEY=<レガシー環境での`MESSAGE_RELAYER_KEY`と同じ秘密鍵をセットしてください>

VERIFY_SUBMITTER_ADDR=<レガシー環境での`verse submitter(oasvlfy)`と同じアドレスをセットしてください>
VERIFY_SUBMITTER_KEY=<レガシー環境での`verse submitter(oasvlfy)`と同じ秘密鍵をセットしてください>

OP_ETH_RPC_HTTP_PORT=<レガシー環境での`L2GETH_HTTP_PORT`と同じポート番号をセットしてください>
OP_ETH_RPC_WS_PORT=<レガシー環境での`L2GETH_WS_PORT`と同じポート番号をセットしてください>
```

それ以外の環境変数はOPStackコントラクトのデプロイ後にセットします。

### レプリカの構築

レガシーOptimismのレプリカをセットアップします。まず、一つ前のステップで仮セットアップしたOPStackノードの`verse-layer-opstack`ディレクトリ直下にこの`verse-layer-opstack-upgrade`リポジトリをクローンします。
```shell
cd /path/to/verse-layer-opstack

git clone https://github.com/oasysgames/verse-layer-opstack-upgrade.git

cd verse-layer-opstack-upgrade
```

環境変数ファイルを作成します。
```shell
# Sample for Oasys mainnet
cp .env.sample.mainnet .env

# Sample for Oasys testnet
cp .env.sample.testnet .env
```

以下の環境変数をセットします。
```shell
L2_CHAIN_ID=<L2 Chain ID>
ORIGIN_RPC_URL=<URL of legacy l2geth rpc>
ORIGIN_DTL_URL=<URL of legacy data-transport-layer endpoint>
```

レガシーノードの`verse-layer-optimism/assets`ディレクトリから以下のファイルを`verse-layer-opstack-upgrade/assets`ディレクトリにコピーします。
- addresses.json
- genesis.json
- contractupdate.json
  - このファイルはレガシーノードに存在する場合のみ上書きコピーします

レプリカコンテナを起動します。
```shell
docker-compose up -d replica
```

`New block`ログが出力されていれば同期が進行しています。
```shell
docker-compose logs -f replica

# Outputs
replica-1  | INFO [04-20|07:05:18.663] Syncing transaction batch range          start=0 end=70
replica-1  | INFO [04-20|07:05:18.665] New block                                index=0     l1-timestamp=1713092618 l1-blocknumber=45 tx-hash=0x24ffe16b2cbb111f4170b59e8c1125227b08ef08d482546eaaaca5666d728dce queue-orign=sequencer gas=21000 fees=0 elapsed=540.167µs
replica-1  | INFO [04-20|07:05:18.668] New block                                index=1     l1-timestamp=1713092629 l1-blocknumber=45 tx-hash=0xcab3d8a811aa6512d707817fff5bdd7cb6417fef515cd1ddbf397790fa7f6052 queue-orign=sequencer gas=21000 fees=0 elapsed=228.167µs
```

以上でレプリカの構築は完了です。レプリケーションには数時間から数十時間を要するためアップグレード日までレプリカは起動したままにします。

### Legacyコントラクトのオーナー転送
アップグレードを行うためには一部のLegacyコントラクトのオーナー権限をOasysが提供する[`L1BuildAgent`](../../packages/contracts-bedrock/src/oasys/L1/build/L1BuildAgent.sol)コントラクトに転送しなければなりません。

**L1BuildAgentのコントラクトアドレス**
- Oasys Mainnet: `0x85D92cD5d9b7942f2Ed0d02C6b5120E9D43C52aA`
- Oasys Testnet: `0x85D92cD5d9b7942f2Ed0d02C6b5120E9D43C52aA`

:::warning
！！！！！超注意！！！！！
オーナーの転送は取り消すことが出来ないので十分に注意します。転送先を間違えるとL2の管理権限を永久に失います。
:::

**オーナー転送が必要なLegacyコントラクト**
- AddressManager
  - Transfer Method: `transferOwnership(address newOwner)`
  - ABI: [Lib_AddressManager.json](./docs/abi/Lib_AddressManager.json)
- L1StandardBridge
  - Transfer Method: `setOwner(address _owner)`
  - ABI: [L1ChugSplashProxy.json](./docs/abi/L1ChugSplashProxy.json)
- L1ERC721Bridge
  - Transfer Method: `setOwner(address _owner)`
  - ABI: [L1ChugSplashProxy.json](./docs/abi/L1ChugSplashProxy.json)

Legacyコントラクトのアドレスは`verse-layer-opstack-upgrade/assets/addresses.json`から取得します。
```shell
cd /path/to/verse-layer-opstack/verse-layer-opstack-upgrade

# AddressManager
jq -r .Lib_AddressManager assets/addresses.json

# L1StandardBridge
jq -r .Proxy__OVM_L1StandardBridge assets/addresses.json

# L1ERC721Bridge
jq -r .Proxy__OVM_L1ERC721Bridge assets/addresses.json
```

## 当日作業
### 1. [レガシーノード] レガシーノードの構成変更とRPCのブロック
レガシーノードのdata-transport-layerをアップグレード作業用のコンテナイメージに変更します。また、新しいブロックが作られないようにl2gethのアクセス制御を有効化してRPCをブロックします。

まず、レガシーノードに`verse-layer-optimism/docker-compose.override.yml`ファイルを作成します。既に存在する場合は差分を追加します。
```yaml
services:
  data-transport-layer:
    image: ghcr.io/oasysgames/oasys-optimism/data-transport-layer:op-migrate

  l2geth:
    image: ghcr.io/oasysgames/oasys-optimism/l2geth:op-migrate
    environment:
      ACL_CONFIG: /assets/acl.yml
```

次にアクセス制御設定ファイル`./assets/acl.yml`を作成します。既に存在する場合は中身を完全に置き換えます。
```yaml
from: []
```

コンテナをstop&startして変更を反映させます。**restartではなく必ずstop&startしてください。**
```shell
docker-compose stop data-transport-layer l2geth
docker-compose up -d data-transport-layer l2geth
```

acl.ymlが読み込まれているか確認します。
```shell
docker-compose logs -f --tail=10000 l2geth | grep 'Reload access control config'

l2geth-1  | INFO [04-20|08:20:57.450] Reload access control config             md5hash=4ad59fbe28b0482602e30eb0f0088217
```

### 2. [Builderウォレット] ブリッジコントラクトの停止
BuilderウォレットからL1BuildAgentの`pauseLegacyL1CrossDomainMessenger(uint256 _chainId, address addressManager)`メソッドを実行してL1のブリッジコントラクトを一時的に停止します。`_chainId`にはL2チェーンIDを、`addressManager`にはAddressManagerコントラクトのアドレスを指定します。

[L1BuildAgentのABI](./docs/abi/IL1BuildAgent.json)

### 3. [OPStackノード] デポジットの待機
L1のブリッジコントラクトに送信された全てのデポジットトランザクションがレガシーノードに反映されるのを待ちます。
```shell
cd /path/to/verse-layer-opstack/verse-layer-opstack-upgrade

docker-compose run op-migrate /upgrade/scripts/check-deposits.sh origin
```

`All deposits have been batch submitted`と出力されれば全てのL1デポジットがレガシーノードに反映されています。
```shell
INFO [04-21|06:28:42.844] Checking L2 block                        number=662
INFO [04-21|06:28:42.845] Checking L2 block                        number=661
INFO [04-21|06:28:42.847] Deposit found                            l2-block=661 l1-block=3383 queue-index=253
INFO [04-21|06:28:42.847] Found final deposit in l2geth            queue-index=253
INFO [04-21|06:28:42.848] Remaining deposits that must be submitted count=0
INFO [04-21|06:28:42.848] All deposits have been batch submitted
```

同様に、レプリカにもL1デポジットが反映されるのを待ちます。
```shell
docker-compose run op-migrate /upgrade/scripts/check-deposits.sh replica
```

### 4. [OPStackノード] ロールアップの待機
全てのL2ブロックがL1へロールアップされるのを待ちます。
```shell
cd /path/to/verse-layer-opstack/verse-layer-opstack-upgrade

docker-compose run op-migrate /upgrade/scripts/check-rollups.sh
```

`All batches have been submitted`と出力されれば全てのL2ブロックがL1へロールアップされています。
```
INFO [04-21|06:35:21.603] Waiting for CanonicalTransactionChain
INFO [04-21|06:35:21.603] Waiting for StateCommitmentChain
INFO [04-21|06:35:21.604] Total elements matches block number      name=StateCommitmentChain count=847
INFO [04-21|06:35:21.604] Total elements matches block number      name=CanonicalTransactionChain count=847
INFO [04-21|06:35:21.604] All batches have been submitted
```

### 5. [OPStackノード] レプリケーションの確認
レガシーノードとレプリカが完全同期するのを待ちます。
```shell
cd /path/to/verse-layer-opstack/verse-layer-opstack-upgrade

docker-compose run op-migrate /upgrade/scripts/check-replica.sh
```

`Fully synchronized`と出力されたら完全に同期されています。
```shell
origin : number=847 state=0xc7e84c57135bb52773f7f195885835e87d8ffdd67bdd3ace5ca8b79cac7fc529
replica: number=847 state=0xc7e84c57135bb52773f7f195885835e87d8ffdd67bdd3ace5ca8b79cac7fc529
Fully synchronized
```

### 6. [OPStackノード] レプリカの停止
レプリカを停止します。
```shell
cd /path/to/verse-layer-opstack/verse-layer-opstack-upgrade

docker-compose stop replica
```

停止時にStateTrieのプルーニングが行われるため時間がかかる場合があります。 **その場合もコンテナをKILLせずに正常終了するのを待ってください。** プルーニングが正常終了すると下記のログが出力されます。
```shell
docker-compose logs --tail=100 replica

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

### 7. [Builderウォレット] OPStackコントラクトセットをデプロイ
BuilderウォレットからL1BuildAgentの`build(uint256 chainId, BuildConfig calldata cfg)`メソッドを実行してL1にOPStackのコントラクトセットをデプロイします。引数の指定と順番を間違えないように注意します。`cfg`引数の詳細はこちらを確認してください。
- [Oasys Docs](https://docs.oasys.games/docs/verse-developer/how-to-build-verse/optional-configs#verse-contracts-build-configuration)
- [Contract Code](https://github.com/oasysgames/oasys-opstack/blob/4f2f04d/packages/contracts-bedrock/src/oasys/L1/build/interfaces/IL1BuildAgent.sol#L5-L51)

| 引数名 | 型 | 概要 |
| - | - | - |
| chainId                               | uint256 | L2チェーンID |
| cfg.finalSystemOwner                  | address | OPStackコントラクトセットのオーナー。基本的にはBuilderウォレットを指定します。 |
| cfg.l2OutputOracleProposer            | address | ステートロールアップを行うウォレット。 `OP_PROPOSER_ADDR`を指定します。 |
| cfg.l2OutputOracleChallenger          | address | ステートロールアップの削除を行うウォレット。基本的にはBuilderウォレットを指定します。 |
| cfg.batchSenderAddress                | address | TXデータのロールアップを行うウォレット。`OP_BATCHER_ADDR`を指定します。 |
| cfg.p2pSequencerAddress               | address | `P2P_SEQUENCER_ADDR`を指定します。 |
| cfg.messageRelayer                    | address | L2からL1へブリッジメッセージを中継するウォレット。`MR_FINALIZER_ADDR`を指定します。 |
| cfg.l2BlockTime                       | uint256 | L2のブロック間隔を2〜7秒の間で指定。 |
| cfg.l2GasLimit                        | uint64  | L2ブロックの最大ガス。 特に希望が無い場合は`30000000`を指定します。 |
| cfg.l2OutputOracleSubmissionInterval  | uint256 | ステートロールアップを行うL2のブロック数間隔。 特に希望が無い場合は`80`を指定します。 |
| cfg.finalizationPeriodSeconds         | uint256 | ステートロールアップが最終化される秒数。時に希望がない場合は`604800`(7日間)を指定します。 |
| cfg.l2OutputOracleStartingBlockNumber | uint256 | OPStack L2の開始ブロック番号。 下記のコマンドで取得してください。 |
| cfg.l2OutputOracleStartingTimestamp   | uint256 | OPStack L2の開始ブロック時間。 下記のコマンドで取得してください。 |

`l2OutputOracleStartingBlockNumber`と`l2OutputOracleStartingTimestamp`はOPStackノード上でコマンドを実行して取得してください。
```shell
cd /path/to/verse-layer-opstack/verse-layer-opstack-upgrade

docker-compose run op-migrate /upgrade/scripts/l2oo-starting-block.sh

# Output
l2OutputOracleStartingBlockNumber: 848
l2OutputOracleStartingTimestamp  : 1713686734
```

### 8. [OPStackノード] OPStack構成ファイルのダウンロード
コントラクトセットのデプロイが成功したら[Verse構築ツール](https://tools-fe.oasys.games/check-verse)から`deploy-config.json`と`addresses.json`をダウンロードします。ウォレットアプリ(Metamask等)はOasys Mainnetに接続します。

ダウンロードしたファイルはOPStackノードの`verse-layer-opstack/assets`ディレクトリにコピーします。

### 9. [OPStackノード] データマイグレーション
レプリカが出力したレガシーなチェーンデータをOPStack用のチェーンデータにマイグレーションします。
```shell
cd /path/to/verse-layer-opstack/verse-layer-opstack-upgrade

docker-compose run op-migrate /upgrade/scripts/data-migrate.sh
```

`checked withdrawals`と出力されたらマイグレーションは成功しています。
```shell
INFO [04-21|08:21:58.723] checked L1Block
INFO [04-21|08:21:58.723] recomputing witness data
INFO [04-21|08:21:58.723] checking legacy eth fixed storage slots
INFO [04-21|08:21:58.723] checked legacy eth
INFO [04-21|08:21:58.727] computed withdrawal storage slots        migrated=360              invalid=0
INFO [04-21|08:21:58.733] checked withdrawals
```

念の為チェックコマンドを実行します。先ほどと同様に`checked withdrawals`と出力されていれば問題ありません。
```shell
docker-compose run op-migrate /upgrade/scripts/check-data-migrate.sh
```

マイグレーションが完了したらレプリカの`data`ディレクトリをOPStackノードの`data/op-geth`ディレクトリに移動します。
```shell
cd /path/to/verse-layer-opstack

# 存在しない場合は作成
mkdir data

mv verse-layer-opstack-upgrade/data data/op-geth
```

この際ディレクトリパスが`data/op-geth/data`とならないように注意します。

**正しいディレクトリ構成**
```shell
ls -l data/op-geth

# Output
total 768
drwxr-xr-x  8 user  users     256  4 22 12:22 geth
drwx------  3 user  users      96  4 22 12:16 keystore
-rwxr-xr-x  1 user  users  381041  4 22 12:16 state-dump.txt
```

また、`verse-layer-opstack/assets/rollup.json`ファイルが生成されている事を確認します。
```shell
ls -l assets/rollup.json

# Output
-rwxr-xr-x  1 user  users  1065  4 22 12:28 assets/rollup.json
```

### 10. [レガシーノード] レガシーノードの構成変更
レガシーノードの`verse-layer-optimism/docker-compose.override.yml`に環境変数`ETH1_SYNC_SERVICE_ENABLE: 'false'`を追加します。
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

レガシーノードの全てのコンテナを停止してl2gethコンテナのみを再起動します。アップグレード後のレガシーノードはHistorical Nodeとして稼働させるのでl2geth以外のコンテナは不要となります。
```shell
docker-compose down
docker-compose up -d l2geth
```

### 11. [OPStackノード] OPStackサービスの起動
OPStackノードの`verse-layer-opstack/assets`ディレクトリに以下の必須構成ファイルが存在するか確認します。
- jwt.txt
- addresses.json
- deploy-config.json
- rollup.json

`verse-layer-opstack/docker-compose.override.yml`を作成してHistorical Nodeの環境変数を追加します。
```yaml
services:
  op-geth:
    environment:
      GETH_ROLLUP_HISTORICALRPC: <URL of legacy l2geth rpc>
```

.envファイルに不足している環境変数を追加します。コントラクトアドレスは`verse-layer-opstack/assets/addresses.json`から取得してください。
```shell
# address of the `L2OutputOracleProxy` contract on L1
OP_L2OO_ADDR=
# address of the `AddressManager` contract on L1
OP_AM_ADDR=
# address of the `L1CrossDomainMessengerProxy` contract on L1
OP_L1CDM_ADDR=
# address of the `OptimismPortalProxy` contract on L1
OP_PORTAL_ADDR=
```

`op-geth`と`op-node`コンテナを起動します。
```shell
docker-compose up -d op-geth op-node
```

正しく構成出来ている場合はコントラクトデプロイ時に指定した`cfg.l2BlockTime`の間隔でL2ブロックが生成されます。
```shell
docker-compose logs -f --tail=100 op-geth

# Output
op-geth-1  | INFO [04-21|08:39:48.952] Stopping work on payload                 id=0x273b7c4af4036d30 reason=delivery
op-geth-1  | INFO [04-21|08:39:48.957] Imported new potential chain segment     number=170,743 hash=50b004..c8a88e blocks=1 txs=1 mgas=0.047 elapsed=3.588ms     mgasps=13.055  snapdiffs=2.31MiB    triedirty=0.00B
op-geth-1  | INFO [04-21|08:39:48.958] Chain head was updated                   number=170,743 hash=50b004..c8a88e root=d4bc95..b7f03f elapsed="314.666µs"
op-geth-1  | INFO [04-21|08:39:49.008] Starting work on payload                 id=0x7085fa059a5f525b
op-geth-1  | INFO [04-21|08:39:49.008] Updated payload                          id=0x7085fa059a5f525b number=170,744 hash=664974..d2b1f4 txs=1 withdrawals=0 gas=46841 fees=0 root=cf458c..350bcc elapsed="358.334µs"
```

その他のコンテナも全て起動します。
```shell
docker-compose up -d op-batcher op-proposer message-relayer verse-verifier
```

以上でOPStackへのアップグレードは完了です。
