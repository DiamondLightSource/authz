FROM docker.io/library/rust:1.78.0-bookworm AS build

ARG DATABASE_URL

WORKDIR /app

RUN cargo init
COPY Cargo.toml Cargo.lock ./
RUN cargo build --release

COPY ./ ./
RUN touch src/main.rs \
    && cargo build --release

FROM gcr.io/distroless/cc-debian12@sha256:e1065a1d58800a7294f74e67c32ec4146d09d6cbe471c1fa7ed456b2d2bf06e0 AS deploy

COPY --from=build /app/target/release/bundler /bundler

ENTRYPOINT ["/bundler"]
