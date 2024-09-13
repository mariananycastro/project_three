build:
	docker compose build

bash:
	docker compose up -d
	docker exec -it sinatra bash

down:
	docker compose down

stop:
	docker stop

server:
	docker compose up -d
	docker exec -it sinatra /bin/sh -c "bundle exec rackup --host 0.0.0.0 -p 4567"
