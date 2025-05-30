MAKEFLAGS += --silent

# Include externalized environment variables from file, if available.  For example:
#   make ENV_FILE=my-settings.env <target>
ENV_FILE := default.env
-include ${ENV_FILE}
export

# Specify default environment variables if not provided via environment, $ENV_FILE, or commandline
BASE_MODULE := github.com/weesvc
PROJECT_MODULE := $(BASE_MODULE)/weesvc-gorilla
PROJECT_NAME := weesvc

BUILD_VERSION := "0.0.1-SNAPSHOT"
BUILD_REVISION := $(shell git describe --always --dirty)
BUILD_OS := darwin linux windows    # Targeted build OS's
BUILD_ARCH := 386 amd64             # Targeted build architectures

DOCKER_IMAGE := $(PROJECT_MODULE)
DOCKER_TAG := $(BUILD_VERSION)

# Linker Flags
LINKER_FLAGS := "-X $(PROJECT_MODULE)/internal/env.Version=$(BUILD_VERSION) -X $(PROJECT_MODULE)/internal/env.Revision=$(BUILD_REVISION)"


all: imports fmt vet build

## help: Prints a list of available build targets.
help:
	echo "Usage: make <OPTIONS> ... <TARGETS>"
	echo ""
	echo "Available targets are:"
	echo ''
	sed -n 's/^##//p' ${PWD}/Makefile | column -t -s ':' | sed -e 's/^/ /'
	echo
	echo "Targets run by default are: `sed -n 's/^all: //p' ./Makefile | sed -e 's/ /, /g' | sed -e 's/\(.*\), /\1, and /'`"

## clean-all: Scrub all build artifacts and vendored code.
clean-all: clean

## clean: Remove all build artifacts and generated files.
clean: clean-artifacts
	go clean -i ./...
	rm -Rf bin/

## clean-artifacts: Remove all build artifacts.
clean-artifacts:
	rm -Rf artifacts/

## deps: Verifies and cleans up module dependencies.
deps:
	echo "Tidying modules..."
	go mod tidy

## test: Runs unit tests for the application.
test:
	go test -test.short -cover ./...

## imports: Organizes imports within the codebase.
imports:
	echo "[SKIPPING] Organizing imports..."
#	goimports -w -l --local $(BASE_MODULE) .

## fmt: Applies appropriate formatting on the codebase.
fmt:
	echo "Formatting code..."
	go fmt ./...

## vet: Searches for any suspicious constructs within the codebase.
vet:
	echo "Vetting code..."
	go vet ./...

## setup: Downloads all required tooling for building the application.
setup:
	echo "Installing tools..."
	go install golang.org/x/tools/cmd/goimports@latest

## build: Build the application.
build: deps imports fmt vet build-only

## build-only: Build without prerequisite steps
build-only:
	echo "Building '${PROJECT_NAME}'..."
	mkdir -v -p $(CURDIR)/bin
	go install github.com/a-h/templ/cmd/templ@latest
	templ generate .
	go build -v \
	   -ldflags $(LINKER_FLAGS) \
	   -o "bin/$(PROJECT_NAME)" .

## build-all: Builds all architectures of the application.
build-all: deps imports fmt vet
	mkdir -v -p $(CURDIR)/artifacts
	go install github.com/a-h/templ/cmd/templ@latest
	templ generate .
	gox -verbose \
	    -os "$(BUILD_OS)" -arch "$(BUILD_ARCH)" \
	    -ldflags $(LINKER_FLAGS) \
	    -output "$(CURDIR)/artifacts/{{.OS}}_{{.Arch}}/$(PROJECT_NAME)" .
	mkdir -v -p $(CURDIR)/bin
	cp -v -f \
	    $(CURDIR)/artifacts/$$(go env GOOS)_$$(go env GOARCH)/$(PROJECT_NAME) ./bin

## build-docker: Builds the application as a Docker image.
build-docker:
	docker build --build-arg build_version=$(BUILD_VERSION) -t $(DOCKER_IMAGE):$(DOCKER_TAG) .

## release-docker: Builds the application as a Docker image and pushes to a repository.
release-docker: build-docker
	docker push $(DOCKER_IMAGE):$(DOCKER_TAG)

## develop: Start the application in hot-reload mode.
develop: build-only
	go install github.com/cosmtrek/air@latest
	templ generate --watch --proxy=http://localhost:9092 &
	air -c ./.air.toml -- serve -c config-postgres.yaml --server-port=9092 --resource-caching-enabled=false


.PHONY: build build-all \
        clean clean-all clean-artifacts \
        deps develop fmt help imports \
        setup test vet
