DEFAULT_TIMEOUT := 30

# Docker (Compose) configuration: Infrastructure
PRJ_NAME_INFRA := kafkesc-devcluster-infra
DKR_COMP_INFRA := docker-compose-infra.yml
DKR_CMD_INFRA := docker-compose --file $(DKR_COMP_INFRA) --project-name $(PRJ_NAME_INFRA)

# Docker (Compose) configuration: Workload
PRJ_NAME_WORK := kafkesc-devcluster-work
DKR_COMP_WORK := docker-compose-work.yml
DKR_CMD_WORK := docker-compose --file $(DKR_COMP_WORK) --project-name $(PRJ_NAME_WORK)

# Kafka configuration
BOOTSTRAP_BROKERS := localhost:19091,localhost:19092,localhost:19093
DEFAULT_GROUP := $(PRJ_NAME_INFRA)-group-id
DEFAULT_OFFSET := end

# Kafka configuration from within container
DKR_CMD_SERVICE := kafka-01
DKR_CMD_SERVICE_BOOTSTRAP_BROKERS := kafka-01:9091,kafka-02:9092,kafka-03:9093

# Topic configuration
DEFAULT_PARTITIONS := 3
DEFAULT_REPLICATION_FACTOR := 3

# Checking dependencies
DEPS_LIST := kcat docker docker-compose jq md5sum head
DEPS_CHECK := $(foreach dep,$(DEPS_LIST), \
        $(if $(shell which $(dep)), \
        	OK, \
        	$(error "Dependency '$(dep)' not found in PATH")))

# Default randomized key and value, used by the `produce` target
DEFAULT_KEY = K-$(shell echo $$RANDOM | md5sum | head -c 10)
DEFAULT_VAL = V-$(shell echo $$RANDOM | md5sum | head -c 20)

# User input
timeout := $(DEFAULT_TIMEOUT)
group := $(DEFAULT_GROUP)
offset := $(DEFAULT_OFFSET)
key = $(DEFAULT_KEY)
value = $(DEFAULT_VAL)
partitions = $(DEFAULT_PARTITIONS)
repfac = $(DEFAULT_REPLICATION_FACTOR)

.PHONY: init start stop restart kill logs ps consume produce pull topic.create topic.read topic.delete meta.brokers meta.topics meta.groups workload.setup workload.start workload.stop workload.restart workload.kill workload.ps workload.logs workload.pull

# --------------------------------------------------- Cluster lifecycle targets
init:
	$(DKR_CMD_INFRA) pull

start:
	@echo === Starting Kafka Infrastructure ===
	$(DKR_CMD_INFRA) up --detach --timeout $(timeout)
	@echo === Sleeping 30s to wait for things to settle... ===
	@sleep 30

stop: workload.stop
	@echo === Stopping Kafka Infrastructure ===
	$(DKR_CMD_INFRA) down --remove-orphans --timeout $(timeout)

restart:
	$(DKR_CMD_INFRA) restart  --timeout $(timeout)

kill:
	$(DKR_CMD_INFRA) kill --remove-orphans

logs:
	$(DKR_CMD_INFRA) logs -f $(service)

ps:
	$(DKR_CMD_INFRA) ps

pull:
	$(DKR_CMD_INFRA) pull

# ------------------------------------------------------ Basic commands targets
consume:
	kcat -b $(BOOTSTRAP_BROKERS) -C -J -o $(offset) -G $(group) $(topic)

produce:
	echo "$(key):$(value)" | kcat -b $(BOOTSTRAP_BROKERS) -P -K ':' -t $(topic)

# ------------------------------------------------------ Topic commands targets
topic.create:
	@$(DKR_CMD_INFRA) exec $(DKR_CMD_SERVICE) kafka-topics \
		--bootstrap-server $(DKR_CMD_SERVICE_BOOTSTRAP_BROKERS) \
		--create \
		--if-not-exists \
		--topic $(topic) \
		--partitions $(partitions) \
		--replication-factor $(repfac)
	@sleep 1

topic.read:
	@$(DKR_CMD_INFRA) exec $(DKR_CMD_SERVICE) kafka-topics \
		--bootstrap-server $(DKR_CMD_SERVICE_BOOTSTRAP_BROKERS) \
		--describe \
		--topic $(topic)

topic.delete:
	@$(DKR_CMD_INFRA) exec $(DKR_CMD_SERVICE) kafka-topics \
		--bootstrap-server $(DKR_CMD_SERVICE_BOOTSTRAP_BROKERS) \
		--delete \
		--topic $(topic)
	@sleep 2

# ------------------------------------------------------------ Metadata targets
meta.brokers:
	@echo === BROKERS ===
	@kcat -b $(BOOTSTRAP_BROKERS) -L -J | jq .brokers

meta.topics:
	@echo === TOPICS ===
	@kcat -b $(BOOTSTRAP_BROKERS) -L -J | jq '.topics[] | { topic: .topic, partitions: .partitions | length }'

meta.groups:
	@echo === CONSUMER GROUPS ===
	@$(DKR_CMD_INFRA) exec $(DKR_CMD_SERVICE) kafka-consumer-groups \
		--bootstrap-server $(DKR_CMD_SERVICE_BOOTSTRAP_BROKERS) \
		--describe \
		--all-groups

# ------------------------------------------------------------ Workload targets
workload.setup: start
	@echo === Creating Workload Topics ===
	$(MAKE) topic.create topic=workload01 partitions=15
	$(MAKE) topic.create topic=workload02 partitions=30
	$(MAKE) topic.create topic=workload03 partitions=36
	@sleep 3
	$(MAKE) meta.topics

workload.start: workload.setup
	@echo === Starting Workload ===
	$(DKR_CMD_WORK) up --detach --timeout $(timeout)

workload.stop:
	@echo === Stopping Workload ===
	$(DKR_CMD_WORK) down --remove-orphans --timeout $(timeout)

workload.restart:
	$(DKR_CMD_WORK) restart --timeout $(timeout)

workload.kill:
	$(DKR_CMD_WORK) kill --remove-orphans

workload.ps:
	$(DKR_CMD_WORK) ps

workload.logs:
	$(DKR_CMD_WORK) logs -f $(service)

workload.pull:
	$(DKR_CMD_WORK) pull
