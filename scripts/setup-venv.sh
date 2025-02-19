#!/usr/bin/env bash

echo Installing Python dependencies...
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi

source .venv/bin/activate
pip install -r app/requirements.txt
