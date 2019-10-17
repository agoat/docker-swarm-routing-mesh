FROM alpine:3.9

LABEL maintainer="Arne Stappen <mehh@agoat.info>"

ENV DOCKER_VERSION 18.09.6
ENV DOCKER_RELEASE_CHANNEL stable

RUN apk add --no-cache \
    bash \
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
COPY manager.sh /manager.sh
COPY configure.sh /configure.sh
COPY reload.sh /reload.sh
COPY renewal.sh /renewal.sh
COPY dhparam.sh /dhparam.sh
RUN chmod u+x /manager.sh /configure.sh /reload.sh /renewal.sh /dhparam.sh

ENV INGRESS_ROUTING_MANAGER_VERSION 1.3.1

STOPSIGNAL SIGKILL

CMD ["/manager.sh"]
