#!/bin/bash

set -eu

op-migrate \
  --l1-rpc-url=$L1_HTTP_URL \
  --l1-deployments=/opstack/assets/addresses.json \
  --deploy-config=/opstack/assets/deploy-config.json \
  --ovm-addresses=/upgrade/assets/empty.json \
  --ovm-allowances=/upgrade/assets/empty.json \
  --ovm-messages=/upgrade/assets/empty.json \
  --witness-file=/upgrade/data/state-dump.txt \
  --db-path=/upgrade/data \
  --rollup-config-out=/opstack/assets/rollup.json
