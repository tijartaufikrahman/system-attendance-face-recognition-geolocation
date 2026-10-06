using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using WebsiteSystemAttendances.Services;

namespace WebsiteSystemAttendances.Controllers
{
    public class SuperAdminController : Controller
    {
        private readonly ApiClient _apiClient;
        private readonly ILogger<SuperAdminController> _logger;

        public SuperAdminController(ApiClient apiClient, ILogger<SuperAdminController> logger)
        {
            _apiClient = apiClient;
            _logger = logger;
        }

        private bool IsAuthenticated()
        {
            return HttpContext.Session.GetString("JwtToken") != null;
        }

        private bool IsSuperAdmin()
        {
            var role = HttpContext.Session.GetString("UserRole") ?? "";
            return role.Equals("Superadmin", StringComparison.OrdinalIgnoreCase);
        }

        private void SetUserInfo()
        {
            ViewBag.UserName = HttpContext.Session.GetString("UserName") ?? "Super Admin";
            ViewBag.UserEmail = HttpContext.Session.GetString("UserEmail") ?? "";
        }

        private IActionResult CheckAuth()
        {
            if (!IsAuthenticated()) return RedirectToAction("Login", "Auth");
            if (!IsSuperAdmin()) return RedirectToAction("Index", "Admin");
            return null!;
        }

        // ============================================================
        // DASHBOARD
        // ============================================================
        public async Task<IActionResult> Index()
        {
            var auth = CheckAuth();
            if (auth != null) return auth;
            SetUserInfo();
            ViewData["Title"] = "Dashboard";

            var companies = await _apiClient.GetAsync("api/companies");
            var companiesArr = companies != null && companies.Success ? JArray.Parse(companies.Data ?? "[]") : new JArray();

            ViewBag.TotalCompanies = companiesArr.Count;
            ViewBag.ActiveCompanies = companiesArr.Count(c => (bool?)c["isActive"] == true);
            ViewBag.SuspendedCompanies = companiesArr.Count(c => (bool?)c["isActive"] == false);

            return View();
        }

        // ============================================================
        // COMPANIES - LIST
        // ============================================================
        public async Task<IActionResult> Companies()
        {
            var auth = CheckAuth();
            if (auth != null) return auth;
            SetUserInfo();
            ViewData["Title"] = "Perusahaan / Klien";

            var result = await _apiClient.GetAsync("api/companies");
            var companies = result != null && result.Success ? JArray.Parse(result.Data ?? "[]") : new JArray();
            return View(companies);
        }

        // ============================================================
        // COMPANIES - CREATE
        // ============================================================
        [HttpGet]
        public IActionResult CompanyCreate()
        {
            var auth = CheckAuth();
            if (auth != null) return auth;
            SetUserInfo();
            ViewData["Title"] = "Daftarkan Klien Baru";
            return View();
        }

        [HttpPost]
        public async Task<IActionResult> CompanyCreate(
            string name, string? address, string? phone,
            string adminName, string adminEmail, string adminPassword)
        {
            var auth = CheckAuth();
            if (auth != null) return auth;
            SetUserInfo();
            ViewData["Title"] = "Daftarkan Klien Baru";

            var payload = new
            {
                Name = name,
                Address = address,
                Phone = phone,
                AdminName = adminName,
                AdminEmail = adminEmail,
                AdminPassword = adminPassword
            };

            var result = await _apiClient.PostAsync("api/companies/create-with-admin", payload);
            if (result != null && result.Success)
            {
                TempData["Success"] = "Perusahaan & akun Admin HR berhasil dibuat!";
                return RedirectToAction("Companies");
            }

            ViewBag.Error = "Gagal menambahkan perusahaan. " + (result?.Message ?? "");
            return View();
        }

        // ============================================================
        // COMPANIES - EDIT
        // ============================================================
        [HttpGet]
        public async Task<IActionResult> CompanyEdit(int id)
        {
            var auth = CheckAuth();
            if (auth != null) return auth;
            SetUserInfo();
            ViewData["Title"] = "Edit Perusahaan";

            var result = await _apiClient.GetByIdAsync("api/companies", id);
            if (result == null || !result.Success) return RedirectToAction("Companies");

            var company = JObject.Parse(result.Data ?? "{}");
            return View(company);
        }

        [HttpPost]
        public async Task<IActionResult> CompanyEdit(int id, string name, string? address, string? phone, bool isActive)
        {
            var auth = CheckAuth();
            if (auth != null) return auth;
            SetUserInfo();
            ViewData["Title"] = "Edit Perusahaan";

            var payload = new { Name = name, Address = address, Phone = phone, IsActive = isActive };
            var result = await _apiClient.PutAsync("api/companies", id, payload);

            if (result != null && result.Success)
            {
                TempData["Success"] = "Perusahaan berhasil diupdate!";
                return RedirectToAction("Companies");
            }

            ViewBag.Error = "Gagal mengupdate perusahaan.";
            var companyResult = await _apiClient.GetByIdAsync("api/companies", id);
            return View(companyResult != null && companyResult.Success ? JObject.Parse(companyResult.Data ?? "{}") : new JObject());
        }

        // ============================================================
        // COMPANIES - DELETE
        // ============================================================
        [HttpPost]
        public async Task<IActionResult> CompanyDelete(int id)
        {
            var auth = CheckAuth();
            if (auth != null) return auth;

            var r = await _apiClient.DeleteAsync("api/companies", id);
            if (r != null && r.Success)
                TempData["Success"] = "Perusahaan berhasil dihapus!";
            else
                TempData["Error"] = r?.Message ?? "Gagal menghapus perusahaan.";
            return RedirectToAction("Companies");
        }
    }
}
