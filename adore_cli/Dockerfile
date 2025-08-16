# === BUILD ARGUMENTS ===
# These must be declared before FROM to be available in base image selection
ARG ADORE_CLI_USER_IMAGE

# === DEVELOPMENT ENVIRONMENT DOCKERFILE ===
# Extends the user-customized core image with development tools and user packages
# Uses the user-customized core image as base
FROM ${ADORE_CLI_USER_IMAGE} AS adore_cli

# Re-declare ARGs for use within this stage
ARG USER
ARG UID
ARG GID
ARG ROS_DISTRO
ARG BRANCH
ARG SHORT_HASH
ARG ARCH

ENV ROS_DISTRO=${ROS_DISTRO}

# === METADATA LABELS ===
LABEL org.adore.version="${BRANCH}_${SHORT_HASH}_${ARCH}_${USER}"
LABEL org.adore.image-type="development-runtime"
LABEL org.adore.user="${USER}"
LABEL org.adore.uid="${UID}"
LABEL org.adore.gid="${GID}"

# === REQUIREMENTS GATHERING ===
# Copy all gathered requirements from the build context
COPY .tmp/requirements /tmp/.tmp/requirements
COPY .tmp/requirements/. /tmp/
WORKDIR /tmp/.tmp/requirements

# === REPOSITORY AND PPA SETUP ===
ENV DEBIAN_FRONTEND=noninteractive
USER root

# Add PPAs first (if any)
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    apt-get update && apt-get install -y software-properties-common && \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && \
    find . -maxdepth 1 -type f -name '*.ppa' -exec cat {} + 2>/dev/null | \
    sed '/^#/d' | \
    sed '/^$/d' | \
    envsubst | \
    xargs -r -I {} add-apt-repository -y {} || true

# === PYTHON PACKAGES ===
# Install Python packages discovered from requirements files
RUN --mount=type=cache,target=/root/.cache/pip \
    find . -maxdepth 1 -type f -name '*.pip3' -exec cat {} + 2>/dev/null | \
    xargs -r python3 -m pip install --ignore-installed --break-system-packages || true

# === DEBIAN PACKAGES ===
# Install .deb packages if present
COPY .tmp/packages/. /tmp/
WORKDIR /tmp
RUN find . -maxdepth 1 -type f -name "*.deb" -print0 | \
    xargs -0 sudo dpkg -i --force-all 2>/dev/null || true

# === SYSTEM PACKAGES ===
# Install system packages discovered from requirements files
ENV DEBIAN_FRONTEND=noninteractive
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && \
    find . -maxdepth 1 -type f -name '*.system' -exec cat {} + 2>/dev/null | \
    sed '/^#/d' | \
    sed '/^$/d' | \
    envsubst | \
    xargs -r apt-get install --no-install-recommends -y || true

# === ADORE CLI SPECIFIC PACKAGES ===
# Install packages specific to ADORe CLI runtime
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

# === FINAL USER SETUP ===
USER ${USER}
WORKDIR /tmp/adore

# === DEVELOPMENT ENVIRONMENT READY ===
# The image now contains the complete development environment
# with user-specific customizations and all discovered requirements
