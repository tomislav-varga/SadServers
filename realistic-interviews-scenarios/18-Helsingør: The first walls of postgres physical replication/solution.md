# Solution for "Helsingør": The first walls of postgres physical replication
## Description
You're setting up a PostgreSQL database with replication, you decided to use Docker along with Docker Compose to make it easier to manage and test, after a few hours of work you finished the job and the master database is up and running, but you're having trouble with the replica.

You need to figure out what's wrong with the replica and fix it.

Since you are using Docker Compose, you can check the status of the running containers using docker compose ps or docker ps will do the job too). You may also want to check the logs of the containers.

All definition for the containers are inside the docker-compose.yml file. You can stand up the environment by running docker compose up -d and set it down by running `docker compose down`.

If you make any change to the docker-compose.yml file, you can restart the containers by running docker compose up -d --force-recreate.

## Problem Analysis
Checking the status of the running containers using `docker ps` shows that the replica container is not healthy:
```bash
docker ps
CONTAINER ID   IMAGE         COMMAND                  CREATED         STATUS                          PORTS                                       NAMES
98e1b8d4a341   postgres:16   "docker-entrypoint.s…"   21 months ago   Restarting (1) 12 seconds ago                                               postgres-db-replica
e3810a53aa68   postgres:16   "docker-entrypoint.s…"   21 months ago   Up 2 minutes (healthy)          0.0.0.0:5432->5432/tcp, :::5432->5432/tcp   postgres-db-master
```

The replica container is in a restarting loop. Checking the logs of the replica container reveals the following:
```bash
docker logs postgres-db-replica
Backup done, starting replica...
2026-01-16 15:31:11.221 GMT [1] LOG:  starting PostgreSQL 16.2 (Debian 16.2-1.pgdg120+2) on x86_64-pc-linux-gnu, compiled by gcc (Debian 12.2.0-14) 12.2.0, 64-bit
2026-01-16 15:31:11.222 GMT [1] LOG:  listening on IPv4 address "0.0.0.0", port 5432
2026-01-16 15:31:11.222 GMT [1] LOG:  listening on IPv6 address "::", port 5432
2026-01-16 15:31:11.229 GMT [1] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
2026-01-16 15:31:11.239 GMT [15] LOG:  database system was interrupted; last known up at 2026-01-16 15:31:10 GMT
2026-01-16 15:31:11.257 GMT [15] LOG:  entering standby mode
2026-01-16 15:31:11.257 GMT [15] LOG:  starting backup recovery with redo LSN 0/1F000028, checkpoint LSN 0/1F000060, on timeline ID 1
2026-01-16 15:31:11.263 GMT [15] FATAL:  recovery aborted because of insufficient parameter settings
2026-01-16 15:31:11.263 GMT [15] DETAIL:  max_connections = 80 is a lower setting than on the primary server, where its value was 100.
2026-01-16 15:31:11.263 GMT [15] HINT:  You can restart the server after making the necessary configuration changes.
2026-01-16 15:31:11.265 GMT [1] LOG:  startup process (PID 15) exited with exit code 1
2026-01-16 15:31:11.265 GMT [1] LOG:  aborting startup due to startup process failure
2026-01-16 15:31:11.266 GMT [1] LOG:  database system is shut down
rm: cannot remove '/var/lib/postgresql/data/': Device or resource busy
waiting for checkpoint
30743/30743 kB (100%), 0/1 tablespace
30743/30743 kB (100%), 1/1 tablespace
Backup done, starting replica...
2026-01-16 15:32:04.400 GMT [1] LOG:  starting PostgreSQL 16.2 (Debian 16.2-1.pgdg120+2) on x86_64-pc-linux-gnu, compiled by gcc (Debian 12.2.0-14) 12.2.0, 64-bit
2026-01-16 15:32:04.401 GMT [1] LOG:  listening on IPv4 address "0.0.0.0", port 5432
2026-01-16 15:32:04.401 GMT [1] LOG:  listening on IPv6 address "::", port 5432
2026-01-16 15:32:04.408 GMT [1] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
2026-01-16 15:32:04.417 GMT [15] LOG:  database system was interrupted; last known up at 2026-01-16 15:32:03 GMT
2026-01-16 15:32:04.435 GMT [15] LOG:  entering standby mode
2026-01-16 15:32:04.436 GMT [15] LOG:  starting backup recovery with redo LSN 0/21000028, checkpoint LSN 0/21000060, on timeline ID 1
2026-01-16 15:32:04.441 GMT [15] FATAL:  recovery aborted because of insufficient parameter settings
2026-01-16 15:32:04.441 GMT [15] DETAIL:  max_connections = 80 is a lower setting than on the primary server, where its value was 100.
2026-01-16 15:32:04.441 GMT [15] HINT:  You can restart the server after making the necessary configuration changes.
2026-01-16 15:32:04.449 GMT [1] LOG:  startup process (PID 15) exited with exit code 1
2026-01-16 15:32:04.449 GMT [1] LOG:  aborting startup due to startup process failure
2026-01-16 15:32:04.449 GMT [1] LOG:  database system is shut down
```
The key part of the log is:
```2026-01-16 15:32:04.441 GMT [15] FATAL:  recovery aborted because of insufficient parameter settings
2026-01-16 15:32:04.441 GMT [15] DETAIL:  max_connections = 80 is a lower setting than on the primary server, where its value was 100.
2026-01-16 15:32:04.441 GMT [15] HINT:  You can restart the server after making the necessary configuration changes.
```
### Root Cause
**Mismatched Configuration Parameters**: The replica PostgreSQL instance has four parameters that are different from those on the master instance. To resolve the issue, these parameters need to be aligned with those of the master.

