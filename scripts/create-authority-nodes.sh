#!/usr/bin/env sh

# shellcheck disable=SC2005

# Output files
NODE1_KEY_FILE="node1.key"
NODE2_KEY_FILE="node2.key"
CHAIN_SPEC_FILE="chainSpec.json"
RAW_CHAIN_SPEC_FILE="rawChainSpec.json"
NODE_COMMON_PARAMS="--no-prometheus --no-telemetry --rpc-methods Unsafe --rpc-cors all"
NODE1_WS_PORT=9945
NODE2_WS_PORT=9946

main()  {
  # TODO:
  # Check if `local` works inside docker containers
  local supra=$1
  local pass_phrase
  local node1_key
  local node2_key
  local gran_key
  local peer_id_vec

  # Generate the default chainSpec.json
  ${supra} build-spec --disable-default-bootnode --chain local > "${CHAIN_SPEC_FILE}" 2> /dev/null && echo "Generated Chain Spec"

  # Node1 - AURA and GRANDPA keys
  subkey generate --scheme sr25519 > ${NODE1_KEY_FILE}
  pass_phrase="$(get_mnemonics ${NODE1_KEY_FILE})"
  subkey inspect --scheme ed25519 "${pass_phrase}" > "${NODE1_KEY_FILE%.*}_grandpa.key"

  # Node1 - Parse out the Aura & Grandpa Public Keys
  node1_key="$(get_public_key ${NODE1_KEY_FILE})"
  gran_key="$(get_public_key ${NODE1_KEY_FILE%.*}_grandpa.key)"

  # Node1 - Add Aura & Grandpa Keys to chainSpec
  search_skip_replace "palletAura" 2 '"'"$node1_key"'",' "${CHAIN_SPEC_FILE}"
  search_skip_replace "palletGrandpa" 3 '"'"$gran_key"'",' "${CHAIN_SPEC_FILE}"

  # Node2 - AURA and GRANDPA keys
  subkey generate --scheme sr25519 > ${NODE2_KEY_FILE}
  pass_phrase="$(get_mnemonics ${NODE2_KEY_FILE})"
  subkey inspect --scheme ed25519 "${pass_phrase}" > "${NODE2_KEY_FILE%.*}_grandpa.key"

  # Node2 - Parse out the Aura & Grandpa Public Keys
  node2_key=$(get_public_key "${NODE2_KEY_FILE}")
  gran_key=$(get_public_key "${NODE2_KEY_FILE%.*}_grandpa.key")

  # Node2 - Add Aura & Grandpa Keys to chainSpec
  search_skip_replace "palletAura" 3 '"'"$node2_key"'"' "${CHAIN_SPEC_FILE}"
  search_skip_replace "palletGrandpa" 7 '"'"$gran_key"'",' "${CHAIN_SPEC_FILE}"

  # Remove palletBalances & palletSudo sections
  sed -i '/palletBalances/,+54d' "${CHAIN_SPEC_FILE}"

  # Node1 - Add peerid vector & Public Key to chainSpec
  peer_id_vec=$(generate_decoded_peer_id_file "${NODE1_KEY_FILE}")
  search_skip_delete_insert "supraAuthorization" 3 39 "${peer_id_vec}," "${CHAIN_SPEC_FILE}"

  # Node2 - Add peerid vector & Public Key to chainSpec
  peer_id_vec=$(generate_decoded_peer_id_file "${NODE2_KEY_FILE}")
  search_skip_delete_insert "supraAuthorization" 7 39 "${peer_id_vec}," "${CHAIN_SPEC_FILE}"

  # Generate the rawChainSpec.json
  ${supra} build-spec --chain="${CHAIN_SPEC_FILE}" --raw --disable-default-bootnode > "${RAW_CHAIN_SPEC_FILE}" 2> /dev/null && echo "Generated Raw Chain Spec"

  # TODO
  ${supra} --base-path /tmp/one --chain "${RAW_CHAIN_SPEC_FILE}" --port 30333 --ws-port "$NODE1_WS_PORT" --rpc-port 9933 $NODE_COMMON_PARAMS --node-key "$(get_node_key ${NODE1_KEY_FILE})" --one &
  ${supra} --base-path /tmp/two --chain "${RAW_CHAIN_SPEC_FILE}" --port 30334 --ws-port "$NODE2_WS_PORT" --rpc-port 9934 $NODE_COMMON_PARAMS --node-key "$(get_node_key ${NODE2_KEY_FILE})" --two --bootnodes /ip4/127.0.0.1/tcp/30333/p2p/"$(get_peer_id ${NODE1_KEY_FILE})" &
  echo "Execution continues"
  #   - Add node1's AURA & GRANDPA keys to the node1's websocket endpoint using CURL
  wait
  #   - Add node2's AURA & GRANDPA keys to the node2's websocket endpoint using CURL
  wait
  #   - Restart both the nodes
}

get_peer_id(){
  local key_file=$1
  echo "$(sed -n 2p ${key_file%.*}_decoded.key | cut -f2 -d : | xargs)"
}

get_node_key() {
  local node_key="$(sed -n 3p node1.key | cut -f2 -d : | xargs)"
  echo "${node_key##0x}"
}

get_public_key() {
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
  local delete_end=$((delete_start + number_of_lines_to_delete))

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
