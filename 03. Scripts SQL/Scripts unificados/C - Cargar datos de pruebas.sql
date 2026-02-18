USE BugsDev;
GO

SET NOCOUNT ON;

/* ============================================================
   Script C - Cargar datos de pruebas (unificado, idempotente)
   Reglas:
   - Sin limpieza (no DELETE/TRUNCATE/DROP/DBCC reseed)
   - Sin SQL dinámico
   - Idempotente por PK o clave natural según corresponda
   ============================================================ */

/* ------------------------------------------------------------
   0) IDs y constantes base (tomados de scripts históricos)
   ------------------------------------------------------------ */
DECLARE @RolSuperAdminId NVARCHAR(128) = N'2f5b0ce3-3ef4-4837-b4f3-3d2ed72f9486';
DECLARE @AdminUsuarioId UNIQUEIDENTIFIER = '0235532B-F4D8-4F39-ABA9-4C5E5CDA1EE7';
DECLARE @AdminAspNetId NVARCHAR(128) = N'10000000-0000-0000-0000-000000000001';
DECLARE @AdminEmail NVARCHAR(256) = N'jnahuel.developer@gmail.com';
DECLARE @AdminPasswordHash NVARCHAR(MAX) = N'AFe7ZzniG8g/tZuG7jF+0JTqll4otxupK7p38wh1Y28RMDzWd6AkTzbvCabk1Y2FBw==';
DECLARE @AdminSecurityStamp NVARCHAR(128) = N'seed-security-stamp-0001';

DECLARE @OperadorDarioId UNIQUEIDENTIFIER = '11111111-1111-1111-1111-111111111111';
DECLARE @OperadorErnestoId UNIQUEIDENTIFIER = '22222222-2222-2222-2222-222222222222';

DECLARE @LocacionDevCentralId UNIQUEIDENTIFIER = '33333333-3333-3333-3333-333333333333';
DECLARE @LocacionDevSecundariaId UNIQUEIDENTIFIER = '33333333-3333-3333-3333-333333333334';

DECLARE @JerarquiaDevCentralId UNIQUEIDENTIFIER = '44444444-4444-4444-4444-444444444444';
DECLARE @JerarquiaDevSecundariaId UNIQUEIDENTIFIER = '44444444-4444-4444-4444-444444444445';

DECLARE @ModeloTerminalBaseId UNIQUEIDENTIFIER = '55555555-5555-5555-5555-555555555555';
DECLARE @TransaccionTextoBaseId UNIQUEIDENTIFIER = '66666666-6666-6666-6666-666666666666';

DECLARE @Terminal1Id UNIQUEIDENTIFIER = '77777777-7777-7777-7777-777777777777';
DECLARE @Terminal2Id UNIQUEIDENTIFIER = '77777777-7777-7777-7777-777777777772';
DECLARE @Terminal3Id UNIQUEIDENTIFIER = '77777777-7777-7777-7777-777777777773';

DECLARE @Maquina1Id UNIQUEIDENTIFIER = '88888888-8888-8888-8888-888888888888';
DECLARE @Maquina2Id UNIQUEIDENTIFIER = '88888888-8888-8888-8888-888888888882';
DECLARE @Maquina3Id UNIQUEIDENTIFIER = '88888888-8888-8888-8888-888888888883';

DECLARE @MarcaModeloId UNIQUEIDENTIFIER = 'ABABABAB-1111-2222-3333-444444444444';
DECLARE @TipoProductoId UNIQUEIDENTIFIER = 'CDCDCDCD-1111-2222-3333-444444444444';

DECLARE @UsuarioOperadorAId UNIQUEIDENTIFIER = '99999999-9999-9999-9999-999999999991';
DECLARE @UsuarioConsumidor2Id UNIQUEIDENTIFIER = '99999999-9999-9999-9999-999999999992';

DECLARE @TransaccionId UNIQUEIDENTIFIER = 'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAA1';
DECLARE @TransaccionMalId UNIQUEIDENTIFIER = 'B1B1B1B1-1111-2222-3333-444444444444';

DECLARE @TipoMovimientoNuevoId UNIQUEIDENTIFIER = 'A1A1A1A1-0000-0000-0000-000000000001';
DECLARE @TipoMovimientoReposicionId UNIQUEIDENTIFIER = 'A1A1A1A1-0000-0000-0000-000000000002';
DECLARE @ArticuloId UNIQUEIDENTIFIER = 'D1D1D1D1-1111-2222-3333-444444444444';
DECLARE @ArticuloAsignacionId UNIQUEIDENTIFIER = 'E1E1E1E1-1111-2222-3333-444444444444';
DECLARE @StockId UNIQUEIDENTIFIER = 'F1F1F1F1-1111-2222-3333-444444444444';
DECLARE @StockHistoricoId UNIQUEIDENTIFIER = 'F2F2F2F2-1111-2222-3333-444444444444';

DECLARE @EstadoFinAcreditadoId INT;
DECLARE @EstadoTxTerminadoOkId INT;

DECLARE @AspNetAdminExistenteId NVARCHAR(128);

/* ------------------------------------------------------------
   1) AspNetRoles (SuperAdmin)
   ------------------------------------------------------------ */
IF NOT EXISTS (SELECT 1 FROM AspNetRoles WHERE [Name] = N'SuperAdmin')
BEGIN
    INSERT INTO AspNetRoles (Id, [Name], [Weight])
    VALUES (@RolSuperAdminId, N'SuperAdmin', 1000);
END

SELECT TOP 1 @RolSuperAdminId = Id
FROM AspNetRoles
WHERE [Name] = N'SuperAdmin';

/* ------------------------------------------------------------
   2) Operador / Locacion / Jerarquia
   ------------------------------------------------------------ */
IF NOT EXISTS (SELECT 1 FROM Operador WHERE OperadorID = @OperadorDarioId)
BEGIN
    INSERT INTO Operador (OperadorID, Nombre, Numero, TiempoAvisoInhibicion, TiempoAvisoConexion, ClientId, SecretToken, AccessToken)
    VALUES (@OperadorDarioId, N'Dario Conca', 101, 10, 10, NULL, N'DEV-OP-101', N'ACCESS-OP-101');
