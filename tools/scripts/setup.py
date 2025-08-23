#!/usr/bin/env python3
"""
Supabase Setup Script

This script automates the setup of a Supabase project for the application.
It handles:
- Login verification
- Project creation
- Project ID and URL retrieval
- API key retrieval
- Environment variable configuration
- Database initialization and migration
"""

import argparse
import json
import os
import random
import re
import secrets
import string
import subprocess
import sys
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Union

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
    cmd: List[str], check: bool = True, capture_output: bool = True
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


def generate_secure_password(length: int = 16) -> str:
    """Generate a secure password."""
    # Use secrets module for cryptographically strong random numbers
    alphabet = string.ascii_letters + string.digits + "!#$%&()*+,-./:;<=>?@[]^_`{|}~"
    password = "".join(secrets.choice(alphabet) for _ in range(length))
    return password


def check_supabase_login() -> bool:
    """Check if the user is logged in to Supabase CLI."""
    log("Checking Supabase login status...")

    # Check for token files in possible locations
    token_locations = [
        os.path.expanduser("~/.supabase/access-token"),
        os.path.expanduser("~/.config/supabase/access-token"),
        os.path.expanduser("~/.config/supabase/tokens.json"),
    ]

    for location in token_locations:
        if os.path.exists(location):
            log(f"Token file found at: {location}")
            return True

    # Try to list projects as a login test
    result = run_command(["npx", "supabase", "projects", "list"], check=False)
    return result.returncode == 0


def login_to_supabase() -> None:
    """Login to Supabase CLI."""
    log("Please login to Supabase")
    run_command(["npx", "supabase", "login"], check=False, capture_output=False)
    log("Waiting for login to complete...")
    time.sleep(3)


def get_project_name(args) -> str:
    """Get the project name from arguments or package.json."""
    if args.project_name:
        return args.project_name

    # Try to get project name from package.json
    if os.path.exists("package.json"):
        try:
            with open("package.json", "r") as f:
                package_data = json.load(f)
                if "name" in package_data:
                    project_name = package_data["name"].lower().replace(" ", "-")
                    log(f"Using project name from package.json: {project_name}")
                    return project_name
        except (json.JSONDecodeError, IOError) as e:
            warning(f"Failed to read package.json: {e}")

    # Default project name
    default_name = "supa-accelerator"
    log(f"Using default project name: {default_name}")
    return default_name


def check_project_exists(project_name: str) -> bool:
    """Check if a project with the given name already exists."""
    log(f"Checking if project '{project_name}' already exists...")

    for attempt in range(1, 4):
        log(f"Attempt {attempt}/3: Retrieving projects list...")

        # Now try with JSON format
        result = run_command(
            ["npx", "supabase", "projects", "list", "-o", "json"], check=False
        )

        if result.returncode == 0 and result.stdout:
            try:
                projects = json.loads(result.stdout)
                log("Valid JSON response received")

                if not projects:
                    return False

                # Check if project exists in the list
                for project in projects:
                    if project.get("name") == project_name:
                        return True

                # Project not found
                return False
            except json.JSONDecodeError:
                log(f"Invalid JSON response: {result.stdout}")

        log("Waiting before retry...")
        time.sleep(1)

    # If we can't determine if the project exists, assume it doesn't
    log("Could not determine if project exists. Proceeding with creation.")
    return False


def create_project(project_name: str, org_id: str, region: str) -> Tuple[str, str]:
    """Create a new Supabase project and return the project ID and password."""
    log(f"Creating new Supabase project: {project_name} in region {region}")

    # Generate a secure password
    db_password = generate_secure_password()
    log("Generated secure database password")

    # Save password to file for reference
    with open("template_postgres_pw", "w") as f:
        f.write(db_password)
    log("Saved database password to template_postgres_pw")

    # Create the project with retries
    for attempt in range(1, 4):
        log(f"Attempt {attempt}/3: Creating Supabase project...")
        result = run_command(
            [
                "npx",
                "supabase",
                "projects",
                "create",
                project_name,
                "--org-id",
                org_id,
                "--db-password",
                db_password,
                "--region",
                region,
            ],
            check=False,
        )

        if result.returncode == 0:
            log("Project creation command executed successfully")
            break

        if attempt < 3:
            log("Project creation attempt failed. Waiting before retry...")
            time.sleep(1)
        else:
            log("Failed to create project after 3 attempts")
            log(
                "Will try to continue in case the project was actually created despite the error"
            )

    # Get project ID with retries
    project_id = get_project_id(project_name)
    if not project_id:
        error(
            "Failed to retrieve project ID after multiple attempts. Project may not have been created successfully."
        )

    return project_id, db_password


def get_project_id(project_name: str) -> Optional[str]:
    """Get the project ID for a given project name."""
    log("Retrieving project ID...")

    for attempt in range(1, 6):
        log(f"Attempt {attempt}/5: Getting project ID...")
        result = run_command(
            ["npx", "supabase", "projects", "list", "-o", "json"], check=False
        )

        if result.returncode == 0 and result.stdout:
            try:
                projects = json.loads(result.stdout)
                for project in projects:
                    if project.get("name") == project_name:
                        project_id = project.get("id")
                        if project_id:
                            log(f"Project ID retrieved: {project_id}")
                            return project_id
            except json.JSONDecodeError:
                log(f"Invalid JSON response: {result.stdout}")

        log("Waiting for project ID to be available...")
        time.sleep(10)

    return None


