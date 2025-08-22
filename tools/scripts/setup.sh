#!/bin/bash
set -e

# Supabase executable
SUPABASE_CMD="npx supabase"

# Default organization ID
ORG_ID="wtzdspvojbntegninaxc"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to display messages
log() {
  echo -e "${GREEN}[SETUP]${NC} $1"
}

error() {
  echo -e "${RED}[ERROR]${NC} $1"
  exit 1
}

warn() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if npx is installed
if ! command -v npx &> /dev/null; then
  error "npx is not installed. Please install Node.js and npm first."
fi

# Check if .env file exists, create from example if not
if [ ! -f .env ]; then
  if [ -f .env.example ]; then
    log "Creating .env file from .env.example"
    cp .env.example .env
    warn "Please update the .env file with your Supabase credentials"
  else
    warn "No .env.example file found. Creating empty .env file"
    touch .env
  fi
fi

# Login to Supabase if not already logged in
log "Checking Supabase login status..."
if ! $SUPABASE_CMD projects list &> /dev/null; then
  log "Please login to Supabase"
  $SUPABASE_CMD login
fi

# Project creation or selection
PROJECT_NAME=""
PROJECT_EXISTS=false

# Check if project name is provided as argument
if [ -n "$1" ]; then
  PROJECT_NAME="$1"
