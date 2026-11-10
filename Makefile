.PHONY: up down logs status test shell queue clean

up:
	docker compose up -d --build

down:
	docker compose down

logs:
	docker compose logs -f

status:
	docker compose exec slurmctld sinfo -N -l

test:
	./scripts/smoke_test.sh

queue:
	docker compose exec -u alice slurmctld sbatch /jobs/queue_demo.sbatch
	docker compose exec slurmctld squeue

shell:
	docker compose exec -u alice slurmctld bash

clean:
	docker compose down -v
