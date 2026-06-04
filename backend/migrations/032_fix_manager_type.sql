-- Fix manager_id type: UUID → VARCHAR(50)  
ALTER TABLE organization_units 
    ALTER COLUMN manager_id TYPE VARCHAR(50) 
    USING COALESCE(manager_id::text, '');
