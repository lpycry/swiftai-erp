-- Clean up existing accounts and periods for a clean reset
-- Run this BEFORE applying new GAAP seed data

DELETE FROM gl_account_balances;
DELETE FROM gl_journal_lines;
DELETE FROM gl_journal_entries;
DELETE FROM gl_accounts;
DELETE FROM gl_periods;
