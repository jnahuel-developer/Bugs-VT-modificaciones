USE BugsDev;
GO

PRINT '=== BLOQUE 6: Chequeo final de estado ===';

PRINT '> AspNetUsers:';
SELECT Id, Email, UserName, UsuarioID
FROM AspNetUsers
ORDER BY Email;

PRINT '> AspNetUserRoles:';
SELECT ur.UserId, u.Email, ur.RoleId
FROM AspNetUserRoles ur
LEFT JOIN AspNetUsers u ON u.Id = ur.UserId
ORDER BY u.Email;

PRINT '> Usuario (dominio):';
SELECT UsuarioID, Numero, Nombre, Apellido, OperadorID, LocacionID, JerarquiaID
FROM Usuario
ORDER BY Apellido, Nombre;

PRINT '> Conteos de tablas principales:';

SELECT 'Transaccion'       AS Tabla, COUNT(*) AS Registros FROM Transaccion
UNION ALL
SELECT 'TransaccionesMal', COUNT(*) FROM TransaccionesMal
UNION ALL
SELECT 'MercadoPagoTable', COUNT(*) FROM MercadoPagoTable
UNION ALL
SELECT 'StockHistorico',   COUNT(*) FROM StockHistorico
UNION ALL
SELECT 'Stock',            COUNT(*) FROM Stock
UNION ALL
SELECT 'Jerarquia',        COUNT(*) FROM Jerarquia
UNION ALL
SELECT 'Locacion',         COUNT(*) FROM Locacion
UNION ALL
SELECT 'Maquina',          COUNT(*) FROM Maquina
UNION ALL
SELECT 'Terminal',         COUNT(*) FROM Terminal
UNION ALL
SELECT 'Operador',         COUNT(*) FROM Operador;
GO
