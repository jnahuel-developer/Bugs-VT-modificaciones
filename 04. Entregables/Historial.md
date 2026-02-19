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
    Estado: Fusionada en main
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
    Estado: Fusionada en main
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

mod0005
	Rama: mod0005
	Módulo principal: BugsMVC
	Estado: Fusionada en develop
	Descripción:
		- Se robusteció el cierre por timeout de operaciones de pagos mixtos para evitar registros incorrectos en MercadoPagoTable.
		- Si la operación mixta expira sin impacto financiero (MontoAcumulado == 0 o sin PaymentId1/PaymentId2) se cierra la operación en MercadoPagoOperacionMixta y se registra únicamente un log informativo (sin insertar NO_PROCESABLE).
		- Si la operación mixta expira con al menos 1 pago aprobado (monto acumulado > 0 y existe PaymentId1/PaymentId2), se registra NO_PROCESABLE en MercadoPagoTable con:
			- Comprobante = PaymentId real parcial (PaymentId1 ?? PaymentId2).
			- Descripcion = "Pago mixto inconsistente".
			- UrlDevolucion = NULL.
			- MaquinaId resuelta por ExternalReference + OperadorId (fallback a máquina nula si no se puede resolver).
		- Se agregaron logs de trazabilidad para cierres silenciosos y para inserciones NO_PROCESABLE, incluyendo snapshot de la operación mixta (ids, montos, approvedCount y paymentIds).
	Archivos modificados:
		- 02. Codigo fuente/BugsMVC/BugsMVC/Controllers/PagosMPController.cs
	Archivos nuevos:
		- (ninguno)
	Archivos eliminados:
		- (ninguno)

mod0006
    Rama: mod0006
    Módulo principal: Simuladores
    Estado: Fusionada en develop
    Descripción:
        - Se agregaron los endpoints POST /__admin/scenarios/mixed_rejected y POST /__admin/scenarios/mixed_cancelled para generar pagos mixtos donde la parte 2 queda fija en estado rejected o cancelled, sin afectar los escenarios existentes.
        - Se extendió el escenario mixto para soportar un estado final configurable en el pago 2, manteniendo el flujo actual del pago 1 (authorized → approved) cuando corresponde.
        - Se ajustó status_detail para reflejar correctamente approved/authorized/rejected/cancelled, con fallback compatible.
    Archivos modificados:
        - 05. Simuladores/mp_simulator.py
    Archivos nuevos:
        - (ninguno)
    Archivos eliminados:
        - (ninguno)

mod0007
    Rama: mod0007
    Módulo principal: BugsMVC
    Estado: Fusionada en develop
    Descripción:
        - Se incorporó el cierre de pagos mixtos cuando un pago parcial finaliza en estado Rejected/Cancelled, registrándolo como no procesable cuando corresponde y evitando el envío a máquina.
        - Se ajustó la validación de envío a máquina para exigir dos pagos parciales registrados con identificadores válidos (distintos de 0) y monto acumulado > 0.
        - Se agregaron logs más descriptivos y helpers para resolución de máquina por ExternalReference y selección de comprobante válido en cierres mixtos (rechazo/cancelación y timeout).
    Archivos modificados:
        - 02. Codigo fuente\BugsMVC\BugsMVC\Controllers\PagosMPController.cs
    Archivos nuevos:
        - (ninguno)
    Archivos eliminados:
        - (ninguno)