# === CORE ENVIRONMENT MAKEFILE ===
# Builds the ADORe CLI core environment layer with all discovered requirements

SHELL := /bin/bash
MAKEFLAGS += --warn-undefined-variables --no-builtin-rules

.DEFAULT_GOAL := all

ROOT_DIR := $(shell dirname "$(realpath $(firstword $(MAKEFILE_LIST)))")

.EXPORT_ALL_VARIABLES:
DOCKER_BUILDKIT?= 1
DOCKER_CONFIG?=
ROS_DISTRO?=jazzy

# Use SOURCE_DIRECTORY if provided, otherwise default to parent of adore_cli
SOURCE_DIRECTORY?=$(shell realpath "${ROOT_DIR}/../..")
VENDOR_PATH?=${SOURCE_DIRECTORY}/vendor

USER:=$(shell whoami)
UID:=$(shell id -u)
GID:=$(shell id -g)
DOCKER_GID:=$(shell getent group docker | cut -d: -f3)

CROSS_COMPILE?=false
ARCH?=amd64
DOCKER_PLATFORM?=linux/$(ARCH)

include ../adore_cli.mk
include ${ADORE_CLI_MAKEFILE_PATH}/make_gadgets/make_gadgets.mk

# Target: build
.PHONY: build
build: clean gather
	@echo "Building ADORe CLI core environment..."
	@echo "Base image: ${ADORE_CLI_BASE_IMAGE}"
	@echo "Target image: ${ADORE_CLI_CORE_IMAGE}"
	@if [ "$(CROSS_COMPILE)" = "true" ]; then \
		docker buildx build \
			--builder=default \
			--platform $(DOCKER_PLATFORM) \
			--tag ${ADORE_CLI_CORE_IMAGE} \
			--build-arg ADORE_CLI_BASE_IMAGE=${ADORE_CLI_BASE_IMAGE} \
			--build-arg ROS_DISTRO=${ROS_DISTRO} \
			--build-arg OS_CODE_NAME=${OS_CODE_NAME} \
			--build-arg BRANCH=${ADORE_CLI_BRANCH} \
			--build-arg SHORT_HASH=${ADORE_CLI_SHORT_HASH} \
			--build-arg ARCH=${ARCH} \
			--load . ; \
	else \
		docker build --network host \
			--tag ${ADORE_CLI_CORE_IMAGE} \
			--build-arg ADORE_CLI_BASE_IMAGE=${ADORE_CLI_BASE_IMAGE} \
			--build-arg ROS_DISTRO=${ROS_DISTRO} \
			--build-arg OS_CODE_NAME=${OS_CODE_NAME} \
			--build-arg BRANCH=${ADORE_CLI_BRANCH} \
			--build-arg SHORT_HASH=${ADORE_CLI_SHORT_HASH} \
			--build-arg ARCH=${ARCH} . ; \
	fi

# Target: gather_requirements
.PHONY: gather_requirements
gather_requirements:
	@echo "=== Gathering requirements ==="
	@echo "SOURCE_DIRECTORY: '${SOURCE_DIRECTORY}'"
	@echo "VENDOR_PATH: '${VENDOR_PATH}'"
	@echo "PWD: $(shell pwd)"
	@# Clean up any temp directories
	@rm -rf "${SOURCE_DIRECTORY}/.log/.adore_cli/temp" 2>/dev/null || true
	@# Export SOURCE_DIRECTORY for the script
	@SOURCE_DIRECTORY='${SOURCE_DIRECTORY}' bash gather_requirements_files.sh
	@echo "=== Gather complete ==="