END

IF NOT EXISTS (SELECT 1 FROM Operador WHERE OperadorID = @OperadorErnestoId)
BEGIN
    INSERT INTO Operador (OperadorID, Nombre, Numero, TiempoAvisoInhibicion, TiempoAvisoConexion, ClientId, SecretToken, AccessToken)
    VALUES (@OperadorErnestoId, N'Ernesto Perez', 102, 10, 10, NULL, N'DEV-OP-102', N'ACCESS-OP-102');
END

IF NOT EXISTS (SELECT 1 FROM Locacion WHERE LocacionID = @LocacionDevCentralId)
BEGIN
    INSERT INTO Locacion
        (LocacionID, Nombre, CUIT, Direccion, Localidad, CodigoPostal, Provincia,
         NombreZona1, NombreZona2, NombreZona3, NombreZona4, NombreZona5,
         MostrarUsuario, SaludarUsuario, Numero, OperadorID)
    VALUES
        (@LocacionDevCentralId, N'Locación Dev Central', N'20123456789', N'Av. Siempre Viva 123',
         N'Buenos Aires', N'C1000', N'Buenos Aires', N'Zona 1', N'Zona 2', N'Zona 3', N'Zona 4', N'Zona 5',
         1, 1, 1, @OperadorDarioId);
END

IF NOT EXISTS (SELECT 1 FROM Locacion WHERE LocacionID = @LocacionDevSecundariaId)
BEGIN
    INSERT INTO Locacion
        (LocacionID, Nombre, CUIT, Direccion, Localidad, CodigoPostal, Provincia,
         NombreZona1, NombreZona2, NombreZona3, NombreZona4, NombreZona5,
         MostrarUsuario, SaludarUsuario, Numero, OperadorID)
    VALUES
        (@LocacionDevSecundariaId, N'Locación Dev Secundaria', N'20987654321', N'Calle Falsa 456',
         N'Buenos Aires', N'C2000', N'Buenos Aires', N'Zona 1', N'Zona 2', N'Zona 3', N'Zona 4', N'Zona 5',
         1, 1, 2, @OperadorErnestoId);
END

IF NOT EXISTS (SELECT 1 FROM Jerarquia WHERE JerarquiaID = @JerarquiaDevCentralId)
BEGIN
    INSERT INTO Jerarquia
        (JerarquiaID, Nombre,
         RecargaZona1, RecargaZona2, RecargaZona3, RecargaZona4, RecargaZona5,
         DescuentoPorcentualZona1, DescuentoPorcentualZona2, DescuentoPorcentualZona3, DescuentoPorcentualZona4, DescuentoPorcentualZona5,
         MontoRecorteZona1, MontoRecorteZona2, MontoRecorteZona3, MontoRecorteZona4, MontoRecorteZona5,
         PeriodoRecargaZona1, PeriodoRecargaZona2, PeriodoRecargaZona3, PeriodoRecargaZona4, PeriodoRecargaZona5,
         LocacionID)
    VALUES
        (@JerarquiaDevCentralId, N'Jerarquía General Dev',
         100,100,100,100,100,
         0,0,0,0,0,
         0,0,0,0,0,
         30,30,30,30,30,
         @LocacionDevCentralId);
END

IF NOT EXISTS (SELECT 1 FROM Jerarquia WHERE JerarquiaID = @JerarquiaDevSecundariaId)
BEGIN
    INSERT INTO Jerarquia
        (JerarquiaID, Nombre,
         RecargaZona1, RecargaZona2, RecargaZona3, RecargaZona4, RecargaZona5,
         DescuentoPorcentualZona1, DescuentoPorcentualZona2, DescuentoPorcentualZona3, DescuentoPorcentualZona4, DescuentoPorcentualZona5,
         MontoRecorteZona1, MontoRecorteZona2, MontoRecorteZona3, MontoRecorteZona4, MontoRecorteZona5,
         PeriodoRecargaZona1, PeriodoRecargaZona2, PeriodoRecargaZona3, PeriodoRecargaZona4, PeriodoRecargaZona5,
         LocacionID)
    VALUES
        (@JerarquiaDevSecundariaId, N'Jerarquía General Dev Secundaria',
         120,120,120,120,120,
         5,5,5,5,5,
         0,0,0,0,0,
         30,30,30,30,30,
         @LocacionDevSecundariaId);
END

/* ------------------------------------------------------------
   3) Catálogos (MarcaModelo, TipoProducto, ModeloTerminal, TransaccionTexto)
   ------------------------------------------------------------ */
IF NOT EXISTS (SELECT 1 FROM MarcaModelo WHERE MarcaModeloID = @MarcaModeloId)
BEGIN
    INSERT INTO MarcaModelo (MarcaModeloID, MarcaModeloNombre)
    VALUES (@MarcaModeloId, N'MarcaModelo - Pruebas');
END

IF NOT EXISTS (SELECT 1 FROM TipoProducto WHERE TipoProductoID = @TipoProductoId)
BEGIN
    INSERT INTO TipoProducto (TipoProductoID, Nombre)
    VALUES (@TipoProductoId, N'Snacks y Bebidas - Pruebas');
END

IF NOT EXISTS (SELECT 1 FROM ModeloTerminal WHERE ModeloTerminalID = @ModeloTerminalBaseId)
BEGIN
    INSERT INTO ModeloTerminal (ModeloTerminalID, Modelo)
    VALUES (@ModeloTerminalBaseId, N'Modelo Terminal Genérico Dev');
END

IF NOT EXISTS (SELECT 1 FROM TransaccionTexto WHERE TransaccionTextoID = @TransaccionTextoBaseId)
BEGIN
    INSERT INTO TransaccionTexto
        (TransaccionTextoID, CodigoTransaccion, SumaEnVentas, SumaEnRecargas, SumaEnEfectivo, TextoTransaccion, ModeloTerminalID)
    VALUES
        (@TransaccionTextoBaseId, N'VT', 1, 0, 0, N'Venta estándar sistema VT', @ModeloTerminalBaseId);
END

