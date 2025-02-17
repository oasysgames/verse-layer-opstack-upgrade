#!/bin/bash

set -eu

. /upgrade/scripts/lib.sh

L2_BLOCK=$(cast block-number --rpc-url $ORIGIN_RPC_URL)
L1_TIMESTAMP=$(cast block --json --rpc-url $L1_HTTP_URL | jq .timestamp)

echo "l2OutputOracleStartingBlockNumber: $((L2_BLOCK+1))"
echo "l2OutputOracleStartingTimestamp  : $((16#${L1_TIMESTAMP:3:-1}))"
