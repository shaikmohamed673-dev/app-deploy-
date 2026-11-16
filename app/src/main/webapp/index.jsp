<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.sql.*, com.example.DatabaseConnection, java.lang.management.ManagementFactory" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Java + Tomcat + PostgreSQL Manual Deployment</title>
    <style>
        :root {
            --primary: #2563eb;
            --primary-dark: #1d4ed8;
            --success: #16a34a;
            --danger: #dc2626;
            --warning: #ca8a04;
            --bg: #f8fafc;
            --card-bg: #ffffff;
            --text: #0f172a;
            --text-muted: #64748b;
            --border: #e2e8f0;
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        }

        body {
            background-color: var(--bg);
            color: var(--text);
            line-height: 1.6;
            padding: 2rem 1rem;
        }

        .container {
            max-width: 1000px;
            margin: 0 auto;
        }

        header {
            background: linear-gradient(135deg, #1e293b, #0f172a);
            color: white;
            padding: 2rem;
            border-radius: 12px;
            margin-bottom: 2rem;
            box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1);
        }

        header h1 {
            font-size: 1.8rem;
            display: flex;
            align-items: center;
            gap: 0.75rem;
        }

        header p {
            color: #94a3b8;
            margin-top: 0.5rem;
        }

        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 1.5rem;
            margin-bottom: 2rem;
        }

        .card {
            background: var(--card-bg);
            border: 1px solid var(--border);
            border-radius: 10px;
            padding: 1.5rem;
            box-shadow: 0 1px 3px rgba(0,0,0,0.05);
        }

        .card h2 {
            font-size: 1.2rem;
            margin-bottom: 1rem;
            padding-bottom: 0.5rem;
            border-bottom: 1px solid var(--border);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .badge {
            display: inline-block;
            font-size: 0.75rem;
            font-weight: 600;
            padding: 0.25rem 0.6rem;
            border-radius: 9999px;
            text-transform: uppercase;
        }

        .badge-success { background: #dcfce7; color: var(--success); }
        .badge-danger { background: #fee2e2; color: var(--danger); }
        .badge-info { background: #e0f2fe; color: #0284c7; }

        .stat-list {
            list-style: none;
        }

        .stat-list li {
            display: flex;
            justify-content: space-between;
            padding: 0.4rem 0;
            border-bottom: 1px dashed #f1f5f9;
            font-size: 0.9rem;
        }

        .stat-list li span:first-child {
            color: var(--text-muted);
        }

        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 1rem;
            font-size: 0.875rem;
        }

        th, td {
            padding: 0.65rem 0.75rem;
            text-align: left;
            border-bottom: 1px solid var(--border);
        }

        th {
            background: #f8fafc;
            font-weight: 600;
            color: var(--text-muted);
        }

        .btn {
            background: var(--primary);
            color: white;
            border: none;
            padding: 0.6rem 1.2rem;
            border-radius: 6px;
            font-size: 0.9rem;
            font-weight: 500;
            cursor: pointer;
            text-decoration: none;
            display: inline-block;
            transition: background 0.2s;
        }

        .btn:hover {
            background: var(--primary-dark);
        }

        .form-group {
            margin-bottom: 1rem;
        }

        .form-group label {
            display: block;
            font-size: 0.85rem;
            font-weight: 600;
            margin-bottom: 0.25rem;
            color: var(--text-muted);
        }

        .form-control {
            width: 100%;
            padding: 0.5rem 0.75rem;
            border: 1px solid var(--border);
            border-radius: 6px;
            font-size: 0.9rem;
        }

        .endpoints {
            display: flex;
            gap: 0.5rem;
            margin-top: 1rem;
            flex-wrap: wrap;
        }

        .endpoint-link {
            font-size: 0.8rem;
            background: #f1f5f9;
            padding: 0.35rem 0.75rem;
            border-radius: 6px;
            color: var(--primary);
            text-decoration: none;
            font-family: monospace;
        }

        .endpoint-link:hover {
            background: #e2e8f0;
        }
    </style>
</head>
<body>

<div class="container">
    <header>
        <h1>
            <span>&#9881;</span> Java + Tomcat + PostgreSQL Deployment
        </h1>
        <p>Live verification dashboard running on Ubuntu Linux with Apache Tomcat and PostgreSQL RDBMS.</p>
    </header>

    <div class="grid">
        <!-- Application Server Diagnostics -->
        <div class="card">
            <h2>
                Application Server
                <span class="badge badge-info">Tomcat</span>
            </h2>
            <ul class="stat-list">
                <li><span>Container:</span> <strong><%= application.getServerInfo() %></strong></li>
                <li><span>Java Version:</span> <strong><%= System.getProperty("java.version") %> (<%= System.getProperty("java.vendor") %>)</strong></li>
                <li><span>OS Environment:</span> <strong><%= System.getProperty("os.name") %> (<%= System.getProperty("os.arch") %>)</strong></li>
                <li><span>Server Uptime:</span> <strong><%= ManagementFactory.getRuntimeMXBean().getUptime() / 1000 %>s</strong></li>
                <li><span>Servlet Specification:</span> <strong>Jakarta EE <%= application.getMajorVersion() %>.<%= application.getMinorVersion() %></strong></li>
            </ul>
            <div class="endpoints">
                <a class="endpoint-link" href="health" target="_blank">&#10138; GET /health</a>
                <a class="endpoint-link" href="api/users" target="_blank">&#10138; GET /api/users</a>
            </div>
        </div>

        <!-- PostgreSQL Database Status -->
        <div class="card">
            <%
                boolean dbConnected = false;
                String dbProduct = "Unknown";
                String dbVersion = "";
                String errorMessage = "";
                int userCount = 0;

                try (Connection conn = DatabaseConnection.getConnection()) {
                    dbConnected = true;
                    DatabaseMetaData meta = conn.getMetaData();
                    dbProduct = meta.getDatabaseProductName();
                    dbVersion = meta.getDatabaseProductVersion();

                    try (Statement stmt = conn.createStatement();
                         ResultSet rs = stmt.executeQuery("SELECT COUNT(*) FROM users")) {
                        if (rs.next()) {
                            userCount = rs.getInt(1);
                        }
                    }
                } catch (Exception e) {
                    errorMessage = e.getMessage();
                }
            %>

            <h2>
                PostgreSQL Status
                <% if (dbConnected) { %>
                    <span class="badge badge-success">Connected</span>
                <% } else { %>
                    <span class="badge badge-danger">Disconnected</span>
                <% } %>
            </h2>

            <% if (dbConnected) { %>
                <ul class="stat-list">
                    <li><span>RDBMS Engine:</span> <strong><%= dbProduct %></strong></li>
                    <li><span>Version:</span> <strong style="font-size: 0.8rem;"><%= dbVersion %></strong></li>
                    <li><span>Connection Target:</span> <strong><%= DatabaseConnection.getConnectionInfo() %></strong></li>
                    <li><span>Total User Records:</span> <strong><%= userCount %></strong></li>
                </ul>
            <% } else { %>
                <div style="background: #fef2f2; border: 1px solid #fecaca; color: #b91c1c; padding: 0.75rem; border-radius: 6px; font-size: 0.85rem;">
                    <strong>Connection Failed:</strong><br>
                    <%= errorMessage %>
                </div>
            <% } %>
        </div>
    </div>

    <!-- Live Database Records & Insertion Form -->
    <div class="grid">
        <div class="card" style="grid-column: span 2;">
            <h2>Existing Records (from 'users' table)</h2>
            <% if (dbConnected) { %>
                <table>
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Username</th>
                            <th>Full Name</th>
                            <th>Email</th>
                            <th>Role</th>
                            <th>Active</th>
                            <th>Created At</th>
                        </tr>
                    </thead>
                    <tbody>
                        <%
                            try (Connection conn = DatabaseConnection.getConnection();
                                 Statement stmt = conn.createStatement();
                                 ResultSet rs = stmt.executeQuery("SELECT id, username, full_name, email, role, is_active, created_at FROM users ORDER BY id ASC")) {
                                while (rs.next()) {
                        %>
                        <tr>
                            <td><%= rs.getInt("id") %></td>
                            <td><strong><%= rs.getString("username") %></strong></td>
                            <td><%= rs.getString("full_name") %></td>
                            <td><%= rs.getString("email") %></td>
                            <td><span class="badge badge-info"><%= rs.getString("role") %></span></td>
                            <td><%= rs.getBoolean("is_active") ? "Yes" : "No" %></td>
                            <td><%= rs.getTimestamp("created_at") %></td>
                        </tr>
                        <%
                                }
                            } catch (Exception e) {
                        %>
                        <tr><td colspan="7" style="color: red;">Error reading records: <%= e.getMessage() %></td></tr>
                        <%
                            }
                        %>
                    </tbody>
                </table>
            <% } else { %>
                <p style="color: var(--text-muted); font-size: 0.9rem;">Database connection is offline. Verify PostgreSQL service status and configuration.</p>
            <% } %>
        </div>
    </div>

    <!-- Quick User Creation Form -->
    <% if (dbConnected) { %>
    <div class="card">
        <h2>Insert New Test Record</h2>
        <form method="POST" action="api/users" onsubmit="handleFormSubmit(event)">
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem;">
                <div class="form-group">
                    <label>Username</label>
                    <input class="form-control" name="username" id="inp_username" required placeholder="e.g. devops_hero">
                </div>
                <div class="form-group">
                    <label>Full Name</label>
                    <input class="form-control" name="fullName" id="inp_fullName" required placeholder="e.g. Dev Ops">
                </div>
                <div class="form-group">
                    <label>Email</label>
                    <input class="form-control" type="email" name="email" id="inp_email" required placeholder="e.g. hero@company.com">
                </div>
                <div class="form-group">
                    <label>Role</label>
                    <select class="form-control" name="role" id="inp_role">
                        <option value="USER">USER</option>
                        <option value="DEVELOPER">DEVELOPER</option>
                        <option value="ADMIN">ADMIN</option>
                    </select>
                </div>
            </div>
            <button type="submit" class="btn" style="margin-top: 0.5rem;">+ Create Record via POST</button>
            <span id="formStatus" style="margin-left: 1rem; font-size: 0.9rem;"></span>
        </form>
    </div>
    <% } %>

</div>

<script>
async function handleFormSubmit(e) {
    e.preventDefault();
    const status = document.getElementById('formStatus');
    status.innerText = "Submitting...";
    status.style.color = "#2563eb";

    const params = new URLSearchParams();
    params.append('username', document.getElementById('inp_username').value);
    params.append('fullName', document.getElementById('inp_fullName').value);
    params.append('email', document.getElementById('inp_email').value);
    params.append('role', document.getElementById('inp_role').value);

    try {
        const res = await fetch('api/users', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: params
        });
        const data = await res.json();
        if (res.ok && data.success) {
            status.innerText = "Success! Reloading page...";
            status.style.color = "#16a34a";
            setTimeout(() => window.location.reload(), 1000);
        } else {
            status.innerText = "Error: " + (data.error || 'Failed to save');
            status.style.color = "#dc2626";
        }
    } catch (err) {
        status.innerText = "Network Error: " + err.message;
        status.style.color = "#dc2626";
    }
}
</script>

</body>
</html>
