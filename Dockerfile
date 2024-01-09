# Generated by IBM TransformationAdvisor
# Thu Jan 13 20:19:27 UTC 2022


FROM adoptopenjdk/openjdk8-openj9 AS build-stage

RUN apt-get update && \
    apt-get install -y maven unzip

COPY . /project
WORKDIR /project

#RUN mvn -X initialize process-resources verify => to get dependencies from maven
RUN mvn clean package	
#RUN mvn --version
RUN mvn --version

RUN mkdir -p /config/apps && \
    mkdir -p /sharedlibs && \
    mkdir -p /licenses && \
    cp ./src/main/liberty/config/server.xml /config && \
    cp ./target/*.*ar /config/apps/ && \
    cp ./wlp-core-license.jar /licenses && \
    if [ ! -z "$(ls ./src/main/liberty/lib)" ]; then \
        cp ./src/main/liberty/lib/* /sharedlibs; \
    fi

FROM icr.io/appcafe/websphere-liberty:kernel-java8-ibmjava-ubi

ARG TLS=true


RUN mkdir -p /opt/ibm/wlp/usr/shared/config/lib/global
COPY --chown=1001:0 --from=build-stage /config/ /config/
COPY --chown=1001:0 --from=build-stage /sharedlibs/ /opt/ibm/wlp/usr/shared/config/lib/global
COPY --chown=1001:0 --from=build-stage /licenses/wlp-core-license.jar /tmp
# This script will add the requested XML snippets to enable Liberty features and grow image to be fit-for-purpose using featureUtility.
# Only available in 'kernel-slim'. The 'full' tag already includes all features for convenience.

RUN features.sh
# Add interim fixes (optional)
# COPY --chown=1001:0  interim-fixes /opt/ibm/wlp/fixes/

# This script will add the requested server configurations, apply any interim fixes and populate caches to optimize runtime
RUN configure.sh

# Upgrade to production license 
RUN ls /tmp
RUN java -jar /tmp/wlp-core-license.jar --acceptLicense /opt/ibm/wlp 
RUN rm /tmp/wlp-core-license.jar

