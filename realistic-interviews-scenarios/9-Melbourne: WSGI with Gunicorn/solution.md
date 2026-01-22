# Solution for Melbourne: WSGI with Gunicorn
## Description:
There is a Python WSGI web application file at /home/admin/wsgi.py , the purpose of which is to serve the string "Hello, world!". This file is served by a Gunicorn server which is fronted by an nginx server (both servers managed by systemd). So the flow of an HTTP request is: Web Client (curl) -> Nginx -> Gunicorn -> wsgi.py . The objective is to be able to curl the localhost (on default port :80) and get back "Hello, world!", using the current setup.

## Problem Analysis
### Potential Causes
1. **Socket File Misconfiguration**: The Gunicorn socket file may be misconfigured, leading to permission issues or incorrect paths that prevent Nginx from communicating with Gunicorn.
2. **Service User/Group Mismatch**: The user and group settings in the Gunicorn service file may not align with those in the socket file or Nginx configuration, causing permission denied errors.
3. **Nginx Configuration Issues**: The Nginx configuration may have incorrect paths or settings that prevent it from properly proxying requests to the Gunicorn socket.

## Root Cause
1. Nginx is not enabled and started when running the `systemctl status nginx` command.
Running `curl localhost` returns `curl: (7) Failed to connect to localhost port 80: Connection refused`
```bash
sudo systemctl status nginx
● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/lib/systemd/system/nginx.service; disabled; vendor preset: enabled)
     Active: inactive (dead)
       Docs: man:nginx(8)
```
2. The Gunicorn socket file is created with root ownership and permissions that allow read and write access to all users (`srw-rw-rw- 1 root root`), which is not secure. Additionally, Nginx runs under the `www-data` user, which may not have the necessary permissions to access the socket file owned by root and the file extension should be `.socket`.
```bash
srw-rw-rw- 1 root root 0 Dec 27 04:32 /run/gunicorn.sock
```
3. The Gunicorn service file specifies the group as `admin`, while Nginx runs under the `www-data` group. This mismatch can lead to permission issues when Nginx tries to access the Gunicorn socket.
```bash
[Unit]
Description=gunicorn daemon
Requires=gunicorn.socket
After=network.target

[Service]
User=admin
Group=admin
WorkingDirectory=/home/admin
ExecStart=/usr/local/bin/gunicorn \
          --bind unix:/run/gunicorn.sock \
          wsgi
Restart=on-failure

[Install]
WantedBy=multi-user.target
```
4. The Gunicorn service file lacks the `:application` suffix in the `ExecStart` command, which is necessary for Gunicorn to locate the WSGI application callable within the `wsgi.py` file.
```bash
ExecStart=/usr/local/bin/gunicorn \
          --bind unix:/run/gunicorn.sock \
          wsgi
```
## Solution
1. **Enable and Start Nginx**:
- Run the following commands to enable and start the Nginx service:
```bash
sudo systemctl enable nginx
sudo systemctl start nginx
```
2. **Update WSGI Python file**:
The file `wsgi.py` contains an error in the `application` function. The `Content-Length` header should be removed to allow the response to be sent correctly:
```python
def application(environ, start_response):
   start_response('200 OK', [('Content-Type', 'text/html'), ('Content-Length', '0'), ]) # This parameter should be removed
   return [b'Hello, world!']
```
```python
def application(environ, start_response):
      start_response('200 OK', [('Content-Type', 'text/html')])
      return [b'Hello, world!']
```
3. **Update Gunicorn Socket File**:
- Creat a new socket file by running  `sudo vim /etc/systemd/system/gunicorn.socket` to specify the correct user and group:
```bash 
[Unit]
Description=gunicorn socket

[Socket]
ListenStream=/run/gunicorn.socket
SocketUser=admin
SocketGroup=www-data
SocketMode=0660


[Install]
WantedBy=sockets.target
```
- Reload the systemd daemon and restart the Gunicorn socket:
```bash
sudo systemctl daemon-reload
sudo systemctl restart gunicorn.socket
```
4. **Update Gunicorn Service File**:
- Open the Gunicorn service file file by running  `sudo vim /etc/systemd/system/gunicorn.service` to set the correct group and specify the application callable:
```bash
[Unit]
Description=gunicorn daemon
Requires=gunicorn.socket
After=network.target

[Service]
User=admin
Group=www-data
WorkingDirectory=/home/admin
ExecStart=/usr/local/bin/gunicorn \
   --workers 3 \
   wsgi:application
Restart=on-failure

[Install]
WantedBy=multi-user.target
```
- Reload the systemd daemon and restart the Gunicorn service:
```bash
sudo systemctl daemon-reload
sudo systemctl restart gunicorn.service
```

## Verification
- Check the status of both Nginx and Gunicorn services to ensure they are active and running:
```bash
sudo systemctl status nginx
sudo systemctl status gunicorn
```
- Test the setup by curling localhost:
```bash
curl -s http://localhost
```
- You should receive the response "Hello, world!" indicating that the setup is functioning correctly.