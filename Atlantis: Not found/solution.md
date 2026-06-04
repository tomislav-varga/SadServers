# Solution for Atlantis: Not found
## Description
There is a small "C" application in the /home/admin/app directory. Create the Docker container "app" with a small footprint and minimalistic so you get a hello binary that returns a greeting in Atlantean (Docker multi-stage build). The binary application is automatically called when running docker run app.

## Problem Analysis
Looking at the contents of the `/home/admin/app` directory, we find a `Dockerfile` which contains the instructions to build the Docker image for the application. The `Dockerfile` is as follows:
```Dockerfile
# STAGE 1
FROM    debian:13 AS builder
RUN     apt-get update && apt-get install -y gcc
WORKDIR /src
COPY    hello.c .
RUN     gcc -o hello hello.c

# STAGE 2
FROM    alpine:3.20
COPY    --from=builder /src/hello /usr/local/bin/hello
CMD     ["/usr/local/bin/hello"]
```
The `Dockerfile` uses a multi-stage build to create a Docker image. The building stage is using `debian:13` as the base image, which is relatively large. To create a smaller image, we can use a more minimal base image for the builder stage, such as `alpine`, which is known for its small footprint.  
By default, the `gcc` package is not available in the `alpine` image, which leads to compilation issues. We can use `musl-dev` from the Alpine repositories to compile the C application.

## Solution
To create a smaller Docker image, we can modify the `Dockerfile` to use `alpine` as the base image for the builder stage and install the necessary packages to compile the C application.  
Here is the updated `Dockerfile`:
```Dockerfile
FROM alpine:3.20 AS builder
RUN apk add --no-cache gcc musl-dev
WORKDIR /src
COPY hello.c .
RUN gcc -o hello hello.c

FROM alpine:3.20
COPY --from=builder /src/hello /usr/local/bin/hello
CMD ["/usr/local/bin/hello"]
```
### Steps to Implement the Solution
1. Update the `Dockerfile` with the above content.
2. Build the Docker image using the following command:
```bash
docker build -t app -f Dockerfile .
```
3. Run the Docker container using the following command:
```bash
docker run app
```

## Verification
After running the container, you should see the output of the `hello` binary, which should return a greeting in Atlantean: `SOO-puhk`.  
If the output is correct, it indicates that the application is working as expected and the Docker image has been successfully built with a smaller footprint.