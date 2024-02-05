FROM docker.io/library/rust:1.75.0-bullseye AS build

ARG DATABASE_URL

WORKDIR /app

RUN cargo init
COPY Cargo.toml Cargo.lock ./
RUN cargo build --release

COPY ./ ./
RUN touch src/main.rs \
    && cargo build --release

FROM gcr.io/distroless/cc-debian12@sha256:4049e8f163161818a52e028c3c110ee0ba9d71a14760ad2838aabba52b3f9782 AS deploy

COPY --from=build /app/target/release/bundler /bundler

ENTRYPOINT ["/bundler"]
