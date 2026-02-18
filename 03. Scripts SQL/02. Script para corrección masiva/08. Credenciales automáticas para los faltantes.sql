USE BugsDev;
GO

/* ============================================================
   SCRIPT: Crear credenciales web para consumidores de una locación
   ============================================================

   ¿Qué hace?
   ----------
   Para la locación indicada en @LocacionID, crea usuarios web
   (AspNetUsers) para todos los consumidores (Usuario) que NO
   tengan credenciales asociadas aún, y les asigna el rol "Consumidor".

   Cómo usarlo (resumen):
   ----------------------
   1) Buscar el LocacionID que querés usar:
        SELECT LocacionID, Nombre, Numero FROM Locacion ORDER BY Nombre;

   2) Obtener el PasswordHash de la contraseña por defecto (ej. 123456):
        -- Elegir un usuario web que tenga esa contraseña
        SELECT PasswordHash
        FROM AspNetUsers
        WHERE Email = 'email_del_usuario_que_tiene_esa_contraseña';

      Copiás el valor completo devuelto (es una cadena larga) y lo
      pegás en @DefaultPasswordHash.

   3) Configurar:
        - @LocacionID          -> GUID de la locación destino
        - @EmailDomain         -> dominio para los emails generados
        - @DefaultPasswordHash -> HASH de la contraseña por defecto
        - @SoloPrevisualizar   -> 1 = solo ver, 0 = crear usuarios

   4) Ejecutar el script.

   Formato de email generado:
   --------------------------
   consumidor<Numero>@<dominio>

   Ejemplo:
   - Numero = 123
   - @EmailDomain = '@locacion.com'

   Email: consumidor123@locacion.com

   ============================================================ */

-----------------------------
-- 1) CONFIGURACIÓN
-----------------------------
DECLARE @LocacionID UNIQUEIDENTIFIER = '33333333-3333-3333-3333-333333333333'; 
-- TODO: Reemplazar por el LocacionID real, por ejemplo:
-- DECLARE @LocacionID UNIQUEIDENTIFIER = '82680110-4F59-4CFD-A826-39B4800E19B1';

DECLARE @EmailDomain NVARCHAR(100) = '@locacion.com'; 
-- TODO: Cambiar por el dominio deseado (dejar la '@').

DECLARE @DefaultPasswordHash NVARCHAR(MAX) = 'AFe7ZzniG8g/tZuG7jF+0JTqll4otxupK7p38wh1Y28RMDzWd6AkTzbvCabk1Y2FBw==';
-- EJEMPLO (NO USAR TAL CUAL): 'AQAAAAEAACcQAAAAE...'
-- Debés pegar aquí el PasswordHash obtenido de AspNetUsers para la
-- contraseña que quieras usar (ej. 123456).

DECLARE @SoloPrevisualizar BIT = 1;
-- 1 = sólo muestra qué se haría, sin insertar nada
-- 0 = crea usuarios y roles realmente

DECLARE @RoleName NVARCHAR(256) = 'Consumidor';


-----------------------------
-- 2) VALIDACIONES BÁSICAS
-----------------------------
IF @LocacionID = '00000000-0000-0000-0000-000000000000'
BEGIN
    RAISERROR('Configurá @LocacionID con el GUID de la locación antes de ejecutar el script.', 16, 1);
    RETURN;
END

IF @DefaultPasswordHash IS NULL OR @DefaultPasswordHash = 'PEGAR_AQUI_EL_HASH_DE_LA_CONTRASEÑA_POR_DEFECTO'
BEGIN
    RAISERROR('Configurá @DefaultPasswordHash con el hash de la contraseña por defecto antes de ejecutar el script.', 16, 1);
    RETURN;
END

DECLARE @RoleId NVARCHAR(128);

SELECT @RoleId = Id
FROM AspNetRoles
WHERE Name = @RoleName;

IF @RoleId IS NULL
BEGIN
    RAISERROR('No se encontró el rol "%s" en AspNetRoles. Crealo o ajustá @RoleName.', 16, 1, @RoleName);
    RETURN;
END

