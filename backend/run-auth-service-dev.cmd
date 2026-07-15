@echo off
cd /d C:\SwiftAIERP\backend
set GIN_MODE=release
bin\auth-service.exe >> C:\SwiftAIERP\backend\auth-service.task.log 2>&1
