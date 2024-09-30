FROM docker.io/library/rust:1.81.0-bookworm AS build

ARG DATABASE_URL

WORKDIR /app

RUN cargo init
COPY Cargo.toml Cargo.lock ./
RUN cargo build --release

COPY ./ ./
RUN touch src/main.rs \
    && cargo build --release

FROM gcr.io/distroless/cc-debian12@sha256:3310655aac0d85eb9d579792387af1ff3eb7a1667823478be58020ab0e0d97a8 AS deploy

COPY --from=build /app/target/release/bundler /bundler

ENTRYPOINT ["/bundler"]
