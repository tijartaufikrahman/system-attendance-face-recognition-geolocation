using Microsoft.AspNetCore.Mvc;
using RestAPIAttendaces.DTOs;
using RestAPIAttendaces.Interfaces;

namespace RestAPIAttendaces.Controllers
{
    [ApiController]
    [Route("api/auth")]
    public class AuthController : ControllerBase
    {
        private readonly IAuth _auth;

        public AuthController(IAuth auth)
        {
            _auth = auth;
        }

        /// <summary>
        /// Login untuk Company Users (Admin HR, Employee)
        /// </summary>
        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginRequest request)
        {
            try
            {
                if (string.IsNullOrEmpty(request.Email) || string.IsNullOrEmpty(request.Password))
                    return BadRequest(new { Message = "Email dan Password wajib diisi" });

                var result = await _auth.Login(request.Email, request.Password);
                // Pesan error sama untuk semua case (security: jangan bocorkan info)
                if (result == null || string.IsNullOrEmpty(result.Token))
                    return Unauthorized(new { Message = "Email atau password salah" });

                return Ok(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Message = "Terjadi kesalahan saat login", Error = ex.Message });
            }
        }

        /// <summary>
        /// Login untuk Mobile (Employee / Admin HR via Mobile App)
        /// </summary>
        [HttpPost("mobile/login")]
        public async Task<IActionResult> MobileLogin([FromBody] LoginRequest request)
        {
            try
            {
                if (string.IsNullOrEmpty(request.Email) || string.IsNullOrEmpty(request.Password))
                    return BadRequest(new { Message = "Email dan Password wajib diisi" });

                var result = await _auth.MobileLogin(request.Email, request.Password);
                if (result == null || string.IsNullOrEmpty(result.Token))
                    return Unauthorized(new { Message = "Email atau password salah" });

                return Ok(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Message = "Terjadi kesalahan saat login", Error = ex.Message });
            }
        }

        /// <summary>
        /// Login untuk Platform Super Admin (provider platform)
        /// </summary>
        [HttpPost("platform/login")]
        public async Task<IActionResult> PlatformLogin([FromBody] LoginRequest request)
        {
            try
            {
                if (string.IsNullOrEmpty(request.Email) || string.IsNullOrEmpty(request.Password))
                    return BadRequest(new { Message = "Email dan Password wajib diisi" });

                var result = await _auth.PlatformLogin(request.Email, request.Password);
                // Pesan error sama untuk semua case (security)
                if (result == null) return Unauthorized(new { Message = "Email atau password salah" });

                return Ok(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Message = "Terjadi kesalahan saat login", Error = ex.Message });
            }
        }

        [HttpPost("forgot-password")]
        public async Task<IActionResult> ForgotPassword([FromBody] ForgotPasswordRequest request)
        {
            try
            {
                var result = await _auth.ForgotPassword(request.Email);
                if (result.Success) return Ok(new { Message = result.Message });
                return BadRequest(new { Message = result.Message });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Message = ex.Message });
            }
        }

        [HttpPost("verify-otp")]
        public async Task<IActionResult> VerifyOtp([FromForm] string email, [FromForm] string otp)
        {
            try
            {
                var result = await _auth.VerifyOtp(email, otp);
                if (result.Success) return Ok(new { Success = true, Message = result.Message });
                return BadRequest(new { Success = false, Message = result.Message });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Success = false, Message = ex.Message });
            }
        }

        [HttpPost("reset-password")]
        public async Task<IActionResult> ResetPassword([FromForm] string email, [FromForm] string otp, [FromForm] string password)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(password))
                    return BadRequest(new { Success = false, Message = "Password baru tidak boleh kosong" });

                var result = await _auth.ResetPassword(email, otp, password);
                if (result.Success) return Ok(new { Success = true, Message = result.Message });
                return BadRequest(new { Success = false, Message = result.Message });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Success = false, Message = ex.Message });
            }
        }
    }
}
