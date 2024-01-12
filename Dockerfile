FROM registry.access.redhat.com/ubi8/openjdk-11:latest as builder
WORKDIR /build
ARG APP

#ENV http_proxy=http://172.17.0.1:3128
#RUN cd /build/$APP && mvn dependency:go-offline -B

COPY --chown=185:0 . /build/$APP

RUN echo $APP && cd /build/$APP && mvn -o clean package -Dmaven.repo.local=/build/$APP/m2/repository 
FROM icr.io/appcafe/websphere-liberty:kernel-java8-ibmjava-ubi
ARG APP
ARG TLS=true
#USER 0
#RUN dnf install -y procps-ng && dnf clean all
#RUN dnf update -y && dnf install -y curl tar gzip jq  procps util-linux vim-minimal iputils net-tools
USER 1001

COPY --from=builder --chown=1001:0  /build/$APP/target/*.*ar /config/apps/
COPY --from=builder --chown=1001:0  /build/$APP/src/main/liberty/config/ /config/
COPY --from=builder --chown=1001:0  /build/$APP/wlp-core-license.jar /tmp
RUN  echo 'SERVER_HOST=*' > /config/bootstrap.properties

RUN mkdir -p /opt/ibm/wlp/usr/shared/config/lib/global

COPY --chown=1001:0 --from=builder /build/$APP/src/main/liberty/lib/* /opt/ibm/wlp/usr/shared/config/lib/global

# This script will add the requested XML snippets to enable Liberty features and grow image to be fit-for-purpose using featureUtility.
# Only available in 'kernel-slim'. The 'full' tag already includes all features for convenience.
ENV VERBOSE=false

RUN features.sh
# Add interim fixes (optional)
# COPY --chown=1001:0  interim-fixes /opt/ibm/wlp/fixes/

# This script will add the requested server configurations, apply any interim fixes and populate caches to optimize runtime

RUN configure.sh 
# Upgrade to production license 
RUN java -jar /tmp/wlp-core-license.jar --acceptLicense /opt/ibm/wlp && rm /tmp/wlp-core-license.jar

