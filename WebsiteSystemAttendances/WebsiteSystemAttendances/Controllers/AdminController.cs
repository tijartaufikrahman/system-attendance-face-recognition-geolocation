using System.Globalization;
using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json.Linq;
using WebsiteSystemAttendances.Services;

namespace WebsiteSystemAttendances.Controllers
{
    public class AdminController : Controller
    {
        private readonly ApiClient _apiClient;
        public AdminController(ApiClient apiClient) { _apiClient = apiClient; }

        private bool IsAuth() => HttpContext.Session.GetString("JwtToken") != null;
        private int? GetCompanyId() => HttpContext.Session.GetInt32("CompanyId");
        private bool IsSuperAdmin() => (HttpContext.Session.GetString("UserRole") ?? "").Equals("Superadmin", StringComparison.OrdinalIgnoreCase);
        private bool IsAjaxRequest() => string.Equals(Request.Headers["X-Requested-With"], "XMLHttpRequest", StringComparison.OrdinalIgnoreCase);
        private IActionResult AjaxResponse(JsonResponse? response, string successMessage, string fallbackMessage)
        {
            var success = response?.Success == true;
            if (success) TempData["Success"] = successMessage;
            else TempData["Error"] = response?.Message ?? fallbackMessage;
            return Json(new
            {
                success,
                message = success ? successMessage : response?.Message ?? fallbackMessage
            });
        }
        private IActionResult Check()
        {
            if (!IsAuth()) return RedirectToAction("Login", "Auth");
            if (IsSuperAdmin()) return RedirectToAction("Index", "SuperAdmin");
            if (!GetCompanyId().HasValue) return RedirectToAction("Login", "Auth");
            return null!;
        }
        private void SetInfo()
        {
            ViewBag.UserName = HttpContext.Session.GetString("UserName") ?? "Admin";
            ViewBag.UserEmail = HttpContext.Session.GetString("UserEmail") ?? "";
            ViewBag.CompanyName = HttpContext.Session.GetString("CompanyName") ?? "Perusahaan";
        }

        private async Task LoadDropdowns()
        {
            var roles = await _apiClient.GetAsync("api/roles");
            ViewBag.Roles = roles != null && roles.Success ? JArray.Parse(roles.Data ?? "[]") : new JArray();

            var schedules = await _apiClient.GetAsync("api/schedules");
            ViewBag.Schedules = schedules != null && schedules.Success ? JArray.Parse(schedules.Data ?? "[]") : new JArray();

            var positions = await _apiClient.GetAsync("api/positions");
            ViewBag.Positions = positions != null && positions.Success ? JArray.Parse(positions.Data ?? "[]") : new JArray();

            var locations = await _apiClient.GetAsync("api/locations");
            ViewBag.Locations = locations != null && locations.Success ? JArray.Parse(locations.Data ?? "[]") : new JArray();
        }

        private static decimal ParseDecimal(string? value, decimal defaultValue = 0m)
        {
            if (string.IsNullOrWhiteSpace(value)) return defaultValue;
            if (decimal.TryParse(value, NumberStyles.Number | NumberStyles.AllowLeadingSign | NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out var result))
                return result;
            return defaultValue;
        }

        private static string FormatTime(string? time)
        {
            if (string.IsNullOrWhiteSpace(time)) return "00:00:00";
            if (TimeSpan.TryParse(time, CultureInfo.InvariantCulture, out var ts)) return ts.ToString(@"hh\:mm\:ss");
            if (time.Length == 5) return time + ":00";
            return time;
        }

        // ============================================================
        // DASHBOARD
        // ============================================================
        public async Task<IActionResult> Index()
        {
            var c = Check(); if (c != null) return c; SetInfo(); ViewData["Title"] = "Dashboard";
            var users = await _apiClient.GetAsync("api/users");
            var schedules = await _apiClient.GetAsync("api/schedules");
            var positions = await _apiClient.GetAsync("api/positions");
            var locations = await _apiClient.GetAsync("api/locations");

            ViewBag.TotalUsers = users != null && users.Success ? JArray.Parse(users.Data ?? "[]").Count : 0;
            ViewBag.TotalSchedules = schedules != null && schedules.Success ? JArray.Parse(schedules.Data ?? "[]").Count : 0;
            ViewBag.TotalPositions = positions != null && positions.Success ? JArray.Parse(positions.Data ?? "[]").Count : 0;
            ViewBag.TotalLocations = locations != null && locations.Success ? JArray.Parse(locations.Data ?? "[]").Count : 0;

            return View();
        }

