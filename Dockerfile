FROM sumglobal/rpi-openjdk:8-jdk-azul

RUN [ "cross-build-start" ]

ARG kafka_version=0.11.0.1
ARG scala_version=2.12

MAINTAINER Charles Walker <cwalker@sumglobal.com>

RUN apt-get update \
    && apt-get install bash docker unzip wget curl jq coreutils net-tools

ENV KAFKA_VERSION=$kafka_version SCALA_VERSION=$scala_version
ADD download-kafka.sh /tmp/download-kafka.sh
RUN chmod a+x /tmp/download-kafka.sh && sync && /tmp/download-kafka.sh && tar xfz /tmp/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz -C /opt && rm /tmp/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz && ln -s /opt/kafka_${SCALA_VERSION}-${KAFKA_VERSION} /opt/kafka

VOLUME ["/kafka"]

#ENV HOSTNAME_COMMAND "docker info | grep ^.*'Node Address:'| cut -d' ' -f 4"
ENV KAFKA_HOME /opt/kafka_${SCALA_VERSION}-${KAFKA_VERSION}
ENV PATH ${PATH}:${KAFKA_HOME}/bin
ENV ZOOKEEPER_IP zookeeper
#ENV KAFKA_LISTENER_SECURITY_PROTOCOL_MAP INSIDE:PLAINTEXT,OUTSIDE:PLAINTEXT,BROKER:PLAINTEXT
#ENV KAFKA_ADVERTISED_PROTOCOL_NAME OUTSIDE
#ENV KAFKA_PROTOCOL_NAME INSIDE
ENV KAFKA_ADVERTISED_PORT 9094
ENV KAFKA_PORT 9092
ADD config/server.properties.template ${KAFKA_HOME}/config/server.properties.template
ADD start.sh /usr/bin/start.sh
ADD broker-list.sh /usr/bin/broker-list.sh
ADD create-topics.sh /usr/bin/create-topics.sh
# The scripts need to have executable permission
RUN chmod a+x /usr/bin/start.sh && \
    chmod a+x /usr/bin/broker-list.sh && \
    chmod a+x /usr/bin/create-topics.sh
# Use "exec" form so that it runs as PID 1 (useful for graceful shutdown)
CMD ["start.sh"]

RUN [ "cross-build-end" ]  

