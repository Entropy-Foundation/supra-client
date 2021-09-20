# Supra

The Image exposes 3 ports `30333` `9933` `9944` which would need to be mapped to host ports appropriately.

## Start bootnode

```bash
docker run --network host -it -v /home/$USER/data:/app/data -p 30333:30333 -p 9944:9944 -p 9933:9933 supraoracles/dhtimg1 --start-bootnode
```

### Important Files generated

- This will store 4 files inside the host computer's `/home/$USER/data` directory. We need the following 2 for adding more authority nodes to the network
  - `bootnode_decoded.key` - Stores peerid of the bootnode
  - `rawChainSpec.json` - Configuration file required by every node on the network

- Copy `rawChainSpec.json` manually to **all** hosts where a node is to be run

### Configure Peerid format

- This is a one time task that needs to be performed after you see blocks being finalized on bootnode
- [https://polkadot.js.org/apps/?rpc=wss%3A%2F%2Fdhtpoc.pocsupraoracles.com%3A443#/settings/developer](https://polkadot.js.org/apps/?rpc=wss%3A%2F%2Fdhtpoc.pocsupraoracles.com%3A443#/settings/developer)

- Paste the following value in the text box and click submit

    ```json
    {
      "PeerId": "(Vec<u8>)"
    }
    ```

## Add another authority node to the network

```bash
docker run --network host -it -v /home/$USER/data:/app/data -p 30333:30333 -p 9944:9944 -p 9933:9933 supraoracles/dhtimg1 \
       --bootnode /ip4/158.177.11.94/tcp/30333/p2p/<peer-id> \
       --chain-spec /app/data/rawChainSpec.json
```

  - Copy Peerid from Bootnode's `bootnode_decoded.key` file and replace it in the above command in place of `<peer-id>`

### Add node's Peerid to bootnode's keystore

- Place Bootnode's `rawChainSpec.json` file at `/home/$USER/data`
- Above command would place 1 file `auth_node.key` inside `/home/$USER/data` (i.e., the same directory where we placed `rawChainSpec.json` file)
- Last 2 lines of the file would look like the following:

  ```text
  owner: AccountId: 0xb60239b9b992599466d7d993c67912d42760f3a8257b45e756cd00dddb25db75
  node: PeerId: 0x002408011220ecf0f7fb9f5d1bffe6521bbe286c4def63e4b62884d00c0fea3999c2a44c4f3e
  ```

- On your local browser open [https://polkadot.js.org/apps/?rpc=wss%3A%2F%2Fdhtpoc.pocsupraoracles.com%3A443#/sudo](https://polkadot.js.org/apps/?rpc=wss%3A%2F%2Fdhtpoc.pocsupraoracles.com%3A443#/sudo)
    - Select `supraAuthorization` and `addWellKnownNode(node, owner)` from the 2 dropdowns
    - Paste `node: PeerId:`& `owner: AccountId:` values
    - "Submit" > "Sign and Submit"
- After the transaction gets written to the block you should see new blocks being _finalized_

