NAME     = peterwang115/mysql-slave
VERSIONS = $(foreach path, $(wildcard */Dockerfile), $(path:%/Dockerfile=%))

.PHONY: all build $(VERSIONS)

all: build

build: $(VERSIONS)

$(VERSIONS):
	docker build --rm=true -t $(NAME):$@ $@