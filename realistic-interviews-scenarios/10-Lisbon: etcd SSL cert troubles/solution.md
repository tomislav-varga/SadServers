# Solution for Lisbon: etcd SSL cert trouble
## Description:
There's an etcd server running on https://localhost:2379 , get the value for the key "foo", ie etcdctl get foo or curl https://localhost:2379/v2/keys/foo


## Problem Analysis
Running curl https://localhost:2379/v2/keys/foo returns an SSL certificate error indicating that the certificate has expired. This prevents secure communication with the etcd server.
```bash
curl -v https://localhost:2379/v2/keys/foo
*   Trying 127.0.0.1:2379...
* Connected to localhost (127.0.0.1) port 2379 (#0)
* ALPN, offering h2
* ALPN, offering http/1.1
* successfully set certificate verify locations:
*  CAfile: /etc/ssl/certs/ca-certificates.crt
*  CApath: /etc/ssl/certs
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
* TLSv1.3 (IN), TLS handshake, Certificate (11):
* TLSv1.3 (OUT), TLS alert, certificate expired (557):
* SSL certificate problem: certificate has expired
* Closing connection 0
curl: (60) SSL certificate problem: certificate has expired
More details here: https://curl.se/docs/sslcerts.html
```
### Potential Causes
1. **Expired SSL Certificate**: The SSL certificate used by the etcd server has expired, which is causing the SSL handshake to fail.
2. **Incorrect Certificate Configuration**: The etcd server may be configured to use an incorrect or outdated certificate file.

## Root Cause
1. The system date shows that the current date is beyond the expiration date of the SSL certificate used by the etcd server.
```bash
Tue Dec 29 04:38:24 UTC 2026
```
2. Inspecting the SSL certificate reveals that it expired on Jan 30, 2023.
```bash
echo | openssl s_client -connect localhost:2379 -servername localhost -showcerts
CONNECTED(00000003)
depth=0 C = AU, ST = Some-State, O = Internet Widgits Pty Ltd, CN = localhost
verify error:num=18:self signed certificate
verify return:1
depth=0 C = AU, ST = Some-State, O = Internet Widgits Pty Ltd, CN = localhost
verify error:num=10:certificate has expired
notAfter=Jan 30 00:02:48 2023 GMT
verify return:1
depth=0 C = AU, ST = Some-State, O = Internet Widgits Pty Ltd, CN = localhost
notAfter=Jan 30 00:02:48 2023 GMT
verify return:1
```
3. A redirect rule in iptables is present to forward traffic from port 2379 to port 443, where a nginx server is running.
Resulting in a 404 http error when trying to access etcd.
```bash
curl -v https://localhost:2379/v2/keys/foo
*   Trying 127.0.0.1:2379...
* Connected to localhost (127.0.0.1) port 2379 (#0)
* ALPN, offering h2
* ALPN, offering http/1.1
* successfully set certificate verify locations:
*  CAfile: /etc/ssl/certs/ca-certificates.crt
*  CApath: /etc/ssl/certs
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
* TLSv1.3 (IN), TLS handshake, Certificate (11):
* TLSv1.3 (IN), TLS handshake, CERT verify (15):
* TLSv1.3 (IN), TLS handshake, Finished (20):
* TLSv1.3 (OUT), TLS change cipher, Change cipher spec (1):
* TLSv1.3 (OUT), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384
* ALPN, server accepted to use http/1.1
* Server certificate:
*  subject: C=AU; ST=Some-State; O=Internet Widgits Pty Ltd; CN=localhost
*  start date: Dec 31 00:02:48 2022 GMT
*  expire date: Jan 30 00:02:48 2023 GMT
*  common name: localhost (matched)
*  issuer: C=AU; ST=Some-State; O=Internet Widgits Pty Ltd; CN=localhost
*  SSL certificate verify ok.
> GET /v2/keys/foo HTTP/1.1
> Host: localhost:2379
> User-Agent: curl/7.74.0
> Accept: */*
>
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* old SSL session ID is stale, removing
* Mark bundle as not supporting multiuse
< HTTP/1.1 404 Not Found
< Server: nginx/1.18.0
< Date: Sat, 28 Jan 2023 08:04:05 GMT
< Content-Type: text/html
< Content-Length: 153
< Connection: keep-alive
<
<html>
<head><title>404 Not Found</title></head>
<body>
<center><h1>404 Not Found</h1></center>
<hr><center>nginx/1.18.0</center>
</body>
</html>
* Connection #0 to host localhost left intact
```
Running `sudo iptables -t nat -L -n -v` shows the redirect rule.
```bash

Chain OUTPUT (policy ACCEPT 30 packets, 1938 bytes)
 pkts bytes target     prot opt in     out     source               destination
   20  1200 REDIRECT   tcp  --  *      lo      0.0.0.0/0            0.0.0.0/0            tcp dpt:2379 redir ports 443
    0     0 DOCKER     all  --  *      *       0.0.0.0/0           !127.0.0.0/8          ADDRTYPE match dst-type LOCAL

```
## Solution Steps
1. **Set system date** to date before certificate expiration to temporarily mitigate the issue.
```bash
sudo date -s "2023-01-01 00:00:00"
```
2. **Delete the iptables redirect rule** to ensure traffic to port 2379 reaches the etcd server directly.
```bash
sudo iptables -t nat -D OUTPUT -p tcp --dport 2379 -j REDIRECT --to-ports 443
```
3. **Run curl command again** to verify that the etcd server is accessible and returns the expected value for the key "foo".
```bash
curl -v https://localhost:2379/v2/keys/foo
{"action":"get","node":{"key":"/foo","value":"bar","modifiedIndex":4,"createdIndex":4}}
```