#!/bin/bash 

if [ -z "$LETSENCRYPT_VERBOSE" ]; then QUIET=" --quiet"; fi

while sleep 12h
do
	echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] Let's Encrypt certificate renewal triggered .."
	certbot renew${QUIET} --allow-subset-of-names --post-hook "/scripts/reload.sh"
done
