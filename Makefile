# Add the override when the GPU monitoring project's network exists
COMPOSE := docker compose $(shell docker network inspect deploy_default >/dev/null 2>&1 && echo -f docker-compose.yml -f docker-compose.project1.yml)

.PHONY: up down logs status test shell queue clean

up:
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f

status:
	$(COMPOSE) exec slurmctld sinfo -N -l

test:
	./scripts/smoke_test.sh

queue:
	$(COMPOSE) exec -u alice slurmctld sbatch /jobs/queue_demo.sbatch
	$(COMPOSE) exec slurmctld squeue

shell:
	$(COMPOSE) exec -u alice slurmctld bash

clean:
	$(COMPOSE) down -v
