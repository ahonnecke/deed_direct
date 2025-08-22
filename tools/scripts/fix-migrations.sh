#!/bin/bash

# Script to fix migration issues by comparing local and remote migrations
# and applying the necessary repair commands

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Listing migrations to determine what needs to be fixed...${NC}"
MIGRATIONS_OUTPUT=$(npx supabase migration list)

echo -e "${GREEN}Current migration status:${NC}"
echo "$MIGRATIONS_OUTPUT"

# Extract local migrations - look for lines with migration numbers in the first column
# The format is typically "   0001  |        | 0001       "
LOCAL_MIGRATIONS=$(echo "$MIGRATIONS_OUTPUT" | grep -E "^\s*[0-9]+" | awk '{print $1}')

# Check if we have any migrations to fix
if [ -z "$LOCAL_MIGRATIONS" ]; then
  echo -e "${RED}No migrations found in the output. Trying direct file listing...${NC}"
  
  # Try to get migrations directly from the files
  MIGRATION_FILES=$(ls -1 supabase/migrations/*.sql 2>/dev/null | sort)
  
  if [ -z "$MIGRATION_FILES" ]; then
    echo -e "${RED}No migration files found in supabase/migrations/. Make sure you are in the correct directory.${NC}"
    exit 1
  fi
  
  echo -e "${GREEN}Found migration files:${NC}"
  echo "$MIGRATION_FILES"
  
  # Extract migration numbers from filenames
  for FILE in $MIGRATION_FILES; do
    FILENAME=$(basename "$FILE")
    MIGRATION_NUMBER=$(echo "$FILENAME" | grep -oE '^[0-9]+' | head -1)
    
    if [ ! -z "$MIGRATION_NUMBER" ]; then
      echo -e "${YELLOW}Repairing migration $MIGRATION_NUMBER from file $FILENAME...${NC}"
      npx supabase migration repair --status applied "$MIGRATION_NUMBER"
      if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully repaired migration $MIGRATION_NUMBER${NC}"
      else
        echo -e "${RED}Failed to repair migration $MIGRATION_NUMBER${NC}"
      fi
    fi
  done
else
  echo -e "\n${YELLOW}Preparing to fix migrations...${NC}"

  # For each migration, check if it needs to be repaired
  for MIGRATION in $LOCAL_MIGRATIONS; do
    # Check if migration is marked as applied (has a non-empty Remote column)
    if echo "$MIGRATIONS_OUTPUT" | grep -q "^\s*$MIGRATION\s*|\s*$MIGRATION"; then
      echo -e "${GREEN}Migration $MIGRATION is already applied. Skipping.${NC}"
    else
      echo -e "${YELLOW}Repairing migration $MIGRATION...${NC}"
      npx supabase migration repair --status applied "$MIGRATION"
      if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully repaired migration $MIGRATION${NC}"
      else
        echo -e "${RED}Failed to repair migration $MIGRATION${NC}"
      fi
    fi
  done
fi

echo -e "\n${GREEN}Migration repair complete. Running migration list again to verify:${NC}"
npx supabase migration list

echo -e "\n${GREEN}You can now run 'make run-migrations' to apply any pending changes.${NC}"
