FROM sumglobal/rpi-openjdk:8-jdk-azul

# RUN [ "cross-build-start" ]

ARG kafka_version=2.3.0
ARG scala_version=2.12

LABEL maintainer="Charles Walker <cwalker@sumglobal.com>, Chip Dickson <cdickson@sumglobal.com>"

RUN apt-get update \
    && apt-get install bash docker unzip wget curl jq coreutils net-tools

ENV KAFKA_VERSION=$kafka_version SCALA_VERSION=$scala_version
ADD download-kafka.sh /tmp/download-kafka.sh
RUN chmod a+x /tmp/download-kafka.sh && sync && /tmp/download-kafka.sh && tar xfz /tmp/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz -C /opt && rm /tmp/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz && ln -s /opt/kafka_${SCALA_VERSION}-${KAFKA_VERSION} /opt/kafka

VOLUME ["/kafka"]

ENV KAFKA_HOME /opt/kafka_${SCALA_VERSION}-${KAFKA_VERSION}
# default to auto assign
ENV KAFKA_BROKER_ID=-1
ENV PATH ${PATH}:${KAFKA_HOME}/bin
ENV ZOOKEEPER_IP zookeeper
ENV KAFKA_ADVERTISED_PORT 9094
ENV KAFKA_PORT 9092
ADD config/server.properties.template ${KAFKA_HOME}/config/server.properties.template
# ADD start.sh /usr/bin/start.sh
ADD pi_start.sh /usr/bin/pi_start.sh
ADD broker-list.sh /usr/bin/broker-list.sh
ADD create-topics.sh /usr/bin/create-topics.sh
# The scripts need to have executable permission
RUN chmod a+x /usr/bin/pi_start.sh && \
    chmod a+x /usr/bin/broker-list.sh && \
    chmod a+x /usr/bin/create-topics.sh

# tone down the JVM to run better on RASPI
ENV KAFKA_HEAP_OPTS -Xmx256M\ -Xms256M
# Zulu embedded doesn't support the G1 compiler and other options set by default - These are a bit more reasonable
ENV KAFKA_JVM_PERFORMANCE_OPTS -server\ -XX:+DisableExplicitGC\ -Djava.awt.headless=true
# Use "exec" form so that it runs as PID 1 (useful for graceful shutdown)
CMD ["pi_start.sh"]

# RUN [ "cross-build-end" ]  

