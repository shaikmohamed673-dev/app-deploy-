-- ============================================================================
-- PostgreSQL Database Initialization Script for Java Tomcat Web Application
-- ============================================================================

-- NOTE: Execute the first 3 commands as the 'postgres' superuser:
-- sudo -i -u postgres psql

-- 1. Create Application Database User
CREATE USER appuser WITH ENCRYPTED PASSWORD 'AppSecurePassword123!';

-- 2. Create Database owned by appuser
CREATE DATABASE appdb OWNER appuser;

-- 3. Grant Privileges
GRANT ALL PRIVILEGES ON DATABASE appdb TO appuser;

-- Connect to the application database:
-- \c appdb

-- Grant schema privileges in PostgreSQL 15+
GRANT ALL ON SCHEMA public TO appuser;

-- ============================================================================
-- Tables and Initial Data (Run connected to 'appdb' as 'appuser' or 'postgres')
-- ============================================================================

-- Switch to appdb if using automated psql execution:
\connect appdb

-- Drop existing tables if re-initializing
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- 1. Create Users Table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    role VARCHAR(30) DEFAULT 'USER',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Create Audit Logs Table (to verify write operations)
CREATE TABLE audit_logs (
    id SERIAL PRIMARY KEY,
    action VARCHAR(100) NOT NULL,
    actor VARCHAR(50) DEFAULT 'SYSTEM',
    details TEXT,
    logged_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. Seed Initial Sample Data
INSERT INTO users (username, full_name, email, role) VALUES
('jdoe', 'John Doe', 'john.doe@example.com', 'ADMIN'),
('asmith', 'Alice Smith', 'alice.smith@example.com', 'DEVELOPER'),
('bwayne', 'Bruce Wayne', 'bruce.wayne@example.com', 'USER'),
('ckent', 'Clark Kent', 'clark.kent@example.com', 'USER');

INSERT INTO audit_logs (action, actor, details) VALUES
('DATABASE_INITIALIZED', 'DBA', 'PostgreSQL database initialized successfully for Tomcat app.'),
('SEED_DATA_INSERTED', 'DBA', 'Initial 4 sample users inserted.');

-- 4. Verification Query
SELECT 'Database setup complete. Total users: ' || COUNT(*) AS status FROM users;
