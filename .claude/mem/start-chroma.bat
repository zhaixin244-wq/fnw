@echo off
REM ChromaDB auto-start script for claude-mem
REM Created: 2026-05-14

REM Skip if already running
curl -s http://127.0.0.1:8000/api/v1/heartbeat >nul 2>&1 && exit /b 0

REM Start ChromaDB
start /b "" python -c "import uvicorn; from chromadb.app import app; uvicorn.run(app, host='127.0.0.1', port=8000, log_level='warning')" > "%USERPROFILE%\.claude-mem\logs\chroma-autostart.log" 2>&1
