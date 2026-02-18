mod0001
    Rama: mod0001
    Módulo principal: Ambos
    Estado: Fusionada en main
    Descripción:
        - Se incorporó el código fuente inicial de BugsMVC y StockNotifier.
    Archivos modificados:
        - (ninguno)
    Archivos nuevos:
        - (múltiples) Carga inicial del repositorio (código fuente de BugsMVC y StockNotifier).
    Archivos eliminados:
        - (ninguno)

mod0002
    Rama: mod0002
    Módulo principal: BugsMVC
    Estado: Fusionada en main
    Descripción:
        - Se agregaron tres scripts SQL unificados para soporte/diagnóstico del módulo BugsMVC.
    Archivos modificados:
        - (ninguno)
    Archivos nuevos:
        - 03. Scripts SQL\Scripts unificados\A - Ver todas las tablas.sql
        - 03. Scripts SQL\Scripts unificados\B - Borrar todas las tablas de pruebas.sql
        - 03. Scripts SQL\Scripts unificados\C - Cargar datos de pruebas.sql
    Archivos eliminados:
        - (ninguno)

mod0003
    Rama: mod0003
    Módulo principal: Ambos
    Estado: En desarrollo
    Descripción:
        - Se implementó el toggle PagosMixtos:Modo (OFF/ON) con lectura cacheada y default seguro OFF.
        - Se aplicó gating en BugsMVC para deshabilitar el flujo mixto cuando el modo se encuentra en OFF.
        - Se aplicó gating en StockNotifier para mantener devoluciones simples cuando el modo se encuentra en OFF y condicionar la lógica mixta a ON.
        - Se registró en el log el valor efectivo resuelto de PagosMixtos:Modo al inicio (OFF/ON).
        - Se agregó la key PagosMixtos:Modo=OFF en configuraciones de ambos proyectos.
    Archivos modificados:
        - 02. Codigo fuente/BugsMVC/BugsMVC/BugsMVC.csproj
        - 02. Codigo fuente/BugsMVC/BugsMVC/Controllers/PagosMPController.cs
        - 02. Codigo fuente/BugsMVC/BugsMVC/Global.asax.cs
        - 02. Codigo fuente/BugsMVC/BugsMVC/settings.config
        - 02. Codigo fuente/StockNotifier/App.config
        - 02. Codigo fuente/StockNotifier/Program.cs
        - 02. Codigo fuente/StockNotifier/StockNotifier.csproj
    Archivos nuevos:
        - 02. Codigo fuente/BugsMVC/BugsMVC/Helpers/PagosMixtosConfigHelper.cs
        - 02. Codigo fuente/StockNotifier/PagosMixtosConfigHelper.cs
        - 04. Entregables/Historial.md
    Archivos eliminados:
        - (ninguno)

mod0004
    Rama: mod0004
    Módulo principal: Ambos
    Estado: En desarrollo
    Descripción:
        - Se agregaron las keys Ambiente:Desarrollo y Ambiente:Simuladores con lectura cacheada, validación ON/OFF y logging mínimo del valor efectivo.
        - Se estableció connection.config como configSource por defecto en Web.config.
        - Se desvió la consulta de estado de pago hacia mp_simulator cuando Ambiente:Simuladores se encuentra en ON, manteniéndose el SDK real cuando se encuentra en OFF.
        - Se desvió el envío a máquina hacia el simulador local cuando Ambiente:Simuladores se encuentra en ON, manteniéndose el destino configurado cuando se encuentra en OFF.
    Archivos modificados:
        - 02. Codigo fuente/BugsMVC/BugsMVC/BugsMVC.csproj
        - 02. Codigo fuente/BugsMVC/BugsMVC/Controllers/PagosMPController.cs
        - 02. Codigo fuente/BugsMVC/BugsMVC/Global.asax.cs
        - 02. Codigo fuente/BugsMVC/BugsMVC/Web.config
        - 02. Codigo fuente/BugsMVC/BugsMVC/connection.config
        - 02. Codigo fuente/BugsMVC/BugsMVC/settings.config
        - 02. Codigo fuente/StockNotifier/App.config
        - 02. Codigo fuente/StockNotifier/Program.cs
        - 02. Codigo fuente/StockNotifier/StockNotifier.csproj
    Archivos nuevos:
        - 02. Codigo fuente/BugsMVC/BugsMVC/Helpers/AmbienteConfigHelper.cs
        - 02. Codigo fuente/StockNotifier/AmbienteConfigHelper.cs
    Archivos eliminados:
        - (ninguno)
