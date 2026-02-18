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
