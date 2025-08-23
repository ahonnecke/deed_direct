#!/usr/bin/env python3
"""
Supabase Migration Script

This script handles applying migrations to a linked Supabase project.
It uses the Supabase CLI directly and fails fast if any step fails.
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


def check_project_linked() -> bool:
    """Check if a project is linked."""
    log("Checking if a project is linked...")
    
    # Check if the .supabase/config.json file exists, which indicates a linked project
    if not os.path.exists(".supabase/config.json"):
        return False
        
    # Run supabase status to verify the project is properly linked
    result = run_command(["npx", "supabase", "status"], check=False)
    
    # Even if the command fails, we'll check the output for project information
    return result.returncode == 0 or "Project ID:" in (result.stdout or "")


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
    log("Setting auth site URL...")
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
    log("Setting auth redirect URLs...")
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
    """Main function to run the migration script."""
    parser = argparse.ArgumentParser(description="Apply migrations to Supabase project")
    parser.add_argument(
        "--skip-auth-setup", action="store_true", help="Skip auth URL setup"
    )
    args = parser.parse_args()

    # Ensure we're in the project root directory
    os.chdir(
        os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    )

    # Check if a project is linked
    if not check_project_linked():
        error("No project is linked. Please run link.py first.")

    # Sync remote changes
    sync_remote_changes()

    # Apply migrations
    apply_migrations()

    # Set up auth redirect URLs if not skipped
    if not args.skip_auth_setup:
        setup_auth_urls()

    log("Migrations applied successfully!")


if __name__ == "__main__":
    main()
