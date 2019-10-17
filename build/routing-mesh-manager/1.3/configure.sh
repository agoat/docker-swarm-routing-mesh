#!/bin/bash

# set default vars
RSA_KEY_SIZE=${LETSENCRYPT_KEYSIZE:+" --rsa-key-size $LETSENCRYPT_KEYSIZE"}
TEST_CERT=${LETSENCRYPT_TEST:+" --test-cert"}
if [ -z "$LETSENCRYPT_VERBOSE" ]; then QUIET=" --quiet"; fi

# test if nginx configuration folder is mount
if [ ! -d "/etc/nginx/conf.d" ]
then 
	echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] A volume with the controller configuration (shared with the controller container) have to be declared ' (-v config:/etc/nginx/conf.d)!!" >> /dev/stderr
	exit
fi

# remove old conf files
rm -rf /etc/nginx/conf.d/*

declare -A servicelist
declare -A portlist
declare -A ssllist
declare -A hstslist
declare -A policylist
declare -A certnamelist
declare -A counterlist
declare -A redirectlist


# Build a configuration array for every parameter per domaingroup with the service or container name from containers connected to the routing network
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

# Generate a configuration file with a nginx server block for each service/container
echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] .. creating configuration"
for domains in ${!servicelist[@]}
do
	service=${servicelist[$domains]}
	port=${portlist[$domains]:-80}
	ssl=${ssllist[$domains]}
	hsts=${hstslist[$domains]}
	policy=${policylist[$domains]:-"Mozilla-Intermediate"}
	certname=${certnamelist[$domains]}
	counter=${counterlist[$domains]}
	redirect=${redirectlist[$domains]}
	
	CONFIG_FILE=/etc/nginx/conf.d/${service}.${counter}.conf

	echo "[$(date '+%d/%b/%Y:%H:%M:%S %z')] .. writing configuration for service/container '${service}' with domains: $domains"
	
	echo "server {" > ${CONFIG_FILE}
	echo "  listen 80;" >> ${CONFIG_FILE}
	echo "  server_name ${domains//,/ };" >> ${CONFIG_FILE}

	echo "  location ^~ /.well-known/acme-challenge/ {" >> ${CONFIG_FILE}
	echo "    default_type "text/plain";" >> ${CONFIG_FILE}
	echo "    root /var/lib/letsencrypt;" >> ${CONFIG_FILE}
	echo "  }"  >> ${CONFIG_FILE}

	if [ -n "$redirect" ]
	then
		if [ "$(c=${redirect//[^\/]}; echo ${#c})" = "0" ]
		then
			echo "  location / {" >> ${CONFIG_FILE}
			echo "    return 301 http://${redirect}\$request_uri;" >> ${CONFIG_FILE}
			echo "  }" >> ${CONFIG_FILE}
		else
			echo "  location / {" >> ${CONFIG_FILE}
			echo "    return 301 http://${redirect};" >> ${CONFIG_FILE}
			echo "  }" >> ${CONFIG_FILE}
		fi
	elif [ "$ssl" = "redirect" ]
	then
		echo "  location / {" >> ${CONFIG_FILE}
		echo "    return 301 https://\$host\$request_uri;" >> ${CONFIG_FILE}
		echo "  }" >> ${CONFIG_FILE}
	else
		echo "  location / {" >> ${CONFIG_FILE}
		echo "    proxy_pass http://${service}:${port};" >> ${CONFIG_FILE}
		echo "    proxy_pass_header Server;" >> ${CONFIG_FILE}
		echo "    proxy_set_header HOST \$host;" >> ${CONFIG_FILE}
		echo "    proxy_set_header X-Forwarded-Proto \$scheme;" >> ${CONFIG_FILE}
		echo "    proxy_set_header X-Real-IP \$remote_addr;" >> ${CONFIG_FILE}
		echo "    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;" >> ${CONFIG_FILE}
		echo "    proxy_http_version 1.1;" >> ${CONFIG_FILE}
		echo "    proxy_buffering off;" >> ${CONFIG_FILE}
		echo "    proxy_request_buffering off;" >> ${CONFIG_FILE}
		echo "    proxy_connect_timeout 30s;" >> ${CONFIG_FILE}
		echo "    proxy_read_timeout 120s;" >> ${CONFIG_FILE}
		echo "    client_max_body_size 0;" >> ${CONFIG_FILE}
		echo "  }" >> ${CONFIG_FILE}
	fi
	
	echo "}" >> ${CONFIG_FILE}
		
	if [ -n "$ssl" ]
	then
		echo -n "[$(date '+%d/%b/%Y:%H:%M:%S %z')]      preparing Let's Encrypt certificate ..."
		
		if [ -z "$certname" ]
		then
			certname=$(echo $domains | cut -d, -f1)
		fi
		
		certbot certonly${TEST_CERT}${RSA_KEY_SIZE}${QUIET} --webroot -w /var/lib/letsencrypt --cert-name ${certname} --domains ${domains} --keep --renew-with-new-domains --agree-tos --email ${LETSENCRYPT_EMAIL} --no-eff-email

		if [ $? -eq 0 ]
		then
			echo "server {" >> ${CONFIG_FILE}
			echo "  listen 443 ssl http2;" >> ${CONFIG_FILE}
			echo "  server_name ${domains//,/ };" >> ${CONFIG_FILE}

			echo "  ssl_certificate /etc/letsencrypt/live/${certname}/fullchain.pem;" >> ${CONFIG_FILE}
			echo "  ssl_certificate_key /etc/letsencrypt/live/${certname}/privkey.pem;" >> ${CONFIG_FILE}

			
			if [ "$policy" = "Mozilla-Modern" ]
			then
				echo "  ssl_protocols TLSv1.2;" >> ${CONFIG_FILE}
				echo "  ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256';" >> ${CONFIG_FILE}
			
			elif [ "$policy" = "Mozilla-Intermediate" ]
			then
				echo "  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;" >> ${CONFIG_FILE}
				echo "  ssl_ciphers 'ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:!DSS';" >> ${CONFIG_FILE}
			
			elif [ "$policy" = "Mozilla-Old" ]
			then
				echo "  ssl_protocols SSLv3 TLSv1 TLSv1.1 TLSv1.2;" >> ${CONFIG_FILE}
				echo "  ssl_ciphers 'ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:ECDHE-RSA-DES-CBC3-SHA:ECDHE-ECDSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:DES-CBC3-SHA:HIGH:SEED:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!RSAPSK:!aDH:!aECDH:!EDH-DSS-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA:!SRP';" >> ${CONFIG_FILE}
			
			elif [ "$policy" = "AWS-TLS-1-2-2017-01" ]
			then
				echo "  ssl_protocols TLSv1.2;" >> ${CONFIG_FILE}
				echo "  ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:AES128-GCM-SHA256:AES128-SHA256:AES256-GCM-SHA384:AES256-SHA256';" >> ${CONFIG_FILE}
			
			elif [ "$policy" = "AWS-TLS-1-1-2017-01" ]
			then
				echo "  ssl_protocols TLSv1.1 TLSv1.2;" >> ${CONFIG_FILE}
				echo "  ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:AES128-GCM-SHA256:AES128-SHA256:AES128-SHA:AES256-GCM-SHA384:AES256-SHA256:AES256-SHA';" >> ${CONFIG_FILE}
			
			elif [ "$policy" = "AWS-2016-08" ]
			then
				echo "  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;" >> ${CONFIG_FILE}
				echo "  ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:AES128-GCM-SHA256:AES128-SHA256:AES128-SHA:AES256-GCM-SHA384:AES256-SHA256:AES256-SHA';" >> ${CONFIG_FILE}
			fi
			
			echo "  ssl_prefer_server_ciphers on;" >> ${CONFIG_FILE}
			echo "  ssl_session_timeout 5m;" >> ${CONFIG_FILE}
			echo "  ssl_session_cache shared:SSL:50m;" >> ${CONFIG_FILE}
			echo "  ssl_session_tickets off;" >> ${CONFIG_FILE}

			dhparamfile=$(find /etc/letsencrypt -name dhparam_* | sort | tail -1)
			if [ -n $dhparamfile ]
			then
				echo "  ssl_dhparam ${dhparamfile};" >> ${CONFIG_FILE}
			fi
			
			if [ -n "$hsts" ]
			then
				if [ "$hsts" != "off" ]
				then
					echo "  add_header Strict-Transport-Security \"${hsts}\";" >> ${CONFIG_FILE}
				fi
			else
				echo "  add_header Strict-Transport-Security \"max-age=15768000\";" >> ${CONFIG_FILE}
			fi
				
			echo "  ssl_stapling on;" >> ${CONFIG_FILE}
			echo "  ssl_stapling_verify on;" >> ${CONFIG_FILE}
			echo "  ssl_trusted_certificate /etc/letsencrypt/live/${certname}/fullchain.pem;" >> ${CONFIG_FILE}

			echo "  resolver 8.8.8.8 8.8.4.4 valid=300s;" >> ${CONFIG_FILE}
			echo "  resolver_timeout 5s;" >> ${CONFIG_FILE}

			if [ -n "$redirect" ]
			then
				if [ "$(c=${redirect//[^\/]}; echo ${#c})" = "0" ]
				then
					echo "  location / {" >> ${CONFIG_FILE}
					echo "    return 301 https://${redirect}\$request_uri;" >> ${CONFIG_FILE}
					echo "  }" >> ${CONFIG_FILE}
				else
					echo "  location / {" >> ${CONFIG_FILE}
					echo "    return 301 https://${redirect};" >> ${CONFIG_FILE}
					echo "  }" >> ${CONFIG_FILE}
				fi
			else
				echo "  location / {" >> ${CONFIG_FILE}
				echo "    proxy_pass http://${service}:${port};" >> ${CONFIG_FILE}
				echo "    proxy_pass_header Server;" >> ${CONFIG_FILE}
				echo "    proxy_http_version 1.1;" >> ${CONFIG_FILE}
				echo "    proxy_buffering off;" >> ${CONFIG_FILE}
				echo "    proxy_request_buffering off;" >> ${CONFIG_FILE}
		        echo "    proxy_connect_timeout 120s;" >> ${CONFIG_FILE}
		        echo "    proxy_send_timeout 120s;" >> ${CONFIG_FILE}
		        echo "    proxy_read_timeout 120s;" >> ${CONFIG_FILE}
				echo "    client_max_body_size 0;" >> ${CONFIG_FILE}
				echo "    proxy_set_header Host \$host;" >> ${CONFIG_FILE}
				echo "    proxy_set_header Upgrade \$http_upgrade;" >> ${CONFIG_FILE}
				echo "    proxy_set_header Connection \$connection_upgrade;" >> ${CONFIG_FILE}
				echo "    proxy_set_header X-Real-IP \$remote_addr;" >> ${CONFIG_FILE}
				echo "    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;" >> ${CONFIG_FILE}
				echo "    proxy_set_header X-Forwarded-Proto \$scheme;" >> ${CONFIG_FILE}
				echo "    proxy_set_header X-Forwarded-Ssl on;" >> ${CONFIG_FILE}
				echo "    proxy_set_header X-Forwarded-Port \$server_port;" >> ${CONFIG_FILE}
				echo "    proxy_set_header Proxy '';" >> ${CONFIG_FILE}
				echo "  }" >> ${CONFIG_FILE}
			fi
			
			echo "}" >> ${CONFIG_FILE}
			
			echo " ready."
		else
			echo " FAILED!!"
		fi
	fi
done

# Trigger nginx to reload the configuration
/reload.sh


# TODO: check if an expired cert is not in use anymore and delete it
