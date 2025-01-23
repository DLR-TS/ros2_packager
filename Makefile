SHELL:=/bin/bash

.DEFAULT_GOAL := all

ROOT_DIR:=$(shell dirname "$(realpath $(firstword $(MAKEFILE_LIST)))")

MAKEFLAGS += --no-print-directory

.EXPORT_ALL_VARIABLES:
DOCKER_BUILDKIT?=1
DOCKER_CONFIG?=

USER := $(shell whoami)
UID := $(shell id -u)
GID := $(shell id -g)

.PHONY: help
help:
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make \033[36m<target>\033[0m\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

SRC_DIR := .
BUILD_DIR := ./build
DOCKER_ROS2_BUILDER_PACKAGER_IMAGE := ros2_debian_builder_packager

.PHONY: all
all: docker_build build package

.PHONY: build
build: clean ## Build all ros packages located in src
	mkdir -p ${BUILD_DIR}/build && cp src ${BUILD_DIR} -r
	docker run --rm -v $(ROOT_DIR)/$(BUILD_DIR)/src:/ros2_ws/src -v $(ROOT_DIR)/$(BUILD_DIR)/build:/ros2_ws/build  $(DOCKER_ROS2_BUILDER_PACKAGER_IMAGE) /bin/bash -c "make build"

.PHONY: package
package: ## Package, as debian packages, all ros packages located in src
	mkdir -p ${BUILD_DIR}/build && cp src ${BUILD_DIR} -r
	docker run --rm -v $(ROOT_DIR)/$(BUILD_DIR)/src:/ros2_ws/src -v $(ROOT_DIR)/$(BUILD_DIR)/build:/ros2_ws/build  $(DOCKER_ROS2_BUILDER_PACKAGER_IMAGE) /bin/bash -c "make package"

.PHONY: debug
debug: ## Run docker context in interactive session
	docker run -it --rm -v $(ROOT_DIR)/$(BUILD_DIR)/src:/ros2_ws/src -v $(ROOT_DIR)/$(BUILD_DIR)/build:/ros2_ws/build  $(DOCKER_ROS2_BUILDER_PACKAGER_IMAGE) /bin/bash -c "bash"

.PHONY: clean
clean: ## Clean build context
	rm -rf $(BUILD_DIR)

.PHONY: docker_build
docker_build: clean ## Delete docker image for ROS2 Debian Packager
	docker build -t $(DOCKER_ROS2_BUILDER_PACKAGER_IMAGE) --build-arg UID=${UID} --build-arg GID=${GID} -f Dockerfile .

