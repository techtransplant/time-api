build:
	docker-compose build

up: build
	docker-compose up -d

down:
	docker-compose down

restart: down up

deploy:
	./deploy.sh

deploy-auto:
	./deploy.sh --auto-approve

destroy:
	./destroy.sh

destroy-auto:
	./destroy.sh --auto-approve
