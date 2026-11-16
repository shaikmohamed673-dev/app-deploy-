package com.example;

import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.io.PrintWriter;
import java.lang.management.ManagementFactory;
import java.time.Instant;

/**
 * Health check endpoint providing JVM runtime & server environment diagnostics.
 */
@WebServlet(name = "HealthCheckServlet", urlPatterns = {"/health", "/api/health"})
public class HealthCheckServlet extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        resp.setContentType("application/json;charset=UTF-8");
        PrintWriter out = resp.getWriter();

        Runtime runtime = Runtime.getRuntime();
        long maxMemory = runtime.maxMemory() / (1024 * 1024);
        long totalMemory = runtime.totalMemory() / (1024 * 1024);
        long freeMemory = runtime.freeMemory() / (1024 * 1024);
        long usedMemory = totalMemory - freeMemory;
        long uptimeSeconds = ManagementFactory.getRuntimeMXBean().getUptime() / 1000;

        out.println("{");
        out.println("  \"status\": \"UP\",");
        out.println("  \"timestamp\": \"" + Instant.now() + "\",");
        out.println("  \"serverInfo\": \"" + escape(getServletContext().getServerInfo()) + "\",");
        out.println("  \"javaVersion\": \"" + escape(System.getProperty("java.version")) + "\",");
        out.println("  \"javaVendor\": \"" + escape(System.getProperty("java.vendor")) + "\",");
        out.println("  \"os\": \"" + escape(System.getProperty("os.name") + " " + System.getProperty("os.version")) + "\",");
        out.println("  \"uptimeSeconds\": " + uptimeSeconds + ",");
        out.println("  \"memoryMb\": {");
        out.println("    \"used\": " + usedMemory + ",");
        out.println("    \"free\": " + freeMemory + ",");
        out.println("    \"total\": " + totalMemory + ",");
        out.println("    \"max\": " + maxMemory);
        out.println("  }");
        out.println("}");
    }

    private String escape(String s) {
        if (s == null) return "";
        return s.replace("\"", "\\\"");
    }
}
