# Ingress Routing Mesh
#### Ingress controller (based on NGINX) with automated configuration and ssl certificate creation (based on Let's Encrypt)
 ----

 
 #### TODO:
 - Good explanation of container labels
 - Install instructions
 
 ___
 ##### All containers (services) intended to be accessible from the Internet must be registered with the following labels:

 routing.mesh.domains: string <A comma separated list of domain names (use "//" (double slash) to start a new group of domain names for which a separate certificate will be generated)>
 
 routing.mesh.port: integer (optional) <The port of the backend service container (defaults to port 80)>
 
 routing.mesh.ssl: string *|redirect (optional) <Set to generate a Let's encrypt certificate for secure connection (If set to 'redirect' additionally all http request will be redirected to https)>
 
 routing.mesh.ssl.hsts: string off|'curtom declaration' (optional) <set to off to deactivate HSTS or set your own HSTS declaration>
 
 routing.mesh.ssl.policy: string (optional) <one of the following ssl configuration policies are selectable 'Mozilla-Modern', 'Mozilla-Intermediate', 'Mozilla-Old', 'AWS-TLS-1-2-2017-01', 'AWS-TLS-1-1-2017-01', 'AWS-2016-08', default is 'Mozilla-Intermediate'>
 
 routing.mesh.cert.name: string (optional) <The name of the certificate can be set, otherwise the first domainname will be used (will be ignored with multiple groups of domain names)>
 
 routing.mesh.redirect: string (optional) <A comma separated list of domain names which will be redirect to another location ("from1,from2>to1//from3>to2", If 'ssl' is activated, there will also create a Let's Encrypt certificate be created and it will redirect to the https location)>


 ##### The controller have the following environment variables:

 ROUTING_NETWORK: string <The name of the network setup as the internal routing network>
 
 LETSENCRYPT_EMAIL: string <A valid email address for the Let's Encrypt account>
 
 LETSENCRYPT_KEYSIZE: integer (optional) <Set the RSA key size, default is 2048>
 
 LETSENCRYPT_TEST: string * (optional) <Ise the  Let's Encrypt staging test server>
 
 LETSENCRYPT_VERBOSE: string * (optional) <Will output verbose messages from Let's Encrypt>
 
 DHPARAM_KEYSIZE: integer (optional) <This will generate a new Diffie-Hellman parameter with the spezified key size, e.g. 2048 or 4096 Bit (May take some time, especially with 4096 Bit, to be generated, but ssl can be used already during generation)>
 
