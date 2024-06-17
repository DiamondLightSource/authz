FROM docker.io/library/rust:1.79.0-bookworm

RUN rustup component add rustfmt clippy 

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3-pip

COPY docs/requirements.txt /tmp/docs-requirements.txt

RUN pip install -r /tmp/docs-requirements.txt --break-system-packages
