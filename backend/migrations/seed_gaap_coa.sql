-- ============================================================
-- SwiftAI ERP - GAAP Chart of Accounts Seed
-- English-only GAAP standard chart of accounts
-- ============================================================

DO $$
DECLARE
    tid UUID;
    asset_id UUID;
    liab_id UUID;
    equity_id UUID;
    revenue_id UUID;
    cogs_id UUID;
    expense_id UUID;
    other_income_id UUID;
    other_expense_id UUID;
    current_asset_id UUID;
    fixed_asset_id UUID;
    other_asset_id UUID;
    current_liab_id UUID;
    longterm_liab_id UUID;
BEGIN
    FOR tid IN SELECT id FROM tenants LOOP

        -- Period for current month
        INSERT INTO gl_periods (tenant_id, fiscal_year, period_no, start_date, end_date, is_open, is_locked)
        VALUES (tid, 2026, 5, '2026-05-01', '2026-05-31', true, false)
        ON CONFLICT (tenant_id, fiscal_year, period_no) DO NOTHING;

        -- === Level 1: Account Classes ===
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, is_leaf, currency, description)
        VALUES (tid, '1', 'ASSET', 'ASSET', 1, false, 'USD', 'Assets')
        ON CONFLICT (tenant_id, account_code) DO UPDATE SET account_name=EXCLUDED.account_name
        RETURNING id INTO asset_id;

        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, is_leaf, currency, description)
        VALUES (tid, '2', 'LIABILITY', 'LIABILITY', 1, false, 'USD', 'Liabilities')
        ON CONFLICT (tenant_id, account_code) DO UPDATE SET account_name=EXCLUDED.account_name
        RETURNING id INTO liab_id;

        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, is_leaf, currency, description)
        VALUES (tid, '3', 'EQUITY', 'EQUITY', 1, false, 'USD', 'Equity')
        ON CONFLICT (tenant_id, account_code) DO UPDATE SET account_name=EXCLUDED.account_name
        RETURNING id INTO equity_id;

        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, is_leaf, currency, description)
        VALUES (tid, '4', 'REVENUE', 'REVENUE', 1, false, 'USD', 'Revenue')
        ON CONFLICT (tenant_id, account_code) DO UPDATE SET account_name=EXCLUDED.account_name
        RETURNING id INTO revenue_id;

        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, is_leaf, currency, description)
        VALUES (tid, '5', 'COST OF GOODS SOLD', 'COGS', 1, false, 'USD', 'Cost of Goods Sold')
        ON CONFLICT (tenant_id, account_code) DO UPDATE SET account_name=EXCLUDED.account_name
        RETURNING id INTO cogs_id;

        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, is_leaf, currency, description)
        VALUES (tid, '6', 'EXPENSE', 'EXPENSE', 1, false, 'USD', 'Expenses')
        ON CONFLICT (tenant_id, account_code) DO UPDATE SET account_name=EXCLUDED.account_name
        RETURNING id INTO expense_id;

        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, is_leaf, currency, description)
        VALUES (tid, '7', 'OTHER INCOME', 'OTHER_INCOME', 1, false, 'USD', 'Other Income')
        ON CONFLICT (tenant_id, account_code) DO UPDATE SET account_name=EXCLUDED.account_name
        RETURNING id INTO other_income_id;

        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, is_leaf, currency, description)
        VALUES (tid, '8', 'OTHER EXPENSE', 'OTHER_EXPENSE', 1, false, 'USD', 'Other Expenses')
        ON CONFLICT (tenant_id, account_code) DO UPDATE SET account_name=EXCLUDED.account_name
        RETURNING id INTO other_expense_id;

        -- === ASSET Level 2: Sub-classes ===
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '11', 'Current Assets', 'ASSET', 2, asset_id, false, 'USD', 'Current assets - convertible within 1 year')
        ON CONFLICT (tenant_id, account_code) DO NOTHING RETURNING id INTO current_asset_id;

        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '12', 'Fixed Assets', 'ASSET', 2, asset_id, false, 'USD', 'Long-term tangible assets')
        ON CONFLICT (tenant_id, account_code) DO NOTHING RETURNING id INTO fixed_asset_id;

        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '13', 'Other Assets', 'ASSET', 2, asset_id, false, 'USD', 'Non-current intangible and other assets')
        ON CONFLICT (tenant_id, account_code) DO NOTHING RETURNING id INTO other_asset_id;

        -- === LIABILITY Level 2: Sub-classes ===
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '21', 'Current Liabilities', 'LIABILITY', 2, liab_id, false, 'USD', 'Obligations due within 1 year')
        ON CONFLICT (tenant_id, account_code) DO NOTHING RETURNING id INTO current_liab_id;

        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '22', 'Long-Term Liabilities', 'LIABILITY', 2, liab_id, false, 'USD', 'Obligations due beyond 1 year')
        ON CONFLICT (tenant_id, account_code) DO NOTHING RETURNING id INTO longterm_liab_id;

        -- === CURRENT ASSETS (Level 3) ===
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '1101', 'Cash', 'ASSET', 3, current_asset_id, true, 'USD', 'Petty cash on hand')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '1102', 'Bank - Checking', 'ASSET', 3, current_asset_id, true, 'USD', 'Checking account')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '1103', 'Bank - Savings', 'ASSET', 3, current_asset_id, true, 'USD', 'Savings account')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description, reconciliation_type)
        VALUES (tid, '1120', 'Accounts Receivable', 'ASSET', 3, current_asset_id, true, 'USD', 'Trade accounts receivable', 'customer')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '1130', 'Inventory', 'ASSET', 3, current_asset_id, true, 'USD', 'Inventory on hand')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '1140', 'Prepaid Expenses', 'ASSET', 3, current_asset_id, true, 'USD', 'Prepaid insurance, rent, etc.')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;

        -- === FIXED ASSETS (Level 3) ===
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '1210', 'Land', 'ASSET', 3, fixed_asset_id, true, 'USD', 'Land at cost')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '1220', 'Buildings', 'ASSET', 3, fixed_asset_id, true, 'USD', 'Buildings at cost')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '1230', 'Equipment', 'ASSET', 3, fixed_asset_id, true, 'USD', 'Office and IT equipment')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '1240', 'Accumulated Depreciation', 'ASSET', 3, fixed_asset_id, true, 'USD', 'Contra-asset: total depreciation')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;

        -- === OTHER ASSETS (Level 3) ===
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '1310', 'Intangible Assets', 'ASSET', 3, other_asset_id, true, 'USD', 'Patents, trademarks, goodwill')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '1320', 'Security Deposits', 'ASSET', 3, other_asset_id, true, 'USD', 'Rental and utility deposits')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;

        -- === CURRENT LIABILITIES (Level 3) ===
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description, reconciliation_type)
        VALUES (tid, '2101', 'Accounts Payable', 'LIABILITY', 3, current_liab_id, true, 'USD', 'Trade accounts payable', 'vendor')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '2110', 'Accrued Expenses', 'LIABILITY', 3, current_liab_id, true, 'USD', 'Accrued salaries, utilities, etc.')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '2120', 'Taxes Payable', 'LIABILITY', 3, current_liab_id, true, 'USD', 'Sales tax, income tax payable')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '2130', 'Wages Payable', 'LIABILITY', 3, current_liab_id, true, 'USD', 'Unpaid employee wages')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '2140', 'Notes Payable - Short Term', 'LIABILITY', 3, current_liab_id, true, 'USD', 'Short-term notes and borrowings')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;

        -- === LONG-TERM LIABILITIES (Level 3) ===
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '2210', 'Bank Loans Payable', 'LIABILITY', 3, longterm_liab_id, true, 'USD', 'Long-term bank loans')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '2220', 'Notes Payable - Long Term', 'LIABILITY', 3, longterm_liab_id, true, 'USD', 'Long-term notes payable')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;

        -- === EQUITY (Level 2) ===
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '3100', 'Common Stock', 'EQUITY', 2, equity_id, true, 'USD', 'Par value of issued shares')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '3200', 'Retained Earnings', 'EQUITY', 2, equity_id, true, 'USD', 'Cumulative retained earnings')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '3300', 'Current Year Profit/Loss', 'EQUITY', 2, equity_id, true, 'USD', 'Current fiscal year net income/loss')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;

        -- === REVENUE (Level 2) ===
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '4100', 'Sales Revenue - Products', 'REVENUE', 2, revenue_id, true, 'USD', 'Revenue from product sales')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '4200', 'Sales Revenue - Services', 'REVENUE', 2, revenue_id, true, 'USD', 'Revenue from services rendered')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '4300', 'Sales Discounts', 'REVENUE', 2, revenue_id, true, 'USD', 'Contra-revenue: discounts given')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '4400', 'Sales Returns', 'REVENUE', 2, revenue_id, true, 'USD', 'Contra-revenue: returned merchandise')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;

        -- === COGS (Level 2) ===
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '5100', 'Cost of Goods Sold', 'COGS', 2, cogs_id, true, 'USD', 'Direct product costs')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '5200', 'Cost of Services', 'COGS', 2, cogs_id, true, 'USD', 'Direct service delivery costs')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '5300', 'Purchase Discounts', 'COGS', 2, cogs_id, true, 'USD', 'Contra-COGS: purchase discounts received')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;

        -- === EXPENSE (Level 2) ===
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '6100', 'Salaries & Wages', 'EXPENSE', 2, expense_id, true, 'USD', 'Employee salaries and wages')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '6200', 'Rent Expense', 'EXPENSE', 2, expense_id, true, 'USD', 'Office and facility rent')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '6300', 'Utilities Expense', 'EXPENSE', 2, expense_id, true, 'USD', 'Electricity, water, internet, phone')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '6400', 'Office Supplies Expense', 'EXPENSE', 2, expense_id, true, 'USD', 'Office consumables and supplies')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '6500', 'Travel Expense', 'EXPENSE', 2, expense_id, true, 'USD', 'Business travel, lodging, meals')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '6600', 'Depreciation Expense', 'EXPENSE', 2, expense_id, true, 'USD', 'Periodic depreciation charge')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '6700', 'Insurance Expense', 'EXPENSE', 2, expense_id, true, 'USD', 'Insurance premiums')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '6800', 'Professional Fees', 'EXPENSE', 2, expense_id, true, 'USD', 'Legal, accounting, consulting fees')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '6900', 'Misc. Operating Expenses', 'EXPENSE', 2, expense_id, true, 'USD', 'Other operating expenses')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;

        -- === OTHER INCOME (Level 2) ===
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '7100', 'Interest Income', 'OTHER_INCOME', 2, other_income_id, true, 'USD', 'Interest earned on deposits')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '7200', 'Gain on Asset Disposal', 'OTHER_INCOME', 2, other_income_id, true, 'USD', 'Gain from sale of fixed assets')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;

        -- === OTHER EXPENSE (Level 2) ===
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '8100', 'Interest Expense', 'OTHER_EXPENSE', 2, other_expense_id, true, 'USD', 'Interest paid on borrowings')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '8200', 'Loss on Asset Disposal', 'OTHER_EXPENSE', 2, other_expense_id, true, 'USD', 'Loss from sale of fixed assets')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '8300', 'Income Tax Expense', 'OTHER_EXPENSE', 2, other_expense_id, true, 'USD', 'Income tax provision')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;

    END LOOP;
END;
$$;
