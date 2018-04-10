#!/bin/bash 

# check needed environment vars
export ROUTING_NETWORK=${ROUTING_NETWORK:?"The name of the routing network must be set!"}
export LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL:?"There must be an email adress!"}

if [ ! -S /var/run/docker.sock ]
then 
	echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] There must be a bind to '/var/run/docker.sock' (-v /var/run/docker.sock:/var/run/docker.sock)!!" >> /dev/stderr
	exit
fi

# run the certificate renewal in the background
/renewal.sh &

# (re)create start configuration
echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] Generating initial configuration .."
/configure.sh

# create a Diffie-Hellman parameter in the background
if [ -n "${DHPARAM_KEYSIZE}" ]
then
	/dhparam.sh &
fi

sleep 2s

# wait for connects and disconnects in the routing network
echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] Watching for changes in the '${ROUTING_NETWORK}' network .."

runtime=$(date +%s)

docker events --filter "network=${ROUTING_NETWORK}" --filter "event=connect" --filter "event=disconnect" | while read event
do
	eventtime=$(date -d "$(echo $event | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}")" -D "%Y-%m-%dT%H:%M:%S" +%s)
	
	# (re)create new configuration only once per minute
	if [ $eventtime -ge $runtime ]
	then
		echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] Reconfiguration triggered .."
		sleep 20s
		runtime=$(date +%s)
		/configure.sh
		echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] Watching for changes in the '${ROUTING_NETWORK}' network .."
	fi
done
