#!/usr/bin/env sh

# shellcheck disable=SC2039

VOLUME="data"

usage()
{
cat << EOF
usage: docker run [--start-bootnode] | [--bootnode bootnode_address] [--chain-spec chain_spec_file]
      --start-bootnode    Starts a bootnode, which you can refer to in other nodes to form a network
      --bootnode          Bootnode Address
                          eg - "/ip4/127.0.0.1/tcp/30333/p2p/12D3KooWGAGSn6y9vR4eDQWmX2WndeN4PYtodasXLqPALMeCZtr1"
      --chain-spec        Location of the raw chain spec file on the local system

EOF
}

main()  {
  if [ "${#}" -eq 0 ]; then
    usage
    exit 1
  fi

  local is_bootnode="false"
  local bootnode
  local chain_spec_file
  while [ "${#}" -gt 0 ]; do
    case $1 in
      --start-bootnode)
          is_bootnode="true"
          shift 1
          ;;
      --bootnode)
          bootnode="$2"

          if [ -z "$bootnode" ]; then
            echo "Error: Missing bootnode address"
            usage
            exit 1
          fi
          shift 2
          ;;
      --chain-spec)
          chain_spec_file="$2"

          if [ -z "$chain_spec_file" ]; then
            echo "Error: Missing Chain Spec Location"
            usage
            exit 1
          fi

          if [ ! -f "$chain_spec_file" ]; then
            echo "Error: $chain_spec_file does not exist"
            exit 1
          fi

          shift 2
          ;;
      -h|--help)
          usage
          exit 0
          ;;
      *)
          usage "Error: Unknown parameter passed: $1"
          exit 1
          ;;
    esac
  done

  # This is so, testing is easier on local systems
  local supra_executable="supra"
  if ! command -v supra >/dev/null; then
    supra_executable="target/release/supra"
  fi

  if [ ! -d "$VOLUME" ]; then
    mkdir -p "$VOLUME" || echo "$VOLUME could not be created"
  fi

  if [ "$is_bootnode" = "true" ]; then
    ./scripts/create-authority-nodes.sh "$supra_executable" "$VOLUME"
  elif [ -z "$bootnode" ] || [ -z "$chain_spec_file" ]; then
    echo "Both --bootnode and --chain-spec details must be provided"
    usage
    exit 1
  else
    local auth_node_file="$VOLUME/auth_node.key"
    subkey generate --scheme sr25519 > "$auth_node_file"
    local node_key
    node_key=$(sed -n 3p "$auth_node_file" | cut -f2 -d : | xargs)
    node_key=${node_key##0x}

    echo >> "$auth_node_file"
    echo "owner: AccountId: 0x$node_key" >> "$auth_node_file"

    local peer_id
    peer_id="$($supra_executable decode-public-key $node_key | sed -n 3p | cut -f2 -d : | xargs)"
    echo "node: PeerId: 0x$peer_id" >> "$auth_node_file"

    rm -rf /tmp/auth && "$supra_executable" \
      --base-path /tmp/auth \
      --chain "$chain_spec_file" \
      --port 30333 \
      --ws-port 9945 \
      --rpc-port 9933 \
      --no-prometheus --no-telemetry \
      --rpc-methods Unsafe \
      --rpc-cors all \
      --validator \
      --name auth \
      --node-key "$node_key" \
      --bootnodes "$bootnode"
  fi
}

main "$@"
