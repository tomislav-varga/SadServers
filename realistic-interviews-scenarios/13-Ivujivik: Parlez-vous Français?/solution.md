# Solution for Ivujivik: Parlez-vous Français?
## Description
Given the CSV file /home/admin/table_tableau11.csv, find the Electoral District Name/Nom de circonscription that has the largest number of Rejected Ballots/Bulletins rejetés and also has a population of less than 100,000.

The initial CSV file may be corrupted or invalid in a way that can be fixed without changing its data.

Installed in the VM are: Python3, Go, sqlite3, miller directly and PostgreSQL, MySQL in Docker images.

Save the solution in the /home/admin/mysolution , with the name as it is in the file, for example: echo "Trois-Rivières" > ~/mysolution (the solution must be terminated by newline).

## Problem Analysis
The provided CSV file may contain formatting issues that prevent it from being parsed correctly. To solve the problem, we need to clean the CSV file, filter the data based on the given criteria (Rejected Ballots and population), and then identify the Electoral District Name with the highest number of Rejected Ballots. 

Proving that the CSV file is corrupted can be done by running:
```bash
mlr --icsv check table_tableau11.csv
mlr: Header/data length mismatch (13 != 12) at file "table_tableau11.csv" line 101.
```
The error message indicates that there is an issue with the CSV file structure. The issue is that there are more columns in some rows than in the header row, which causes a mismatch.

## Solution
There are multiple ways to solve this problem. Below are the solution steps using Python and the Miller tool.

**Fix the CSV file using Miller**:
```bash
mlr --icsv --ocsv --allow-ragged-csv-input unsparsify \
  table_tableau11.csv > fixed.csv
```
Running this command will create a new CSV file named `fixed.csv` with the formatting issues resolved.
```bash
mlr --icsv check fixed.csv
# No output means the file is valid now.
```
### Solution using Python
1. **Process the fixed CSV file using Python**:
```python
import csv
from typing import Optional, Dict


CSV_FILE = "fixed.csv"

DISTRICT_COL = "Electoral District Name/Nom de circonscription"
POPULATION_COL = "Population"
REJECTED_COL = "Rejected Ballots/Bulletins rejetés"


def find_district_with_most_rejected(
    csv_path: str,
) -> Optional[Dict[str, str]]:
    best_row = None
    max_rejected = -1

    with open(csv_path, newline="", encoding="utf-8") as file:
        reader = csv.DictReader(file)

        for row in reader:
            population =float(row[POPULATION_COL])
            rejected = float(row[REJECTED_COL])

            if population < 100_000 and rejected > max_rejected:
                max_rejected = rejected
                best_row = row

    return best_row


def main() -> None:
    result = find_district_with_most_rejected(CSV_FILE)

    if result is None:
        print("No matching district found.")
        return

    print(
        f"District: {result[DISTRICT_COL]}\n"
        f"Rejected Ballots: {result[REJECTED_COL]}\n"
        f"Population: {result[POPULATION_COL]}"
    )


if __name__ == "__main__":
    main()
```
2. **Run the Python script** to get the result:
```bash
python3 solution.py
District: Montcalm
Rejected Ballots: 1226
Population: 99518
```
3. **Save the solution** to the specified file:
```bash
echo "Montcalm" > /home/admin/mysolution
```

### Solution using Miller only
You can also solve the problem using only Miller commands:
```bash
mlr --icsv --opprint \
  filter '$Population < 100000' \
  then sort -nr 'Rejected Ballots/Bulletins rejetés' \
  then head -n 1 \
  then put '
    $District = $["Electoral District Name/Nom de circonscription"];
    $Rejected = $["Rejected Ballots/Bulletins rejetés"];
    $Population = $Population;
  ' \
  then cut -f District,Rejected,Population \
  fixed.csv
Population District Rejected
99518      Montcalm 1226
```
Proceed to save "Montcalm" in the solution file as shown above.

## Verification
To verify the solution, you can check the contents of the `/home/admin/mysolution` file:
```bash
md5sum /home/admin/mysolution
e399d171f21839a65f8f8ab55ed1e1a1  mysolution
```