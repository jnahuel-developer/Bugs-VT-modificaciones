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
WHERE u.Numero = 502;


SELECT u.Numero,
       au.Id       AS AspNetUserId,
       au.Email,
       r.Name      AS Rol
FROM Usuario u
JOIN AspNetUsers au ON au.UsuarioID = u.UsuarioID
JOIN AspNetUserRoles aur ON aur.UserId = au.Id
JOIN AspNetRoles r ON r.Id = aur.RoleId
WHERE u.Numero = 502;
