USE BugsDev;
GO

/* 1) Parámetros del Admin */
DECLARE @UsuarioId       UNIQUEIDENTIFIER = '0235532B-F4D8-4F39-ABA9-4C5E5CDA1EE7';
DECLARE @Email           NVARCHAR(256)    = 'jnahuel.developer@gmail.com';
DECLARE @PasswordHash    NVARCHAR(MAX)    = 'AFe7ZzniG8g/tZuG7jF+0JTqll4otxupK7p38wh1Y28RMDzWd6AkTzbvCabk1Y2FBw==';

DECLARE @AspNetUserId      NVARCHAR(128);
DECLARE @SuperAdminRoleId  NVARCHAR(128);

/* 2) Verificar que exista el Usuario de negocio */


/* 3) Buscar si ya hay AspNetUsers para ese Usuario */
SELECT TOP 1 @AspNetUserId = Id
FROM AspNetUsers
WHERE UsuarioID = @UsuarioId;

IF @AspNetUserId IS NULL
BEGIN
    SET @AspNetUserId = CAST(NEWID() AS NVARCHAR(128));

    INSERT INTO AspNetUsers
        (Id, UsuarioID, Email, EmailConfirmed, PasswordHash,
         SecurityStamp, PhoneNumber, PhoneNumberConfirmed,
         TwoFactorEnabled, LockoutEndDateUtc, LockoutEnabled,
         AccessFailedCount, UserName)
    VALUES
        (@AspNetUserId, @UsuarioId, @Email, 1, @PasswordHash,
         CAST(NEWID() AS NVARCHAR(128)), NULL, 0,
         0, NULL, 0,
         0, @Email);

    PRINT 'AspNetUsers: usuario ADMIN creado -> ' + @AspNetUserId;
END
ELSE
BEGIN
    UPDATE AspNetUsers
       SET Email        = @Email,
           UserName     = @Email,
           PasswordHash = @PasswordHash
     WHERE Id = @AspNetUserId;

    PRINT 'AspNetUsers: usuario ADMIN ya existía, se actualizaron Email/UserName/PasswordHash -> ' + @AspNetUserId;
END

/* 4) Asegurar rol SuperAdmin en AspNetRoles (con o sin columna Weight) */
IF EXISTS (SELECT 1
           FROM sys.columns
           WHERE [name] = 'Weight'
             AND [object_id] = OBJECT_ID('dbo.AspNetRoles'))
BEGIN
    IF NOT EXISTS (SELECT 1 FROM AspNetRoles WHERE [Name] = 'SuperAdmin')
    BEGIN
        SET @SuperAdminRoleId = CAST(NEWID() AS NVARCHAR(128));
        INSERT INTO AspNetRoles (Id, [Name], [Weight])
        VALUES (@SuperAdminRoleId, 'SuperAdmin', 1000);
        PRINT 'AspNetRoles: rol SuperAdmin creado (con Weight).';
    END
    ELSE
    BEGIN
        SELECT @SuperAdminRoleId = Id
        FROM AspNetRoles
        WHERE [Name] = 'SuperAdmin';
        PRINT 'AspNetRoles: rol SuperAdmin ya existía (con Weight).';
    END
END
ELSE
BEGIN
    IF NOT EXISTS (SELECT 1 FROM AspNetRoles WHERE [Name] = 'SuperAdmin')
    BEGIN
        SET @SuperAdminRoleId = CAST(NEWID() AS NVARCHAR(128));
        INSERT INTO AspNetRoles (Id, [Name])
        VALUES (@SuperAdminRoleId, 'SuperAdmin');
        PRINT 'AspNetRoles: rol SuperAdmin creado (sin Weight).';
    END
    ELSE
    BEGIN
        SELECT @SuperAdminRoleId = Id
        FROM AspNetRoles
        WHERE [Name] = 'SuperAdmin';
        PRINT 'AspNetRoles: rol SuperAdmin ya existía (sin Weight).';
    END
END

/* 5) Asignar rol SuperAdmin al admin */
IF NOT EXISTS (
    SELECT 1
    FROM AspNetUserRoles
    WHERE UserId = @AspNetUserId
      AND RoleId = @SuperAdminRoleId
)
BEGIN
    INSERT INTO AspNetUserRoles (UserId, RoleId)
    VALUES (@AspNetUserId, @SuperAdminRoleId);

    PRINT 'AspNetUserRoles: rol SuperAdmin asignado al Admin.';
END
ELSE
BEGIN
    PRINT 'AspNetUserRoles: el Admin ya tenía rol SuperAdmin.';
END

/* 6) Mostrar resumen */
PRINT '--- RESUMEN ADMIN ---';
SELECT  u.UsuarioID, u.Numero, u.Nombre, u.Apellido, u.Dni,
        u.Legajo, u.OperadorID, u.LocacionID, u.JerarquiaID
FROM Usuario u
WHERE u.UsuarioID = @UsuarioId;

SELECT  au.Id        AS AspNetUserId,
        au.Email,
        au.UserName,
        au.EmailConfirmed,
        au.LockoutEnabled,
        au.AccessFailedCount
FROM AspNetUsers au
WHERE au.UsuarioID = @UsuarioId;

SELECT r.Name AS RolAsignado
FROM AspNetUserRoles ur
JOIN AspNetRoles r ON r.Id = ur.RoleId
WHERE ur.UserId = @AspNetUserId;
GO
