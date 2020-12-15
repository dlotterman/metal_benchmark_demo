#!/bin/bash

aws s3 --quiet --endpoint-url=https://s3.us-east-1.wasabisys.com rm --recursive s3://packetbootstrap/
