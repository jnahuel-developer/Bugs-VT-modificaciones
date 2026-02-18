USE BugsDev;
GO

---------------------------------------------------------
-- 0) Asegurar que exista el rol SuperAdmin
---------------------------------------------------------
DECLARE @SuperAdminRoleId NVARCHAR(128);

IF NOT EXISTS (SELECT 1 FROM AspNetRoles WHERE [Name] = 'SuperAdmin')
BEGIN
    SET @SuperAdminRoleId = CAST(NEWID() AS NVARCHAR(128));
    INSERT INTO AspNetRoles (Id, [Name], [Weight])
    VALUES (@SuperAdminRoleId, 'SuperAdmin', 1000);
END
ELSE
BEGIN
    SELECT @SuperAdminRoleId = Id
    FROM AspNetRoles
    WHERE [Name] = 'SuperAdmin';
END

---------------------------------------------------------
-- 1) Dar SUPERADMIN en TODAS las funciones existentes
---------------------------------------------------------
INSERT INTO FuncionRol (IdFuncion, IdRol)
SELECT f.Id, @SuperAdminRoleId
FROM Funcion f
WHERE NOT EXISTS (
        SELECT 1
        FROM FuncionRol fr
        WHERE fr.IdFuncion = f.Id
          AND fr.IdRol     = @SuperAdminRoleId
      );

---------------------------------------------------------
-- 2) Crear una función "genérica por controlador"
--    (Action = NULL) para cada Controller que no la tenga
---------------------------------------------------------
DECLARE @MaxId INT;
SELECT @MaxId = ISNULL(MAX(Id), 0) FROM Funcion;

IF OBJECT_ID('tempdb..#Controllers') IS NOT NULL
    DROP TABLE #Controllers;

SELECT DISTINCT
       f.Controller,
       ROW_NUMBER() OVER (ORDER BY f.Controller) AS RowNum
INTO #Controllers
FROM Funcion f
WHERE NOT EXISTS (
        SELECT 1
        FROM Funcion f2
        WHERE f2.Controller = f.Controller
          AND f2.[Action] IS NULL
      );

-- Insertamos las funciones genéricas
INSERT INTO Funcion (Id, Controller, [Action], PorOperador, Descripcion)
SELECT @MaxId + RowNum             AS Id,
       Controller,
       NULL                        AS [Action],
       0                           AS PorOperador,
       Controller + ' - Acceso general' AS Descripcion
FROM #Controllers;

---------------------------------------------------------
-- 3) Dar SUPERADMIN también a esas nuevas funciones genéricas
--    y a cualquier otra que haya quedado sin asignar
---------------------------------------------------------
INSERT INTO FuncionRol (IdFuncion, IdRol)
SELECT f.Id, @SuperAdminRoleId
FROM Funcion f
WHERE NOT EXISTS (
        SELECT 1
        FROM FuncionRol fr
        WHERE fr.IdFuncion = f.Id
          AND fr.IdRol     = @SuperAdminRoleId
      );
