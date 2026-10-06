using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace RestAPIAttendaces.Controllers
{
    [Authorize]
    [ApiController]
    public abstract class BaseApiController : ControllerBase
    {
        /// <summary>
        /// Ambil company_id dari JWT token.
        /// Return null jika tidak ada (SuperAdmin).
        /// </summary>
        protected int? GetCompanyId()
        {
            var claim = User.Claims.FirstOrDefault(c => c.Type == "company_id");
            if (claim == null) return null;
            return int.TryParse(claim.Value, out var companyId) ? companyId : null;
        }

        /// <summary>
        /// Ambil user_id dari JWT token.
        /// </summary>
        protected int GetUserId()
        {
            var claim = User.Claims.FirstOrDefault(c => c.Type == ClaimTypes.NameIdentifier);
            if (claim == null) return 0;
            return int.TryParse(claim.Value, out var userId) ? userId : 0;
        }

        /// <summary>
        /// Ambil role name dari JWT token.
        /// </summary>
        protected string GetRoleName()
        {
            return User.Claims.FirstOrDefault(c => c.Type == ClaimTypes.Role)?.Value ?? "";
        }
    }
}
