-- Create syncv3 database for Sliding Sync Proxy
CREATE DATABASE syncv3;

-- Grant privileges to synapse user
GRANT ALL PRIVILEGES ON DATABASE syncv3 TO synapse;
