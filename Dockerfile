FROM rust:1.54.0-buster as planner
WORKDIR /app
RUN curl https://getsubstrate.io -sSf | bash -s \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
COPY . .
RUN cargo build --release \
    && mv target/release/supra /usr/local/bin/ \
    && mv /usr/local/cargo/bin/sub* /usr/local/bin/ \
    && rm -rf target \
    && rm -rf /root/.cargo/registry/ \
    && rm -rf /tmp && rm -rf /usr/local/rustup && rm -rf /usr/local/cargo

FROM debian:buster-slim as runtime
WORKDIR /app
COPY --from=planner /usr/local/bin/supra /usr/local/bin/
COPY --from=planner /usr/local/bin/sub* /usr/local/bin/
COPY --from=planner docker.script.sh ./supra
EXPOSE 30333 9933 9944
ENTRYPOINT ["./supra"]