/* ------------------------------------------------------------
   4) Terminal / Maquina
   Nota: NotasService = ExternalReference (BGSQR_0001/2/3)
   ------------------------------------------------------------ */
IF NOT EXISTS (SELECT 1 FROM Terminal WHERE TerminalID = @Terminal1Id)
BEGIN
    INSERT INTO Terminal
        (TerminalID, NumeroSerie, Interfaz, Version, FechaFabricacion, FechaEstadoSeteosEscritura, TipoLector_out,
         FechaAlta, MaquinaID, OperadorID, ModeloTerminalID, Perifericos, ModuloComunicacion, SimCard,
         NivelSenal1, NivelSenal2, NivelSenal3, FechaNivel1, FechaNivel2, FechaNivel3)
    VALUES
        (@Terminal1Id, 10001, N'TCP/IP', 1, GETDATE(), NULL, NULL,
         GETDATE(), NULL, @OperadorDarioId, @ModeloTerminalBaseId, NULL, N'Módulo 4G de pruebas', N'SIM-PRUEBA-0001',
         80, 75, 70, DATEADD(DAY,-3,GETDATE()), DATEADD(DAY,-2,GETDATE()), DATEADD(DAY,-1,GETDATE()));
END

IF NOT EXISTS (SELECT 1 FROM Terminal WHERE TerminalID = @Terminal2Id)
BEGIN
    INSERT INTO Terminal
        (TerminalID, NumeroSerie, Interfaz, Version, FechaFabricacion, FechaEstadoSeteosEscritura, TipoLector_out,
         FechaAlta, MaquinaID, OperadorID, ModeloTerminalID, Perifericos, ModuloComunicacion, SimCard,
         NivelSenal1, NivelSenal2, NivelSenal3, FechaNivel1, FechaNivel2, FechaNivel3)
    VALUES
        (@Terminal2Id, 10002, N'TCP/IP', 1, GETDATE(), NULL, NULL,
         GETDATE(), NULL, @OperadorDarioId, @ModeloTerminalBaseId, NULL, N'Módulo 4G de pruebas', N'SIM-PRUEBA-0002',
         80, 75, 70, DATEADD(DAY,-3,GETDATE()), DATEADD(DAY,-2,GETDATE()), DATEADD(DAY,-1,GETDATE()));
END

IF NOT EXISTS (SELECT 1 FROM Terminal WHERE TerminalID = @Terminal3Id)
BEGIN
    INSERT INTO Terminal
        (TerminalID, NumeroSerie, Interfaz, Version, FechaFabricacion, FechaEstadoSeteosEscritura, TipoLector_out,
         FechaAlta, MaquinaID, OperadorID, ModeloTerminalID, Perifericos, ModuloComunicacion, SimCard,
         NivelSenal1, NivelSenal2, NivelSenal3, FechaNivel1, FechaNivel2, FechaNivel3)
    VALUES
        (@Terminal3Id, 10003, N'TCP/IP', 1, GETDATE(), NULL, NULL,
         GETDATE(), NULL, @OperadorDarioId, @ModeloTerminalBaseId, NULL, N'Módulo 4G de pruebas', N'SIM-PRUEBA-0003',
         80, 75, 70, DATEADD(DAY,-3,GETDATE()), DATEADD(DAY,-2,GETDATE()), DATEADD(DAY,-1,GETDATE()));
END

IF NOT EXISTS (SELECT 1 FROM Maquina WHERE MaquinaID = @Maquina1Id)
BEGIN
    INSERT INTO Maquina
        (MaquinaID, FechaAviso, FechaEstado, AlarmaActiva, Zona, NumeroSerie, NombreAlias, Ubicacion, Estado, EstadoConexion,
         Mensaje, NotasService, ContadorVentasParcial, MontoVentasParcial, ContadorVentasHistorico, MontoVentasHistorico,
         FechaUltimoService, FechaUltimaRecaudacion, FechaUltimaReposicion, FechaUltimoOk, FechaUltimaConexion,
         TotalRecaudado, SoloVentaEfectivo, ValorVenta, Decimales, FactorEscala, TiempoSesion, CreditoMaximoCash,
         ValorChannelA, ValorChannelB, ValorChannelC, ValorChannelD, ValorChannelE, ValorChannelF,
         ValorBillete1, ValorBillete2, ValorBillete3, ValorBillete4, ValorBillete5, ValorBillete6,
         DescuentoPorcentual, LocacionID, MarcaModeloID, TerminalID, OperadorID, TipoProductoID)
    VALUES
        (@Maquina1Id, GETDATE(), GETDATE(), 0, 1, N'MQ-DEV-0001', N'MQ Dev 1', N'Lobby Sede Central', N'Operativa', N'Conectada',
         N'OK', N'BGSQR_0001', 0,0,0,0,
         NULL,NULL,NULL,NULL,GETDATE(),
         0, 0, 200, 2, 1, 60, 1000,
         10,20,50,100,200,500,
         10,20,50,100,200,500,
         0, @LocacionDevCentralId, @MarcaModeloId, @Terminal1Id, @OperadorDarioId, @TipoProductoId);
END

IF NOT EXISTS (SELECT 1 FROM Maquina WHERE MaquinaID = @Maquina2Id)
BEGIN
    INSERT INTO Maquina
        (MaquinaID, FechaAviso, FechaEstado, AlarmaActiva, Zona, NumeroSerie, NombreAlias, Ubicacion, Estado, EstadoConexion,
         Mensaje, NotasService, ContadorVentasParcial, MontoVentasParcial, ContadorVentasHistorico, MontoVentasHistorico,
         FechaUltimoService, FechaUltimaRecaudacion, FechaUltimaReposicion, FechaUltimoOk, FechaUltimaConexion,
         TotalRecaudado, SoloVentaEfectivo, ValorVenta, Decimales, FactorEscala, TiempoSesion, CreditoMaximoCash,
         ValorChannelA, ValorChannelB, ValorChannelC, ValorChannelD, ValorChannelE, ValorChannelF,
         ValorBillete1, ValorBillete2, ValorBillete3, ValorBillete4, ValorBillete5, ValorBillete6,
         DescuentoPorcentual, LocacionID, MarcaModeloID, TerminalID, OperadorID, TipoProductoID)
    VALUES
        (@Maquina2Id, GETDATE(), GETDATE(), 0, 1, N'MQ-DEV-0002', N'MQ Dev 2', N'Pasillo Sede Central', N'Operativa', N'Conectada',
         N'OK', N'BGSQR_0002', 0,0,0,0,
         NULL,NULL,NULL,NULL,GETDATE(),
         0, 0, 200, 2, 1, 60, 1000,
         10,20,50,100,200,500,
         10,20,50,100,200,500,
         0, @LocacionDevCentralId, @MarcaModeloId, @Terminal2Id, @OperadorDarioId, @TipoProductoId);
