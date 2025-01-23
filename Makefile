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

ARCHS := amd64 arm64

.PHONY: help
help:
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make \033[36m<target>\033[0m\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

SRC_DIR := .
BUILD_DIR := ${ROOT_DIR}/build
DOCKER_ROS2_BUILDER_PACKAGER_IMAGE := ros2_debian_builder_packager

.PHONY: all
all: docker_build build package

.PHONY: build
build: ## Build all ROS packages located in src
	rm -rf $(BUILD_DIR)
	mkdir -p ${BUILD_DIR}/amd64/build && cp src ${BUILD_DIR}/amd64/src -r
	mkdir -p ${BUILD_DIR}/arm64/build && cp src ${BUILD_DIR}/arm64/src -r
	docker run --rm -v ${BUILD_DIR}/amd64/src:/ros2_ws/src -v ${BUILD_DIR}/amd64/build:/ros2_ws/build  $(DOCKER_ROS2_BUILDER_PACKAGER_IMAGE):amd64 /bin/bash -c "make build"
	docker run --rm --platform linux/arm64 -v ${BUILD_DIR}/arm64/src:/ros2_ws/src -v ${BUILD_DIR}/arm64/build:/ros2_ws/build  $(DOCKER_ROS2_BUILDER_PACKAGER_IMAGE):arm64 /bin/bash -c "make build"

.PHONY: package
package: ## Package, as Debian packages, all ROS packages located in src
	mkdir -p ${BUILD_DIR}/build && cp src ${BUILD_DIR} -r
	docker run --rm -v ${BUILD_DIR}/amd64/src:/ros2_ws/src -v ${BUILD_DIR}/amd64/build:/ros2_ws/build  $(DOCKER_ROS2_BUILDER_PACKAGER_IMAGE):amd64 /bin/bash -c "make package"
	docker run --rm --platform linux/arm64 -v ${BUILD_DIR}/arm64/src:/ros2_ws/src -v ${BUILD_DIR}/arm64/build:/ros2_ws/build  $(DOCKER_ROS2_BUILDER_PACKAGER_IMAGE):arm64 /bin/bash -c "make package"

.PHONY: debug_amd64
debug_amd64: ## Run Docker context in interactive session for amd64
	docker run -it --rm -v $(ROOT_DIR)/$(BUILD_DIR)/src:/ros2_ws/src -v $(ROOT_DIR)/$(BUILD_DIR)/build/amd64:/ros2_ws/build  $(DOCKER_ROS2_BUILDER_PACKAGER_IMAGE):amd64 /bin/bash -c "bash"

.PHONY: debug
debug: debug_amd64 ## Run Docker context in interactive session for amd64

.PHONY: debug_arm
debug_arm: ## Run Docker context in interactive session for arm64
	docker run -it --rm --platform linux/arm64 -v $(ROOT_DIR)/$(BUILD_DIR)/src:/ros2_ws/src -v $(ROOT_DIR)/$(BUILD_DIR)/build/arm64:/ros2_ws/build  $(DOCKER_ROS2_BUILDER_PACKAGER_IMAGE):arm64 /bin/bash -c "bash"

.PHONY: clean
clean: ## Clean build context and Docker images
	rm -rf $(BUILD_DIR)
	docker rmi $(DOCKER_ROS2_BUILDER_PACKAGER_IMAGE):amd64 || true
	docker rmi $(DOCKER_ROS2_BUILDER_PACKAGER_IMAGE):arm64 || true

.PHONY: docker_build
docker_build: clean ## Build multi-architecture Docker images for ROS2 Debian Packager
	docker buildx create --name multiarch-builder --use --bootstrap || true
	docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
	for ARCH in $(ARCHS); do \
        docker buildx build --load --platform linux/$$ARCH -t $(DOCKER_ROS2_BUILDER_PACKAGER_IMAGE):$$ARCH \
        --build-arg UID=${UID} --build-arg GID=${GID} -f Dockerfile . || exit 1; \
    done

