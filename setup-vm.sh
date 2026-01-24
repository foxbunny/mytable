#!/usr/bin/env bash

set -e

# Get script directory to ensure log file is created in the right place
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Setup logging
LOG_FILE="$SCRIPT_DIR/setup.log"

# Initialize log file
touch "$LOG_FILE"
echo "Setup started at $(date)" > "$LOG_FILE"

# Log function to append to log file
log() {
    cat >> "$LOG_FILE"
}

# Check if environment is Linux ARM64
OS=$(uname -s)
ARCH=$(uname -m)

if [ "$OS" != "Linux" ]; then
    echo "Error: This script requires Linux (detected: $OS)"
    exit 1
fi

if [ "$ARCH" != "aarch64" ] && [ "$ARCH" != "arm64" ]; then
    echo "Error: This script requires ARM64 architecture (detected: $ARCH)"
    exit 1
fi

echo "Environment check passed: Linux ARM64 ($ARCH)"

# Install NpgsqlRest if not already installed
NPGSQLREST_BIN="/usr/local/bin/NpgsqlRest"

if [ -f "$NPGSQLREST_BIN" ]; then
    echo "NpgsqlRest already installed in /usr/local/bin/"
else
    echo "Installing NpgsqlRest to /usr/local/bin/..."

    # Download the latest Linux ARM64 binary
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"

    DOWNLOAD_URL="https://github.com/NpgsqlRest/NpgsqlRest/releases/latest/download/npgsqlrest-linux-arm64"

    echo "Downloading from: $DOWNLOAD_URL"
    curl -L -o NpgsqlRest "$DOWNLOAD_URL" |& log

    # Install
    sudo mv NpgsqlRest "$NPGSQLREST_BIN" |& log
    sudo chmod +x "$NPGSQLREST_BIN" |& log

    # Cleanup
    cd - |& log
    rm -rf "$TEMP_DIR" |& log

    echo "NpgsqlRest installed successfully"
fi

# Install dbmate if not already installed
DBMATE_BIN="/usr/local/bin/dbmate"

echo ""
if [ -f "$DBMATE_BIN" ]; then
    echo "dbmate already installed in /usr/local/bin/"
else
    echo "Installing dbmate to /usr/local/bin/..."

    # Download the latest Linux ARM64 binary
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"

    DOWNLOAD_URL="https://github.com/amacneil/dbmate/releases/latest/download/dbmate-linux-arm64"

    echo "Downloading from: $DOWNLOAD_URL"
    curl -L -o dbmate "$DOWNLOAD_URL" |& log

    # Install
    sudo mv dbmate "$DBMATE_BIN" |& log
    sudo chmod +x "$DBMATE_BIN" |& log

    # Cleanup
    cd - |& log
    rm -rf "$TEMP_DIR" |& log

    echo "dbmate installed successfully"
fi

# Install PostgreSQL 18 if not already installed
echo ""
if command -v psql &> /dev/null && psql --version | grep -q "18"; then
    echo "PostgreSQL 18 already installed"
else
    echo "Installing PostgreSQL 18..."

    # Add PostgreSQL APT repository (modern method for Ubuntu 22.04+)
    sudo apt-get update |& log
    sudo apt-get install -y wget ca-certificates gnupg |& log

    # Create keyrings directory if it doesn't exist
    sudo mkdir -p /usr/share/keyrings |& log

    # Download and install the PostgreSQL GPG key
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | \
        sudo gpg --dearmor -o /usr/share/keyrings/postgresql-archive-keyring.gpg |& log

    # Add the PostgreSQL repository with signed-by option
    echo "deb [signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" | \
        sudo tee /etc/apt/sources.list.d/pgdg.list |& log

    # Install PostgreSQL 18
    sudo apt-get update |& log
    sudo apt-get install -y postgresql-18 postgresql-contrib-18 |& log

    # Verify installation
    if command -v psql &> /dev/null; then
        echo "PostgreSQL 18 installed successfully"
    else
        echo "ERROR: PostgreSQL installation failed - psql command not found"
        echo "Check $LOG_FILE for details"
        exit 1
    fi
fi

# Configure PostgreSQL for local access without password
echo "Configuring PostgreSQL for local access..."

PG_HBA_CONF="/etc/postgresql/18/main/pg_hba.conf"