END

IF NOT EXISTS (SELECT 1 FROM Maquina WHERE MaquinaID = @Maquina3Id)
BEGIN
    INSERT INTO Maquina
        (MaquinaID, FechaAviso, FechaEstado, AlarmaActiva, Zona, NumeroSerie, NombreAlias, Ubicacion, Estado, EstadoConexion,
         Mensaje, NotasService, ContadorVentasParcial, MontoVentasParcial, ContadorVentasHistorico, MontoVentasHistorico,
         FechaUltimoService, FechaUltimaRecaudacion, FechaUltimaReposicion, FechaUltimoOk, FechaUltimaConexion,
         TotalRecaudado, SoloVentaEfectivo, ValorVenta, Decimales, FactorEscala, TiempoSesion, CreditoMaximoCash,
         ValorChannelA, ValorChannelB, ValorChannelC, ValorChannelD, ValorChannelE, ValorChannelF,
         ValorBillete1, ValorBillete2, ValorBillete3, ValorBillete4, ValorBillete5, ValorBillete6,
         DescuentoPorcentual, LocacionID, MarcaModeloID, TerminalID, OperadorID, TipoProductoID)
    VALUES
        (@Maquina3Id, GETDATE(), GETDATE(), 0, 1, N'MQ-DEV-0003', N'MQ Dev 3', N'Sala de reuniones', N'Operativa', N'Conectada',
         N'OK', N'BGSQR_0003', 0,0,0,0,
         NULL,NULL,NULL,NULL,GETDATE(),
         0, 0, 200, 2, 1, 60, 1000,
         10,20,50,100,200,500,
         10,20,50,100,200,500,
         0, @LocacionDevCentralId, @MarcaModeloId, @Terminal3Id, @OperadorDarioId, @TipoProductoId);
END

/* ------------------------------------------------------------
   5) Usuario (dominio) + consumidores mínimos
   ------------------------------------------------------------ */
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
        Recarga_CreditoInicialZona1, Recarga_CreditoInicialZona2, Recarga_CreditoInicialZona3, Recarga_CreditoInicialZona4, Recarga_CreditoInicialZona5,
        Recarga_CreditoIntermedioZona1, Recarga_CreditoIntermedioZona2, Recarga_CreditoIntermedioZona3, Recarga_CreditoIntermedioZona4, Recarga_CreditoIntermedioZona5,
        Recarga_CreditoFinalZona1, Recarga_CreditoFinalZona2, Recarga_CreditoFinalZona3, Recarga_CreditoFinalZona4, Recarga_CreditoFinalZona5,
        Recarga_EfectivoInicial, Recarga_EfectivoFinal, Recarga_RecargaTotalTeorica,
        EsServicioTecnico,
        OperadorID, LocacionID, JerarquiaID
    )
    VALUES
    (
        @AdminUsuarioId, N'Dev', N'Admin', N'ADM001', 12345678,
        1, 1234, NULL, GETDATE(),
        0, NULL, NULL,
        0,
        0,0,0,0,0,
        NULL,NULL,NULL,NULL,NULL,
        0,0,
        NULL,NULL,NULL,NULL,NULL,
        NULL,NULL,NULL,NULL,NULL,
        NULL,NULL,NULL,NULL,NULL,
        NULL,NULL,0,
        0,
        @OperadorDarioId, @LocacionDevCentralId, @JerarquiaDevCentralId
    );
END

UPDATE Usuario
SET OperadorID = @OperadorDarioId,
    LocacionID = @LocacionDevCentralId,
    JerarquiaID = @JerarquiaDevCentralId
WHERE UsuarioID = @AdminUsuarioId
  AND (OperadorID IS NULL OR LocacionID IS NULL OR JerarquiaID IS NULL);

IF NOT EXISTS (SELECT 1 FROM Usuario WHERE UsuarioID = @UsuarioOperadorAId)
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
        Recarga_RecargaTotalTeorica,
        EsServicioTecnico,
        OperadorID, LocacionID, JerarquiaID
    )
    VALUES
    (
        @UsuarioOperadorAId, N'Lopez', N'Juan', N'EMP001', 30123456,
        2001, 1111, DATEADD(YEAR,1,GETDATE()), GETDATE(),
        0, NULL, GETDATE(),
        0,
        0,0,0,0,0,
        NULL,NULL,NULL,NULL,NULL,
        0,0,
        0,
        0,
        @OperadorDarioId, @LocacionDevCentralId, @JerarquiaDevCentralId
    );
END

IF NOT EXISTS (SELECT 1 FROM Usuario WHERE UsuarioID = @UsuarioConsumidor2Id)
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
        Recarga_RecargaTotalTeorica,
        EsServicioTecnico,
        OperadorID, LocacionID, JerarquiaID
    )
    VALUES
    (
        @UsuarioConsumidor2Id, N'Garcia', N'Maria', N'EMP002', 30223456,
        2002, 2222, DATEADD(YEAR,1,GETDATE()), GETDATE(),
        0, NULL, GETDATE(),
        0,
        0,0,0,0,0,
        NULL,NULL,NULL,NULL,NULL,
        0,0,
        0,
        0,
        @OperadorDarioId, @LocacionDevCentralId, @JerarquiaDevCentralId
    );
END

/* ------------------------------------------------------------
   6) AspNetUsers + AspNetUserRoles
   ------------------------------------------------------------ */
