# Build and deploy the ingress controller

# Let's build the images
docker build -t agoat/routingmesh-controller:1.0.3 ./build/routingmesh-controller/1.0.3 
docker build -t agoat/routingmesh-manager:1.0.3 ./build/routingmesh-manager/1.0.3 

# Create network separately (as long as the docker cli is not setting the network.name properly)
docker network create -d overlay --attachable --label com.docker.stack.namespace=routingmesh routingmesh

# Deploy the stack
docker stack deploy -c docker-stack-deploy.yml routingmesh
