@echo off
cd /d "%~dp0"
start "" http://localhost:5194
python serve.py
