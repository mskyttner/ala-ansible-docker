NAME = dina-web/ala-docker
VERSION = $(TRAVIS_BUILD_ID)
ME = $(USER)
HOST = ala.dina-web.net
TS := $(shell date '+%Y_%m_%d_%H_%M')


all: init build up

init:
	@echo "Pulling source code for dependencies from GitHub..."
	mkdir -p mysql-datadir
	test -d ala-install || git clone --depth=1 \
		https://github.com/AtlasOfLivingAustralia/ala-install
	curl -L -s -o wait-for-it.sh \
		https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh && \
		chmod +x wait-for-it.sh

build:
	@echo "Building Docker image..."
	docker-compose build ala

up: 
	@echo "Starting services..."
	docker-compose up -d

stop:
	@echo "Stopping services..."
	docker-compose stop

clean: stop rm
	@echo "Removing code and persisted db data..."
	sudo rm -rf wait-for-it.sh ala-install

rm:
	docker-compose rm -vf
	sudo rm -rf mysql-datadir

push:
	docker push $(NAME)

release: build push
