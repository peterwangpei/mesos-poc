package demo.util;

import javax.servlet.ServletContext;
import java.io.IOException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.Properties;

public class Util {
    public static Connection getMasterConnection(ServletContext servletContext) throws IOException, SQLException {
        return DriverManager.getConnection(
                getProperty("master_url", servletContext),
                getProperty("master_user", servletContext),
                getProperty("master_password", servletContext));
    }
    public static Connection getSlaveConnection(ServletContext servletContext) throws IOException, SQLException {
        return DriverManager.getConnection(
                getProperty("slave_url", servletContext),
                getProperty("slave_user", servletContext),
                getProperty("slave_password", servletContext));
    }

    private static String getProperty(String key, ServletContext servletContext) throws IOException {
        Properties props = new Properties();
        props.load(servletContext.getResourceAsStream("/WEB-INF/jdbc.properties"));
        return props.getProperty(key);
    }
}
