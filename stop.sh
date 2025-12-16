#!/bin/bash

echo "🛑 Stopping services..."

for pid_file in logs/*.pid; do
    if [ -f "$pid_file" ]; then
        pid=$(cat "$pid_file")
        if ps -p $pid > /dev/null 2>&1; then
            kill $pid 2>/dev/null
            echo "Stopped $(basename $pid_file .pid)"
        fi
        rm "$pid_file"
    fi
done

echo "✅ All services stopped"
