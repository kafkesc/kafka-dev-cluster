# Docker (Compose) configuration
PRJ_NAME := kafkesc-devcluster
DKR_COMP := docker-compose.yml
DKR_CMD := docker-compose --file $(DKR_COMP) --project-name $(PRJ_NAME)
DEFAULT_TIMEOUT := 30

# Kafka configuration
BOOTSTRAP_BROKERS := localhost:19091,localhost:19092,localhost:19093
DEFAULT_GROUP := $(PRJ_NAME)-group-id
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

.PHONY: init start stop restart kill logs ps consume produce topic.create topic.read topic.delete meta.brokers meta.topics meta.groups

# --------------------------------------------------- Cluster lifecycle targets
init:
	$(DKR_CMD) pull

start:
	$(DKR_CMD) up --detach --timeout $(timeout)

stop:
	$(DKR_CMD) down --remove-orphans --timeout $(timeout)

restart:
	$(DKR_CMD) restart  --timeout $(timeout)

kill:
	$(DKR_CMD) kill --remove-orphans --timeout $(timeout)

logs:
	$(DKR_CMD) logs -f $(service)

ps:
	$(DKR_CMD) ps

# ------------------------------------------------ Kafka basic commands targets
consume:
	kcat -b $(BOOTSTRAP_BROKERS) -C -J -o $(offset) -G $(group) $(topic)

produce:
	echo "$(key):$(value)" | kcat -b $(BOOTSTRAP_BROKERS) -P -K ':' -t $(topic)

# ------------------------------------------------ Kafka topic commands targets
topic.create:
	@$(DKR_CMD) exec $(DKR_CMD_SERVICE) kafka-topics \
		--bootstrap-server $(DKR_CMD_SERVICE_BOOTSTRAP_BROKERS) \
		--create \
		--if-not-exists \
		--topic $(topic) \
		--partitions $(partitions) \
		--replication-factor $(repfac)

topic.read:
	@$(DKR_CMD) exec $(DKR_CMD_SERVICE) kafka-topics \
		--bootstrap-server $(DKR_CMD_SERVICE_BOOTSTRAP_BROKERS) \
		--describe \
		--topic $(topic)

topic.delete:
	@$(DKR_CMD) exec $(DKR_CMD_SERVICE) kafka-topics \
		--bootstrap-server $(DKR_CMD_SERVICE_BOOTSTRAP_BROKERS) \
		--delete \
		--topic $(topic)

# ------------------------------------------------------ Kafka metadata targets
meta.brokers:
	@echo === BROKERS ===
	@kcat -b $(BOOTSTRAP_BROKERS) -L -J | jq .brokers

meta.topics:
	@echo === TOPICS ===
	@kcat -b $(BOOTSTRAP_BROKERS) -L -J | jq '.topics[] | { topic: .topic, partitions: .partitions | length }'

meta.groups:
	@echo === CONSUMER GROUPS ===
	@$(DKR_CMD) exec $(DKR_CMD_SERVICE) kafka-consumer-groups \
		--bootstrap-server $(DKR_CMD_SERVICE_BOOTSTRAP_BROKERS) \
		--describe \
		--all-groups