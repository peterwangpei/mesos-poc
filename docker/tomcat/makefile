NAME     = peterwang115/tomcat-demo
VERSIONS = $(foreach path, $(wildcard */Dockerfile), $(path:%/Dockerfile=%))

.PHONY: all build $(VERSIONS)

all: build

build: $(VERSIONS)

$(VERSIONS):
	../../demo/demosite/demo/build.sh
	cp -f ../../demo/demosite/demo/target/demo.war $@
	docker build --rm=true -t $(NAME):$@ $@
	rm $@/demo.war