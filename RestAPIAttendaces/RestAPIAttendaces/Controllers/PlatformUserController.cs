using Microsoft.AspNetCore.Mvc;
using RestAPIAttendaces.Interfaces;

namespace RestAPIAttendaces.Controllers
{
    [ApiController]
    [Route("api/platform-users")]
    public class PlatformUserController : ControllerBase
    {
        private readonly IPlatformUser _platformUser;

        public PlatformUserController(IPlatformUser platformUser)
        {
            _platformUser = platformUser;
        }

        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var result = await _platformUser.GetAll();
            return Ok(result);
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            var result = await _platformUser.GetById(id);
            if (result == null) return NotFound(new { Message = "Platform user tidak ditemukan" });
            return Ok(result);
        }

        [HttpPost]
        public async Task<IActionResult> Create([FromBody] PlatformUser user)
        {
            if (string.IsNullOrEmpty(user.Email) || string.IsNullOrEmpty(user.Password))
                return BadRequest(new { Message = "Email dan password wajib diisi" });

            // Check duplicate email
            var existing = await _platformUser.GetByEmail(user.Email);
            if (existing != null)
                return BadRequest(new { Message = "Email sudah terdaftar" });

            user.Password = BCrypt.Net.BCrypt.HashPassword(user.Password);
            var result = await _platformUser.Create(user);
            return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, [FromBody] PlatformUser user)
        {
            // Hash password if provided
            if (!string.IsNullOrEmpty(user.Password))
                user.Password = BCrypt.Net.BCrypt.HashPassword(user.Password);

            var result = await _platformUser.Update(id, user);
            if (!result) return NotFound(new { Message = "Platform user tidak ditemukan" });
            return Ok(new { Message = "Berhasil diupdate" });
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var result = await _platformUser.Delete(id);
            if (!result) return NotFound(new { Message = "Platform user tidak ditemukan" });
            return Ok(new { Message = "Berhasil dihapus" });
        }
    }
}
