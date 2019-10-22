# Build and deploy the ingress routing mesh stack

# Build the images
docker build -t agoat/routing-mesh-controller:1.3 ./build/routing-mesh-controller/1.3
docker build -t agoat/routing-mesh-manager:2.0.0 ./build/routing-mesh-manager/2.0

# Deploy the stack
docker stack deploy -c docker-stack-deploy.yml RoutingMesh
