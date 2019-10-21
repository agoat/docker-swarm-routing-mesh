#!/bin/bash 
trap 'kill $(jobs -p)' EXIT

export ROUTING_NETWORK=${ROUTING_NETWORK:?"The name of the routing network must be set!"}
export LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL:?"There must be an email adress!"}
export DHPARAM_KEYSIZE=${DHPARAM_KEYSIZE:-1024}

export FILES_PATH="/etc/nginx/conf.d/"

export NODE_ID=${NODE_ID:-$(hostname)}

# Check environment
if [ ! -S /var/run/docker.sock ]
then
	echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] There must be a bind to '/var/run/docker.sock' (-v /var/run/docker.sock:/var/run/docker.sock)!!" >> /dev/stderr
	exit
fi

if [ ! -d "/etc/nginx/conf.d" ]
then
	echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] A volume with the controller configuration (shared with the controller container) have to be declared ' (-v config:/etc/nginx/conf.d)!!" >> /dev/stderr
	exit
fi

# if no master.lock set master.lock and start master task (dhparam key, wait for changes in lists and generate configuration)
/scripts/master.sh &
sleep 2s

# Start watch task (wait for network events and write lists)
/scripts/watch.sh &
sleep 5s

# Start configuration task (wait for changes in configuration)
/scripts/configure.sh
