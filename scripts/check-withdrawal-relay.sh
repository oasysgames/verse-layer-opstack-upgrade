#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
    source .env
else
    echo "The .env file is missing."
    exit 1
fi

# Ensure the required environment variables are set
if [ -z "$PATH_VERSE_LAYER_OPTIMISM" ] || [ -z "$L1_HTTP_URL" ]; then
    echo "Required environment variables are missing."
    echo "Make sure PATH_VERSE_LAYER_OPTIMISM and L1_HTTP_URL are set."
    exit 1
fi

# Check if the addresses.json file does not exist
if [ ! -f "$PATH_VERSE_LAYER_OPTIMISM/assets/addresses.json" ]; then
    echo "Error: addresses.json file not found in $PATH_VERSE_LAYER_OPTIMISM/assets/"
    exit 1
fi

# Parse the required properties from the JSON file
STATE_COMMITMENT_CHAIN_ADDRESS=$(jq -r '.StateCommitmentChain' "$PATH_VERSE_LAYER_OPTIMISM/assets/addresses.json")

# Function to convert hex to decimal
hex_to_dec() {
    echo $((16#$1))
}

# Function to make HTTP requests and get the result
get_hex_result() {
    local data=$1
    curl -s $L1_HTTP_URL \
        -X POST \
        -H "Content-Type: application/json" \
        --data "{\"method\":\"eth_call\",\"params\":[{\"from\": null, \"to\": \"$STATE_COMMITMENT_CHAIN_ADDRESS\",\"data\": \"$data\"}, \"latest\"],\"id\":1,\"jsonrpc\":\"2.0\"}" | jq -r .result
}

# Get the numbers from the endpoints
result1_hex=$(get_hex_result "0xe561dddc")
result2_hex=$(get_hex_result "0xfc7e9c6f")

# Convert to decimal
result1=$(hex_to_dec "${result1_hex:2}")
result2=$(hex_to_dec "${result2_hex:2}")

# Print the numbers before comparison
echo "Submitted Indexs: $result1"
echo "Verified Indexs : $result2"

# Compare the results
if [ "$result1" -eq "$result2" ]; then
    echo "Success: The numbers match."
else
    echo "Error: The numbers do not match. L2 state is not yet instant verified."
    echo "Wait 1 minute and then run the script again."
fi