        // ============================================================
        // LOKASI (1 Perusahaan = 1 Lokasi)
        // ============================================================
        public async Task<IActionResult> Locations()
        {
            var c = Check(); if (c != null) return c; SetInfo(); ViewData["Title"] = "Lokasi Kantor";

            // Ambil lokasi company yang sedang login
            var r = await _apiClient.GetAsync("api/locations/company");
            if (r != null && r.Success)
            {
                var loc = JObject.Parse(r.Data ?? "{}");
                return View(loc); // Ada data lokasi → tampilkan card
            }

            // Belum ada lokasi → tampilkan form tambah
            return View(new JObject());
        }

        // ============================================================
        // PENGATURAN ABSENSI
        // ============================================================
        public async Task<IActionResult> AttendanceSettings()
        {
            var c = Check(); if (c != null) return c; SetInfo(); ViewData["Title"] = "Pengaturan Absensi";
            var r = await _apiClient.GetAsync("api/company-settings/company");
            var setting = r != null && r.Success ? JObject.Parse(r.Data ?? "{}") : new JObject();
            if (r == null || !r.Success) ViewBag.Error = r?.Message ?? "Pengaturan absensi belum dapat dimuat.";
            return View(setting);
        }

        [HttpPost]
        public async Task<IActionResult> AttendanceSettingsSave(int radiusMeters, string faceTolerance)
        {
            var c = Check(); if (c != null) return c;
            if (!double.TryParse(faceTolerance, NumberStyles.Float, CultureInfo.InvariantCulture, out var parsedTolerance))
            {
                parsedTolerance = double.TryParse(faceTolerance, NumberStyles.Float, CultureInfo.CurrentCulture, out var localizedTolerance)
                    ? localizedTolerance
                    : -1;
            }

            if (parsedTolerance < 0)
            {
                TempData["Error"] = "Nilai akurasi wajah tidak valid.";
                return RedirectToAction(nameof(AttendanceSettings));
            }

            var r = await _apiClient.PutAsync("api/company-settings/company", new
            {
                RadiusMeters = radiusMeters,
                FaceTolerance = parsedTolerance
            });
            if (IsAjaxRequest()) return AjaxResponse(r, "Pengaturan absensi berhasil disimpan.", "Pengaturan absensi gagal disimpan.");
            if (r != null && r.Success) TempData["Success"] = "Pengaturan absensi berhasil disimpan.";
            else TempData["Error"] = r?.Message ?? "Pengaturan absensi gagal disimpan.";
            return RedirectToAction(nameof(AttendanceSettings));
        }

        [HttpPost]
        public async Task<IActionResult> LocationSave(string name, string? address, string latitude, string longitude, int? radiusMeters)
        {
            var c = Check(); if (c != null) return c;
            var companyId = GetCompanyId();
            if (!companyId.HasValue)
            {
                TempData["Error"] = "Company ID tidak ditemukan.";
                return RedirectToAction("Locations");
            }

            // Cek apakah sudah ada lokasi
            var existing = await _apiClient.GetAsync("api/locations/company");
            bool hasLocation = existing != null && existing.Success;

            if (hasLocation && existing != null)
            {
                // UPDATE - ambil ID dari data yang ada
                var locData = JObject.Parse(existing.Data ?? "{}");
                int locId = locData["id"]?.Value<int>() ?? 0;
                if (locId > 0)
                {
                    var payload = new
                    {
                        Name = name,
                        CompanyId = companyId.Value,
                        Address = address,
                        Latitude = ParseDecimal(latitude),
                        Longitude = ParseDecimal(longitude),
                        RadiusMeters = radiusMeters ?? 50
                    };
                    var r = await _apiClient.PutAsync("api/locations", locId, payload);
                    if (IsAjaxRequest()) return AjaxResponse(r, "Lokasi berhasil diperbarui!", "Gagal memperbarui lokasi.");
                    if (r != null && r.Success)
                    {
                        TempData["Success"] = "Lokasi berhasil diperbarui!";
                        return RedirectToAction("Locations");
                    }
                    TempData["Error"] = r?.Message ?? "Gagal memperbarui lokasi.";
                    return RedirectToAction("Locations");
                }
            }

            // CREATE - belum ada lokasi
            var createPayload = new
            {
                Name = name,
                CompanyId = companyId.Value,
                Address = address,
                Latitude = ParseDecimal(latitude),
                Longitude = ParseDecimal(longitude),
                RadiusMeters = radiusMeters ?? 50
            };
            var cr = await _apiClient.PostAsync("api/locations", createPayload);
            if (IsAjaxRequest()) return AjaxResponse(cr, "Lokasi berhasil ditambahkan!", "Gagal menambahkan lokasi.");
            if (cr != null && cr.Success)
            {
                TempData["Success"] = "Lokasi berhasil ditambahkan!";
                return RedirectToAction("Locations");
            }
            TempData["Error"] = cr?.Message ?? "Gagal menambahkan lokasi.";
            return RedirectToAction("Locations");
        }

