FROM rust:1.54.0-buster as planner
WORKDIR /app
RUN cargo install cargo-chef
COPY . .
RUN cargo chef prepare --recipe-path recipe.json \
    && rm -rf /tmp && rm -rf /root/.cargo/registry \
    && rm -rf /usr/local/rustup \
    && rm -rf target

FROM rust:1.54.0-buster as cacher
WORKDIR /app
RUN curl https://getsubstrate.io -sSf | bash -s \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
COPY --from=planner /usr/local/cargo/bin/cargo-chef /usr/local/cargo/bin/
COPY --from=planner /app/recipe.json .
RUN cargo chef cook --release --recipe-path recipe.json \
    && rm -rf /tmp && rm -rf /root/.cargo/registry \
    && rm -rf /usr/local/rustup

FROM rust:1.54.0-buster as builder
WORKDIR /app
RUN curl https://getsubstrate.io -sSf | bash -s \
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

FROM debian:buster-slim as runtime
COPY --from=builder /usr/local/bin/supra /usr/local/bin/
COPY --from=builder /usr/local/bin/sub* /usr/local/bin/
WORKDIR /app
COPY --from=builder /app/docker.script.sh ./supra
EXPOSE 30333 9933 9944
ENTRYPOINT ["./supra"]
