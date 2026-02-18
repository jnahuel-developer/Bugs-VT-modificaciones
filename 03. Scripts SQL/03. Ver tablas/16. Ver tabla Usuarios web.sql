USE BugsDev;
GO

SELECT 
    Id           AS AspNetUserId,
    UsuarioID,
    Email,
    UserName
FROM AspNetUsers
ORDER BY Email, UserName;
