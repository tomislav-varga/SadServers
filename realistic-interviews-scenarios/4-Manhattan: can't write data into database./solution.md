# Solution for Manhattan: can't write data into database.
## Description
Your objective is to be able to insert a row in an existing Postgres database. The issue is not specific to Postgres and you don't need to know details about it (although it may help).

Helpful Postgres information: it's a service that listens to a port (:5432) and writes to disk in a data directory, the location of which is defined in the data_directory parameter of the configuration file /etc/postgresql/14/main/postgresql.conf. In our case Postgres is managed by systemd as a unit with name postgresql.

Test: (from default admin user) sudo -u postgres psql -c "insert into persons(name) values ('jane smith');" -d dt

Should return:INSERT 0 1

output of the insert command:
```bash
sudo -u postgres psql -c "insert into persons(name) values ('jane smith');" -d dt
psql: error: connection to server on socket "/var/run/postgresql/.s.PGSQL.5432" failed: No such file or directory
        Is the server running locally and accepting connections on that socket?
```
## Problem Analysis
### Potential Causes
1. **PostgreSQL Service Not Running**: The error message indicates that the client cannot connect to the server, which may be because the PostgreSQL service is not running.
2. **Disk Space Issues**: If the disk where PostgreSQL is trying to write data is full, it may prevent the server from starting or accepting connections.
3. **Configuration Issues**: Incorrect configuration settings in the PostgreSQL configuration files could prevent the server from starting properly.
4. **Permission Issues**: The PostgreSQL user may not have the necessary permissions to access the data directory or other required files.
### Root Cause
Revealed after running the command:
```bash
sudo systemctl start postgres*
Job for postgresql@14-main.service failed because the service did not take the steps required by its unit configuration.
See "systemctl status postgresql@14-main.service" and "journalctl -xe" for details.

journalctl -xe
Dec 16 12:16:14 i-0c1675530628264d8 systemd[1]: Starting PostgreSQL Cluster 14-main...
-- Subject: A start job for unit postgresql@14-main.service has begun execution
-- Defined-By: systemd
-- Support: https://www.debian.org/support
--
-- A start job for unit postgresql@14-main.service has begun execution.
--
-- The job identifier is 851.
Dec 16 12:16:14 i-0c1675530628264d8 postgresql@14-main[1049]: Error: /usr/lib/postgresql/14/bin/pg_ctl /usr/lib/postgresql/14/bin/pg_ctl start -D /opt/pgdata/main -l /var/log/postgresql/postgresql-14-main.log -s
Dec 16 12:16:14 i-0c1675530628264d8 postgresql@14-main[1049]: 2025-12-16 12:16:14.597 UTC [1054] FATAL:  could not create lock file "postmaster.pid": No space left on device #This is the root cause
Dec 16 12:16:14 i-0c1675530628264d8 postgresql@14-main[1049]: pg_ctl: could not start server
Dec 16 12:16:14 i-0c1675530628264d8 postgresql@14-main[1049]: Examine the log output.
Dec 16 12:16:14 i-0c1675530628264d8 systemd[1]: postgresql@14-main.service: Can't open PID file /run/postgresql/14-main.pid (yet?) after start: No such file or directory
Dec 16 12:16:14 i-0c1675530628264d8 systemd[1]: postgresql@14-main.service: Failed with result 'protocol'.
-- Subject: Unit failed
-- Defined-By: systemd
-- Support: https://www.debian.org/support
--
-- The unit postgresql@14-main.service has entered the 'failed' state with result 'protocol'.
Dec 16 12:16:14 i-0c1675530628264d8 systemd[1]: Failed to start PostgreSQL Cluster 14-main.
-- Subject: A start job for unit postgresql@14-main.service has failed
-- Defined-By: systemd
-- Support: https://www.debian.org/support
````
The root cause is "No space left on device" error when Postgres tries to create its lock file.
```bash
df -h
Filesystem       Size  Used Avail Use% Mounted on
udev             224M     0  224M   0% /dev
tmpfs             47M  1.6M   46M   4% /run
/dev/nvme1n1p1   7.7G  1.2G  6.1G  17% /
tmpfs            233M     0  233M   0% /dev/shm
tmpfs            5.0M     0  5.0M   0% /run/lock
tmpfs            233M     0  233M   0% /sys/fs/cgroup
/dev/nvme1n1p15  124M  278K  124M   1% /boot/efi
/dev/nvme0n1     8.0G  8.0G   28K 100% /opt/pgdata #This is the problematic mount point
tmpfs             47M     0   47M   0% /run/user/1000
````
The /opt/pgdata mount point is 100% full, which prevents Postgres from writing data to its data directory.
## Solution Steps
1. **Free Up Space on /opt/pgdata**:
   - Identify and remove unnecessary files or move them to another location with sufficient space.
   - You can use commands like `du -sh /opt/pgdata/*` to identify large files or directories.
   - Once the space is freed up, you can restart the Postgres service:
     ```bash
     sudo systemctl start postgresql
     ```        
2. **Verify PostgreSQL Service Status**:
        - Check if the PostgreSQL service is running:
          ```bash
          sudo systemctl status postgresql
          ```
        - Ensure there are no errors in the logs:
          ```bash
          sudo journalctl -u postgresql
          ```
3. **Test Data Insertion**:
```bash
sudo -u postgres psql -c "insert into persons(name) values ('jane smith');" -d dt
INSERT 0 1
```   
4. **Verify Data Insertion**:- If the insert command returns `INSERT 0 1`, the issue is resolved`
