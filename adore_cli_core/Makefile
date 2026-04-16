SHELL := /bin/bash
MAKEFLAGS += --warn-undefined-variables --no-builtin-rules
.DEFAULT_GOAL := build

ROOT_DIR := $(shell dirname "$(realpath $(firstword $(MAKEFILE_LIST)))")

.EXPORT_ALL_VARIABLES:
DOCKER_BUILDKIT ?= 1
ROS_DISTRO      ?= jazzy
APT_MIRROR      ?= http://archive.ubuntu.com/ubuntu
APT_MIRROR_PORTS ?= http://ports.ubuntu.com/ubuntu-ports
ARCH            ?= $(shell uname -m)
DOCKER_PLATFORM ?= linux/$(ARCH)
CROSS_COMPILE   ?= false

include ../adore_cli.mk
include ${ADORE_CLI_MAKEFILE_PATH}/make_gadgets/make_gadgets.mk

PATCHES          := $(sort $(wildcard $(ROOT_DIR)/patches/*.patch))
DOCKERFILE       := $(ROOT_DIR)/Dockerfile.adore_cli_core
BUILD_DOCKERFILE := $(if $(PATCHES),$(DOCKERFILE).patched,$(DOCKERFILE))

.PHONY: patch
patch:
ifneq ($(PATCHES),)
	@cp $(DOCKERFILE) $(DOCKERFILE).patched
	@for p in $(PATCHES); do \
	    echo "Applying patch: $$(basename $$p)"; \
	    patch -p1 $(DOCKERFILE).patched < "$$p" || exit 1; \
	done
endif

.PHONY: build
build: patch check_cross_compile_deps
	@if [ "$(CROSS_COMPILE)" = "true" ]; then \
	    docker buildx build --builder=default --platform=$(DOCKER_PLATFORM) --load \
	        --build-arg ROS_DISTRO=$(ROS_DISTRO) \
	        --build-arg OS_CODE_NAME=$(OS_CODE_NAME) \
	        --build-arg ARCH=$(ARCH) \
	        --build-arg SHORT_HASH=$(ADORE_CLI_SHORT_HASH) \
	        --build-arg APT_MIRROR=$(APT_MIRROR) \
	        --build-arg APT_MIRROR_PORTS=$(APT_MIRROR_PORTS) \
	        -t $(ADORE_CLI_CORE_IMAGE) \
	        -f $(BUILD_DOCKERFILE) \
	        $(ROOT_DIR); \
	else \
	    docker build --network host \
	        --build-arg ROS_DISTRO=$(ROS_DISTRO) \
	        --build-arg OS_CODE_NAME=$(OS_CODE_NAME) \
	        --build-arg ARCH=$(ARCH) \
	        --build-arg SHORT_HASH=$(ADORE_CLI_SHORT_HASH) \
	        --build-arg APT_MIRROR=$(APT_MIRROR) \
	        --build-arg APT_MIRROR_PORTS=$(APT_MIRROR_PORTS) \
	        -t $(ADORE_CLI_CORE_IMAGE) \
	        -f $(BUILD_DOCKERFILE) \
	        $(ROOT_DIR); \
	fi

.PHONY: clean
clean:
	@docker rmi $(ADORE_CLI_CORE_IMAGE) 2>/dev/null || true
	@rm -f $(DOCKERFILE).patched
