#!/usr/bin/env bash
# set -eu

cargo build --release

./target/release/node-template --dev --tmp --enable-offchain-indexing true
