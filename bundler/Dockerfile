FROM docker.io/library/rust:1.81.0-bookworm AS build

ARG DATABASE_URL

WORKDIR /app

RUN cargo init
COPY Cargo.toml Cargo.lock ./
RUN cargo build --release

COPY ./ ./
RUN touch src/main.rs \
    && cargo build --release

FROM gcr.io/distroless/cc-debian12@sha256:682ff941956437ab1fc0f6fe969b18ede078839cc4f4fbc156ab546d2a9055fd AS deploy

COPY --from=build /app/target/release/bundler /bundler

ENTRYPOINT ["/bundler"]
