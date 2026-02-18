USE BugsDev;
GO

/* ============================================================
   SEED MÍNIMO PARA PRUEBAS MP (Simulador)
   - Crea/actualiza Operador Numero=5 con AccessToken NO nulo
   - Selecciona una Maquina existente (preferente 8888...) y:
       * la asigna al Operador
       * la vincula a una Locacion del Operador (si existe)
       * setea NotasService = ExternalReference (clave para resolver máquina)
   ============================================================ */

DECLARE @NumeroOperador INT = 5;
DECLARE @OperadorId UNIQUEIDENTIFIER = '55555555-5555-5555-5555-555555555555';

-- CAMBIAR SEGÚN PRUEBA:
-- SIMPLE:  BGSQR_SIMPLE_01
-- MIXTO:   BGSQR_05500
DECLARE @ExternalReference NVARCHAR(200) = N'BGSQR_SIMPLE_01';

DECLARE @MaquinaPreferida UNIQUEIDENTIFIER = '88888888-8888-8888-8888-888888888888';
DECLARE @MaquinaId UNIQUEIDENTIFIER = NULL;

PRINT '== SEED MINIMO MP ==';
PRINT 'Operador Numero=' + CAST(@NumeroOperador AS NVARCHAR(10));
PRINT 'ExternalReference=' + @ExternalReference;

------------------------------------------------------------
-- 1) Operador Numero=5 (AccessToken debe ser NO NULL)
------------------------------------------------------------
IF EXISTS (SELECT 1 FROM dbo.Operador WHERE Numero = @NumeroOperador)
BEGIN
    UPDATE dbo.Operador
    SET AccessToken = ISNULL(AccessToken, 'SIMULATED_ACCESS_TOKEN'),
        Nombre = ISNULL(Nombre, 'Operador Simulado'),
        SecretToken = ISNULL(SecretToken, 'DEV-OP-5')
    WHERE Numero = @NumeroOperador;

    SELECT @OperadorId = OperadorID FROM dbo.Operador WHERE Numero = @NumeroOperador;
    PRINT 'Operador existente actualizado. OperadorID=' + CONVERT(NVARCHAR(36), @OperadorId);
END
ELSE
BEGIN
    INSERT INTO dbo.Operador
        (OperadorID, Nombre, Numero, TiempoAvisoInhibicion, TiempoAvisoConexion, ClientId, SecretToken, AccessToken)
    VALUES
        (@OperadorId, 'Operador Simulado', @NumeroOperador, 10, 10, NULL, 'DEV-OP-5', 'SIMULATED_ACCESS_TOKEN');

    PRINT 'Operador creado. OperadorID=' + CONVERT(NVARCHAR(36), @OperadorId);
END

------------------------------------------------------------
-- 2) Resolver Maquina (preferente 8888..., si no TOP 1)
------------------------------------------------------------
IF EXISTS (SELECT 1 FROM dbo.Maquina WHERE MaquinaID = @MaquinaPreferida)
BEGIN
    SET @MaquinaId = @MaquinaPreferida;
END
ELSE
BEGIN
    SELECT TOP 1 @MaquinaId = MaquinaID FROM dbo.Maquina ORDER BY MaquinaID;
END

IF @MaquinaId IS NULL
BEGIN
    RAISERROR('No existe ninguna Maquina en la base. Ejecutar primero tus scripts de Infraestructura VT.', 16, 1);
    RETURN;
END

PRINT 'Maquina seleccionada=' + CONVERT(NVARCHAR(36), @MaquinaId);

------------------------------------------------------------
-- 3) Resolver Locacion del Operador (si hay), si no dejar NULL
------------------------------------------------------------
DECLARE @LocacionId UNIQUEIDENTIFIER = NULL;

SELECT TOP 1 @LocacionId = LocacionID
FROM dbo.Locacion
WHERE OperadorID = @OperadorId
ORDER BY Numero;

-- Si no hay locación del operador, intentamos tomar cualquiera existente (opcional)
IF @LocacionId IS NULL
BEGIN
    SELECT TOP 1 @LocacionId = LocacionID FROM dbo.Locacion ORDER BY Numero;
END

PRINT 'Locacion seleccionada=' + ISNULL(CONVERT(NVARCHAR(36), @LocacionId), 'NULL');

------------------------------------------------------------
-- 4) Actualizar Maquina para que sea resoluble por ExternalReference
------------------------------------------------------------
UPDATE dbo.Maquina
SET OperadorID = @OperadorId,
    LocacionID = @LocacionId,
    NotasService = @ExternalReference
WHERE MaquinaID = @MaquinaId;

PRINT 'Maquina actualizada: OperadorID, LocacionID, NotasService=ExternalReference';

------------------------------------------------------------
-- 5) Mostrar resumen
------------------------------------------------------------
SELECT 
    o.OperadorID, o.Numero, o.Nombre, o.AccessToken, o.SecretToken
FROM dbo.Operador o
WHERE o.OperadorID = @OperadorId;

SELECT
    m.MaquinaID, m.OperadorID, m.LocacionID, m.NotasService, m.NombreAlias, m.NumeroSerie
FROM dbo.Maquina m
WHERE m.MaquinaID = @MaquinaId;

GO