if [ -f "$PG_HBA_CONF" ]; then
    # Backup original config
    sudo cp "$PG_HBA_CONF" "${PG_HBA_CONF}.backup" |& log

    # Configure trust authentication for local connections
    sudo sed -i 's/^local\s\+all\s\+all\s\+peer/local   all             all                                     trust/' "$PG_HBA_CONF" |& log
    sudo sed -i 's/^host\s\+all\s\+all\s\+127\.0\.0\.1\/32\s\+scram-sha-256/host    all             all             127.0.0.1\/32            trust/' "$PG_HBA_CONF" |& log
    sudo sed -i 's/^host\s\+all\s\+all\s\+::1\/128\s\+scram-sha-256/host    all             all             ::1\/128                 trust/' "$PG_HBA_CONF" |& log

    # Restart PostgreSQL to apply changes
    sudo systemctl restart postgresql |& log
    sudo systemctl enable postgresql |& log

    echo "PostgreSQL configured for local access without password"
else
    echo "Warning: PostgreSQL config file not found at $PG_HBA_CONF"
fi

# Create database user and table
echo "Setting up database and table..."

DB_USER=$(whoami)
DB_NAME="mytable"
DB_HOST="localhost"
DB_PORT="5432"

# Create database user if not exists
sudo -u postgres psql -tc "SELECT 1 FROM pg_user WHERE usename = '$DB_USER'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE USER $DB_USER WITH SUPERUSER;" |& log

# Create database if not exists
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;" |& log

# Create mytable if not exists
psql -U $DB_USER -d $DB_NAME -tc "SELECT 1 FROM information_schema.tables WHERE table_name = 'mytable'" | grep -q 1 || \
    psql -U $DB_USER -d $DB_NAME -c "CREATE TABLE mytable (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100),
        created_at TIMESTAMP DEFAULT NOW()
    );" |& log

echo "Database user '$DB_USER' and table 'mytable' created successfully"

# Add DATABASE_URL to ~/.bashrc if not already present
DATABASE_URL="postgres://$DB_USER@$DB_HOST:$DB_PORT/$DB_NAME?sslmode=disable"
BASHRC_FILE="$HOME/.bashrc"

if ! grep -q "DATABASE_URL" "$BASHRC_FILE" 2>/dev/null; then
    echo "" >> "$BASHRC_FILE"
    echo "# Database connection for mytable (added by setup-vm.sh)" >> "$BASHRC_FILE"
    echo "export DATABASE_URL=\"$DATABASE_URL\"" >> "$BASHRC_FILE"
    echo "DATABASE_URL added to $BASHRC_FILE"
else
    echo "DATABASE_URL already configured in $BASHRC_FILE"
fi

# Output setup summary
echo ""
echo "=========================================="
echo "Setup Summary"
echo "=========================================="
echo ""
echo "Environment:"
echo "  OS: Linux"
echo "  Architecture: $ARCH"
echo ""
echo "Installed Tools:"
echo "  NpgsqlRest: $NPGSQLREST_BIN"
echo "  dbmate: $DBMATE_BIN"
echo "  PostgreSQL: $(psql --version 2>/dev/null || echo 'Not found')"
echo ""
echo "PostgreSQL Service:"
echo "  Status: $(systemctl is-active postgresql 2>/dev/null || echo 'unknown')"
echo "  Local access: Configured (no password required)"
echo ""
echo "Database Connection:"
echo "  Host: $DB_HOST"
echo "  Port: $DB_PORT"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo "  Password: (none required)"
echo "  Connection String: postgresql://$DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
echo "  DATABASE_URL: $DATABASE_URL (exported in ~/.bashrc)"
echo ""
echo "Usage:"
echo "  Run NpgsqlRest: NpgsqlRest [options]"
echo "  Get help: NpgsqlRest --help"
echo "  Connect to database: psql -U $DB_USER -d $DB_NAME"
echo "  List tables: psql -U $DB_USER -d $DB_NAME -c '\\dt'"
echo ""
echo "Database Migrations (dbmate):"
echo "  Create migration: dbmate new migration_name"
echo "  Apply migrations: dbmate up"
echo "  Rollback migration: dbmate rollback"
echo "  Get help: dbmate --help"
echo ""
echo "Testing:"
echo "  Run tests: ./test-db.sh"
echo ""
echo "Log file: $LOG_FILE"
echo "=========================================="
