# Build and deploy the ingress routing mesh stack

# Let's build the images
docker build -t agoat/routing-mesh-controller:1.0.4 ./build/routing-mesh-controller/1.0
docker build -t agoat/routing-mesh-manager:1.0.4 ./build/routing-mesh-manager/1.0 

# Create network separately (as long as the docker cli is not setting the network.name properly)
docker network create -d overlay --attachable --label com.docker.stack.namespace=routingmesh routingmesh

# Deploy the stack
docker stack deploy -c docker-stack-deploy.yml irm
