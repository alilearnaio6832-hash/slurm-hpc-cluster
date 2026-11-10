"""Busy-loop on one core for N seconds (default 20) to create visible CPU load."""
import socket
import sys
import time

seconds = float(sys.argv[1]) if len(sys.argv) > 1 else 20.0
end = time.time() + seconds
while time.time() < end:
    pass
print(f"burned {seconds:.0f}s on {socket.gethostname()}")
