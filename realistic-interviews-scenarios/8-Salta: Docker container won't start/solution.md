# Solution for Salta: Docker container won't start
## Description:
There's a "dockerized" Node.js web application in the /home/admin/app directory. Create a Docker container so you get a web app on port :8888 and can curl to it. For the solution to be valid, there should be only one running Docker container.

## Problem Analysis
### Potential Causes
1. **Port Conflict**: Another service may already be using port 8888, preventing the Docker container from binding to that port.
2. **Wrong Port Mapping**: The Docker container may not be correctly configured to map the internal application port to the host's port 8888.
3. **Dockerfile Issues**: The Dockerfile may have errors or misconfigurations that prevent the application from starting correctly within the container.
4. **Application Issues**: The Node.js application itself may have issues that prevent it from starting properly.

## Root Cause
1. Checking the Dockerfile in /home/admin/app reveals that the exposed port is 8880, not 8888. This means that the Docker container will only be accessible on port 8880 unless explicitly mapped otherwise.
2. Additionally, there is a mismatch in the CMD instruction of the Dockerfile, which specifies to run `node server.js`, but the actual application file is named `serve.js`. This will cause the application to fail to start within the container.
```bash
# most recent node (security patches) and alpine (minimal, adds to security, possible libc issues)
FROM node:15.7-alpine

# Create app directory & copy app files
WORKDIR /usr/src/app

# we copy first package.json only, so we take advantage of cached Docker layers
COPY ./package*.json ./

# RUN npm ci --only=production
RUN npm install

# Copy app source
COPY ./* ./

# port used by this app
EXPOSE 8880 # wrong port, should be 8888

# command to run
CMD [ "node", "serve.js" ] # name of the file is serve.js, not server.js like in the app folder
```
3. **A Nginx server** is listening in port 8888, causing a port conflict on the host machine. This will prevent the application from starting correctly.
```bash
sudo lsof -i :8888
COMMAND   PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
nginx   12345 root    6u  IPv4  123456      0t0  TCP *:8888 (LISTEN)
nginx   12346 www-data  6u  IPv4  123456      0t0  TCP *:8888 (LISTEN)
```

The incorrect exposed port and the mismatch in the application file name are the root causes preventing the Docker container from starting correctly and being accessible on port 8888.
Plus, the Nginx server is causing a port conflict.
## Solution Steps
1. **Update the Dockerfile**:
   - Open the Dockerfile located in /home/admin/app in a text editor.
   - Change the line `EXPOSE 8880` to `EXPOSE 8888`.
   - Change the line `CMD [ "node", "server.js" ]` to `CMD [ "node", "serve.js" ]`.
   - Save and close the Dockerfile.
2. **Build the Docker Image**:
   - Navigate to the /home/admin/app directory.
   - Run the command: `sudo docker build -t my-node-app .`
3. **Stop the Nginx Server**:
   - Run the command: `sudo systemctl stop nginx`
4. **Run the Docker Container**:
   - Stop any existing containers that may be running: `sudo docker ps -q | xargs -r sudo docker stop`
   - Start a new container with the correct port mapping: `sudo docker run -d -p 8888:8888 --name my-running-app my-node`
