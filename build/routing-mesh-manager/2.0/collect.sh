#!/bin/bash


declare -A servicelist
declare -A portlist
declare -A ssllist
declare -A hstslist
declare -A policylist
declare -A certnamelist
declare -A counterlist
declare -A redirectlist

# Collect data for all containers connected to the routing network
echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] .. fetching configuration"
for containername in $(docker network inspect ${ROUTING_NETWORK} -f '{{ range .Containers }}{{ .Name }} {{ end}}')
do
    if [[ ! ${containername} == "${ROUTING_NETWORK}-endpoint" ]]
    then
        _domains=$(docker inspect ${containername} -f '{{index .Config.Labels "routing.mesh.domains"}}')

        if [[ -n "$_domains" ]]
        then
            counter=0

            for domains in ${_domains//\/\//$'\n'}
            do
                if [[ -n "$domains" ]]
                then
                    servicename=$(docker inspect ${containername} -f '{{index .Config.Labels "com.docker.swarm.service.name"}}')

                    if [[ -n "$servicename" ]]
                    then
                        servicelist[$domains]="$servicename"
                    else
                        servicelist[$domains]="$containername"
                    fi

                    portlist[$domains]=$(docker inspect ${containername} -f '{{index .Config.Labels "routing.mesh.port"}}')
                    ssllist[$domains]=$(docker inspect ${containername} -f '{{index .Config.Labels "routing.mesh.ssl"}}')
                    hstslist[$domains]=$(docker inspect ${containername} -f '{{index .Config.Labels "routing.mesh.ssl.hsts"}}')
                    policylist[$domains]=$(docker inspect ${containername} -f '{{index .Config.Labels "routing.mesh.ssl.policy"}}')

                    if [[ "$(c=${_domains//[^\/\/]}; echo ${#c})" = "0" ]]
                    then
                        certnamelist[$domains]=$(docker inspect ${containername} -f '{{index .Config.Labels "routing.mesh.cert.name"}}')
                    fi

                    counterlist[$domains]=${counter}
                    counter=$((counter + 1))
                fi
            done

            _redirects=$(docker inspect ${containername} -f '{{index .Config.Labels "routing.mesh.redirects"}}')

            if [[ -n "$_redirects" ]]
            then
                for redirects in ${_redirects//\/\//$'\n'}
                do
                    if [[ -n "$redirects" ]]
                    then
                        domains=${redirects%>*}

                        servicename=$(docker inspect ${containername} -f '{{index .Config.Labels "com.docker.swarm.service.name"}}')

                        if [[ -n "$servicename" ]]
                        then
                            servicelist[$domains]="$servicename"
                        else
                            servicelist[$domains]="$containername"
                        fi

                        redirectlist[$domains]=${redirects#*>}
                        ssllist[$domains]=$(docker inspect ${containername} -f '{{index .Config.Labels "routing.mesh.ssl"}}')
                        hstslist[$domains]="off"
                        policylist[$domains]=$(docker inspect ${containername} -f '{{index .Config.Labels "routing.mesh.ssl.policy"}}')

                        counterlist[$domains]=${counter}
                        counter=$((counter + 1))
                    fi
                done
            fi
        fi
    fi
done

# Write collected data
rm -f /etc/nginx/conf.d/node.${NODE_ID}.list
for domain in ${!servicelist[@]}
do
  echo $domain:${servicelist[$domain]}:${portlist[$domain]:-80}:${redirectlist[$domain]}:${ssllist[$domain]}:${hstslist[$domain]}:${policylist[$domain]:-"Mozilla-Intermediate"}:${certnamelist[$domain]}:${counterlist[$domain]}: >>/etc/nginx/conf.d/node.${NODE_ID}.list
done
