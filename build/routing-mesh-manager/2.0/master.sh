#!/bin/bash

while true
do
  if [[ -f "${FILES_PATH}master.lock" && ${NODE_ID} != $(< "${FILES_PATH}master.lock") ]]
  then
    if [[ $(find "${FILES_PATH}master.lock" -mmin +3) ]]
    then
      rm -f "${FILES_PATH}master.lock"
    fi
    if [[ ! $SLAVE ]]
    then
      echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] Start working as slave .."
      SLAVE=true
    fi
    sleep 5m

  else
    echo ${NODE_ID} > "${FILES_PATH}master.lock"
    echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] Start working as master .."

    sleep 1s

    # run the certificate renewal in the background
    /scripts/renewal.sh &

    # create a Diffie-Hellman parameter in the background
    if [ -n "${DHPARAM_KEYSIZE}" ]
    then
      /scripts/dhparam.sh &
    fi

    sleep 2s
    
    # (re)create start configuration
    echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] Generating initial configuration .."
    /scripts/generate.sh
    OLD_FILES_CHECKSUM=$( ls -l ${FILES_PATH}node.*.list 2>/dev/null | md5sum | awk '{ print $1 }')

    # watching for changed list files
    echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] Watching for changes in collections .."

    while true
    do
       # check if configuration files changed (md5sum)
      NEW_FILES_CHECKSUM=$( ls -l ${FILES_PATH}node.*.list 2>/dev/null | md5sum | awk '{ print $1 }')

      if [[ ${NEW_FILES_CHECKSUM} != ${OLD_FILES_CHECKSUM} ]]
      then
        echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] Changes in collection files detected .."

        OLD_FILES_CHECKSUM=$NEW_FILES_CHECKSUM
        /scripts/generate.sh
        echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] .. configuration updated"
      fi
      echo ${NODE_ID} > "${FILES_PATH}master.lock"
      sleep 10s
    done
  fi
done
