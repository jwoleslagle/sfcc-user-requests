# Based on https://gist.github.com/miguelmota/c13bd2f5cc5493c82689c40117846571
# This Makefile tags the image with the commit ID using the double tagging method. It's clunky, but it works.

# Requirements: 
# 1) Docker must be running
# 2) CHANGE ALL <ENDPOINT> REFERENCES to what you created in the target AWS directory
# 3) A named profile "serverlessDeploy" must exist with access key / id with rights to push to ECR in your AWS config file

default: all

# Login to AWS registry
docker/login:
	export AWS_PROFILE="serverlessDeploy" && aws ecr get-login-password | docker login --username AWS --password-stdin <ENDPOINT>

# Build docker target
docker/build:
	docker build -f Dockerfile -t sfcc-requests .

# Tag docker image
docker/tag:
	$(eval REV=$(shell git rev-parse HEAD | cut -c1-7))
	docker tag sfcc-requests:latest <ENDPOINT>:latest
	docker tag sfcc-requests:latest <ENDPOINT>:$(REV)

# Push to registry
docker/push:
	$(eval REV=$(shell git rev-parse HEAD | cut -c1-7))
	docker push <ENDPOINT>:latest
	docker push <ENDPOINT>:$(REV)

# Build docker image and push to AWS registry
all: docker/login docker/build docker/tag docker/push 