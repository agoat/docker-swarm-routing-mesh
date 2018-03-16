#!/bin/bash 

# generate Diffie-Hellman parameter
if [ ! -f /etc/letsencrypt/dhparam_${DHPARAM_KEYSIZE}.pem ]
then
	echo "Generation of Diffie-Hellman parameter with ${DHPARAM_KEYSIZE} Bits started .."
	openssl dhparam -out /etc/letsencrypt/dhparam_${DHPARAM_KEYSIZE}.pem ${DHPARAM_KEYSIZE}
	
	echo "Reconfiguration triggered .."
	/configure.sh

else
	echo "A Diffie-Hellman parameter with ${DHPARAM_KEYSIZE} Bits is already present .."
fi
