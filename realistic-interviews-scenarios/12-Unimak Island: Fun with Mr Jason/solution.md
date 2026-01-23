# Solution for Unimak-Island:Fun with Mr Jason
## Description
Using the file station_information.json , find the station_id where "has_kiosk" is false and "capacity" is greater than 30.

Save the station_id of the solution in the /home/admin/mysolution file, for example: echo "ec040a94-4de7-4fb3-aea0-ec5892034a69" > ~/mysolution

You can use the installed utilities jq, gron, jid as well as Python3 and Golang. 

## Solution
To find the entry, we can use the `jq` command-line tool to parse the JSON file and filter the stations based on the given criteria: "has_kiosk" is false and "capacity" is greater than 30.
Here is the command to achieve this:
```bash
jq '.data.stations[] | select(.has_kiosk == false and .capacity > 30) | .station_id' station_information.json > /home/admin/mysolution

```
Note that the output will include quotes around the station_id. To remove the quotes, we can use the `sed` command:
```bash
sed -i 's/"//g' /home/admin/mysolution
```

Or we can use Python to achieve the same result:
```python
import json

with open('station_information.json') as f:
    data = json.load(f)

stations = data.get('data', {}).get('stations', [])

with open('/home/admin/mysolution', 'w') as out:
    for station in stations:
        has_kiosk = station.get('has_kiosk', False)
        capacity = station.get('capacity', 0)

        if not has_kiosk and capacity > 30:
            out.write(station.get('station_id', '') + '\n')
```
Both methods will filter the stations based on the specified conditions and write the resulting station_id to the /home/admin/mysolution file.

## Verification
Finally, to verify the solution, we can create a md5 hash of the /home/admin/mysolution file using the `md5sum` command:
```bash
md5sum /home/admin/mysolution
8d8414808b15d55dad857fd5aeb2aebc  /home/admin/mysolution
```
This will give you the MD5 hash of the solution file, which you can use for verification.