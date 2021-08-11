FROM debian:buster-slim

WORKDIR /usr/scr/supra

RUN apt-get update && \
    apt-get install -y git clang curl libssl-dev llvm libudev-dev

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

ENV PATH="/root/.cargo/bin:${PATH}"
RUN	rustup target add wasm32-unknown-unknown && \
    rustup default nightly-2021-07-05

COPY . .

RUN cargo build --release


# FROM rust:latest

# WORKDIR /usr/scr/supra

# COPY . .

# RUN apt-get update && \
#     apt-get install -y git clang curl libssl-dev llvm libudev-dev 

# RUN rustup default nightly
# RUN rustup target add wasm32-unknown-unknown --toolchain nightly

# RUN cargo build --release



# FROM ubuntu

# WORKDIR /usr/scr/supra

# COPY . .

# RUN apt-get update && \
#     apt-get install -y git clang curl libssl-dev llvm libudev-dev 

# RUN curl https://sh.rustup.rs -sSf | sh -s -- -y

# ENV PATH="/root/.cargo/bin:${PATH}"
# RUN	rustup toolchain install nightly && \
# 	rustup target add wasm32-unknown-unknown --toolchain nightly && \
#     rustup default nightly

# RUN cargo build --release
