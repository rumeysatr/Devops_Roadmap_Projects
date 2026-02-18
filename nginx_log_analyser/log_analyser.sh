#!/bin/bash

echo "1. Top 5 IP addresses with the most requests:"
awk '{print $1}' nginx-access.log | sort | uniq -c | sort -rn | head -n 5 | awk '{print $2 " - " $1 " requests"}'
echo ""

echo "2. Top 5 most requested paths:"
awk '{print $7}' nginx-access.log | sort | uniq -c | sort -rn | head -n 5 | awk '{print $2 " - " $1 " requests"}'
echo ""

echo "3. Top 5 response status codes:"
awk '{print $9}' nginx-access.log | sort | uniq -c | sort -rn | head -n 5 | awk '{print $2 " - " $1 " requests"}'
echo ""

echo "4. Top 5 user agents:"
awk '{for(i=12; i<=NF; i++) printf "%s ", $i; print ""}' nginx-access.log | sort | uniq -c | sort -rn | head -n 5 | awk '{count=$1; $1=""; print $0 " - " count " requests"}'
echo ""


