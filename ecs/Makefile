# Based on https://gist.github.com/miguelmota/c13bd2f5cc5493c82689c40117846571

# Requirements: 
# 1) Docker must be running
# 2) This is set up to push to the ECR in HBC-Infrastructure, if pushing elsewhere change all ecr references
# 3) A named profile "serverlessDeployHBCInfrastructure" must exist with access key / id with rights to push to ECR in your AWS config file

default: all

# Login to AWS registry
docker/login:
	export AWS_PROFILE="serverlessDeployHBCInfrastructure" && export AWS_REGION=us-east-1 && aws ecr get-login-password | docker login --username AWS --password-stdin 170674482192.dkr.ecr.us-east-1.amazonaws.com/sfcc-requests

# Build docker target
docker/build:
	docker build -f Dockerfile -t sfcc-requests .

# Tag docker image
docker/tag:
	$(eval REV=$(shell git rev-parse HEAD | cut -c1-7))
	docker tag sfcc-requests:latest 170674482192.dkr.ecr.us-east-1.amazonaws.com/sfcc-requests:latest
	docker tag sfcc-requests:latest 170674482192.dkr.ecr.us-east-1.amazonaws.com/sfcc-requests:$(REV)

# Push to registry
docker/push:
	$(eval REV=$(shell git rev-parse HEAD | cut -c1-7))
	docker push 170674482192.dkr.ecr.us-east-1.amazonaws.com/sfcc-requests:latest
	docker push 170674482192.dkr.ecr.us-east-1.amazonaws.com/sfcc-requests:$(REV)

# Build docker image and push to AWS registry
all: docker/login docker/build docker/tag docker/push 