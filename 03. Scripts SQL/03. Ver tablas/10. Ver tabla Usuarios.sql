USE BugsDev;
GO

SELECT 
    UsuarioID,
    Numero,
    Nombre,
    Apellido,
    Dni,
    Legajo,
    OperadorID,
    LocacionID,
    JerarquiaID,
    FechaCreacion,
    Inhibido
FROM Usuario
ORDER BY Apellido, Nombre, Numero;
