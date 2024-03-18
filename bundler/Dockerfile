FROM docker.io/library/rust:1.76.0-bullseye AS build

ARG DATABASE_URL

WORKDIR /app

RUN cargo init
COPY Cargo.toml Cargo.lock ./
RUN cargo build --release

COPY ./ ./
RUN touch src/main.rs \
    && cargo build --release

FROM gcr.io/distroless/cc-debian12@sha256:e6ae66a5a343d7112167f9117c4e630cfffcd80db44e44302759ec13ddd2d22b AS deploy

COPY --from=build /app/target/release/bundler /bundler

ENTRYPOINT ["/bundler"]
