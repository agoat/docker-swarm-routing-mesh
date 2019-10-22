FROM alpine:3.10

LABEL maintainer="Arne Stappen <mehh@agoat.info>"

ENV DOCKER_VERSION 19.03.4
ENV DOCKER_RELEASE_CHANNEL stable

RUN apk add --no-cache \
    bash \
    util-linux \
    libressl \
	certbot

RUN apk add --no-cache --virtual .curl curl \
	&& curl -fSL https://download.docker.com/linux/static/$DOCKER_RELEASE_CHANNEL/x86_64/docker-$DOCKER_VERSION.tgz -o docker-cs.tgz \
	&& mkdir /usr/src \
	&& tar -zxC /usr/src -f docker-cs.tgz \
	&& cp /usr/src/docker/docker /usr/bin/ \
	&& rm -rf /usr/src \
	&& apk del .curl
	
#COPY cli.ini /etc/letsencrypt/cli.ini
COPY *.sh /scripts/
RUN chmod -R u+x /scripts

ENV INGRESS_ROUTING_MANAGER_VERSION 2.0

STOPSIGNAL SIGKILL

CMD ["/scripts/manager.sh"]
