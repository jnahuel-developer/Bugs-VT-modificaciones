USE BugsDev;
GO

PRINT '=== BLOQUE 5: Borrando Jerarquías, Locaciones, Máquinas, Terminales, Operadores ===';

-- 5.0 Tablas auxiliares posibles (si existen y referencian estas entidades)
IF OBJECT_ID('dbo.TablasOffline', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando TablasOffline...';
    DELETE FROM TablasOffline;
END

IF OBJECT_ID('dbo.ArticuloAsignacion', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando ArticuloAsignacion...';
    DELETE FROM ArticuloAsignacion;
END

-- 5.1 Jerarquías
IF OBJECT_ID('dbo.Jerarquia', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando Jerarquia...';
    DELETE FROM Jerarquia;
    SELECT COUNT(*) AS JerarquiaRestantes FROM Jerarquia;
END
ELSE
    PRINT '> Tabla Jerarquia no encontrada.';

-- 5.2 Máquinas
IF OBJECT_ID('dbo.Maquina', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando Maquina...';
    DELETE FROM Maquina;
    SELECT COUNT(*) AS MaquinaRestantes FROM Maquina;
END
ELSE
    PRINT '> Tabla Maquina no encontrada.';

-- 5.3 Terminales
IF OBJECT_ID('dbo.Terminal', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando Terminal...';
    DELETE FROM Terminal;
    SELECT COUNT(*) AS TerminalRestantes FROM Terminal;
END
ELSE
    PRINT '> Tabla Terminal no encontrada.';

-- 5.4 Locaciones
IF OBJECT_ID('dbo.Locacion', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando Locacion...';
    DELETE FROM Locacion;
    SELECT COUNT(*) AS LocacionRestantes FROM Locacion;
END
ELSE
    PRINT '> Tabla Locacion no encontrada.';

-- 5.5 Operadores
IF OBJECT_ID('dbo.Operador', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando Operador...';
    DELETE FROM Operador;
    SELECT COUNT(*) AS OperadorRestantes FROM Operador;
END
ELSE
    PRINT '> Tabla Operador no encontrada.';

PRINT '=== BLOQUE 5 completado ===';
GO
