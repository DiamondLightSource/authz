FROM docker.io/library/rust:1.95.0-bookworm AS build

ARG DATABASE_URL

RUN cargo install cargo-auditable

WORKDIR /app

RUN cargo init
COPY Cargo.toml Cargo.lock ./
RUN cargo build --release

COPY ./ ./
RUN touch src/main.rs \
    && cargo auditable build --release

FROM gcr.io/distroless/cc-debian12@sha256:aa0b7af67fa8211751ea6e00baa8373ba56cc1417ffc986ec9619bd0e1556b56 AS deploy

COPY --from=build /app/target/release/bundler /bundler

ENTRYPOINT ["/bundler"]
