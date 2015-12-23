NAME     = ubuntu1404/etcd
VERSIONS = $(foreach path, $(wildcard */Dockerfile), $(path:%/Dockerfile=%))

.PHONY: all build $(VERSIONS)

all: build

build: $(VERSIONS)

$(VERSIONS):
	cp -f docker-entrypoint.sh $@/docker-entrypoint.sh
	docker build --rm=true -t $(NAME):$@ $@
	rm -f $@/docker-entrypoint.sh