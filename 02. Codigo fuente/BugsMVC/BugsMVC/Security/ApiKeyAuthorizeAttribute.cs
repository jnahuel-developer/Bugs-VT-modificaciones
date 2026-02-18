using BugsMVC.DAL;
using BugsMVC.Models;
using System;
using System.Linq;
using System.Net;
using System.Web;
using System.Web.Mvc;

namespace BugsMVC.Security
{
    public class ApiKeyAuthorizeAttribute : AuthorizeAttribute
    {
        public const string ApiKeyHeaderName = "X-Api-Key";
        public const string OperadorIdItemKey = "OperadorId";

        protected override bool AuthorizeCore(HttpContextBase httpContext)
        {
            if (httpContext == null)
            {
                return false;
            }

            string providedToken = httpContext.Request.Headers[ApiKeyHeaderName];
            if (string.IsNullOrWhiteSpace(providedToken))
            {
                return false;
            }

            using (var db = new BugsContext())
            {
                Operador operador = db.Operadores.FirstOrDefault(x => x.SecretToken == providedToken);
                if (operador == null)
                {
                    return false;
                }

                if (!SecureEquals(operador.SecretToken, providedToken))
                {
                    return false;
                }

                httpContext.Items[OperadorIdItemKey] = operador.OperadorID;
                return true;
            }
        }

        protected override void HandleUnauthorizedRequest(AuthorizationContext filterContext)
        {
            filterContext.Result = new HttpStatusCodeResult(HttpStatusCode.Unauthorized);
        }

        private static bool SecureEquals(string left, string right)
        {
            if (left == null || right == null)
            {
                return false;
            }

            if (left.Length != right.Length)
            {
                return false;
            }

            int result = 0;
            for (int i = 0; i < left.Length; i++)
            {
                result |= left[i] ^ right[i];
            }

            return result == 0;
        }
    }
}
