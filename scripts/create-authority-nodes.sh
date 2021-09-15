#!/usr/bin/env sh

# shellcheck disable=SC2005

# Output files
NODE1_KEY_FILE="node1.key"
NODE2_KEY_FILE="node2.key"
CHAIN_SPEC_FILE="chainSpec.json"
RAW_CHAIN_SPEC_FILE="rawChainSpec.json"
NODE_COMMON_PARAMS="--no-prometheus --no-telemetry --rpc-methods Unsafe --rpc-cors all"
NODE1_RPC_PORT=9933
NODE2_RPC_PORT=9934

main()  {
  # TODO:
  # Check if `local` works inside docker containers
  local supra=$1
  local pass_phrase
  local node1_ss58_key
  local node2_ss58_key
  local node1_node_key
  local node2_node_key
  local gran_key
  local peer_id_vec

  # Generate the default chainSpec.json
  ${supra} build-spec --disable-default-bootnode --chain local > "${CHAIN_SPEC_FILE}" 2> /dev/null && echo "Generated Chain Spec"

  # Node1 - AURA and GRANDPA keys
  subkey generate --scheme sr25519 > ${NODE1_KEY_FILE}
  pass_phrase="$(get_mnemonics ${NODE1_KEY_FILE})"
  subkey inspect --scheme ed25519 "${pass_phrase}" > "${NODE1_KEY_FILE%.*}_grandpa.key"

  # Node1 - Parse out the Aura & Grandpa Public Keys
  node1_ss58_key="$(get_public_key_ss58 ${NODE1_KEY_FILE})"
  gran_key="$(get_public_key_ss58 ${NODE1_KEY_FILE%.*}_grandpa.key)"

  # Node1 - Add Aura & Grandpa Keys to chainSpec
  search_skip_replace "palletAura" 2 '"'"$node1_ss58_key"'",' "${CHAIN_SPEC_FILE}"
  search_skip_replace "palletGrandpa" 3 '"'"$gran_key"'",' "${CHAIN_SPEC_FILE}"

  # Node2 - AURA and GRANDPA keys
  subkey generate --scheme sr25519 > ${NODE2_KEY_FILE}
  pass_phrase="$(get_mnemonics ${NODE2_KEY_FILE})"
  subkey inspect --scheme ed25519 "${pass_phrase}" > "${NODE2_KEY_FILE%.*}_grandpa.key"

  # Node2 - Parse out the Aura & Grandpa Public Keys
  node2_ss58_key=$(get_public_key_ss58 "${NODE2_KEY_FILE}")
  gran_key=$(get_public_key_ss58 "${NODE2_KEY_FILE%.*}_grandpa.key")

  # Node2 - Add Aura & Grandpa Keys to chainSpec
  search_skip_replace "palletAura" 3 '"'"$node2_ss58_key"'"' "${CHAIN_SPEC_FILE}"
  search_skip_replace "palletGrandpa" 7 '"'"$gran_key"'",' "${CHAIN_SPEC_FILE}"

  # Remove palletBalances & palletSudo sections
  sed -i '/palletBalances/,+54d' "${CHAIN_SPEC_FILE}"

  # Node1 - Add peer_id vector & Public Key to chainSpec
  peer_id_vec=$(generate_decoded_peer_id_file "${NODE1_KEY_FILE}")
  search_skip_delete_insert "supraAuthorization" 3 40 "${peer_id_vec}," "${CHAIN_SPEC_FILE}"
  search_skip_delete_insert "supraAuthorization" 4 1 "\"${node1_ss58_key}\"" "${CHAIN_SPEC_FILE}"

  # Node2 - Add peer_id vector & Public Key to chainSpec
  peer_id_vec=$(generate_decoded_peer_id_file "${NODE2_KEY_FILE}")
  search_skip_delete_insert "supraAuthorization" 7 40 "${peer_id_vec}," "${CHAIN_SPEC_FILE}"
  search_skip_delete_insert "supraAuthorization" 8 1 "\"${node2_ss58_key}\"" "${CHAIN_SPEC_FILE}"

  # Generate the rawChainSpec.json
  ${supra} build-spec --chain="${CHAIN_SPEC_FILE}" --raw --disable-default-bootnode > "${RAW_CHAIN_SPEC_FILE}" 2> /dev/null && echo "Generated Raw Chain Spec"

  node1_node_key="$(get_node_key ${NODE1_KEY_FILE})"
  node2_node_key="$(get_node_key ${NODE2_KEY_FILE})"

  # Start node1 and node2
  rm -rf /tmp/one && ${supra} --rpc-port "$NODE1_RPC_PORT" --node-key "$node1_node_key" --chain "${RAW_CHAIN_SPEC_FILE}" --base-path /tmp/one --one --ws-port 9945 --port 30333 $NODE_COMMON_PARAMS &
  rm -rf /tmp/two && ${supra} --rpc-port "$NODE2_RPC_PORT" --node-key "$node2_node_key" --chain "${RAW_CHAIN_SPEC_FILE}" --bootnodes /ip4/127.0.0.1/tcp/30333/p2p/"$(get_peer_id ${NODE1_KEY_FILE%.*}_decoded.key)" --base-path /tmp/two --two --ws-port 9946 --port 30334 $NODE_COMMON_PARAMS &

  sleep 10 # Wait till the nodes start

  # Add AURA & GRANDPA keys to the to node1 and node2's keystore
  add_to_keystore "aura" "${NODE1_KEY_FILE}" "$NODE1_RPC_PORT"
  add_to_keystore "gran" "${NODE1_KEY_FILE%.*}_grandpa.key" "$NODE1_RPC_PORT"
  add_to_keystore "aura" "${NODE2_KEY_FILE}" "$NODE2_RPC_PORT"
  add_to_keystore "gran" "${NODE2_KEY_FILE%.*}_grandpa.key" "$NODE2_RPC_PORT"

  # Restart both the nodes
  kill "$(ps aux | grep "$node1_node_key" | awk '{print $2}' | head -1)" && echo "Node1 stopped"
  kill "$(ps aux | grep "$node2_node_key" | awk '{print $2}' | head -1)" && echo "Node2 stopped"
  ${supra} --rpc-port "$NODE1_RPC_PORT" --node-key "$node1_node_key" --chain "${RAW_CHAIN_SPEC_FILE}" --base-path /tmp/one --one --ws-port 9945 --port 30333 $NODE_COMMON_PARAMS &
  ${supra} --rpc-port "$NODE2_RPC_PORT" --node-key "$node2_node_key" --chain "${RAW_CHAIN_SPEC_FILE}" --bootnodes /ip4/127.0.0.1/tcp/30333/p2p/"$(get_peer_id ${NODE1_KEY_FILE%.*}_decoded.key)" --base-path /tmp/two --two --ws-port 9946 --port 30334 $NODE_COMMON_PARAMS &
  wait
}

