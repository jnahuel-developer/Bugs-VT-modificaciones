USE BugsDev;
GO
/* ============================================================
   DATOS MÍNIMOS PARA PRUEBAS MP (SIMULADOR)
   - Asegura AccessToken no nulo en el Operador (requisito del flujo)
   - Asegura Maquina.NotasService para resolver external_reference
   - Crea/ajusta 2 external_reference:
       * Mixto:  BGSQR_05500
       * Simple: BGSQR_SIMPLE_01
   ============================================================ */

-----------------------------
-- 1) CONFIGURACIÓN
-----------------------------
DECLARE @OperadorNumero INT = 101; -- <-- Usar el número real del operador en tu DB (ej: 101 de tus scripts).
DECLARE @OperadorNombre NVARCHAR(200) = N'Operador Pruebas MP';
DECLARE @OperadorAccessToken NVARCHAR(500) = N'SIMULATED_ACCESS_TOKEN'; -- no debe ser NULL (aunque uses simulador)
DECLARE @OperadorSecretToken NVARCHAR(200) = N'DEV-OP-MP-101'; -- opcional, por si luego usás APIs por X-Api-Key

DECLARE @ExtRefMixto  NVARCHAR(200) = N'BGSQR_05500';
DECLARE @ExtRefSimple NVARCHAR(200) = N'BGSQR_SIMPLE_01';

-----------------------------
-- 2) LOOKUPS (si hicieran falta)
-----------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.MercadoPagoEstadoFinanciero WHERE Id = 4)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.MercadoPagoEstadoFinanciero WHERE Id = 1) INSERT INTO dbo.MercadoPagoEstadoFinanciero (Id, Descripcion) VALUES (1, N'DEVUELTO');
    IF NOT EXISTS (SELECT 1 FROM dbo.MercadoPagoEstadoFinanciero WHERE Id = 2) INSERT INTO dbo.MercadoPagoEstadoFinanciero (Id, Descripcion) VALUES (2, N'ACREDITADO');
    IF NOT EXISTS (SELECT 1 FROM dbo.MercadoPagoEstadoFinanciero WHERE Id = 3) INSERT INTO dbo.MercadoPagoEstadoFinanciero (Id, Descripcion) VALUES (3, N'AVISO_FALLIDO');
    IF NOT EXISTS (SELECT 1 FROM dbo.MercadoPagoEstadoFinanciero WHERE Id = 4) INSERT INTO dbo.MercadoPagoEstadoFinanciero (Id, Descripcion) VALUES (4, N'NO_PROCESABLE');
END

IF NOT EXISTS (SELECT 1 FROM dbo.MercadoPagoEstadoTransmision WHERE Id = 5)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.MercadoPagoEstadoTransmision WHERE Id = 1) INSERT INTO dbo.MercadoPagoEstadoTransmision (Id, Descripcion) VALUES (1, N'EN_PROCESO');
    IF NOT EXISTS (SELECT 1 FROM dbo.MercadoPagoEstadoTransmision WHERE Id = 2) INSERT INTO dbo.MercadoPagoEstadoTransmision (Id, Descripcion) VALUES (2, N'TERMINADO_OK');
    IF NOT EXISTS (SELECT 1 FROM dbo.MercadoPagoEstadoTransmision WHERE Id = 3) INSERT INTO dbo.MercadoPagoEstadoTransmision (Id, Descripcion) VALUES (3, N'TERMINADO_MAL');
    IF NOT EXISTS (SELECT 1 FROM dbo.MercadoPagoEstadoTransmision WHERE Id = 4) INSERT INTO dbo.MercadoPagoEstadoTransmision (Id, Descripcion) VALUES (4, N'ERROR_CONEXION');
    IF NOT EXISTS (SELECT 1 FROM dbo.MercadoPagoEstadoTransmision WHERE Id = 5) INSERT INTO dbo.MercadoPagoEstadoTransmision (Id, Descripcion) VALUES (5, N'NO_PROCESABLE');
END

-----------------------------
-- 3) OPERADOR (crear o ajustar)
-----------------------------
DECLARE @OperadorId UNIQUEIDENTIFIER;

SELECT @OperadorId = OperadorID
FROM dbo.Operador
WHERE Numero = @OperadorNumero;

IF @OperadorId IS NULL
BEGIN
    SET @OperadorId = NEWID();
    INSERT INTO dbo.Operador (OperadorID, Nombre, Numero, TiempoAvisoInhibicion, TiempoAvisoConexion, ClientId, SecretToken, AccessToken)
    VALUES (@OperadorId, @OperadorNombre, @OperadorNumero, 10, 10, NULL, @OperadorSecretToken, @OperadorAccessToken);
