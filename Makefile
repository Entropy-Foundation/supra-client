#!/bin/bash

release:
	cargo build --release

build:
	docker build . -t supra

dev:
	docker run supra --dev --tmp