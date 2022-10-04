# Docker (Compose) configuration
PRJ_NAME := kafkesc-devcluster
DKR_COMP := docker-compose.yml
DKR_CMD := docker-compose --file $(DKR_COMP) --project-name $(PRJ_NAME)
DEFAULT_TIMEOUT := 30

# Kafka configuration
BOOTSTRAP_BROKERS := localhost:19091,localhost:19092,localhost:19093
DEFAULT_GROUP := $(PRJ_NAME)-group-id
DEFAULT_OFFSET := end

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

.PHONY: init start stop restart kill logs status consume produce ls-brokers ls-topics

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

status:
	docker ps --filter name=kafka-0
	docker ps --filter name=zookeeper

# ------------------------------------------------ Kafka basic commands targets
consume:
	kcat -b $(BOOTSTRAP_BROKERS) -C -J -o $(offset) -G $(group) $(topic)

produce:
	echo "$(key):$(value)" | kcat -b $(BOOTSTRAP_BROKERS) -P -K ':' -t $(topic)

# ------------------------------------------------------ Kafka metadata targets
ls-brokers:
	kcat -b $(BOOTSTRAP_BROKERS) -L -J | jq .brokers

ls-topics:
	kcat -b $(BOOTSTRAP_BROKERS) -L -J | jq '.topics[] | { topic: .topic, partitions: .partitions | length }'
