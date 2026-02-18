USE BugsDev;
GO

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
ORDER BY NumeroSerie;
