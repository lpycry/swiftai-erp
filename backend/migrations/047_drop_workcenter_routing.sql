-- Remove Work Center and Routing tables (no longer needed)
DROP TABLE IF EXISTS routing_operations CASCADE;
DROP TABLE IF EXISTS routings CASCADE;
DROP TABLE IF EXISTS work_centers CASCADE;
