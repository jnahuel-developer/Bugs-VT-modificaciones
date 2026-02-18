USE BugsDev;
GO

/* ============================================================
   Script 3 - Consumidores y credenciales
   - 10 Usuarios ligados a Operador Nahuel / Locación Dev / Jerarquía General
   - 6 de ellos con credenciales web en AspNetUsers
   ============================================================ */

PRINT '=== Script 3: Consumidores y credenciales ===';

-------------------------------------------------------------
-- 0) IDs fijos coherentes con Script 1
-------------------------------------------------------------
DECLARE @OperadorNahuelId      UNIQUEIDENTIFIER = '11111111-1111-1111-1111-111111111111';
DECLARE @LocacionPruebasId     UNIQUEIDENTIFIER = '33333333-3333-3333-3333-333333333333';
DECLARE @JerarquiaBasicaId     UNIQUEIDENTIFIER = '44444444-4444-4444-4444-444444444444';

-------------------------------------------------------------
-- 1) Obtener plantilla de AspNetUsers desde el usuario admin
-------------------------------------------------------------
PRINT '1) Obteniendo plantilla de credenciales desde el usuario admin...';

DECLARE @TemplatePasswordHash       NVARCHAR(MAX);
DECLARE @TemplateSecurityStamp      NVARCHAR(MAX);
DECLARE @TemplateEmailConfirmed     BIT;
DECLARE @TemplatePhoneConfirmed     BIT;
DECLARE @TemplateTwoFactorEnabled   BIT;
DECLARE @TemplateLockoutEnabled     BIT;
DECLARE @TemplateAccessFailedCount  INT;

SELECT 
    @TemplatePasswordHash      = PasswordHash,
    @TemplateSecurityStamp     = SecurityStamp,
    @TemplateEmailConfirmed    = EmailConfirmed,
    @TemplatePhoneConfirmed    = PhoneNumberConfirmed,
    @TemplateTwoFactorEnabled  = TwoFactorEnabled,
    @TemplateLockoutEnabled    = LockoutEnabled,
    @TemplateAccessFailedCount = AccessFailedCount
FROM AspNetUsers
WHERE Email = 'jnahuel.developer@gmail.com';

IF @TemplatePasswordHash IS NULL
BEGIN
    RAISERROR('No se encontró el usuario admin en AspNetUsers (mail jnahuel.developer@gmail.com).', 16, 1);
    RETURN;
END

PRINT '   - Plantilla de Identity obtenida.';


-------------------------------------------------------------
-- 2) Determinar base para los números de consumidor en la locación
-------------------------------------------------------------
PRINT '2) Calculando base de Numero en Usuario para la locación de pruebas...';

DECLARE @BaseNumero INT;

SELECT @BaseNumero = ISNULL(MAX(Numero), 0)
FROM Usuario
WHERE LocacionID = @LocacionPruebasId;

PRINT '   - Máximo Numero actual en esta locación: ' + CONVERT(NVARCHAR(20), @BaseNumero);

DECLARE @Num1 INT = @BaseNumero + 1;
DECLARE @Num2 INT = @BaseNumero + 2;
DECLARE @Num3 INT = @BaseNumero + 3;
DECLARE @Num4 INT = @BaseNumero + 4;
DECLARE @Num5 INT = @BaseNumero + 5;
DECLARE @Num6 INT = @BaseNumero + 6;
DECLARE @Num7 INT = @BaseNumero + 7;
DECLARE @Num8 INT = @BaseNumero + 8;
DECLARE @Num9 INT = @BaseNumero + 9;
DECLARE @Num10 INT = @BaseNumero + 10;


-------------------------------------------------------------
-- 3) Definir IDs de Usuario (GUID) para los 10 consumidores
-------------------------------------------------------------
DECLARE @Usuario1Id  UNIQUEIDENTIFIER = NEWID();
DECLARE @Usuario2Id  UNIQUEIDENTIFIER = NEWID();
DECLARE @Usuario3Id  UNIQUEIDENTIFIER = NEWID();
DECLARE @Usuario4Id  UNIQUEIDENTIFIER = NEWID();
DECLARE @Usuario5Id  UNIQUEIDENTIFIER = NEWID();
DECLARE @Usuario6Id  UNIQUEIDENTIFIER = NEWID();
DECLARE @Usuario7Id  UNIQUEIDENTIFIER = NEWID();
DECLARE @Usuario8Id  UNIQUEIDENTIFIER = NEWID();
DECLARE @Usuario9Id  UNIQUEIDENTIFIER = NEWID();
DECLARE @Usuario10Id UNIQUEIDENTIFIER = NEWID();


