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

mod0008
	Rama: mod0008
	Módulo principal: StockNotifier
	Estado: Fusionada en develop
	Descripción:
		- Se integró el feature-flag de pagos mixtos (PagosMixtos:Modo) usando los helpers existentes, con logueo de configuración al inicio del proceso.
		- Se aisló el flujo original de devolución de Mercado Pago en un método reutilizable, preservando el comportamiento para pagos simples cuando pagos mixtos está deshabilitado.
		- Con pagos mixtos habilitados, se agregó la correlación contra MercadoPagoOperacionMixta para detectar si el comprobante corresponde a una operación mixta y, en ese caso, ejecutar la devolución de ambos comprobantes (PaymentId1 y PaymentId2) cuando corresponda.
	Archivos modificados:
		- 02. Codigo fuente\StockNotifier\Program.cs
	Archivos nuevos:
		- (ninguno)
	Archivos eliminados:
		- (ninguno)

mod0009
	Rama: mod0009
	Módulo principal: StockNotifier
	Estado: Fusionada en develop
	Descripción:
		- Se incorporó la atención de pagos mixtos dentro del flujo de devoluciones, validando si el comprobante a devolver está asociado a una operación en MercadoPagoOperacionMixta.
		- Cuando el comprobante no está asociado a una operación mixta, se procesa como devolución estándar (pago simple).
		- Cuando el comprobante sí está asociado a una operación mixta y existe un segundo PaymentId válido, se ejecuta la devolución de ambos comprobantes (PaymentId1 y PaymentId2) dentro de la misma iteración.
		- Se mantuvo el flujo original de devoluciones para pagos simples sin cambios funcionales cuando no aplica mixto.
		- Se agregaron logs en español (tono formal) para distinguir claramente los casos “pago simple” vs “pago mixto” y los comprobantes involucrados.
	Archivos modificados:
		- 02. Codigo fuente\StockNotifier\Program.cs
	Archivos nuevos:
		- (ninguno)
	Archivos eliminados:
		- (ninguno)

mod0010
	Rama: mod0010
	Módulo principal: mp_simulator
	Estado: Fusionada en develop
	Descripción:
		- Se incorporó soporte de refunds (devoluciones) para payments mediante los endpoints POST /v1/payments/{id}/refunds y POST /payments/{id}/refunds (alias), manteniendo los endpoints GET existentes para consulta de payments.
		- Se agregó estado en memoria para refunds por payment (requested_at/apply_at/modo/delay/aplicado) y un next_refund_mode global one-shot que se consume en el primer refund y vuelve a ok.
		- Se implementó creación automática del payment al solicitar refund si no existe (status inicial approved), para permitir IDs ficticios en pruebas locales.
		- Se agregaron endpoints admin para controlar el comportamiento del “próximo refund”: ok, delay_ok, delay_timeout y no_response, más endpoints de consulta/reset del modo.
		- Se eliminaron archivos de análisis innecesarios creados previamente para esta mod.
	Archivos modificados:
		- 05. Simuladores\mp_simulator.py
	Archivos nuevos:
		- (ninguno)
	Archivos eliminados:
		- (ninguno)