SELECT TOP 1 @AspNetAdminExistenteId = Id
FROM AspNetUsers
WHERE Email = @AdminEmail;

IF @AspNetAdminExistenteId IS NULL
BEGIN
    INSERT INTO AspNetUsers
        (Id, UserName, Email, EmailConfirmed, PasswordHash, SecurityStamp,
         PhoneNumberConfirmed, TwoFactorEnabled, LockoutEnabled, AccessFailedCount, UsuarioID)
    VALUES
        (@AdminAspNetId, @AdminEmail, @AdminEmail, 1, @AdminPasswordHash, @AdminSecurityStamp,
         0, 0, 0, 0, @AdminUsuarioId);

    SET @AspNetAdminExistenteId = @AdminAspNetId;
END
ELSE
BEGIN
    UPDATE AspNetUsers
    SET UserName = @AdminEmail,
        Email = @AdminEmail,
        PasswordHash = @AdminPasswordHash
    WHERE Id = @AspNetAdminExistenteId;
END

IF NOT EXISTS (
    SELECT 1
    FROM AspNetUserRoles
    WHERE UserId = @AspNetAdminExistenteId
      AND RoleId = @RolSuperAdminId
)
BEGIN
    INSERT INTO AspNetUserRoles (UserId, RoleId)
    VALUES (@AspNetAdminExistenteId, @RolSuperAdminId);
END

/* ------------------------------------------------------------
   7) Funcion / FuncionRol / FuncionOperador
   ------------------------------------------------------------ */
DECLARE @Funciones TABLE
(
    Id INT PRIMARY KEY,
    Controller NVARCHAR(100),
    [Action] NVARCHAR(100),
    PorOperador BIT,
    Descripcion NVARCHAR(250)
);

