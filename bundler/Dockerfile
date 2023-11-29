FROM docker.io/library/rust:1.74.0-bullseye AS build

WORKDIR /app

RUN cargo init
COPY Cargo.toml Cargo.lock ./
RUN cargo build --release

COPY ./ ./
RUN touch src/main.rs \
    && cargo build --release

FROM gcr.io/distroless/cc AS deploy

COPY --from=build /app/target/release/bundler /bundler

ENTRYPOINT ["/bundler"]