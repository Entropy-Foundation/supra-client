FROM debian:stretch-slim

# show backtraces
ENV RUST_BACKTRACE 1

# install tools and dependencies
RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && \
	DEBIAN_FRONTEND=noninteractive apt-get install -y \
		libssl1.1 \
		ca-certificates \
		curl && \
# apt cleanup
	apt-get autoremove -y && \
	apt-get clean && \
	find /var/lib/apt/lists/ -type f -not -name lock -delete; \
# add user
	useradd -m -u 1000 -U -s /bin/sh -d /supra supra

# add supra binary to docker image
COPY ./target/release/supra /usr/local/bin

USER supra

# check if executable works in this container
RUN /usr/local/bin/supra -h

EXPOSE 30333 9933 9944
VOLUME ["/supra"]

ENTRYPOINT ["/usr/local/bin/supra"]