# Solution for Bekasi: Supervisor is still around
## Description:
There is an nginx service running on port 443, it is the main web server for the company and looks like a new employee has deployed some changes to the configuration of supervisor and now it is not working as expected.

If you try to access curl -k https://bekasi it should return Hello SadServers! but for some reason it is not.

You cannot modify files from the /home/admin/bekasi folder in order to pass the check.sh

You must find out what the issue is and fix it.

## Problem Analysis:
```bash
curl -k https://bekasi
Failed to start the server. Please check the setup
```
The application is responding with "Failed to start the server. Please check the setup" when trying to access the root endpoint. This indicates that the server is not properly configured or is missing required environment variables.
Looking at the source code of the application located in `/home/admin/bekasi/bekasi.py`, we find the following relevant snippet:
```python
import os
from flask import Flask
app = Flask(__name__)

@app.route("/")
def hello():
    if check_env():
        return "Hello SadServers!\n"
    else:
        return "Failed to start the server. Please check the setup\n"

def check_env():
    isServerSet = os.getenv('BEKASI_SERVER')
    isUserSet = os.getenv('BEKASI_USER')
    return isServerSet and isUserSet

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000)
```
The code snippet shows that the application checks for the presence of two environment variables: `BEKASI_SERVER` and `BEKASI_USER`. If both variables are set, it returns "Hello SadServers!", otherwise it returns the error message.

### Root Cause
**Missing Environment Variables**: The environment variables `BEKASI_SERVER` and `BEKASI_USER` are not set in the supervisor configuration, causing the application to fail the environment check and return the error message.

## Solution
To resolve the issue, we need to set the required environment variables in the supervisor configuration file for the Bekasi application.
1. Open the supervisor configuration file for the Bekasi application located at `/etc/supervisor/conf.d/bekasi.conf` in a text editor.
2. Add the following line at the end of the file:
```ini
environment=BEKASI_SERVER="bekasi.sadservers.com",BEKASI_USER="admin"
```
(To find out the correct values for these environment variables, run echo $BEKASI_SERVER and echo $BEKASI_USER in the terminal.)  
3. Save and close the file.   
4. Reload the supervisor configuration to apply the changes:
```bash
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl restart bekasi
```

## Verification
After applying these changes, run `curl -k https://bekasi` again to verify that the application now returns the expected response:
```bash
curl -k https://bekasi
Hello SadServers!
```
The output `Hello SadServers!` indicates that the application is now functioning correctly with the required environment variables set.
