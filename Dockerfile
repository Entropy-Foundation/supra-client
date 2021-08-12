# Planner-stage gives us `recipe.json` which we use in Cacher-stage
FROM rust:1.54.0-buster as planner

WORKDIR /app

RUN curl https://getsubstrate.io -sSf | bash -s \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
COPY . .
RUN cargo build --release \
    && mv target/release/node-template /usr/local/bin/supra-dht \
    && mv /usr/local/cargo/bin/sub* /usr/local/bin/ \
    && rm -rf target \
    && rm -rf /root/.cargo/registry/ \
    && rm -rf /tmp && rm -rf /usr/local/rustup && rm -rf /usr/local/cargo

FROM rust:1.54.0-buster as runtime
COPY --from=planner /usr/local/bin/supra-dht /usr/local/bin/
COPY --from=planner /usr/local/bin/sub* /usr/local/bin/

EXPOSE 30333 9933 9944
CMD ["supra-dht", \
  "--base-path", "/tmp/alice", \
  "--chain", "local", \
  "--alice", \
  "--port", "30333", \
  "--ws-port", "9944", \
  "--rpc-port", "9933", \
  "--node-key", "0000000000000000000000000000000000000000000000000000000000000001", \
  "--no-telemetry", \
  "--no-prometheus", \
  "--validator"]

