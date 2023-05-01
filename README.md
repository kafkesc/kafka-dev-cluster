# Kafkesc: Kafka Development Cluster

A **_battery-included_** BUT **_development-only_** pairing of `Makefile` & `docker-compose.yml`,
designed to quickly spin-up a [Kafka](https://kafka.apache.org/) cluster for development purposes.

The `docker-compose-infra.yml` launches:

* a Kafka cluster made of 3 Brokers
* a ZooKeeper ensemble, made of a single server

This should be plenty for local development of services and tools, designed
to interact and operate against Kafka.

For the `docker-compose-work.yml`, refer to the [Workload Generation](#workload-generation) section below.

## Dependencies

* [`kcat`](https://github.com/edenhill/kcat)
* [`docker` + `docker-compose`](https://docs.docker.com/get-docker/) 
* [`jq`](https://stedolan.github.io/jq/) 
* `md5sum`, `head` ([GNU Core Utilities](https://en.wikipedia.org/wiki/List_of_GNU_Core_Utilities_commands))

## Getting started

The project provides a `Makefile` with super-simple functionalities.
It provides single _mnemonic devices_ to manage the cluster lifecycle and 
do basic operations against Kafka topics.

A good `Makefile` autocompletion will make things even easier.

|            Command | Arguments                                                                                                | Description                                                                                  |
|-------------------:|----------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------|
|             `init` |                                                                                                          | Prepares localhost to launch the cluster                                                     |
|            `start` | `timeout=SEC`                                                                                            | Launches the cluster                                                                         |
|             `stop` | `timeout=SEC`                                                                                            | Shuts down the cluster: remove every resource for the project                                |
|          `restart` | `timeout=SEC`                                                                                            | Restarts the cluster                                                                         |
|             `kill` | `timeout=SEC`                                                                                            | Forcefully shuts down the cluster (i.e. `SIGKILL`)                                           |
|             `logs` | `?service=(zookeeper,kafka-0[1-3])`                                                                      | Tail-follow logs of the running services (default: all services).                            |
|               `ps` |                                                                                                          | Docker status of the running services                                                        |
|          `consume` | `topic=TOPIC`,<br/> `?offset=(beginning, end, stored, OFFSET, -OFFSET, s@TS, e@TS)`,<br/> `?group=GROUP` | Consume from a topic, from a given offset and using a given `group.id`; use `CTRL+C` to stop |
|          `produce` | `topic=TOPIC`,<br/> `?key=KEY`,<br/> `?value=VALUE`                                                      | Produce to a topic, using a given key/value pair                                             |
|     `topic.create` | `topic=TOPIC`,<br/> `?partitions=PC`,<br/> `?repfac=RF`                                                  | Create a new topic                                                                           |
|       `topic.read` | `topic=TOPIC`                                                                                            | Describe a topic                                                                             |
|     `topic.delete` | `topic=TOPIC`                                                                                            | Delete a topic                                                                               |
|     `meta.brokers` |                                                                                                          | Lists cluster brokers                                                                        |
|      `meta.topics` |                                                                                                          | Lists clusters topics                                                                        |
|      `meta.groups` |                                                                                                          | Lists clusters consumer groups                                                               |
|   `workload.setup` |                                                                                                          | Creates necessary topics for the producers/consumers to use                                  |
|   `workload.start` |                                                                                                          | Start `docker-compose-work.yml`: launch producers ([ksunami]) and consumers ([kcat])         |
|    `workload.stop` |                                                                                                          | Stop `docker-compose-work.yml`: remove every resource for the project                        |
| `workload.restart` |                                                                                                          | Restart `docker-compose-work.yml`                                                            |
|    `workload.kill` |                                                                                                          | Forcefully shuts down `docker-compose-work.yml` (i.e. `SIGKILL`)                             | 
|      `workload.ps` |                                                                                                          | Docker status of the running services                                                        |
|    `workload.logs` | `?service=(prod-0[1-3],cons-0[1-3][abc]?)`                                                               | Tail-follow logs of the running services (default: all services).                            |

**NOTE:**

* `?ARG`: the argument is optional
* `SEC`: amount of seconds
* `group` defaults to `kafkesc-devcluster-group-id`
* `offset` defaults to `end` - see [`kcat`](https://github.com/edenhill/kcat) for more details
  * `s@TS`: timestamp in milliseconds to start at
  * `e@TS`: timestamp in milliseconds to end at (not included)
  * `OFFSET`: integer of the _absolute_ offset of a record
  * `-OFFSET`: integer of the _relative_ offset of a record from the end
* `key` defaults to a random alphanumeric string of 12 characters (ex. `K-a21d38311c`)
* `value` defaults to a random alphanumeric string of 22 characters (ex. `V-6bbeba0cf4d0d5c2de36`)
* `partitions` defaults to `3`
  * `PC`: partitions count for the `topic`
* `repfac` defaults to `3`
  * `RF`: replication factor for the `topic`

## Connecting

Once `start`ed, you can connect to the services using:

|                         | Configuration strings                             |
|-------------------------|---------------------------------------------------|
| Kafka bootstrap brokers | `localhost:19091,localhost:19092,localhost:19093` |
| ZooKeeper server        | `localhost:2181`                                  |

## Supported environment variables

`docker-compose` accepts environment variables that will be applied in the configuration, following the 
rules documented [here](https://docs.docker.com/compose/environment-variables/).

The default values are defined in [`.env`](./.env).

## Network structure

The `docker-compose-infra.yml` is in charge of creating a single, default `bridge` network: `kafkesc-devcluster-network`.

The `docker-compose-work.yml` depends on it: it sets as its own `default` network, the one created by `docker-compose-infra.yml`,
so that producers and consumers can connect to the Kafka brokers.

The containers launched by the `-infra` docker compose are reachable from your `localhost`. The ports are mapped like this:

|     Service | `localhost` client port | `kafka-devcluster_default` client port |
|------------:|:-----------------------:|:--------------------------------------:|
| `zookeeper` |         `2181`          |                 `2181`                 |
|  `kafka-01` |         `19091`         |                 `9091`                 |
|  `kafka-02` |         `19092`         |                 `9092`                 |
|  `kafka-03` |         `19093`         |                 `9093`                 |

The Kafka brokers will communicate with each other using the `kafka-0[1-3]:909[1-3]`.
Instead, to communicate with ZooKeeper, brokers will use `zookeeper:2181`.

### Running commands _inside_ a container

This is probably obvious from section above, but it's good to explicitly call out:
when `docker exec`-uting from inside one of the docker containers, it's possible to
address the sibling containers using the _Service_ name as target hostname.

## Workload Generation

In addition to the "infrastructure", this project can also spawn a _workload_.
Maybe it's not realistic to use this for benchmarking, but having a producers/consumers in place, that are moving
records on the cluster, can be a time saver during development.

This is realised by the `docker-compose-work.yml` setup. But of course, everything is controlled via `Makefile`, so
you should care about these details only if you want to make changes (or if something is broken).

### Producers included in the Workload

Instances of [ksunami] are set up for a specific producer behaviour:

|  Produced Topic Name | Container name | Ksunami Behaviour                                                              |
|---------------------:|---------------:|--------------------------------------------------------------------------------|
|         `workload01` |      `prod-01` | spikes once a day; 100x traffic at spike                                       |
|         `workload02` |      `prod-02` | no traffic for most; massive spike with 10000x traffic for 30s every 5 minutes |
|         `workload03` |      `prod-03` | pretty stable; `min` and `max` phase almost identical                          |

### Consumers included in the Workload

Instances of [kcat] are set up for a specific grouping:

| Consumed Topic | Consumer Group | Container name |
|---------------:|---------------:|:---------------|
|   `workload01` |      `cons-01` | `cons-01a`     |
|   `workload01` |      `cons-01` | `cons-01b`     |
|   `workload02` |      `cons-02` | `cons-02`      |
|   `workload03` |      `cons-03` | `cons-03a`     |
|   `workload03` |      `cons-03` | `cons-03b`     |
|   `workload03` |      `cons-03` | `cons-03c`     |

Please see [docker-compose-workload.yml](./docker-compose-work.yml) for details.

## Storage and Persistence

**TODO**

At current stage, at shutdown all data is lost.

Maybe this is a chance for _Your_ contribution? :wink: :innocent:

## License

[Apache License 2.0](./LICENSE)

[ksunami]: https://crates.io/crates/ksunami
[kcat]: https://github.com/edenhill/kcat