def get_api_keys(project_id: str) -> Tuple[Optional[str], Optional[str]]:
    """Get the API keys for a project."""
    log("Getting API keys...")

    # Try multiple times with increasing wait times
    for attempt in range(1, 6):
        log(f"Attempt {attempt}/5: Retrieving API keys...")

        # First try direct command to see output
        if attempt == 1:
            log("Running direct API keys command to see output format:")
            run_command(
                [
                    "npx",
                    "supabase",
                    "projects",
                    "api-keys",
                    "--project-ref",
                    project_id,
                ],
                check=False,
                capture_output=False,
            )

        # Now try with JSON format
        result = run_command(
            [
                "npx",
                "supabase",
                "projects",
                "api-keys",
                "--project-ref",
                project_id,
                "-o",
                "json",
            ],
            check=False,
        )

        if result.returncode == 0 and result.stdout:
            try:
                keys_data = json.loads(result.stdout)
                anon_key = None
                service_key = None

                for key in keys_data:
                    if key.get("name") == "anon":
                        anon_key = key.get("api_key")
                    elif key.get("name") == "service_role":
                        service_key = key.get("api_key")

                if anon_key and service_key:
                    log("API keys retrieved successfully")
                    return anon_key, service_key
            except json.JSONDecodeError:
                log(f"Invalid JSON response: {result.stdout}")

                # Try alternative extraction method
                anon_key = re.search(r'"anon"[^}]*"api_key":"([^"]*)"', result.stdout)
                service_key = re.search(
                    r'"service_role"[^}]*"api_key":"([^"]*)"', result.stdout
                )

                if anon_key and service_key:
                    log("API keys retrieved using alternative method")
                    return anon_key.group(1), service_key.group(1)

        log("Waiting for API keys to be available...")
        time.sleep(attempt * 5)  # Increasing wait time for each retry

    # If we still don't have keys, try one more approach - direct parsing from project show
    log("Trying to get API keys from project show command...")
    result = run_command(
        ["npx", "supabase", "projects", "show", "--project-ref", project_id],
        check=False,
    )

    if result.returncode == 0 and result.stdout:
        # Try to extract keys from the output
        anon_match = re.search(r"anon:\s*\n\s*([^\n]+)", result.stdout)
        service_match = re.search(r"service_role:\s*\n\s*([^\n]+)", result.stdout)

        if anon_match and service_match:
            anon_key = anon_match.group(1).strip()
            service_key = service_match.group(1).strip()
            log("API keys retrieved from project show command")
            return anon_key, service_key

    return None, None


def link_project(project_id: str, db_password: str) -> bool:
    """Link to the Supabase project."""
    log("Linking to Supabase project...")

    # Link with the password we created - retry up to 5 times
    log("Linking project with database password...")
    for attempt in range(1, 6):
        log(f"Attempt {attempt}/5: Linking to project...")
        result = run_command(
            [
                "npx",
                "supabase",
                "link",
                "--project-ref",
                project_id,
                "--password",
                db_password,
            ],
            check=False,
        )

        if result.returncode == 0:
            log("Successfully linked to project!")
            return True

        log(f"Link attempt output: {result.stdout}")

        if attempt == 5:
            error(
                "Failed to link project after 5 attempts. Please check your database password."
            )
        else:
            log("Link attempt failed. Waiting before retry...")
            time.sleep(10)

    return False


def update_env_file(
    project_id: str,
    project_url: str,
    anon_key: str,
    service_key: str,
    db_password: str,
    org_id: str,
) -> None:
    """Update the .env file with Supabase credentials."""
    log("Updating .env file with Supabase credentials...")

    # Create .env file if it doesn't exist
    if not os.path.exists(".env"):
        if os.path.exists(".env.example"):
            log("Creating .env file from .env.example")
            with open(".env.example", "r") as src, open(".env", "w") as dst:
                dst.write(src.read())
        elif os.path.exists(".env.template"):
            log("Creating .env file from .env.template")
            with open(".env.template", "r") as src, open(".env", "w") as dst:
                dst.write(src.read())
        else:
            log("Creating empty .env file")
            open(".env", "w").close()

    # Read current .env file
    with open(".env", "r") as f:
        env_content = f.read()

    # Update environment variables
    env_vars = {
        "NEXT_PUBLIC_SUPABASE_URL": project_url,
        "NEXT_PUBLIC_SUPABASE_ANON_KEY": anon_key,
        "SUPABASE_URL": project_url,
        "SUPABASE_ANON_KEY": anon_key,
        "SUPABASE_SERVICE_KEY": service_key,
        "POSTGRES_PASSWORD": db_password,
        "SUPABASE_ORG_ID": org_id,
    }

    # Update each variable in the .env file
    for key, value in env_vars.items():
        pattern = re.compile(f"^{key}=.*", re.MULTILINE)
        if pattern.search(env_content):
            env_content = pattern.sub(f"{key}={value}", env_content)
        else:
            env_content += f"\n{key}={value}"

    # Write updated content back to .env file
    with open(".env", "w") as f:
        f.write(env_content)

    log("Environment variables updated successfully")


