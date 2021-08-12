# Supra DHT

## Run node with _Alice_ as authority

```bash
docker run -it -p 30333:30333 -p 9944:9944 -p 9933:9933 supra-client:0.0.1
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
