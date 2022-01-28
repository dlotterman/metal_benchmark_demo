#!/bin/bash

NUM_CORES=$(nproc --all)
HTML_DIR="/tmp/www"
SYSBENCH_RUN_OUTPUT=$HTML_DIR"/sysbench_output.html"
AB_RUN_OUTPUT=$HTML_DIR"/ab_output.html"
META_OUTPUT=$HTML_DIR"/metadata.html"

PACKET_API_TOKEN=$(< /dev/shm/packet)

#This variable gets mangled by gate_open.sh
CUSTOMER="EXAMPLE_CUSTOMER"

mkdir -p $HTML_DIR

cat << EOL > $META_OUTPUT
<body>
<pre>
EOL

# TODO: Yikes, this is a disaster
curl -s https://metadata.packet.net/metadata | echo "Hostname: "$(jq .hostname) >> $META_OUTPUT
echo "Uptime: " "$(uptime)" >> $META_OUTPUT
curl -s https://metadata.packet.net/metadata | echo "Packet API ID: ""$(jq .id)" >> $META_OUTPUT
curl -s https://metadata.packet.net/metadata | echo "Packet Facility: ""$(jq .facility)" >> $META_OUTPUT

INSTANCE_CONFIG=$(curl -s https://metadata.packet.net/metadata | (jq .class))
echo "Packet Instance Config: $INSTANCE_CONFIG" >> $META_OUTPUT

curl -s https://metadata.packet.net/metadata | echo "Packet Instance Interfaces: ""$(jq .network.interfaces)" >> $META_OUTPUT

INSTANCE_COST=$(curl -s -H "X-Auth-Token: $PACKET_API_TOKEN" https://api.equinix.com/metal/v1/plans | jq '.plans[] | select (.name == '$INSTANCE_CONFIG') | {pricing} | .pricing.hour' )

echo "Packet Instance Cost: $INSTANCE_COST" >> $META_OUTPUT

cat << EOL >> $META_OUTPUT
</pre>
</body>
EOL

cat << EOL > $SYSBENCH_RUN_OUTPUT
<body>
<pre>
EOL

sysbench cpu --cpu-max-prime=20000 --threads="$NUM_CORES" --time=60 run >> $SYSBENCH_RUN_OUTPUT 2>&1

cat << EOL >> $SYSBENCH_RUN_OUTPUT
</pre>
</body>
EOL

EVENTS=$(grep "total number of events" $SYSBENCH_RUN_OUTPUT | awk '{print$NF}')
EPS=$(grep "events per second" $SYSBENCH_RUN_OUTPUT | awk '{print$NF}')
EPD=$(echo "scale=2 ; $EPS * 60 * 60 / $INSTANCE_COST" | bc)

cat << EOL > $AB_RUN_OUTPUT
<body>
<pre>
EOL

cat > /etc/sysctl.conf << EOL
net.core.rmem_default=12582912
net.core.wmem_default=12582912
net.core.rmem_max=12582912
net.core.wmem_max=12582912
net.ipv4.tcp_rmem=10240 87380 12582912
net.ipv4.tcp_wmem=10240 87380 12582912
net.ipv4.tcp_congestion_control=westwood
fs.file-max = 110000
EOL

cat > /etc/security/limits.conf << EOL
nginx       soft    nofile   10000
nginx       hard    nofile   110000
EOL


cat > /etc/nginx/nginx.conf << EOL
user www-data;
worker_processes auto;
worker_cpu_affinity auto;
pid /run/nginx.pid;
worker_rlimit_nofile 100000;
include /etc/nginx/modules-enabled/*.conf;

events {
        worker_connections 1024;
        use epoll;
        multi_accept on;
}
http {
        sendfile on;
        access_log off;
        tcp_nopush on;
        tcp_nodelay on;
        keepalive_timeout 65;
        types_hash_max_size 2048;
        open_file_cache max=200000 inactive=20s;
        open_file_cache_valid 30s;
        open_file_cache_min_uses 2;
        open_file_cache_errors on;
        include /etc/nginx/mime.types;
        default_type application/octet-stream;
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3; # Dropping SSLv3, ref: POODLE
        ssl_prefer_server_ciphers on;
        error_log /var/log/nginx/error.log;
        gzip on;
        include /etc/nginx/conf.d/*.conf;
        include /etc/nginx/sites-enabled/*;
}
EOL

# gotta \ escape $uri
cat > /etc/nginx/sites-available/default << EOL
server {
        listen 80 default_server;
        listen [::]:80 default_server;
        root /var/www/html;
        index index.html index.htm index.nginx-debian.html;
        server_name _;
        location / {
                try_files \$uri \$uri/ =404;
        }
        location /packetbot {
                add_header Content-Type text/plain;
                return 200 'Packetbot Simple Bench!';
        }
}
EOL

systemctl reload nginx

sleep 2 # give nginx time to reload

ab -n 80000 -c 500 -k http://localhost/packetbot >> $AB_RUN_OUTPUT 2>&1

cat << EOL >> $AB_RUN_OUTPUT
</pre>
</body>
EOL

AB_RPS=$(grep "Requests per second" $AB_RUN_OUTPUT | awk '{print$4}')
AB_FAILED=$(grep "Failed requests" $AB_RUN_OUTPUT | awk '{print$3}')
AB_TPR=$(grep "across all concurrent requests" $AB_RUN_OUTPUT | awk '{print$4}' | awk -F \. '{print$NF}')
AB_RPD=$(echo "scale=2 ; $AB_RPS * 60 * 60 / $INSTANCE_COST" | bc)



cat > $HTML_DIR/index.html << EOL
<!doctype html>
<html lang="en">
<head>
	<!-- Required meta tags -->
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">

	<!-- Bootstrap CSS -->
	<link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.5.0/css/bootstrap.min.css" integrity="sha384-9aIt2nRpC12Uk9gS9baDl411NQApFmC26EwAOH8WgZl5MYYxFfc+NcPb1dKGj7Sk" crossorigin="anonymous">
	
	<link href="https://s3.wasabisys.com/packetrepo/http_assets/counter.css" rel="stylesheet">
	
	<link href="//maxcdn.bootstrapcdn.com/bootstrap/4.1.1/css/bootstrap.min.css" rel="stylesheet" id="bootstrap-css">

	<script>
		function setHref() {
		document.getElementById('modify-me').href = window.location.protocol + "//" + 		window.location.hostname + ":9090/";
		}
	</script>


	<title>Metal Demo Benchmark Results</title>
</head>
  
  
<body onload="setHref()">
	<link rel="stylesheet" href="https://netdna.bootstrapcdn.com/font-awesome/4.0.3/css/font-awesome.min.css">
	<nav class="navbar navbar-expand-md navbar-dark fixed-top" style="background-color: #ffffff;">
		<a class="navbar-brand" href="#"><img src="https://metal.equinix.com/metal/images/logo/equinix-metal-full.svg" width="150" height="30" alt=""></a>
		<button class="navbar-toggler" type="button" data-toggle="collapse" data-target="#navbarsExampleDefault" aria-controls="navbarsExampleDefault" aria-expanded="false" aria-label="Toggle navigation">
		<span class="navbar-toggler-icon"></span>
		</button>

		<div class="collapse navbar-collapse" id="navbarsExampleDefault">
			<ul class="navbar-nav mr-auto">
			<li class="nav-item active">
				<a class="nav-link" class="text-link" href="https://console.equinix.com/">Metal Home <span class="sr-only">(current)</span></a>
			</li>
			<li class="nav-item">
				<a class="nav-link" class="text-link" href="#" id="modify-me">Cockpit</a>
			</li>

		</div>
	</nav>

	<main role="main">

 
	<div class="jumbotron" style="background-color: #ffffff;">
		<div class="container">
			<div class="row">
				<div class="col text-center">
					<h1>$CUSTOMER Demo Instance Benchmark Results</h1>
					<p>From a real sysbench while the $CUSTOMER demo was ongoing</p>
					<img src="https://s3.wasabisys.com/packetrepo/http_assets/packet_boot" class="rounded">
				</div>
			</div>
		</div>
	</div>
	<div class="container">
		<div class="row text-center top-buffer"">
			<div class="col">
				<div class="counter">
					<i class="fa fa-desktop fa-2x"></i>
					<h2 class="timer count-title count-number" data-to="$EVENTS" data-speed="4500"></h2>
					<p class="count-text ">Prime Numbers Calculated (Events)</p>
				</div>
			</div>
			<div class="col">
				<div class="counter">
					<i class="fa fa-calendar fa-2x"></i>
					<h2 class="timer count-title count-number" data-to="$EPS" data-speed="2500"></h2>
					<p class="count-text ">Prime Numbers Calculater Per Second</p>
				</div>
			</div>
			<div class="col">
				<div class="counter">
					<i class="fa fa-dollar fa-2x"></i>
					<h2 class="timer count-title count-number" data-to="$(echo "$INSTANCE_COST * 100" | bc)" data-speed="1600"></h2>
					<p class="count-text ">Cents Per Hour</p>
				</div>
			</div>
			<div class="col">
				<div class="counter">
					<i class="fa fa-lightbulb-o fa-2x"></i>
					<h2 class="timer count-title count-number" data-to="$EPD" data-speed="17000"></h2>
					<p class="count-text ">Total Prime Numbers Calculated Per Cent</p>
				</div>
			</div>
		</div>
	</div>

	<div class="container">
		<div class="row text-center top-buffer"">
			<div class="col">
				<div class="counter">
					<i class="fa fa-desktop fa-2x"></i>
					<h2 class="timer count-title count-number" data-to="$AB_RPS" data-speed="5500"></h2>
					<p class="count-text ">HTTP Requests Per Second (Events)</p>
				</div>
			</div>
            <div class="col">
				<div class="counter">
					<i class="fa fa-calendar fa-2x"></i>
					<h2 class="timer count-title count-number" data-to="$AB_FAILED" data-speed="2500"></h2>
					<p class="count-text ">Failed HTTP Requests</p>
				</div>
            </div>
            <div class="col">
				<div class="counter">
					<i class="fa fa-calendar fa-2x"></i>
					<h2 class="timer count-title count-number" data-to="$AB_TPR" data-speed="2500"></h2>
					<p class="count-text ">Average Request time in μs</p>
				</div>
            </div>
            <div class="col">
				<div class="counter">
					<i class="fa fa-calendar fa-2x"></i>
					<h2 class="timer count-title count-number" data-to="$AB_RPD" data-speed="16500"></h2>
					<p class="count-text ">Requests per Cent</p>
				</div>
            </div>
		</div>
	</div>

<div class="container">
	<div class="row top-buffer"">
		<div class=""col-md-6 text-center">
			<h2>Sysbench Output</h2>
			<embed type="text/html" src="sysbench_output.html" width="500" height="500"> 
		</div>
		<div class=""col-md-6 text-center">
			<h2>Apache Benchmark Output</h2>
			<embed type="text/html" src="ab_output.html" width="500" height="500"> 
		</div>
		<div class=""col-md-6 text-center">
			<h2>Metadata Output</h2>
			<embed type="text/html" src="metadata.html" width="500" height="500"> 
		</div>
	</div>
</div>

</main>



    <!-- Optional JavaScript -->
    <!-- jQuery first, then Popper.js, then Bootstrap JS -->
    <script src="https://code.jquery.com/jquery-3.5.1.slim.min.js" integrity="sha384-DfXdz2htPH0lsSSs5nCTpuj/zy4C+OGpamoFVy38MVBnE+IbbVYUew+OrCXaRkfj" crossorigin="anonymous"></script>
    <script src="https://cdn.jsdelivr.net/npm/popper.js@1.16.0/dist/umd/popper.min.js" integrity="sha384-Q6E9RHvbIyZFJoft+2mJbHaEWldlvI9IOYy5n3zV9zzTtmI3UksdQRVvoxMfooAo" crossorigin="anonymous"></script>
    <script src="https://stackpath.bootstrapcdn.com/bootstrap/4.5.0/js/bootstrap.min.js" integrity="sha384-OgVRvuATP1z7JjHLkuOU7Xw704+h835Lr+6QL9UvYjZE3Ipu6Tp75j7Bh/kR0JKI" crossorigin="anonymous"></script>
	<script src="https://s3.wasabisys.com/packetrepo/http_assets/counter.js"></script>
	<script src="//maxcdn.bootstrapcdn.com/bootstrap/4.1.1/js/bootstrap.min.js"></script>
	<script src="//cdnjs.cloudflare.com/ajax/libs/jquery/3.2.1/jquery.min.js"></script>
  </body>
</html>
EOL


ln -s /tmp/www/index.html /var/www/html/ > /dev/null 2>&1
ln -s /tmp/www/sysbench_output.html /var/www/html/ > /dev/null 2>&1
ln -s /tmp/www/ab_output.html /var/www/html/ > /dev/null 2>&1
ln -s /tmp/www/metadata.html /var/www/html/ > /dev/null 2>&1


