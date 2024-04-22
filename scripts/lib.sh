#!/bin/bash

legacy_address() {
  grep "$1" /upgrade/assets/addresses.json | grep -oP '0x[a-fA-F0-9]+'
}
