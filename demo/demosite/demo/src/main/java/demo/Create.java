package demo;

import demo.util.Util;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.logging.Level;
import java.util.logging.Logger;

public class Create extends HttpServlet {
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        String user_name = request.getParameter("user_name");
        String user_pass = request.getParameter("user_pass");
        String email = request.getParameter("email");
        Connection conn = null;
        Statement statement = null;
        try {
            Class.forName("com.mysql.jdbc.Driver");
            conn = Util.getMasterConnection(getServletContext());
            statement = conn.createStatement();
            statement.execute(String.format("INSERT INTO users VALUES( null, '%s', '%s', '%s' )", new Object[]{user_name,user_pass,email}));
            conn.commit();
        } catch (Exception e) {
            Logger.getLogger("Create").log(Level.WARNING, e.getMessage(), e);
            e.printStackTrace();
        } finally {
            if (statement != null) {
                try {
                    statement.close();
                } catch (SQLException e) {
                    e.printStackTrace();
                }
            }

            if (conn != null) {
                try {
                    conn.close();
                } catch (SQLException e) {
                    e.printStackTrace();
                }
            }
        }

        response.sendRedirect("select");
    }

    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        doPost(request, response);
    }
}
