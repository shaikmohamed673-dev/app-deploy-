package com.example;

import javax.naming.Context;
import javax.naming.InitialContext;
import javax.naming.NamingException;
import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Utility class to provide PostgreSQL database connections.
 * Supports Tomcat JNDI connection pool (recommended) with fallback to direct JDBC.
 */
public class DatabaseConnection {

    private static final Logger LOGGER = Logger.getLogger(DatabaseConnection.class.getName());
    private static final String JNDI_LOOKUP_NAME = "java:/comp/env/jdbc/postgresDB";

    // Fallback environment or default connection parameters
    private static final String DB_HOST = System.getenv("DB_HOST") != null ? System.getenv("DB_HOST") : "localhost";
    private static final String DB_PORT = System.getenv("DB_PORT") != null ? System.getenv("DB_PORT") : "5432";
    private static final String DB_NAME = System.getenv("DB_NAME") != null ? System.getenv("DB_NAME") : "appdb";
    private static final String DB_USER = System.getenv("DB_USER") != null ? System.getenv("DB_USER") : "appuser";
    private static final String DB_PASS = System.getenv("DB_PASSWORD") != null ? System.getenv("DB_PASSWORD") : "AppSecurePassword123!";

    static {
        try {
            // Explicitly load PostgreSQL Driver
            Class.forName("org.postgresql.Driver");
        } catch (ClassNotFoundException e) {
            LOGGER.log(Level.SEVERE, "PostgreSQL JDBC Driver not found in classpath!", e);
        }
    }

    /**
     * Obtains a connection to the PostgreSQL database.
     * Tries JNDI first, then falls back to direct JDBC connection.
     *
     * @return active java.sql.Connection
     * @throws SQLException if connection fails
     */
    public static Connection getConnection() throws SQLException {
        // 1. Try Tomcat JNDI DataSource
        try {
            Context initCtx = new InitialContext();
            DataSource ds = (DataSource) initCtx.lookup(JNDI_LOOKUP_NAME);
            if (ds != null) {
                return ds.getConnection();
            }
        } catch (NamingException e) {
            LOGGER.log(Level.FINE, "JNDI lookup failed ('" + JNDI_LOOKUP_NAME + "'). Falling back to direct JDBC connection.");
        }

        // 2. Direct JDBC Fallback
        String jdbcUrl = String.format("jdbc:postgresql://%s:%s/%s?sslmode=prefer", DB_HOST, DB_PORT, DB_NAME);
        return DriverManager.getConnection(jdbcUrl, DB_USER, DB_PASS);
    }

    public static String getConnectionInfo() {
        return String.format("Host=%s, Port=%s, Database=%s, User=%s", DB_HOST, DB_PORT, DB_NAME, DB_USER);
    }
}