        [HttpPost]
        public async Task<IActionResult> LocationDelete()
        {
            var c = Check(); if (c != null) return c;
            var existing = await _apiClient.GetAsync("api/locations/company");
            if (existing == null || !existing.Success)
            {
                TempData["Error"] = "Belum ada lokasi untuk dihapus.";
                return RedirectToAction("Locations");
            }

            var locData = JObject.Parse(existing.Data ?? "{}");
            int locId = locData["id"]?.Value<int>() ?? 0;
            if (locId > 0)
            {
                var r = await _apiClient.DeleteAsync("api/locations", locId);
                if (IsAjaxRequest()) return AjaxResponse(r, "Lokasi berhasil dihapus!", "Gagal menghapus lokasi.");
                if (r != null && r.Success)
                    TempData["Success"] = "Lokasi berhasil dihapus!";
                else
                    TempData["Error"] = r?.Message ?? "Gagal menghapus lokasi.";
            }
            if (IsAjaxRequest())
            {
                TempData["Error"] = "Belum ada lokasi untuk dihapus.";
                return Json(new { success = false, message = "Belum ada lokasi untuk dihapus." });
            }
            return RedirectToAction("Locations");
        }

        // ============================================================
        // JAM KERJA / SCHEDULES (CRUD)
        // ============================================================
        public async Task<IActionResult> Schedules()
        {
            var c = Check(); if (c != null) return c; SetInfo(); ViewData["Title"] = "Jam Kerja";
            var r = await _apiClient.GetAsync("api/schedules");
            return View(r != null && r.Success ? JArray.Parse(r.Data ?? "[]") : new JArray());
        }

        public IActionResult ScheduleCreate()
        {
            var c = Check(); if (c != null) return c; SetInfo(); ViewData["Title"] = "Tambah Jam Kerja";
            return View();
        }

        [HttpPost]
        public async Task<IActionResult> ScheduleCreate(string name, string clockIn, string clockOut)
        {
            var c = Check(); if (c != null) return c; SetInfo(); ViewData["Title"] = "Tambah Jam Kerja";
            var companyId = GetCompanyId();
            if (!companyId.HasValue)
            {
                ViewBag.Error = "Company ID tidak ditemukan.";
                return View();
            }
            var r = await _apiClient.PostAsync("api/schedules", new { Name = name, CompanyId = companyId.Value, ClockIn = FormatTime(clockIn), ClockOut = FormatTime(clockOut) });
            if (IsAjaxRequest()) return AjaxResponse(r, "Jam kerja berhasil ditambahkan!", "Gagal menambahkan jam kerja.");
            if (r != null && r.Success)
            {
                TempData["Success"] = "Jam kerja berhasil ditambahkan!";
                return RedirectToAction("Schedules");
            }
            ViewBag.Error = r?.Message ?? "Gagal menambahkan jam kerja.";
            return View();
        }

        public async Task<IActionResult> ScheduleEdit(int id)
        {
            var c = Check(); if (c != null) return c; SetInfo(); ViewData["Title"] = "Edit Jam Kerja";
            var r = await _apiClient.GetByIdAsync("api/schedules", id);
            if (r != null && r.Success)
            {
                var schedule = JObject.Parse(r.Data ?? "{}");
                return View(schedule);
            }

            TempData["Error"] = "Jam kerja tidak ditemukan.";
            return RedirectToAction("Schedules");
        }

        [HttpPost]
        public async Task<IActionResult> ScheduleEdit(int id, string name, string clockIn, string clockOut)
        {
            var c = Check(); if (c != null) return c; SetInfo(); ViewData["Title"] = "Edit Jam Kerja";
            var companyId = GetCompanyId();
            if (!companyId.HasValue)
            {
                TempData["Error"] = "Company ID tidak ditemukan.";
                return RedirectToAction("Schedules");
            }
            var r = await _apiClient.PutAsync("api/schedules", id, new { Name = name, CompanyId = companyId.Value, ClockIn = FormatTime(clockIn), ClockOut = FormatTime(clockOut) });
            if (IsAjaxRequest()) return AjaxResponse(r, "Jam kerja berhasil diperbarui!", "Gagal memperbarui jam kerja.");
            if (r != null && r.Success)
            {
                TempData["Success"] = "Jam kerja berhasil diperbarui!";
                return RedirectToAction("Schedules");
            }

            ViewBag.Error = r?.Message ?? "Gagal memperbarui jam kerja.";
            var scheduleR = await _apiClient.GetByIdAsync("api/schedules", id);
            return View(scheduleR != null && scheduleR.Success ? JObject.Parse(scheduleR.Data ?? "{}") : new JObject());
        }

