package demo;

import demo.model.User;
import demo.util.Util;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.sql.*;
import java.util.ArrayList;
import java.util.logging.Level;
import java.util.logging.Logger;

public class Select extends HttpServlet {
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        doGet(request, response);
    }

    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        Connection conn = null;
        Statement statement = null;
        try {
            Class.forName("com.mysql.jdbc.Driver");
            conn = Util.getSlaveConnection(getServletContext());
            statement = conn.createStatement();
            ResultSet rs = statement.executeQuery("SELECT * from users");
            ArrayList<User> users = new ArrayList<User>();
            while(rs.next()) {
                User user = new User();
                user.setId(rs.getInt("user_id"));
                user.setName(rs.getString("user_name"));
                user.setPassword(rs.getString("user_pass"));
                user.setEmail(rs.getString("email"));
                users.add(user);
            }

            rs.close();
            request.setAttribute("users", users);
            request.getRequestDispatcher("index.jsp").forward(request, response);
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
    }
}
