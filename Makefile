DOCKER_IMAGE_VERSION=0.10.2.1
DOCKER_IMAGE_NAME=sumglobal/rpi-kafka
DOCKER_IMAGE_TAGNAME=$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_VERSION)

default: build

build:
	docker run --rm --privileged multiarch/qemu-user-static:register --reset
	docker build --no-cache -t $(DOCKER_IMAGE_TAGNAME) .
	docker tag $(DOCKER_IMAGE_TAGNAME) $(DOCKER_IMAGE_NAME):latest

push:
	docker push $(DOCKER_IMAGE_TAGNAME)
	docker push $(DOCKER_IMAGE_NAME)

