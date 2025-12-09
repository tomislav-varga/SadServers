# Check PostgreSQL service status
sudo systemctl status postgresql
# Check all PostgreSQL related services
sudo systemctl status post*
# Connect to the PostgreSQL database using the provided credentials to see the error message
PGPASSWORD=app1user
psql -h 127.0.0.1 -d app1 -U app1user -c '\q'
# Get the path of the PostgreSQL configuration file
systemctl status post*
● postgresql@13-main.service - PostgreSQL Cluster 13-main
     Loaded: loaded (/lib/systemd/system/postgresql@.service; enabled-runtime; vendor preset: enabled)
     Active: active (running) since Tue 2025-12-09 16:11:47 UTC; 19min ago
    Process: 1133 ExecReload=/usr/bin/pg_ctlcluster --skip-systemctl-redirect 13-main reload (code=exited, status=0/SUCCESS)
   Main PID: 639 (postgres)
      Tasks: 7 (limit: 521)
     Memory: 39.2M
        CPU: 621ms
     CGroup: /system.slice/system-postgresql.slice/postgresql@13-main.service
             ├─639 /usr/lib/postgresql/13/bin/postgres -D /var/lib/postgresql/13/main -c config_file=/etc/postgresql/13/main/postgresql.conf
             ├─649 postgres: 13/main: checkpointer
             ├─650 postgres: 13/main: background writer
             ├─651 postgres: 13/main: walwriter
             ├─652 postgres: 13/main: autovacuum launcher
             ├─653 postgres: 13/main: stats collector
             └─654 postgres: 13/main: logical replication launcher
# The configuration file is located at /etc/postgresql/13/main/postgresql.conf
# Open the PostgreSQL configuration file for reading the path of the hba file
vim /etc/postgresql/13/main/postgresql.conf
# The hba file is located at /etc/postgresql/13/main/pg_hba.conf
# Edit the pg_hba.conf file to set administrative access for the user app1user
# Database administrative login by Unix domain socket
local   all             postgres                                peer
host    all             all             all                     trust
host    all             all             all                     trust

# After editing the pg_hba.conf file, reload the PostgreSQL service
sudo systemctl reload postgresql
# Try connecting to the PostgreSQL database again
PGPASSWORD=app1user
psql -h 127.0.0.1 -d app1 -U app1user -c '\q'
