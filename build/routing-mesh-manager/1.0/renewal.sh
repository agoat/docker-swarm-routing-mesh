#!/bin/bash 

if [ -z "$LETSENCRYPT_VERBOSE" ]; then QUIET=" --quiet"; fi

while sleep 12h
do
	echo "Let's Encrypt certificate renewal triggered .."
	certbot renew${QUIET} --allow-subset-of-names --post-hook "/reload.sh"
done
