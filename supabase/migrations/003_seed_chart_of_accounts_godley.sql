-- 003 — Standard SF chart of accounts, seeded for agency 0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c (Deatria Godley)
-- 95 accounts: assets/liabilities/equity/income/expense

-- ASSETS (1000-1999)
INSERT INTO chart_of_accounts (agency_id, account_code, account_name, account_type, account_subtype, is_active, is_system) VALUES
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '1000', 'Current Assets',              'asset', 'header',          TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '1010', 'Operating Checking Account',  'asset', 'bank',             TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '1020', 'Savings Account',             'asset', 'bank',             TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '1030', 'Premium Trust Account',       'asset', 'bank',             TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '1040', 'Petty Cash',                  'asset', 'cash',             TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '1100', 'Accounts Receivable',         'asset', 'receivable',       TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '1110', 'SF Commissions Receivable',   'asset', 'receivable',       TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '1120', 'AIPP Receivable',             'asset', 'receivable',       TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '1200', 'Prepaid Expenses',            'asset', 'prepaid',          TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '1210', 'Prepaid Insurance — E&O',     'asset', 'prepaid',          TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '1220', 'Prepaid Rent',                'asset', 'prepaid',          TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '1230', 'Prepaid Software/SaaS',       'asset', 'prepaid',          TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '1500', 'Fixed Assets',                'asset', 'header',           TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '1510', 'Office Equipment',            'asset', 'fixed',            TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '1515', 'Accumulated Depreciation — Equipment', 'asset', 'contra_asset', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '1520', 'Furniture and Fixtures',      'asset', 'fixed',            TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '1525', 'Accumulated Depreciation — Furniture', 'asset', 'contra_asset', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '1530', 'Leasehold Improvements',      'asset', 'fixed',            TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '1535', 'Accumulated Depreciation — Leasehold', 'asset', 'contra_asset', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '1540', 'Vehicles',                    'asset', 'fixed',            TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '1545', 'Accumulated Depreciation — Vehicles', 'asset', 'contra_asset', TRUE, FALSE);

-- LIABILITIES (2000-2999)
INSERT INTO chart_of_accounts (agency_id, account_code, account_name, account_type, account_subtype, is_active, is_system) VALUES
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '2000', 'Current Liabilities',         'liability', 'header',       TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '2010', 'Accounts Payable',            'liability', 'payable',      TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '2020', 'Accrued Expenses',            'liability', 'accrued',      TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '2030', 'Accrued Payroll',             'liability', 'accrued',      TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '2040', 'Payroll Taxes Payable',       'liability', 'payable',      TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '2041', 'Federal Income Tax Withheld', 'liability', 'payable',      TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '2042', 'State Income Tax Withheld',   'liability', 'payable',      TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '2043', 'Social Security Payable',     'liability', 'payable',      TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '2044', 'Medicare Payable',            'liability', 'payable',      TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '2050', 'Sales Tax Payable',           'liability', 'payable',      TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '2060', 'Premium Trust Liability',     'liability', 'trust',        TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '2070', 'Unearned Revenue',            'liability', 'deferred',     TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '2100', 'Credit Cards Payable',        'liability', 'header',       TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '2110', 'Business Credit Card — Chase','liability', 'credit_card',  TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '2120', 'Business Credit Card — Other','liability', 'credit_card',  TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '2500', 'Long-Term Liabilities',       'liability', 'header',       TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '2510', 'SBA Loan Payable',            'liability', 'loan',         TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '2520', 'Equipment Loan Payable',      'liability', 'loan',         TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '2530', 'Line of Credit Payable',      'liability', 'line_of_credit', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '2540', 'Vehicle Loan Payable',        'liability', 'loan',         TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '2900', 'Owner Loan to Agency',        'liability', 'owner_loan',   TRUE, FALSE);

-- EQUITY (3000-3999)
INSERT INTO chart_of_accounts (agency_id, account_code, account_name, account_type, account_subtype, is_active, is_system) VALUES
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '3000', 'Equity',                          'equity', 'header',      TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '3010', 'Owner Capital / Paid-In Capital',  'equity', 'capital',    TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '3020', 'Owner Draws',                      'equity', 'draws',      TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '3030', 'Retained Earnings',                'equity', 'retained',   TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '3040', 'Current Year Earnings',            'equity', 'current',    TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '3050', 'S-Corp Distributions',             'equity', 'distribution', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '3060', 'Shareholder Loan Payable',         'equity', 'loan',       TRUE, FALSE);

