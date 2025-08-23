#!/bin/bash
set -e

# Supabase executable
SUPABASE_CMD="npx supabase"

# Default organization ID
ORG_ID="wtzdspvojbntegninaxc"

# Default region
REGION="us-west-1"

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

# Function to generate a secure password
generate_secure_password() {
  # Generate a 16-character password with letters, numbers, and symbols
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 12 | tr -d '=+/' | cut -c1-16
  else
    # Fallback if openssl is not available
    LC_ALL=C tr -dc 'A-Za-z0-9!#$%&()*+,-./:;<=>?@[]^_`{|}~' </dev/null | head -c 16
  fi
}

# Function to extract project ID from URL
extract_project_id_from_url() {
  local url=$1
  # Extract subdomain from URL (e.g., https://hfhuoiymuzlxiavqwhhy.supabase.co -> hfhuoiymuzlxiavqwhhy)
  echo "$url" | sed -E 's|https?://([^.]+)\.supabase\.co.*|\1|'
}

# Function to update environment variable
update_env_var() {
  local var_name=$1
  local var_value=$2
  
  # Skip if value is null or empty
  if [[ -z "$var_value" || "$var_value" == "null" ]]; then
    warn "Skipping $var_name as value is empty or null"
    return
  fi
  
  if grep -q "^$var_name=" .env; then
    sed -i "s|^$var_name=.*|$var_name=$var_value|g" .env
  else
    echo "$var_name=$var_value" >> .env
  fi
  log "Set $var_name successfully"
}

# Check if npx is installed
if ! command -v npx &> /dev/null; then
  error "npx is not installed. Please install Node.js and npm first."
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  error "jq is not installed. Please install jq first."
fi

# Check if .env file exists, create from example if not
if [ ! -f .env ]; then
  if [ -f .env.example ]; then
    log "Creating .env file from .env.example"
    cp .env.example .env
  elif [ -f .env.template ]; then
    log "Creating .env file from .env.template"
    cp .env.template .env
  else
    log "Creating empty .env file"
    touch .env
  fi
fi

# Login to Supabase if needed
log "Checking Supabase login status..."

# Always run login to ensure we're properly authenticated
log "Please login to Supabase (or confirm existing login)"
$SUPABASE_CMD login

# Give some time for the login to take effect
log "Waiting for login to complete..."
sleep 3

# Project creation or selection
PROJECT_NAME=""

# Check if project name is provided as argument
if [ -n "$1" ]; then
  PROJECT_NAME="$1"
