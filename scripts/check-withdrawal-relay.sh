#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
    source .env
else
    echo "The .env file is missing."
    exit 1
fi

# Ensure the required environment variables are set
if [ -z "$STATE_COMMITMENT_CHAIN_ADDRESS" ] || [ -z "$L1_HTTP_URL" ]; then
    echo "Required environment variables are missing."
    echo "Make sure STATE_COMMITMENT_CHAIN_ADDRESS and L1_HTTP_URL are set."
    exit 1
fi

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
