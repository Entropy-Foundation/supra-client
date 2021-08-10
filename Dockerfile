FROM rust@sha256:c0a933dca3319a5256b16197d9709fed7fc0055995d40d6ac822e9f613480361

WORKDIR /app

RUN curl https://getsubstrate.io -sSf | bash -s
COPY . .
RUN cargo build --release
