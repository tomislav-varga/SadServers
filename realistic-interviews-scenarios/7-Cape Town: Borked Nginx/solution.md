# Solution for Cape Town: Borked
## Description:
There's an Nginx web server installed and managed by systemd. Running curl -I 127.0.0.1:80 returns curl: (7) Failed to connect to localhost port 80: Connection refused , fix it so when you curl you get the default Nginx page.

## Problem Analysis
### Potential Causes
1. **Nginx Service Not Running**: The Nginx service may not be running, which would prevent it from accepting connections on port 80.
2. **Firewall Blocking Port 80**: A firewall may be blocking incoming connections on port 80, preventing access to the Nginx server.
3. **Nginx Configuration Issues**: There may be issues with the Nginx configuration files that prevent the server from starting properly.

## Root Cause
1. Checking the status of the Nginx service reveals that it has failed to start due to syntax errors in the configuration file.
```bash
admin@i-07534170c66bba5dc:~$ sudo systemctl status nginx
● nginx.service - The NGINX HTTP and reverse proxy server
     Loaded: loaded (/etc/systemd/system/nginx.service; enabled; vendor preset: enabled)
     Active: failed (Result: exit-code) since Thu 2025-12-18 08:24:01 UTC; 3min 5s ago
        CPU: 28ms

Dec 18 08:24:01 i-07534170c66bba5dc systemd[1]: Starting The NGINX HTTP and reverse proxy server...
Dec 18 08:24:01 i-07534170c66bba5dc nginx[573]: nginx: [emerg] unexpected ";" in /etc/nginx/sites-enabl> # This is the first root cause
Dec 18 08:24:01 i-07534170c66bba5dc nginx[573]: nginx: configuration file /etc/nginx/nginx.conf test fa>
Dec 18 08:24:01 i-07534170c66bba5dc systemd[1]: nginx.service: Control process exited, code=exited, sta>
Dec 18 08:24:01 i-07534170c66bba5dc systemd[1]: nginx.service: Failed with result 'exit-code'.
Dec 18 08:24:01 i-07534170c66bba5dc systemd[1]: Failed to start The NGINX HTTP and reverse proxy server.
```

2. Maximum number of File Descriptors reached. The service unit file has a LimitNOFILE setting of 10, which is too low for Nginx to operate correctly.
```bash
less /var/log/nginx/error.log
2022/09/11 16:26:27 [crit] 5801#5801: *23 open() "/var/www/html/index.nginx-debian.html" failed (24: Too many open files), client: 127.0.0.1, server: _, request: "GET / HTTP/1.1", host: "localhost:80"
2022/09/11 16:26:28 [crit] 5801#5801: accept4() failed (24: Too many open files)
```
```bash
sudo systemctl show nginx | grep LimitNOFILE
LimitNOFILE=10
```
or, you can check with:
```bash
cat /proc/$(pgrep nginx)/limits | grep "Max open files"
Max open files            10                 10                 files
```
The unexpected semicolon in the Nginx configuration file and the low LimitNOFILE setting are the root causes preventing Nginx from starting and serving requests.
## Solution Steps
1. **Delete the semi-colon in the Nginx configuration file**:
   - Open the file /etc/nginx/sites-enabled/default in a text editor with sudo privileges.
   - Remove the unexpected semicolon (;) that is causing the syntax error.
   - Save and close the file.
   - Restart the Nginx service with `sudo systemctl restart
2. **Increase the LimitNOFILE setting in the Nginx service unit**:
   - Open the file /lib/systemd/system/nginx.service
   - Locate the line that starts with LimitNO
   - Change the value from 10 to 10240
   - Save and close the file.
   - Reload the systemd daemon to apply the changes: `sudo systemctl daemon-reload`
   - Restart the Nginx service with `sudo systemctl restart nginx`
3. **Verify the Nginx service is running**:
   - Check the status of the Nginx service with `sudo systemctl status nginx`
   - Ensure that it is active and running without errors.
   - Test the Nginx server by running `curl -I localhost:80` to confirm that it    returns the default Nginx page.