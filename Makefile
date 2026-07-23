IMAGE ?= ghcr.io/rancherlabs/db-cache-dump
TAG ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
LOCAL_IMAGE := $(IMAGE):$(TAG)

.PHONY: build test test-e2e import

build:
	docker build -t $(LOCAL_IMAGE) package/

test: build
	bash test/smoke.sh $(LOCAL_IMAGE)

test-e2e: build
	IMAGE=$(LOCAL_IMAGE) bash test/e2e-k3d.sh

import: build
	k3d image import $(LOCAL_IMAGE)
