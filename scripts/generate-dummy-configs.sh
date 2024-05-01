#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
    source .env
else
    echo "The .env file is missing."
    exit 1
fi

# Check that required environment variables are defined
if [ -z "$PATH_VERSE_LAYER_OPSTACK" ] || [ -z "$L1_HTTP_URL" ]; then
    echo "Required environment variables are missing."
    echo "Make sure PATH_VERSE_LAYER_OPSTACK and L1_HTTP_URL are set."
    exit 1
fi

# Check if the assets directory exists
assets_dir="$PATH_VERSE_LAYER_OPSTACK/assets"
if [ ! -d "$assets_dir" ]; then
    echo "Directory $assets_dir does not exist."
    exit 1
fi

# Check if the specified files exist and warn
addresses_file="$assets_dir/addresses.json"
deploy_config_file="$assets_dir/deploy-config.json"

if [ -f "$addresses_file" ]; then
    echo "Warning: $addresses_file already exists."
fi
if [ -f "$deploy_config_file" ]; then
    echo "Warning: $deploy_config_file already exists."
fi

# Write the JSON data to addresses.json
cat > "$addresses_file" << EOF
{
    "ProxyAdmin": "0xffffffffffffffffffffffffffffffffffffffff",
    "SystemConfigProxy": "0xffffffffffffffffffffffffffffffffffffffff",
    "L1StandardBridgeProxy": "0xffffffffffffffffffffffffffffffffffffffff",
    "L1ERC721BridgeProxy": "0xffffffffffffffffffffffffffffffffffffffff",
    "L1CrossDomainMessengerProxy": "0xffffffffffffffffffffffffffffffffffffffff",
    "L2OutputOracleProxy": "0xffffffffffffffffffffffffffffffffffffffff",
    "OptimismPortalProxy": "0xffffffffffffffffffffffffffffffffffffffff",
    "ProtocolVersions": "0xffffffffffffffffffffffffffffffffffffffff",
    "BatchInbox": "0xffffffffffffffffffffffffffffffffffffffff",
    "AddressManager": "0xffffffffffffffffffffffffffffffffffffffff",
    "P2PSequencer": "0xffffffffffffffffffffffffffffffffffffffff",
    "FinalSystemOwner": "0xffffffffffffffffffffffffffffffffffffffff",
    "L2OutputOracleProposer": "0xffffffffffffffffffffffffffffffffffffffff",
    "L2OutputOracleChallenger": "0xffffffffffffffffffffffffffffffffffffffff",
    "BatchSender": "0xffffffffffffffffffffffffffffffffffffffff"
}
EOF

# Write the JSON data to deploy-config.json
cat > "$deploy_config_file" << EOF
{
  "baseFeeVaultMinimumWithdrawalAmount": "0x8ac7230489e80000",
  "baseFeeVaultRecipient": "0xffffffffffffffffffffffffffffffffffffffff",
  "baseFeeVaultWithdrawalNetwork": 0,
  "batchInboxAddress": "0xffffffffffffffffffffffffffffffffffffffff",
  "batchSenderAddress": "0xffffffffffffffffffffffffffffffffffffffff",
  "channelTimeout": 300,
  "eip1559Denominator": 50,
  "eip1559DenominatorCanyon": 250,
  "eip1559Elasticity": 10,
  "enableGovernance": false,
  "finalSystemOwner": "0xffffffffffffffffffffffffffffffffffffffff",
  "finalizationPeriodSeconds": 604800,
  "gasPriceOracleOverhead": 188,
  "gasPriceOracleScalar": 684000,
  "governanceTokenName": "",
  "governanceTokenOwner": "0xffffffffffffffffffffffffffffffffffffffff",
  "governanceTokenSymbol": "",
  "l1BlockTime": 15,
  "l1ChainID": 12345,
  "l1CrossDomainMessengerProxy": "0xffffffffffffffffffffffffffffffffffffffff",
  "l1ERC721BridgeProxy": "0xffffffffffffffffffffffffffffffffffffffff",
  "l1FeeVaultMinimumWithdrawalAmount": "0x8ac7230489e80000",
  "l1FeeVaultRecipient": "0xffffffffffffffffffffffffffffffffffffffff",
  "l1FeeVaultWithdrawalNetwork": 0,
  "l1StandardBridgeProxy": "0xffffffffffffffffffffffffffffffffffffffff",
  "l1StartingBlockTag": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "l2BlockTime": 1,
  "l2ChainID": 4200,
  "l2GenesisBlockBaseFeePerGas": "0x0",
  "l2GenesisBlockGasLimit": "0x1c9c380",
  "l2GenesisRegolithTimeOffset": "0x0",
  "l2OutputOracleChallenger": "0xffffffffffffffffffffffffffffffffffffffff",
  "l2OutputOracleProposer": "0xffffffffffffffffffffffffffffffffffffffff",
  "l2OutputOracleStartingBlockNumber": 0,
  "l2OutputOracleStartingTimestamp": 0,
  "l2OutputOracleSubmissionInterval": 80,
  "l2ZeroFeeTime": 1714490532,
  "maxSequencerDrift": 600,
  "optimismPortalProxy": "0xffffffffffffffffffffffffffffffffffffffff",
  "p2pSequencerAddress": "0xffffffffffffffffffffffffffffffffffffffff",
  "portalGuardian": "0xffffffffffffffffffffffffffffffffffffffff",
  "proxyAdminOwner": "0xffffffffffffffffffffffffffffffffffffffff",
  "recommendedProtocolVersion": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "requiredProtocolVersion": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "sequencerFeeVaultMinimumWithdrawalAmount": "0x8ac7230489e80000",
  "sequencerFeeVaultRecipient": "0xffffffffffffffffffffffffffffffffffffffff",
  "sequencerFeeVaultWithdrawalNetwork": 0,
  "sequencerWindowSize": 3600,
  "systemConfigProxy": "0xffffffffffffffffffffffffffffffffffffffff",
  "systemConfigStartBlock": 0
}
EOF

# Obtain the latest block
latest_block=$(curl -s $L1_HTTP_URL \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"method":"eth_getBlockByNumber","params":["latest", false],"id":1,"jsonrpc":"2.0"}' | jq -r '.result')

# Extract the required properties from the latest block
block_number=$(printf "%d" $(echo "$latest_block" | jq -r '.number'))
block_hash=$(echo "$latest_block" | jq -r '.hash')
block_timestamp=$(printf "%d" $(echo "$latest_block" | jq -r '.timestamp'))

# Update the deploy-config.json file with the extracted data
jq --argjson systemConfigStartBlock "$block_number" \
   --arg l1StartingBlockTag "$block_hash" \
   --argjson l2OutputOracleStartingTimestamp "$block_timestamp" \
   '.systemConfigStartBlock = $systemConfigStartBlock |
    .l1StartingBlockTag = $l1StartingBlockTag |
    .l2OutputOracleStartingTimestamp = $l2OutputOracleStartingTimestamp' \
   "$deploy_config_file" > "${deploy_config_file}.tmp" && mv "${deploy_config_file}.tmp" "$deploy_config_file"

