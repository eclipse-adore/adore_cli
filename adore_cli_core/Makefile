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

# === MANIFEST PATHS ===
BUILD_TEMP_DIR:=.tmp
BUILD_REQUIREMENTS_DIR:=${BUILD_TEMP_DIR}/requirements
BUILD_CONTEXT_REQUIREMENTS_DIR:=.log/.adore_cli/requirements
REQUIREMENTS_MANIFEST:=${SOURCE_DIRECTORY}/.log/.adore_cli/requirements_manifest.sha256

# Target: build
.PHONY: build
build: clean gather_requirements
	@echo "Building ADORe CLI core environment..."
	@echo "Base image: ${ADORE_CLI_BASE_IMAGE}"
	@echo "Target image: ${ADORE_CLI_CORE_IMAGE}"
	@echo "Requirements manifest: ${REQUIREMENTS_MANIFEST}"
	@if [ "$(CROSS_COMPILE)" = "true" ]; then \
		docker buildx build \
			--builder=default \
			-f Dockerfile.adore_cli_core \
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
		docker build \
			-f Dockerfile.adore_cli_core \
			--network host \
			--tag ${ADORE_CLI_CORE_IMAGE} \
			--build-arg ADORE_CLI_BASE_IMAGE=${ADORE_CLI_BASE_IMAGE} \
			--build-arg ROS_DISTRO=${ROS_DISTRO} \
			--build-arg OS_CODE_NAME=${OS_CODE_NAME} \
			--build-arg BRANCH=${ADORE_CLI_BRANCH} \
			--build-arg SHORT_HASH=${ADORE_CLI_SHORT_HASH} \
			--build-arg ARCH=${ARCH} . ; \
	fi

.PHONY: gather_requirements
gather_requirements:
	@echo "=== Gathering requirements for core layer ==="
	@echo "SOURCE_DIRECTORY: '${SOURCE_DIRECTORY}'"
	rm -rf .tmp
	mkdir -p .tmp
	cd ../tools/ && bash requirements_hashing_util.sh combine "${SOURCE_DIRECTORY}"
	cd ../tools/ && bash requirements_hashing_util.sh manifest "${SOURCE_DIRECTORY}"
	cp "${SOURCE_DIRECTORY}/.log/.adore_cli/requirements" .tmp/ -r
	@echo "=== Requirements gathering complete ==="

.PHONY: clean
clean:
	@echo "Cleaning core build artifacts..."
	@rm -rf .log
	@rm -rf .tmp
	@rm -rf "${BUILD_TEMP_DIR}" 2>/dev/null || true
	@rm -rf "${BUILD_CONTEXT_REQUIREMENTS_DIR}" 2>/dev/null || true
