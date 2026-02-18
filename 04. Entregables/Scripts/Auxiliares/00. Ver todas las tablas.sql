USE BugsDev;
GO

SET NOCOUNT ON;

PRINT '==================== Usuarios ====================';
SELECT 
    UsuarioID,
    Numero,
    Nombre,
    Apellido,
    Dni,
    Legajo,
    OperadorID,
    LocacionID,
    JerarquiaID,
    FechaCreacion,
    Inhibido
FROM Usuario
ORDER BY Apellido, Nombre, Numero;

PRINT '==================== Operadores ====================';
SELECT 
    OperadorID,
    Numero,
    Nombre,
    TiempoAvisoInhibicion,
    TiempoAvisoConexion,
    SecretToken,
    AccessToken
FROM Operador
ORDER BY Numero;

PRINT '==================== Locaciones ====================';
SELECT
    LocacionID,
    Nombre,
    Numero,
    OperadorID,
    CUIT,
    Direccion,
    Localidad,
    CodigoPostal,
    Provincia
FROM Locacion
ORDER BY OperadorID, Numero;

PRINT '==================== Jerarquías ====================';
SELECT
    JerarquiaID,
    Nombre,
    LocacionID
FROM Jerarquia
ORDER BY LocacionID, Nombre;

PRINT '==================== Máquinas ====================';
SELECT 
    MaquinaID,
    NumeroSerie,
    NombreAlias,
    OperadorID,
    LocacionID,
    TerminalID,
    MarcaModeloID,
    TipoProductoID
FROM Maquina
ORDER BY OperadorID, LocacionID, NumeroSerie;

PRINT '==================== Terminales ====================';
SELECT 
    TerminalID,
    NumeroSerie,
    Interfaz,
    Version,
    OperadorID,
    ModeloTerminalID
FROM Terminal
ORDER BY OperadorID, NumeroSerie;

PRINT '==================== Transacciones ====================';
SELECT TOP 200
    TransaccionID,
    FechaTransaccion,
    CodigoTransaccion,
    ValorVenta,
    ValorRecarga,
    UsuarioID,
    LocacionID,
    OperadorID,
    MaquinaID,
    TerminalID,
    JerarquiaID
FROM Transaccion
ORDER BY FechaTransaccion DESC;

PRINT '==================== TransaccionesMal ====================';
SELECT TOP 200
    IdTransaccionMal,
    FechaDescarga,
    Motivo,
    LocacionID,
    OperadorID,
    MaquinaID,
    TerminalID
FROM TransaccionesMal
ORDER BY FechaDescarga DESC;

PRINT '==================== MercadoPagoTable ====================';
SELECT TOP 200
    MercadoPagoId,
    Fecha,
    Monto,
    MaquinaId,
    OperadorId,
    MercadoPagoEstadoFinancieroId,
    MercadoPagoEstadoTransmisionId,
    Reintentos
FROM MercadoPagoTable
ORDER BY Fecha DESC;

PRINT '==================== MercadoPagoOperacionMixta ====================';
SELECT TOP (200)
    MercadoPagoOperacionMixtaId,
    OperadorId,
    ExternalReference,
    FechaAuthorizedUtc,
    MontoAcumulado,
    ApprovedCount,
    PaymentId1,
    PaymentId2,
    Cerrada,
    FechaCierreUtc,
    FechaUltimaActualizacionUtc
FROM dbo.MercadoPagoOperacionMixta
ORDER BY MercadoPagoOperacionMixtaId DESC;

PRINT '==================== Stock ====================';
SELECT TOP 200
    StockID,
    Cantidad,
    ArticuloAsignacionID,
    UsuarioIDEdicionWeb,
    FechaAviso,
    FechaEdicionWeb,
    FechaEdicionVT
FROM Stock
ORDER BY StockID;

PRINT '==================== StockHistorico ====================';
SELECT TOP 200
    StockHistoricoID,
    StockID,
    TipoDeMovimientoID,
    Fecha,
    UsuarioID,
    Cantidad,
    FechaAviso
FROM StockHistorico
ORDER BY Fecha DESC;