INSERT INTO @Funciones (Id, Controller, [Action], PorOperador, Descripcion)
VALUES
(1,N'Locacion',N'Index',0,N'Permiso Locacion.Index (1)'),
(2,N'Usuario',N'Index',0,N'Permiso Usuario.Index (2)'),
(3,N'Maquina',N'Index',0,N'Permiso Maquina.Index (3)'),
(4,N'Terminal',N'Index',0,N'Permiso Terminal.Index (4)'),
(5,N'Transaccion',N'Index',0,N'Permiso Transaccion.Index (5)'),
(6,N'UsuarioWeb',N'Index',0,N'Permiso UsuarioWeb.Index (6)'),
(7,N'Articulo',N'Index',0,N'Permiso Articulo.Listado (7)'),
(8,N'Stock',N'Index',0,N'Permiso Stock.Index (8)'),
(9,N'Informes',N'Consumo',0,N'Permiso Informes.Consumo (9)'),
(10,N'Informes',N'Ventas',0,N'Permiso Informes.Ventas (10)'),
(11,N'Informes',N'CertificadoEntregaEpp',0,N'Permiso Informes.CertificadoEntregaEpp (11)'),
(12,N'Informes',N'EntregaEPPTrabajador',0,N'Permiso Informes.EntregaEPPTrabajador (12)'),
(13,N'Informes',N'EntregaTotalEPP',0,N'Permiso Informes.EntregaTotalEPP (13)'),
(14,N'Operador',N'Index',0,N'Permiso Operadores.Index (14)'),
(15,N'MarcaModelo',N'Index',0,N'Permiso ModelosMaquina.Index (15)'),
(16,N'ModeloTerminal',N'Index',0,N'Permiso ModeloTerminal.Index (16)'),
(17,N'TransaccionTexto',N'Index',0,N'Permiso TransaccionTexto.Index (17)'),
(18,N'Auditoria',N'Index',0,N'Permiso Auditoria.Index (18)'),
(19,N'Jerarquia',N'Index',0,N'Permiso Jerarquia.Index (19)'),
(20,N'ArticuloAsignacion',N'Index',0,N'Permiso Articulo.Asignacion (20)'),
(21,N'Stock',N'Reposiciones',0,N'Permiso Stock.Reposiciones (21)'),
(22,N'Terminal',N'Create',0,N'Permiso Terminal.Create (22)'),
(23,N'Terminal',N'Edit',0,N'Permiso Terminal.Update (23)'),
(24,N'Terminal',N'Delete',0,N'Permiso Terminal.Delete (24)'),
(25,N'Consumidor',N'Index',0,N'Permiso Consumidor.Index (25)'),
(27,N'Seguridad',N'Index',0,N'Permiso Seguridad.Seguridad (27)'),
(28,N'Alarma',N'Configuracion',0,N'Permiso Alarma.Configuracion (28)'),
(29,N'Consumidor',N'MiCuenta',0,N'Permiso Consumidor.MiCuenta (29)'),
(30,N'Locacion',N'Create',0,N'Permiso Locacion.Create (30)'),
(31,N'Locacion',N'Edit',0,N'Permiso Locacion.Update (31)'),
(32,N'Locacion',N'Delete',0,N'Permiso Locacion.Delete (32)'),
(33,N'Usuario',N'Create',0,N'Permiso Usuario.Create (33)'),
(34,N'Usuario',N'Edit',0,N'Permiso Usuario.Update (34)'),
(35,N'Usuario',N'Delete',0,N'Permiso Usuario.Delete (35)'),
(36,N'Usuario',N'CargaMasiva',0,N'Permiso Usuario.CargaMasiva (36)'),
(37,N'Maquina',N'Create',0,N'Permiso Maquina.Create (37)'),
(38,N'Maquina',N'Edit',0,N'Permiso Maquina.Update (38)'),
(39,N'Maquina',N'Delete',0,N'Permiso Maquina.Delete (39)'),
(40,N'UsuarioWeb',N'Create',0,N'Permiso UsuarioWeb.Create (40)'),
(41,N'UsuarioWeb',N'Edit',0,N'Permiso UsuarioWeb.Update (41)'),
(42,N'UsuarioWeb',N'Delete',0,N'Permiso UsuarioWeb.Delete (42)'),
(43,N'Articulo',N'Create',0,N'Permiso Articulo.Create (43)'),
(44,N'Articulo',N'Edit',0,N'Permiso Articulo.Update (44)'),
(45,N'Articulo',N'Delete',0,N'Permiso Articulo.Delete (45)'),
(46,N'ArticuloAsignacion',N'Create',0,N'Permiso Articulo.AsignacionCreate (46)'),
(47,N'ArticuloAsignacion',N'Edit',0,N'Permiso Articulo.AsignacionUpdate (47)'),
(48,N'ArticuloAsignacion',N'Delete',0,N'Permiso Articulo.AsignacionDelete (48)'),
(49,N'Jerarquia',N'Create',0,N'Permiso Jerarquia.Create (49)'),
(50,N'Jerarquia',N'Edit',0,N'Permiso Jerarquia.Update (50)'),
(51,N'Jerarquia',N'Delete',0,N'Permiso Jerarquia.Delete (51)'),
(52,N'Stock',N'Edit',0,N'Permiso Stock.Update (52)'),
(53,N'Stock',N'Delete',0,N'Permiso Stock.Delete (53)'),
(54,N'Transaccion',N'Delete',0,N'Permiso Transaccion.Delete (54)'),
(55,N'Transaccion',N'DeleteRange',0,N'Permiso Transaccion.DeleteRange (55)'),
(56,N'MercadoPago',N'Index',0,N'Permiso MercadoPago.Index (56)'),
(57,N'MercadoPago',N'Configure',0,N'Permiso ConfiguracionPagosExternos.Index (57)'),
(58,N'MercadoPago',N'Index',0,N'Permiso PagosExternos.Index (58)'),
(59,N'MercadoPago',N'DeleteRange',0,N'Permiso PagosExternos.DeleteRange (59)'),
(60,N'MercadoPago',N'Delete',0,N'Permiso PagosExternos.Delete (60)'),
(1001,N'Operador',N'GetAllOperadores',0,N'Permiso Operador.GetAllOperadores (1001)'),
(1002,N'Operador',N'SetOperadorID',0,N'Permiso Operador.SetOperadorID (1002)'),
(3000,N'Locacion',N'GetAllLocaciones',0,N'Permiso Locacion.GetAllLocaciones (3000)'),
(3001,N'Jerarquia',N'GetAllJerarquias',0,N'Permiso Jerarquia.GetAllJerarquias (3001)'),
(3002,N'Maquina',N'GetAllMaquinas',0,N'Permiso Maquina.GetAllMaquinas (3002)'),
(3003,N'Terminal',N'GetAllTerminales',0,N'Permiso Terminal.GetAllTerminales (3003)'),
(3004,N'Usuario',N'GetAllUsers',0,N'Permiso Usuario.GetAllUsers (3004)'),
(3005,N'Transaccion',N'GetAllTransacciones',0,N'Permiso Transaccion.GetAllTransacciones (3005)'),
(3006,N'Transaccion',N'GetAllTransaccionesMal',0,N'Permiso Transaccion.GetAllTransaccionesMal (3006)'),
(3007,N'MercadoPago',N'GetAllMercadoPagos',0,N'Permiso MercadoPago.GetAllMercadoPagos (3007)'),
(3008,N'Stock',N'GetAllStock',0,N'Permiso Stock.GetAllStock (3008)'),
(3009,N'StockHistorico',N'GetAllStockHistorico',0,N'Permiso StockHistorico.GetAllStockHistorico (3009)'),
(3010,N'Articulo',N'GetAllArticulos',0,N'Permiso Articulo.GetAllArticulos (3010)'),
(3011,N'ArticuloAsignacion',N'GetAllArticulosAsignaciones',0,N'Permiso ArticuloAsignacion.GetAllArticulosAsignaciones (3011)'),
(3012,N'ModeloTerminal',N'GetAllModelosTerminal',0,N'Permiso ModeloTerminal.GetAllModelosTerminal (3012)'),
(3013,N'MarcaModelo',N'GetAllMarcaModelos',0,N'Permiso MarcaModelo.GetAllMarcaModelos (3013)'),
(3014,N'Auditoria',N'GetAllAuditorias',0,N'Permiso Auditoria.GetAllAuditorias (3014)'),
(3015,N'TransaccionTexto',N'GetAllTransaccionesTextos',0,N'Permiso TransaccionTexto.GetAllTransaccionesTextos (3015)'),
(3016,N'UsuarioWeb',N'GetAllUsers',0,N'Permiso UsuarioWeb.GetAllUsers (3016)'),
(3017,N'Consumidor',N'GetAllConsumos',0,N'Permiso Consumidor.GetAllConsumos (3017)'),
(3018,N'Transaccion',N'GetAllGrupoTransaccionesMal',0,N'Permiso Transaccion.GetAllGrupoTransaccionesMal (3018)'),
(3019,N'Usuario',N'ClearSession',0,N'Permiso Usuario.ClearSession (3019)');

INSERT INTO Funcion (Id, Controller, [Action], PorOperador, Descripcion)
SELECT f.Id, f.Controller, f.[Action], f.PorOperador, f.Descripcion
FROM @Funciones f
WHERE NOT EXISTS (SELECT 1 FROM Funcion x WHERE x.Id = f.Id);

INSERT INTO FuncionRol (IdFuncion, IdRol)
SELECT f.Id, @RolSuperAdminId
FROM Funcion f
WHERE NOT EXISTS (
    SELECT 1
    FROM FuncionRol fr
    WHERE fr.IdFuncion = f.Id
      AND fr.IdRol = @RolSuperAdminId
);

INSERT INTO FuncionOperador (FuncionId, OperadorId)
SELECT f.Id, @OperadorDarioId
FROM Funcion f
WHERE NOT EXISTS (
    SELECT 1
    FROM FuncionOperador fo
    WHERE fo.FuncionId = f.Id
      AND fo.OperadorId = @OperadorDarioId
);

/* ------------------------------------------------------------
   8) Transaccion + TransaccionesMal
   ------------------------------------------------------------ */
