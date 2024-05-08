#!/bin/bash

set -eu

. /upgrade/scripts/lib.sh

exec op-migrate-rollover batches \
  --l1-rpc-url $L1_HTTP_URL \
  --l2-rpc-url $ORIGIN_RPC_URL \
  --address-manager-address $(legacy_address Lib_AddressManager) \
  --canonical-transaction-chain-address $(legacy_address CanonicalTransactionChain) \
  --state-commitment-chain-address $(legacy_address StateCommitmentChain)
