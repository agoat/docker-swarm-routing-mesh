#!/bin/bash

sleep 2s

OLD_FILES_CHECKSUM=$( ls -l ${FILES_PATH}*.conf 2>/dev/null | md5sum | awk '{ print $1 }')
/scripts/reload.sh

echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] Watching for changes in configuration files .."
while true
do
  # check if configuration files changed (md5sum)
  NEW_FILES_CHECKSUM=$( ls -l ${FILES_PATH}*.conf 2>/dev/null | md5sum | awk '{ print $1 }')

  if [[ ${NEW_FILES_CHECKSUM} != ${OLD_FILES_CHECKSUM} ]]
  then
    echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] Changes in configuration files detected .."

    OLD_FILES_CHECKSUM=${NEW_FILES_CHECKSUM}
    /scripts/reload.sh
    echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] .. new configuration applied"

  fi
  sleep 10s
done
