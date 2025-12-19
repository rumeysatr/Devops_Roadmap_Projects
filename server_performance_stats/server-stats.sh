#!/bin/bash

#CPU USAGE : capasity - idle(id)
top -b -n 1 | grep "Cpu(s)" | awk '{print "CPU Usage: " 100 - $8 "%"}'

#MEMORY USAGE Percentage: (used / total) * 100 
free -m | grep "Mem" | awk '{print "Memory Usage: " ($3 / $2) * 100}'

#TOTAL DISK USAGE Percentage:
df -h / | tail -n 1 | awk '{print "Disk Usage: Used:" $3 "/ Free:" $4 "("$5")"}'

#TOP 5 PROCESSES BY CPU USAGE
ps ax -o pid,user,%cpu,cmd --sort -%cpu | head -n 6

#TOP 5 PROCESSES BY MEMORY USAGE
ps ax -o pid,user,%mem,cmd --sort -%mem | head -6
