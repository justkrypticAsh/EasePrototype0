#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"
if [ -d ".venv" ]; then
    source .venv/bin/activate
else
    python3 -m venv .venv
    source .venv/bin/activate
    pip install -e .
fi
echo "Starting EASE FastAPI Backend on http://localhost:8000 ..."
uvicorn backend.app.main:app --reload --port 8000