        [HttpPost]
        public async Task<IActionResult> ScheduleDelete(int id)
        {
            var c = Check(); if (c != null) return c;
            var r = await _apiClient.DeleteAsync("api/schedules", id);
            if (IsAjaxRequest()) return AjaxResponse(r, "Jam kerja berhasil dihapus!", "Gagal menghapus jam kerja.");
            if (r != null && r.Success)
            {
                TempData["Success"] = "Jam kerja berhasil dihapus!";
            }
            else
            {
                TempData["Error"] = r?.Message ?? "Gagal menghapus jam kerja.";
            }
            return RedirectToAction("Schedules");
        }

        // ============================================================
        // JABATAN / POSITIONS (CRUD)
        // ============================================================
        public async Task<IActionResult> Positions()
        {
            var c = Check(); if (c != null) return c; SetInfo(); ViewData["Title"] = "Jabatan";
            var r = await _apiClient.GetAsync("api/positions");
            var schedules = await _apiClient.GetAsync("api/schedules");

            ViewBag.Schedules = schedules != null && schedules.Success ? JArray.Parse(schedules.Data ?? "[]") : new JArray();
            return View(r != null && r.Success ? JArray.Parse(r.Data ?? "[]") : new JArray());
        }

        public async Task<IActionResult> PositionCreate()
        {
            var c = Check(); if (c != null) return c; SetInfo(); ViewData["Title"] = "Tambah Jabatan";
            await LoadDropdowns();
            return View();
        }

        [HttpPost]
        public async Task<IActionResult> PositionCreate(string name, string? description, int defaultScheduleId)
        {
            var c = Check(); if (c != null) return c; SetInfo(); ViewData["Title"] = "Tambah Jabatan";
            var companyId = GetCompanyId();
            if (!companyId.HasValue)
            {
                ViewBag.Error = "Company ID tidak ditemukan.";
                await LoadDropdowns();
                return View();
            }
            var r = await _apiClient.PostAsync("api/positions", new { Name = name, CompanyId = companyId.Value, Description = description, DefaultScheduleId = defaultScheduleId });
            if (IsAjaxRequest()) return AjaxResponse(r, "Jabatan berhasil ditambahkan!", "Gagal menambahkan jabatan.");
            if (r != null && r.Success)
            {
                TempData["Success"] = "Jabatan berhasil ditambahkan!";
                return RedirectToAction("Positions");
            }

            ViewBag.Error = r?.Message ?? "Gagal menambahkan jabatan.";
            await LoadDropdowns();
            return View();
        }

        public async Task<IActionResult> PositionEdit(int id)
        {
            var c = Check(); if (c != null) return c; SetInfo(); ViewData["Title"] = "Edit Jabatan";
            var r = await _apiClient.GetByIdAsync("api/positions", id);
            if (r != null && r.Success)
            {
                await LoadDropdowns();
                var position = JObject.Parse(r.Data ?? "{}");
                return View(position);
            }

            TempData["Error"] = "Jabatan tidak ditemukan.";
            return RedirectToAction("Positions");
        }

        [HttpPost]
        public async Task<IActionResult> PositionEdit(int id, string name, string? description, int defaultScheduleId)
        {
            var c = Check(); if (c != null) return c; SetInfo(); ViewData["Title"] = "Edit Jabatan";
            var companyId = GetCompanyId();
            if (!companyId.HasValue)
            {
                TempData["Error"] = "Company ID tidak ditemukan.";
                return RedirectToAction("Positions");
            }
            var r = await _apiClient.PutAsync("api/positions", id, new { Name = name, CompanyId = companyId.Value, Description = description, DefaultScheduleId = defaultScheduleId });
            if (IsAjaxRequest()) return AjaxResponse(r, "Jabatan berhasil diperbarui!", "Gagal memperbarui jabatan.");
            if (r != null && r.Success)
            {
                TempData["Success"] = "Jabatan berhasil diperbarui!";
                return RedirectToAction("Positions");
            }

            ViewBag.Error = r?.Message ?? "Gagal memperbarui jabatan.";
            await LoadDropdowns();
            var posR = await _apiClient.GetByIdAsync("api/positions", id);
            return View(posR != null && posR.Success ? JObject.Parse(posR.Data ?? "{}") : new JObject());
        }

