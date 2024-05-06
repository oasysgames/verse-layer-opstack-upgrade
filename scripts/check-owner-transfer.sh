#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
    source .env
else
    echo "The .env file is missing."
    exit 1
fi

# Ensure required environment variables are set
if [ -z "$L1_HTTP_URL" ] || [ -z "$PATH_VERSE_LAYER_OPTIMISM" ]; then
    echo "Required environment variables are missing."
    echo "Make sure L1_HTTP_URL, PATH_VERSE_LAYER_OPTIMISM are set."
    exit 1
fi

# Check if the addresses.json file does not exist
if [ ! -f "$PATH_VERSE_LAYER_OPTIMISM/assets/addresses.json" ]; then
    echo "Error: addresses.json file not found in $PATH_VERSE_LAYER_OPTIMISM/assets/"
    exit 1
fi

# Parse the required properties from the JSON file
ADDRESS_MANAGER_ADDRESS=$(jq -r '.Lib_AddressManager' "$PATH_VERSE_LAYER_OPTIMISM/assets/addresses.json")
L1_STANDARD_BRIDGE_ADDRESS=$(jq -r '.Proxy__OVM_L1StandardBridge' "$PATH_VERSE_LAYER_OPTIMISM/assets/addresses.json")
L1_ERC721_BRIDGE_ADDRESS=$(jq -r '.Proxy__OVM_L1ERC721Bridge' "$PATH_VERSE_LAYER_OPTIMISM/assets/addresses.json")
STATE_COMMITMENT_CHAIN_ADDRESS=$(jq -r '.StateCommitmentChain' "$PATH_VERSE_LAYER_OPTIMISM/assets/addresses.json")

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
        --data "{\"method\":\"eth_call\",\"params\":[{\"from\":\"$L1_BUILD_AGENT_ADDRESS\",\"to\":\"$to_address\",\"data\":\"$data\"}, \"latest\"],\"id\":1,\"jsonrpc\":\"2.0\"}" | jq -r .result)

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
