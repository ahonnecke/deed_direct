.PHONY: setup.all setup.create-project setup.link setup.link-and-migrate sb.run-migrations sb.reset-db sb.local-start sb.local-stop sb.sync-config sb.list-migrations sb.login sb.logout sp.login sp.logout sb.migration-status docker.up docker.down docker.build dev.all dev.web dev.mobile dev.install dev.typecheck dev.test help

# Default Supabase CLI command
SUPABASE_CMD := npx supabase

# Login to Supabase
sb.login:
	@echo "Running Supabase login..."
	$(SUPABASE_CMD) login

# Logout from Supabase
sb.logout:
	@echo "Logging out from Supabase..."
	$(SUPABASE_CMD) logout

# Sync config from remote project
sb.sync-config:
	@echo "Syncing config from remote project..."
	$(SUPABASE_CMD) db pull

# Reset database and run all migrations
sb.reset-db:
	@echo "Resetting database and running all migrations..."
	$(SUPABASE_CMD) db reset

# Start local Supabase
sb.local-start:
	@echo "Starting local Supabase..."
	$(SUPABASE_CMD) start

# Stop local Supabase
sb.local-stop:
	@echo "Stopping local Supabase..."
	$(SUPABASE_CMD) stop

# List migrations
sb.list-migrations:
	@echo "Listing migrations..."
	$(SUPABASE_CMD) migration list

# Check migration status
sb.migration-status:
	@echo "Checking migration status..."
	$(SUPABASE_CMD) migration status

# Create a new Supabase project (always interactive)
setup.create-project:
	@echo "Creating new Supabase project..."
	python3 ./tools/scripts/create-project.py

# Link to existing project
setup.link:
	@echo "Linking to Supabase project..."
	python3 ./tools/scripts/link.py

# Apply migrations to linked project
sb.run-migrations:
	@echo "Applying migrations to Supabase project..."
	python3 ./tools/scripts/migrate.py

# Link and run migrations in one step
setup.link-and-migrate:
	@echo "Linking to project and applying migrations..."
	python3 ./tools/scripts/link-and-migrate.py

# Complete setup (create project, link, configure, and run migrations)
setup.all: setup.create-project setup.link-and-migrate
	@echo "Supabase setup complete!"

# Docker commands
docker.up:
	@echo "Starting Docker containers..."
	docker compose up -d web

# Build and start Docker containers
docker.build:
	@echo "Building and starting Docker containers..."
	docker compose up --build web

# Stop Docker containers
docker.down:
	@echo "Stopping Docker containers..."
	docker compose down

# Install dependencies
dev.install:
	@echo "Installing dependencies..."
	pnpm install

# Run development servers
dev.all:
	@echo "Starting development servers..."
	pnpm dev

# Run web development server
dev.web:
	@echo "Starting web development server..."
	pnpm --filter web dev

# Run mobile development server
dev.mobile:
	@echo "Starting mobile development server..."
	pnpm --filter mobile dev

# Run TypeScript checks
dev.typecheck:
	@echo "Running TypeScript checks..."
	pnpm typecheck

# Run tests
dev.test:
	@echo "Running tests..."
	pnpm test

# Help command
help:
	@echo "Setup Commands (one-time use):"
	@echo "  make setup.all          - Complete setup (create project, link, configure, and run migrations)"
	@echo "  make setup.create-project - Create a new Supabase project (always interactive)"
	@echo "  make setup.link           - Link to existing Supabase project"
	@echo "  make setup.link-and-migrate - Link to project and run migrations in one step"
	@echo ""
	@echo "Supabase Commands (sb. or sp.):"
	@echo "  make sb.login          - Login to Supabase"
	@echo "  make sb.logout         - Logout from Supabase"
	@echo "  make sp.login          - Login to Supabase (alternative)"
	@echo "  make sp.logout         - Logout from Supabase (alternative)"
	@echo "  make sb.sync-config    - Sync config from remote project (db pull)"
	@echo "  make sb.list-migrations - List all migrations and their status"
	@echo "  make sb.migration-status - Check migration status"
	@echo "  make sb.run-migrations - Apply migrations to linked project"
	@echo "  make sb.reset-db       - Reset database and run all migrations"
	@echo "  make sb.local-start    - Start local Supabase"
	@echo "  make sb.local-stop     - Stop local Supabase"
	@echo ""
	@echo "Docker Commands (docker.):"
	@echo "  make docker.up             - Start Docker containers"
	@echo "  make docker.build          - Build and start Docker containers"
	@echo "  make docker.down           - Stop Docker containers"
	@echo ""
	@echo "Development Commands (dev.):"
	@echo "  make dev.install        - Install dependencies"
	@echo "  make dev.all            - Run development servers"
	@echo "  make dev.web            - Run web development server"
	@echo "  make dev.mobile         - Run mobile development server"
	@echo "  make dev.typecheck      - Run TypeScript checks"
	@echo "  make dev.test           - Run tests"
