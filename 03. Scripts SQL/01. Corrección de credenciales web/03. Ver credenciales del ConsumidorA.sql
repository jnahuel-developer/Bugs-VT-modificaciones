SELECT 
    u.UsuarioID,
    u.Numero,
    u.Nombre,
    u.Apellido,
    anu.Id      AS AspNetUserId,
    anu.Email
FROM Usuario u
LEFT JOIN AspNetUsers anu
       ON anu.UsuarioID = u.UsuarioID
WHERE u.Numero = 501;
