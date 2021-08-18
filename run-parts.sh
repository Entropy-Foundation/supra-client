#!/usr/bin/env bash
# set -eu

cargo build --release && ./target/release/supra --dev --tmp --enable-offchain-indexing true
