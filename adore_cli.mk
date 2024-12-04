
# This Makefile contains useful targets that can be included in downstream projects.

ifeq ($(filter adore_cli.mk, $(notdir $(MAKEFILE_LIST))), adore_cli.mk)

.EXPORT_ALL_VARIABLES:
SHELL:=/bin/bash
ADORE_CLI_PROJECT:=adore_cli_core
ADORE_CLI_MAKEFILE_PATH:=$(shell realpath "$(shell dirname "$(lastword $(MAKEFILE_LIST))")")

ifeq ($(SUBMODULES_PATH),)
    ADORE_CLI_SUBMODULES_PATH:=${ADORE_CLI_MAKEFILE_PATH}
else
    ADORE_CLI_SUBMODULES_PATH:=$(shell realpath ${SUBMODULES_PATH})
endif

MAKE_GADGETS_PATH:=${ADORE_CLI_SUBMODULES_PATH}/make_gadgets
ifeq ($(wildcard $(MAKE_GADGETS_PATH)/*),)
    $(info INFO: To clone submodules use: 'git submodule update --init --recursive')
    $(info INFO: To specify alternative path for submodules use: SUBMODULES_PATH="<path to submodules>" make build')
    $(info INFO: Default submodule path is: ${ADORE_CLI_MAKEFILE_PATH}')
    $(error "ERROR: ${MAKE_GADGETS_PATH} does not exist. Did you clone the submodules?")
endif

BRANCH:=$(shell cd ${ADORE_CLI_MAKEFILE_PATH} && bash ${MAKE_GADGETS_PATH}/tools/branch_name.sh)
ADORE_CLI_CORE_TAG:=${BRANCH}
ADORE_CLI_CORE_IMAGE:=${ADORE_CLI_PROJECT}:${ADORE_CLI_CORE_TAG}
ADORE_CLI_PROJECT_X11_DISPLAY:=${ADORE_CLI_PROJECT}_x11_display
ADORE_CLI_CORE_X11_DISPLAY_IMAGE:=${ADORE_CLI_PROJECT_X11_DISPLAY}:${ADORE_CLI_CORE_TAG}
ADORE_CLI_IMAGE?=${ADORE_CLI_CORE_X11_DISPLAY_IMAGE}
ADORE_CLI_CONTAINER_NAME?=adore_cli_core_${BRANCH}

SOURCE_DIRECTORY?=${REPO_DIRECTORY}
ADORE_CLI_WORKING_DIRECTORY?=${REPO_DIRECTORY}
ADORE_DIRECTORY?=${REPO_DIRECTORY}
SOURCE_DIRECTORY?=${REPO_DIRECTORY}
DOCKER_COMPOSE_FILE?=${ADORE_CLI_MAKEFILE_PATH}/docker-compose.yaml


#ADORE_PATH:=$(shell (find "${ADORE_CLI_SUBMODULES_PATH}" -name adore.mk | xargs realpath | sed "s|/adore.mk||g") 2>/dev/null || true )
#ADORE_CLI_WORKING_DIRECTORY?=${ADORE_CLI_MAKEFILE_PATH}

UID := $(shell id -u)
GID := $(shell id -g)
ADORE_TAG ?= $(ADORE_CLI_TAG)

include ${MAKE_GADGETS_PATH}/make_gadgets.mk
include ${MAKE_GADGETS_PATH}/docker/docker-tools.mk

REPO_DIRECTORY:=${ADORE_CLI_MAKEFILE_PATH}
ADORE_CLI_SUBMODULES:=make_gadgets

$(shell mkdir -p "${ADORE_CLI_MAKEFILE_PATH}/.ccache")
$(shell touch "${ADORE_CLI_MAKEFILE_PATH}/.zsh_history")
$(shell touch "${ADORE_CLI_MAKEFILE_PATH}/.bash_history")
$(shell mkdir -p "${SOURCE_DIRECTORY}/.log")

.PHONY: start
start: adore_cli_setup adore_cli_start adore_cli_attach adore_cli_teardown ## OFFLINE start of adore cli 

.PHONY: run
run: adore_cli_setup adore_cli_start adore_cli_run adore_cli_teardown ## Execute a command in the ADORe CLI context `make run cmd="<command to execute>"` 

.PHONY: stop
stop: stop_adore_cli 

.PHONY: adore_cli_up
adore_cli_up: adore_cli_setup adore_cli_start adore_cli_attach adore_cli_teardown 

.PHONY: cli
cli: adore_cli ## Same as 'make adore_cli' for the lazy 

.PHONY: stop_adore_cli
stop_adore_cli: docker_host_context_check adore_cli_teardown ## Stop adore_cli docker context if it is running

.PHONY: stop_adore_cli
stop_adore_cli: docker_host_context_check adore_cli_teardown

.PHONY: adore_cli 
adore_cli: docker_host_context_check ## Start adore_cli context or attach to it if already running
	@if [[ "$$(docker inspect -f '{{.State.Running}}' '${ADORE_CLI_CONTAINER_NAME}' 2>/dev/null)" == "true"  ]]; then\
        cd "${ADORE_CLI_MAKEFILE_PATH}" && make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk adore_cli_attach;\
        exit 0;\
    else\
        cd "${ADORE_CLI_MAKEFILE_PATH}" && make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk adore_cli_up;\
        exit 0;\
    fi;

.PHONY: build_fast_adore_cli_core
build_fast_adore_cli: # Build the adore_cli core context if it does not already exist in the docker repository. If it does exist this is a noop.
	@[ ! -n "$$(docker images -q ${ADORE_CLI_CORE_IMAGE})" ] && cd "${ADORE_CLI_MAKEFILE_PATH}" && make build || true
	@[ ! -n "$$(docker images -q ${ADORE_CLI_CORE_X11_DISPLAY_IMAGE})" ] && cd "${ADORE_CLI_MAKEFILE_PATH}" && make build || true
	@[ ! -n "$$(docker images -q ${ADORE_CLI_IMAGE})" ] && cd "${ADORE_CLI_MAKEFILE_PATH}/adore_cli" && make build || true

.PHONY: build_adore_cli_core
build_adore_cli_core: clean_adore_cli ## Builds the ADORe CLI core docker context/image
	cd "${ADORE_CLI_MAKEFILE_PATH}" && make build 

.PHONY: build_adore_cli
build_adore_cli: ## Builds the ADORe CLI runtime docker context/image
	cd "${ADORE_CLI_MAKEFILE_PATH}/adore_cli" && make build 

.PHONY: clean_adore_cli 
clean_adore_cli: ## Clean adore_cli docker context 
	cd "${ADORE_CLI_MAKEFILE_PATH}" && make clean
	cd "${ADORE_CLI_MAKEFILE_PATH}/adore_cli" && make clean

.PHONY: adore_cli_setup
adore_cli_setup: build_fast_adore_cli 
	@echo "Running adore_cli setup... SOURCE_DIRECTORY: ${SOURCE_DIRECTORY}"
	@mkdir -p ${ADORE_CLI_MAKEFILE_PATH}/.log
	@mkdir -p ${ADORE_CLI_MAKEFILE_PATH}/.ccache
	@touch ${ADORE_CLI_MAKEFILE_PATH}/.bash_history
	@touch ${ADORE_CLI_MAKEFILE_PATH}/.zsh_history
	@touch ${ADORE_CLI_MAKEFILE_PATH}/.zsh_history.new

.PHONY: adore_cli_teardown
adore_cli_teardown:
	@echo "Running adore_cli teardown..."
	@cd ${ADORE_CLI_MAKEFILE_PATH} && docker compose -f ${DOCKER_COMPOSE_FILE} down || true
	@cd ${ADORE_CLI_MAKEFILE_PATH} && docker compose -f ${DOCKER_COMPOSE_FILE} rm -f || true
	@cd ${ADORE_CLI_MAKEFILE_PATH} && docker compose -f ${DOCKER_COMPOSE_FILE} stop || true

.PHONY: adore_cli_start
adore_cli_start:
	@echo "Running adore_cli start..."
	@echo "  SOURCE_DIRECTORY: ${SOURCE_DIRECTORY}"
	@echo "  ADORE_CLI_IMAGE: ${ADORE_CLI_IMAGE}"
	@echo "  ADORE_CLI_CONTAINER_NAME: ${ADORE_CLI_CONTAINER_NAME}"
	echo ${ADORE_CLI_MAKEFILE_PATH}
	cd ${ADORE_CLI_MAKEFILE_PATH} && \
    docker compose  -f ${DOCKER_COMPOSE_FILE} up \
      --force-recreate \
      --renew-anon-volumes \
      --detach

.PHONY: adore_cli_run
adore_cli_run:
	@if [ -z "$(cmd)" ]; then \
        echo "Usage: make adore_cli_run cmd='<your_command>'"; \
        exit 1; \
    fi
	@echo "Checking if container ${ADORE_CLI_CONTAINER_NAME} is running..."
	@if ! docker ps --filter "name=${ADORE_CLI_CONTAINER_NAME}" --format "{{.Names}}" | grep -q "^${ADORE_CLI_CONTAINER_NAME}$$"; then \
        echo "Container ${ADORE_CLI_CONTAINER_NAME} is not running. Starting it..."; \
        make adore_cli_start; \
    fi
	@echo "Executing command in container ${ADORE_CLI_CONTAINER_NAME}: $(cmd)"
	docker exec --workdir /tmp/adore -it ${ADORE_CLI_CONTAINER_NAME} bash -c "source setup.sh && $(cmd)"


.PHONY: adore_cli_start_headless
adore_cli_start_headless: adore_cli_setup
	export DISPLAY_MODE=headless && make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk adore_cli_start 

.PHONY: adore_cli_attach
adore_cli_attach:
	@echo "Running adore_cli attach..."
	@docker exec -it ${ADORE_CLI_CONTAINER_NAME} /bin/zsh -c "ADORE_CLI_WORKING_DIRECTORY=${ADORE_CLI_WORKING_DIRECTORY} bash /tmp/adore_cli/tools/adore_cli.sh" || true

.PHONY: branch_adore_cli
branch_adore_cli: ## Returns the current docker safe/sanitized branch for adore_cli 
	@printf "%s\n" ${ADORE_CLI_TAG}

.PHONY: image_adore_cli
image_adore_cli: ## Returns the current docker image name for adore_cli
	@echo "${ADORE_CLI_CORE_X11_DISPLAY_IMAGE}"

.PHONY: images_adore_cli
images_adore_cli: ## Returns all docker images for adore_cli
	@echo "${ADORE_CLI_CORE_IMAGE}"
	@echo "${ADORE_CLI_CORE_X11_DISPLAY_IMAGE}"
	@echo "${ADORE_CLI_IMAGE}"

.PHONY: container_name_adore_cli
container_name_adore_cli: ## Returns the container name for the adore_cli
	@echo "${ADORE_CLI_CONTAINER_NAME}"

endif
