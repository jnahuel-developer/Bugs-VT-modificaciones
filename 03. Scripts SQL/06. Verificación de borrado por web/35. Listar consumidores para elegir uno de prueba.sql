USE BugsDev;
GO

------------------------------------------------------------
-- Script 0: Listado rápido de consumidores
-- Objetivo: elegir un UsuarioID concreto para probar el borrado
------------------------------------------------------------

SELECT TOP 50
       u.UsuarioID,
       u.Numero,
       u.Nombre,
       u.Apellido,
       u.Dni,
       u.Legajo,
       op.Nombre  AS Operador,
       l.Nombre   AS Locacion,
       j.Nombre   AS Jerarquia
FROM Usuario u
LEFT JOIN Operador op ON u.OperadorID = op.OperadorID
LEFT JOIN Locacion  l ON u.LocacionID = l.LocacionID
LEFT JOIN Jerarquia j ON u.JerarquiaID = j.JerarquiaID
ORDER BY op.Nombre, l.Nombre, u.Numero;
