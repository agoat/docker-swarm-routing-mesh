#!/bin/bash 

# force all controllers to reload the configuration via HUP signal 
controllers=$(docker container ls --filter "Label=routing.mesh.controller" -q)

if [ -n "$controllers" ]
then
	reload=$(docker kill -s HUP ${controllers})
fi
