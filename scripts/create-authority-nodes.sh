#!/usr/bin/env sh

# Hardcoded well-known accounts' keys
ALICE_AURA="5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY"
BOB_AURA="5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty"
ALICE_GRANDPA="5FA9nQDVg267DEd8m1ZypXLBnvN7SFxYwV7ndqSYGiN9TTpu"
BOB_GRANDPA="5GoNkf6WdbxCFnPdAnYYQyCjAKPJgLNxXwPjwTh6DGg6gN3E"

# Output files
NODE1_AURA_FILE="node1.key"
NODE2_AURA_FILE="node2.key"

main()  {
  # TODO:
  # Check if `local` works inside our docker containers
  local supra
  supra=$1

  # Generate the default chainSpec.json
  ${supra} build-spec --disable-default-bootnode --chain local > chainSpec.json

  # Generate Public-Private and AURA keys
  subkey generate --scheme sr25519 > ${NODE1_AURA_FILE}
  insert_node_keys ${NODE1_AURA_FILE} "ALICE"
  subkey generate --scheme sr25519 > ${NODE2_AURA_FILE}
  insert_node_keys ${NODE2_AURA_FILE} "BOB"

  # TODO:
  # Figure out how to get the peerid for both these nodes
  # Get the hex array for both of these nodes - `supra decode-peed-id <peer-id>`
  # Insert the hex array to chainSpec.json

  # Generate rawChainSpec.json - `node-template build-spec --chain=chainSpec.json --raw --disable-default-bootnode > rawChainSpec.json`
  ${supra} build-spec --chain=chainSpec.json --raw --disable-default-bootnode > rawChainSpec.json
}

insert_node_keys() {
  local key_file
  local grandpa_key_file
  local pass_phrase
  local aura_key
  local grandpa_key
  local aura_search_key
  local grandpa_search_key

  key_file="$1"
  replacing="$2"

  if [ "$replacing" = "ALICE" ]; then
    aura_search_key=${ALICE_AURA}
    grandpa_search_key=${ALICE_GRANDPA}
  else
    aura_search_key=${BOB_AURA}
    grandpa_search_key=${BOB_GRANDPA}
  fi

  # Insert AURA key to chainSpec.json
  aura_key="$(tail -1 ${key_file} | awk -F ":" '{printf("%s", $2)}' | xargs)"
  sed -i "s/${aura_search_key}/${aura_key}/g" chainSpec.json

  # Parse passphrase from the key_file
  pass_phrase="$(head -1 ${key_file} | awk -F ':' 'NF {printf ("%s", $2)}' | xargs)"

  # Generate GRANDPA key
  grandpa_key_file="${key_file%.*}_grandpa.key"
  subkey inspect --scheme ed25519 "${pass_phrase}" > "${grandpa_key_file}"

  # Insert GRANPA Key to chainSpec.json
  grandpa_key="$(tail -1 ${grandpa_key_file} | awk -F ":" '{printf("%s", $2)}' | xargs)"
  sed -i "s/${grandpa_search_key}/${grandpa_key}/g" chainSpec.json
}

main "$@"
