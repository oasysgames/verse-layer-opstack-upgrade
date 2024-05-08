#!/bin/bash

set -eu

. /upgrade/scripts/lib.sh

ADDRESS_MANAGER_ADDRESS=$(legacy_address Lib_AddressManager)
L1_STANDARD_BRIDGE_ADDRESS=$(legacy_address Proxy__OVM_L1StandardBridge)
L1_ERC721_BRIDGE_ADDRESS=$(legacy_address Proxy__OVM_L1ERC721Bridge)
STATE_COMMITMENT_CHAIN_ADDRESS=$(legacy_address StateCommitmentChain)

# Function to perform the validation
validate_address() {
    local to_address=$1
    local data=$2
    local message=$3

    echo "$message"

    # Zero pad L1_BUILD_AGENT_ADDRESS to 32 bytes (64 hex characters)
    padded_address=$(printf '%064s' "${L1_BUILD_AGENT_ADDRESS:2}")

    # Convert to lowercase
    expected="0x$padded_address"
    expected_lower=$(echo "$expected" | tr '[:upper:]' '[:lower:]')

    # Make the HTTP request and capture the result
    response=$(curl -s $L1_HTTP_URL \
        -X POST \
        -H "Content-Type: application/json" \
        --data "{\"method\":\"eth_call\",\"params\":[{\"from\":null,\"to\":\"$to_address\",\"data\":\"$data\"}, \"latest\"],\"id\":1,\"jsonrpc\":\"2.0\"}" | jq -r .result)

    # Validate the response
    if [ "$response" == "$expected_lower" ]; then
        echo "Success: The response matches the padded L1_BUILD_AGENT_ADDRESS."
    else
        echo "Failure: The response does not match the padded L1_BUILD_AGENT_ADDRESS."
        echo "Expected: $expected_lower"
        echo "Actual:   $response"
    fi
}

# 1st comparison
validate_address "$ADDRESS_MANAGER_ADDRESS" "0x8da5cb5b" "1st: Make sure ownership of AddressManager is transferred to L1BuildAgent"

# 2nd comparison
validate_address "$L1_STANDARD_BRIDGE_ADDRESS" "0x893d20e8" "2nd: Make sure ownership of L1StandardBridge is transferred to L1BuildAgent"

# 3rd comparison
validate_address "$L1_ERC721_BRIDGE_ADDRESS" "0x893d20e8" "3rd: Make sure ownership of L1ERC721Bridge is transferred to L1BuildAgent"
