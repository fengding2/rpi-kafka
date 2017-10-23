
rpi kafka-docker
============

ARM 32 bit Dockerfile for [Apache Kafka](http://kafka.apache.org/)

Uses the Azul embedded Open JDK

The image is available directly from [Docker Hub](https://hub.docker.com/r/sumglobal/rpi-kafka/)

## Usage with Kubernetes

- Assumes there is a running Zookeeper in the cluster with service name "zookeeper" listening on port 2181. You can find the one we are using here: [rpi-zookeeper](https://hub.docker.com/r/sumglobal/rpi-zookeeper) 

- Create a Replication Controller

- ```TODO: finish instructions```


## Usage with Docker compose

Start a cluster:

- ```docker-compose up -d ```

Add more brokers:

- ```docker-compose scale kafka=3```

Destroy a cluster:

- ```docker-compose stop```

## Note

The default ```docker-compose.yml``` should be seen as a starting point. By default each broker will get a new port number and broker id on restart. Depending on your use case this might not be desirable. If you need to use specific ports and broker ids, modify the docker-compose configuration accordingly, e.g. [docker-compose-single-broker.yml](https://github.com/wurstmeister/kafka-docker/blob/master/docker-compose-single-broker.yml):

- ```docker-compose -f docker-compose-single-broker.yml up```

## Broker IDs

You can configure the broker id in different ways

1. explicitly, using ```KAFKA_BROKER_ID```
2. via a command, using ```BROKER_ID_COMMAND```, e.g. ```BROKER_ID_COMMAND: "hostname | awk -F'-' '{print $2}'"```

If you don't specify a broker id in your docker-compose file, it will automatically be generated (see [https://issues.apache.org/jira/browse/KAFKA-1070](https://issues.apache.org/jira/browse/KAFKA-1070). This allows scaling up and down. In this case it is recommended to use the ```--no-recreate``` option of docker-compose to ensure that containers are not re-created and thus keep their names and ids.


## Automatically create topics

If you want to have kafka-docker automatically create topics in Kafka during
creation, a ```KAFKA_CREATE_TOPICS``` environment variable can be
added in ```docker-compose.yml```.

Here is an example snippet from ```docker-compose.yml```:

        environment:
          KAFKA_CREATE_TOPICS: "Topic1:1:3,Topic2:1:1:compact"

```Topic 1``` will have 1 partition and 3 replicas, ```Topic 2``` will have 1 partition, 1 replica and a `cleanup.policy` set to `compact`.

## Advertised hostname

You can configure the advertised hostname in different ways

1. explicitly, using ```KAFKA_ADVERTISED_HOST_NAME```
2. via a command, using ```HOSTNAME_COMMAND```, e.g. ```HOSTNAME_COMMAND: "route -n | awk '/UG[ \t]/{print $$2}'"```

When using commands, make sure you review the "Variable Substitution" section in [https://docs.docker.com/compose/compose-file/](https://docs.docker.com/compose/compose-file/)

If ```KAFKA_ADVERTISED_HOST_NAME``` is specified, it takes precedence over ```HOSTNAME_COMMAND```

## JMX

For monitoring purposes you may wish to configure JMX. Additional to the standard JMX parameters, problems could arise from the underlying RMI protocol used to connect

* java.rmi.server.hostname - interface to bind listening port
* com.sun.management.jmxremote.rmi.port - The port to service RMI requests

For example, to connect to a kafka running locally (assumes exposing port 1099)

      KAFKA_JMX_OPTS: "-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Djava.rmi.server.hostname=127.0.0.1 -Dcom.sun.management.jmxremote.rmi.port=1099"
      JMX_PORT: 1099

Jconsole can now connect at ```jconsole 192.168.99.100:1099```

