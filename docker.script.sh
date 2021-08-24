#!/usr/bin/env sh

echo Arguments: "$@"
supra --node-key="$(subkey generate-node-key > node-key 2>&1 && cat node-key | tail -1)" "$@"
