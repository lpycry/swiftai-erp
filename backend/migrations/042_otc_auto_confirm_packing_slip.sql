-- Add auto_confirm_so and packing_slip columns to order_type_configs

ALTER TABLE order_type_configs
    ADD COLUMN IF NOT EXISTS auto_confirm_so BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS packing_slip BOOLEAN NOT NULL DEFAULT false;
