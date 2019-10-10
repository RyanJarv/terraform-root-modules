
export DOCKER_ORG ?= ryanjarv
export DOCKER_IMAGE ?= $(DOCKER_ORG)/${IMAGE_NAME}
export DOCKER_TAG ?= latest
export DOCKER_IMAGE_NAME ?= $(DOCKER_IMAGE):$(DOCKER_TAG)
export DOCKER_BUILD_FLAGS = 
export BUILD_HARNESS_ORG=ryanjarv
export BUILD_HARNESS_PROJECT ?= build-harness
export BUILD_HARNESS_BRANCH ?= master
export README_DEPS ?= docs/targets.md docs/terraform.md

export SOURCE_DOCKER_REGISTRY=${DOCKER_ORG}
export SOURCE_VERSION=${DOCKER_TAG}
export IMAGE_NAME=terraform-root-modules
export TARGET_DOCKER_REGISTRY=${DOCKER_ORG}
export TARGET_VERSION=0.11.0
-include $(shell curl -sSL -o .build-harness "https://git.io/build-harness"; echo .build-harness)

all: init deps build install run

deps:
	@exit 0

build:
	@make --no-print-directory docker:build

push:
	docker push $(DOCKER_IMAGE)

run:
	docker run -it ${DOCKER_IMAGE_NAME} sh
