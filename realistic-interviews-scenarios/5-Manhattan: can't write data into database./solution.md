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
Output of the insert command:
```bash
sudo -u postgres psql -c "insert into persons(name) values ('jane smith');" -d dt
psql: error: connection to server on socket "/var/run/postgresql/.s.PGSQL.5432" failed: No such file or directory
        Is the server running locally and accepting connections on that socket?
```

### Potential Causes
1. **PostgreSQL Service Not Running**: The error message indicates that the client cannot connect to the server, which may be because the PostgreSQL service is not running.
2. **Disk Space Issues**: If the disk where PostgreSQL is trying to write data is full, it may prevent the server from starting or accepting connections.
3. **Configuration Issues**: Incorrect configuration settings in the PostgreSQL configuration files could prevent the server from starting properly.
4. **Permission Issues**: The PostgreSQL user may not have the necessary permissions to access the data directory or other required files.

### Root Cause
**Disk Space Issues**: The PostgreSQL service is failing to start because the disk where its data directory is located is full, preventing it from creating necessary files.
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
```
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
```
The /opt/pgdata mount point is 100% full, which prevents Postgres from writing data to its data directory.

## Solution Steps
1. **Free Up Space on /opt/pgdata**:
  - Identify and remove unnecessary files or move them to another location with sufficient space.
  - Run `sudo du -sh /opt/pgdata/*` to identify large files or directories:
```bash
  sudo du -sh /opt/pgdata/*
  4.0K    /opt/pgdata/deleteme
  7.0G    /opt/pgdata/file1.bk
  923M    /opt/pgdata/file2.bk
  488K    /opt/pgdata/file3.bk
  50M     /opt/pgdata/main
  ```
  - Remove or move large unnecessary files`:
```bash
  sudo rm /opt/pgdata/file1.bk
  sudo rm /opt/pgdata/file2.bk
  ```
  - Once the space is freed up, you can restart the Postgres service:
```bash
  sudo systemctl restart postgresql
  ```        
2. **Verify PostgreSQL Service Status**:
  - Check if the PostgreSQL service is running:
```bash
  sudo systemctl status postgresql
  ● postgresql.service - PostgreSQL RDBMS
   Loaded: loaded (/lib/systemd/system/postgresql.service; enabled; vendor preset: enabled)
   Active: active (exited) since Tue 2026-01-13 07:30:43 UTC; 14s ago
  Process: 1000 ExecStart=/bin/true (code=exited, status=0/SUCCESS)
  Main PID: 1000 (code=exited, status=0/SUCCESS)

  Jan 13 07:30:43 i-03ad436595fc8adc6 systemd[1]: Starting PostgreSQL RDBMS...
  Jan 13 07:30:43 i-03ad436595fc8adc6 systemd[1]: Started PostgreSQL RDBMS.
  ```
  - Ensure there are no errors in the logs:
```bash
  sudo journalctl -u postgresql
  -- Logs begin at Tue 2026-01-13 07:22:57 UTC, end at Tue 2026-01-13 07:31:43 UTC. --
  Jan 13 07:23:53 i-03ad436595fc8adc6 systemd[1]: Starting PostgreSQL RDBMS...
  Jan 13 07:23:53 i-03ad436595fc8adc6 systemd[1]: Started PostgreSQL RDBMS.
  Jan 13 07:30:41 i-03ad436595fc8adc6 systemd[1]: postgresql.service: Succeeded.
  Jan 13 07:30:41 i-03ad436595fc8adc6 systemd[1]: Stopped PostgreSQL RDBMS.
  Jan 13 07:30:41 i-03ad436595fc8adc6 systemd[1]: Stopping PostgreSQL RDBMS...
  Jan 13 07:30:43 i-03ad436595fc8adc6 systemd[1]: Starting PostgreSQL RDBMS...
  Jan 13 07:30:43 i-03ad436595fc8adc6 systemd[1]: Started PostgreSQL RDBMS.
  ```

## Verification
Rerun the insert command to verify that data can now be written to the database:
```bash
sudo -u postgres psql -c "insert into persons(name) values ('jane smith');" -d dt
INSERT 0 1
```   
If the insert command returns `INSERT 0 1`, the issue is resolved`
