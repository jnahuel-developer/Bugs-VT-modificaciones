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
WHERE u.Numero = 503;


SELECT Id, Email, UsuarioID
FROM AspNetUsers
WHERE Email = 'consumidor.b@test.com';
