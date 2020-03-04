FROM node:10.19.0-alpine3.11
LABEL maintainer "jeffrey.woleslagle@hbc.com"
#Install git
RUN apk --update add git && \
    rm -rf /var/lib/apt/lists/* && \
    rm /var/cache/apk/* && \
    apk add --no-cache bash && \
    apk add --no-cache jq
RUN git config --global url."https://957e6ec11be553a251ced7d287db66341775e35b:@github.com/".insteadOf "https://github.com/"   && \
    git clone https://github.com/saksdirect/sfcc-ci.git/ && \
    cd sfcc-ci && \
    npm install -g && \
    #DEBUG - look for "Authentication Succeeded" message
    #sfcc-ci client:auth 9ea5c0b3-3dad-4338-a762-c7d760ec7d88 hbc2020!
COPY . .EXPOSE 3000