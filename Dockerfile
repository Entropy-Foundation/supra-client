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
RUN apt update -y && apt install -y cmake pkg-config libssl-dev git gcc build-essential git clang libclang-dev
RUN cargo chef cook --release --recipe-path recipe.json

# We copy dependencies from the the Cacher-stage and compile our application
FROM rust:1.54.0-buster as builder
WORKDIR /app
RUN curl https://getsubstrate.io -sSf | bash -s
COPY . .
COPY --from=cacher /app/target/ target/
COPY --from=cacher /usr/local/cargo/ /usr/local/cargo/
RUN cargo build --release && mv target/release/node-template target/release/supra-dht

# This Stage creates the final image
# NO rust installation, NO dependencies installations - keeps the image as small as possible
FROM rust:1.54.0-buster as runtime
WORKDIR /app
COPY --from=builder /app/target/release/supra-dht /usr/local/bin
COPY --from=builder /usr/local/cargo/bin/sub* /usr/local/bin/

#CMD ["bash"]
ENTRYPOINT ["./usr/local/bin/supra-dht"]
EXPOSE 30333 9933 9944 9615
