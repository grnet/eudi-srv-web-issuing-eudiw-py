#!/usr/bin/env python3

import argparse
import requests
import time
import urllib3
from subprocess import Popen

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

DEFAULT_HOST = "https://snf-74864.ok-kno.grnetcloud.net:5500"
DEFAULT_TIMEOUT = 5

proc = None

def restart():
    global proc
    if proc is not None:
        print("Terminating stuck server...")
        try:
            proc.terminate()
        except Exception as e:
            print(f"Error terminating server: {e}")
    print("Restarting server...")
    proc = Popen(["./run-issuer.sh"])
    print("Server restarted.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Monitor server function")
    parser.add_argument(
        "--host",
        type=str,
        required=False,
        default=DEFAULT_HOST,
        help=f"URL to watch for changes, default: {DEFAULT_HOST}",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        required=False,
        default=DEFAULT_TIMEOUT,
        help=f"The timeout to use, default: {DEFAULT_TIMEOUT}",
    )
    args = parser.parse_args()

    url = f"{args.host}/.well-known/openid-credential-issuer"
    print(f"Watching {url} for changes (every {DEFAULT_TIMEOUT}s)...")

    while True:
        try:
            response = requests.get(url, timeout=args.timeout, verify=False)
            response.raise_for_status()
        except requests.exceptions.Timeout:
            print("Request timed out.")
            restart()
        except requests.exceptions.RequestException as e:
            print(f"An error occurred: {e}")
            restart()
        time.sleep(DEFAULT_TIMEOUT)
    