IF NOT EXISTS (SELECT 1 FROM Transaccion WHERE TransaccionID = @TransaccionId)
BEGIN
    INSERT INTO Transaccion
        (TransaccionID, FechaAltaBase, FechaTransaccion, CodigoTransaccion,
         EfectivoInicial, EfectivoFinal,
         CreditoInicialZona1, CreditoFinalZona1,
         CreditoInicialZona2, CreditoFinalZona2,
         CreditoInicialZona3, CreditoFinalZona3,
         CreditoInicialZona4, CreditoFinalZona4,
         CreditoInicialZona5, CreditoFinalZona5,
         ValorVenta, ValorRecarga, DescuentoAplicado,
         UsuarioService, TransaccionOriginal, ValorRecorte,
         TransaccionTextoID, ArticuloID, ModeloTerminalID, TerminalID, MaquinaID,
         LocacionID, OperadorID, UsuarioID, JerarquiaID)
    VALUES
        (@TransaccionId, DATEADD(DAY,-1,GETDATE()), DATEADD(DAY,-1,GETDATE()), N'VT',
         0, 0,
         0, 100,
         0, 0,
         0, 0,
         0, 0,
         0, 0,
         100, 0, 0,
         0, N'VT-TEST-001', NULL,
         @TransaccionTextoBaseId, NULL, @ModeloTerminalBaseId, @Terminal1Id, @Maquina1Id,
         @LocacionDevCentralId, @OperadorDarioId, @UsuarioOperadorAId, @JerarquiaDevCentralId);
END

IF NOT EXISTS (SELECT 1 FROM TransaccionesMal WHERE IdTransaccionMal = @TransaccionMalId)
BEGIN
    INSERT INTO TransaccionesMal
        (IdTransaccionMal, TerminalID, Transaccion, FechaDescarga, Motivo, MaquinaID, LocacionID, OperadorID)
    VALUES
        (@TransaccionMalId, @Terminal1Id, N'TRX_MAL_2001_1', DATEADD(HOUR,-1,GETDATE()),
         N'Error simulado para pruebas de borrado', @Maquina1Id, @LocacionDevCentralId, @OperadorDarioId);
END

/* ------------------------------------------------------------
   9) Articulo / ArticuloAsignacion / Stock / StockHistorico
   ------------------------------------------------------------ */
IF NOT EXISTS (SELECT 1 FROM TipoDeMovimiento WHERE TipoDeMovimientoID = @TipoMovimientoNuevoId)
BEGIN
    INSERT INTO TipoDeMovimiento (TipoDeMovimientoID, Nombre, Descripcion)
    VALUES (@TipoMovimientoNuevoId, N'Nuevo', N'Alta inicial de stock');
END

IF NOT EXISTS (SELECT 1 FROM TipoDeMovimiento WHERE TipoDeMovimientoID = @TipoMovimientoReposicionId)
BEGIN
    INSERT INTO TipoDeMovimiento (TipoDeMovimientoID, Nombre, Descripcion)
    VALUES (@TipoMovimientoReposicionId, N'Reposición', N'Reposición de stock');
END

IF NOT EXISTS (SELECT 1 FROM Articulo WHERE ArticuloID = @ArticuloId)
BEGIN
    INSERT INTO Articulo (ArticuloID, Nombre, CostoReal, UnidadMedida, Marca, Modelo, Certificacion, OperadorID)
    VALUES (@ArticuloId, N'Producto A1', 100.00, 1, N'Marca Prueba', N'Modelo Prueba', N'Cert A', @OperadorDarioId);
END

IF NOT EXISTS (SELECT 1 FROM ArticuloAsignacion WHERE Id = @ArticuloAsignacionId)
BEGIN
    INSERT INTO ArticuloAsignacion
        (Id, ArticuloID, LocacionID, NroZona, MaquinaID, Precio, AlarmaBajo, AlarmaMuyBajo, Capacidad, AlarmaActiva, ControlStock)
    VALUES
        (@ArticuloAsignacionId, @ArticuloId, @LocacionDevCentralId, 1, @Maquina1Id, 150.00, 5, 2, 20, 1, 1);
END

UPDATE ArticuloAsignacion
SET ControlStock = 1
WHERE Id = @ArticuloAsignacionId
  AND ControlStock <> 1;

IF NOT EXISTS (SELECT 1 FROM Stock WHERE StockID = @StockId)
BEGIN
    INSERT INTO Stock
        (StockID, Cantidad, ArticuloAsignacionID, FechaAviso, FechaEdicionWeb, UsuarioIDEdicionWeb, FechaEdicionVT)
    VALUES
        (@StockId, 12, @ArticuloAsignacionId, DATEADD(HOUR,-4,GETDATE()), DATEADD(HOUR,-3,GETDATE()), @UsuarioOperadorAId, DATEADD(HOUR,-2,GETDATE()));
END

IF NOT EXISTS (SELECT 1 FROM StockHistorico WHERE StockHistoricoID = @StockHistoricoId)
BEGIN
    INSERT INTO StockHistorico
        (StockHistoricoID, StockID, TipoDeMovimientoID, Fecha, UsuarioID, Cantidad, FechaAviso)
    VALUES
        (@StockHistoricoId, @StockId, @TipoMovimientoReposicionId, DATEADD(HOUR,-2,GETDATE()), @UsuarioOperadorAId, 3, DATEADD(HOUR,-4,GETDATE()));
END

/* ------------------------------------------------------------
   10) MercadoPagoEstado* + MercadoPagoTable + MercadoPagoOperacionMixta
   ------------------------------------------------------------ */
IF NOT EXISTS (SELECT 1 FROM MercadoPagoEstadoFinanciero WHERE Descripcion = N'DEVUELTO')
    INSERT INTO MercadoPagoEstadoFinanciero (Descripcion) VALUES (N'DEVUELTO');
IF NOT EXISTS (SELECT 1 FROM MercadoPagoEstadoFinanciero WHERE Descripcion = N'ACREDITADO')
    INSERT INTO MercadoPagoEstadoFinanciero (Descripcion) VALUES (N'ACREDITADO');
IF NOT EXISTS (SELECT 1 FROM MercadoPagoEstadoFinanciero WHERE Descripcion = N'AVISO_FALLIDO')
    INSERT INTO MercadoPagoEstadoFinanciero (Descripcion) VALUES (N'AVISO_FALLIDO');
