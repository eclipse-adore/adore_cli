
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

ADORE_CLI_TAG:=$(shell cd "${MAKE_GADGETS_PATH}" && make get_sanitized_branch_name REPO_DIRECTORY="${ADORE_CLI_MAKEFILE_PATH}")
ADORE_CLI_IMAGE:=${ADORE_CLI_PROJECT}:${ADORE_CLI_TAG}
ADORE_CLI_PROJECT_X11_DISPLAY:=${ADORE_CLI_PROJECT}_x11_display
ADORE_CLI_IMAGE_X11_DISPLAY:=${ADORE_CLI_PROJECT_X11_DISPLAY}:${ADORE_CLI_TAG}

SOURCE_DIRECTORY?=${REPO_DIRECTORY}

DOCKER_COMPOSE_FILE?=${ADORE_CLI_MAKEFILE_PATH}/docker-compose.yaml

##ADORE_PATH:=$(shell (find "${ADORE_CLI_SUBMODULES_PATH}" -name adore.mk | xargs realpath | sed "s|/adore.mk||g") 2>/dev/null || true )
#ADORE_CLI_WORKING_DIRECTORY?=${ADORE_CLI_MAKEFILE_PATH}

UID := $(shell id -u)
GID := $(shell id -g)


TEST_SCENARIOS?=adore_scenarios/baseline_test.launch


include ${MAKE_GADGETS_PATH}/make_gadgets.mk
include ${MAKE_GADGETS_PATH}/docker/docker-tools.mk

REPO_DIRECTORY:=${ADORE_CLI_MAKEFILE_PATH}
#CATKIN_WORKSPACE_DIRECTORY:=${REPO_DIRECTORY}/catkin_workspace

ADORE_CLI_SUBMODULES:=make_gadgets
#include ${MAKE_GADGETS_PATH}/submodule_utils.mk
#$(call include_submodules,${ADORE_CLI_SUBMODULES_PATH}, ${ADORE_CLI_SUBMODULES})

$(shell mkdir -p "${ADORE_CLI_MAKEFILE_PATH}/.ccache")
$(shell touch "${ADORE_CLI_MAKEFILE_PATH}/.zsh_history")
$(shell touch "${ADORE_CLI_MAKEFILE_PATH}/.bash_history")
$(shell mkdir -p "${SOURCE_DIRECTORY}/.log")

.PHONY: start
start: adore_cli_setup adore_cli_start adore_cli_attach adore_cli_teardown ## OFFLINE start of adore cli 

.PHONY: stop
stop: stop_adore_cli 

.PHONY: adore_cli_up
adore_cli_up: build_fast_adore_cli_core adore_cli_setup adore_cli_start adore_cli_attach adore_cli_teardown 

.PHONY: cli
cli: adore_cli ## Same as 'make adore_cli' for the lazy 

.PHONY: stop_adore_cli
stop_adore_cli: docker_host_context_check adore_cli_teardown ## Stop adore_cli docker context if it is running

.PHONY: stop_adore_cli
stop_adore_cli: docker_host_context_check adore_cli_teardown

.PHONY: adore_cli 
adore_cli: docker_host_context_check build_fast_adore_cli_core ## Start adore_cli context or attach to it if already running
	@if [[ "$$(docker inspect -f '{{.State.Running}}' '${ADORE_CLI_PROJECT}' 2>/dev/null)" == "true"  ]]; then\
        cd "${ADORE_CLI_MAKEFILE_PATH}" && make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk adore_cli_attach;\
        exit 0;\
    else\
        cd "${ADORE_CLI_MAKEFILE_PATH}" && make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk adore_cli_up;\
        exit 0;\
    fi;

.PHONY: build_fast_adore_cli_core
build_fast_adore_cli_core: # build the adore_cli core context if it does not already exist in the docker repository. If it does exist this is a noop.
	@if [ -n "$$(docker images -q ${ADORE_CLI_PROJECT}:${ADORE_CLI_TAG})" ]; then \
        echo "Docker image: ${ADORE_CLI_PROJECT}:${ADORE_CLI_TAG} already build, skipping build."; \
    else \
        cd "${ADORE_CLI_MAKEFILE_PATH}" && make build_adore_cli_core;\
    fi


.PHONY: build_adore_cli_core
build_adore_cli_core: clean_adore_cli ## Builds the ADORe CLI core docker context/image
	cd "${ADORE_CLI_MAKEFILE_PATH}" && make build 

.PHONY: clean_adore_cli 
clean_adore_cli: ## Clean adore_cli docker context 
	cd "${ADORE_CLI_MAKEFILE_PATH}" && make clean

.PHONY: adore_cli_setup
adore_cli_setup: 
	@echo "Running adore_cli setup... SOURCE_DIRECTORY: ${SOURCE_DIRECTORY}"
#	make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk build_fast_adore_cli_core
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
	@echo "Running adore_cli start... SOURCE_DIRECTORY: ${SOURCE_DIRECTORY}"
	cd ${ADORE_CLI_MAKEFILE_PATH} && \
    docker compose  -f ${DOCKER_COMPOSE_FILE} up \
      --force-recreate \
      --renew-anon-volumes \
      --detach;



.PHONY: adore_cli_start_headless
adore_cli_start_headless: adore_cli_setup
	export DISPLAY_MODE=headless && make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk adore_cli_start 

.PHONY: adore_cli_attach
adore_cli_attach:
	@echo "Running adore_cli attach..."
	docker exec -it ${ADORE_CLI_PROJECT} /bin/zsh -c "ADORE_CLI_WORKING_DIRECTORY=${ADORE_CLI_WORKING_DIRECTORY} bash /tmp/adore_cli/tools/adore_cli.sh" || true

.PHONY: branch_adore_cli
branch_adore_cli: ## Returns the current docker safe/sanitized branch for adore_cli 
	@printf "%s\n" ${ADORE_CLI_TAG}

.PHONY: image_adore_cli
image_adore_cli: ## Returns the current docker image name for adore_cli
	@echo "${ADORE_CLI_IMAGE_X11_DISPLAY}"

.PHONY: images_adore_cli
images_adore_cli: ## Returns all docker images for adore_cli
	@echo "${ADORE_CLI_IMAGE}"
	@echo "${ADORE_CLI_IMAGE_X11_DISPLAY}"

.PHONY: take_ownership_adore_cli
take_ownership_adore_cli: ## Takes ownership of the ADORe CLI docker image. The ADORe cli docker image is owned by the user that created it. This target takes ownership of it.
	cd ${ADORE_CLI_MAKEFILE_PATH} && make own

endif
