#!/bin/bash

set -eu

. /upgrade/scripts/lib.sh

BLOCK="${1:-latest}"

while true; do
  origin_number="$(cast block --json --rpc-url $ORIGIN_RPC_URL $BLOCK | jq -rM .number)"
  origin_hash="$(cast   block --json --rpc-url $ORIGIN_RPC_URL $BLOCK | jq -rM .hash)"
  origin_state="$(cast  block --json --rpc-url $ORIGIN_RPC_URL $BLOCK | jq -rM .stateRoot)"

  replica_number="$(cast block --json --rpc-url $REPLICA_RPC_URL $BLOCK | jq -rM .number)"
  replica_hash="$(cast   block --json --rpc-url $REPLICA_RPC_URL $BLOCK | jq -rM .hash)"
  replica_state="$(cast  block --json --rpc-url $REPLICA_RPC_URL $BLOCK | jq -rM .stateRoot)"

  if [ x"$origin_number" == x -o x"$replica_number" == x ]; then
    echo "Error: Failed to retrieve latest block" >&2
    exit 1
  fi

  echo "origin : number=$((16#${origin_number:2})) hash=${origin_hash} state=${origin_state}"
  echo "replica: number=$((16#${replica_number:2})) hash=${replica_hash} state=${replica_state}"

  if [ "$origin_number" == "$replica_number" -a "$origin_hash" == "$replica_hash" -a "$origin_state" == "$replica_state" ]; then
    echo Synchronized
    exit 0
  fi

  echo -n "Waiting for synchronization"
  for i in $(seq 5); do
    sleep 1
    echo -n .
  done
  echo;echo
done
