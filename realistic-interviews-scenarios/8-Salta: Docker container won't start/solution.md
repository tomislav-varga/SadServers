# Solution for Salta: Docker container won't start
## Description:
There's a "dockerized" Node.js web application in the /home/admin/app directory. Create a Docker container so you get a web app on port :8888 and can curl to it. For the solution to be valid, there should be only one running Docker container.

## Investigation
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

3. A Nginx server is listening in port 8888, causing a port conflict on the host machine. This will prevent the application from starting correctly.
```bash
sudo ss -tulnp | grep :8888
tcp   LISTEN 0      511                          0.0.0.0:8888       0.0.0.0:*    users:(("nginx",pid=606,fd=6),("nginx",pid=605,fd=6),("nginx",pid=604,fd=6))
tcp   LISTEN 0      511                             [::]:8888          [::]:*    users:(("nginx",pid=606,fd=7),("nginx",pid=605,fd=7),("nginx",pid=604,fd=7))

```

### Root Cause
The incorrect exposed port and the mismatch in the application file name prevent the application from starting correctly. 

The presence of the Nginx server listening on port 8888 also creates a conflict that needs to be resolved.

## Solution Steps
1. **Update the Dockerfile**:
   - Open the Dockerfile located in /home/admin/app in a text editor.
   - Change the line `EXPOSE 8880` to `EXPOSE 8888`.
   - Change the line `CMD [ "node", "serve.js" ]` to `CMD [ "node", "server.js" ]`.
   - Save and close the Dockerfile.
2. **Build the Docker Image**:
   - Navigate to the /home/admin/app directory.
   - Run the command: `sudo docker build -t node-app .`
3. **Stop the Nginx Server**:
   - Run the command: `sudo systemctl stop nginx`
4. **Run the Docker Container**:
   - Start a new container with the correct port mapping: `sudo docker run -d -p 8888:8888 --name my-running-app node-app`

## Verification
After completing the above steps, run:
```bash
curl localhost:8888
```
You should receive the response `Hello World!`, indicating that the Docker container is running correctly and the application is accessible on port 8888`.


