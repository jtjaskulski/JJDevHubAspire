SELECT 'CREATE DATABASE identity_read'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'identity_read')\gexec
