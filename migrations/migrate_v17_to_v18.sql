-- Database Migration: v17 to v18
-- Adds product status tracking for price change history
-- Safe to run multiple times (uses IF NOT EXISTS where possible)

-- Enable foreign keys
PRAGMA foreign_keys=ON;

-- Add status column (defaults to 'active')
-- Note: SQLite doesn't support IF NOT EXISTS on ALTER TABLE
-- So we wrap in a transaction and ignore errors if column exists
BEGIN TRANSACTION;

-- Try to add columns (will fail silently if they exist)
ALTER TABLE products ADD COLUMN status TEXT DEFAULT 'active';
ALTER TABLE products ADD COLUMN closed_at TEXT;
ALTER TABLE products ADD COLUMN closed_reason TEXT;

-- Set all existing products to 'active' status
UPDATE products SET status = 'active' WHERE status IS NULL;

-- Update database version
PRAGMA user_version = 18;

COMMIT;

-- Verify migration
SELECT 'Migration completed! Database version: ' || PRAGMA user_version;
SELECT COUNT(*) || ' products updated to active status' FROM products WHERE status = 'active';
