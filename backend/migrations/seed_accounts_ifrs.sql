-- Enhanced IFRS/GAAP Chart of Accounts — additional standard accounts

DO $$
DECLARE
    tid UUID;
    parent_id UUID;
BEGIN
    FOR tid IN SELECT id FROM tenants LOOP

        -- Non-current asset: try insert, if exists get the ID
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        SELECT tid, '12', '非流动资产', 'asset', 2, id, false, 'USD', 'Non-current assets'
        FROM gl_accounts WHERE tenant_id = tid AND account_code = '1'
        ON CONFLICT (tenant_id, account_code) DO NOTHING;
        SELECT id INTO parent_id FROM gl_accounts WHERE tenant_id = tid AND account_code = '12';

        -- Intangible assets
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        VALUES (tid, '1701', '无形资产', 'asset', 3, parent_id, true, 'USD', 'Intangible assets')
        ON CONFLICT (tenant_id, account_code) DO NOTHING;

        -- Additional revenue accounts
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        SELECT tid, ac.code, ac.name, 'revenue', 2, ga.id, true, 'USD', ac.descr
        FROM (VALUES ('4003', '利息收入', 'Interest income'), ('4004', '汇兑收益', 'Foreign exchange gains')) AS ac(code, name, descr)
        JOIN gl_accounts ga ON ga.tenant_id = tid AND ga.account_code = '4'
        WHERE NOT EXISTS (SELECT 1 FROM gl_accounts WHERE tenant_id = tid AND account_code = ac.code);

        -- Additional expense accounts
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        SELECT tid, ac.code, ac.name, 'expense', 3, ga.id, true, 'USD', ac.descr
        FROM (VALUES
            ('5104', '折旧费用', 'Depreciation'),
            ('5105', '摊销费用', 'Amortization'),
            ('5106', '工资薪酬', 'Salaries'),
            ('5107', '保险费', 'Insurance'),
            ('5108', '咨询费', 'Professional fees'),
            ('5109', '邮寄快递费', 'Postage'),
            ('5110', '税费', 'Taxes'),
            ('5111', '维修保养费', 'Maintenance')
        ) AS ac(code, name, descr)
        JOIN gl_accounts ga ON ga.tenant_id = tid AND (ga.account_code = '51' )
        WHERE NOT EXISTS (SELECT 1 FROM gl_accounts WHERE tenant_id = tid AND account_code = ac.code)
        LIMIT 1;

        -- Equity reserve accounts
        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        SELECT tid, '3003', '盈余公积', 'equity', 2, id, true, 'USD', 'Statutory reserve'
        FROM gl_accounts WHERE tenant_id = tid AND account_code = '3'
        AND NOT EXISTS (SELECT 1 FROM gl_accounts WHERE tenant_id = tid AND account_code = '3003');

        INSERT INTO gl_accounts (tenant_id, account_code, account_name, account_type, level, parent_id, is_leaf, currency, description)
        SELECT tid, '3004', '一般风险准备', 'equity', 2, id, true, 'USD', 'Risk reserve'
        FROM gl_accounts WHERE tenant_id = tid AND account_code = '3'
        AND NOT EXISTS (SELECT 1 FROM gl_accounts WHERE tenant_id = tid AND account_code = '3004');

    END LOOP;
END;
$$;
