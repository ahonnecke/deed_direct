# Supabase + Expo Accelerator

A full-stack monorepo with **Next.js (web)** + **Expo (mobile)** powered by **Supabase**.

## Quick Start

```bash
# Clone the repository
git clone <repository-url>
cd supabase_expo_accelerator_plan

# Copy environment variables template
cp .env.example .env

# Start the web app with Docker
make docker.build

# Open in browser
# http://localhost:3000
```

## Prerequisites

### Docker Installation

#### Linux (Ubuntu/Debian)
```bash
# Update package index
sudo apt update

# Install dependencies
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Add Docker repository
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Add your user to the docker group (to run Docker without sudo)
sudo usermod -aG docker $USER
# Log out and log back in for changes to take effect
```

#### macOS
1. Download and install Docker Desktop from [Docker Hub](https://www.docker.com/products/docker-desktop)
2. Start Docker Desktop from your Applications folder

#### Windows
1. Download and install Docker Desktop from [Docker Hub](https://www.docker.com/products/docker-desktop)
2. Follow the installation wizard
3. Ensure WSL 2 is installed and configured if prompted

### Node.js and pnpm
```bash
# Install Node.js 20+ (recommended via nvm)
nvm install 20
nvm use 20

# Enable and use pnpm 9+
corepack enable
corepack use pnpm@9
```

## Environment Setup

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

2. Update the following required variables in `.env`:
   - `NEXT_PUBLIC_SUPABASE_URL`: Your Supabase project URL
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`: Your Supabase anonymous key
   - `SUPABASE_URL`: Same as public URL
   - `SUPABASE_ANON_KEY`: Same as public anon key
   - `SUPABASE_SERVICE_ROLE_KEY`: Your Supabase service role key (for admin operations)

## Development Options

### Option 1: Docker Development (Recommended)
```bash
# Build and start the web app
make docker.build

# Or start without rebuilding
make docker.up

# Stop containers when done
make docker.down

# Access the web app at http://localhost:3000
```

### Option 2: Local Development
```bash
# Install dependencies
make dev.install

# Start the web app
make dev.web

# Access the web app at http://localhost:3000
```

### Mobile Development
```bash
# Install dependencies (if not done already)
make dev.install

# Start the Expo app
make dev.mobile
```

## Supabase Setup

### Option A: Create a new Supabase project
```bash
# Create a new Supabase project
make setup.create-project

# Link to the newly created project and apply migrations
make setup.link-and-migrate
```

### Option B: Link to an existing Supabase project
```bash
# Login to Supabase (first time only)
make sb.login

# Link to your existing Supabase project and apply migrations
make setup.link-and-migrate
```

### Option C: Complete setup in one command
```bash
# Run the complete setup process
make setup.all
```

## Project Structure

- `apps/web` — Next.js 14 (App Router) web application
- `apps/mobile` — Expo Router mobile application
- `packages/ui` — Shared UI components (Tamagui)
- `packages/shared` — Shared utilities and types
- `packages/supabase` — Supabase client configurations
- `supabase/` — Migrations and Edge Functions

## Common Commands

### Project Scripts
```bash
# Run development servers
make dev.all

# Run TypeScript checks
make dev.typecheck

# Run tests
make dev.test
```

### Web App Commands
```bash
# Start development server
make dev.web

# Build and start with Docker
make docker.build
```

### Mobile App Commands
```bash
# Start Expo development server
make dev.mobile
```

## Troubleshooting

### Docker Issues
- **Container fails to start**: Check if ports are already in use (`lsof -i :3000`)
- **Environment variables not loading**: Ensure `.env` file exists and has correct permissions
- **Build fails**: Try rebuilding with `make docker.build` or manually with `docker compose build --no-cache web`

### Supabase Issues
- **Connection errors**: Verify your Supabase URL and keys in `.env`
- **Migration failures**: Check Supabase CLI installation and login status
- **Supabase setup hangs**: Check your network connection and Supabase login status with `npx supabase projects list`

### Development Issues
- **pnpm workspace not recognized**: Ensure `pnpm-workspace.yaml` includes `apps/*` and `packages/*`
- **Docker build fails copying `public/`**: Ensure `apps/web/public/` exists
- **Edge runtime warnings**: Split clients into `client.browser.ts` and `client.ssr.ts` for different runtimes

## Additional Resources

- [Supabase Documentation](https://supabase.com/docs)
- [Next.js Documentation](https://nextjs.org/docs)
- [Expo Documentation](https://docs.expo.dev)
- [Tamagui Documentation](https://tamagui.dev/docs)
- [Docker Documentation](https://docs.docker.com)

## License

MIT
