# Generated by IBM TransformationAdvisor
# Thu Jan 13 20:19:27 UTC 2022


FROM adoptopenjdk/openjdk8-openj9 AS build-stage

RUN apt-get update && \
    apt-get install -y maven unzip

COPY . /project
WORKDIR /project

#RUN mvn -X initialize process-resources verify => to get dependencies from maven

RUN tar -xvzf m2.tgz -C /root
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
USER 0
#RUN dnf install -y procps-ng && dnf clean all
RUN dnf update -y && dnf install -y curl tar gzip jq  procps util-linux vim-minimal iputils net-tools
USER 1001
ENV IBM_JAVA_OPTIONS="-Xshareclasses:name=liberty,readonly,nonfatal,cacheDir=/home/default/.classCache/ -Dosgi.checkConfiguration=false -XX:+UseContainerSupport"

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
ENV VERBOSE=true
RUN configure.sh && mv  /output/.classCache /home/default/

Run echo apres : && echo /home/default/.classCache && ls -la /home/default/.classCache
# Upgrade to production license 
RUN java -jar /tmp/wlp-core-license.jar --acceptLicense /opt/ibm/wlp && rm /tmp/wlp-core-license.jar

