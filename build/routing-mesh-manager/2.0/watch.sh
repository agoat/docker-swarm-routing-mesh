#!/bin/bash

sleep 5s

# Initial run
echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] Generating initial collection .."
/scripts/collect.sh

# Wait for connects and disconnects in the routing network
echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] Watching for changes in the '${ROUTING_NETWORK}' network .."

lastruntime=$(date +%s)

docker events --filter "network=${ROUTING_NETWORK}" --filter "event=connect" --filter "event=disconnect" --format "{{.Time}}"| while read event
do
	eventtime=$(echo $event | awk '{print $1;}')

	# (re)create new configuration only once per minute
	if [ $eventtime -ge $lastruntime ]
	then
		echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] Changes in the '${ROUTING_NETWORK}' network detected .."
		echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] .. waiting for containers to settle down"
		sleep 10s
		lastruntime=$(date +%s)
		/scripts/collect.sh
    echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] .. collection updated"
	fi
done