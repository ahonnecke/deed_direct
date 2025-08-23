#!/usr/bin/env python3
"""
Supabase Project Linking and Migration Script

This script handles linking to an existing Supabase project and applying migrations.
It reads credentials from the .env file and uses direct Supabase CLI commands
with fail-fast behavior.
"""

import argparse
import os
import subprocess
import sys
from typing import Dict

# ANSI color codes for terminal output
COLORS = {
    "reset": "\033[0m",
    "red": "\033[31m",
    "green": "\033[32m",
    "yellow": "\033[33m",
}


def log(message: str) -> None:
    """Print a log message."""
    print(f"{COLORS['green']}[SETUP]{COLORS['reset']} {message}")


def error(message: str) -> None:
    """Print an error message and exit."""
    print(f"{COLORS['red']}[ERROR]{COLORS['reset']} {message}")
    sys.exit(1)


def warning(message: str) -> None:
    """Print a warning message."""
    print(f"{COLORS['yellow']}[WARNING]{COLORS['reset']} {message}")


def run_command(
    cmd: list[str], check: bool = True, capture_output: bool = True
) -> subprocess.CompletedProcess:
    """Run a command and return the result."""
    try:
        log(f"Running command: {' '.join(cmd)}")
        result = subprocess.run(
            cmd,
            check=check,
            capture_output=capture_output,
            text=True,
        )
        return result
    except subprocess.CalledProcessError as e:
        if check:
            error(f"Command failed: {e}")
        return e


def check_supabase_login() -> bool:
    """Check if the user is logged in to Supabase CLI."""
    log("Checking Supabase login status...")
    
    # Try to list projects as a login test
    result = run_command(["npx", "supabase", "projects", "list"], check=False)
    return result.returncode == 0


def login_to_supabase() -> None:
    """Login to Supabase CLI."""
    log("Please login to Supabase")
    run_command(["npx", "supabase", "login"], check=True, capture_output=False)


def read_env_file() -> Dict[str, str]:
    """Read environment variables from .env file."""
    log("Reading environment variables from .env file...")
    
    if not os.path.exists(".env"):
        error(".env file not found. Please run create-project.py first.")
    
    env_vars = {}
    with open(".env", "r") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                env_vars[key] = value
    
    return env_vars


def link_project(project_id: str, db_password: str) -> None:
    """Link to the Supabase project."""
    log("Linking to Supabase project...")
    
    # Make sure we have a valid password
    if not db_password:
        error("Database password is empty. Cannot link project.")
    
    # Link with the password
    log("Linking project with database password...")
    run_command(
        [
            "npx",
            "supabase",
            "link",
            "--project-ref",
            project_id,
            "--password",
            db_password,
        ],
        check=True,
        capture_output=False,
    )
    log("Successfully linked to project!")


def initialize_supabase() -> None:
    """Initialize Supabase if not already initialized."""
    if not os.path.exists("supabase"):
        log("Initializing Supabase...")
        run_command(["npx", "supabase", "init"], check=True)
        log("Supabase initialized successfully")


def sync_remote_changes() -> None:
    """Sync remote configuration."""
    log("Syncing configuration from remote project...")
    run_command(["npx", "supabase", "db", "remote", "changes"], check=True)
    log("Successfully synced remote changes")


def apply_migrations() -> None:
    """Apply migrations to Supabase project."""
    log("Applying migrations to Supabase project...")
    run_command(["npx", "supabase", "db", "push"], check=True, capture_output=False)
    log("Successfully pushed migrations")


def setup_auth_urls() -> None:
    """Set up auth redirect URLs."""
    log("Setting up auth redirect URLs...")

    # Set site URL
    run_command(
        [
            "npx",
            "supabase",
            "config",
            "set",
            "auth.site_url",
            "http://localhost:3000",
        ],
        check=True,
    )

    # Set redirect URLs
    run_command(
        [
            "npx",
            "supabase",
            "config",
            "set",
            "auth.additional_redirect_urls",
            '["http://localhost:3000"]',
        ],
        check=True,
    )

    log("Auth URLs configured successfully")


def main():
    """Main function to run the linking and migration script."""
    parser = argparse.ArgumentParser(description="Link to Supabase project and apply migrations")
    parser.add_argument("--project-id", help="ID of the Supabase project")
    parser.add_argument("--db-password", help="Database password for the project")
    args = parser.parse_args()

    # Ensure we're in the project root directory
    os.chdir(
        os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    )

    # Check if logged in, if not, login
    if not check_supabase_login():
        login_to_supabase()

    # Read environment variables from .env file
    env_vars = read_env_file()
    
    # Get project ID and DB password from args or env vars
    project_id = args.project_id or env_vars.get("SUPABASE_PROJECT_ID")
    if not project_id:
        error("Project ID not found. Please provide it as an argument or set SUPABASE_PROJECT_ID in .env")
    
    db_password = args.db_password or env_vars.get("SUPABASE_DB_PASSWORD")
    if not db_password:
        error("Database password not found. Please provide it as an argument or set SUPABASE_DB_PASSWORD in .env")

    # Initialize Supabase if needed
    initialize_supabase()
    
    # Link to the project
    link_project(project_id, db_password)
    
    # Sync remote changes
    sync_remote_changes()
    
    # Apply migrations
    apply_migrations()
    
    # Set up auth redirect URLs
    setup_auth_urls()
    
    log("Setup complete! Your Supabase project is linked and migrations are applied.")
    log(f"Project ID: {project_id}")



if __name__ == "__main__":
    main()
