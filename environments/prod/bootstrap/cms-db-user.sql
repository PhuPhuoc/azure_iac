-- One-time bootstrap for the CMS database role.
--
-- Why this is not in Terraform: azurerm has no resource for PostgreSQL roles and
-- the postgresql provider needs a TCP route to the server, which is private
-- (public_network_access_enabled = false, delegated subnet). The bastion VM is
-- the intended place to run it and already ships postgresql-client.
--
--   1. terraform output -raw cms_db_password
--   2. scp environments/prod/bootstrap/cms-db-user.sql bastion:
--   3. ssh ubuntu@<bastion-ip> -- \
--        psql "host=pg-phungela-prod01.postgres.database.azure.com port=5432 dbname=cms user=cmsadmin sslmode=require" \
--             -v app_password='<password from step 1>' -f cms-db-user.sql
--
-- Safe to re-run: the role is created only when missing and the password is
-- always reset to the value passed in, so re-running resyncs the app after a
-- rotation. The role holds no server-level privilege and has no privilege in any
-- other database; tables it creates are its own, tables restored from the dump
-- stay owned by the administrator and are granted explicitly below.

\set ON_ERROR_STOP on

SELECT 'CREATE ROLE cms_app LOGIN'
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'cms_app')
\gexec

SELECT format('ALTER ROLE cms_app WITH LOGIN PASSWORD %L', :'app_password')
\gexec

SELECT format('GRANT CONNECT ON DATABASE %I TO cms_app', current_database())
\gexec

GRANT USAGE, CREATE ON SCHEMA public TO cms_app;

GRANT ALL ON ALL TABLES IN SCHEMA public TO cms_app;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO cms_app;

-- Strapi creates tables on boot when the database is empty; the administrator
-- re-imports the dump as itself, so future objects need the same grants.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON TABLES TO cms_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON SEQUENCES TO cms_app;
