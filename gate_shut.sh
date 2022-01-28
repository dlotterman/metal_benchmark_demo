#!/bin/bash

USER_S3_BUCKET_NAME="packetbootstrap"
USER_S3_BUCKET_URL="https://s3.us-east-1.wasabisys.com"

aws s3 --quiet --endpoint-url=$USER_S3_BUCKET_URL rm --recursive s3://$USER_S3_BUCKET_NAME/
