#!/bin/bash

# S3 credentials not managed y script, assumes you can use `aws s3` tool with env variables set
# Requires 'aws cli' to be installed locally.

UUID=$(uuidgen)
CUSTOMER="Equinix Metal"
METAL_TOKEN="/home/USER/.secrets/metal_benchmark_demo"
SCRATCH_DIR="/tmp"
USER_S3_BUCKET_NAME="packetbootstrap" #Name of the bucket from your object provider
USER_S3_S3_ENDPOINT="https://s3.us-east-1.wasabisys.com" # S3 endpoint, Wasabi left for example
USER_S3_URL="https://packetbootstrap.s3.wasabisys.com" # FQDN of bucket

SCRIPT=`realpath $0`
SCRIPTPATH=`dirname $SCRIPT`

while getopts c:a:f: flag
	do
	    case "${flag}" in
	        c) CUSTOMER=${OPTARG};;
	        a) age=${OPTARG};;
	        f) fullname=${OPTARG};;
	    esac
	done


S3_URL="$USER_S3_URL/$UUID"
RAMDIR="/dev/shm/"

# important to exit hard so you know something broke rather then stays silent
set -e

# Clean up from previous runs

aws s3 --quiet --endpoint-url=$USER_S3_S3_ENDPOINT rm --recursive s3://$USER_S3_BUCKET_NAME/

aws s3 --quiet --endpoint-url=$USER_S3_S3_ENDPOINT cp $METAL_TOKEN s3://$USER_S3_BUCKET_NAME/$UUID/packet


cp "$SCRIPTPATH"/bench_spotter.sh "$SCRATCH_DIR"/$UUID"_bench_spotter.sh"
sed -i "s/EXAMPLE_CUSTOMER/$CUSTOMER/" "$SCRATCH_DIR"/$UUID"_bench_spotter.sh"

aws s3 --quiet --endpoint-url=$USER_S3_S3_ENDPOINT cp "$SCRATCH_DIR"/$UUID"_bench_spotter.sh" s3://$USER_S3_BUCKET_NAME/$UUID/bench_spotter.sh


echo "UUID: $UUID"
cat << EOF


#cloud-config
package_update: true
packages:
 - screen
 - sysbench
 - cockpit
 - iotop
 - nginx
 - apache2-utils
 - jq
runcmd:
 - [ curl, "$S3_URL/packet", -o, /dev/shm/packet ]
 - [ curl, "$S3_URL/bench_spotter.sh", -o, /dev/shm/bench_spotter.sh ]
 - [ chmod, 0755, /dev/shm/bench_spotter.sh ]
 - [ bash, /dev/shm/bench_spotter.sh ] 

EOF