-------------------------------------------------------------
-- 4) Insertar 10 Usuarios de prueba
-------------------------------------------------------------
PRINT '4) Insertando 10 consumidores de prueba...';

-- Usuario 1: Juan Lopez
IF NOT EXISTS (SELECT 1 FROM Usuario WHERE UsuarioID = @Usuario1Id)
BEGIN
    INSERT INTO Usuario
    (
        UsuarioID,
        Apellido, Nombre, Legajo, Dni,
        Numero, ClaveTerminal,
        FechaVencimiento, FechaCreacion, Inhibido,
        FechaInhibido, UltimoUsoVT,
        Efectivo,
        CreditoZona1, CreditoZona2, CreditoZona3, CreditoZona4, CreditoZona5,
        UltimaRecargaZona1, UltimaRecargaZona2, UltimaRecargaZona3, UltimaRecargaZona4, UltimaRecargaZona5,
        Recarga_Recargado, Recarga_Recortado,
        Recarga_RecargaTotalTeorica,
        EsServicioTecnico,
        OperadorID, LocacionID, JerarquiaID
    )
    VALUES
    (
        @Usuario1Id,
        N'Lopez', N'Juan', N'EMP001', 30123456,
        @Num1, 1111,
        DATEADD(YEAR, 1, GETDATE()), GETDATE(), 0,
        NULL, GETDATE(),
        0.00,
        0.00, 0.00, 0.00, 0.00, 0.00,
        NULL, NULL, NULL, NULL, NULL,
        0, 0,
        0.00,
        0,
        @OperadorNahuelId, @LocacionPruebasId, @JerarquiaBasicaId
    );
END

-- Usuario 2: Maria Garcia
IF NOT EXISTS (SELECT 1 FROM Usuario WHERE UsuarioID = @Usuario2Id)
BEGIN
    INSERT INTO Usuario
    (
        UsuarioID,
        Apellido, Nombre, Legajo, Dni,
        Numero, ClaveTerminal,
        FechaVencimiento, FechaCreacion, Inhibido,
        FechaInhibido, UltimoUsoVT,
        Efectivo,
        CreditoZona1, CreditoZona2, CreditoZona3, CreditoZona4, CreditoZona5,
        UltimaRecargaZona1, UltimaRecargaZona2, UltimaRecargaZona3, UltimaRecargaZona4, UltimaRecargaZona5,
        Recarga_Recargado, Recarga_Recortado,
        Recarga_RecargaTotalTeorica,
        EsServicioTecnico,
        OperadorID, LocacionID, JerarquiaID
    )
    VALUES
    (
        @Usuario2Id,
        N'Garcia', N'Maria', N'EMP002', 30223456,
        @Num2, 2222,
        DATEADD(YEAR, 1, GETDATE()), GETDATE(), 0,
        NULL, DATEADD(DAY, -1, GETDATE()),
        0.00,
        0.00, 0.00, 0.00, 0.00, 0.00,
        NULL, NULL, NULL, NULL, NULL,
        0, 0,
        0.00,
        0,
        @OperadorNahuelId, @LocacionPruebasId, @JerarquiaBasicaId
    );
END

-- Usuario 3: Carlos Sanchez
IF NOT EXISTS (SELECT 1 FROM Usuario WHERE UsuarioID = @Usuario3Id)
BEGIN
    INSERT INTO Usuario
    (
        UsuarioID,
        Apellido, Nombre, Legajo, Dni,
        Numero, ClaveTerminal,
        FechaVencimiento, FechaCreacion, Inhibido,
        FechaInhibido, UltimoUsoVT,
        Efectivo,
        CreditoZona1, CreditoZona2, CreditoZona3, CreditoZona4, CreditoZona5,
        UltimaRecargaZona1, UltimaRecargaZona2, UltimaRecargaZona3, UltimaRecargaZona4, UltimaRecargaZona5,
        Recarga_Recargado, Recarga_Recortado,
        Recarga_RecargaTotalTeorica,
        EsServicioTecnico,
        OperadorID, LocacionID, JerarquiaID
    )
    VALUES
    (
        @Usuario3Id,
        N'Sanchez', N'Carlos', N'EMP003', 30323456,
        @Num3, 3333,
        DATEADD(YEAR, 1, GETDATE()), GETDATE(), 0,
        NULL, DATEADD(DAY, -2, GETDATE()),
        0.00,
        0.00, 0.00, 0.00, 0.00, 0.00,
        NULL, NULL, NULL, NULL, NULL,
        0, 0,
        0.00,
        0,
        @OperadorNahuelId, @LocacionPruebasId, @JerarquiaBasicaId
    );
