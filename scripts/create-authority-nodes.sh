#!/usr/bin/env sh

# shellcheck disable=SC2005

NODE1_RPC_PORT=9933
NODE2_RPC_PORT=9934
NODE_COMMON_PARAMS="--no-prometheus --no-telemetry --rpc-methods Unsafe --rpc-cors all"

# Output files
NODE1_KEY_FILE="bootnode.key"
NODE2_KEY_FILE="node2.key"
CHAIN_SPEC_FILE="chainSpec.json"
RAW_CHAIN_SPEC_FILE="rawChainSpec.json"

main()  {
  local supra="$1"
  local out_dir="$2"
  local pass_phrase
  local node1_ss58_key
  local node2_ss58_key
  local node1_node_key
  local node2_node_key
  local gran_key
  local peer_id_vec

  # Create Output directory if it does not exist
  if [ ! -d "$out_dir" ]; then
    mkdir -p "$out_dir"
  fi

  NODE1_KEY_FILE="$out_dir/$NODE1_KEY_FILE"
  RAW_CHAIN_SPEC_FILE="$out_dir/$RAW_CHAIN_SPEC_FILE"

  # Generate the default chainSpec.json
  ${supra} build-spec --disable-default-bootnode --chain local > "${CHAIN_SPEC_FILE}" 2> /dev/null && echo "Generated ${CHAIN_SPEC_FILE}"

  # Add node1 & node2 AURA & GRANDPA keys to chainSpec.json
  add_aura_grandpa_keys_to_chainspec 2 3 "${NODE1_KEY_FILE}" && echo "Node1 - AURA/GRANDPA key added to ${CHAIN_SPEC_FILE}" || echo "Failed: Node1 - Adding AURA/GRANDPA keys to ${CHAIN_SPEC_FILE}"
  add_aura_grandpa_keys_to_chainspec 3 7 "${NODE2_KEY_FILE}" && echo "Node2 - AURA/GRANDPA key added to ${CHAIN_SPEC_FILE}" || echo "Failed: Node2 - Adding AURA/GRANDPA keys to ${CHAIN_SPEC_FILE}"

  # Add node1 & node2 peer_id vectors to chainSpec.json
  node1_ss58_key="$(get_public_key_ss58 ${NODE1_KEY_FILE})"
  node2_ss58_key=$(get_public_key_ss58 "${NODE2_KEY_FILE}")
  add_peer_id_vec_to_chainspec 3 "${node1_ss58_key}" "${NODE1_KEY_FILE}" && echo "Node1 - Added PeerID to ${CHAIN_SPEC_FILE}" || echo "Failed: Node1 - Adding PeerID to ${CHAIN_SPEC_FILE}"
  add_peer_id_vec_to_chainspec 7 "${node2_ss58_key}" "${NODE2_KEY_FILE}" && echo "Node2 - Added PeerID to ${CHAIN_SPEC_FILE}" || echo "Failed: Node2 - Adding PeerID to ${CHAIN_SPEC_FILE}"

  # Generate the rawChainSpec.json
  ${supra} build-spec --chain="${CHAIN_SPEC_FILE}" --raw --disable-default-bootnode > "${RAW_CHAIN_SPEC_FILE}" 2> /dev/null && echo "Generated ${RAW_CHAIN_SPEC_FILE}"

  node1_node_key="$(get_node_key ${NODE1_KEY_FILE})"
  node2_node_key="$(get_node_key ${NODE2_KEY_FILE})"

  # Start node1 and node2
  rm -rf /tmp/one && echo "Starting - Node1" && ${supra} --rpc-port "$NODE1_RPC_PORT" --node-key "$node1_node_key" --chain "${RAW_CHAIN_SPEC_FILE}" --base-path /tmp/one --one --ws-port 9945 --port 30333 $NODE_COMMON_PARAMS &
  rm -rf /tmp/two && echo "Starting - Node2" && ${supra} --rpc-port "$NODE2_RPC_PORT" --node-key "$node2_node_key" --chain "${RAW_CHAIN_SPEC_FILE}" --bootnodes /ip4/127.0.0.1/tcp/30333/p2p/"$(get_peer_id ${NODE1_KEY_FILE%.*}_decoded.key)" --base-path /tmp/two --two --ws-port 9946 --port 30334 $NODE_COMMON_PARAMS &

  sleep 10 # Wait for the nodes to start

  # Add AURA & GRANDPA keys to the to node1 and node2's keystore
  add_key_to_node_keystore "aura" "${NODE1_KEY_FILE}" "$NODE1_RPC_PORT" && echo "Node1 - Aura key added to keystore"  || echo "Failed: Node1 - Aura key to keystore"
  add_key_to_node_keystore "gran" "${NODE1_KEY_FILE%.*}_grandpa.key" "$NODE1_RPC_PORT" && echo "Node1 - Grandpa key added to keystore"  || echo "Failed: Node1 - Grandpa key to keystore"
  add_key_to_node_keystore "aura" "${NODE2_KEY_FILE}" "$NODE2_RPC_PORT" && echo "Node2 - Aura key added to keystore"  || echo "Failed: Node2 - Aura key to keystore"
  add_key_to_node_keystore "gran" "${NODE2_KEY_FILE%.*}_grandpa.key" "$NODE2_RPC_PORT" && echo "Node2 - Grandpa key added to keystore"  || echo "Failed: Node2 - Grandpa key to keystore"

  # Restart both the nodes
  kill "$(ps aux | grep "$node1_node_key" | awk '{print $2}' | head -1)" && echo "Node1 stopped"
  kill "$(ps aux | grep "$node2_node_key" | awk '{print $2}' | head -1)" && echo "Node2 stopped"
  echo "Starting - Node1" && ${supra} --rpc-port "$NODE1_RPC_PORT" --node-key "$node1_node_key" --chain "${RAW_CHAIN_SPEC_FILE}" --base-path /tmp/one --one --ws-port 9945 --port 30333 $NODE_COMMON_PARAMS &
  echo "Starting - Node2" && ${supra} --rpc-port "$NODE2_RPC_PORT" --node-key "$node2_node_key" --chain "${RAW_CHAIN_SPEC_FILE}" --bootnodes /ip4/127.0.0.1/tcp/30333/p2p/"$(get_peer_id ${NODE1_KEY_FILE%.*}_decoded.key)" --base-path /tmp/two --two --ws-port 9946 --port 30334 $NODE_COMMON_PARAMS > /dev/null 2>&1 &

  wait
}

