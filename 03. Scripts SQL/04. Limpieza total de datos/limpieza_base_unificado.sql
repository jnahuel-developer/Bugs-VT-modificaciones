/* ============================================================================
   SCRIPT ÚNICO DE LIMPIEZA (SQL Server)
   Objetivo: Dejar la base sólo con el SuperAdmin (Email: jnahuel.developer@gmail.com)
   Fuente: Unificación de 8 archivos proporcionados
   Generado: 2026-01-15 19:26:38
   Nota: Se respetó el orden original de los bloques (22→29) y el contenido tal cual.
============================================================================ */

SET NOCOUNT ON;
GO



/* ===== INICIO: Preparar variables y verificar admin ===== */
USE BugsDev;
GO

PRINT '=== BLOQUE 0: Verificando admin ===';

DECLARE @AdminEmail        NVARCHAR(256) = 'jnahuel.developer@gmail.com';
DECLARE @AdminUserId       NVARCHAR(128);
DECLARE @AdminUsuarioId    UNIQUEIDENTIFIER;

-- Buscar usuario Identity admin
SELECT 
    @AdminUserId    = Id,
    @AdminUsuarioId = UsuarioID
FROM AspNetUsers
WHERE Email = @AdminEmail;

IF @AdminUserId IS NULL
BEGIN
    RAISERROR('No se encontró AspNetUser con Email = %s. Abortando limpieza.', 16, 1, @AdminEmail);
    RETURN;
END

PRINT 'Admin Identity encontrado:';
SELECT @AdminUserId AS AdminUserId, @AdminUsuarioId AS AdminUsuarioId, @AdminEmail AS AdminEmail;

-- Ver el Usuario de dominio asociado
PRINT 'Usuario de dominio asociado al admin:';
SELECT UsuarioID, Numero, Nombre, Apellido, OperadorID, LocacionID, JerarquiaID
FROM Usuario
WHERE UsuarioID = @AdminUsuarioId;
GO
/* ===== FIN: Preparar variables y verificar admin ===== */


/* ===== INICIO: Limpiar Identity (usuarios web) excepto admin ===== */
USE BugsDev;
GO

PRINT '=== BLOQUE 1: Limpiando Identity excepto admin ===';

DECLARE @AdminEmail1        NVARCHAR(256) = 'jnahuel.developer@gmail.com';
DECLARE @AdminUserId1       NVARCHAR(128);

SELECT @AdminUserId1 = Id
FROM AspNetUsers
WHERE Email = @AdminEmail1;

IF @AdminUserId1 IS NULL
BEGIN
    RAISERROR('Admin no encontrado en AspNetUsers en BLOQUE 1. Abortando.', 16, 1);
    RETURN;
END

PRINT '> AdminUserId = ' + @AdminUserId1;

-- 1.1 Eliminar roles de otros usuarios
PRINT '> Eliminando AspNetUserRoles de usuarios NO admin...';
DELETE FROM AspNetUserRoles
WHERE UserId <> @AdminUserId1;

-- 1.2 (Opcional, si existen) logins y claims de otros usuarios
IF OBJECT_ID('dbo.AspNetUserLogins', 'U') IS NOT NULL
BEGIN
    PRINT '> Eliminando AspNetUserLogins de usuarios NO admin...';
    DELETE FROM AspNetUserLogins
    WHERE UserId <> @AdminUserId1;
END

IF OBJECT_ID('dbo.AspNetUserClaims', 'U') IS NOT NULL
BEGIN
    PRINT '> Eliminando AspNetUserClaims de usuarios NO admin...';
    DELETE FROM AspNetUserClaims
    WHERE UserId <> @AdminUserId1;
END

-- 1.3 Eliminar otros usuarios Identity
PRINT '> Eliminando AspNetUsers distintos del admin...';
DELETE FROM AspNetUsers
WHERE Id <> @AdminUserId1;

PRINT '> Estado actual de AspNetUsers:';
SELECT Id, Email, UserName, UsuarioID
FROM AspNetUsers
ORDER BY Email;

PRINT '> Estado actual de AspNetUserRoles:';
SELECT ur.UserId, u.Email, ur.RoleId
FROM AspNetUserRoles ur
LEFT JOIN AspNetUsers u ON u.Id = ur.UserId
ORDER BY u.Email;
GO
/* ===== FIN: Limpiar Identity (usuarios web) excepto admin ===== */