        [HttpPost]
        public async Task<IActionResult> PositionDelete(int id)
        {
            var c = Check(); if (c != null) return c;
            var r = await _apiClient.DeleteAsync("api/positions", id);
            if (IsAjaxRequest()) return AjaxResponse(r, "Jabatan berhasil dihapus!", "Gagal menghapus jabatan.");
            if (r != null && r.Success)
            {
                TempData["Success"] = "Jabatan berhasil dihapus!";
            }
            else
            {
                TempData["Error"] = r?.Message ?? "Gagal menghapus jabatan.";
            }
            return RedirectToAction("Positions");
        }

        // ============================================================
        // ROLE / HAK AKSES (CRUD)
        // ============================================================
        public async Task<IActionResult> Roles()
        {
            var c = Check(); if (c != null) return c; SetInfo(); ViewData["Title"] = "Role (Hak Akses)";
            var r = await _apiClient.GetAsync("api/roles");
            return View(r != null && r.Success ? JArray.Parse(r.Data ?? "[]") : new JArray());
        }

        public IActionResult RoleCreate()
        {
            var c = Check(); if (c != null) return c; SetInfo(); ViewData["Title"] = "Tambah Role";
            return View();
        }

        [HttpPost]
        public async Task<IActionResult> RoleCreate(string name, string platform)
        {
            var c = Check(); if (c != null) return c; SetInfo(); ViewData["Title"] = "Tambah Role";
            var companyId = GetCompanyId();
            if (!companyId.HasValue)
            {
                ViewBag.Error = "Company ID tidak ditemukan.";
                return View();
            }
            if (string.IsNullOrWhiteSpace(name))
            {
                ViewBag.Error = "Nama role wajib diisi.";
                return View();
            }
            var r = await _apiClient.PostAsync("api/roles", new { Name = name, Platform = platform, CompanyId = companyId.Value });
            if (IsAjaxRequest()) return AjaxResponse(r, "Role berhasil ditambahkan!", "Gagal menambahkan role.");
            if (r != null && r.Success)
            {
                TempData["Success"] = "Role berhasil ditambahkan!";
                return RedirectToAction("Roles");
            }
            ViewBag.Error = r?.Message ?? "Gagal menambahkan role.";
            return View();
        }

        public async Task<IActionResult> RoleEdit(int id)
        {
            var c = Check(); if (c != null) return c; SetInfo(); ViewData["Title"] = "Edit Role";
            var r = await _apiClient.GetByIdAsync("api/roles", id);
            if (r != null && r.Success)
            {
                var role = JObject.Parse(r.Data ?? "{}");
                return View(role);
            }
            TempData["Error"] = "Role tidak ditemukan.";
            return RedirectToAction("Roles");
        }

        [HttpPost]
        public async Task<IActionResult> RoleEdit(int id, string name, string platform)
        {
            var c = Check(); if (c != null) return c; SetInfo(); ViewData["Title"] = "Edit Role";
            var companyId = GetCompanyId();
            if (!companyId.HasValue)
            {
                TempData["Error"] = "Company ID tidak ditemukan.";
                return RedirectToAction("Roles");
            }
            var r = await _apiClient.PutAsync("api/roles", id, new { Name = name, Platform = platform, CompanyId = companyId.Value });
            if (IsAjaxRequest()) return AjaxResponse(r, "Role berhasil diperbarui!", "Gagal memperbarui role.");
            if (r != null && r.Success)
            {
                TempData["Success"] = "Role berhasil diperbarui!";
                return RedirectToAction("Roles");
            }
            ViewBag.Error = r?.Message ?? "Gagal memperbarui role.";
            var roleR = await _apiClient.GetByIdAsync("api/roles", id);
            return View(roleR != null && roleR.Success ? JObject.Parse(roleR.Data ?? "{}") : new JObject());
        }

        [HttpPost]
        public async Task<IActionResult> RoleDelete(int id)
        {
            var c = Check(); if (c != null) return c;
            var r = await _apiClient.DeleteAsync("api/roles", id);
            if (IsAjaxRequest()) return AjaxResponse(r, "Role berhasil dihapus!", "Gagal menghapus role.");
            if (r != null && r.Success)
            {
                TempData["Success"] = "Role berhasil dihapus!";
            }
            else
            {
                TempData["Error"] = r?.Message ?? "Gagal menghapus role.";
            }
            return RedirectToAction("Roles");
        }

