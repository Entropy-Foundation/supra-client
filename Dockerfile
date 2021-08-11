# Planner-stage gives us `recipe.json` which we use in Cacher-stage
FROM rust:1.54.0-buster as planner
WORKDIR /app
RUN cargo install cargo-chef
COPY . .
RUN cargo chef prepare --recipe-path recipe.json


# Cacher-stage helps download all dependencies
# Since dependencies do not change often, docker build does not need to download them everytime
FROM rust:1.54.0-buster as cacher
WORKDIR /app
COPY --from=planner /usr/local/cargo/bin/cargo-chef /usr/local/cargo/bin
COPY --from=planner /app/recipe.json recipe.json
RUN apt update -y && apt install -y musl-tools cmake pkg-config libssl-dev git gcc build-essential git clang libclang-dev
RUN rustup target add x86_64-unknown-linux-musl
RUN cargo chef cook --release --recipe-path recipe.json

# We copy dependencies from the the Cacher-stage and compile our application
FROM rust:1.54.0-buster as builder
WORKDIR /app
RUN apt update \
    && apt install -y cmake pkg-config libssl-dev git gcc build-essential git clang lld libclang-dev musl-tools \
    && ln -s /bin/g++ /bin/musl-g++
RUN rustup update nightly \
    && rustup target add wasm32-unknown-unknown --toolchain nightly \
    && rustup target add x86_64-unknown-linux-musl \
    && rustup target add x86_64-unknown-linux-musl --toolchain nightly
RUN cargo install --target=x86_64-unknown-linux-musl subkey
COPY --from=cacher /app/target/ target/
COPY --from=cacher /usr/local/cargo/ /usr/local/cargo/
COPY . .
RUN rustup component add rustfmt
RUN cargo build --release --target=x86_64-unknown-linux-musl \
    && mv target/release/node-template target/release/supra-dht

# This Stage creates the final image
# NO rust installation, NO dependencies installations - keeps the image as small as possible
#FROM debian:buster-20210721 as runtime
#WORKDIR /app
#COPY --from=builder /app/target/release/supra-dht /usr/local/bin
#COPY --from=builder /usr/local/cargo/bin/sub* /usr/local/bin/
#
##CMD ["bash"]
##ENTRYPOINT ["./usr/local/bin/supra-dht"]
#EXPOSE 30333 9933 9944 9615

FROM alpine:3.14.1
RUN addgroup -g 1000 supra
RUN adduser -D -s /bin/sh -u 1000 -G supra supra
WORKDIR /home/supra/bin/
COPY --from=cargo-build /app/target/x86_64-unknown-linux-musl/release/supra-dht .
COPY --from=builder /usr/local/cargo/bin/sub* /usr/local/bin/
RUN chown supra:supra supra-dht
USER supra

EXPOSE 30333 9933 9944 9615
CMD ["./supra-dht"]

