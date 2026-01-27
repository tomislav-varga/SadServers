# Solution for Tarifa: Between Two Seas
## Description:
There are three Docker containers defined in the docker-compose.yml file: an HAProxy accepting connetions on port :5000 of the host, and two nginx containers, not exposed to the host.

The person who tried to set this up wanted to have HAProxy in front of the (backend or upstream) nginx containers load-balancing them but something is not working.

## Problem Analysis
Running `docker logs haproxy` shows that HAProxy is unable to resolve the addresses of the backend nginx container nginx_1:
```bash
[NOTICE]   (1) : config : [/usr/local/etc/haproxy/haproxy.cfg:19] : 'server nginx_backends/nginx_1' : could not resolve address 'nginx_1', disabling server.
```
Looking at the docker-compose.yml file reveals that the HAProxy container is only connected to the `frontend_network` network, while the nginx_1 container is only connected to the `backend_network` network. This means that HAProxy cannot communicate with nginx_1 because they are on different networks.
```yaml
version: '3'

services:
  nginx_0:
    image: nginx:1.25.3
    container_name: nginx_0
    restart: always
    volumes:
      - ./custom_index/nginx_0:/usr/share/nginx/html
      - ./custom-nginx_0.conf:/etc/nginx/conf.d/default.conf:ro
    networks:
      - frontend_network # nginx_0 is on the frontend_network

  nginx_1:
    image: nginx:1.25.3
    container_name: nginx_1
    restart: always
    volumes:
      - ./custom_index/nginx_1:/usr/share/nginx/html
      - ./custom-nginx_1.conf:/etc/nginx/conf.d/default.conf:ro
    networks:
      - backend_network # nginx_1 is on the backend_network

  haproxy:
    image: haproxy:2.8.4
    container_name: haproxy
    restart: always
    ports:
      - "5000:5000"
    depends_on:
      - nginx_0
      - nginx_1
    volumes:
      - ./haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro
    networks:
      - frontend_network
    # missing connection to backend_network
networks:
  frontend_network:
    driver: bridge
  backend_network:
    driver: bridge
```
The configuration of nginx_1 also shows that it is listening on port 81 instead of the default port 80:
```cfg
server {
    listen 81; # port 81 instead of 80

    server_name localhost;

    location / {
        root   /usr/share/nginx/html;
        index  index.html;
    }
}
```
While HAProxy is trying to connect to nginx_1 on port 80. The relevant section of the HAProxy configuration file haproxy.cfg is as follows:
```cfg
global
    daemon
    maxconn 256

defaults
    mode http
    default-server init-addr last,libc,none
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

frontend http-in
    bind *:5000
    default_backend nginx_backends

backend nginx_backends
    balance roundrobin
    server nginx_0 nginx_0:80 check
    server nginx_1 nginx_1:80 check 
```

### Root Cause
1. **Network Misconfiguration**: The HAProxy container is not on the same Docker network as the nginx_1 container, preventing it from resolving the hostname and communicating with it.
2. **Port Misconfiguration**: The nginx_1 container is configured to listen on port 81, but HAProxy is trying to connect to it on port 80.

## Solution
To resolve the issue, we need to ensure that HAProxy can communicate with both nginx containers and that it connects to the correct port for nginx_1.
1. Modify the `docker-compose.yml` file to connect HAProxy to both networks:
```yaml
    networks:
      - frontend_network
      - backend_network
```
2. Update `the custom-nginx_1.conf` file to listen on port 80 instead of port 81:
```cfg
server {
    listen 80;

    server_name localhost;

    location / {
        root   /usr/share/nginx/html;
        index  index.html;
    }
}
```
3. Restart the Docker containers to apply the changes:
```bash
  docker compose down --volumes --remove-orphans
  docker compose up -d
```
4. After applying these changes, check the logs of the HAProxy container to ensure that it can now resolve and connect to both nginx containers without errors:
```bash
docker logs haproxy
[NOTICE]   (1) : New worker (8) forked
[NOTICE]   (1) : Loading success.
```
## Verification
Run the check script to verify that the setup is working correctly:
```bash
/home/admin/agent/check.sh
OK
```
The output `OK` indicates that HAProxy is successfully load-balancing between the two nginx containers.