-- BOM Test Data
-- Requires: products, bom_headers, bom_items tables with new schema
-- Run AFTER migration 046_bom_rewrite.sql

-- Clear test data first (safe to re-run)
DELETE FROM bom_items WHERE bom_id IN (SELECT bom_id FROM bom_headers WHERE bom_version LIKE 'TEST%');
DELETE FROM bom_headers WHERE bom_version LIKE 'TEST%';

-- Create test products if they don't exist
-- First, find an existing tenant UUID from any existing product
DO $$
DECLARE
    v_tenant_id UUID;
    v_user_id UUID;
    v_fg_id UUID;      -- Finished Good
    v_rm1_id UUID;     -- Raw Material 1
    v_rm2_id UUID;     -- Raw Material 2
    v_sfg_id UUID;     -- Semi-Finished Good
    v_bom_id UUID;
BEGIN
    -- Use the first tenant from the products table
    SELECT tenant_id INTO v_tenant_id FROM products LIMIT 1;
    IF v_tenant_id IS NULL THEN
        RAISE EXCEPTION 'No tenant found. Create a product first.';
    END IF;

    -- Use first user or null
    SELECT id INTO v_user_id FROM users LIMIT 1;

    -- Create test materials (products) with procurement_type='in-house' and material_type
    -- Finished Good: Desk Lamp
    INSERT INTO products (id, tenant_id, sku, name, description, unit_of_measure, 
        standard_cost, procurement_type, material_type, is_active, created_at, updated_at)
    VALUES (gen_random_uuid(), v_tenant_id, 'FG-LAMP-001', 'LED Desk Lamp - Model A', 
        'Energy-efficient LED desk lamp with adjustable arm', 'PCS',
        45.0000, 'in-house', 'finished_goods', true, NOW(), NOW())
    RETURNING id INTO v_fg_id;

    -- Semi-Finished: Lamp Base Assembly
    INSERT INTO products (id, tenant_id, sku, name, description, unit_of_measure,
        standard_cost, procurement_type, material_type, is_active, created_at, updated_at)
    VALUES (gen_random_uuid(), v_tenant_id, 'SFG-BASE-001', 'Lamp Base Assembly',
        'Pre-assembled lamp base with wiring', 'PCS',
        18.5000, 'in-house', 'half_finished_goods', true, NOW(), NOW())
    RETURNING id INTO v_sfg_id;

    -- Raw Material 1: Aluminum Tube
    INSERT INTO products (id, tenant_id, sku, name, description, unit_of_measure,
        standard_cost, procurement_type, material_type, is_active, created_at, updated_at)
    VALUES (gen_random_uuid(), v_tenant_id, 'RM-ALUM-001', 'Aluminum Tube 20mm',
        'Extruded aluminum tube, 20mm diameter, 500mm length', 'M',
        2.5000, 'purchase', 'raw_material', true, NOW(), NOW())
    RETURNING id INTO v_rm1_id;

    -- Raw Material 2: LED Module
    INSERT INTO products (id, tenant_id, sku, name, description, unit_of_measure,
        standard_cost, procurement_type, material_type, is_active, created_at, updated_at)
    VALUES (gen_random_uuid(), v_tenant_id, 'RM-LED-001', 'LED Module 12W 3000K',
        '12-watt warm white LED module with driver', 'PCS',
        8.0000, 'purchase', 'raw_material', true, NOW(), NOW())
    RETURNING id INTO v_rm2_id;

    RAISE NOTICE 'Created products: FG=%, SFG=%, RM1=%, RM2=%', v_fg_id, v_sfg_id, v_rm1_id, v_rm2_id;

    -- ── BOM 1: Semi-Finished Good "Lamp Base Assembly" ──
    INSERT INTO bom_headers (bom_id, tenant_id, material_id, bom_version, bom_usage, status, base_qty,
        valid_from, valid_to, created_by, created_at, updated_at)
    VALUES (gen_random_uuid(), v_tenant_id, v_sfg_id, 'TEST-V1.0', 'PRODUCTION', 'ACTIVE', 1.0000,
        '2026-01-01 00:00:00+00', '2099-12-31 23:59:59+00', v_user_id, NOW(), NOW())
    RETURNING bom_id INTO v_bom_id;

    -- Items for Lamp Base Assembly: 0.5M Aluminum Tube + 2 screws (phantom)
    INSERT INTO bom_items (item_id, bom_id, item_position, component_id, quantity, unit_of_measure, 
        scrap_factor, is_phantom_item, valid_from, valid_to, remark)
    VALUES 
        (gen_random_uuid(), v_bom_id, 10, v_rm1_id, 0.5000, 'M', 0.0200, false,
         '2026-01-01 00:00:00+00', '2099-12-31 23:59:59+00', 'Cut to 450mm length'),
        (gen_random_uuid(), v_bom_id, 20, v_rm2_id, 1.0000, 'PCS', 0.0100, false,
         '2026-01-01 00:00:00+00', '2099-12-31 23:59:59+00', 'Solder wires to module');

    RAISE NOTICE 'Created BOM for SFG with bom_id=%', v_bom_id;

    -- ── BOM 2: Finished Good "LED Desk Lamp" ──
    INSERT INTO bom_headers (bom_id, tenant_id, material_id, bom_version, bom_usage, status, base_qty,
        valid_from, valid_to, created_by, created_at, updated_at)
    VALUES (gen_random_uuid(), v_tenant_id, v_fg_id, 'TEST-V1.0', 'PRODUCTION', 'ACTIVE', 1.0000,
        '2026-01-01 00:00:00+00', '2099-12-31 23:59:59+00', v_user_id, NOW(), NOW())
    RETURNING bom_id INTO v_bom_id;

    -- Items for LED Desk Lamp: 1x Lamp Base Assembly + additional raw materials
    INSERT INTO bom_items (item_id, bom_id, item_position, component_id, quantity, unit_of_measure,
        scrap_factor, is_phantom_item, valid_from, valid_to, remark)
    VALUES
        (gen_random_uuid(), v_bom_id, 10, v_sfg_id, 1.0000, 'PCS', 0.0000, false,
         '2026-01-01 00:00:00+00', '2099-12-31 23:59:59+00', 'Use pre-assembled base'),
        (gen_random_uuid(), v_bom_id, 20, v_rm2_id, 1.0000, 'PCS', 0.0300, false,
         '2026-01-01 00:00:00+00', '2099-12-31 23:59:59+00', 'Spare LED module'),
        (gen_random_uuid(), v_bom_id, 30, v_rm1_id, 0.1000, 'M', 0.0500, true,
         '2026-01-01 00:00:00+00', '2099-12-31 23:59:59+00', 'Small bracket (phantom, consumed directly)');

    RAISE NOTICE 'Created BOM for FG with bom_id=%', v_bom_id;

    -- Summary
    RAISE NOTICE '──────────────────────────────────────────';
    RAISE NOTICE 'Test data created successfully!';
    RAISE NOTICE 'Finished Good:  FG-LAMP-001 (LED Desk Lamp)';
    RAISE NOTICE '  → BOM V1.0 with 3 components (1 SFG + 2 RM)';
    RAISE NOTICE 'Semi-Finished: SFG-BASE-001 (Lamp Base Assembly)';
    RAISE NOTICE '  → BOM V1.0 with 2 components (2 RM)';
    RAISE NOTICE '';
    RAISE NOTICE 'To verify via API:';
    RAISE NOTICE '  GET  /api/v1/bom  (list all BOMs)';
    RAISE NOTICE '  POST /api/v1/bom/explode  {material_id, bom_version, explosion_type, requirement_qty}';
    RAISE NOTICE '──────────────────────────────────────────';
END $$;
