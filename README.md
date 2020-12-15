### Equinix Metal Benchmark Demo ###

This horrendous code is enables the Equinxi Metal bechmark demo sometimes given by the Equinix Metal SA Team. It is public for transperancy's sake.


The psuedo steps of the code are:

Run `gate_open.sh -c "Customer Name`:

```
devvm:~/code/metal_benchmark_demo$ ./gate_open.sh -c "Dios Mio"
UUID: 77a6b99c-a97c-4a78-b6c7-76a11f7cb9b4


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
 - [ curl, "https://packetbootstrap.s3.wasabisys.com/77a6b99c-a97c-4a78-b6c7-76a11f7cb9b4/packet", -o, /dev/shm/packet ]
 - [ curl, "https://packetbootstrap.s3.wasabisys.com/77a6b99c-a97c-4a78-b6c7-76a11f7cb9b4/bench_spotter.sh", -o, /dev/shm/bench_spotter.sh ]
 - [ chmod, 0755, /dev/shm/bench_spotter.sh ]
 - [ bash, /dev/shm/bench_spotter.sh ]
 
```

Copy and paste the section from `#cloud-config` down into the user data field while provisioning a Metal instance, and the code should take care of the rest. It'll take about ~2 minutes from the instance booting after provisioning for the benchmarks to complete and the HTML to render correctly.

#### `gate_open.sh` does the following: #####

* `set -e` cause you want it to barf if things go badly

* Stash everything under a UUID namespace for isolation and obfuscation

* Wipes the S3 / Wasabi bucket clean

* Uploads a Metal API token to the bucket, token should be read only. The token is used to query the API to get the cost for the instance in `bench_spotter.sh`

* Template out some bash because yikes, this is how the bench_spotter picks up the "customer" name specified in the `-c` flag

* Echo to shell some stuff to copy paste into user_data

* Note that `gate_open.sh` makes sloppy use of an S3 like service that needs to be configured on the workstation system before hand. The bucket's content must be publically accesible via HTTP/s.

#### `cloud-config` does the following: ####

* Installs some packages 
  * Including `cockpit`, this is later referenced in the bootstrap dashbord mangled by `bench_spotter.sh`

* Curls the files uploaded by `gate_open.sh` down

* Executes `bench_spotter.sh` locally


#### `bench_spotter.sh` does the following: ####

* Curls some stuff from the metadata API

* Curls the main API to get pricing

* Does a `sysbench`

* Do some quickly system / config mangling of nginx, then run a simple `ab` against `localhost`

* It then starts writing a bunch of metadata to different files, munging and merging them into the main HTML file

* It then seriously abuses nginx configuration to symlink it's munged files into an enabled nginx site

* The site is just a simple bootstrap 4.0 dashboard. The dynamic content comes from `http_assets`

* The dashboard also includes links to the Metal Console

#### `gate_shut.sh` does the following: ####

* Just wipes the bucket clean
