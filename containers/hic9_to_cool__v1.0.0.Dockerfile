# Copyright (C) 2022 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT

FROM ubuntu:20.04 AS base


ARG CONTAINER_VERSION
ARG CONTAINER_TITLE

ARG STRAW_GIT='https://github.com/aidenlab/straw.git'
ARG STRAW_GIT_HASH='098a79b49d7ceff5441772f2d8a7847512bb88d5'
ARG COOLER_VERSION="0.8.11"

ARG PIP_NO_CACHE_DIR=0
ARG DEBIAN_FRONTEND=noninteractive

RUN if [ -z "$CONTAINER_VERSION" ]; then echo "Missing CONTAINER_VERSION --build-arg" && exit 1; fi

RUN apt-get update \
&&  apt-get install -y -q cmake \
                          gawk \
                          gcc \
                          g++ \
                          git \
                          libcurl4 \
                          libcurl4-gnutls-dev \
                          python3 \
                          python3-dev \
                          python3-pip \
                          zstd \
&&  git clone "$STRAW_GIT" /tmp/straw \
&&  cd /tmp/straw/ && mkdir build \
&&  cmake -S C++ -B build/ -DCMAKE_BUILD_TYPE=Release \
&&  cmake --build build/ -j $(nproc) \
&&  install -Dm755 build/straw /usr/local/bin/straw \
&&  install -Dm644 LICENSE /usr/share/doc/straw/LICENSE \
&&  pip install "cooler==$COOLER_VERSION" \
&&  apt-get remove -y -q cmake \
                         gcc \
                         g++ \
                         git \
                         libcurl4-gnutls-dev \
                         python3-pip \
&&  rm -rf /var/lib/apt/lists/* /tmp/straw

COPY scripts/hic9_to_cool.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/hic9_to_cool.sh

RUN straw || true
RUN hic9_to_cool.sh || true
RUN cooler --help

ENV SHELL=/usr/bin/bash

WORKDIR /data

LABEL org.opencontainers.image.authors='Roberto Rossini <roberros@uio.no>'
LABEL org.opencontainers.image.url='https://github.com/paulsengroup/2022-confined-polymer-paper-data-analysis'
LABEL org.opencontainers.image.documentation='https://github.com/2022-confined-polymer-paper-data-analysis'
LABEL org.opencontainers.image.source='https://github.com/paulsengroup/2022-confined-polymer-paper-data-analysis'
LABEL org.opencontainers.image.licenses='MIT'
LABEL org.opencontainers.image.title="${CONTAINER_TITLE:-hic9_to_cool}"
LABEL org.opencontainers.image.version="${CONTAINER_VERSION:-latest}"