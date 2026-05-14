-- Simplified seed: standard accounts for all tenants

DO $$
DECLARE
    tid UUID;
    asset_id UUID;
    liab_id UUID;
    equity_id UUID;
    revenue_id UUID;
    expense_id UUID;
    current_asset_id UUID;
    current_liab_id UUID;
    admin_expense_id UUID;
BEGIN
    FOR tid IN SELECT id FROM tenants LOOP

        -- Period (columns: fiscal_year, period_no, NOT year/month)
        INSERT INTO gl_periods (tenant_id, fiscal_year, period_no, start_date, end_date, is_open, is_locked)
        VALUES (tid, 2026, 5, '2026-05-01', '2026-05-31', true, false)
        ON CONFLICT (tenant_id, fiscal_year, period_no) DO NOTHING;

        -- === Level 1: Account classes ===
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, is_leaf, currency) VALUES (tid, '1', '资产类', 'asset', 1, false, 'USD') ON CONFLICT (tenant_id, account_code) DO UPDATE SET account_name=EXCLUDED.account_name RETURNING id INTO asset_id;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, is_leaf, currency) VALUES (tid, '2', '负债类', 'liability', 1, false, 'USD') ON CONFLICT (tenant_id, account_code) DO UPDATE SET account_name=EXCLUDED.account_name RETURNING id INTO liab_id;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, is_leaf, currency) VALUES (tid, '3', '权益类', 'equity', 1, false, 'USD') ON CONFLICT (tenant_id, account_code) DO UPDATE SET account_name=EXCLUDED.account_name RETURNING id INTO equity_id;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, is_leaf, currency) VALUES (tid, '4', '收入类', 'revenue', 1, false, 'USD') ON CONFLICT (tenant_id, account_code) DO UPDATE SET account_name=EXCLUDED.account_name RETURNING id INTO revenue_id;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, is_leaf, currency) VALUES (tid, '5', '费用类', 'expense', 1, false, 'USD') ON CONFLICT (tenant_id, account_code) DO UPDATE SET account_name=EXCLUDED.account_name RETURNING id INTO expense_id;

        -- === Level 2: Subclasses ===
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency) VALUES (tid, '11', '流动资产', 'asset', 2, asset_id, false, 'USD') ON CONFLICT (tenant_id, account_code) DO NOTHING RETURNING id INTO current_asset_id;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency) VALUES (tid, '21', '流动负债', 'liability', 2, liab_id, false, 'USD') ON CONFLICT (tenant_id, account_code) DO NOTHING RETURNING id INTO current_liab_id;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency) VALUES (tid, '51', '管理费用', 'expense', 2, expense_id, false, 'USD') ON CONFLICT (tenant_id, account_code) DO NOTHING RETURNING id INTO admin_expense_id;

        -- === Level 3: Leaf accounts ===
        -- Assets
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description) VALUES (tid, '1101', '库存现金', 'asset', 3, current_asset_id, true, 'USD', 'Cash on hand') ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description) VALUES (tid, '1102', '银行存款', 'asset', 3, current_asset_id, true, 'USD', 'Cash in bank') ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description) VALUES (tid, '1122', '应收账款', 'asset', 3, current_asset_id, true, 'USD', 'Accounts receivable') ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description) VALUES (tid, '1405', '库存商品', 'asset', 3, current_asset_id, true, 'USD', 'Finished goods') ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description) VALUES (tid, '1601', '固定资产', 'asset', 3, current_asset_id, true, 'USD', 'Fixed assets') ON CONFLICT (tenant_id, account_code) DO NOTHING;

        -- Liabilities
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description) VALUES (tid, '2201', '应付票据', 'liability', 3, current_liab_id, true, 'USD', 'Notes payable') ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description) VALUES (tid, '2202', '应付账款', 'liability', 3, current_liab_id, true, 'USD', 'Accounts payable') ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description) VALUES (tid, '2211', '应付职工薪酬', 'liability', 3, current_liab_id, true, 'USD', 'Wages payable') ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description) VALUES (tid, '2221', '应交税费', 'liability', 3, current_liab_id, true, 'USD', 'Taxes payable') ON CONFLICT (tenant_id, account_code) DO NOTHING;

        -- Expenses
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description) VALUES (tid, '5101', '办公费', 'expense', 3, admin_expense_id, true, 'USD', 'Office expenses') ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description) VALUES (tid, '5102', '差旅费', 'expense', 3, admin_expense_id, true, 'USD', 'Travel expenses') ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description) VALUES (tid, '5103', '房租', 'expense', 3, admin_expense_id, true, 'USD', 'Rent') ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description) VALUES (tid, '5201', '销售费用', 'expense', 3, expense_id, true, 'USD', 'Selling expenses') ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description) VALUES (tid, '5301', '财务费用', 'expense', 3, expense_id, true, 'USD', 'Finance costs') ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description) VALUES (tid, '5401', '营业成本', 'expense', 3, expense_id, true, 'USD', 'Cost of sales') ON CONFLICT (tenant_id, account_code) DO NOTHING;

        -- Equity
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description) VALUES (tid, '3001', '实收资本', 'equity', 2, equity_id, true, 'USD', 'Paid-in capital') ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description) VALUES (tid, '3101', '本年利润', 'equity', 2, equity_id, true, 'USD', 'Current year profit') ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description) VALUES (tid, '3102', '未分配利润', 'equity', 2, equity_id, true, 'USD', 'Retained earnings') ON CONFLICT (tenant_id, account_code) DO NOTHING;

        -- Revenue
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description) VALUES (tid, '4001', '主营业务收入', 'revenue', 2, revenue_id, true, 'USD', 'Revenue') ON CONFLICT (tenant_id, account_code) DO NOTHING;
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description) VALUES (tid, '4002', '其他业务收入', 'revenue', 2, revenue_id, true, 'USD', 'Other revenue') ON CONFLICT (tenant_id, account_code) DO NOTHING;

    END LOOP;
END;
$$;
