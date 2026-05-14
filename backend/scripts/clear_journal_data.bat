@echo off
title SwiftAI ERP - Clear Journal Entries
echo ========================================
echo  Clear All Journal Entries and Balances
echo ========================================
echo.
echo WARNING: This will permanently delete:
echo   - All journal entries
echo   - All journal lines
echo   - All account balances
echo   - All attachments
echo.
echo This cannot be undone!
echo.
set /p CONFIRM="Type YES to confirm: "
if not "%CONFIRM%"=="YES" (
    echo Operation cancelled.
    pause
    exit /b 1
)

echo.
echo Connecting to database...
echo.

cd /d "%~dp0"

C:
cd \SwiftAIERP\backend

set GO_SCRIPT=C:\Users\lpycr\AppData\Local\Temp\swiftai_wipe_journal.go

if exist "%GO_SCRIPT%" del "%GO_SCRIPT%"

echo package main > "%GO_SCRIPT%"
echo. >> "%GO_SCRIPT%"
echo import ( >> "%GO_SCRIPT%"
echo 	"context" >> "%GO_SCRIPT%"
echo 	"fmt" >> "%GO_SCRIPT%"
echo 	"github.com/jackc/pgx/v5/pgxpool" >> "%GO_SCRIPT%"
echo ) >> "%GO_SCRIPT%"
echo. >> "%GO_SCRIPT%"
echo func main() { >> "%GO_SCRIPT%"
echo 	pool, _ := pgxpool.New(context.Background(), "postgres://swiftai:swiftai_dev_pass@localhost:5432/swiftai_erp?sslmode=disable") >> "%GO_SCRIPT%"
echo 	defer pool.Close() >> "%GO_SCRIPT%"
echo. >> "%GO_SCRIPT%"
echo 	tables := []string{"gl_account_balances", "gl_entry_attachments", "gl_journal_lines", "gl_journal_entries"} >> "%GO_SCRIPT%"
echo 	for _, t := range tables { >> "%GO_SCRIPT%"
echo 		res, err := pool.Exec(context.Background(), "DELETE FROM " + t) >> "%GO_SCRIPT%"
echo 		if err != nil { >> "%GO_SCRIPT%"
echo 			fmt.Printf("ERROR deleting %s: %%v\n", err) >> "%GO_SCRIPT%"
echo 		} else { >> "%GO_SCRIPT%"
echo 			fmt.Printf("OK  %s: %%d rows deleted\n", t, res.RowsAffected()) >> "%GO_SCRIPT%"
echo 		} >> "%GO_SCRIPT%"
echo 	} >> "%GO_SCRIPT%"
echo 	fmt.Println("Done!") >> "%GO_SCRIPT%"
echo } >> "%GO_SCRIPT%"

go run "%GO_SCRIPT%"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo All journal entries and balances have been cleared.
) else (
    echo.
    echo An error occurred. Check the output above.
)

del "%GO_SCRIPT%" 2>nul

echo.
pause
