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
