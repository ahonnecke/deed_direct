.PHONY: login link run-migrations reset-db local-start local-stop sync-config list-migrations fix-migrations

# Default Supabase CLI command
SUPABASE_CMD := npx supabase

# Login to Supabase
login:
	@echo "Running Supabase login..."
	$(SUPABASE_CMD) login

# Link to Supabase project
link:
	@echo "Running Supabase link..."
	$(SUPABASE_CMD) link

# Sync config from remote project
sync-config:
	@echo "Syncing config from remote project..."
	$(SUPABASE_CMD) db pull

# Run migrations
run-migrations:
	@echo "Running Supabase migrations..."
	$(SUPABASE_CMD) db push

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

# Fix migrations using the script
fix-migrations:
	@echo "Fixing migration history..."
	./tools/scripts/fix-migrations.sh

# Help command
help:
	@echo "Supabase Commands:"
	@echo "  make login          - Login to Supabase"
	@echo "  make link           - Link to Supabase project"
	@echo "  make sync-config    - Sync config from remote project (db pull)"
	@echo "  make list-migrations - List all migrations and their status"
	@echo "  make fix-migrations - Fix migration history automatically"
	@echo "  make run-migrations - Run pending migrations"
	@echo "  make reset-db       - Reset database and run all migrations"
	@echo "  make local-start    - Start local Supabase"
	@echo "  make local-stop     - Stop local Supabase"