END

-- Usuario 4: Ana Torres
IF NOT EXISTS (SELECT 1 FROM Usuario WHERE UsuarioID = @Usuario4Id)
BEGIN
    INSERT INTO Usuario
    (
        UsuarioID,
        Apellido, Nombre, Legajo, Dni,
        Numero, ClaveTerminal,
        FechaVencimiento, FechaCreacion, Inhibido,
        FechaInhibido, UltimoUsoVT,
        Efectivo,
        CreditoZona1, CreditoZona2, CreditoZona3, CreditoZona4, CreditoZona5,
        UltimaRecargaZona1, UltimaRecargaZona2, UltimaRecargaZona3, UltimaRecargaZona4, UltimaRecargaZona5,
        Recarga_Recargado, Recarga_Recortado,
        Recarga_RecargaTotalTeorica,
        EsServicioTecnico,
        OperadorID, LocacionID, JerarquiaID
    )
    VALUES
    (
        @Usuario4Id,
        N'Torres', N'Ana', N'EMP004', 30423456,
        @Num4, 4444,
        DATEADD(YEAR, 1, GETDATE()), GETDATE(), 0,
        NULL, DATEADD(DAY, -3, GETDATE()),
        0.00,
        0.00, 0.00, 0.00, 0.00, 0.00,
        NULL, NULL, NULL, NULL, NULL,
        0, 0,
        0.00,
        0,
        @OperadorNahuelId, @LocacionPruebasId, @JerarquiaBasicaId
    );
END

-- Usuario 5: Luis Fernandez
IF NOT EXISTS (SELECT 1 FROM Usuario WHERE UsuarioID = @Usuario5Id)
BEGIN
    INSERT INTO Usuario
    (
        UsuarioID,
        Apellido, Nombre, Legajo, Dni,
        Numero, ClaveTerminal,
        FechaVencimiento, FechaCreacion, Inhibido,
        FechaInhibido, UltimoUsoVT,
        Efectivo,
        CreditoZona1, CreditoZona2, CreditoZona3, CreditoZona4, CreditoZona5,
        UltimaRecargaZona1, UltimaRecargaZona2, UltimaRecargaZona3, UltimaRecargaZona4, UltimaRecargaZona5,
        Recarga_Recargado, Recarga_Recortado,
        Recarga_RecargaTotalTeorica,
        EsServicioTecnico,
        OperadorID, LocacionID, JerarquiaID
    )
    VALUES
    (
        @Usuario5Id,
        N'Fernandez', N'Luis', N'EMP005', 30523456,
        @Num5, 5555,
        DATEADD(YEAR, 1, GETDATE()), GETDATE(), 0,
        NULL, DATEADD(DAY, -4, GETDATE()),
        0.00,
        0.00, 0.00, 0.00, 0.00, 0.00,
        NULL, NULL, NULL, NULL, NULL,
        0, 0,
        0.00,
        0,
        @OperadorNahuelId, @LocacionPruebasId, @JerarquiaBasicaId
    );
END

-- Usuario 6: Sofia Ramirez
IF NOT EXISTS (SELECT 1 FROM Usuario WHERE UsuarioID = @Usuario6Id)
BEGIN
    INSERT INTO Usuario
    (
        UsuarioID,
        Apellido, Nombre, Legajo, Dni,
        Numero, ClaveTerminal,
        FechaVencimiento, FechaCreacion, Inhibido,
        FechaInhibido, UltimoUsoVT,
        Efectivo,
        CreditoZona1, CreditoZona2, CreditoZona3, CreditoZona4, CreditoZona5,
        UltimaRecargaZona1, UltimaRecargaZona2, UltimaRecargaZona3, UltimaRecargaZona4, UltimaRecargaZona5,
        Recarga_Recargado, Recarga_Recortado,
        Recarga_RecargaTotalTeorica,
        EsServicioTecnico,
        OperadorID, LocacionID, JerarquiaID
    )
    VALUES
    (
        @Usuario6Id,
        N'Ramirez', N'Sofia', N'EMP006', 30623456,
        @Num6, 6666,
        DATEADD(YEAR, 1, GETDATE()), GETDATE(), 0,
        NULL, DATEADD(DAY, -5, GETDATE()),
        0.00,
        0.00, 0.00, 0.00, 0.00, 0.00,
        NULL, NULL, NULL, NULL, NULL,
        0, 0,
        0.00,
        0,
        @OperadorNahuelId, @LocacionPruebasId, @JerarquiaBasicaId
    );
