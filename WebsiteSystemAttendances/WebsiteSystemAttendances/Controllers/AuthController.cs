using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using WebsiteSystemAttendances.Services;

namespace WebsiteSystemAttendances.Controllers
{
    public class AuthController : Controller
    {
        private readonly ApiClient _apiClient;
        private readonly ILogger<AuthController> _logger;

        public AuthController(ApiClient apiClient, ILogger<AuthController> logger)
        {
            _apiClient = apiClient;
            _logger = logger;
        }

        [HttpGet]
        public IActionResult Login()
        {
            if (HttpContext.Session.GetString("JwtToken") != null)
            {
                var role = HttpContext.Session.GetString("UserRole") ?? "";
                if (role.Equals("Superadmin", StringComparison.OrdinalIgnoreCase))
                    return RedirectToAction("Index", "SuperAdmin");
                return RedirectToAction("Index", "Admin");
            }
            return View();
        }

        // === Company Login (Admin HR) ===
        [HttpPost]
        public async Task<IActionResult> Login(string email, string password)
        {
            try
            {
                _logger.LogInformation("Company login attempt: {Email}", email);
                var result = await _apiClient.LoginAsync(email, password);
                if (result != null && result.Success)
                {
                    var jo = JObject.Parse(result.Data!);
                    string token = jo["token"]?.ToString() ?? "";
                    string name = jo["name"]?.ToString() ?? "";
                    string userEmail = jo["email"]?.ToString() ?? "";
                    string role = jo["role"]?.ToString() ?? "";
                    int userId = jo["id"]?.Value<int>() ?? 0;
                    int roleId = jo["roleId"]?.Value<int>() ?? 0;
                    int? companyId = jo["companyId"]?.Value<int>();

                    _logger.LogInformation("Company login success: {Name}, Role: {Role}", name, role);

                    HttpContext.Session.SetString("JwtToken", token);
                    HttpContext.Session.SetString("UserName", name);
                    HttpContext.Session.SetString("UserEmail", userEmail);
                    HttpContext.Session.SetString("UserRole", role);
                    HttpContext.Session.SetInt32("UserId", userId);
                    HttpContext.Session.SetInt32("RoleId", roleId);
                    if (companyId.HasValue)
                        HttpContext.Session.SetInt32("CompanyId", companyId.Value);

                    return RedirectToAction("Index", "Admin");
                }

                ViewBag.Error = result?.Message ?? "Email atau password salah!";
                return View("Login");
            }
            catch (HttpRequestException)
            {
                ViewBag.Error = "API Server tidak bisa dihubungi! Pastikan API berjalan.";
                return View("Login");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during company login");
                ViewBag.Error = $"Error: {ex.Message}";
                return View("Login");
            }
        }

        // === Platform Login (Super Admin) ===
        [HttpPost]
        public async Task<IActionResult> PlatformLogin(string email, string password)
        {
            try
            {
                _logger.LogInformation("Platform login attempt: {Email}", email);
                var result = await _apiClient.PlatformLoginAsync(email, password);
                if (result != null && result.Success)
                {
                    var jo = JObject.Parse(result.Data!);
                    string token = jo["token"]?.ToString() ?? "";
                    string name = jo["name"]?.ToString() ?? "";
                    string userEmail = jo["email"]?.ToString() ?? "";
                    string role = jo["role"]?.ToString() ?? "";
                    int userId = jo["id"]?.Value<int>() ?? 0;

                    _logger.LogInformation("Platform login success: {Name}, Role: {Role}", name, role);

                    HttpContext.Session.SetString("JwtToken", token);
                    HttpContext.Session.SetString("UserName", name);
                    HttpContext.Session.SetString("UserEmail", userEmail);
                    HttpContext.Session.SetString("UserRole", role);
                    HttpContext.Session.SetInt32("UserId", userId);

                    return RedirectToAction("Index", "SuperAdmin");
                }

                ViewBag.Error = result?.Message ?? "Email atau password salah!";
                return View("Login");
            }
            catch (HttpRequestException)
            {
                ViewBag.Error = "API Server tidak bisa dihubungi! Pastikan API berjalan.";
                return View("Login");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during platform login");
                ViewBag.Error = $"Error: {ex.Message}";
                return View("Login");
            }
        }

        [HttpPost]
        public IActionResult Logout()
        {
            HttpContext.Session.Clear();
            return RedirectToAction("Login");
        }
    }
}