END
ELSE
BEGIN
    -- Asegurar AccessToken no NULL
    UPDATE dbo.Operador
    SET
        Nombre = COALESCE(Nombre, @OperadorNombre),
        AccessToken = COALESCE(AccessToken, @OperadorAccessToken),
        SecretToken = COALESCE(SecretToken, @OperadorSecretToken)
    WHERE OperadorID = @OperadorId;
END

-----------------------------
-- 4) MAQUINAS (ajustar 1 y asegurar una 2da si hace falta)
-----------------------------
DECLARE @MaquinaMixtaId UNIQUEIDENTIFIER;
DECLARE @MaquinaSimpleId UNIQUEIDENTIFIER;

-- Tomar 1ra máquina del operador (debería existir si ya corriste Infraestructura VT)
SELECT TOP (1) @MaquinaMixtaId = MaquinaID
FROM dbo.Maquina
WHERE OperadorID = @OperadorId
ORDER BY MaquinaID;

IF @MaquinaMixtaId IS NULL
BEGIN
    RAISERROR('No hay máquinas para el operador %d. Ejecutá primero el script de infraestructura (Maquina).', 16, 1, @OperadorNumero);
    RETURN;
END

-- Setear ExternalReference del MIXTO en esa máquina
UPDATE dbo.Maquina
SET
    NotasService = @ExtRefMixto,
    NombreAlias = COALESCE(NULLIF(NombreAlias, ''), N'MQ MP MIXTA')
WHERE MaquinaID = @MaquinaMixtaId;

-- Buscar otra máquina distinta para el SIMPLE
SELECT TOP (1) @MaquinaSimpleId = MaquinaID
FROM dbo.Maquina
WHERE OperadorID = @OperadorId
  AND MaquinaID <> @MaquinaMixtaId
ORDER BY MaquinaID;

IF @MaquinaSimpleId IS NULL
BEGIN
    -- No existe 2da máquina: clonar la primera (dinámico, para no depender de columnas NOT NULL)
    DECLARE @NewMaquinaId UNIQUEIDENTIFIER = NEWID();
    DECLARE @InsertCols NVARCHAR(MAX) = N'';
    DECLARE @SelectCols NVARCHAR(MAX) = N'';
    DECLARE @Sql NVARCHAR(MAX) = N'';

    ;WITH c AS (
        SELECT
            col.name,
            col.is_identity,
            col.is_computed,
            t.system_type_id
        FROM sys.columns col
        JOIN sys.types t ON col.user_type_id = t.user_type_id
        WHERE col.object_id = OBJECT_ID(N'dbo.Maquina')
    )
    SELECT
        @InsertCols = STRING_AGG(QUOTENAME(name), N','),
        @SelectCols = STRING_AGG(
            CASE
                WHEN name = 'MaquinaID' THEN N'@NewMaquinaId AS [MaquinaID]'
                ELSE QUOTENAME(name)
            END
        , N',')
    FROM c
    WHERE is_identity = 0
      AND is_computed = 0
      AND system_type_id <> 189; -- timestamp/rowversion

    SET @Sql = N'
        INSERT INTO dbo.Maquina (' + @InsertCols + N')
        SELECT ' + @SelectCols + N'
        FROM dbo.Maquina
        WHERE MaquinaID = @SourceMaquinaId;
    ';

    EXEC sp_executesql
        @Sql,
        N'@SourceMaquinaId UNIQUEIDENTIFIER, @NewMaquinaId UNIQUEIDENTIFIER',
        @SourceMaquinaId = @MaquinaMixtaId,
        @NewMaquinaId = @NewMaquinaId;

    SET @MaquinaSimpleId = @NewMaquinaId;

    -- Ajustes del clon para el SIMPLE
    UPDATE dbo.Maquina
    SET
        NotasService = @ExtRefSimple,
        NombreAlias = N'MQ MP SIMPLE'
    WHERE MaquinaID = @MaquinaSimpleId;
END
ELSE
BEGIN
    -- Ya existe 2da máquina: setear ExternalReference del SIMPLE
    UPDATE dbo.Maquina
    SET
        NotasService = @ExtRefSimple,
        NombreAlias = COALESCE(NULLIF(NombreAlias, ''), N'MQ MP SIMPLE')
    WHERE MaquinaID = @MaquinaSimpleId;
END

-----------------------------
-- 5) RESUMEN
-----------------------------
PRINT 'OK - Datos mínimos listos.';
SELECT OperadorID, Numero, Nombre, AccessToken, SecretToken
FROM dbo.Operador
WHERE OperadorID = @OperadorId;

SELECT MaquinaID, OperadorID, NombreAlias, NotasService
FROM dbo.Maquina
WHERE OperadorID = @OperadorId
  AND NotasService IN (@ExtRefMixto, @ExtRefSimple)
ORDER BY NotasService;
GO
