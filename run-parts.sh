#!/usr/bin/env bash
# set -eu

# gnome-terminal --command  cd front-end && yarn start

cargo build --release

./target/release/node-template --dev --tmp --enable-offchain-indexing true
