#!/bin/bash 

# generate Diffie-Hellman parameter
if [ ! -f /etc/letsencrypt/dhparam_${DHPARAM_KEYSIZE}.pem ]
then
	echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] Generation of Diffie-Hellman parameter with ${DHPARAM_KEYSIZE} Bits started .."
	openssl dhparam -out /etc/letsencrypt/dhparam_${DHPARAM_KEYSIZE}.pem ${DHPARAM_KEYSIZE}
	
	echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] Reconfiguration triggered .."
	/scripts/configure.sh

else
	echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] A Diffie-Hellman parameter with ${DHPARAM_KEYSIZE} Bits is already present .."
fi
