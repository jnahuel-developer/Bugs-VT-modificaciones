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
