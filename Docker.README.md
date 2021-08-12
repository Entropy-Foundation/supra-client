# Supra DHT

## Run node with _Alice_ as authority

```bash
docker run -it supra-client
```

It executes the following command:-

```bash
supra-dht \
  --base-path /tmp/alice \
  --chain local \
  --alice \
  --port 30333 \
  --ws-port 9944 \
  --rpc-port 9933 \
  --node-key 0000000000000000000000000000000000000000000000000000000000000001 \
  --no-telemetry \
  --no-prometheus \
  --validator
```

The Image exposes 3 ports `30333` `9933` `9944` which would need to be mapped to host ports appropriately.