add_aura_grandpa_keys_to_chainspec() {
  local aura_key_insert_offset="$1"
  local grandpa_key_insert_offset="$2"
  local key_file="$3"

  # Node1 - AURA and GRANDPA keys
  subkey generate --scheme sr25519 > ${key_file}
  local pass_phrase="$(get_mnemonics ${key_file})"
  subkey inspect --scheme ed25519 "${pass_phrase}" > "${key_file%.*}_grandpa.key"

  # Node1 - Parse out the Aura & Grandpa Public Keys
  local node1_ss58_key="$(get_public_key_ss58 ${key_file})"
  local gran_key="$(get_public_key_ss58 ${key_file%.*}_grandpa.key)"

  # Ugly hack - but reduces code duplication
  if [ "$key_file" = "$NODE1_KEY_FILE" ]; then
    node1_ss58_key='"'"$node1_ss58_key"'",' # Adds a command at the end
  else
    node1_ss58_key='"'"$node1_ss58_key"'"' # Adds a command at the end
  fi

  gran_key='"'"$gran_key"'",'

  # Node1 - Add Aura & Grandpa Keys to chainSpec
  search_skip_replace "palletAura" "$aura_key_insert_offset" "$node1_ss58_key" "${CHAIN_SPEC_FILE}"
  search_skip_replace "palletGrandpa" "$grandpa_key_insert_offset" "$gran_key" "${CHAIN_SPEC_FILE}"
}

add_peer_id_vec_to_chainspec() {
  local peer_id_vec_offset="$1"
  local ss58_key="$2"
  local key_file="$3"

  local ss588_key_offset=$(( peer_id_vec_offset + 1 ))

  local peer_id_vec
  generate_peer_id_vec "${key_file}"
  peer_id_vec=$(get_peer_id_vector "${key_file}")

  search_skip_delete_insert "supraAuthorization" "$peer_id_vec_offset" 40 "${peer_id_vec}," "${CHAIN_SPEC_FILE}"
  search_skip_delete_insert "supraAuthorization" "$ss588_key_offset" 1 "\"${ss58_key}\"" "${CHAIN_SPEC_FILE}"
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

add_key_to_node_keystore() {
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

get_peer_id_vector(){
  echo "$(tail -1 "${1%.*}"_decoded.key | cut -f2 -d : | xargs)"
}

generate_peer_id_vec() {
  local key_file=$1

  # Public key (hex) from `subkey generate --scheme sr25519` = node_key
  local node_key="$(get_node_key $key_file)"

  # Decode the Node-Key to get PeerID
  ${supra} decode-public-key ${node_key} > "${key_file%.*}"_decoded.key
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
