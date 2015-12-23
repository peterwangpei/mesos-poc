<%--
  Created by IntelliJ IDEA.
  User: ezeng
  Date: 12/22/15
  Time: 5:08 PM
  To change this template use File | Settings | File Templates.
--%>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<html>
<head>
    <title>Create User</title>
    <style type="text/css">
        body, input, textarea, keygen, select, button {
            font-size: 16px;
            line-height: 24px;
            margin: 6px;
            padding: 6px;;
        }

        tr {
            line-height: 24px;
        }
    </style>
</head>
<body>
<form target="_self" action="create" method="post">
    <table>
        <tr>
            <th colspan="2">Create User</th>
        </tr>
        <tr>
            <td>
                <label for="user_name">user name:</label>
            </td>
            <td><input id="user_name" name="user_name"/></td>
        </tr>
        <tr>
            <td><label for="user_pass">password:</label></td>
            <td><input id="user_pass" name="user_pass"/></td>
        </tr>
        <tr>
            <td><label for="email">email:</label></td>
            <td><input id="email" name="email"/></td>
        </tr>
        <tr>
            <td></td>
            <td>
                <input type="submit" value="create"/>
            </td>
        </tr>
    </table>
</form>
</body>
</html>
