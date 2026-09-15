GO_IMAGE ?= golang:1.26-bookworm
VERSION ?= 0.3.3
GOOS ?= linux
ARCH ?= amd64
PACKAGE_ARCHES ?= amd64 arm64
PLUGIN_DIR := build/plugins/$(GOOS)/$(ARCH)
PLUGIN_SO := $(PLUGIN_DIR)/cliproxyapi-copilot.so
CACHE_DIR := .cache
VERSION_LDFLAG := -X main.pluginVersion=$(VERSION)
DOCKER_PLATFORM_amd64 :=
DOCKER_PLATFORM_arm64 := --platform linux/arm64

.PHONY: test build build-arm64 build-all build-local package clean

test:
	go test ./...

build:
	mkdir -p $(PLUGIN_DIR) $(CACHE_DIR)/go-build $(CACHE_DIR)/go-mod $(CACHE_DIR)/home
	docker run --rm \
		$(DOCKER_PLATFORM_$(ARCH)) \
		--user "$$(id -u):$$(id -g)" \
		-e HOME=/src/$(CACHE_DIR)/home \
		-e GOCACHE=/src/$(CACHE_DIR)/go-build \
		-e GOMODCACHE=/src/$(CACHE_DIR)/go-mod \
		-v "$(CURDIR):/src" \
		-w /src \
		$(GO_IMAGE) \
		sh -ec 'CGO_ENABLED=1 GOOS=$(GOOS) GOARCH=$(ARCH) go build -buildvcs=false -trimpath -ldflags "$(VERSION_LDFLAG)" -buildmode=c-shared -o $(PLUGIN_SO) ./cmd/cliproxyapi-copilot'

build-arm64:
	$(MAKE) build ARCH=arm64

build-local:
	mkdir -p $(PLUGIN_DIR)
	CGO_ENABLED=1 GOOS=$(GOOS) GOARCH=$(ARCH) go build -buildvcs=false -trimpath -ldflags "$(VERSION_LDFLAG)" -buildmode=c-shared -o $(PLUGIN_SO) ./cmd/cliproxyapi-copilot

build-all: build build-arm64

package: build-all
	scripts/package-release.sh "$(VERSION)" "$(GOOS)" $(PACKAGE_ARCHES)

clean:
	rm -rf build dist $(CACHE_DIR)
