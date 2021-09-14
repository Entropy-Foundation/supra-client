#!/usr/bin/env sh

# Output files
NODE1_KEY_FILE="node1.key"
NODE2_KEY_FILE="node2.key"

main()  {
  # TODO:
  # Check if `local` works inside our docker containers
  local supra
  local pass_phrase
  local node1_key
  local node2_key
  local gran_key
  local peer_id_vec

  supra=$1

  # Generate the default chainSpec.json
  ${supra} build-spec --disable-default-bootnode --chain local > chainSpec.json 2> /dev/null && echo "Generated Chain Spec"

  # Node1 - AURA and GRANDPA keys
  subkey generate --scheme sr25519 > ${NODE1_KEY_FILE}
  pass_phrase="$(get_mnemonics ${NODE1_KEY_FILE})"
  subkey inspect --scheme ed25519 "${pass_phrase}" > "${NODE1_KEY_FILE%.*}_grandpa.key"

  # Node1 - Parse out the Aura & Grandpa Public Keys
  node1_key="$(get_public_key ${NODE1_KEY_FILE})"
  gran_key="$(get_public_key ${NODE1_KEY_FILE%.*}_grandpa.key)"

  # Node1 - Add Aura & Grandpa Keys to chainSpec
  search_skip_replace "palletAura" 2 '"'"$node1_key"'",' "chainSpec.json"
  search_skip_replace "palletGrandpa" 3 '"'"$gran_key"'",' "chainSpec.json"

  # Node2 - AURA and GRANDPA keys
  subkey generate --scheme sr25519 > ${NODE2_KEY_FILE}
  pass_phrase="$(get_mnemonics ${NODE2_KEY_FILE})"
  subkey inspect --scheme ed25519 "${pass_phrase}" > "${NODE2_KEY_FILE%.*}_grandpa.key"

  # Node2 - Parse out the Aura & Grandpa Public Keys
  node2_key=$(get_public_key "${NODE2_KEY_FILE}")
  gran_key=$(get_public_key "${NODE2_KEY_FILE%.*}_grandpa.key")

  # Node2 - Add Aura & Grandpa Keys to chainSpec
  search_skip_replace "palletAura" 3 '"'"$node2_key"'"' "chainSpec.json"
  search_skip_replace "palletGrandpa" 7 '"'"$gran_key"'",' "chainSpec.json"

  # Remove palletBalances & palletSudo sections
  sed -i '/palletBalances/,+54d' chainSpec.json

  # Node1 - Add peerid vector & Public Key to chainSpec
  peer_id_vec=$(generate_decoded_peerid_file "${NODE1_KEY_FILE}")
  search_skip_delete_insert "supraAuthorization" 3 39 "${peer_id_vec}," "chainSpec.json"

  # Node2 - Add peerid vector & Public Key to chainSpec
  peer_id_vec=$(generate_decoded_peerid_file "${NODE2_KEY_FILE}")
  search_skip_delete_insert "supraAuthorization" 7 39 "${peer_id_vec}," "chainSpec.json"

  # Generate the rawChainSpec.json
  ${supra} build-spec --chain=chainSpec.json --raw --disable-default-bootnode > rawChainSpec.json 2> /dev/null && echo "Generated Raw Chain Spec"

  # TODO
  #   - Start the bootnode (node1)
  #   - Start the 2nd node (node2) using the configurations of the bootnode
  #   - Add node1's keys to the node1's websocket endpoint using CURL
  #   - Add node2's keys to the node2's websocket endpoint using CURL
  #   - Restart both the nodes
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

get_public_key() {
  echo "$(tail -1 $1 | awk -F ":" '{printf("%s", $2)}' | xargs)"
}

get_mnemonics() {
  echo "$(head -1 $1 | awk -F ':' 'NF {printf ("%s", $2)}' | xargs)"
}

generate_decoded_peerid_file() {
  local key_file=$1

  # Public key (hex) from `subkey generate --scheme sr25519` = node_key
  local node_key="$(sed -n 3p ${key_file} | awk -F ":" '{printf("%s", $2)}' | xargs)"

  # Decode the Node-Key to get PeerID
  ${supra} decode-public-key ${node_key##0x} > "${key_file%.*}"_decoded.key

  echo "$(tail -1 "${key_file%.*}"_decoded.key | awk -F ':' 'NF {printf ("%s", $2)}' | xargs)"
}

main "$@"