END

-- Usuario 7: Diego Alvarez
IF NOT EXISTS (SELECT 1 FROM Usuario WHERE UsuarioID = @Usuario7Id)
BEGIN
    INSERT INTO Usuario
    (
        UsuarioID,
        Apellido, Nombre, Legajo, Dni,
        Numero, ClaveTerminal,
        FechaVencimiento, FechaCreacion, Inhibido,
        FechaInhibido, UltimoUsoVT,
        Efectivo,
        CreditoZona1, CreditoZona2, CreditoZona3, CreditoZona4, CreditoZona5,
        UltimaRecargaZona1, UltimaRecargaZona2, UltimaRecargaZona3, UltimaRecargaZona4, UltimaRecargaZona5,
        Recarga_Recargado, Recarga_Recortado,
        Recarga_RecargaTotalTeorica,
        EsServicioTecnico,
        OperadorID, LocacionID, JerarquiaID
    )
    VALUES
    (
        @Usuario7Id,
        N'Alvarez', N'Diego', N'EMP007', 30723456,
        @Num7, 7777,
        DATEADD(YEAR, 1, GETDATE()), GETDATE(), 0,
        NULL, DATEADD(DAY, -6, GETDATE()),
        0.00,
        0.00, 0.00, 0.00, 0.00, 0.00,
        NULL, NULL, NULL, NULL, NULL,
        0, 0,
        0.00,
        0,
        @OperadorNahuelId, @LocacionPruebasId, @JerarquiaBasicaId
    );
END

-- Usuario 8: Paula Guzman
IF NOT EXISTS (SELECT 1 FROM Usuario WHERE UsuarioID = @Usuario8Id)
BEGIN
    INSERT INTO Usuario
    (
        UsuarioID,
        Apellido, Nombre, Legajo, Dni,
        Numero, ClaveTerminal,
        FechaVencimiento, FechaCreacion, Inhibido,
        FechaInhibido, UltimoUsoVT,
        Efectivo,
        CreditoZona1, CreditoZona2, CreditoZona3, CreditoZona4, CreditoZona5,
        UltimaRecargaZona1, UltimaRecargaZona2, UltimaRecargaZona3, UltimaRecargaZona4, UltimaRecargaZona5,
        Recarga_Recargado, Recarga_Recortado,
        Recarga_RecargaTotalTeorica,
        EsServicioTecnico,
        OperadorID, LocacionID, JerarquiaID
    )
    VALUES
    (
        @Usuario8Id,
        N'Guzman', N'Paula', N'EMP008', 30823456,
        @Num8, 8888,
        DATEADD(YEAR, 1, GETDATE()), GETDATE(), 0,
        NULL, DATEADD(DAY, -7, GETDATE()),
        0.00,
        0.00, 0.00, 0.00, 0.00, 0.00,
        NULL, NULL, NULL, NULL, NULL,
        0, 0,
        0.00,
        0,
        @OperadorNahuelId, @LocacionPruebasId, @JerarquiaBasicaId
    );
END

-- Usuario 9: Martin Herrera
IF NOT EXISTS (SELECT 1 FROM Usuario WHERE UsuarioID = @Usuario9Id)
BEGIN
    INSERT INTO Usuario
    (
        UsuarioID,
        Apellido, Nombre, Legajo, Dni,
        Numero, ClaveTerminal,
        FechaVencimiento, FechaCreacion, Inhibido,
        FechaInhibido, UltimoUsoVT,
        Efectivo,
        CreditoZona1, CreditoZona2, CreditoZona3, CreditoZona4, CreditoZona5,
        UltimaRecargaZona1, UltimaRecargaZona2, UltimaRecargaZona3, UltimaRecargaZona4, UltimaRecargaZona5,
        Recarga_Recargado, Recarga_Recortado,
        Recarga_RecargaTotalTeorica,
        EsServicioTecnico,
        OperadorID, LocacionID, JerarquiaID
    )
    VALUES
    (
        @Usuario9Id,
        N'Herrera', N'Martin', N'EMP009', 30923456,
        @Num9, 9999,
        DATEADD(YEAR, 1, GETDATE()), GETDATE(), 0,
        NULL, DATEADD(DAY, -8, GETDATE()),
        0.00,
        0.00, 0.00, 0.00, 0.00, 0.00,
        NULL, NULL, NULL, NULL, NULL,
        0, 0,
        0.00,
        0,
        @OperadorNahuelId, @LocacionPruebasId, @JerarquiaBasicaId
    );