/* ===== INICIO: Quitar dependencias del admin en dominio (null FKs) ===== */
USE BugsDev;
GO

PRINT '=== BLOQUE 2: Limpiando FKs del Usuario admin ===';

DECLARE @AdminEmail2        NVARCHAR(256) = 'jnahuel.developer@gmail.com';
DECLARE @AdminUserId2       NVARCHAR(128);
DECLARE @AdminUsuarioId2    UNIQUEIDENTIFIER;

SELECT 
    @AdminUserId2    = Id,
    @AdminUsuarioId2 = UsuarioID
FROM AspNetUsers
WHERE Email = @AdminEmail2;

IF @AdminUsuarioId2 IS NULL
BEGIN
    RAISERROR('No se encontró UsuarioID para el admin en BLOQUE 2. Abortando.', 16, 1);
    RETURN;
END

PRINT '> Nullificando OperadorID / LocacionID / JerarquiaID del Usuario admin...';

UPDATE Usuario
SET 
    OperadorID  = NULL,
    LocacionID  = NULL,
    JerarquiaID = NULL
WHERE UsuarioID = @AdminUsuarioId2;

PRINT '> Usuario admin luego de la actualización:';
SELECT UsuarioID, Numero, Nombre, Apellido, OperadorID, LocacionID, JerarquiaID
FROM Usuario
WHERE UsuarioID = @AdminUsuarioId2;
GO
/* ===== FIN: Quitar dependencias del admin en dominio (null FKs) ===== */


/* ===== INICIO: Limpiar tablas transaccionales (Transaccion, TransaccionesMal, MP, Stock) ===== */
USE BugsDev;
GO

PRINT '=== BLOQUE 3: Borrando datos transaccionales y de stock ===';

