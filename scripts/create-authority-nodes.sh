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
  sed -i '/"palletAura"/!b;n;n;c"'"$node1_key"'",' chainSpec.json
  sed -i '/"palletGrandpa"/!b;n;n;n;c"'"$gran_key"'",' chainSpec.json

  # Node2 - AURA and GRANDPA keys
  subkey generate --scheme sr25519 > ${NODE2_KEY_FILE}
  pass_phrase="$(get_mnemonics ${NODE2_KEY_FILE})"
  subkey inspect --scheme ed25519 "${pass_phrase}" > "${NODE2_KEY_FILE%.*}_grandpa.key"

  # Node2 - Parse out the Aura & Grandpa Public Keys
  node2_key=$(get_public_key "${NODE2_KEY_FILE}")
  gran_key=$(get_public_key "${NODE2_KEY_FILE%.*}_grandpa.key")

  # Node2 - Add Aura & Grandpa Keys to chainSpec
  sed -i '/"palletAura"/!b;n;n;n;c"'"$node2_key"'"' chainSpec.json
  sed -i '/"palletGrandpa"/!b;n;n;n;n;n;n;n;c"'"$gran_key"'",' chainSpec.json

  # TODO:
  # Insert the hex array to chainSpec.json
  sed -i '/"supraAuthorization"/{!b;n;n;n;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;d}' chainSpec.json
  sed -i '/"supraAuthorization"/{!b;n;n;n;n;n;n;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;N;d}' chainSpec.json

  peer_id_vec=$(generate_decoded_peerid_file "${NODE1_KEY_FILE}")
  sed -i '/"supraAuthorization"/!b;n;n;a'"$peer_id_vec"',' chainSpec.json
  sed -i '/"supraAuthorization"/!b;n;n;n;n;c"'"$node1_key"'"' chainSpec.json

  peer_id_vec=$(generate_decoded_peerid_file "${NODE2_KEY_FILE}")
  sed -i '/"supraAuthorization"/!b;n;n;n;n;n;n;a'"$peer_id_vec"',' chainSpec.json
  sed -i '/"supraAuthorization"/!b;n;n;n;n;n;n;n;n;c"'"$node2_key"'"' chainSpec.json

  # Generate the rawChainSpec.json
  ${supra} build-spec --chain=chainSpec.json --raw --disable-default-bootnode > rawChainSpec.json 2> /dev/null && echo "Generated Raw Chain Spec"
}

get_public_key() {
  local key_file
  key_file=$1
  echo "$(tail -1 ${key_file} | awk -F ":" '{printf("%s", $2)}' | xargs)"
}

get_mnemonics() {
  local key_file
  key_file=$1
  echo "$(head -1 ${key_file} | awk -F ':' 'NF {printf ("%s", $2)}' | xargs)"
}

generate_decoded_peerid_file() {
  local key_file
  local node_key

  key_file=$1

  # Public key (hex) from `subkey generate --scheme sr25519` = node_key
  node_key="$(sed -n 3p ${key_file} | awk -F ":" '{printf("%s", $2)}' | xargs)"

  # Decode the Node-Key to get PeerID
  ${supra} decode-public-key ${node_key##0x} > "${key_file%.*}"_decoded.key

  echo "$(tail -1 "${key_file%.*}"_decoded.key | awk -F ':' 'NF {printf ("%s", $2)}' | xargs)"
}

main "$@"
