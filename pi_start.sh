#!/bin/bash -x

#KAFKA_PORT=9092
# If a ZooKeeper container is linked with the alias `zookeeper`, use it.
# You MUST set ZOOKEEPER_IP in env otherwise.
# [ -n "$ZOOKEEPER_PORT_2181_TCP_ADDR" ] && ZOOKEEPER_IP=$ZOOKEEPER_PORT_2181_TCP_ADDRI
# [ -n "$ZOOKEEPER_PORT_2181_TCP_PORT" ] && ZOOKEEPER_PORT=$ZOOKEEPER_PORT_2181_TCP_PORT

# IP=$(grep "\s${HOSTNAME}$" /etc/hosts | head -n 1 | awk '{print $1}')

# Store original IFS config, so we can restore it at various stages
ORIG_IFS=$IFS

if [[ -z "$KAFKA_ZOOKEEPER_CONNECT" ]]; then
    echo "ERROR: missing mandatory config: KAFKA_ZOOKEEPER_CONNECT"
    exit 1
fi

if [[ -z "$KAFKA_PORT" ]]; then
    export KAFKA_PORT=9092
fi


create-topics.sh &
unset KAFKA_CREATE_TOPICS

if [[ -z "$KAFKA_ADVERTISED_PORT" && \
  -z "$KAFKA_LISTENERS" && \
  -z "$KAFKA_ADVERTISED_LISTENERS" && \
  -S /var/run/docker.sock ]]; then
    KAFKA_ADVERTISED_PORT=$(docker port "$(hostname)" $KAFKA_PORT | sed -r 's/.*:(.*)/\1/g')
    export KAFKA_ADVERTISED_PORT
fi

if [[ -z "$KAFKA_BROKER_ID" ]]; then
    if [[ -n "$BROKER_ID_COMMAND" ]]; then
        KAFKA_BROKER_ID=$(eval "$BROKER_ID_COMMAND")
        export KAFKA_BROKER_ID
    else
        # By default auto allocate broker ID
        export KAFKA_BROKER_ID=-1
    fi
fi

if [[ -z "$KAFKA_LOG_DIRS" ]]; then
    export KAFKA_LOG_DIRS="/kafka/kafka-logs-$HOSTNAME"
fi

if [[ -n "$KAFKA_HEAP_OPTS" ]]; then
    sed -r -i 's/(export KAFKA_HEAP_OPTS)="(.*)"/\1="'"$KAFKA_HEAP_OPTS"'"/g' "$KAFKA_HOME/bin/kafka-server-start.sh"
    unset KAFKA_HEAP_OPTS
fi

if [[ -n "$HOSTNAME_COMMAND" ]]; then
    HOSTNAME_VALUE=$(eval "$HOSTNAME_COMMAND")

    # Replace any occurences of _{HOSTNAME_COMMAND} with the value
    IFS=$'\n'
    for VAR in $(env); do
        if [[ $VAR =~ ^KAFKA_ && "$VAR" =~ "_{HOSTNAME_COMMAND}" ]]; then
            eval "export ${VAR//_\{HOSTNAME_COMMAND\}/$HOSTNAME_VALUE}"
        fi
    done
    IFS=$ORIG_IFS
fi

if [[ -n "$PORT_COMMAND" ]]; then
    PORT_VALUE=$(eval "$PORT_COMMAND")

    # Replace any occurences of _{PORT_COMMAND} with the value
    IFS=$'\n'
    for VAR in $(env); do
        if [[ $VAR =~ ^KAFKA_ && "$VAR" =~ "_{PORT_COMMAND}" ]]; then
	    eval "export ${VAR//_\{PORT_COMMAND\}/$PORT_VALUE}"
        fi
    done
    IFS=$ORIG_IFS
fi

if [[ -n "$RACK_COMMAND" && -z "$KAFKA_BROKER_RACK" ]]; then
    KAFKA_BROKER_RACK=$(eval "$RACK_COMMAND")
    export KAFKA_BROKER_RACK
fi

# Try and configure minimal settings or exit with error if there isn't enough information
if [[ -z "$KAFKA_ADVERTISED_HOST_NAME$KAFKA_LISTENERS" ]]; then
    if [[ -n "$KAFKA_ADVERTISED_LISTENERS" ]]; then
        echo "ERROR: Missing environment variable KAFKA_LISTENERS. Must be specified when using KAFKA_ADVERTISED_LISTENERS"
        exit 1
    elif [[ -z "$HOSTNAME_VALUE" ]]; then
        echo "ERROR: No listener or advertised hostname configuration provided in environment."
        echo "       Please define KAFKA_LISTENERS / (deprecated) KAFKA_ADVERTISED_HOST_NAME"
        exit 1
    fi

    # Maintain existing behaviour
    # If HOSTNAME_COMMAND is provided, set that to the advertised.host.name value if listeners are not defined.
    export KAFKA_ADVERTISED_HOST_NAME="$HOSTNAME_VALUE"
fi

if [[ -z "$KAFKA_LISTENER_SECURITY_PROTOCOL_MAP" ]]; then
    export KAFKA_LISTENER_SECURITY_PROTOCOL_MAP="$KAFKA_LISTENER_SECURITY_PROTOCOL_MAP"
fi

