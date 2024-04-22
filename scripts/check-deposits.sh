#!/bin/bash

. /upgrade/scripts/lib.sh

if [ "$1" == "origin" ]; then
  L2_HTTP_URL="$ORIGIN_RPC_URL"
elif [ "$1" == "replica" ]; then
  L2_HTTP_URL="$REPLICA_RPC_URL"
fi

exec op-migrate-rollover deposits \
  --l1-rpc-url $L1_HTTP_URL \
  --l2-rpc-url $L2_HTTP_URL \
  --address-manager-address $(legacy_address Lib_AddressManager) \
  --canonical-transaction-chain-address $(legacy_address CanonicalTransactionChain) \
  --state-commitment-chain-address $(legacy_address StateCommitmentChain)
