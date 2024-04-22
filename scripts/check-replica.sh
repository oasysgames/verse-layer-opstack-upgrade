#!/bin/bash

set -eu

. /upgrade/scripts/lib.sh

while true; do
  origin_number="$(cast block-number --rpc-url $ORIGIN_RPC_URL)"
  origin_state="$(cast block -j --rpc-url $ORIGIN_RPC_URL | jq -rM .stateRoot)"

  replica_number="$(cast block-number --rpc-url $REPLICA_RPC_URL)"
  replica_state="$(cast block -j --rpc-url $REPLICA_RPC_URL | jq -rM .stateRoot)"

  if [ x"$origin_number" == x -o x"$replica_number" == x ]; then
    echo "Error: Failed to retrieve latest block" >&2
    exit 1
  fi

  echo "origin : number=${origin_number} state=${origin_state}"
  echo "replica: number=${replica_number} state=${replica_state}"

  if [ "$origin_number" == "$replica_number" -a "$origin_state" == "$replica_state" ]; then
    echo "Fully synchronized"
    exit 0
  fi

  echo -n "Waiting for synchronization"
  for i in $(seq 5); do
    sleep 1
    echo -n .
  done
  echo;echo
done
