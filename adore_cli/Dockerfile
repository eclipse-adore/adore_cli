
ARG USER
ARG UID
ARG GID
ARG ROS_DISTRO
ARG ADORE_CLI_CORE_IMAGE


FROM ${ADORE_CLI_CORE_IMAGE} AS adore_cli

ARG USER
ARG UID
ARG GID
ARG ROS_DISTRO
ENV ROS_DISTRO=${ROS_DISTRO}



COPY .tmp/requirements /tmp/.tmp/requirements
COPY .tmp/requirements/. /tmp/
WORKDIR /tmp/.tmp/requirements

ENV DEBIAN_FRONTEND=noninteractive
USER root
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    apt-get update && apt-get install -y software-properties-common && \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && \
    find . -maxdepth 1 -type f -name '*.ppa' -exec cat {} + 2>/dev/null | \
    sed '/^#/d' | \
    sed '/^$/d' | \
    envsubst | \
    xargs -r -I {} add-apt-repository -y {}


RUN --mount=type=cache,target=/root/.cache/pip \
    find . -maxdepth 1 -type f -name '*.pip3' -exec cat {} + 2>/dev/null | \
    xargs -r python3 -m pip install --ignore-installed --break-system-packages

COPY .tmp/packages/. /tmp/
WORKDIR /tmp
RUN find . -maxdepth 1 -type f -name "*.deb" -print0 | xargs -0 sudo dpkg -i --force-all || true

WORKDIR /tmp
ENV DEBIAN_FRONTEND=noninteractive
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && \
    find . -maxdepth 1 -type f -name '*.system' -exec cat {} + 2>/dev/null | \
    sed '/^#/d' | \
    sed '/^$/d' | \
    envsubst | \
    xargs -r apt-get install --no-install-recommends -y

USER ${USER}
COPY requirements.adore_cli.system /tmp
USER root
WORKDIR /tmp
ENV DEBIAN_FRONTEND=noninteractive
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && \
    apt-get install --no-install-recommends -y $(sed '/^#/d' *.system | sed '/^$/d' | envsubst)

RUN groupadd -r tracing || true
RUN usermod -aG tracing ${USER}

USER ${USER}