        // ============================================================
        // DATA KARYAWAN / USERS (CRUD)
        // ============================================================
        public async Task<IActionResult> Users()
        {
            var c = Check(); if (c != null) return c; SetInfo(); ViewData["Title"] = "Data Karyawan";
            var r = await _apiClient.GetAsync("api/users");
            await LoadDropdowns();
            return View(r != null && r.Success ? JArray.Parse(r.Data ?? "[]") : new JArray());
        }

        public async Task<IActionResult> UserCreate()
        {
            var c = Check(); if (c != null) return c; SetInfo(); ViewData["Title"] = "Tambah Karyawan";
            await LoadDropdowns();
            return View();
        }

        [HttpPost]
        public async Task<IActionResult> UserCreate(string name, string email, int roleId, int? locationId, int? positionId, int? scheduleId)
        {
            var c = Check(); if (c != null) return c; SetInfo(); ViewData["Title"] = "Tambah Karyawan";
            var payload = new
            {
                Name = name,
                Email = email,
                RoleId = roleId,
                LocationId = locationId,
                PositionId = positionId,
                ScheduleId = scheduleId,
                IsActive = true
            };

            var r = await _apiClient.PostAsync("api/users", payload);
            if (IsAjaxRequest()) return AjaxResponse(r, "Karyawan berhasil ditambahkan!", "Gagal menambahkan karyawan.");
            if (r != null && r.Success)
            {
                TempData["Success"] = "Karyawan berhasil ditambahkan! Password telah dikirim ke email: " + email;
                return RedirectToAction("Users");
            }

            ViewBag.Error = r?.Message ?? "Gagal menambahkan karyawan.";
            await LoadDropdowns();
            return View();
        }

        public async Task<IActionResult> UserEdit(int id)
        {
            var c = Check(); if (c != null) return c; SetInfo(); ViewData["Title"] = "Edit Karyawan";
            var r = await _apiClient.GetByIdAsync("api/users", id);
            if (r != null && r.Success)
            {
                await LoadDropdowns();
                var user = JObject.Parse(r.Data ?? "{}");
                return View(user);
            }

            TempData["Error"] = "Karyawan tidak ditemukan.";
            return RedirectToAction("Users");
        }

        [HttpPost]
        public async Task<IActionResult> UserEdit(int id, string name, string email, string? password, int roleId, int? locationId, int? positionId, int? scheduleId, bool isActive)
        {
            var c = Check(); if (c != null) return c; SetInfo(); ViewData["Title"] = "Edit Karyawan";

            var payload = new Dictionary<string, object?>
            {
                ["name"] = name,
                ["email"] = email,
                ["roleId"] = roleId,
                ["locationId"] = locationId,
                ["positionId"] = positionId,
                ["scheduleId"] = scheduleId,
                ["isActive"] = isActive
            };

            if (!string.IsNullOrWhiteSpace(password))
            {
                payload["password"] = password;
            }

            var r = await _apiClient.PutAsync("api/users", id, payload);
            if (IsAjaxRequest()) return AjaxResponse(r, "Data karyawan berhasil diperbarui!", "Gagal memperbarui data karyawan.");
            if (r != null && r.Success)
            {
                TempData["Success"] = "Data karyawan berhasil diperbarui!";
                return RedirectToAction("Users");
            }

            ViewBag.Error = r?.Message ?? "Gagal memperbarui data karyawan.";
            await LoadDropdowns();
            var userR = await _apiClient.GetByIdAsync("api/users", id);
            return View(userR != null && userR.Success ? JObject.Parse(userR.Data ?? "{}") : new JObject());
        }

        [HttpPost]
        public async Task<IActionResult> UserDelete(int id)
        {
            var c = Check(); if (c != null) return c;
            var r = await _apiClient.DeleteAsync("api/users", id);
            if (IsAjaxRequest()) return AjaxResponse(r, "Karyawan berhasil dihapus!", "Gagal menghapus karyawan.");
            if (r != null && r.Success)
            {
                TempData["Success"] = "Karyawan berhasil dihapus!";
            }
            else
            {
                TempData["Error"] = r?.Message ?? "Gagal menghapus karyawan.";
            }
            return RedirectToAction("Users");
        }

