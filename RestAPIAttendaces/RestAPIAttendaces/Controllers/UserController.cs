using Microsoft.AspNetCore.Mvc;
using RestAPIAttendaces.Interfaces;

namespace RestAPIAttendaces.Controllers
{
    [ApiController]
    [Route("api/users")]
    public class UserController : BaseApiController
    {
        private readonly IUser _user;
        private readonly IEmailService _emailService;
        public UserController(IUser user, IEmailService emailService)
        {
            _user = user;
            _emailService = emailService;
        }

        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var companyId = GetCompanyId();
            var all = await _user.GetAll();
            if (companyId.HasValue)
                all = all.Where(u => u.CompanyId == companyId.Value).ToList();
            return Ok(all);
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            var result = await _user.GetById(id);
            if (result == null) return NotFound();
            return Ok(result);
        }

        [HttpPost]
        public async Task<IActionResult> Create([FromBody] User user)
        {
            if (string.IsNullOrWhiteSpace(user.Email))
                return BadRequest(new { Message = "Email wajib diisi" });

            var companyId = GetCompanyId();
            if (companyId.HasValue) user.CompanyId = companyId.Value;

            // Generate random password
            var plainPassword = GenerateRandomPassword();
            user.Password = BCrypt.Net.BCrypt.HashPassword(plainPassword);
            user.CreatedAt = DateTime.Now;

            var result = await _user.Create(user);

            // Kirim email credentials (async, tanpa await agar response cepat)
            _ = Task.Run(async () =>
            {
                try
                {
                    await _emailService.SendCredentialsEmail(
                        user.Email,
                        user.Name,
                        user.Email,
                        plainPassword
                    );
                }
                catch
                {
                    // Email gagal tidak memblokir create user
                }
            });

            return CreatedAtAction(nameof(GetById), new { id = result.Id }, new
            {
                result.Id,
                result.Name,
                result.Email,
                Message = "Karyawan berhasil ditambahkan. Password dikirim ke email."
            });
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, [FromBody] User user)
        {
            var companyId = GetCompanyId();
            if (companyId.HasValue) user.CompanyId = companyId.Value;

            // Hash password only if provided
            if (!string.IsNullOrEmpty(user.Password) && !user.Password.StartsWith("$2a$"))
                user.Password = BCrypt.Net.BCrypt.HashPassword(user.Password);

            var result = await _user.Update(id, user);
            if (!result) return NotFound();
            return Ok(new { Message = "Berhasil diupdate" });
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var (success, error) = await _user.Delete(id);
            if (!success) return BadRequest(new { Message = error ?? "Gagal menghapus" });
            return Ok(new { Message = "Karyawan berhasil dihapus" });
        }

        private string GenerateRandomPassword()
        {
            // 8 karakter: huruf besar + kecil + angka
            const string chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
            var random = new Random();
            return new string(Enumerable.Repeat(chars, 8).Select(s => s[random.Next(s.Length)]).ToArray());
        }
    }
}