END

-- Usuario 10: Carla Dominguez
IF NOT EXISTS (SELECT 1 FROM Usuario WHERE UsuarioID = @Usuario10Id)
BEGIN
    INSERT INTO Usuario
    (
        UsuarioID,
        Apellido, Nombre, Legajo, Dni,
        Numero, ClaveTerminal,
        FechaVencimiento, FechaCreacion, Inhibido,
        FechaInhibido, UltimoUsoVT,
        Efectivo,
        CreditoZona1, CreditoZona2, CreditoZona3, CreditoZona4, CreditoZona5,
        UltimaRecargaZona1, UltimaRecargaZona2, UltimaRecargaZona3, UltimaRecargaZona4, UltimaRecargaZona5,
        Recarga_Recargado, Recarga_Recortado,
        Recarga_RecargaTotalTeorica,
        EsServicioTecnico,
        OperadorID, LocacionID, JerarquiaID
    )
    VALUES
    (
        @Usuario10Id,
        N'Dominguez', N'Carla', N'EMP010', 31023456,
        @Num10, 1010,
        DATEADD(YEAR, 1, GETDATE()), GETDATE(), 0,
        NULL, DATEADD(DAY, -9, GETDATE()),
        0.00,
        0.00, 0.00, 0.00, 0.00, 0.00,
        NULL, NULL, NULL, NULL, NULL,
        0, 0,
        0.00,
        0,
        @OperadorNahuelId, @LocacionPruebasId, @JerarquiaBasicaId
    );
END

PRINT '   - Usuarios insertados (si no existían).';


-------------------------------------------------------------
-- 5) Crear AspNetUsers para 6 consumidores (1 a 6)
-------------------------------------------------------------
PRINT '5) Creando credenciales web para 6 consumidores...';

DECLARE @AspNetUser1Id NVARCHAR(128) = CONVERT(NVARCHAR(128), NEWID());
DECLARE @AspNetUser2Id NVARCHAR(128) = CONVERT(NVARCHAR(128), NEWID());
DECLARE @AspNetUser3Id NVARCHAR(128) = CONVERT(NVARCHAR(128), NEWID());
DECLARE @AspNetUser4Id NVARCHAR(128) = CONVERT(NVARCHAR(128), NEWID());
DECLARE @AspNetUser5Id NVARCHAR(128) = CONVERT(NVARCHAR(128), NEWID());
DECLARE @AspNetUser6Id NVARCHAR(128) = CONVERT(NVARCHAR(128), NEWID());

-- Para todos usaremos el mismo PasswordHash de la plantilla (mismo password que el admin)