-- 3.1 StockHistorico (depende de Stock y Usuario)
IF OBJECT_ID('dbo.StockHistorico', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando StockHistorico...';
    DELETE FROM StockHistorico;
    SELECT COUNT(*) AS StockHistoricoRestantes FROM StockHistorico;
END
ELSE
    PRINT '> Tabla StockHistorico no encontrada.';

-- 3.2 Stock
IF OBJECT_ID('dbo.Stock', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando Stock...';
    DELETE FROM Stock;
    SELECT COUNT(*) AS StockRestantes FROM Stock;
END
ELSE
    PRINT '> Tabla Stock no encontrada.';

-- 3.3 MercadoPagoTable
IF OBJECT_ID('dbo.MercadoPagoTable', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando MercadoPagoTable...';
    DELETE FROM MercadoPagoTable;
    SELECT COUNT(*) AS MercadoPagoRestantes FROM MercadoPagoTable;
END
ELSE
    PRINT '> Tabla MercadoPagoTable no encontrada.';

-- 3.3b MercadoPagoOperacionMixta
IF OBJECT_ID('dbo.MercadoPagoOperacionMixta', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando MercadoPagoOperacionMixta...';
    DELETE FROM MercadoPagoOperacionMixta;
    SELECT COUNT(*) AS MercadoPagoMixtaRestantes FROM MercadoPagoOperacionMixta;
END
ELSE
    PRINT '> Tabla MercadoPagoTable no encontrada.';

-- 3.4 TransaccionesMal
IF OBJECT_ID('dbo.TransaccionesMal', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando TransaccionesMal...';
    DELETE FROM TransaccionesMal;
    SELECT COUNT(*) AS TransaccionesMalRestantes FROM TransaccionesMal;
END
ELSE
    PRINT '> Tabla TransaccionesMal no encontrada.';

-- 3.5 Transaccion
IF OBJECT_ID('dbo.Transaccion', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando Transaccion...';
    DELETE FROM Transaccion;
    SELECT COUNT(*) AS TransaccionRestantes FROM Transaccion;
END
ELSE
    PRINT '> Tabla Transaccion no encontrada.';

PRINT '=== BLOQUE 3 completado ===';
GO
/* ===== FIN: Limpiar tablas transaccionales (Transaccion, TransaccionesMal, MP, Stock) ===== */


/* ===== INICIO: Borrar usuarios de dominio (Usuario) excepto el del admin ===== */
USE BugsDev;
GO

PRINT '=== BLOQUE 4: Borrando Usuarios de dominio (consumidores) excepto admin ===';

DECLARE @AdminEmail4        NVARCHAR(256) = 'jnahuel.developer@gmail.com';
DECLARE @AdminUsuarioId4    UNIQUEIDENTIFIER;

SELECT @AdminUsuarioId4 = u.UsuarioID
FROM AspNetUsers au
JOIN Usuario u ON u.UsuarioID = au.UsuarioID
WHERE au.Email = @AdminEmail4;

IF @AdminUsuarioId4 IS NULL
BEGIN
    RAISERROR('No se encontró Usuario admin en BLOQUE 4. Abortando.', 16, 1);
    RETURN;
END

PRINT '> AdminUsuarioId = ' + CONVERT(NVARCHAR(36), @AdminUsuarioId4);

PRINT '> Borrando Usuarios distintos del admin...';

DELETE FROM Usuario
WHERE UsuarioID <> @AdminUsuarioId4;

PRINT '> Usuarios restantes:';
SELECT UsuarioID, Numero, Nombre, Apellido
FROM Usuario
ORDER BY Apellido, Nombre;
GO
/* ===== FIN: Borrar usuarios de dominio (Usuario) excepto el del admin ===== */


/* ===== INICIO: Limpieza previa de datos dependientes de Operador ===== */
USE BugsDev;
GO

PRINT '--- Limpieza previa de datos dependientes de Operador ---';

-- 1) Articulos y tablas que puedan depender de ellos
IF OBJECT_ID('dbo.ArticuloAsignacion', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando ArticuloAsignacion...';
    DELETE FROM ArticuloAsignacion;
    SELECT COUNT(*) AS ArticuloAsignacionRestantes FROM ArticuloAsignacion;
END

IF OBJECT_ID('dbo.Articulo', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando Articulo...';
    DELETE FROM Articulo;
    SELECT COUNT(*) AS ArticuloRestantes FROM Articulo;
END

/* ===== FIN: Limpieza previa de datos dependientes de Operador ===== */


/* ===== INICIO: Borrar Jerarquías, Locaciones, Máquinas, Terminales, Operadores ===== */
USE BugsDev;
GO

PRINT '=== BLOQUE 5: Borrando Jerarquías, Locaciones, Máquinas, Terminales, Operadores ===';

-- 5.0 Tablas auxiliares posibles (si existen y referencian estas entidades)
IF OBJECT_ID('dbo.TablasOffline', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando TablasOffline...';
    DELETE FROM TablasOffline;
END

IF OBJECT_ID('dbo.ArticuloAsignacion', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando ArticuloAsignacion...';
    DELETE FROM ArticuloAsignacion;
END

-- 5.1 Jerarquías
IF OBJECT_ID('dbo.Jerarquia', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando Jerarquia...';
    DELETE FROM Jerarquia;
    SELECT COUNT(*) AS JerarquiaRestantes FROM Jerarquia;
END
ELSE
    PRINT '> Tabla Jerarquia no encontrada.';

-- 5.2 Máquinas
IF OBJECT_ID('dbo.Maquina', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando Maquina...';
    DELETE FROM Maquina;
    SELECT COUNT(*) AS MaquinaRestantes FROM Maquina;
END
ELSE
    PRINT '> Tabla Maquina no encontrada.';

-- 5.3 Terminales
IF OBJECT_ID('dbo.Terminal', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando Terminal...';
    DELETE FROM Terminal;
    SELECT COUNT(*) AS TerminalRestantes FROM Terminal;
END
ELSE
    PRINT '> Tabla Terminal no encontrada.';

-- 5.4 Locaciones
IF OBJECT_ID('dbo.Locacion', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando Locacion...';
    DELETE FROM Locacion;
    SELECT COUNT(*) AS LocacionRestantes FROM Locacion;
END
ELSE
    PRINT '> Tabla Locacion no encontrada.';

-- 5.5 Operadores
IF OBJECT_ID('dbo.Operador', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando Operador...';
    DELETE FROM Operador;
    SELECT COUNT(*) AS OperadorRestantes FROM Operador;
END
ELSE
    PRINT '> Tabla Operador no encontrada.';

PRINT '=== BLOQUE 5 completado ===';
GO
/* ===== FIN: Borrar Jerarquías, Locaciones, Máquinas, Terminales, Operadores ===== */


/* ===== INICIO: Chequeo final ===== */
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
/* ===== FIN: Chequeo final ===== */


PRINT '=== Script de limpieza unificado COMPLETADO ===';
GO