IF NOT EXISTS (SELECT 1 FROM MercadoPagoEstadoFinanciero WHERE Descripcion = N'NO_PROCESABLE')
    INSERT INTO MercadoPagoEstadoFinanciero (Descripcion) VALUES (N'NO_PROCESABLE');

IF NOT EXISTS (SELECT 1 FROM MercadoPagoEstadoTransmision WHERE Descripcion = N'EN_PROCESO')
    INSERT INTO MercadoPagoEstadoTransmision (Descripcion) VALUES (N'EN_PROCESO');
IF NOT EXISTS (SELECT 1 FROM MercadoPagoEstadoTransmision WHERE Descripcion = N'TERMINADO_OK')
    INSERT INTO MercadoPagoEstadoTransmision (Descripcion) VALUES (N'TERMINADO_OK');
IF NOT EXISTS (SELECT 1 FROM MercadoPagoEstadoTransmision WHERE Descripcion = N'TERMINADO_MAL')
    INSERT INTO MercadoPagoEstadoTransmision (Descripcion) VALUES (N'TERMINADO_MAL');
IF NOT EXISTS (SELECT 1 FROM MercadoPagoEstadoTransmision WHERE Descripcion = N'ERROR_CONEXION')
    INSERT INTO MercadoPagoEstadoTransmision (Descripcion) VALUES (N'ERROR_CONEXION');
IF NOT EXISTS (SELECT 1 FROM MercadoPagoEstadoTransmision WHERE Descripcion = N'NO_PROCESABLE')
    INSERT INTO MercadoPagoEstadoTransmision (Descripcion) VALUES (N'NO_PROCESABLE');

SELECT TOP 1 @EstadoFinAcreditadoId = Id
FROM MercadoPagoEstadoFinanciero
WHERE Descripcion = N'ACREDITADO'
ORDER BY Id;

SELECT TOP 1 @EstadoTxTerminadoOkId = Id
FROM MercadoPagoEstadoTransmision
WHERE Descripcion = N'TERMINADO_OK'
ORDER BY Id;

IF NOT EXISTS (
    SELECT 1
    FROM MercadoPagoOperacionMixta
    WHERE OperadorId = @OperadorDarioId
      AND ExternalReference = N'BGSQR_0002'
)
BEGIN
    INSERT INTO MercadoPagoOperacionMixta
        (OperadorId, ExternalReference, FechaAuthorizedUtc, MontoAcumulado, ApprovedCount, PaymentId1, PaymentId2, Cerrada, FechaCierreUtc, FechaUltimaActualizacionUtc)
    VALUES
        (@OperadorDarioId, N'BGSQR_0002', DATEADD(MINUTE,-40,GETUTCDATE()), 500.00, 2, 91000001, 91000002, 1, DATEADD(MINUTE,-35,GETUTCDATE()), DATEADD(MINUTE,-35,GETUTCDATE()));
END

IF NOT EXISTS (
    SELECT 1
    FROM MercadoPagoOperacionMixta
    WHERE OperadorId = @OperadorErnestoId
      AND ExternalReference = N'BGSQR_0003'
)
BEGIN
    INSERT INTO MercadoPagoOperacionMixta
        (OperadorId, ExternalReference, FechaAuthorizedUtc, MontoAcumulado, ApprovedCount, PaymentId1, PaymentId2, Cerrada, FechaCierreUtc, FechaUltimaActualizacionUtc)
    VALUES
        (@OperadorErnestoId, N'BGSQR_0003', DATEADD(MINUTE,-8,GETUTCDATE()), 260.00, 1, 92000001, NULL, 0, NULL, DATEADD(MINUTE,-3,GETUTCDATE()));
END

IF NOT EXISTS (
    SELECT 1
    FROM MercadoPagoTable
    WHERE OperadorId = @OperadorDarioId
      AND MaquinaId = @Maquina1Id
      AND Comprobante = N'MP-SIMPLE-0001'
)
BEGIN
    INSERT INTO MercadoPagoTable
        (Fecha, Monto, MaquinaId, MercadoPagoEstadoFinancieroId, MercadoPagoEstadoTransmisionId,
         OperadorId, Comprobante, Descripcion, FechaModificacionEstadoTransmision, Entidad, UrlDevolucion, Reintentos)
    VALUES
        (DATEADD(HOUR,-6,GETDATE()), 350.00, @Maquina1Id, @EstadoFinAcreditadoId, @EstadoTxTerminadoOkId,
         @OperadorDarioId, N'MP-SIMPLE-0001', N'BGSQR_0001', GETDATE(), N'MP', NULL, 0);
END

IF NOT EXISTS (
    SELECT 1
    FROM MercadoPagoTable
    WHERE OperadorId = @OperadorDarioId
      AND MaquinaId = @Maquina2Id
      AND Comprobante = N'MP-MIXTO-CONSOL-0001'
)
BEGIN
    INSERT INTO MercadoPagoTable
        (Fecha, Monto, MaquinaId, MercadoPagoEstadoFinancieroId, MercadoPagoEstadoTransmisionId,
         OperadorId, Comprobante, Descripcion, FechaModificacionEstadoTransmision, Entidad, UrlDevolucion, Reintentos)
    VALUES
        (DATEADD(HOUR,-2,GETDATE()), 500.00, @Maquina2Id, @EstadoFinAcreditadoId, @EstadoTxTerminadoOkId,
         @OperadorDarioId, N'MP-MIXTO-CONSOL-0001', N'BGSQR_0002', GETDATE(), N'MP', NULL, 0);
END

PRINT 'Carga de pruebas finalizada correctamente.';
PRINT 'Operadores para SCOPED: 11111111-1111-1111-1111-111111111111 | 22222222-2222-2222-2222-222222222222';
PRINT 'Maquinas para SCOPED: 88888888-8888-8888-8888-888888888888 | 88888888-8888-8888-8888-888888888882 | 88888888-8888-8888-8888-888888888883';
PRINT 'ExternalReference: BGSQR_0001 | BGSQR_0002 | BGSQR_0003';
GO
