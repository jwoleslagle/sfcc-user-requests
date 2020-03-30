FROM node:10.19.0-alpine3.11
LABEL maintainer "Jeff Woleslagle jeffrey.woleslagle@hbc.com"
#Install git
RUN apk --update add git && \
    rm -rf /var/lib/apt/lists/* && \
    rm /var/cache/apk/* && \
    apk add bash && \
    apk add jq && \
    apk add sed
RUN git config --global url."https://5c312e9a788e15a6946ad401d0c0d4c4121fe423:@github.com/".insteadOf "https://github.com/"   && \
    git clone https://github.com/saksdirect/sfcc-ci.git/ && \
    cd sfcc-ci && \
    npm install -g
RUN apk add --update \
    python \
    python-dev \
    py-pip \
    build-base \
    && pip install awscli==1.16.310 --upgrade \
    && apk --purge -v del py-pip \
    && rm -rf /var/cache/apk/*
COPY test.sh /root/integrationTest.sh 
RUN chmod +x /root/integrationTest.sh
COPY bulkProvision.sh /root/bulkProvision.sh 
RUN chmod +x /root/bulkProvision.sh 