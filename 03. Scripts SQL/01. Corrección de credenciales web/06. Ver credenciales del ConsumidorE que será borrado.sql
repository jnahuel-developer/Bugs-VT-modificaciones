SELECT 
    u.UsuarioID,
    u.Numero,
    u.Nombre,
    u.Apellido,
    anu.Email
FROM Usuario u
LEFT JOIN AspNetUsers anu
       ON anu.UsuarioID = u.UsuarioID
WHERE u.Numero = 505;