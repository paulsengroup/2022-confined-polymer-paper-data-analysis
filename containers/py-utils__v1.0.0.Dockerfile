# Copyright (C) 2021 Roberto Rossini <roberros@uio.no>
# Copyright (C) 2022 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT

FROM python:3.10-bullseye AS base

ARG CONTAINER_VERSION
ARG CONTAINER_TITLE

ARG COOLER_VER='0.8.11'
ARG NUMPY_VER='1.22.*'
ARG PANDAS_VER='1.3.*'

RUN if [ -z "$CONTAINER_VERSION" ]; then echo "Missing CONTAINER_VERSION --build-arg" && exit 1; fi

RUN pip install --no-cache-dir        \
        cooler=="$COOLER_VER"         \
        numpy=="$NUMPY_VER"           \
        pandas=="$PANDAS_VER"

LABEL org.opencontainers.image.authors='Roberto Rossini <roberros@uio.no>'
LABEL org.opencontainers.image.url='https://github.com/paulsengroup/2022-confiled-polymer-paper-data-analysis'
LABEL org.opencontainers.image.documentation='https://github.com/2022-confiled-polymer-paper-data-analysis'
LABEL org.opencontainers.image.source='https://github.com/paulsengroup/2022-confiled-polymer-paper-data-analysis'
LABEL org.opencontainers.image.licenses='MIT'
LABEL org.opencontainers.image.title="${CONTAINER_TITLE:-py-utils}"
LABEL org.opencontainers.image.version="${CONTAINER_VERSION:-latest}"
