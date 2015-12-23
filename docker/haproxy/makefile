NAME     = ubuntu1404/haproxy
VERSIONS = $(foreach path, $(wildcard */Dockerfile), $(path:%/Dockerfile=%))

.PHONY: all build $(VERSIONS)

all: build

build: $(VERSIONS)

$(VERSIONS):
	docker build --rm=true -t $(NAME):$@ $@