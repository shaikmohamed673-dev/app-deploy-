# Java + Apache Tomcat + PostgreSQL Manual Ubuntu Deployment Repository

A production-ready repository blueprint demonstrating **manual deployment** of a Java Web Application (WAR) on **Ubuntu Linux** using **Apache Tomcat 10** and **PostgreSQL RDBMS**.

---

## 📁 Repository Structure

```
java-tomcat-postgres-deployment/
├── DEPLOYMENT_GUIDE.md             # Complete step-by-step "HOW" and "WHY" deployment manual
├── README.md                       # Repository overview and quick start
│
├── database/
│   └── schema.sql                  # PostgreSQL schema: users, audit_logs & seed data
│
├── scripts/
│   ├── setup-ubuntu.sh             # All-in-one automated Ubuntu bootstrap script
│   └── tomcat.service              # Systemd unit file template for Tomcat
│
├── config/
│   ├── context.xml                 # Tomcat JNDI DataSource configuration
│   └── server.xml.snippet          # Tomcat Connector and Nginx reverse proxy snippets
│
└── app/                            # Java Web Application (WAR project)
    ├── pom.xml                     # Maven project configuration (Servlet 6.0, PostgreSQL 42.x)
    └── src/
        └── main/
            ├── java/
            │   └── com/example/
            │       ├── DatabaseConnection.java     # Connection manager (JNDI + JDBC fallback)
            │       ├── HealthCheckServlet.java     # /health endpoint (JVM & Server stats)
            │       └── DatabaseTestServlet.java    # /api/users endpoint (Query & Insert)
            └── webapp/
                ├── META-INF/
                │   └── context.xml                 # App-level JNDI DataSource definition
                ├── WEB-INF/
                │   └── web.xml                     # Servlet mappings & resource references
                └── index.jsp                       # Interactive diagnostic dashboard & form
```

---

## ⚡ Quick Start (On Ubuntu Server)

### 1. Automated Setup via Script
If you want to quickly configure an Ubuntu VM with all packages, users, and services:

```bash
chmod +x scripts/setup-ubuntu.sh
sudo ./scripts/setup-ubuntu.sh
```

### 2. Manual Step-by-Step Deployment
For an in-depth walkthrough explaining the **WHY** behind every design choice (systemd, JNDI pooling, security sandbox, non-root users) and the exact **HOW** commands, read:

👉 **[Read the Full Deployment Guide (DEPLOYMENT_GUIDE.md)](DEPLOYMENT_GUIDE.md)**

---

## 📦 Building the Application

Ensure Maven and OpenJDK 17+ are installed:

```bash
cd app
mvn clean package
```

The compiled WAR file will be generated at:
```
app/target/sample-app.war
```

Deploying to Tomcat is as simple as copying the WAR into Tomcat's `webapps` directory:

```bash
sudo cp target/sample-app.war /opt/tomcat/webapps/sample-app.war
sudo chown tomcat:tomcat /opt/tomcat/webapps/sample-app.war
```

Access the application in your browser:
```
http://<YOUR_UBUNTU_IP>:8080/sample-app/
```

---

## 🔌 Application Endpoints

| HTTP Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/sample-app/` | Interactive diagnostic UI dashboard showing system & DB status |
| `GET` | `/sample-app/health` | JSON JVM status, memory usage, OS version & uptime |
| `GET` | `/sample-app/api/users` | JSON array of active users retrieved from PostgreSQL |
| `POST` | `/sample-app/api/users` | Inserts a new user record and writes to `audit_logs` |

---

## 🛡️ Key Architectural Principles
1. **Security Isolation:** Apache Tomcat runs under a dedicated, unprivileged `tomcat` system user without interactive shell access (`/bin/false`).
2. **Resource Management:** PostgreSQL connection pooling is handled through container JNDI resources (`context.xml`), decoupling credentials from source code.
3. **Daemon Supervision:** Handled natively by Ubuntu's `systemd` (`tomcat.service`), offering crash recovery, startup on boot, and logging via `journalctl`.
