# Solution for "Can't Serve Web File" in Tokyo Scenario
## Description:
There's a web server serving a file /var/www/html/index.html with content "hello sadserver" but when we try to check it locally with an HTTP client like curl 127.0.0.1:80, nothing is returned. This scenario is not about the particular web server configuration and you only need to have general knowledge about how web servers work.

## Problem Analysis
### Potential Causes
1. **Web Server Not Running**: The web server service may not be running, which would prevent it from serving any files.
2. **Firewall Blocking Port 80**: A firewall may be blocking incoming connections on port 80, preventing access to the web server.
3. **Incorrect File Permissions**: The web server may not have the necessary permissions to read the index.html file.
4. **Misconfigured Web Server**: The web server may be misconfigured, preventing it from serving files correctly.
### Root Cause
1. Firewall blocking port 80.
Revealed after running the command:
```bash
sudo iptables -L
Chain INPUT (policy ACCEPT)
target     prot opt source               destination
DROP       tcp  --  anywhere             anywhere             tcp dpt:http

Chain FORWARD (policy ACCEPT)
target     prot opt source               destination
```
To fix the issue, we need to allow incoming traffic on port 80. This can be done by adding a rule to the firewall to accept TCP traffic on port 80.

```bash
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
```
Since iptables rules chain policies are set Top-Down, the new rule will not be effective if there is a DROP rule before it. To ensure the new rule is effective, we can insert it at the top of the INPUT chain:

```bash
sudo iptables -I INPUT 1 -p tcp --dport 80 -j ACCEPT
```

After adding the rule, we can verify that it has been added correctly by running:

```bash
sudo iptables -L INPUT --line-numbers
Chain INPUT (policy ACCEPT)
num  target     prot opt source               destination
1    ACCEPT     tcp  --  anywhere             anywhere             tcp dpt:http
2    DROP       tcp  --  anywhere             anywhere             tcp dpt:http
```
Now, we can test accessing the web server again:

```bash
curl -v 127.0.0.1:80
*   Trying 127.0.0.1:80...
* Connected to 127.0.0.1 (127.0.0.1) port 80 (#0)
> GET / HTTP/1.1
> Host: 127.0.0.1
> User-Agent: curl/7.81.0
> Accept: */*
>
* Mark bundle as not supporting multiuse
< HTTP/1.1 403 Forbidden
< Date: Thu, 18 Dec 2025 07:49:19 GMT
< Server: Apache/2.4.52 (Ubuntu)
< Content-Length: 274
< Content-Type: text/html; charset=iso-8859-1
<
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html><head>
<title>403 Forbidden</title>
</head><body>
<h1>Forbidden</h1>
<p>You don't have permission to access this resource.</p>
<hr>
<address>Apache/2.4.52 (Ubuntu) Server at 127.0.0.1 Port 80</address>
</body></html>
* Connection #0 to host 127.0.0.1 left intact
```
The web server is now responding, but we get a 403 Forbidden error, which indicates access permission issues. To fix this, we need to ensure that the web server has the correct permissions to read the index.html file.
This leads us to the second potential cause:
2. Incorrect File Permissions.
Revealed after running the command:
```bash
ls -la /var/www/html
total 12
drwxr-xr-x 2 root root 4096 Aug  1  2022 .
drwxr-xr-x 3 root root 4096 Aug  1  2022 ..
-rw------- 1 root root   16 Aug  1  2022 index.html
```
The index.html file has permissions set to 600, which means only the root user can read it. The web server typically runs under a different user (like www-data for Apache on Ubuntu), so it cannot read the file.
To fix this, we need to change the file permissions to allow the web server user to read the file:
```bash
sudo chown www-data:www-data /var/www/html/index.html
```
And set the correct permissions:
```bash
sudo chmod 644 /var/www/html/index.html
```
Now, we can test accessing the web server again:
```bash
curl -v 127.0.0.1:80
*   Trying 127.0.0.1:80...
* Connected to 127.0.0.1 (127.0.0.1) port 80 (#0)
> GET / HTTP/1.1
> Host: 127.0.0.1
> User-Agent: curl/7.81.0
> Accept: */*
>
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< Date: Thu, 18 Dec 2025 07:52:04 GMT
< Server: Apache/2.4.52 (Ubuntu)
< Last-Modified: Mon, 01 Aug 2022 00:40:24 GMT
< ETag: "10-5e5233ed9edbf"
< Accept-Ranges: bytes
< Content-Length: 16
< Content-Type: text/html
<
hello sadserver
* Connection #0 to host 127.0.0.1 left intact
```
The web server is now successfully serving the index.html file with the content "hello sadserver".