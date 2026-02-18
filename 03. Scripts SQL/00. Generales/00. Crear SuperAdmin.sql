USE BugsDev;
GO

/* Script crear usuario ADMIN SuperAdmin
   Mail: jnahuel.developer@gmail.com
   Password: 123456 (hash provisto) */

DECLARE @AdminUsuarioId   UNIQUEIDENTIFIER = '0235532B-F4D8-4F39-ABA9-4C5E5CDA1EE7';
DECLARE @AdminAspNetId    NVARCHAR(128);
DECLARE @SuperAdminRoleId NVARCHAR(128);
DECLARE @PasswordHash     NVARCHAR(MAX) = 'AFe7ZzniG8g/tZuG7jF+0JTqll4otxupK7p38wh1Y28RMDzWd6AkTzbvCabk1Y2FBw==';

PRINT '=== Creando/recuperando ADMIN ===';

--------------------------------------------------
-- 1) Asegurar rol SuperAdmin
--------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM AspNetRoles WHERE [Name] = 'SuperAdmin')
BEGIN
    SET @SuperAdminRoleId = CAST(NEWID() AS NVARCHAR(128));
    INSERT INTO AspNetRoles (Id, [Name], [Weight])
    VALUES (@SuperAdminRoleId, 'SuperAdmin', 1000);

    PRINT '- Rol SuperAdmin creado.';
END
ELSE
BEGIN
    SELECT @SuperAdminRoleId = Id
    FROM AspNetRoles
    WHERE [Name] = 'SuperAdmin';

    PRINT '- Rol SuperAdmin ya existía.';
END

--------------------------------------------------
-- 2) Asegurar fila en Usuario (datos básicos)
--------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM Usuario WHERE UsuarioID = @AdminUsuarioId)
BEGIN
    INSERT INTO Usuario
    (
        UsuarioID, Apellido, Nombre, Legajo, Dni,
        Numero, ClaveTerminal, FechaVencimiento, FechaCreacion,
        Inhibido, FechaInhibido, UltimoUsoVT,
        Efectivo,
        CreditoZona1, CreditoZona2, CreditoZona3, CreditoZona4, CreditoZona5,
        UltimaRecargaZona1, UltimaRecargaZona2, UltimaRecargaZona3, UltimaRecargaZona4, UltimaRecargaZona5,
        Recarga_Recargado, Recarga_Recortado,
        Recarga_CreditoInicialZona1, Recarga_CreditoInicialZona2, Recarga_CreditoInicialZona3,
        Recarga_CreditoInicialZona4, Recarga_CreditoInicialZona5,
        Recarga_CreditoIntermedioZona1, Recarga_CreditoIntermedioZona2, Recarga_CreditoIntermedioZona3,
        Recarga_CreditoIntermedioZona4, Recarga_CreditoIntermedioZona5,
        Recarga_CreditoFinalZona1, Recarga_CreditoFinalZona2, Recarga_CreditoFinalZona3,
        Recarga_CreditoFinalZona4, Recarga_CreditoFinalZona5,
        Recarga_EfectivoInicial, Recarga_EfectivoFinal,
        Recarga_RecargaTotalTeorica,
        EsServicioTecnico,
        OperadorID, LocacionID, JerarquiaID
    )
    VALUES
    (
        @AdminUsuarioId,
        N'Dev', N'Admin', N'ADM001', 12345678,
        1, 1234, NULL, GETDATE(),
        0, NULL, NULL,
        0.00,
        0.00, 0.00, 0.00, 0.00, 0.00,
        NULL, NULL, NULL, NULL, NULL,
        0, 0,
        NULL, NULL, NULL,
        NULL, NULL,
        NULL, NULL, NULL,
        NULL, NULL,
        NULL, NULL, NULL,
        NULL, NULL,
        NULL, NULL,
        0.00,
        0,      -- EsServicioTecnico
        NULL, NULL, NULL  -- sin Operador/Locación/Jerarquía
    );

    PRINT '- Fila Usuario para ADMIN creada.';
END
ELSE
    PRINT '- Fila Usuario para ADMIN ya existía.';

--------------------------------------------------
-- 3) Crear AspNetUsers si no existe
--------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM AspNetUsers WHERE Email = 'jnahuel.developer@gmail.com')
BEGIN
    SET @AdminAspNetId = CAST(NEWID() AS NVARCHAR(128));

    INSERT INTO AspNetUsers
    (
        Id, UserName, Email,
        EmailConfirmed, PasswordHash, SecurityStamp,
        PhoneNumberConfirmed, TwoFactorEnabled,
        LockoutEnabled, AccessFailedCount,
        UsuarioID
    )
    VALUES
    (
        @AdminAspNetId,
        'jnahuel.developer@gmail.com',
        'jnahuel.developer@gmail.com',
        1,                      -- EmailConfirmed
        @PasswordHash,
        CAST(NEWID() AS NVARCHAR(128)),
        0,                      -- PhoneNumberConfirmed
        0,                      -- TwoFactorEnabled
        0,                      -- LockoutEnabled
        0,                      -- AccessFailedCount
        @AdminUsuarioId
    );

    PRINT '- AspNetUsers ADMIN creado.';
END
ELSE
BEGIN
    SELECT @AdminAspNetId = Id
    FROM AspNetUsers
    WHERE Email = 'jnahuel.developer@gmail.com';

    PRINT '- AspNetUsers ADMIN ya existía.';
END

--------------------------------------------------
-- 4) Asociar ADMIN al rol SuperAdmin
--------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM AspNetUserRoles
    WHERE UserId = @AdminAspNetId
      AND RoleId = @SuperAdminRoleId
)
BEGIN
    INSERT INTO AspNetUserRoles (UserId, RoleId)
    VALUES (@AdminAspNetId, @SuperAdminRoleId);

    PRINT '- ADMIN asignado al rol SuperAdmin.';
END
ELSE
    PRINT '- ADMIN ya tenía rol SuperAdmin.';

PRINT '=== Fin script recreación ADMIN ===';
GO
