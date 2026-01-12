# Solution for Kampot: A New Port
## Description
A Python app serving simulated bank data runs as root and listens on port 20280. The app is managed by supervisor and cannot be stopped or reconfigured to use a different port.

An internal legacy monitoring system expects the service to be available on port 80, but the app is hardcoded to 20280 for security and legacy reasons. Your task is to make the service accessible on port 80 locally.

## Initial Investigation
First, verify that the Python app is running and listening on port 20280.
```bash
ps aux | sed -n '1p;/python/p' # Shows python process including headers
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         695  0.2  2.0  39284  9460 ?        Ss   04:45   0:00 /usr/bin/python3 /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
root         776  0.0  3.3  36852 15468 ?        Ss   04:45   0:00 /usr/bin/python3 /usr/share/unattended-upgrades/unattended-upgrade-shutdown --wait-for-signal
root         906  0.2  4.2  41388 19420 ?        S    04:45   0:00 python3 /home/admin/bank_app.py
admin       1751  0.0  0.4   4044  2164 pts/0    S+   04:47   0:00 sed -n 1p;/python/p
```
Check open ports:
```bash
sudo ss -tulnp | grep python
tcp   LISTEN 0      128            0.0.0.0:20280      0.0.0.0:*    users:(("python3",pid=923,fd=3))
```
The app is confirmed to be running and listening on port 20280.
Is there any process listening on port 80?
```bash
sudo ss -tulnp | grep :80
```
No output indicates that no process is listening on port 80.


## Solution
### Option 1: Using iptables to Redirect Traffic
You can use `iptables` to redirect traffic from port 80 to port 20280.
First, add the following rule that redirects incoming TCP traffic on port 80 to port 20280:
```bash
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 20280
```
To redirect outgoing traffic from local processes to port 80, use:
```bash
sudo iptables -t nat -A OUTPUT -p tcp --dport 80 -j REDIRECT --to-port 20280
```

### Option 2: Using nginx as a Reverse Proxy
Install nginx if it's not already installed:
```bash
sudo apt-get update
sudo apt-get install nginx
``` 
Create an nginx configuration file to set up a reverse proxy:
```bash
sudo vim /etc/nginx/sites-available/bank_proxy
```
Add the following configuration to the file:
```nginx
server {
    listen 80;

    location / {
        proxy_pass http://127.0.0.1:20280;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```
**Note:** If there is a default nginx configuration file, you may want to disable it to avoid conflicts:
```bash
sudo rm /etc/nginx/sites-enabled/default.conf
```
Adding a new server block to the sites-available directory will work fine as long as there are no conflicting server blocks listening on the same port.

**Alternatively, you can set the new configuration as the default by modifying the server block:**
```nginx
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    location / {
        proxy_pass http://127.0.0.1:20280;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```
Enable the new site and restart nginx`:
```bash
sudo ln -s /etc/nginx/sites-available/bank_proxy /etc/nginx/sites-enabled/
sudo systemctl restart nginx
```

### Option 3: Using systemd socket activation
This is another method to forward traffic from port 80 to the Python app running on port 20280 using systemd socket activation. 
However, it will not work since a supervisor is already managing the Python app:
```bash
 sudo ps aux | grep python
root         707  0.0  2.4  39284 11252 ?        Ss   04:53   0:00 /usr/bin/python3 /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
```

## Verification
Test the setup by accessing the service on port 80:
```bash
curl http://localhost:80/accounts
```
You should see the bank account data served by the Python app running on port 20280.
