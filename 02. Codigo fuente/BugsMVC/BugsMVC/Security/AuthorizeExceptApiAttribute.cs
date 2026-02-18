using System.Web.Mvc;

namespace BugsMVC.Security
{
    public class AuthorizeExceptApiAttribute : AuthorizeAttribute
    {
        public override void OnAuthorization(AuthorizationContext filterContext)
        {
            if (filterContext == null)
            {
                return;
            }

            string path = filterContext.HttpContext?.Request?.Path ?? string.Empty;
            if (path.StartsWith("/api"))
            {
                return;
            }

            base.OnAuthorization(filterContext);
        }
    }
}