-- Usuario 1: Juan Lopez
IF NOT EXISTS (SELECT 1 FROM AspNetUsers WHERE UsuarioID = @Usuario1Id)
BEGIN
    INSERT INTO AspNetUsers
    (
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
    VALUES
    (
        @AspNetUser1Id,
        @Usuario1Id,
        N'juan.lopez@devtest.com',
        @TemplateEmailConfirmed,
        @TemplatePasswordHash,
        @TemplateSecurityStamp,
        NULL,
        @TemplatePhoneConfirmed,
        @TemplateTwoFactorEnabled,
        NULL,
        @TemplateLockoutEnabled,
        @TemplateAccessFailedCount,
        N'juan.lopez@devtest.com'
    );
END

-- Usuario 2: Maria Garcia
IF NOT EXISTS (SELECT 1 FROM AspNetUsers WHERE UsuarioID = @Usuario2Id)
BEGIN
    INSERT INTO AspNetUsers
    (
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
    VALUES
    (
        @AspNetUser2Id,
        @Usuario2Id,
        N'maria.garcia@devtest.com',
        @TemplateEmailConfirmed,
        @TemplatePasswordHash,
        @TemplateSecurityStamp,
        NULL,
        @TemplatePhoneConfirmed,
        @TemplateTwoFactorEnabled,
        NULL,
        @TemplateLockoutEnabled,
        @TemplateAccessFailedCount,
        N'maria.garcia@devtest.com'
    );
END

-- Usuario 3: Carlos Sanchez
IF NOT EXISTS (SELECT 1 FROM AspNetUsers WHERE UsuarioID = @Usuario3Id)
BEGIN
    INSERT INTO AspNetUsers
    (
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
    VALUES
    (
        @AspNetUser3Id,
        @Usuario3Id,
        N'carlos.sanchez@devtest.com',
        @TemplateEmailConfirmed,
        @TemplatePasswordHash,
        @TemplateSecurityStamp,
        NULL,
        @TemplatePhoneConfirmed,
        @TemplateTwoFactorEnabled,
        NULL,
        @TemplateLockoutEnabled,
        @TemplateAccessFailedCount,
        N'carlos.sanchez@devtest.com'
    );
END

-- Usuario 4: Ana Torres
IF NOT EXISTS (SELECT 1 FROM AspNetUsers WHERE UsuarioID = @Usuario4Id)
BEGIN
    INSERT INTO AspNetUsers
    (
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
    VALUES
    (
        @AspNetUser4Id,
        @Usuario4Id,
        N'ana.torres@devtest.com',
        @TemplateEmailConfirmed,
        @TemplatePasswordHash,
        @TemplateSecurityStamp,
        NULL,
        @TemplatePhoneConfirmed,
        @TemplateTwoFactorEnabled,
        NULL,
        @TemplateLockoutEnabled,
        @TemplateAccessFailedCount,
        N'ana.torres@devtest.com'
    );
END

-- Usuario 5: Luis Fernandez
IF NOT EXISTS (SELECT 1 FROM AspNetUsers WHERE UsuarioID = @Usuario5Id)
BEGIN
    INSERT INTO AspNetUsers
    (
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
    VALUES
    (
        @AspNetUser5Id,
        @Usuario5Id,
        N'luis.fernandez@devtest.com',
        @TemplateEmailConfirmed,
        @TemplatePasswordHash,
        @TemplateSecurityStamp,
        NULL,
        @TemplatePhoneConfirmed,
        @TemplateTwoFactorEnabled,
        NULL,
        @TemplateLockoutEnabled,
        @TemplateAccessFailedCount,
        N'luis.fernandez@devtest.com'
    );
END

-- Usuario 6: Sofia Ramirez
IF NOT EXISTS (SELECT 1 FROM AspNetUsers WHERE UsuarioID = @Usuario6Id)
BEGIN
    INSERT INTO AspNetUsers
    (
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
    VALUES
    (
        @AspNetUser6Id,
        @Usuario6Id,
        N'sofia.ramirez@devtest.com',
        @TemplateEmailConfirmed,
        @TemplatePasswordHash,
        @TemplateSecurityStamp,
        NULL,
        @TemplatePhoneConfirmed,
        @TemplateTwoFactorEnabled,
        NULL,
        @TemplateLockoutEnabled,
        @TemplateAccessFailedCount,
        N'sofia.ramirez@devtest.com'
    );
END

PRINT '   - Credenciales creadas para 6 consumidores (1 a 6).';


-------------------------------------------------------------
-- 6) Resumen de lo creado
-------------------------------------------------------------
PRINT '6) Resumen de consumidores y credenciales:';

SELECT 
    u.UsuarioID,
    u.Apellido,
    u.Nombre,
    u.Numero,
    u.ClaveTerminal,
    u.OperadorID,
    u.LocacionID,
    u.JerarquiaID
FROM Usuario u
WHERE u.UsuarioID IN 
(
    @Usuario1Id, @Usuario2Id, @Usuario3Id, @Usuario4Id, @Usuario5Id,
    @Usuario6Id, @Usuario7Id, @Usuario8Id, @Usuario9Id, @Usuario10Id
)
ORDER BY u.Numero;

SELECT 
    anu.Id      AS AspNetUserId,
    anu.UsuarioID,
    anu.Email,
    anu.UserName
FROM AspNetUsers anu
WHERE anu.UsuarioID IN 
(
    @Usuario1Id, @Usuario2Id, @Usuario3Id, @Usuario4Id, @Usuario5Id, @Usuario6Id
)
ORDER BY anu.Email;

PRINT '=== Fin Script 3: Consumidores y credenciales ===';
GO