-- INCOME (4000-4999)
INSERT INTO chart_of_accounts (agency_id, account_code, account_name, account_type, account_subtype, is_active, is_system) VALUES
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '4000', 'SF Commission Income',             'income', 'header',     TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '4010', 'New Business Commission',          'income', 'commission', TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '4020', 'Renewal Commission',               'income', 'commission', TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '4030', 'Life Insurance Commission',        'income', 'commission', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '4040', 'Health Insurance Commission',      'income', 'commission', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '4050', 'Commercial Lines Commission',      'income', 'commission', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '4100', 'SF Bonus Income',                  'income', 'header',     TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '4110', 'AIPP Bonus',                       'income', 'bonus',      TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '4120', 'ScoreBoard Bonus',                 'income', 'bonus',      TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '4130', 'New Agent Bonus',                  'income', 'bonus',      TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '4140', 'Contingency Bonus',                'income', 'bonus',      TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '4150', 'SF Marketing Development Funds',   'income', 'bonus',      TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '4160', 'SF Training Reimbursement',        'income', 'reimbursement', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '4900', 'Other Income',                     'income', 'header',     TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '4910', 'Notary Fees',                      'income', 'fee',        TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '4920', 'Interest Income',                  'income', 'interest',   TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '4930', 'Miscellaneous Income',             'income', 'misc',       TRUE, FALSE);

-- OPERATING EXPENSES (6000-7999)
INSERT INTO chart_of_accounts (agency_id, account_code, account_name, account_type, account_subtype, is_active, is_system) VALUES
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6000', 'Payroll & Compensation',           'expense', 'header',    TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6010', 'Staff Wages',                      'expense', 'payroll',   TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6011', 'Staff Wages — Licensed',           'expense', 'payroll',   TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6012', 'Staff Wages — Unlicensed',         'expense', 'payroll',   TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6013', 'Staff Wages — Family',             'expense', 'payroll',   TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6020', 'Owner W-2 Wages (S-Corp)',         'expense', 'payroll',   TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6030', 'Payroll Tax Expense — ER Share',   'expense', 'payroll',   TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6031', 'Social Security — ER',             'expense', 'payroll',   TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6032', 'Medicare — ER',                    'expense', 'payroll',   TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6033', 'FUTA Expense',                     'expense', 'payroll',   TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6034', 'SUTA Expense',                     'expense', 'payroll',   TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6040', 'Staff Commissions',                'expense', 'commission', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6050', 'Staff Bonuses',                    'expense', 'bonus',     TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6060', 'Contract Labor — 1099',            'expense', 'contract',  TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6100', 'Employee Benefits',                'expense', 'header',    TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6110', 'Health Insurance — Staff',         'expense', 'benefits',  TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6115', 'S-Corp Medical — Owner',           'expense', 'benefits',  TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6120', 'Retirement Plan Contributions',    'expense', 'benefits',  TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6130', 'Workers Compensation Insurance',   'expense', 'benefits',  TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6200', 'Occupancy',                        'expense', 'header',    TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6210', 'Rent / Lease',                     'expense', 'rent',      TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6220', 'Utilities',                        'expense', 'utilities', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6230', 'Janitorial / Cleaning',            'expense', 'facilities', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6240', 'Repairs and Maintenance',          'expense', 'facilities', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6250', 'Property Insurance',               'expense', 'insurance', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6300', 'Technology & Software',            'expense', 'header',    TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6310', 'Software Subscriptions — SaaS',   'expense', 'software',  TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6311', 'Claude.ai Subscription',          'expense', 'software',  TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6312', 'Supabase',                        'expense', 'software',  TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6313', 'Composio',                        'expense', 'software',  TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6314', 'Agency Management System',        'expense', 'software',  TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6315', 'Other Software',                  'expense', 'software',  TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6320', 'Phone & Internet',                'expense', 'technology', TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6330', 'Computer Equipment',              'expense', 'equipment', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6340', 'IT Support',                      'expense', 'technology', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6400', 'Marketing & Advertising',         'expense', 'header',    TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6410', 'Digital Advertising',             'expense', 'advertising', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6420', 'Print Advertising',               'expense', 'advertising', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6430', 'Promotional Items / Giveaways',   'expense', 'marketing', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6440', 'Sponsorships & Donations',        'expense', 'marketing', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6450', 'Client Events & Entertainment',   'expense', 'marketing', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6460', 'Social Media & Content Tools',    'expense', 'marketing', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6470', 'Website Hosting & Domain',        'expense', 'marketing', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6500', 'Professional Services',           'expense', 'header',    TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6510', 'Accounting & Bookkeeping',        'expense', 'professional', TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6520', 'Legal Fees',                      'expense', 'professional', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6530', 'Consulting Fees',                 'expense', 'professional', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6540', 'Payroll Processing Fees',         'expense', 'professional', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6600', 'Insurance Expense',               'expense', 'header',    TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6610', 'E&O Insurance',                   'expense', 'insurance', TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6620', 'General Liability Insurance',     'expense', 'insurance', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6630', 'Business Owner Policy (BOP)',     'expense', 'insurance', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6700', 'Education & Licensing',           'expense', 'header',    TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6710', 'License Renewal Fees',            'expense', 'licensing', TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6720', 'Continuing Education',            'expense', 'education', TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6730', 'Training & Development',          'expense', 'education', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6740', 'SF Conference & Travel',          'expense', 'education', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6750', 'Books & Publications',            'expense', 'education', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6800', 'Vehicle & Travel',                'expense', 'header',    TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6810', 'Mileage Reimbursement',           'expense', 'vehicle',   TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6820', 'Vehicle Lease / Loan Payment',    'expense', 'vehicle',   TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6830', 'Vehicle Insurance',               'expense', 'vehicle',   TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6840', 'Fuel & Maintenance',              'expense', 'vehicle',   TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6850', 'Business Travel',                 'expense', 'travel',    TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6860', 'Meals & Entertainment',           'expense', 'entertainment', TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6900', 'General & Administrative',        'expense', 'header',    TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6910', 'Office Supplies',                 'expense', 'supplies',  TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6920', 'Postage & Shipping',              'expense', 'supplies',  TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6930', 'Printing & Copying',              'expense', 'supplies',  TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6940', 'Bank Fees & Charges',             'expense', 'banking',   TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6941', 'Credit Card Interest',            'expense', 'banking',   TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6942', 'Loan Interest',                   'expense', 'banking',   TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6950', 'Miscellaneous Expense',           'expense', 'misc',      TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '6960', 'Depreciation Expense',            'expense', 'depreciation', TRUE, FALSE);

