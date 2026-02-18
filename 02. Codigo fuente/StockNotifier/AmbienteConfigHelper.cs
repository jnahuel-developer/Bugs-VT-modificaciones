using System;
using System.Configuration;

namespace StockNotifier
{
    public static class AmbienteConfigHelper
    {
        private static readonly log4net.ILog Log =
            log4net.LogManager.GetLogger(System.Reflection.MethodBase.GetCurrentMethod().DeclaringType);

        private static readonly bool _ambienteDesarrolloHabilitado = ResolverValorAmbiente("Ambiente:Desarrollo");
        private static readonly bool _ambienteSimuladoresHabilitado = ResolverValorAmbiente("Ambiente:Simuladores");

        public static bool AmbienteDesarrolloHabilitado => _ambienteDesarrolloHabilitado;
        public static bool AmbienteSimuladoresHabilitado => _ambienteSimuladoresHabilitado;

        public static void Inicializar()
        {
            _ = AmbienteDesarrolloHabilitado;
            _ = AmbienteSimuladoresHabilitado;
        }

        private static bool ResolverValorAmbiente(string configKey)
        {
            string modo = ConfigurationManager.AppSettings[configKey];

            if (string.IsNullOrWhiteSpace(modo))
            {
                Log.Info($"No se encontró la configuración '{configKey}'. Se tomará el valor OFF por defecto.");
                Log.Info($"Se resolvió la configuración '{configKey}' con valor efectivo: OFF.");
                return false;
            }

            if (string.Equals(modo, "ON", StringComparison.OrdinalIgnoreCase))
            {
                Log.Info($"Se resolvió la configuración '{configKey}' con valor efectivo: ON.");
                return true;
            }

            if (string.Equals(modo, "OFF", StringComparison.OrdinalIgnoreCase))
            {
                Log.Info($"Se resolvió la configuración '{configKey}' con valor efectivo: OFF.");
                return false;
            }

            Log.Info($"Se detectó un valor inválido en '{configKey}' ({modo}). Se tomará el valor OFF por defecto.");
            Log.Info($"Se resolvió la configuración '{configKey}' con valor efectivo: OFF.");
            return false;
        }
    }
}
