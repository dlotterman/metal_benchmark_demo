#!/bin/bash


CUSTOMER="Equinix Metal"
#METAL_TOKEN="~/.secrets/metal"
METAL_TOKEN="/home/dlotterman/.secrets/metal"
SCRATCH_DIR="/tmp"

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

UUID=$(uuidgen)
BUCKET_URL="https://packetbootstrap.s3.wasabisys.com/$UUID"
RAMDIR="/dev/shm/"

# important to exit hard so you know something broke rather then stays silent
set -e

# Clean up from previous runs
aws s3 --quiet --endpoint-url=https://s3.us-east-1.wasabisys.com rm --recursive s3://packetbootstrap/
#aws s3 --endpoint-url=https://s3.us-east-1.wasabisys.com rm --recursive s3://packetbootstrap/

aws s3 --quiet --endpoint-url=https://s3.us-east-1.wasabisys.com cp $METAL_TOKEN s3://packetbootstrap/$UUID/packet
#aws s3 --endpoint-url=https://s3.us-east-1.wasabisys.com cp $METAL_TOKEN s3://packetbootstrap/$UUID/packet

cp "$SCRIPTPATH"/bench_spotter.sh "$SCRATCH_DIR"/$UUID"_bench_spotter.sh"
sed -i "s/EXAMPLE_CUSTOMER/$CUSTOMER/" "$SCRATCH_DIR"/$UUID"_bench_spotter.sh"

aws s3 --quiet --endpoint-url=https://s3.us-east-1.wasabisys.com cp "$SCRATCH_DIR"/$UUID"_bench_spotter.sh" s3://packetbootstrap/$UUID/bench_spotter.sh


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
runcmd:
 - [ curl, "$BUCKET_URL/packet", -o, /dev/shm/packet ]
 - [ curl, "$BUCKET_URL/bench_spotter.sh", -o, /dev/shm/bench_spotter.sh ]
 - [ chmod, 0755, /dev/shm/bench_spotter.sh ]
 - [ bash, /dev/shm/bench_spotter.sh ] 

EOF
