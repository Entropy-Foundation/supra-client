# Reference: https://github.com/LukeMathWalker/cargo-chef#without-the-pre-built-image

# Planner-stage:
# Generates `recipe.json` using `cargo chef`
FROM rust:1.54.0-slim-buster as planner
WORKDIR /app
RUN cargo install cargo-chef
COPY . .
RUN cargo chef prepare --recipe-path recipe.json \
    && rm -rf /tmp && rm -rf /root/.cargo/registry \
    && rm -rf /usr/local/rustup \
    && rm -rf target

# Cacher-stage:
# Caches all rust cargo dependencies
# Since dependencies do not change often, docker build does not need to download them everytime
FROM rust:1.54.0-slim-buster as cacher
WORKDIR /app
RUN apt-get update -qq \
    && apt-get install -y -qq cmake libssl-dev clang libclang-dev \
    && rustup update stable && rustup update nightly \
    && rustup target add wasm32-unknown-unknown --toolchain nightly \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
COPY --from=planner /usr/local/cargo/bin/cargo-chef /usr/local/cargo/bin/
COPY --from=planner /app/recipe.json .
RUN cargo chef cook --release --recipe-path recipe.json \
    && rm -rf /tmp && rm -rf /root/.cargo/registry \
    && rm -rf /usr/local/rustup

# Builder-Stage:
# Uses dependencies cached from the earlier stage to build the project
FROM rust:1.54.0-slim-buster as builder
WORKDIR /app
RUN apt-get update -qq \
    && apt-get install -y -qq cmake libssl-dev clang libclang-dev \
    && rustup update stable && rustup update nightly \
    && rustup target add wasm32-unknown-unknown --toolchain nightly \
    && cargo install --force --git https://github.com/paritytech/substrate subkey \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
COPY --from=cacher $CARGO_HOME $CARGO_HOME
COPY --from=cacher /app/target target
COPY --from=planner /app .
RUN cargo build --release \
    && mv target/release/supra /usr/local/bin/ \
    && mv /usr/local/cargo/bin/sub* /usr/local/bin/ \
    && rm -rf /tmp && rm -rf /root/.cargo/registry \
    && rm -rf /usr/local/rustup \
    && rm -rf $CARGO_HOME && rm -rf target

# Runtime-Stage:
# Contains the final binary and scripts
FROM debian:buster-slim as runtime
COPY --from=builder /usr/local/bin/supra /usr/local/bin/
COPY --from=builder /usr/local/bin/sub* /usr/local/bin/
WORKDIR /app
COPY --from=planner /app/scripts/create-bootnode.sh scripts/
COPY --from=builder /app/docker.script.sh start
RUN apt-get update && apt-get install -y curl procps
EXPOSE 30333 9933 9944
ENTRYPOINT ["./start"]