def initialize_supabase() -> None:
    """Initialize Supabase if not already initialized."""
    if not os.path.exists("supabase"):
        log("Initializing Supabase...")
        result = run_command(["npx", "supabase", "init"], check=False)
        if result.returncode != 0:
            error("Failed to initialize Supabase")
        log("Supabase initialized successfully")


def sync_remote_changes() -> bool:
    """Sync remote configuration."""
    log("Syncing configuration from remote project...")
    for attempt in range(1, 4):
        log(f"Attempt {attempt}/3: Syncing remote changes...")
        result = run_command(
            ["npx", "supabase", "db", "remote", "changes"], check=False
        )

        if result.returncode == 0:
            log("Successfully synced remote changes")
            return True

        if attempt == 3:
            error("Failed to sync remote changes after 3 attempts")
        else:
            log("Sync attempt failed. Waiting before retry...")
            time.sleep(5)

    return False


def apply_migrations() -> bool:
    """Apply migrations to Supabase project."""
    log("Applying migrations to Supabase project...")
    for attempt in range(1, 4):
        log(f"Attempt {attempt}/3: Pushing migrations...")
        result = run_command(["npx", "supabase", "db", "push"], check=False)

        if result.returncode == 0:
            log("Successfully pushed migrations")
            return True

        if attempt == 3:
            error("Failed to push migrations after 3 attempts")
        else:
            log("Migration push attempt failed. Waiting before retry...")
            time.sleep(5)

    return False


def setup_auth_urls() -> bool:
    """Set up auth redirect URLs."""
    log("Setting up auth redirect URLs...")

    # Set site URL
    for attempt in range(1, 4):
        log(f"Attempt {attempt}/3: Setting auth site URL...")
        result = run_command(
            [
                "npx",
                "supabase",
                "config",
                "set",
                "auth.site_url",
                "http://localhost:3000",
            ],
            check=False,
        )

        if result.returncode == 0:
            break

        if attempt == 3:
            error("Failed to set auth site URL after 3 attempts")
        else:
            log("Auth site URL setting failed. Waiting before retry...")
            time.sleep(3)

    # Set redirect URLs
    for attempt in range(1, 4):
        log(f"Attempt {attempt}/3: Setting auth redirect URLs...")
        result = run_command(
            [
                "npx",
                "supabase",
                "config",
                "set",
                "auth.additional_redirect_urls",
                '["http://localhost:3000"]',
            ],
            check=False,
        )

        if result.returncode == 0:
            break

        if attempt == 3:
            error("Failed to set auth redirect URLs after 3 attempts")
        else:
            log("Auth redirect URLs setting failed. Waiting before retry...")
            time.sleep(3)

    log("Auth URLs configured successfully")
    return True


def main():
    """Main function to run the setup script."""
    parser = argparse.ArgumentParser(description="Set up a Supabase project")
    parser.add_argument("--project-name", help="Name of the Supabase project")
    parser.add_argument(
        "--org-id", default="wtzdspvojbntegninaxc", help="Supabase organization ID"
    )
    parser.add_argument(
        "--region", default="us-west-1", help="Region for the Supabase project"
    )
    args = parser.parse_args()

    # Ensure we're in the project root directory
    os.chdir(
        os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    )

    # Check if logged in, if not, login
    if not check_supabase_login():
        login_to_supabase()

    # Get project name
    project_name = get_project_name(args)

    # Check if project already exists
    if check_project_exists(project_name):
        error(
            f"Project '{project_name}' already exists. Please use a different name or delete the existing project."
        )

    # Create new project
    project_id, db_password = create_project(project_name, args.org_id, args.region)

    # Construct project URL from project ID
    project_url = f"https://{project_id}.supabase.co"
    log(f"Project URL constructed: {project_url}")

    # Link to the project
    link_project(project_id, db_password)

    # Get API keys
    anon_key, service_key = get_api_keys(project_id)
    if not anon_key or not service_key:
        error("Failed to retrieve API keys")

    # Mask keys for logging
    anon_key_masked = anon_key[:5] + "..."
    service_key_masked = service_key[:5] + "..."
    log(
        f"API keys retrieved: Anon key: {anon_key_masked}, Service key: {service_key_masked}"
    )

    # Update environment variables
    update_env_file(
        project_id, project_url, anon_key, service_key, db_password, args.org_id
    )

    # Initialize Supabase
    initialize_supabase()

    # Sync remote changes
    sync_remote_changes()

    # Apply migrations
    apply_migrations()

    # Set up auth redirect URLs
    setup_auth_urls()

    log("Setup complete! Your Supabase project is ready to use.")
    log(f"Project URL: {project_url}")
    log(f"Project ID: {project_id}")
    log("Project credentials have been added to your .env file")
    log("Database password saved to template_postgres_pw")


if __name__ == "__main__":
    main()
