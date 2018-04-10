#!/bin/bash 

# force all controllers to reload the configuration via HUP signal 
controllers=$(docker container ls --filter "Label=routing.mesh.controller" -q)

if [ -n "$controllers" ]
then
	echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] Applying new configuration .."
	reload=$(docker kill -s HUP ${controllers})
fi