if [[ -z "$OFFSETS_TOPIC_REPLICATION_FACTOR" ]]; then
    export OFFSETS_TOPIC_REPLICATION_FACTOR=1
fi

# Concatenate the IP:PORT for ZooKeeper to allow setting a full connection
# string with multiple ZooKeeper hosts
# [ -z "$ZOOKEEPER_CONNECTION_STRING" ] && ZOOKEEPER_CONNECTION_STRING="${ZOOKEEPER_IP}:${ZOOKEEPER_PORT:-2181}"

cat ${KAFKA_HOME}/config/server.properties.template | sed \
  -e "s|{{KAFKA_LISTENERS}}|${KAFKA_LISTENERS}|g" \
  -e "s|{{KAFKA_ADVERTISED_LISTENERS}}|${KAFKA_ADVERTISED_LISTENERS}|g" \
  -e "s|{{KAFKA_LISTENER_SECURITY_PROTOCOL_MAP}}|${KAFKA_LISTENER_SECURITY_PROTOCOL_MAP}|g" \
  -e "s|{{KAFKA_INTER_BROKER_LISTENER_NAME}}|${KAFKA_INTER_BROKER_LISTENER_NAME}|g" \
  -e "s|{{KAFKA_AUTO_CREATE_TOPICS_ENABLE}}|${KAFKA_AUTO_CREATE_TOPICS_ENABLE:-true}|g" \
  -e "s|{{KAFKA_BROKER_ID}}|${KAFKA_BROKER_ID:-1}|g" \
  -e "s|{{KAFKA_DEFAULT_REPLICATION_FACTOR}}|${KAFKA_DEFAULT_REPLICATION_FACTOR:-1}|g" \
  -e "s|{{KAFKA_DELETE_TOPIC_ENABLE}}|${KAFKA_DELETE_TOPIC_ENABLE:-false}|g" \
  -e "s|{{KAFKA_GROUP_MAX_SESSION_TIMEOUT_MS}}|${KAFKA_GROUP_MAX_SESSION_TIMEOUT_MS:-300000}|g" \
  -e "s|{{KAFKA_INTER_BROKER_PROTOCOL_VERSION}}|${KAFKA_INTER_BROKER_PROTOCOL_VERSION:-$KAFKA_VERSION}|g" \
  -e "s|{{KAFKA_LOG_MESSAGE_FORMAT_VERSION}}|${KAFKA_LOG_MESSAGE_FORMAT_VERSION:-$KAFKA_VERSION}|g" \
  -e "s|{{KAFKA_LOG_RETENTION_HOURS}}|${KAFKA_LOG_RETENTION_HOURS:-168}|g" \
  -e "s|{{KAFKA_NUM_PARTITIONS}}|${KAFKA_NUM_PARTITIONS:-1}|g" \
  -e "s|{{KAFKA_ADVERTISED_PORT}}|${KAFKA_ADVERTISED_PORT:-9094}|g" \
  -e "s|{{KAFKA_PORT}}|${KAFKA_PORT:-9092}|g" \
  -e "s|{{KAFKA_ZOOKEEPER_CONNECTION}}|${KAFKA_ZOOKEEPER_CONNECT}|g" \
  -e "s|{{ZOOKEEPER_CONNECTION_TIMEOUT_MS}}|${ZOOKEEPER_CONNECTION_TIMEOUT_MS:-10000}|g" \
  -e "s|{{ZOOKEEPER_SESSION_TIMEOUT_MS}}|${ZOOKEEPER_SESSION_TIMEOUT_MS:-10000}|g" \
  -e "s|{{OFFSETS_TOPIC_REPLICATION_FACTOR}}|${OFFSETS_TOPIC_REPLICATION_FACTOR}|g" \
   > ${KAFKA_HOME}/config/server.properties

# Kafka's built-in start scripts set the first three system properties here, but
# we add two more to make remote JMX easier/possible to access in a Docker
# environment:
#
#   1. RMI port - pinning this makes the JVM use a stable one instead of
#      selecting random high ports each time it starts up.
#   2. RMI hostname - normally set automatically by heuristics that may have
#      hard-to-predict results across environments.
#
# These allow saner configuration for firewalls, EC2 security groups, Docker
# hosts running in a VM with Docker Machine, etc. See:
#
# https://issues.apache.org/jira/browse/CASSANDRA-7087
if [ -z $KAFKA_JMX_OPTS ]; then
    KAFKA_JMX_OPTS="-Dcom.sun.management.jmxremote=true"
    KAFKA_JMX_OPTS="$KAFKA_JMX_OPTS -Dcom.sun.management.jmxremote.authenticate=false"
    KAFKA_JMX_OPTS="$KAFKA_JMX_OPTS -Dcom.sun.management.jmxremote.ssl=false"
    KAFKA_JMX_OPTS="$KAFKA_JMX_OPTS -Dcom.sun.management.jmxremote.rmi.port=$JMX_PORT"
    KAFKA_JMX_OPTS="$KAFKA_JMX_OPTS -Djava.rmi.server.hostname=${JAVA_RMI_SERVER_HOSTNAME:-$KAFKA_ADVERTISED_HOST_NAME} "
    export KAFKA_JMX_OPTS
fi

echo "Starting kafka"
exec ${KAFKA_HOME}/bin/kafka-server-start.sh ${KAFKA_HOME}/config/server.properties
