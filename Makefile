.PHONY: setup create-project link run-migrations link-and-migrate reset-db local-start local-stop sync-config list-migrations

# Default Supabase CLI command
SUPABASE_CMD := npx supabase

# Login to Supabase
login:
	@echo "Running Supabase login..."
	$(SUPABASE_CMD) login

# Sync config from remote project
sync-config:
	@echo "Syncing config from remote project..."
	$(SUPABASE_CMD) db pull

# Reset database and run all migrations
reset-db:
	@echo "Resetting database and running all migrations..."
	$(SUPABASE_CMD) db reset

# Start local Supabase
local-start:
	@echo "Starting local Supabase..."
	$(SUPABASE_CMD) start

# Stop local Supabase
local-stop:
	@echo "Stopping local Supabase..."
	$(SUPABASE_CMD) stop

# List migrations
list-migrations:
	@echo "Listing migrations..."
	$(SUPABASE_CMD) migration list

# Check migration status
migration-status:
	@echo "Checking migration status..."
	$(SUPABASE_CMD) migration status

# Create a new Supabase project
create-project:
	@echo "Creating new Supabase project..."
	python3 ./tools/scripts/create-project.py

# Link to existing project
link:
	@echo "Linking to Supabase project..."
	python3 ./tools/scripts/link.py

# Apply migrations to linked project
run-migrations:
	@echo "Applying migrations to Supabase project..."
	python3 ./tools/scripts/migrate.py

# Link and run migrations in one step
link-and-migrate:
	@echo "Linking to project and applying migrations..."
	python3 ./tools/scripts/link-and-migrate.py

# Complete setup (create project, link, configure, and run migrations)
setup: create-project link-and-migrate
	@echo "Supabase setup complete!"

# Help command
help:
	@echo "Supabase Commands:"
	@echo "  make setup          - Complete setup (create project, link, configure, and run migrations)"
	@echo "  make create-project - Create a new Supabase project"
	@echo "  make link           - Link to existing Supabase project"
	@echo "  make run-migrations - Apply migrations to linked project"
	@echo "  make link-and-migrate - Link to project and run migrations in one step"
	@echo "  make login          - Login to Supabase"
	@echo "  make sync-config    - Sync config from remote project (db pull)"
	@echo "  make list-migrations - List all migrations and their status"
	@echo "  make migration-status - Check migration status"
	@echo "  make reset-db       - Reset database and run all migrations"
	@echo "  make local-start    - Start local Supabase"
	@echo "  make local-stop     - Stop local Supabase"
