/*
Script B - Borrar todas las tablas de pruebas (sin dropear tablas)
Estrategia:
1) Deshabilita constraints en todas las tablas de usuario.
2) DELETE de todas las tablas de usuario.
3) Rehabilita constraints con validación (WITH CHECK CHECK).
4) Reseed de todas las tablas con identity a 0.

Notas:
- Excluye únicamente objetos del sistema (is_ms_shipped = 1).
- Incluye tablas AspNet* si están en la base.
- Reseed en 0: en identity 1,1 el próximo INSERT será 1.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRAN;

    DECLARE @SchemaName SYSNAME;
    DECLARE @TableName SYSNAME;
    DECLARE @FullName NVARCHAR(600);
    DECLARE @Sql NVARCHAR(MAX);

    DECLARE @Tablas TABLE
    (
        RowId INT IDENTITY(1,1) PRIMARY KEY,
        SchemaName SYSNAME,
        TableName SYSNAME,
        FullName NVARCHAR(600),
        HasIdentity BIT
    );

    INSERT INTO @Tablas (SchemaName, TableName, FullName, HasIdentity)
    SELECT
        s.name,
        t.name,
        QUOTENAME(s.name) + N'.' + QUOTENAME(t.name),
        CASE WHEN EXISTS (
            SELECT 1
            FROM sys.identity_columns ic
            WHERE ic.object_id = t.object_id
        ) THEN 1 ELSE 0 END
    FROM sys.tables t
    INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE t.is_ms_shipped = 0
    ORDER BY s.name, t.name;

    DECLARE @i INT = 1;
    DECLARE @n INT = (SELECT COUNT(*) FROM @Tablas);

    PRINT 'Paso 1/4 - Deshabilitando constraints...';
    WHILE @i <= @n
    BEGIN
        SELECT @FullName = FullName FROM @Tablas WHERE RowId = @i;
        SET @Sql = N'ALTER TABLE ' + @FullName + N' NOCHECK CONSTRAINT ALL;';
        PRINT '  NOCHECK: ' + @FullName;
        EXEC sp_executesql @Sql;
        SET @i += 1;
    END

    PRINT 'Paso 2/4 - Borrando datos...';
    SET @i = 1;
    WHILE @i <= @n
    BEGIN
        SELECT @FullName = FullName FROM @Tablas WHERE RowId = @i;
        SET @Sql = N'DELETE FROM ' + @FullName + N';';
        PRINT '  DELETE:  ' + @FullName;
        EXEC sp_executesql @Sql;
        SET @i += 1;
    END

    PRINT 'Paso 3/4 - Rehabilitando constraints con validación...';
    SET @i = 1;
    WHILE @i <= @n
    BEGIN
        SELECT @FullName = FullName FROM @Tablas WHERE RowId = @i;
        SET @Sql = N'ALTER TABLE ' + @FullName + N' WITH CHECK CHECK CONSTRAINT ALL;';
        PRINT '  CHECK:   ' + @FullName;
        EXEC sp_executesql @Sql;
        SET @i += 1;
    END

    PRINT 'Paso 4/4 - Reseed de identidades (RESEED, 0)...';
    SET @i = 1;
    WHILE @i <= @n
    BEGIN
        SELECT @FullName = FullName FROM @Tablas WHERE RowId = @i;

        IF EXISTS (
            SELECT 1 FROM @Tablas WHERE RowId = @i AND HasIdentity = 1
        )
        BEGIN
            SET @Sql = N'DBCC CHECKIDENT (''' + @FullName + N''', RESEED, 0) WITH NO_INFOMSGS;';
            PRINT '  RESEED:  ' + @FullName;
            EXEC sp_executesql @Sql;
        END

        SET @i += 1;
    END

    COMMIT;
    PRINT 'Limpieza finalizada correctamente.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK;

    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrNum INT = ERROR_NUMBER();
    DECLARE @ErrState INT = ERROR_STATE();

    RAISERROR('Error en script B (%d): %s', 16, 1, @ErrNum, @Err);
END CATCH;
