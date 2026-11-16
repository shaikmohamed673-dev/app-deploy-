# End-to-End Manual Deployment Guide: Java + Apache Tomcat + PostgreSQL on Ubuntu

This guide provides a comprehensive, production-grade walkthrough for manually deploying a Java web application on **Ubuntu Linux (20.04 / 22.04 / 24.04 LTS)** using **Apache Tomcat 10** and **PostgreSQL**.

---

## Table of Contents
1. [Architectural Overview](#1-architectural-overview)
2. [The "WHY": Design Decisions & Rationale](#2-the-why-design-decisions--rationale)
3. [Prerequisites & Server Requirements](#3-prerequisites--server-requirements)
4. [Step-by-Step "HOW": Step 1 - Ubuntu Server Hardening & Packages](#4-step-1---ubuntu-server-hardening--packages)
5. [Step 2 - PostgreSQL Installation & Database Setup](#5-step-2---postgresql-installation--database-setup)
6. [Step 3 - Java OpenJDK Installation](#6-step-3---java-openjdk-installation)
7. [Step 4 - Apache Tomcat Manual Installation](#7-step-4---apache-tomcat-manual-installation)
8. [Step 5 - PostgreSQL JDBC Driver Setup in Tomcat](#8-step-5---postgresql-jdbc-driver-setup-in-tomcat)
9. [Step 6 - Configure Tomcat as a systemd Service](#9-step-6---configure-tomcat-as-a-systemd-service)
10. [Step 7 - Building the Java WAR Application](#10-step-7---building-the-java-war-application)
11. [Step 8 - Deploying the Application WAR File](#11-step-8---deploying-the-application-war-file)
12. [Step 9 - Testing, Verification & Diagnostics](#12-step-9---testing-verification--diagnostics)
13. [Step 10 - Troubleshooting Common Pitfalls](#13-step-10---troubleshooting-common-pitfalls)
14. [Step 11 - Production Hardening & Reverse Proxy (Nginx + SSL)](#14-step-11---production-hardening--reverse-proxy-nginx--ssl)

---

## 1. Architectural Overview

```
                      +---------------------------------------+
                      |       Client (Browser / API)          |
                      +---------------------------------------+
                                          |
                                          | HTTP / HTTPS (Port 80/443 or 8080)
                                          v
+-------------------------------------------------------------------------------+
| Ubuntu Linux Host                                                             |
|                                                                               |
|   +-----------------------------------------------------------------------+   |
|   | Apache Tomcat 10 (Servlet / JSP Container)                            |   |
|   | Runs as non-root service user: 'tomcat'                               |   |
|   | Port: 8080                                                            |   |
|   |                                                                       |   |
|   |   +---------------------------------------------------------------+   |   |
|   |   | sample-app.war (/opt/tomcat/webapps/sample-app)               |   |   |
|   |   |                                                               |   |   |
|   |   |   [Servlets / JSP] <---> [JNDI DataSource Pool (Hikari/Tomcat)]|   |   |
|   |   +---------------------------------------------------------------+   |   |
|   |                                     |                                 |   |
|   |                                     | PostgreSQL JDBC Driver (42.x)   |   |
|   +-------------------------------------|---------------------------------+   |
|                                         |                                     |
|                                         | TCP / UNIX Socket (Port 5432)       |
|                                         v                                     |
|   +-----------------------------------------------------------------------+   |
|   | PostgreSQL Database Server                                            |   |
|   | Database: appdb                                                       |   |
|   | User: appuser                                                         |   |
|   | Tables: users, audit_logs                                             |   |
|   +-----------------------------------------------------------------------+   |
+-------------------------------------------------------------------------------+
```

---

## 2. The "WHY": Design Decisions & Rationale

Before executing commands, it is crucial to understand **why** each tool and technique is chosen:

### Why Manual Deployment?
* **Deep Infrastructure Transparency:** Container abstractions (Docker/K8s) hide networking, permissions, environment paths, and system-level dependencies. Manual deployment demystifies how Linux, JVM, systemd, and application containers interact.
* **Legacy & Enterprise Reality:** Thousands of mission-critical enterprise systems run directly on bare metal or virtual machines (AWS EC2, GCP Compute Engine, Azure VMs) without Docker.
* **Resource Optimization:** Eliminates container runtime overhead, direct kernel namespaces, and image storage bloat on small VMs (e.g., 1 GB RAM VPS).
* **Troubleshooting Mastery:** When a containerized app fails with memory leaks, file permission bugs, or connection exhaustion, engineers with manual deployment experience diagnose the root cause faster.

### Why Ubuntu Linux?
* **Long Term Support (LTS):** 5 years of standard security patches and enterprise stability.
* **Predictable Tooling:** Canonical package repositories, reliable `systemd` process supervisor, and clear filesystem hierarchy (`/opt`, `/etc/systemd/system`, `/var/log`).

### Why Apache Tomcat?
* **Lightweight Servlet Container:** Rather than heavy, monolithic enterprise application servers (like WebLogic or JBoss/WildFly), Apache Tomcat strictly implements Jakarta Servlet, Jakarta Server Pages (JSP), and WebSocket specifications.
* **Battle-Tested:** Deployed in millions of production environments over 25+ years with proven performance.

### Why PostgreSQL?
* **ACID Guarantees:** Multi-Version Concurrency Control (MVCC), strict relational consistency, foreign keys, and transactions.
* **Extensibility & Security:** Native support for connection role separation, SCRAM-SHA-256 encryption, and rich telemetry.

### Why JNDI Connection Pooling?
* **Connection Reuse:** Opening a TCP connection and negotiating SSL + authentication with PostgreSQL is computationally expensive. Connection pooling maintains a warm pool of reusable connections.
* **Separation of Concerns:** Database credentials and connection limits reside in the server configuration (`context.xml`), allowing developers to deploy the WAR across Development, Staging, and Production environments without modifying Java source code.

### Why a Dedicated `tomcat` System User & `systemd`?
* **Principle of Least Privilege:** Running Tomcat as `root` is a severe security vulnerability. If a remote code execution exploit occurs within an application, the attacker gets full control of the operating system. Running as `tomcat` restricts the attacker to the container directory.
* **Process Supervison via `systemd`:** Automatically restarts Tomcat on unexpected crashes or machine reboots, manages standard output (`catalina.out`), and integrates with Ubuntu's `journalctl`.

---

## 3. Prerequisites & Server Requirements

* **Operating System:** Ubuntu 20.04, 22.04, or 24.04 LTS (64-bit x86_64 or ARM64).
* **Hardware Sizing:** Minimum 1 vCPU, 1 GB RAM (2 GB RAM recommended).
* **User Privileges:** Standard user with `sudo` privileges.

---

## 4. Step 1 - Ubuntu Server Hardening & Packages

Connect to your Ubuntu server via SSH:

```bash
ssh username@your-server-ip
```

Update system packages and install required command-line utilities:

```bash
# Update package index and upgrade existing packages
sudo apt-get update -y && sudo apt-get upgrade -y

# Install essential tools
sudo apt-get install -y curl wget git tar ufw build-essential libpq-dev
```

### Configure the Firewall (UFW)
Ensure you do not lock yourself out of SSH before enabling the firewall:

```bash
# Allow SSH connections
sudo ufw allow 22/tcp

# Allow Tomcat default HTTP port
sudo ufw allow 8080/tcp

# (Optional) Allow HTTP/HTTPS if using Nginx later
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable Firewall
sudo ufw --force enable
sudo ufw status verbose
```

---

## 5. Step 2 - PostgreSQL Installation & Database Setup

### 2.1 Install PostgreSQL
Ubuntu repositories include stable PostgreSQL releases:

```bash
sudo apt-get install -y postgresql postgresql-contrib
```

Verify that the PostgreSQL service is active and set to start on boot:

```bash
sudo systemctl enable postgresql
sudo systemctl status postgresql --no-pager
```

### 2.2 Create Database User and Database
Switch to the built-in `postgres` superuser account and start the `psql` interactive shell:

```bash
sudo -i -u postgres psql
```

Execute the following SQL statements:

```sql
-- 1. Create a dedicated application user with an encrypted password
CREATE USER appuser WITH ENCRYPTED PASSWORD 'AppSecurePassword123!';

-- 2. Create the application database owned by appuser
CREATE DATABASE appdb OWNER appuser;

-- 3. Grant full privileges
GRANT ALL PRIVILEGES ON DATABASE appdb TO appuser;

-- 4. In PostgreSQL 15+, grant schema usage permissions
\connect appdb
GRANT ALL ON SCHEMA public TO appuser;

-- Exit psql
\q
```

### 2.3 Populate Schema and Initial Seed Data
Run the application schema script:

```bash
# Download or copy database/schema.sql to your server, then execute:
sudo -u postgres psql -d appdb -f database/schema.sql
```

Alternatively, run the queries inline:

```bash
sudo -u postgres psql -d appdb -c "
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    role VARCHAR(30) DEFAULT 'USER',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id SERIAL PRIMARY KEY,
    action VARCHAR(100) NOT NULL,
    actor VARCHAR(50) DEFAULT 'SYSTEM',
    details TEXT,
    logged_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users (username, full_name, email, role) VALUES
('jdoe', 'John Doe', 'john.doe@example.com', 'ADMIN'),
('asmith', 'Alice Smith', 'alice.smith@example.com', 'DEVELOPER'),
('bwayne', 'Bruce Wayne', 'bruce.wayne@example.com', 'USER')
ON CONFLICT (username) DO NOTHING;
"
```

Verify data retrieval:

```bash
PGPASSWORD='AppSecurePassword123!' psql -h localhost -U appuser -d appdb -c "SELECT id, username, email, role FROM users;"
```

---

## 6. Step 3 - Java OpenJDK Installation

Apache Tomcat 10.1+ requires **Java 11 or higher** (Java 17 LTS or Java 21 LTS is recommended).

### 3.1 Install OpenJDK 17

```bash
sudo apt-get install -y openjdk-17-jdk openjdk-17-jre
```

### 3.2 Verify Java Installation

```bash
java -version
javac -version
```

Output should resemble:
```
openjdk version "17.0.x" 202x-xx-xx
OpenJDK Runtime Environment (build 17.0.x+...)
OpenJDK 64-Bit Server VM (build 17.0.x+..., mixed mode, sharing)
```

Find the exact `JAVA_HOME` path:
```bash
sudo update-alternatives --list java
# Expected: /usr/lib/jvm/java-17-openjdk-amd64/bin/java
# Therefore, JAVA_HOME is: /usr/lib/jvm/java-17-openjdk-amd64
```

Export `JAVA_HOME` to system environment:
```bash
echo "JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64" | sudo tee -a /etc/environment
source /etc/environment
```

---

## 7. Step 4 - Apache Tomcat Manual Installation

### 4.1 Create Non-Root System User and Group
For security, Tomcat should run under a dedicated system user without login shell access:

```bash
sudo groupadd tomcat
sudo useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat
```

### 4.2 Download and Extract Apache Tomcat 10
Download the official Apache Tomcat 10 binary distribution:

```bash
cd /tmp
TOMCAT_VERSION="10.1.34"

wget "https://archive.apache.org/dist/tomcat/tomcat-10/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"

# Create target directory
sudo mkdir -p /opt/tomcat

# Extract archive stripping the top-level folder
sudo tar -xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz -C /opt/tomcat --strip-components=1

# Clean up archive
rm -f apache-tomcat-${TOMCAT_VERSION}.tar.gz
```

### 4.3 Configure Filesystem Permissions
Apply strict file permissions:

```bash
cd /opt/tomcat

# Assign group ownership
sudo chgrp -R tomcat /opt/tomcat

# Restrict configuration access
sudo chmod -R g+r conf
sudo chmod g+x conf

# Grant tomcat user ownership of runtime and deploy directories
sudo chown -R tomcat webapps/ work/ temp/ logs/

# Ensure shell scripts in bin/ are executable
sudo chmod -R u+x bin/*.sh
```

---

## 8. Step 5 - PostgreSQL JDBC Driver Setup in Tomcat

For Tomcat to provide a JNDI DataSource connection pool across applications, the **PostgreSQL JDBC Driver JAR** must be present in Tomcat's common classpath (`/opt/tomcat/lib/`).

```bash
PG_DRIVER_VERSION="42.7.3"
sudo curl -sSL -o /opt/tomcat/lib/postgresql-${PG_DRIVER_VERSION}.jar \
  "https://repo1.maven.org/maven2/org/postgresql/postgresql/${PG_DRIVER_VERSION}/postgresql-${PG_DRIVER_VERSION}.jar"

# Verify driver file exists and is readable
ls -la /opt/tomcat/lib/postgresql-*.jar
```

---

## 9. Step 6 - Configure Tomcat as a systemd Service

Creating a systemd service allows Ubuntu to supervise Tomcat, start it on boot, and manage logs through standard Linux interfaces.

### 9.1 Create `/etc/systemd/system/tomcat.service`

Create the service file:

```bash
sudo nano /etc/systemd/system/tomcat.service
```

Paste the following configuration:

```ini
[Unit]
Description=Apache Tomcat 10 Web Application Container
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=forking

# Run as non-privileged system user
User=tomcat
Group=tomcat

# Environment variables
Environment="JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64"
Environment="CATALINA_PID=/opt/tomcat/temp/tomcat.pid"
Environment="CATALINA_HOME=/opt/tomcat"
Environment="CATALINA_BASE=/opt/tomcat"
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseG1GC -Djava.awt.headless=true"
Environment="JAVA_OPTS=-Djava.security.egd=file:/dev/./urandom"

# Startup and Shutdown commands
ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

# Restart policy on crash
RestartSec=10
Restart=always

# Security sandbox flags
UMask=0027
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

### 9.2 Enable and Start Tomcat Service

```bash
# Reload systemd daemon to recognize new unit file
sudo systemctl daemon-reload

# Enable service at system startup
sudo systemctl enable tomcat

# Start Tomcat
sudo systemctl start tomcat

# Check service status
sudo systemctl status tomcat --no-pager
```

Verify that Tomcat is listening on port 8080:

```bash
sudo ss -tulpn | grep 8080
```

---

## 10. Step 7 - Building the Java WAR Application

You can build the project either on your development machine or directly on the Ubuntu server.

### Option A: Building directly on Ubuntu
Install Apache Maven:

```bash
sudo apt-get install -y maven
```

Navigate to the `app/` directory and compile:

```bash
cd /path/to/java-tomcat-postgres-deployment/app
mvn clean package
```

Upon success, Maven creates the WAR artifact:
```
target/sample-app.war
```

### Option B: Building on Local Machine & Copying via SCP
On your local machine:
```bash
cd app
mvn clean package
scp target/sample-app.war username@your-server-ip:/tmp/sample-app.war
```

---

## 11. Step 8 - Deploying the Application WAR File

Manual WAR deployment in Apache Tomcat is done by copying the `.war` file into `/opt/tomcat/webapps/`.

```bash
# Copy WAR artifact into Tomcat's webapps directory
sudo cp /tmp/sample-app.war /opt/tomcat/webapps/sample-app.war

# Ensure correct ownership
sudo chown tomcat:tomcat /opt/tomcat/webapps/sample-app.war
```

### How Tomcat Auto-Deployment Works:
1. Tomcat's background deployment scanner detects the newly placed `sample-app.war`.
2. Tomcat unpacks it into a directory named `/opt/tomcat/webapps/sample-app/`.
3. Servlets and listeners are registered dynamically.

Monitor the deployment in real time:

```bash
sudo tail -f /opt/tomcat/logs/catalina.out
```

Expected output:
```
Deployment of web application archive [/opt/tomcat/webapps/sample-app.war] has finished in [x,xxx] ms
```

---

## 12. Step 9 - Testing, Verification & Diagnostics

### 12.1 Web Browser Access
Open your web browser and navigate to:
```
http://<YOUR_SERVER_IP>:8080/sample-app/
```
You will see the interactive dashboard with:
* **Tomcat & JVM Diagnostics** (Uptime, Memory, Servlet API version).
* **Live PostgreSQL Status** (Product version, Connected status).
* **Sample User Records** retrieved directly from the `users` table.
* **Interactive Form** to submit new users directly to the database.

### 12.2 Command-Line Verification (cURL)

**1. Test Application Health Endpoint:**
```bash
curl -s http://localhost:8080/sample-app/health | jq .
```
Response:
```json
{
  "status": "UP",
  "serverInfo": "Apache Tomcat/10.1.34",
  "javaVersion": "17.0.12",
  "uptimeSeconds": 142,
  "memoryMb": {
    "used": 45,
    "free": 180,
    "total": 225,
    "max": 1024
  }
}
```

**2. Test Database User Fetch Endpoint:**
```bash
curl -s http://localhost:8080/sample-app/api/users | jq .
```
Response:
```json
{
  "databaseConnected": true,
  "product": "PostgreSQL",
  "version": "16.x ...",
  "totalUsers": 3,
  "users": [
    {"id": 1, "username": "jdoe", "role": "ADMIN"},
    ...
  ]
}
```

**3. Test Creating a User Record via POST:**
```bash
curl -X POST http://localhost:8080/sample-app/api/users \
     -d "username=devops_guru" \
     -d "fullName=DevOps Guru" \
     -d "email=guru@cloud.io" \
     -d "role=ADMIN"
```
Response:
```json
{
  "success": true,
  "newUserId": 4,
  "message": "User created successfully"
}
```

---

## 13. Step 10 - Troubleshooting Common Pitfalls

| Symptom | Root Cause | Resolution |
| :--- | :--- | :--- |
| `java.lang.ClassNotFoundException: org.postgresql.Driver` | PostgreSQL JDBC driver is missing from the classpath. | Copy `postgresql-42.x.jar` into `/opt/tomcat/lib/` or verify it is packaged in `WEB-INF/lib/`. |
| `org.postgresql.util.PSQLException: Connection refused` | PostgreSQL service is down or not listening on port 5432. | Check `sudo systemctl status postgresql` and verify `listen_addresses = 'localhost'` in `/etc/postgresql/<version>/main/postgresql.conf`. |
| `FATAL: password authentication failed for user "appuser"` | Password mismatch or `pg_hba.conf` restriction. | Reset password via `ALTER USER appuser WITH PASSWORD '...';` in `psql`. Verify `md5` or `scram-sha-256` in `pg_hba.conf`. |
| `java.lang.NoClassDefFoundError: javax/servlet/...` | App was compiled with legacy `javax.servlet` instead of `jakarta.servlet` for Tomcat 10+. | Upgrade imports to `jakarta.servlet.*` or run Apache Tomcat 9 instead. |
| `Permission denied` when Tomcat starts or writes logs | Files in `/opt/tomcat/` owned by `root`. | Run `sudo chown -R tomcat:tomcat /opt/tomcat/{logs,temp,work,webapps}`. |
| Tomcat fails to start with `Address already in use: 8080` | Another process is occupying port 8080. | Run `sudo lsof -i :8080` or `sudo ss -tulpn \| grep 8080` and stop conflicting process. |

---

## 14. Step 11 - Production Hardening & Reverse Proxy (Nginx + SSL)

In production environments, never expose Tomcat port 8080 directly to the internet. Instead, place **Nginx** in front as a reverse proxy to handle SSL/TLS termination, request throttling, and port 80/443 mapping.

### 14.1 Install Nginx

```bash
sudo apt-get install -y nginx
```

### 14.2 Create Nginx Configuration
Create `/etc/nginx/sites-available/sample-app`:

```nginx
server {
    listen 80;
    server_name yourdomain.com; # Replace with your domain or server IP

    location / {
        proxy_pass http://127.0.0.1:8080/sample-app/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable site and restart Nginx:

```bash
sudo ln -s /etc/nginx/sites-available/sample-app /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### 14.3 Secure with Free SSL Certificate (Certbot)

```bash
sudo apt-get install -y certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com
```

Certbot automatically configures HTTPS redirect, TLS certificates, and cron renewal.