        // ============================================================
        // PENGUMUMAN
        // ============================================================
        public async Task<IActionResult> Announcements()
        {
            var c = Check(); if (c != null) return c; SetInfo(); ViewData["Title"] = "Pengumuman";
            var r = await _apiClient.GetAsync("api/announcements");
            var announcements = r != null && r.Success ? JArray.Parse(r.Data ?? "[]") : new JArray();
            if (r == null || !r.Success)
                TempData["Error"] = r?.Message ?? "Gagal memuat pengumuman.";

            var usersR = await _apiClient.GetAsync("api/users");
            ViewBag.Users = usersR != null && usersR.Success ? JArray.Parse(usersR.Data ?? "[]") : new JArray();

            var posR = await _apiClient.GetAsync("api/positions");
            ViewBag.Positions = posR != null && posR.Success ? JArray.Parse(posR.Data ?? "[]") : new JArray();

            return View(announcements);
        }

        [HttpPost]
        public async Task<IActionResult> AnnouncementCreate(string title, string content, string targetType, string? targetIds)
        {
            var c = Check(); if (c != null) return c;
            var r = await _apiClient.PostAsync("api/announcements", new
            {
                Title = title,
                Content = content,
                TargetType = targetType,
                TargetIds = targetIds
            });
            if (IsAjaxRequest()) return AjaxResponse(r, "Pengumuman berhasil dibuat!", "Gagal membuat pengumuman.");
            if (r != null && r.Success) TempData["Success"] = "Pengumuman berhasil dibuat!";
            else TempData["Error"] = r?.Message ?? "Gagal membuat pengumuman.";
            return RedirectToAction("Announcements");
        }

        [HttpGet]
        public async Task<IActionResult> AnnouncementEdit(int id)
        {
            var c = Check(); if (c != null) return c; SetInfo(); ViewData["Title"] = "Edit Pengumuman";
            var r = await _apiClient.GetByIdAsync("api/announcements", id);
            if (r == null || !r.Success)
            {
                TempData["Error"] = r?.Message ?? "Pengumuman tidak ditemukan.";
                return RedirectToAction("Announcements");
            }

            var usersR = await _apiClient.GetAsync("api/users");
            ViewBag.Users = usersR != null && usersR.Success ? JArray.Parse(usersR.Data ?? "[]") : new JArray();
            var posR = await _apiClient.GetAsync("api/positions");
            ViewBag.Positions = posR != null && posR.Success ? JArray.Parse(posR.Data ?? "[]") : new JArray();
            return View(JObject.Parse(r.Data ?? "{}"));
        }

        [HttpPost]
        public async Task<IActionResult> AnnouncementEdit(int id, string title, string content, string targetType, string? targetIds)
        {
            var c = Check(); if (c != null) return c;
            var r = await _apiClient.PutAsync("api/announcements", id, new
            {
                Title = title,
                Content = content,
                TargetType = targetType,
                TargetIds = targetIds
            });
            if (IsAjaxRequest()) return AjaxResponse(r, "Pengumuman berhasil diperbarui!", "Gagal memperbarui pengumuman.");
            if (r != null && r.Success)
            {
                TempData["Success"] = "Pengumuman berhasil diperbarui!";
                return RedirectToAction("Announcements");
            }

            TempData["Error"] = r?.Message ?? "Gagal memperbarui pengumuman.";
            return RedirectToAction("AnnouncementEdit", new { id });
        }

        [HttpPost]
        public async Task<IActionResult> AnnouncementDelete(int id)
        {
            var c = Check(); if (c != null) return c;
            var r = await _apiClient.DeleteAsync("api/announcements", id);
            if (IsAjaxRequest()) return AjaxResponse(r, "Pengumuman berhasil dihapus!", "Gagal menghapus pengumuman.");
            if (r != null && r.Success) TempData["Success"] = "Pengumuman berhasil dihapus!";
            else TempData["Error"] = r?.Message ?? "Gagal menghapus pengumuman.";
            return RedirectToAction("Announcements");
        }

        // ============================================================
        // LEMBUR
        // ============================================================
        public async Task<IActionResult> Overtimes()
        {
            var c = Check(); if (c != null) return c; SetInfo(); ViewData["Title"] = "Penugasan Lembur";
            var r = await _apiClient.GetAsync("api/overtimes");
            var overtimes = r != null && r.Success ? JArray.Parse(r.Data ?? "[]") : new JArray();

            var usersR = await _apiClient.GetAsync("api/users");
            var users = usersR != null && usersR.Success ? JArray.Parse(usersR.Data ?? "[]") : new JArray();
            var schedulesR = await _apiClient.GetAsync("api/schedules");
            var schedules = schedulesR != null && schedulesR.Success ? JArray.Parse(schedulesR.Data ?? "[]") : new JArray();

            ViewBag.Users = users;
            ViewBag.Schedules = schedules;
            return View(overtimes);
        }