else
  # Try to get project name from package.json
  if [ -f package.json ]; then
    PROJECT_NAME=$(grep -o '"name": *"[^"]*"' package.json | cut -d'"' -f4 | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
  fi
  
  # If still no project name, ask user
  if [ -z "$PROJECT_NAME" ]; then
    read -p "Enter project name (lowercase, no spaces): " PROJECT_NAME
  fi
fi

# Check if project already exists
log "Checking if project '$PROJECT_NAME' already exists..."
if $SUPABASE_CMD projects list -o json | jq -r '.[] | .name' | grep -q "$PROJECT_NAME"; then
  log "Project '$PROJECT_NAME' already exists"
  PROJECT_EXISTS=true
else
  log "Creating new Supabase project: $PROJECT_NAME"
  # Ask for database password
  read -sp "Enter database password for the new project: " DB_PASSWORD
  echo ""
  # Create new project with password
  $SUPABASE_CMD projects create "$PROJECT_NAME" --org-id "$ORG_ID" --db-password "$DB_PASSWORD"
  # Store password for linking
  echo "$DB_PASSWORD" > .db_password_temp
fi

# Get project ID
PROJECT_ID=$($SUPABASE_CMD projects list -o json | jq -r ".[] | select(.name == \"$PROJECT_NAME\") | .id")
if [ -z "$PROJECT_ID" ]; then
  error "Failed to get project ID"
fi

# Link to the project
log "Linking to Supabase project..."
LINK_SUCCESS=false

# Ask if user wants to skip database connection
read -p "Do you want to skip database connection and continue with setup? (y/N): " SKIP_DB
if [[ "$SKIP_DB" =~ ^[Yy]$ ]]; then
  log "Skipping database connection..."
  LINK_SUCCESS=true
else
  # Try to link with password
  if [ -f ".db_password_temp" ]; then
    DB_PASSWORD=$(cat .db_password_temp)
    rm .db_password_temp  # Remove the temporary password file
    
    log "Attempting to link with provided password..."
    if PGPASSWORD="$DB_PASSWORD" $SUPABASE_CMD link --project-ref "$PROJECT_ID" --password "$DB_PASSWORD" 2>/dev/null; then
      LINK_SUCCESS=true
    fi
  fi
  
  # If linking failed or no temp password file, ask for password
  if [ "$LINK_SUCCESS" != "true" ]; then
    # Try up to 3 times
    for i in {1..3}; do
      read -sp "Enter database password for project '$PROJECT_NAME' (attempt $i/3): " DB_PASSWORD
      echo ""
      
      if PGPASSWORD="$DB_PASSWORD" $SUPABASE_CMD link --project-ref "$PROJECT_ID" --password "$DB_PASSWORD" 2>/dev/null; then
        LINK_SUCCESS=true
        break
      else
        warn "Failed to connect to database. Please check your password."
      fi
    done
    
    # If still not successful after 3 attempts
    if [ "$LINK_SUCCESS" != "true" ]; then
      warn "Could not connect to database after 3 attempts."
      read -p "Do you want to continue setup without database connection? (y/N): " CONTINUE
      if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        error "Setup aborted."
      fi
      log "Continuing setup without database connection..."
    fi
  fi
fi

# Store database password in .env if it's not empty
if ! is_empty_or_null "$DB_PASSWORD"; then
  update_env_var "POSTGRES_PASSWORD" "$DB_PASSWORD"
fi

# Initialize Supabase if not already initialized
if [ ! -d "supabase" ]; then
  log "Initializing Supabase..."
  $SUPABASE_CMD init
fi

# Get project URL and keys
log "Fetching project credentials..."

# Function to check if a value is empty or null
is_empty_or_null() {
  [[ -z "$1" || "$1" == "null" ]]
}

# Try to fetch project URL
PROJECT_URL=$($SUPABASE_CMD projects list -o json | jq -r ".[] | select(.name == \"$PROJECT_NAME\") | .url")
if is_empty_or_null "$PROJECT_URL"; then
  warn "Could not fetch project URL automatically."
  read -p "Please enter your Supabase project URL (e.g., https://your-project.supabase.co): " PROJECT_URL
  if is_empty_or_null "$PROJECT_URL"; then
    error "Project URL is required to continue."
  fi
fi

# Try to fetch anon key
ANON_KEY=$($SUPABASE_CMD projects api-keys --project-ref "$PROJECT_ID" -o json | jq -r '.[] | select(.name == "anon key") | .api_key')
if is_empty_or_null "$ANON_KEY"; then
  warn "Could not fetch anon key automatically."
  read -p "Please enter your Supabase anon key: " ANON_KEY
  if is_empty_or_null "$ANON_KEY"; then
    error "Anon key is required to continue."
  fi
fi

# Try to fetch service key
SERVICE_KEY=$($SUPABASE_CMD projects api-keys --project-ref "$PROJECT_ID" -o json | jq -r '.[] | select(.name == "service_role key") | .api_key')
if is_empty_or_null "$SERVICE_KEY"; then
  warn "Could not fetch service role key automatically."
  read -p "Please enter your Supabase service role key: " SERVICE_KEY
  if is_empty_or_null "$SERVICE_KEY"; then
    warn "Service role key not provided. Some functionality may be limited."
  fi
fi

# Update .env file with Supabase credentials
log "Updating .env file with Supabase credentials..."

# Function to update environment variable
update_env_var() {
  local var_name=$1
  local var_value=$2
  
  # Skip if value is null or empty
  if is_empty_or_null "$var_value"; then
    warn "Skipping $var_name as value is empty or null"
    return
  fi
  
  if grep -q "$var_name=" .env; then
    sed -i "s|$var_name=.*|$var_name=$var_value|g" .env
  else
    echo "$var_name=$var_value" >> .env
  fi
  log "Set $var_name successfully"
}

# Update all environment variables
update_env_var "NEXT_PUBLIC_SUPABASE_URL" "$PROJECT_URL"
update_env_var "NEXT_PUBLIC_SUPABASE_ANON_KEY" "$ANON_KEY"
update_env_var "SUPABASE_URL" "$PROJECT_URL"
update_env_var "SUPABASE_ANON_KEY" "$ANON_KEY"
update_env_var "SUPABASE_SERVICE_KEY" "$SERVICE_KEY"

# Add organization ID to .env
update_env_var "SUPABASE_ORG_ID" "$ORG_ID"

# Only perform database operations if link was successful
if [ "$LINK_SUCCESS" = "true" ]; then
  # Sync remote configuration
  log "Syncing configuration from remote project..."
  $SUPABASE_CMD db remote changes || warn "Failed to sync remote changes. Continuing..."

  # Apply migrations
  log "Applying migrations to Supabase project..."
  $SUPABASE_CMD db push || warn "Failed to push migrations. Continuing..."
else
  warn "Skipping database operations due to connection issues."
fi

log "Setting up auth redirect URLs..."
$SUPABASE_CMD config set auth.site_url http://localhost:3000
$SUPABASE_CMD config set auth.additional_redirect_urls '["http://localhost:3000"]'

log "Setup complete! Your Supabase project is ready to use."
log "Project URL: $PROJECT_URL"
log "Project credentials have been added to your .env file"