-- OTHER INCOME / EXPENSE (8000-8999)
INSERT INTO chart_of_accounts (agency_id, account_code, account_name, account_type, account_subtype, is_active, is_system) VALUES
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '8000', 'Other Income & Expense',          'expense', 'header',    TRUE, TRUE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '8010', 'Gain on Sale of Assets',          'income',  'other',     TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '8020', 'Loss on Sale of Assets',          'expense', 'other',     TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '8030', 'Other Non-Operating Income',      'income',  'other',     TRUE, FALSE),
('0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID, '8040', 'Other Non-Operating Expense',     'expense', 'other',     TRUE, FALSE);

-- Set parent_account_id linkages
UPDATE chart_of_accounts SET parent_account_id = (SELECT id FROM chart_of_accounts WHERE agency_id = '0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID AND account_code = '1000') WHERE agency_id = '0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID AND account_code IN ('1010','1020','1030','1040','1100','1110','1120','1200','1210','1220','1230');
UPDATE chart_of_accounts SET parent_account_id = (SELECT id FROM chart_of_accounts WHERE agency_id = '0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID AND account_code = '1500') WHERE agency_id = '0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID AND account_code IN ('1510','1515','1520','1525','1530','1535','1540','1545');
UPDATE chart_of_accounts SET parent_account_id = (SELECT id FROM chart_of_accounts WHERE agency_id = '0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID AND account_code = '2000') WHERE agency_id = '0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID AND account_code IN ('2010','2020','2030','2040','2041','2042','2043','2044','2050','2060','2070','2100','2110','2120');
UPDATE chart_of_accounts SET parent_account_id = (SELECT id FROM chart_of_accounts WHERE agency_id = '0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID AND account_code = '2500') WHERE agency_id = '0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID AND account_code IN ('2510','2520','2530','2540','2900');
UPDATE chart_of_accounts SET parent_account_id = (SELECT id FROM chart_of_accounts WHERE agency_id = '0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID AND account_code = '2100') WHERE agency_id = '0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID AND account_code IN ('2110','2120');
UPDATE chart_of_accounts SET parent_account_id = (SELECT id FROM chart_of_accounts WHERE agency_id = '0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID AND account_code = '4000') WHERE agency_id = '0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID AND account_code IN ('4010','4020','4030','4040','4050');
UPDATE chart_of_accounts SET parent_account_id = (SELECT id FROM chart_of_accounts WHERE agency_id = '0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID AND account_code = '4100') WHERE agency_id = '0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID AND account_code IN ('4110','4120','4130','4140','4150','4160');
UPDATE chart_of_accounts SET parent_account_id = (SELECT id FROM chart_of_accounts WHERE agency_id = '0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID AND account_code = '4900') WHERE agency_id = '0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID AND account_code IN ('4910','4920','4930');
UPDATE chart_of_accounts SET parent_account_id = (SELECT id FROM chart_of_accounts WHERE agency_id = '0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID AND account_code = '6000') WHERE agency_id = '0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID AND account_code IN ('6010','6011','6012','6013','6020','6030','6031','6032','6033','6034','6040','6050','6060');
UPDATE chart_of_accounts SET parent_account_id = (SELECT id FROM chart_of_accounts WHERE agency_id = '0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID AND account_code = '6010') WHERE agency_id = '0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID AND account_code IN ('6011','6012','6013');
UPDATE chart_of_accounts SET parent_account_id = (SELECT id FROM chart_of_accounts WHERE agency_id = '0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID AND account_code = '6030') WHERE agency_id = '0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::UUID AND account_code IN ('6031','6032','6033','6034');;