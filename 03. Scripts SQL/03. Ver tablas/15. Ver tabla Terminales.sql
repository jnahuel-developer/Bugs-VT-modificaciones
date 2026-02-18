USE BugsDev;
GO

SELECT 
    TerminalID,
    NumeroSerie,
    Interfaz,
    Version,
    OperadorID,
    ModeloTerminalID
FROM Terminal
ORDER BY NumeroSerie;
