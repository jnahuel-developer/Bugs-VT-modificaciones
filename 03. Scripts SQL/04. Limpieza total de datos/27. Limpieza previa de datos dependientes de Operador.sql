USE BugsDev;
GO

PRINT '--- Limpieza previa de datos dependientes de Operador ---';

-- 1) Articulos y tablas que puedan depender de ellos
IF OBJECT_ID('dbo.ArticuloAsignacion', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando ArticuloAsignacion...';
    DELETE FROM ArticuloAsignacion;
    SELECT COUNT(*) AS ArticuloAsignacionRestantes FROM ArticuloAsignacion;
END

IF OBJECT_ID('dbo.Articulo', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando Articulo...';
    DELETE FROM Articulo;
    SELECT COUNT(*) AS ArticuloRestantes FROM Articulo;
END

PRINT '--- Borrando Operadores ---';

IF OBJECT_ID('dbo.Operador', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando Operador...';
    DELETE FROM Operador;
    SELECT COUNT(*) AS OperadorRestantes FROM Operador;
END
GO
