#!/bin/bash

if [ -z "$SERVERLESSBENCH_HOME" ]; then
    echo "$0: ERROR: SERVERLESSBENCH_HOME environment variable not set"
    exit
fi

source $SERVERLESSBENCH_HOME/local.env

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
SRC_DIR=$SCRIPTS_DIR/../src

echo "1. building smarthome device images"
if [[ ! $(docker images | grep smartdevice) ]]; then
    docker build -t smartdevice $SRC_DIR/smarthome/device
fi

echo "2. running smarthome device containers"
if [[ ! $(docker ps | grep smartdevice) ]]; then
    docker run -p $ALEXA_SMARTHOME_PORT_DOOR:8080 -e DEVICE_NAME=door -d --rm --name door smartdevice
    docker run -p $ALEXA_SMARTHOME_PORT_LIGHT:8080 -e DEVICE_NAME=light -d --rm --name light smartdevice
    docker run -p $ALEXA_SMARTHOME_PORT_TV:8080 -e DEVICE_NAME=tv -d --rm --name tv smartdevice
    docker run -p $ALEXA_SMARTHOME_PORT_AIR_CONDITIONING:8080 -e DEVICE_NAME=air-conditioning -d --rm --name air-conditioning smartdevice
    docker run -p $ALEXA_SMARTHOME_PORT_PLUG:8080 -e DEVICE_NAME=plug -d --rm --name plug smartdevice
fi

echo "3. creating reminder database..."
couchdb_url=http://$COUCHDB_USERNAME:$COUCHDB_PASSWORD@$COUCHDB_IP:$COUCHDB_PORT
curl -X PUT $couchdb_url/$ALEXA_REMINDER_COUCHDB_DATABASE

echo "4. uploading functions to OpenWhisk..."
$SCRIPTS_DIR/action_create.sh
