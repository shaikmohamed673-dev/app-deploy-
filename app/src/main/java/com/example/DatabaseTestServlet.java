package com.example;

import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.io.PrintWriter;
import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

/**
 * Servlet to test PostgreSQL connection, retrieve users, and insert records.
 */
@WebServlet(name = "DatabaseTestServlet", urlPatterns = {"/api/db-test", "/api/users"})
public class DatabaseTestServlet extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        resp.setContentType("application/json;charset=UTF-8");
        PrintWriter out = resp.getWriter();

        try (Connection conn = DatabaseConnection.getConnection()) {
            DatabaseMetaData metaData = conn.getMetaData();
            String dbProduct = metaData.getDatabaseProductName();
            String dbVersion = metaData.getDatabaseProductVersion();

            // Query sample users
            StringBuilder usersJson = new StringBuilder();
            int count = 0;

            String query = "SELECT id, username, full_name, email, role, is_active, created_at FROM users ORDER BY id ASC";
            try (Statement stmt = conn.createStatement();
                 ResultSet rs = stmt.executeQuery(query)) {

                while (rs.next()) {
                    if (count > 0) usersJson.append(",");
                    usersJson.append(String.format(
                        "{\"id\": %d, \"username\": \"%s\", \"fullName\": \"%s\", \"email\": \"%s\", \"role\": \"%s\", \"isActive\": %b, \"createdAt\": \"%s\"}",
                        rs.getInt("id"),
                        escape(rs.getString("username")),
                        escape(rs.getString("full_name")),
                        escape(rs.getString("email")),
                        escape(rs.getString("role")),
                        rs.getBoolean("is_active"),
                        rs.getTimestamp("created_at")
                    ));
                    count++;
                }
            }

            resp.setStatus(HttpServletResponse.SC_OK);
            out.println("{");
            out.println("  \"databaseConnected\": true,");
            out.println("  \"product\": \"" + escape(dbProduct) + "\",");
            out.println("  \"version\": \"" + escape(dbVersion) + "\",");
            out.println("  \"totalUsers\": " + count + ",");
            out.println("  \"users\": [" + usersJson + "]");
            out.println("}");

        } catch (SQLException e) {
            resp.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
            out.println("{");
            out.println("  \"databaseConnected\": false,");
            out.println("  \"error\": \"" + escape(e.getMessage()) + "\",");
            out.println("  \"sqlState\": \"" + escape(e.getSQLState()) + "\",");
            out.println("  \"targetConfig\": \"" + escape(DatabaseConnection.getConnectionInfo()) + "\"");
            out.println("}");
        }
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        resp.setContentType("application/json;charset=UTF-8");
        PrintWriter out = resp.getWriter();

        String username = req.getParameter("username");
        String fullName = req.getParameter("fullName");
        String email = req.getParameter("email");
        String role = req.getParameter("role") != null ? req.getParameter("role") : "USER";

        if (username == null || username.trim().isEmpty() ||
            fullName == null || fullName.trim().isEmpty() ||
            email == null || email.trim().isEmpty()) {
            resp.setStatus(HttpServletResponse.SC_BAD_REQUEST);
            out.println("{\"error\": \"Missing required parameters: username, fullName, email\"}");
            return;
        }

        try (Connection conn = DatabaseConnection.getConnection()) {
            conn.setAutoCommit(false);

            String insertSql = "INSERT INTO users (username, full_name, email, role) VALUES (?, ?, ?, ?) RETURNING id";
            int newId = -1;
            try (PreparedStatement pstmt = conn.prepareStatement(insertSql)) {
                pstmt.setString(1, username.trim());
                pstmt.setString(2, fullName.trim());
                pstmt.setString(3, email.trim());
                pstmt.setString(4, role.trim().toUpperCase());
                try (ResultSet rs = pstmt.executeQuery()) {
                    if (rs.next()) {
                        newId = rs.getInt(1);
                    }
                }
            }

            // Record audit log
            String logSql = "INSERT INTO audit_logs (action, actor, details) VALUES (?, ?, ?)";
            try (PreparedStatement pstmtLog = conn.prepareStatement(logSql)) {
                pstmtLog.setString(1, "USER_CREATED");
                pstmtLog.setString(2, "WEB_UI");
                pstmtLog.setString(3, "Created user ID " + newId + " (" + username + ")");
                pstmtLog.executeUpdate();
            }

            conn.commit();
            resp.setStatus(HttpServletResponse.SC_CREATED);
            out.println(String.format("{\"success\": true, \"newUserId\": %d, \"message\": \"User created successfully\"}", newId));

        } catch (SQLException e) {
            resp.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
            out.println(String.format("{\"success\": false, \"error\": \"%s\"}", escape(e.getMessage())));
        }
    }

    private String escape(String s) {
        if (s == null) return "";
        return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", " ");
    }
}