## Solution
Starting with the first issue regarding `max_connections`:
1. Open the `postgres/replica/postgres.conf` file in a text editor.
2. Locate the `max_connections` parameter and change its value from 80 to 100:
```conf
max_connections = 100
```
3. Save the changes to the `postgres.conf` file.
4. Restart the replica container to apply the new configuration by running:
```bash
docker compose restart postgres-db-replica
```

Run `docker logs postgres-db-replica` again to see the logs:
```bash
2026-01-16 15:38:05.910 GMT [1] LOG:  starting PostgreSQL 16.2 (Debian 16.2-1.pgdg120+2) on x86_64-pc-linux-gnu, compiled by gcc (Debian 12.2.0-14) 12.2.0, 64-bit
2026-01-16 15:38:05.912 GMT [1] LOG:  listening on IPv4 address "0.0.0.0", port 5432
2026-01-16 15:38:05.912 GMT [1] LOG:  listening on IPv6 address "::", port 5432
2026-01-16 15:38:05.919 GMT [1] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
2026-01-16 15:38:05.928 GMT [14] LOG:  database system was interrupted; last known up at 2026-01-16 15:38:05 GMT
2026-01-16 15:38:05.946 GMT [14] LOG:  entering standby mode
2026-01-16 15:38:05.946 GMT [14] LOG:  starting backup recovery with redo LSN 0/36000028, checkpoint LSN 0/36000060, on timeline ID 1
2026-01-16 15:38:05.952 GMT [14] FATAL:  recovery aborted because of insufficient parameter settings
2026-01-16 15:38:05.952 GMT [14] DETAIL:  max_worker_processes = 4 is a lower setting than on the primary server, where its value was 8.
2026-01-16 15:38:05.952 GMT [14] HINT:  You can restart the server after making the necessary configuration changes.
2026-01-16 15:38:05.954 GMT [1] LOG:  startup process (PID 14) exited with exit code 1
2026-01-16 15:38:05.954 GMT [1] LOG:  aborting startup due to startup process failure
2026-01-16 15:38:05.955 GMT [1] LOG:  database system is shut down
```
To resolve this second issue, we need to update the `max_worker_processes` setting in the replica's configuration to match that of the master.
1. Open the `postgres/replica/postgres.conf` file in a text editor.
2. Locate the `max_worker_processes` parameter and change its value from 4 to 8:
```conf
max_worker_processes = 8
```
3. Save the changes to the `postgres.conf` file.
4. Restart the replica container to apply the new configuration by running:
```bash
docker compose restart postgres-db-replica
```

Third issue regarding `max_wal_senders`:
```bash
docker logs postgres-db-replica
2026-01-16 15:42:51.560 GMT [1] LOG:  starting PostgreSQL 16.2 (Debian 16.2-1.pgdg120+2) on x86_64-pc-linux-gnu, compiled by gcc (Debian 12.2.0-14) 12.2.0, 64-bit
2026-01-16 15:42:51.561 GMT [1] LOG:  listening on IPv4 address "0.0.0.0", port 5432
2026-01-16 15:42:51.561 GMT [1] LOG:  listening on IPv6 address "::", port 5432
2026-01-16 15:42:51.568 GMT [1] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
2026-01-16 15:42:51.576 GMT [15] LOG:  database system was interrupted; last known up at 2026-01-16 15:42:51 GMT
2026-01-16 15:42:51.593 GMT [15] LOG:  entering standby mode
2026-01-16 15:42:51.594 GMT [15] LOG:  starting backup recovery with redo LSN 0/49000028, checkpoint LSN 0/49000060, on timeline ID 1
2026-01-16 15:42:51.600 GMT [15] FATAL:  recovery aborted because of insufficient parameter settings
2026-01-16 15:42:51.600 GMT [15] DETAIL:  max_wal_senders = 5 is a lower setting than on the primary server, where its value was 10.
2026-01-16 15:42:51.600 GMT [15] HINT:  You can restart the server after making the necessary configuration changes.
2026-01-16 15:42:51.602 GMT [1] LOG:  startup process (PID 15) exited with exit code 1
2026-01-16 15:42:51.602 GMT [1] LOG:  aborting startup due to startup process failure
2026-01-16 15:42:51.602 GMT [1] LOG:  database system is shut down
```
To resolve the third issue, align the replica’s max_wal_senders configuration with the master by following the previously outlined steps.