IF NOT EXISTS (SELECT 1 FROM Locacion WHERE LocacionID = @LocacionID)
BEGIN
    DECLARE @msg NVARCHAR(200);
    SET @msg = N'No se encontró ninguna locación con LocacionID = ' 
               + CONVERT(NVARCHAR(36), @LocacionID) + N'.';

    RAISERROR(@msg, 16, 1);
    RETURN;
END



-----------------------------
-- 3) CONSUMIDORES OBJETIVO
-----------------------------
;WITH UsuariosObjetivo AS (
    SELECT 
        u.UsuarioID,
        u.Numero,
        u.Apellido,
        u.Nombre
    FROM Usuario u
    WHERE u.LocacionID = @LocacionID
      AND NOT EXISTS (
            SELECT 1 
            FROM AspNetUsers au 
            WHERE au.UsuarioID = u.UsuarioID
        )
)
SELECT 
    u.UsuarioID,
    u.Numero,
    u.Apellido,
    u.Nombre,
    LOWER('consumidor' + CAST(u.Numero AS NVARCHAR(10)) + @EmailDomain) AS EmailSugerido
INTO #UsuariosObjetivo
FROM UsuariosObjetivo u;

IF NOT EXISTS (SELECT 1 FROM #UsuariosObjetivo)
BEGIN
    PRINT 'No hay consumidores en esta locación sin credenciales web. Nada para hacer.';
    DROP TABLE #UsuariosObjetivo;
    RETURN;
END

PRINT 'PREVISUALIZACIÓN DE USUARIOS QUE RECIBIRÁN CREDENCIALES:';
SELECT * FROM #UsuariosObjetivo;


IF @SoloPrevisualizar = 1
BEGIN
    PRINT 'Modo previsualización activado (@SoloPrevisualizar = 1). No se harán inserciones.';
    DROP TABLE #UsuariosObjetivo;
    RETURN;
END


-----------------------------
-- 4) INSERTAR EN AspNetUsers
-----------------------------
DECLARE @NuevosUsuarios TABLE (
    UsuarioID UNIQUEIDENTIFIER,
    UserId    NVARCHAR(128),
    Email     NVARCHAR(256)
);

INSERT INTO AspNetUsers (
    Id,
    UsuarioID,
    Email,
    EmailConfirmed,
    PasswordHash,
    SecurityStamp,
    PhoneNumber,
    PhoneNumberConfirmed,
    TwoFactorEnabled,
    LockoutEndDateUtc,
    LockoutEnabled,
    AccessFailedCount,
    UserName
)
OUTPUT inserted.UsuarioID, inserted.Id, inserted.Email
    INTO @NuevosUsuarios (UsuarioID, UserId, Email)
SELECT
    CAST(NEWID() AS NVARCHAR(128)) AS Id,
    u.UsuarioID,
    u.EmailSugerido               AS Email,
    0                             AS EmailConfirmed,
    @DefaultPasswordHash          AS PasswordHash,
    CAST(NEWID() AS NVARCHAR(128)) AS SecurityStamp,
    NULL                          AS PhoneNumber,
    0                             AS PhoneNumberConfirmed,
    0                             AS TwoFactorEnabled,
    NULL                          AS LockoutEndDateUtc,
    0                             AS LockoutEnabled,
    0                             AS AccessFailedCount,
    u.EmailSugerido               AS UserName
FROM #UsuariosObjetivo u;


-----------------------------
-- 5) INSERTAR ROLES (AspNetUserRoles)
-----------------------------
INSERT INTO AspNetUserRoles (UserId, RoleId)
SELECT 
    nu.UserId,
    @RoleId
FROM @NuevosUsuarios nu;


-----------------------------
-- 6) RESUMEN FINAL
-----------------------------
PRINT 'Se crearon credenciales web para los siguientes consumidores:';

SELECT 
    u.UsuarioID,
    u.Numero,
    u.Apellido,
    u.Nombre,
    nu.Email,
    @RoleName AS RolAsignado
FROM #UsuariosObjetivo u
JOIN @NuevosUsuarios nu
    ON nu.UsuarioID = u.UsuarioID
ORDER BY u.Numero;

DROP TABLE #UsuariosObjetivo;
GO
