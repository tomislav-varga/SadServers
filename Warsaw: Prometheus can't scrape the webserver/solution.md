# Solution for Warsaw: Prometheus can't scrape the webserver
## Description
A developer created a golang application that is exposing the /metrics endpoint. They have a problem with scraping the metrics from the application. They asked you to help find the problem.

Full source code of the application is available at the /home/admin/app directory. 

## Problem Analysis
```bash
 curl -v http://localhost:9000/metrics
*   Trying 127.0.0.1:9000...
* Connected to localhost (127.0.0.1) port 9000 (#0)
> GET /metrics HTTP/1.1
> Host: localhost:9000
> User-Agent: curl/7.74.0
> Accept: */*
>
* Mark bundle as not supporting multiuse
< HTTP/1.1 405 Method Not Allowed
< Date: Wed, 14 Jan 2026 02:24:40 GMT
< Content-Length: 0
<
* Connection #0 to host localhost left intact
```
The application is responding with a `405 Method Not Allowed` status code when trying to access the `/metrics` endpoint using the `GET` method. This indicates that the server is not configured to handle `GET` requests for this endpoint.

Looking at the source code of the application located in `/home/admin/app`, we find the following relevant snippet:
```go
package main

import (
        "fmt"
        "log"
        "net/http"

        "github.com/gorilla/mux"
        "github.com/prometheus/client_golang/prometheus/promhttp"
)

func main() {
        router := mux.NewRouter()

        router.Handle("/metrics", promhttp.Handler()).Methods("POST")

        fmt.Println("Serving Prometheus metrics on http://localhost:9000/metrics")
        err := http.ListenAndServe(":9000", router)
        if err != nil {
                log.Fatal(err)
        }
}
```
The code snippet shows that the `/metrics` endpoint is configured to handle only `POST` requests:
```go
router.Handle("/metrics", promhttp.Handler()).Methods("POST")
```
This is incorrect because Prometheus expects to scrape metrics using `GET` requests.

### Root Cause
**Incorrect HTTP Method Configuration**: The `/metrics` endpoint is incorrectly configured to accept only `POST` requests instead of `GET` requests.

## Solution
To resolve the issue, we need to modify the code to allow `GET` requests for the `/metrics` endpoint. We can do this by changing the `Methods` call to include `GET` instead of `POST`.
1. Update the code to allow `GET` requests:
```go
router.Handle("/metrics", promhttp.Handler()).Methods("GET")
```
2. Save the changes to the file.
3. Since the app runs as a Docker container, we need to rebuild the Docker image and restart the container to apply the changes.
```bash
cd /home/admin/app
```
The Dockerfile has an extenstion .app, so we need to specify it during the build process.
```bash
docker stop  golang-app
docker rm golang-app
docker build --no-cache -t app -f Dockerfile.app .
docker run -d --name app-container -p 9000:9000 app
```

## Verification
After making these changes and restarting the application, we can verify that the `/metrics` endpoint is now accessible using the `GET` method:
```bash
curl -v  http://localhost:9000/metrics | head -1
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0*   Trying 127.0.0.1:9000...
* Connected to localhost (127.0.0.1) port 9000 (#0)
> GET /metrics HTTP/1.1
> Host: localhost:9000
> User-Agent: curl/7.74.0
> Accept: */*
>
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< Content-Type: text/plain; version=0.0.4; charset=utf-8; escaping=values
< Date: Tue, 27 Jan 2026 03:53:00 GMT
< Transfer-Encoding: chunked
<
{ [3939 bytes data]
# HELP go_gc_duration_seconds A summary of the pause duration of garbage collection cycles.
100  5876    0  5876    0     0  5738k      0 --:--:-- --:--:-- --:--:-- 5738k
* Connection #0 to host localhost left intact
```