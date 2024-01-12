FROM registry.access.redhat.com/ubi8/openjdk-11:latest as builder
WORKDIR /build
# Download and cache dependencies beforehand
COPY --chown=jboss:jboss pom.xml /build
#ENV http_proxy=http://172.17.0.1:3128
#RUN cd /build/modresorts && mvn dependency:go-offline -B

COPY --chown=jboss:jboss . /build/modresorts
#COPY --chown=jboss:jboss m2 /home/jboss

RUN cd /build/modresorts && mvn clean package

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

RUN mkdir -p /opt/ibm/wlp/usr/shared/config/lib/global
COPY --chown=1001:0 --from=build-stage /config/ /config/
COPY --chown=1001:0 --from=build-stage /sharedlibs/ /opt/ibm/wlp/usr/shared/config/lib/global
COPY --chown=1001:0 --from=build-stage /licenses/wlp-core-license.jar /tmp
# This script will add the requested XML snippets to enable Liberty features and grow image to be fit-for-purpose using featureUtility.
# Only available in 'kernel-slim'. The 'full' tag already includes all features for convenience.
ENV VERBOSE=true

RUN features.sh
# Add interim fixes (optional)
# COPY --chown=1001:0  interim-fixes /opt/ibm/wlp/fixes/

# This script will add the requested server configurations, apply any interim fixes and populate caches to optimize runtime

RUN configure.sh 

# Upgrade to production license 
RUN java -jar /tmp/wlp-core-license.jar --acceptLicense /opt/ibm/wlp && rm /tmp/wlp-core-license.jar

