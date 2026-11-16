#!/usr/bin/env bash
# ==============================================================================
# Manual / Automated Setup Script for Java, Apache Tomcat & PostgreSQL on Ubuntu
# Supported OS: Ubuntu 22.04 LTS / 24.04 LTS
# ==============================================================================

set -euo pipefail

# Configuration Variables
TOMCAT_VERSION="10.1.34"
TOMCAT_MAJOR="10"
TOMCAT_TAR_URL="https://archive.apache.org/dist/tomcat/tomcat-${TOMCAT_MAJOR}/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"
INSTALL_DIR="/opt/tomcat"
TOMCAT_USER="tomcat"
TOMCAT_GROUP="tomcat"
PG_USER="appuser"
PG_PASSWORD="AppSecurePassword123!"
PG_DATABASE="appdb"

echo "========================================================================"
echo " Starting Full Manual Stack Deployment (Ubuntu + Java + Tomcat + Postgres)"
echo "========================================================================"

# Step 1: Update OS Packages
echo "[1/7] Updating package index..."
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y curl wget git build-essential ufw tar libpq-dev maven

# Step 2: Install OpenJDK
echo "[2/7] Installing OpenJDK 17 (JRE & JDK)..."
sudo apt-get install -y openjdk-17-jdk openjdk-17-jre
java -version

# Step 3: Install & Configure PostgreSQL
echo "[3/7] Installing and setting up PostgreSQL..."
sudo apt-get install -y postgresql postgresql-contrib
sudo systemctl enable postgresql
sudo systemctl start postgresql

echo "Configuring PostgreSQL database user and database..."
sudo -u postgres psql -v ON_ERROR_STOP=1 <<-EOSQL
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${PG_USER}') THEN
            CREATE USER ${PG_USER} WITH ENCRYPTED PASSWORD '${PG_PASSWORD}';
        END IF;
    END
    \$\$;

    SELECT 'CREATE DATABASE ${PG_DATABASE} OWNER ${PG_USER}'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${PG_DATABASE}')\gexec

    GRANT ALL PRIVILEGES ON DATABASE ${PG_DATABASE} TO ${PG_USER};
EOSQL

# Step 4: Create Dedicated Tomcat System User
echo "[4/7] Creating tomcat system user..."
if ! id -u ${TOMCAT_USER} >/dev/null 2>&1; then
    sudo groupadd ${TOMCAT_GROUP}
    sudo useradd -s /bin/false -g ${TOMCAT_GROUP} -d ${INSTALL_DIR} ${TOMCAT_USER}
fi

# Step 5: Download and Install Apache Tomcat
echo "[5/7] Downloading and installing Apache Tomcat ${TOMCAT_VERSION}..."
if [ ! -d "${INSTALL_DIR}" ]; then
    sudo mkdir -p ${INSTALL_DIR}
    wget -q "${TOMCAT_TAR_URL}" -O /tmp/apache-tomcat.tar.gz
    sudo tar -xzf /tmp/apache-tomcat.tar.gz -C ${INSTALL_DIR} --strip-components=1
    rm -f /tmp/apache-tomcat.tar.gz
fi

# Download PostgreSQL JDBC Driver for Tomcat Shared Library
echo "Downloading PostgreSQL JDBC Driver into /opt/tomcat/lib/..."
PG_JDBC_VERSION="42.7.3"
sudo curl -sSL -o "${INSTALL_DIR}/lib/postgresql-${PG_JDBC_VERSION}.jar" \
    "https://repo1.maven.org/maven2/org/postgresql/postgresql/${PG_JDBC_VERSION}/postgresql-${PG_JDBC_VERSION}.jar"

# Set Permissions
echo "Configuring directory permissions..."
sudo chgrp -R ${TOMCAT_GROUP} ${INSTALL_DIR}
sudo chmod -R g+r ${INSTALL_DIR}/conf
sudo chmod g+x ${INSTALL_DIR}/conf
sudo chown -R ${TOMCAT_USER}:${TOMCAT_GROUP} ${INSTALL_DIR}/webapps/ ${INSTALL_DIR}/work/ ${INSTALL_DIR}/temp/ ${INSTALL_DIR}/logs/
sudo chmod -R u+x ${INSTALL_DIR}/bin/*.sh

# Step 6: Configure systemd Service Unit
echo "[6/7] Installing tomcat.service unit..."
sudo tee /etc/systemd/system/tomcat.service > /dev/null <<EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=forking
User=${TOMCAT_USER}
Group=${TOMCAT_GROUP}
Environment="JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64"
Environment="CATALINA_PID=${INSTALL_DIR}/temp/tomcat.pid"
Environment="CATALINA_HOME=${INSTALL_DIR}"
Environment="CATALINA_BASE=${INSTALL_DIR}"
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseG1GC -Djava.awt.headless=true"
Environment="JAVA_OPTS=-Djava.security.egd=file:/dev/./urandom"
ExecStart=${INSTALL_DIR}/bin/startup.sh
ExecStop=${INSTALL_DIR}/bin/shutdown.sh
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable tomcat
sudo systemctl restart tomcat

# Step 7: Configure Firewall
echo "[7/7] Configuring UFW firewall rules..."
sudo ufw allow 22/tcp || true
sudo ufw allow 8080/tcp || true
sudo ufw --force enable || true

echo "========================================================================"
echo " Installation Complete!"
echo " Tomcat URL: http://<SERVER_IP>:8080"
echo " Service Status: sudo systemctl status tomcat"
echo " Tomcat Logs: sudo tail -f /opt/tomcat/logs/catalina.out"
echo "========================================================================"
