GO_IMAGE ?= golang:1.26-bookworm
BUILD_PLATFORM ?= linux/amd64
VERSION ?= 0.3.3
GOOS ?= linux
ARCH ?= amd64
PACKAGE_ARCHES ?= amd64 arm64
PLUGIN_DIR := build/plugins/$(GOOS)/$(ARCH)
PLUGIN_SO := $(PLUGIN_DIR)/cliproxyapi-copilot.so
CACHE_DIR := .cache
VERSION_LDFLAG := -X main.pluginVersion=$(VERSION)
BUILD_PREREQ_amd64 :=
BUILD_PREREQ_arm64 := apt-get update >/dev/null && apt-get install -y --no-install-recommends gcc-aarch64-linux-gnu libc6-dev-arm64-cross >/dev/null &&
BUILD_ENV_amd64 := GOOS=$(GOOS) GOARCH=amd64
BUILD_ENV_arm64 := GOOS=$(GOOS) GOARCH=arm64 CC=aarch64-linux-gnu-gcc
DOCKER_USER_amd64 := --user "$$(id -u):$$(id -g)"
# arm64 installs its cross compiler in the container. The EXIT cleanup below
# returns bind-mounted output and caches to the invoking host user.
DOCKER_USER_arm64 := --user 0:0
DOCKER_ENV_amd64 :=
DOCKER_ENV_arm64 := -e BUILD_UID="$$(id -u)" -e BUILD_GID="$$(id -g)"
BUILD_CLEANUP_amd64 :=
BUILD_CLEANUP_arm64 := cleanup() { chown -R "$$BUILD_UID:$$BUILD_GID" /src/$(PLUGIN_DIR) /src/$(CACHE_DIR); }; trap cleanup 0;

.PHONY: test build build-arm64 build-all build-local package clean

test:
	go test ./...

build:
	mkdir -p $(PLUGIN_DIR) $(CACHE_DIR)/go-build $(CACHE_DIR)/go-mod $(CACHE_DIR)/home
	docker run --rm \
		--platform $(BUILD_PLATFORM) \
		$(DOCKER_USER_$(ARCH)) \
		$(DOCKER_ENV_$(ARCH)) \
		-e HOME=/src/$(CACHE_DIR)/home \
		-e GOCACHE=/src/$(CACHE_DIR)/go-build \
		-e GOMODCACHE=/src/$(CACHE_DIR)/go-mod \
		-v "$(CURDIR):/src" \
		-w /src \
		$(GO_IMAGE) \
		sh -ec '$(BUILD_CLEANUP_$(ARCH)) $(BUILD_PREREQ_$(ARCH)) CGO_ENABLED=1 $(BUILD_ENV_$(ARCH)) go build -buildvcs=false -trimpath -ldflags "$(VERSION_LDFLAG)" -buildmode=c-shared -o $(PLUGIN_SO) ./cmd/cliproxyapi-copilot'

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
