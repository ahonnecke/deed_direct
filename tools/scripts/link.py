#!/usr/bin/env python3
"""
Supabase Project Linking Script

This script handles only linking to an existing Supabase project.
It reads credentials from the .env file and uses the Supabase CLI directly.
It fails fast if any step fails.
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
    "blue": "\033[34m",
    "magenta": "\033[35m",
    "cyan": "\033[36m",
    "white": "\033[37m",
    "bold": "\033[1m",
}


def log(message: str) -> None:
    """Print a log message with timestamp."""
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


def main():
    """Main function to run the linking script."""
    parser = argparse.ArgumentParser(description="Link to Supabase project")
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
        error(
            "Project ID not found. Please provide it as an argument or set SUPABASE_PROJECT_ID in .env"
        )

    db_password = args.db_password or env_vars.get("SUPABASE_DB_PASSWORD")
    if not db_password:
        error(
            "Database password not found. Please provide it as an argument or set SUPABASE_DB_PASSWORD in .env"
        )

    # Initialize Supabase if needed
    initialize_supabase()

    # Link to the project
    link_project(project_id, db_password)

    log("Project linking complete! Your Supabase project is now linked.")
    log(f"Project ID: {project_id}")
    log("You can now run migrations with 'make run-migrations'")


if __name__ == "__main__":
    main()