else
  # Try to get project name from package.json
  if [ -f package.json ]; then
    PROJECT_NAME=$(grep -o '"name": *"[^"]*"' package.json | cut -d'"' -f4 | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
  fi
  
  # If still no project name, use default
  if [ -z "$PROJECT_NAME" ]; then
    PROJECT_NAME="supa-accelerator"
    log "Using default project name: $PROJECT_NAME"
  fi
fi

# Check if project already exists
log "Checking if project '$PROJECT_NAME' already exists..."

# Debug output for token file - check all possible locations
log "Checking Supabase token file locations..."

# Possible token file locations
TOKEN_LOCATIONS=(
  "$HOME/.supabase/access-token"
  "$HOME/.config/supabase/access-token"
  "$HOME/.config/supabase/tokens.json"
)

TOKEN_FOUND=false
for TOKEN_FILE in "${TOKEN_LOCATIONS[@]}"; do
  if [ -f "$TOKEN_FILE" ]; then
    log "Token file found at: $TOKEN_FILE"
    log "Token file size: $(wc -c < "$TOKEN_FILE") bytes"
    TOKEN_FOUND=true
    break
  fi
done

if [ "$TOKEN_FOUND" = false ]; then
  log "Warning: No token file found in any expected location"
  log "This may cause authentication issues"
  log "Will proceed anyway and rely on interactive login"
fi

# Try to get projects list with multiple attempts
PROJECTS_JSON=""
for i in {1..3}; do
  log "Attempt $i/3: Retrieving projects list..."
  # First try with plain format to see if it works
  log "Running plain projects list command to verify CLI works"
  $SUPABASE_CMD projects list
  
  # Now try with JSON format
  log "Running: npx supabase projects list -o json"
  PROJECTS_JSON=$($SUPABASE_CMD projects list -o json 2>&1)
  PROJECTS_STATUS=$?
  
  log "Command exit status: $PROJECTS_STATUS"
  log "Command output length: ${#PROJECTS_JSON}"
  log "Command output: '$PROJECTS_JSON'"
  
  # Consider empty list ("[]") as a valid response
  if [ $PROJECTS_STATUS -eq 0 ]; then
    if [ "$PROJECTS_JSON" = "[]" ]; then
      log "Empty projects list retrieved successfully"
      break
    elif [ -n "$PROJECTS_JSON" ] && [ "$PROJECTS_JSON" != "null" ]; then
      log "Projects list retrieved successfully"
      break
    fi
  fi
  
  log "Waiting before retry..."
  sleep 5
done

# Process the projects list response
if [ $PROJECTS_STATUS -ne 0 ]; then
  log "Failed to retrieve projects list. Status code: $PROJECTS_STATUS"
  log "Proceeding with project creation anyway"
else
  # Handle empty project list (which is valid - just means no projects yet)
  if [ "$PROJECTS_JSON" = "[]" ]; then
    log "Empty projects list - no projects exist yet"
    # Continue with project creation
  elif [ -z "$PROJECTS_JSON" ] || [ "$PROJECTS_JSON" = "null" ]; then
    log "Null or empty response - assuming no projects exist"
    # Continue with project creation
  else
    # Check if we have a valid JSON response
    if ! echo "$PROJECTS_JSON" | jq -e . >/dev/null 2>&1; then
      log "Invalid JSON response from projects list command"
      log "Response: $PROJECTS_JSON"
      log "Proceeding with project creation despite list retrieval issues"
    else
      log "Valid JSON response received"
      
      # Check if project exists in the list
      if echo "$PROJECTS_JSON" | jq -e '.[]' >/dev/null 2>&1; then
        PROJECT_EXISTS=$(echo "$PROJECTS_JSON" | jq -r '.[] | .name' | grep -q "$PROJECT_NAME"; echo $?)
        if [ $PROJECT_EXISTS -eq 0 ]; then
          error "Project '$PROJECT_NAME' already exists. Please use a different name or delete the existing project."
        else
          log "Project '$PROJECT_NAME' does not exist yet. Proceeding with creation."
        fi
      else
        log "No projects found in the list. Proceeding with creation."
      fi
    fi
  fi
fi

# Project existence check already done above

# Create new project
log "Creating new Supabase project: $PROJECT_NAME in region $REGION"

# Generate a secure password
DB_PASSWORD=$(generate_secure_password)
log "Generated secure database password: $DB_PASSWORD"

# Save password to file for reference
echo "$DB_PASSWORD" > template_postgres_pw
log "Saved database password to template_postgres_pw"

# Create the project with retries
PROJECT_CREATED=false
for i in {1..3}; do
  log "Attempt $i/3: Creating Supabase project..."
  if $SUPABASE_CMD projects create "$PROJECT_NAME" --org-id "$ORG_ID" --db-password "$DB_PASSWORD" --region "$REGION" 2>&1; then
    PROJECT_CREATED=true
    log "Project creation command executed successfully"
    break
  else
    log "Project creation attempt failed"
    if [ $i -lt 3 ]; then
      log "Waiting before retry..."
      sleep 5
    else
      log "Failed to create project after 3 attempts"
      log "Will try to continue in case the project was actually created despite the error"
    fi
  fi
done

# Get project ID with retries
log "Retrieving project ID..."
PROJECT_ID=""
for i in {1..5}; do
  log "Attempt $i/5: Getting project ID..."
  PROJECTS_JSON=$($SUPABASE_CMD projects list -o json 2>/dev/null)
  
  # Debug output
  log "Projects list command exit status: $?"
  log "Projects JSON length: ${#PROJECTS_JSON}"
  
  if [ -n "$PROJECTS_JSON" ] && [ "$PROJECTS_JSON" != "null" ] && [ "$PROJECTS_JSON" != "[]" ]; then
    PROJECT_ID=$(echo "$PROJECTS_JSON" | jq -r ".[] | select(.name == \"$PROJECT_NAME\") | .id")
    
    if [ -n "$PROJECT_ID" ] && [ "$PROJECT_ID" != "null" ]; then
      log "Project ID retrieved: $PROJECT_ID"
      break
    fi
  fi
  
  log "Waiting for project ID to be available..."
  sleep 10  # Longer wait time to allow for project creation to propagate
done

# Fail if project ID is not available
if [ -z "$PROJECT_ID" ] || [ "$PROJECT_ID" == "null" ]; then
  error "Failed to retrieve project ID after multiple attempts. Project may not have been created successfully."
fi

log "Project ID: $PROJECT_ID"

# Construct project URL from project ID
log "Constructing project URL from project ID..."

# The URL format is https://<project-id>.supabase.co
PROJECT_URL="https://$PROJECT_ID.supabase.co"
log "Project URL constructed: $PROJECT_URL"

log "Project URL: $PROJECT_URL"

# Link to the project
log "Linking to Supabase project..."

# Link with the password we just created - retry up to 5 times
log "Linking project with database password..."
for i in {1..5}; do
  log "Attempt $i/5: Linking to project..."
  LINK_OUTPUT=$($SUPABASE_CMD link --project-ref "$PROJECT_ID" --password "$DB_PASSWORD" 2>&1)
  LINK_STATUS=$?
  
  # Debug output
  log "Link command exit status: $LINK_STATUS"
  
  if [ $LINK_STATUS -eq 0 ]; then
    log "Successfully linked to project!"
    break
  else
    log "Link attempt output: $LINK_OUTPUT"
    
    if [ $i -eq 5 ]; then
      error "Failed to link project after 5 attempts. Please check your database password."
    else
      log "Link attempt failed. Waiting 10 seconds before retry..."
      sleep 10
    fi
  fi
done

log "Project linked successfully"

# Get API keys with improved retry logic
log "Getting API keys..."
ANON_KEY=""
SERVICE_KEY=""

# Try multiple times with increasing wait times
for i in {1..5}; do
  log "Attempt $i/5: Retrieving API keys..."
  
  # First try direct command to see output
  if [ $i -eq 1 ]; then
    log "Running direct API keys command to see output format:"
    $SUPABASE_CMD projects api-keys --project-ref "$PROJECT_ID"
  fi
  
  # Now try with JSON format
  API_KEYS_JSON=$($SUPABASE_CMD projects api-keys --project-ref "$PROJECT_ID" -o json 2>&1)
  API_KEYS_STATUS=$?
  
  # Debug output
  log "API keys command exit status: $API_KEYS_STATUS"
  log "API keys JSON length: ${#API_KEYS_JSON}"
  
  if [ $API_KEYS_STATUS -eq 0 ] && [ -n "$API_KEYS_JSON" ] && [ "$API_KEYS_JSON" != "null" ]; then
    # Try to extract keys
    ANON_KEY=$(echo "$API_KEYS_JSON" | jq -r '.[] | select(.name == "anon") | .api_key' 2>/dev/null)
    SERVICE_KEY=$(echo "$API_KEYS_JSON" | jq -r '.[] | select(.name == "service_role") | .api_key' 2>/dev/null)
    
    # Check if we got both keys
    if [ -n "$ANON_KEY" ] && [ "$ANON_KEY" != "null" ] && [ -n "$SERVICE_KEY" ] && [ "$SERVICE_KEY" != "null" ]; then
      log "API keys retrieved successfully"
      break
    else
      # Try alternative extraction method if the first one failed
      log "Standard extraction failed, trying alternative method..."
      # Try to extract from raw output
      ANON_KEY=$(echo "$API_KEYS_JSON" | grep -o '"anon"[^}]*"api_key":"[^"]*"' | grep -o '"api_key":"[^"]*"' | cut -d'"' -f4)
      SERVICE_KEY=$(echo "$API_KEYS_JSON" | grep -o '"service_role"[^}]*"api_key":"[^"]*"' | grep -o '"api_key":"[^"]*"' | cut -d'"' -f4)
      
      if [ -n "$ANON_KEY" ] && [ -n "$SERVICE_KEY" ]; then
        log "API keys retrieved using alternative method"
        break
      fi
    fi
  fi
  
  log "Waiting for API keys to be available..."
  sleep $((i * 5))  # Increasing wait time for each retry
done

# If we still don't have keys, try one more approach - direct parsing from project show
if [ -z "$ANON_KEY" ] || [ "$ANON_KEY" == "null" ] || [ -z "$SERVICE_KEY" ] || [ "$SERVICE_KEY" == "null" ]; then
  log "Trying to get API keys from project show command..."
  PROJECT_SHOW=$($SUPABASE_CMD projects show --project-ref "$PROJECT_ID" 2>&1)
  
  # Try to extract keys from the output
  ANON_KEY=$(echo "$PROJECT_SHOW" | grep -A 1 "anon:" | tail -n 1 | tr -d ' ')
  SERVICE_KEY=$(echo "$PROJECT_SHOW" | grep -A 1 "service_role:" | tail -n 1 | tr -d ' ')
  
  if [ -n "$ANON_KEY" ] && [ -n "$SERVICE_KEY" ]; then
    log "API keys retrieved from project show command"
  fi
fi

# Fail if API keys are still not available
if [ -z "$ANON_KEY" ] || [ "$ANON_KEY" == "null" ] || [ -z "$SERVICE_KEY" ] || [ "$SERVICE_KEY" == "null" ]; then
  error "Failed to retrieve API keys after multiple attempts."
fi

# Mask keys for logging
ANON_KEY_MASKED="${ANON_KEY:0:5}..."
SERVICE_KEY_MASKED="${SERVICE_KEY:0:5}..."
log "API keys retrieved successfully: Anon key: $ANON_KEY_MASKED, Service key: $SERVICE_KEY_MASKED"

# Update environment variables
log "Updating .env file with Supabase credentials..."

# Update all environment variables
if grep -q "^NEXT_PUBLIC_SUPABASE_URL=" .env; then
  sed -i "s|^NEXT_PUBLIC_SUPABASE_URL=.*|NEXT_PUBLIC_SUPABASE_URL=$PROJECT_URL|g" .env
else
  echo "NEXT_PUBLIC_SUPABASE_URL=$PROJECT_URL" >> .env
fi

if grep -q "^NEXT_PUBLIC_SUPABASE_ANON_KEY=" .env; then
  sed -i "s|^NEXT_PUBLIC_SUPABASE_ANON_KEY=.*|NEXT_PUBLIC_SUPABASE_ANON_KEY=$ANON_KEY|g" .env
else
  echo "NEXT_PUBLIC_SUPABASE_ANON_KEY=$ANON_KEY" >> .env
fi

if grep -q "^SUPABASE_URL=" .env; then
  sed -i "s|^SUPABASE_URL=.*|SUPABASE_URL=$PROJECT_URL|g" .env
else
  echo "SUPABASE_URL=$PROJECT_URL" >> .env
fi

if grep -q "^SUPABASE_ANON_KEY=" .env; then
  sed -i "s|^SUPABASE_ANON_KEY=.*|SUPABASE_ANON_KEY=$ANON_KEY|g" .env
else
  echo "SUPABASE_ANON_KEY=$ANON_KEY" >> .env
fi

if grep -q "^SUPABASE_SERVICE_KEY=" .env; then
  sed -i "s|^SUPABASE_SERVICE_KEY=.*|SUPABASE_SERVICE_KEY=$SERVICE_KEY|g" .env
else
  echo "SUPABASE_SERVICE_KEY=$SERVICE_KEY" >> .env
fi

if grep -q "^POSTGRES_PASSWORD=" .env; then
  sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$DB_PASSWORD|g" .env
else
  echo "POSTGRES_PASSWORD=$DB_PASSWORD" >> .env
fi

log "Environment variables updated successfully"

# Initialize Supabase if not already initialized
if [ ! -d "supabase" ]; then
  log "Initializing Supabase..."
  if ! $SUPABASE_CMD init; then
    error "Failed to initialize Supabase"
  fi
  log "Supabase initialized successfully"
fi

# Sync remote configuration with retries
log "Syncing configuration from remote project..."
for i in {1..3}; do
  log "Attempt $i/3: Syncing remote changes..."
  if $SUPABASE_CMD db remote changes 2>/dev/null; then
    log "Successfully synced remote changes"
    break
  elif [ $i -eq 3 ]; then
    error "Failed to sync remote changes after 3 attempts"
  else
    log "Sync attempt failed. Waiting 5 seconds before retry..."
    sleep 5
  fi
done

# Apply migrations with retries
log "Applying migrations to Supabase project..."
for i in {1..3}; do
  log "Attempt $i/3: Pushing migrations..."
  if $SUPABASE_CMD db push 2>/dev/null; then
    log "Successfully pushed migrations"
    break
  elif [ $i -eq 3 ]; then
    error "Failed to push migrations after 3 attempts"
  else
    log "Migration push attempt failed. Waiting 5 seconds before retry..."
    sleep 5
  fi
done

# Set up auth redirect URLs with retries
log "Setting up auth redirect URLs..."
for i in {1..3}; do
  log "Attempt $i/3: Setting auth site URL..."
  if $SUPABASE_CMD config set auth.site_url http://localhost:3000 2>/dev/null; then
    break
  elif [ $i -eq 3 ]; then
    error "Failed to set auth site URL after 3 attempts"
  else
    log "Auth site URL setting failed. Waiting 3 seconds before retry..."
    sleep 3
  fi
done

for i in {1..3}; do
  log "Attempt $i/3: Setting auth redirect URLs..."
  if $SUPABASE_CMD config set auth.additional_redirect_urls '["http://localhost:3000"]' 2>/dev/null; then
    break
  elif [ $i -eq 3 ]; then
    error "Failed to set auth redirect URLs after 3 attempts"
  else
    log "Auth redirect URLs setting failed. Waiting 3 seconds before retry..."
    sleep 3
  fi
done

log "Auth URLs configured successfully"

log "Setup complete! Your Supabase project is ready to use."
log "Project URL: $PROJECT_URL"
log "Project ID: $PROJECT_ID"
log "Project credentials have been added to your .env file"
log "Database password saved to template_postgres_pw"