generate_request_body(){
  local key_type="$1"
  local pass_phrase="$2"
  local pub_key="$3"

  cat <<EOF
{
  "jsonrpc":"2.0",
  "id":1,
  "method":"author_insertKey",
  "params": [
    "$key_type",
    "$pass_phrase",
    "$pub_key"
  ]
}
EOF
}

add_to_keystore() {
  local key_type=$1
  local key_file=$2
  local port=$3
  local request_body="$(generate_request_body "$key_type" "$(get_mnemonics ${key_file})" "$(get_public_key_hex ${key_file})")"
  curl --location --request POST "http://127.0.0.1:$port" --header 'Content-Type: application/json' --data-raw "$request_body"
}

get_peer_id(){
  echo "$(sed -n 2p $1 | cut -f2 -d : | xargs)"
}

get_public_key_hex() {
  echo "$(sed -n 3p $1 | cut -f2 -d : | xargs)"
}

get_node_key() {
  local node_key="$(get_public_key_hex $1)"
  echo "${node_key##0x}"
}

get_public_key_ss58() {
  echo "$(tail -1 $1 | cut -f2 -d : | xargs)"
}

get_mnemonics() {
  echo "$(head -1 $1 | cut -f2 -d : | xargs)"
}

generate_decoded_peer_id_file() {
  local key_file=$1

  # Public key (hex) from `subkey generate --scheme sr25519` = node_key
  local node_key="$(get_node_key $key_file)"

  # Decode the Node-Key to get PeerID
  ${supra} decode-public-key ${node_key} > "${key_file%.*}"_decoded.key

  echo "$(tail -1 "${key_file%.*}"_decoded.key | cut -f2 -d : | xargs)"
}

search_skip_delete_insert() {
  local search_text="$1"
  local number_of_lines_to_skip="$2"
  local number_of_lines_to_delete="$3"
  local insert_text="$4"
  local file="$5"

  local match_found_line_number="$(grep -n ${search_text} "$file" | cut -f1 -d :)"

  if [ "$match_found_line_number" -eq 0 ]; then
    return
  fi

  local delete_start=$((match_found_line_number + number_of_lines_to_skip))
  local delete_end=$((delete_start + number_of_lines_to_delete - 1))

  sed -i "${delete_start},${delete_end}d" "$file"
  sed -i "${delete_start} i ${insert_text}" "$file"
}

search_skip_replace() {
  local search_text="$1"
  local number_of_lines_to_skip="$2"
  local replace_text="$3"
  local file="$4"

  local match_found_line_number="$(grep -n ${search_text} "$file" | cut -f1 -d :)"

  if [ "$match_found_line_number" -eq 0 ]; then
    return
  fi

  local replace_text_at_line_number=$((match_found_line_number + number_of_lines_to_skip))
  sed -i "${replace_text_at_line_number}s/.*/${replace_text}/" "$file"
}

main "$@"
