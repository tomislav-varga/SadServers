# Solution for Moyogalpa: Security Snag. The Trials of Mary and John
## Description
Mary and John are working on a Golang web application, and the security team has asked them to implement security measures. Unfortunately, they have broken the application, and it no longer functions. They need your help to fix it.

The fixed application should be able to allow clients to communicate with the application over HTTPS without ignoring any checks. (eg: curl https://webapp:7000/users.html) and serve its static files.

## Problem Analysis
```bash
 curl -v https://webapp:7000/users.html
* Could not resolve host: webapp
* Closing connection 0
curl: (6) Could not resolve host: webapp
```
The error indicates that the hostname `webapp` cannot be resolved. This is likely due to a missing or incorrect entry in the `/etc/hosts` file or DNS configuration.

```bash
 systemctl list-units -t service --all | grep webapp
  webapp.service                       loaded    active   running Webapp
```
The webapp service is running, which is a good sign.
```bash
journalctl -u webapp.service - since "10 minutes ago"
Jan 15 02:53:14 i-08e9c197ea0e519fd webapp[621]: 2026/01/15 02:53:14 open /home/webapp/pki/server.crt: permission denied
Jan 15 02:53:14 i-08e9c197ea0e519fd webapp[621]: 2026/01/15 02:53:14 open /home/webapp/pki/server.pem: permission denied
Jan 15 02:53:14 i-08e9c197ea0e519fd webapp[621]: 2026/01/15 02:53:14 can not access certificate/key file. sleeping for 10s and will retry
```
The logs indicate that the web application is unable to access the SSL certificate and key files due to permission issues. This is likely the root cause of the problem.

```bash
sudo ls -la /home/webapp/pki
total 20
drwx------ 2 root   root   4096 Apr 10  2024 .
drwxr-xr-x 4 webapp webapp 4096 Apr 10  2024 ..
-rw-r----- 1 admin  admin  1870 Apr 10  2024 CA.crt
-rw-r----- 1 admin  admin  1927 Apr 10  2024 server.crt
-rw-r----- 1 admin  admin  3247 Apr 10  2024 server.pem
```
The ownership and permissions of the `/home/webapp/pki` directory and its contents are incorrect. The files are owned by `admin:admin`, and the web application likely runs under the `webapp` user, which does not have permission to read these files.
```bash
 ls -ld webapp/
drwxr-xr-x 4 webapp webapp 4096 Apr 10  2024 webapp/
admin@i-08e9c197ea0e519fd:/home$ 
ls -ld webapp/static-files/
drwxr-xr-x 2 admin admin 4096 Apr 10  2024 webapp/static-files/
```
Checking the `static-files` directory, it is owned by `admin:admin`, which may also cause permission issues when the web application tries to serve static files.

## Solution
First, we need to add an entry to the `/etc/hosts` file to resolve the `webapp` hostname to `127.0.0.1`:
```bash
sudo vim /etc/hosts
```
Add the following line to the file:
```bash
127.0.0.1  webapp
```
Next, we need to fix the permission issues with the SSL certificate and key files.
To fix the permission issues, we need to change the ownership of the certificate and key files to the `webapp` user and group. We can do this with the following commands:
```bash
sudo chown -R webapp:webapp /home/webapp/
```
After changing the ownership, we should verify that the permissions are correct:
```bash
ls -la /home/webapp/pki
```
The output should show that `server.crt` and `server.pem` are now owned by `webapp:webapp`.
Finally, we can restart the web application service to apply the changes:
```bash
sudo systemctl restart webapp.service
```
Now, we can test the application again using curl:
```bash
curl -v https://webapp:7000/users.html
*   Trying 127.0.0.1:7000...
* Connected to webapp (127.0.0.1) port 7000 (#0)
* ALPN, offering h2
* ALPN, offering http/1.1
* successfully set certificate verify locations:
*  CAfile: /etc/ssl/certs/ca-certificates.crt
*  CApath: /etc/ssl/certs
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
* TLSv1.3 (IN), TLS handshake, Certificate (11):
* TLSv1.3 (OUT), TLS alert, unknown CA (560):
* SSL certificate problem: unable to get local issuer certificate
* Closing connection 0
curl: (60) SSL certificate problem: unable to get local issuer certificate
More details here: https://curl.se/docs/sslcerts.html

curl failed to verify the legitimacy of the server and therefore could not
establish a secure connection to it. To learn more about this situation and
how to fix it, please visit the web page mentioned above.   
```
The application is now accessible over HTTPS, but there is still an issue with the SSL certificate verification. This is expected since we are using a self-signed certificate.
We need to add the self-signed certificate to the trusted certificates store on the client machine to avoid this warning.
```bash
sudo cp /home/webapp/pki/CA.crt /usr/local/share/ca-certificates/webapp-ca.crt
sudo update-ca-certificates
```
Running the curl command again should now work without any SSL errors:
```bash
curl -v https://webapp:7000/users.html
*   Trying 127.0.0.1:7000...
* Connected to webapp (127.0.0.1) port 7000 (#0)
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
* SSL connection using TLSv1.3 / TLS_AES_128_GCM_SHA256
* ALPN, server accepted to use h2
* Server certificate:
*  subject: CN=webapp
*  start date: Apr 10 01:16:12 2024 GMT
*  expire date: Apr  7 01:16:12 2039 GMT
*  subjectAltName: host "webapp" matched cert's "webapp"
*  issuer: O=Demo; OU=Security; CN=Demo CA
*  SSL certificate verify ok.
* Using HTTP2, server supports multi-use
* Connection state changed (HTTP/2 confirmed)
* Copying HTTP/2 data in stream buffer to connection buffer after upgrade: len=0
* Using Stream ID: 1 (easy handle 0x562a980afb20)
> GET /users.html HTTP/2
> Host: webapp:7000
> user-agent: curl/7.74.0
> accept: */*
>
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* Connection state changed (MAX_CONCURRENT_STREAMS == 250)!
< HTTP/2 403
< content-type: text/plain; charset=utf-8
< content-length: 9
< date: Sat, 17 Jan 2026 04:03:54 GMT
<
* Connection #0 to host webapp left intact
Forbidden
```
The application is now accessible over HTTPS without SSL errors. However, we are receiving a `403 Forbidden` response when trying to access the `/users.html` page. This indicates that there may be additional access control mechanisms in place that need to be addressed.
Since the server is a Debian-based system, we can check if AppArmor is enforcing any policies on the web application:
```bash
sudo aa-status
apparmor module is loaded.
10 profiles are loaded.
10 profiles are in enforce mode.
   /usr/bin/man
   /usr/local/bin/webapp
   /usr/sbin/chronyd
   docker-default
   lsb_release
   man_filter
   man_groff
   nvidia_modprobe
   nvidia_modprobe//kmod
   tcpdump
0 profiles are in complain mode.
3 processes have profiles defined.
3 processes are in enforce mode.
   /usr/local/bin/webapp (1112)
   /usr/sbin/chronyd (648)
   /usr/sbin/chronyd (649)
0 processes are in complain mode.
0 processes are unconfined but have a profile defined.
```
The web application is confined by an AppArmor profile, which may be restricting its access to certain files or directories.
To check the AppArmor logs for any denied access attempts, we can use the following command:
```bash
sudo journalctl | grep apparmor | grep DENIED
Jan 17 04:03:54 i-0788135f1f0c243aa audit[1112]: AVC apparmor="DENIED" operation="open" profile="/usr/local/bin/webapp" name="/home/webapp/static-files/users.html" pid=1112 comm="webapp" requested_mask="r" denied_mask="r" fsuid=1001 ouid=1001
Jan 17 04:03:54 i-0788135f1f0c243aa kernel: audit: type=1400 audit(1768622634.929:12): apparmor="DENIED" operation="open" profile="/usr/local/bin/webapp" name="/home/webapp/static-files/users.html" pid=1112 comm="webapp" requested_mask="r" denied_mask="r" fsuid=1001 ouid=1001
Jan 17 04:08:24 i-0788135f1f0c243aa audit[1112]: AVC apparmor="DENIED" operation="open" profile="/usr/local/bin/webapp" name="/home/webapp/static-files/users.html" pid=1112 comm="webapp" requested_mask="r" denied_mask="r" fsuid=1001 ouid=1001
Jan 17 04:08:24 i-0788135f1f0c243aa kernel: audit: type=1400 audit(1768622904.501:13): apparmor="DENIED" operation="open" profile="/usr/local/bin/webapp" name="/home/webapp/static-files/users.html" pid=1112 comm="webapp" requested_mask="r" denied_mask="r" fsuid=1001 ouid=1001
```
The logs show that the AppArmor profile for the web application is denying access to the `/home/webapp/static-files/users.html` file. This is likely the cause of the `403 Forbidden` response.
To resolve this issue, we need to modify the AppArmor profile for the web application to allow access to the static files directory.
We can use the `aa-logprof` tool to update the AppArmor profile based on the logged denials:
```bash
sudo aa-logprof
Reading log entries from /var/log/syslog.
Updating AppArmor profiles in /etc/apparmor.d.
Enforce-mode changes:

Profile:  /usr/local/bin/webapp
Path:     /home/webapp/static-files/users.html
New Mode: owner r
Severity: 4

 [1 - owner /home/*/static-files/users.html r,]
  2 - owner /home/webapp/static-files/users.html r,
(A)llow / [(D)eny] / (I)gnore / (G)lob / Glob with (E)xtension / (N)ew / Audi(t) / (O)wner permissions off / Abo(r)t / (F)inish
Adding owner /home/*/static-files/users.html r, to profile.

= Changed Local Profiles =

The following local profiles were changed. Would you like to save them?

 [1 - /usr/local/bin/webapp]
(S)ave Changes / Save Selec(t)ed Profile / [(V)iew Changes] / View Changes b/w (C)lean profiles / Abo(r)t
Writing updated profile for /usr/local/bin/webapp.
```
After updating the AppArmor profile, we can run curl again to test the application:
```bash
curl -v https://webapp:7000/users.html
*   Trying 127.0.0.1:7000...
* Connected to webapp (127.0.0.1) port 7000 (#0)
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
* SSL connection using TLSv1.3 / TLS_AES_128_GCM_SHA256
* ALPN, server accepted to use h2
* Server certificate:
*  subject: CN=webapp
*  start date: Apr 10 01:16:12 2024 GMT
*  expire date: Apr  7 01:16:12 2039 GMT
*  subjectAltName: host "webapp" matched cert's "webapp"
*  issuer: O=Demo; OU=Security; CN=Demo CA
*  SSL certificate verify ok.
* Using HTTP2, server supports multi-use
* Connection state changed (HTTP/2 confirmed)
* Copying HTTP/2 data in stream buffer to connection buffer after upgrade: len=0
* Using Stream ID: 1 (easy handle 0x55fd655eeb20)
> GET /users.html HTTP/2
> Host: webapp:7000
> user-agent: curl/7.74.0
> accept: */*
>
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* Connection state changed (MAX_CONCURRENT_STREAMS == 250)!
< HTTP/2 200
< content-type: text/html; charset=utf-8
< content-length: 78
< date: Sat, 17 Jan 2026 04:22:16 GMT
<
<html>
  <head> </head>
  <body>
    <p>From Users Page</p>
  </body>
</html>
* Connection #0 to host webapp left intact
```
The application is now accessible over HTTPS, and we can successfully retrieve the `/users.html` page without any errors.

For successfully passsing the checks, we also need to ensure that the healthcheck endpoint is working correctly:
```bash
curl -v https://webapp:7000/healthcheck.html

*   Trying 127.0.0.1:7000...
* Connected to webapp (127.0.0.1) port 7000 (#0)
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
* SSL connection using TLSv1.3 / TLS_AES_128_GCM_SHA256
* ALPN, server accepted to use h2
* Server certificate:
*  subject: CN=webapp
*  start date: Apr 10 01:16:12 2024 GMT
*  expire date: Apr  7 01:16:12 2039 GMT
*  subjectAltName: host "webapp" matched cert's "webapp"
*  issuer: O=Demo; OU=Security; CN=Demo CA
*  SSL certificate verify ok.
* Using HTTP2, server supports multi-use
* Connection state changed (HTTP/2 confirmed)
* Copying HTTP/2 data in stream buffer to connection buffer after upgrade: len=0
* Using Stream ID: 1 (easy handle 0x558dd486eb20)
> GET /healthcheck.html HTTP/2
> Host: webapp:7000
> user-agent: curl/7.74.0
> accept: */*
>
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* Connection state changed (MAX_CONCURRENT_STREAMS == 250)!
< HTTP/2 403
< content-type: text/plain; charset=utf-8
< content-length: 9
< date: Sat, 17 Jan 2026 04:26:52 GMT
<
* Connection #0 to host webapp left intact
```
We need to also allow access to the `/healthcheck.html` file in the AppArmor profile:
```bash
sudo aa-logprof
Reading log entries from /var/log/syslog.
Updating AppArmor profiles in /etc/apparmor.d.
Enforce-mode changes:

Profile:  /usr/local/bin/webapp
Path:     /home/webapp/static-files/healthcheck.html
New Mode: owner r
Severity: 4

 [1 - owner /home/*/static-files/healthcheck.html r,]
  2 - owner /home/webapp/static-files/healthcheck.html r,
(A)llow / [(D)eny] / (I)gnore / (G)lob / Glob with (E)xtension / (N)ew / Audi(t) / (O)wner permissions off / Abo(r)t / (F)inish
Adding owner /home/*/static-files/healthcheck.html r, to profile.

= Changed Local Profiles =

The following local profiles were changed. Would you like to save them?

 [1 - /usr/local/bin/webapp]
(S)ave Changes / Save Selec(t)ed Profile / [(V)iew Changes] / View Changes b/w (C)lean profiles / Abo(r)t
Writing updated profile for /usr/local/bin/webapp.
```
After updating the AppArmor profile again, we can run curl to test the healthcheck endpoint:
```bash
curl -v https://webapp:7000/healthcheck.html

*   Trying 127.0.0.1:7000...
* Connected to webapp (127.0.0.1) port 7000 (#0)
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
* SSL connection using TLSv1.3 / TLS_AES_128_GCM_SHA256
* ALPN, server accepted to use h2
* Server certificate:
*  subject: CN=webapp
*  start date: Apr 10 01:16:12 2024 GMT
*  expire date: Apr  7 01:16:12 2039 GMT
*  subjectAltName: host "webapp" matched cert's "webapp"
*  issuer: O=Demo; OU=Security; CN=Demo CA
*  SSL certificate verify ok.
* Using HTTP2, server supports multi-use
* Connection state changed (HTTP/2 confirmed)
* Copying HTTP/2 data in stream buffer to connection buffer after upgrade: len=0
* Using Stream ID: 1 (easy handle 0x55571dc2fb20)
> GET /healthcheck.html HTTP/2
> Host: webapp:7000
> user-agent: curl/7.74.0
> accept: */*
>
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* Connection state changed (MAX_CONCURRENT_STREAMS == 250)!
< HTTP/2 200
< content-type: text/html; charset=utf-8
< content-length: 85
< date: Sat, 17 Jan 2026 04:28:34 GMT
<
<html>
  <head> </head>
  <body>
    <p>From Health Check Page</p>
  </body>
</html>
* Connection #0 to host webapp left intact
```
The healthcheck endpoint is now accessible over HTTPS, and we can successfully retrieve the `/healthcheck.html` page without any errors.

## Verification
To pass the verification checks, we need to ensure that both the `/users.html` and `/healthcheck.html` endpoints are accessible over HTTPS without any SSL errors or permission issues.
Running the check script under the `/home/admin/agent` directory should return `OK`.