        [HttpPost]
        public async Task<IActionResult> OvertimeCreate(string userIds, string date, int scheduleId, string? note)
        {
            var c = Check(); if (c != null) return c;
            var ids = new List<int>();
            foreach (var value in (userIds ?? "").Split(',', StringSplitOptions.RemoveEmptyEntries))
            {
                if (int.TryParse(value, out var id)) ids.Add(id);
            }
            if (ids.Count == 0 || !DateTime.TryParse(date, out var parsedDate) || scheduleId <= 0)
            {
                const string message = "Pilih karyawan, tanggal, dan jadwal lembur dengan benar.";
                if (IsAjaxRequest()) return Json(new { success = false, message });
                TempData["Error"] = message;
                return RedirectToAction("Overtimes");
            }

            var r = await _apiClient.PostAsync("api/overtimes/batch", new
            {
                UserIds = ids,
                Date = parsedDate.ToString("yyyy-MM-dd"),
                ScheduleId = scheduleId,
                Note = note
            });
            if (IsAjaxRequest()) return AjaxResponse(r, "Penugasan lembur berhasil ditugaskan!", "Gagal menugaskan lembur.");

            if (r != null && r.Success)
            {
                TempData["Success"] = "Penugasan lembur berhasil ditugaskan!";
            }
            else TempData["Error"] = r?.Message ?? "Gagal menugaskan lembur.";
            return RedirectToAction("Overtimes");
        }

        [HttpPost]
        public async Task<IActionResult> OvertimeDelete(int id)
        {
            var c = Check(); if (c != null) return c;
            var r = await _apiClient.DeleteAsync("api/overtimes", id);
            if (IsAjaxRequest()) return AjaxResponse(r, "Lembur berhasil dihapus!", "Tidak bisa menghapus lembur yang sudah disetujui.");
            if (r != null && r.Success) TempData["Success"] = "Lembur berhasil dihapus!";
            else TempData["Error"] = r?.Message ?? "Tidak bisa menghapus lembur yang sudah disetujui.";
            return RedirectToAction("Overtimes");
        }

        [HttpPost]
        public async Task<IActionResult> OvertimeReview(int id, bool approved, string? rejectionReason)
        {
            var c = Check(); if (c != null) return c;
            var r = await _apiClient.PutAsync($"api/overtimes/{id}/review", new
            {
                Approved = approved,
                RejectionReason = rejectionReason
            });
            var successMessage = approved ? "Pengajuan lembur disetujui!" : "Pengajuan lembur ditolak.";
            var errorMessage = approved ? "Gagal menyetujui pengajuan lembur." : "Gagal menolak pengajuan lembur.";
            if (IsAjaxRequest()) return AjaxResponse(r, successMessage, errorMessage);
            if (r != null && r.Success) TempData["Success"] = successMessage;
            else TempData["Error"] = r?.Message ?? errorMessage;
            return RedirectToAction("Overtimes");
        }

        [HttpPost]
        public async Task<IActionResult> OvertimeDeleteAll(int[] ids)
        {
            var c = Check(); if (c != null) return c;
            int deleted = 0;
            foreach (var id in ids)
            {
                var r = await _apiClient.DeleteAsync("api/overtimes", id);
                if (r != null && r.Success) deleted++;
            }
            if (deleted > 0) TempData["Success"] = $"{deleted} lembur berhasil dihapus!";
            else TempData["Error"] = "Tidak ada lembur yang bisa dihapus.";
            return RedirectToAction("Overtimes");
        }

        // ============================================================
        // PRESENSI (readonly)
        // ============================================================
        public async Task<IActionResult> Attendances()
        {
            var c = Check(); if (c != null) return c; SetInfo(); ViewData["Title"] = "Rekap Presensi";
            var r = await _apiClient.GetAsync("api/attendances");
            return View(r != null && r.Success ? JArray.Parse(r.Data ?? "[]") : new JArray());
        }

        [HttpPost]
        public async Task<IActionResult> AttendanceDelete(int id)
        {
            var c = Check(); if (c != null) return c;
            var r = await _apiClient.DeleteAsync("api/attendances", id);
            if (IsAjaxRequest()) return AjaxResponse(r, "Data presensi berhasil dihapus!", "Data presensi gagal dihapus.");
            if (r != null && r.Success) TempData["Success"] = "Data presensi berhasil dihapus!";
            else TempData["Error"] = r?.Message ?? "Data presensi gagal dihapus.";
            return RedirectToAction(nameof(Attendances));
        }
    }
}
