#!/bin/bash
#Script to extract male entries from a data file
#Usage: ./get_male.sh <datafile> <outputfile>

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <datafile> <outputfile>"
    exit 1
fi
datafile=$1
outputfile=$2

#Extract lines where the second column
awk 'NR > 8 && $3 == "M"' "$datafile" >> "$outputfile"
echo "Male entries extracted to $outputfile"
# Alternatively:
#cat "$datafile" | grep "M" >> "$outputfile"

# Example data file format:
#NAME    GENDER  AGE     ADDRESS
#Alicia Fuentes  F       48      Walton Street, line 433
#Jo-Ting Losev   F       46      Hemenway Street, line 390
#Elena Edmonds   F       58      Elmwood Avenue, line 123
#Naydene Cabral  F       46      Winthrop Street, line 454
#Dato Rosengren  M       22      Mystic Street, line 477
#Fernanda Serrano        F       37      Redlands Road, line 392
#Emiliano Wenk   M       90      Paulding Street, line 490
#