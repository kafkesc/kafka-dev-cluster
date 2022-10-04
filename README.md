# Kafkesc: Kafka Development Cluster

A **_battery-included_** BUT **_development-only_** pairing of `Makefile` & `docker-compose.yml`,
designed to quickly spin-up a [Kafka](https://kafka.apache.org/) cluster for development purposes.

The `docker-compose.yml` launches:

* a Kafka cluster made of 3 Brokers
* a ZooKeeper ensemble, made of a single server

This should be plenty for local development of services and tools, designed
to interact and operate against Kafka.

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

|      Command | Arguments                                                                                                                    | Description                                                                                  |
|-------------:|------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------|
|       `init` |                                                                                                                              | Prepares localhost to launch the cluster                                                     |
|      `start` | `timeout=SEC`                                                                                                                | Launches the cluster                                                                         |
|       `stop` | `timeout=SEC`                                                                                                                | Shuts down the cluster                                                                       |
|    `restart` | `timeout=SEC`                                                                                                                | Restarts the cluster                                                                         |
|       `kill` | `timeout=SEC`                                                                                                                | Forcefully shuts down the cluster (i.e. `SIGKILL`)                                           |
|       `logs` | `?service=(zookeeper,kafka-0[1-3])`                                                                                          | Tail-follow logs of the running services (default: all services).                            |
|     `status` |                                                                                                                              | Docker status of the running services                                                        |
|    `consume` | `topic=TOPIC_STR`, `?offset=(beginning,end,stored,OFFSET_INT,-OFFSET_INT,s@TIMESTAMP_MS,e@TIMESTAMP_MS)`, `?group=GROUP_STR` | Consume from a topic, from a given offset and using a given `group.id`; use `CTRL+C` to stop |
|    `produce` | `topic=TOPIC_STR`, `?key=KEY_STR`, `?value=VALUE_STR`                                                                        | Produce to a topic, using a given key/value pair                                             |
| `ls-brokers` |                                                                                                                              | Lists cluster brokers                                                                        |
|  `ls-topics` |                                                                                                                              | Lists clusters topics                                                                        |

**NOTE:**

* `?ARG`: the argument is optional
* `SEC`: amount of seconds
* `group` defaults to `kafkesc-devcluster-group-id`
* `offset` defaults to `end` - see [`kcat`](https://github.com/edenhill/kcat) for more details
  * `TIMESTAMP_MS`: timestamp in milliseconds
  * `OFFSET_INT`: integer of the _absolute_ offset of a record
  * `-OFFSET_INT`: integer of the _relative_ offset of a record from the end
* `key` defaults to a random alphanumeric string of 12 characters (ex. `K-a21d38311c`)
* `value` defaults to a random alphanumeric string of 22 characters (ex. `V-6bbeba0cf4d0d5c2de36`)
* `*_STR`: argument value is a string

## Connecting

Once `start`ed, you can connect to the services using:

|                         | Configuration strings                             |
|-------------------------|---------------------------------------------------|
| Kafka bootstrap brokers | `localhost:19091,localhost:19092,localhost:19093` |
| ZooKeeper server        | `localhost:2181`                                  |

## Supported environment variables

`docker-compose` accepts environment variables that will be applied in the configuration, following the 
rules documented [here](https://docs.docker.com/compose/environment-variables/).

| Env name | Default | Description                                                                                                                                                                                |
|---------:|:--------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `CP_VER` | `7.2.2` | Version of Confluent Platform to use. See [here](https://docs.confluent.io/platform/current/installation/versions-interoperability.html) for how it maps to the specific version of Kafka. |

The default values are defined in [`.env`](./.env).

## Network structure

This setup currently doesn't do anything special: it lets Docker Compose create a single network, following the
rules described [here](https://docs.docker.com/compose/networking/).
The network should be called `kafkesc-devcluster_default`.

The containers launched by the docker compose are reachable from your `localhost`. The ports are mapped like this:

|     Service | `localhost` client port | `kafka-devcluster_default` client port |
|------------:|:-----------------------:|:--------------------------------------:|
| `zookeeper` |         `2181`          |                 `2181`                 |
|  `kafka-01` |         `19091`         |                 `9091`                 |
|  `kafka-02` |         `19092`         |                 `9092`                 |
|  `kafka-03` |         `19093`         |                 `9093`                 |

The Kafka brokers will communicate with each other using the `kafka-0[1-3]:909[1-3]`.
Instead, to communicate with ZooKeeper, brokers will use `zookeeper:2181`.

## Storage

TODO

## License

TODO
