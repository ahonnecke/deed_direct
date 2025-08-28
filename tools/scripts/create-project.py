#!/usr/bin/env python3
"""
Supabase Project Creation Script

This script handles only the creation of a Supabase project and outputs the credentials
to the .env file. It does not handle linking or migrations.

It uses the Supabase CLI directly and fails fast if any step fails.
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
from pathlib import Path
from typing import Dict, Tuple

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


def generate_secure_password(length: int = 16) -> str:
    """Generate a secure password that's safe for command-line usage."""
    # Use secrets module for cryptographically strong random numbers
    # Avoid characters that could cause issues in command-line arguments
    # Specifically avoid: !$&()*;<>?[]\`|' and other shell special characters
    safe_alphabet = string.ascii_letters + string.digits + "#%+,-./:=@^_{}"
    password = "".join(secrets.choice(safe_alphabet) for _ in range(length))
    return password


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


def get_project_name(args) -> str:
    """Get the project name from package.json or user input. Always interactive."""
    # Project name is always interactive now, no CLI argument

    # Try to get project name from package.json
    package_name = None
    if os.path.exists("package.json"):
        try:
            with open("package.json", "r") as f:
                package_data = json.load(f)
                if "name" in package_data:
                    package_name = package_data["name"].lower().replace(" ", "-")
                    log(f"Found project name in package.json: {package_name}")
        except (json.JSONDecodeError, IOError) as e:
            warning(f"Failed to read package.json: {e}")

    # Default suggestion
    default_name = package_name or "supa-accelerator"
    
    # In non-interactive mode, use the default name
    if args.non_interactive:
        log(f"Using default project name (non-interactive mode): {default_name}")
        return default_name
    
    # Prompt for project name in interactive mode
    try:
        print(f"\n{COLORS['cyan']}Enter project name {COLORS['reset']}[{default_name}]: ", end="")
        user_input = input().strip()
        project_name = user_input if user_input else default_name
        log(f"Using project name: {project_name}")
        return project_name
    except KeyboardInterrupt:
        print("\n")
        error("Project creation cancelled by user")
        return ""


def check_project_exists(project_name: str) -> bool:
    """Check if a project with the given name already exists."""
    log(f"Checking if project '{project_name}' already exists...")

    result = run_command(["npx", "supabase", "projects", "list", "-o", "json"], check=True)
    
    try:
        projects = json.loads(result.stdout)
        
        if not projects:
            return False
            
        # Check if project exists in the list
        for project in projects:
            if project.get("name") == project_name:
                return True
                
        return False
    except json.JSONDecodeError:
        error(f"Invalid JSON response from Supabase CLI: {result.stdout}")
        return False


def create_project(project_name: str, org_id: str, region: str) -> Tuple[str, str]:
    """Create a new Supabase project and return the project ID and password."""
    log(f"Creating new Supabase project: {project_name} in region {region}")

    # Generate a secure password
    db_password = generate_secure_password()
    log("Generated secure database password")

    # Create the project - properly handle the password by using a single argument for each flag+value pair
    result = run_command(
        [
            "npx",
            "supabase",
            "projects",
            "create",
            project_name,
            f"--org-id={org_id}",
            f"--db-password={db_password}",
            f"--region={region}",
        ],
        check=True,
    )
    
    # Get project ID
    project_id = get_project_id(project_name)
    if not project_id:
        error("Failed to retrieve project ID. Project may not have been created successfully.")

    return project_id, db_password


def get_project_id(project_name: str) -> str:
    """Get the project ID for a given project name."""
    log("Retrieving project ID...")

    result = run_command(["npx", "supabase", "projects", "list", "-o", "json"], check=True)
    
    try:
        projects = json.loads(result.stdout)
        for project in projects:
            if project.get("name") == project_name:
                project_id = project.get("id")
                if project_id:
                    log(f"Project ID retrieved: {project_id}")
                    return project_id
        
        error(f"Project '{project_name}' not found in projects list")
    except json.JSONDecodeError:
        error(f"Invalid JSON response: {result.stdout}")
    
    return ""