Last issue regarding `max_locks_per_transaction`:
```bash
docker logs postgres-db-replica
2026-01-16 15:45:12.067 GMT [1] LOG:  starting PostgreSQL 16.2 (Debian 16.2-1.pgdg120+2) on x86_64-pc-linux-gnu, compiled by gcc (Debian 12.2.0-14) 12.2.0, 64-bit
2026-01-16 15:45:12.068 GMT [1] LOG:  listening on IPv4 address "0.0.0.0", port 5432
2026-01-16 15:45:12.068 GMT [1] LOG:  listening on IPv6 address "::", port 5432
2026-01-16 15:45:12.075 GMT [1] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
2026-01-16 15:45:12.085 GMT [14] LOG:  database system was interrupted; last known up at 2026-01-16 15:45:11 GMT
2026-01-16 15:45:12.104 GMT [14] LOG:  entering standby mode
2026-01-16 15:45:12.105 GMT [14] LOG:  starting backup recovery with redo LSN 0/59000028, checkpoint LSN 0/59000060, on timeline ID 1
2026-01-16 15:45:12.110 GMT [14] FATAL:  recovery aborted because of insufficient parameter settings
2026-01-16 15:45:12.110 GMT [14] DETAIL:  max_locks_per_transaction = 32 is a lower setting than on the primary server, where its value was 64.
2026-01-16 15:45:12.110 GMT [14] HINT:  You can restart the server after making the necessary configuration changes.
2026-01-16 15:45:12.112 GMT [1] LOG:  startup process (PID 14) exited with exit code 1
2026-01-16 15:45:12.113 GMT [1] LOG:  aborting startup due to startup process failure
2026-01-16 15:45:12.113 GMT [1] LOG:  database system is shut down
```
Resolve the fourth issue by setting max_locks_per_transaction on the replica to 64, following the same procedure as before.

## Verification
After applying these configurations, the replica container should start successfully without entering a restarting loop. You can verify this by checking the status of the containers again:
```bash
docker ps
ìONTAINER ID   IMAGE         COMMAND                  CREATED         STATUS                             PORTS                                       NAMES
6f5966a4f2cf   postgres:16   "docker-entrypoint.s…"   9 minutes ago   Up 18 seconds (healthy)   0.0.0.0:5433->5432/tcp, :::5433->5432/tcp   postgres-db-replica
339f5d7c92b9   postgres:16   "docker-entrypoint.s…"   9 minutes ago   Up 9 minutes (healthy)             0.0.0.0:5432->5432/tcp, :::5432->5432/tcp   postgres-db-master
```

The replica container is now up and running. Checking the logs of the replica container shows database system is ready to accept read-only connections:
```bash
docker logs postgres-db-replica
2026-01-16 15:47:19.988 GMT [1] LOG:  starting PostgreSQL 16.2 (Debian 16.2-1.pgdg120+2) on x86_64-pc-linux-gnu, compiled by gcc (Debian 12.2.0-14) 12.2.0, 64-bit
2026-01-16 15:47:19.989 GMT [1] LOG:  listening on IPv4 address "0.0.0.0", port 5432
2026-01-16 15:47:19.989 GMT [1] LOG:  listening on IPv6 address "::", port 5432
2026-01-16 15:47:19.996 GMT [1] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
2026-01-16 15:47:20.005 GMT [14] LOG:  database system was interrupted; last known up at 2026-01-16 15:47:19 GMT
2026-01-16 15:47:20.023 GMT [14] LOG:  entering standby mode
2026-01-16 15:47:20.024 GMT [14] LOG:  starting backup recovery with redo LSN 0/62000028, checkpoint LSN 0/62000060, on timeline ID 1
2026-01-16 15:47:20.030 GMT [14] LOG:  redo starts at 0/62000028
2026-01-16 15:47:20.034 GMT [14] LOG:  completed backup recovery with redo LSN 0/62000028 and end LSN 0/62000100
2026-01-16 15:47:20.034 GMT [14] LOG:  consistent recovery state reached at 0/62000100
2026-01-16 15:47:20.034 GMT [1] LOG:  database system is ready to accept read-only connections
2026-01-16 15:47:20.051 GMT [15] LOG:  started streaming WAL from primary at 0/63000000 on timeline 1
```
Running the check.sh script under /home/admin/agent/ should return `OK`.