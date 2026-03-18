SHELL := /bin/bash
MAKEFLAGS += --warn-undefined-variables --no-builtin-rules
.DEFAULT_GOAL := build

ROOT_DIR := $(shell dirname "$(realpath $(firstword $(MAKEFILE_LIST)))")

.EXPORT_ALL_VARIABLES:
DOCKER_BUILDKIT ?= 1
ROS_DISTRO      ?= jazzy
ARCH            ?= $(shell uname -m)
DOCKER_PLATFORM ?= linux/$(ARCH)
CROSS_COMPILE   ?= false

include ../adore_cli.mk
include ${ADORE_CLI_MAKEFILE_PATH}/make_gadgets/make_gadgets.mk

.PHONY: build
build:
	@make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_base

.PHONY: clean
clean:
	@docker rmi ${ADORE_CLI_BASE_IMAGE} 2>/dev/null || true