def get_api_keys(project_id: str) -> Tuple[str, str]:
    """Get the API keys for a project."""
    log("Getting API keys...")

    result = run_command(
        [
            "npx",
            "supabase",
            "projects",
            "api-keys",
            f"--project-ref={project_id}",
            "-o",
            "json",
        ],
        check=True,
    )

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
        else:
            error("Failed to retrieve API keys from response")
    except json.JSONDecodeError:
        error(f"Invalid JSON response when retrieving API keys: {result.stdout}")
    
    return "", ""


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

    # Update environment variables - consolidate duplicates
    env_vars = {
        "SUPABASE_URL": project_url,
        "SUPABASE_ANON_KEY": anon_key,
        "SUPABASE_SERVICE_ROLE_KEY": service_key,
        "SUPABASE_DB_PASSWORD": db_password,
        "SUPABASE_ORG_ID": org_id,
        "SUPABASE_PROJECT_ID": project_id,
    }

    # Update each variable in the .env file
    for key, value in env_vars.items():
        pattern = re.compile(f"^{key}=.*", re.MULTILINE)
        if pattern.search(env_content):
            env_content = pattern.sub(f"{key}={value}", env_content)
        else:
            env_content += f"\n{key}={value}"
    
    # Also update the Next.js and Expo public variables
    if project_url:
        for key in ["NEXT_PUBLIC_SUPABASE_URL", "EXPO_PUBLIC_SUPABASE_URL"]:
            pattern = re.compile(f"^{key}=.*", re.MULTILINE)
            if pattern.search(env_content):
                env_content = pattern.sub(f"{key}={project_url}", env_content)
            else:
                env_content += f"\n{key}={project_url}"
    
    if anon_key:
        for key in ["NEXT_PUBLIC_SUPABASE_ANON_KEY", "EXPO_PUBLIC_SUPABASE_ANON_KEY"]:
            pattern = re.compile(f"^{key}=.*", re.MULTILINE)
            if pattern.search(env_content):
                env_content = pattern.sub(f"{key}={anon_key}", env_content)
            else:
                env_content += f"\n{key}={anon_key}"

    # Write updated content back to .env file
    with open(".env", "w") as f:
        f.write(env_content)

    log("Environment variables updated successfully")


def main():
    """Main function to run the setup script."""
    # Import configuration values from the centralized config file
    # Import configuration values
    # Define default values that will be overridden if import succeeds
    SUPABASE_ORG_ID = None
    SUPABASE_REGION = None
    
    try:
        from supabase_config import SUPABASE_ORG_ID, SUPABASE_REGION
    except ImportError:
        # Fallback to local import if the file is in the same directory
        try:
            from .supabase_config import SUPABASE_ORG_ID, SUPABASE_REGION
        except ImportError:
            log("Warning: Could not import supabase_config.py, will exit")
            sys.exit(1)
    
    parser = argparse.ArgumentParser(description="Create a Supabase project")
    parser.add_argument(
        "--org-id", default=SUPABASE_ORG_ID, help="Supabase organization ID"
    )
    parser.add_argument(
        "--region", default=SUPABASE_REGION, help="Region for the Supabase project"
    )
    parser.add_argument(
        "--non-interactive", action="store_true", help="Run in non-interactive mode (will use default values)"
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
        if args.non_interactive:
            # In non-interactive mode, just error out
            error(f"Project '{project_name}' already exists. Please use a different name or delete the existing project.")
        else:
            # In interactive mode, prompt for a new name
            while check_project_exists(project_name):
                warning(f"Project '{project_name}' already exists.")
                print(f"\n{COLORS['cyan']}Enter a different project name{COLORS['reset']}: ", end="")
                try:
                    user_input = input().strip()
                    if not user_input:
                        error("Project name cannot be empty. Project creation cancelled.")
                    project_name = user_input
                    log(f"Trying project name: {project_name}")
                except KeyboardInterrupt:
                    print("\n")
                    error("Project creation cancelled by user")

    # Create new project
    project_id, db_password = create_project(project_name, args.org_id, args.region)

    # Construct project URL from project ID
    project_url = f"https://{project_id}.supabase.co"
    log(f"Project URL constructed: {project_url}")

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

    log("Project creation complete!")
    log(f"Project URL: {project_url}")
    log(f"Project ID: {project_id}")
    log("Project credentials have been added to your .env file")
    log("Run 'make link-and-migrate' to link to the project and apply migrations")


if __name__ == "__main__":
    main()
