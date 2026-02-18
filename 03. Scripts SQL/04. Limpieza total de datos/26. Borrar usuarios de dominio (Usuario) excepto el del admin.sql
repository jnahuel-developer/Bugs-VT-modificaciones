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
