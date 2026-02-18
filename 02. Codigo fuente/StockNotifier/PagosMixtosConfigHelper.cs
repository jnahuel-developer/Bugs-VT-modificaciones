using System;
using System.Configuration;

namespace StockNotifier
{
    public static class PagosMixtosConfigHelper
    {
        private static readonly log4net.ILog Log =
            log4net.LogManager.GetLogger(System.Reflection.MethodBase.GetCurrentMethod().DeclaringType);

        // El modo de pagos mixtos es leído una sola vez al iniciar el proceso y, ante faltante o valor inválido, OFF es aplicado por defecto.
        private static readonly bool _pagosMixtosHabilitados = ResolverPagosMixtosHabilitados();

        public static bool PagosMixtosHabilitados => _pagosMixtosHabilitados;

        private static bool ResolverPagosMixtosHabilitados()
        {
            string modo = ConfigurationManager.AppSettings["PagosMixtos:Modo"];

            if (string.IsNullOrWhiteSpace(modo))
            {
                Log.Info("No se encontró la configuración 'PagosMixtos:Modo'. Se tomará el valor OFF por defecto.");
                return false;
            }

            if (string.Equals(modo, "ON", StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            if (string.Equals(modo, "OFF", StringComparison.OrdinalIgnoreCase))
            {
                return false;
            }

            Log.Info($"Se detectó un valor inválido en 'PagosMixtos:Modo' ({modo}). Se tomará el valor OFF por defecto.");
            return false;
        }
    }
}
