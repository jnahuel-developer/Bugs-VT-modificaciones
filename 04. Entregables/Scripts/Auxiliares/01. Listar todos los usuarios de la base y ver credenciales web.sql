USE BugsDev;
GO

SELECT 
    u.UsuarioID,
    u.Numero,
    u.Nombre,
    u.Apellido,
    u.Dni,
    u.Legajo,
    u.LocacionID,
    u.JerarquiaID,
    u.OperadorID,
    anu.Id          AS AspNetUserId,
    anu.Email,
    anu.UserName
FROM Usuario u
LEFT JOIN AspNetUsers anu
       ON anu.UsuarioID = u.UsuarioID
ORDER BY anu.Email, u.Numero;
