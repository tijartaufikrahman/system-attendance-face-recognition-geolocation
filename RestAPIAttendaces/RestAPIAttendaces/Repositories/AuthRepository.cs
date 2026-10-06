using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using RestAPIAttendaces.DTOs;
using RestAPIAttendaces.Interfaces;

public class AuthRepository : IAuth
{
    private readonly AppDbContext _context;
    private readonly IConfiguration _configuration;

    public AuthRepository(AppDbContext context, IConfiguration configuration)
    {
        _context = context;
        _configuration = configuration;
    }

    // ============================================================
    // LOGIN COMPANY (Admin HR / Employee)
    // Cek: user.is_active = true DAN company.is_active = true
    // ============================================================
    public async Task<LoginResponse?> Login(string email, string password)
    {
        var userWithRole = await (from u in _context.User
                                  join r in _context.Role on u.RoleId equals r.Id
                                  join c in _context.Company on u.CompanyId equals c.Id
                                  where u.Email == email
                                  select new
                                  {
                                      u.Id,
                                      u.Name,
                                      u.Email,
                                      u.CompanyId,
                                      u.RoleId,
                                      u.Password,
                                      UserIsActive = u.IsActive,
                                      CompanyIsActive = c.IsActive,
                                      CompanyName = c.Name,
                                      RoleName = r.Name,
                                      Platform = r.Platform
                                  }).FirstOrDefaultAsync();

        if (userWithRole == null) return null;

        // Cek user aktif
        if (!userWithRole.UserIsActive) return null;

        // Cek company aktif
        if (!userWithRole.CompanyIsActive) return null;

        // Verifikasi password
        if (!VerifyPassword(password, userWithRole.Password)) return null;

        // Cek platform: hanya role 'web' yang bisa login ke website
        // Jangan beri pesan spesifik, samakan saja dengan "login gagal"
        if (userWithRole.Platform != "web")
            return null;

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, userWithRole.Id.ToString()),
            new Claim(ClaimTypes.Name, userWithRole.Email),
            new Claim(ClaimTypes.Role, userWithRole.RoleName),
            new Claim("company_id", userWithRole.CompanyId.ToString()),
            new Claim("platform", userWithRole.Platform),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        var token = GenerateJwtToken(claims);

        return new LoginResponse
        {
            Id = userWithRole.Id,
            Token = token,
            Name = userWithRole.Name,
            Email = userWithRole.Email,
            RoleId = userWithRole.RoleId,
            Role = userWithRole.RoleName,
            CompanyId = userWithRole.CompanyId,
            Message = "Login Berhasil"
        };
    }

    // ============================================================
    // LOGIN MOBILE (Employee / Admin HR via Mobile)
    // Cek: user.is_active = true DAN company.is_active = true
    // Platform harus 'mobile'
    // ============================================================
    public async Task<LoginResponse?> MobileLogin(string email, string password)
    {
        var userWithRole = await (from u in _context.User
                                  join r in _context.Role on u.RoleId equals r.Id
                                  join c in _context.Company on u.CompanyId equals c.Id
                                  where u.Email == email
                                  select new
                                  {
                                      u.Id,
                                      u.Name,
                                      u.Email,
                                      u.CompanyId,
                                      u.RoleId,
                                      u.Password,
                                      UserIsActive = u.IsActive,
                                      CompanyIsActive = c.IsActive,
                                      CompanyName = c.Name,
                                      RoleName = r.Name,
                                      Platform = r.Platform
                                  }).FirstOrDefaultAsync();

        if (userWithRole == null) return null;

        // Cek user aktif
        if (!userWithRole.UserIsActive) return null;

        // Cek company aktif
        if (!userWithRole.CompanyIsActive) return null;

        // Verifikasi password
        if (!VerifyPassword(password, userWithRole.Password)) return null;

        // Cek platform: hanya role 'mobile' yang bisa login ke mobile app
        if (userWithRole.Platform != "mobile")
            return null;

        // Update last login
        var user = await _context.User.FindAsync(userWithRole.Id);
        if (user != null)
        {
            user.LastLoginAt = DateTime.Now;
            await _context.SaveChangesAsync();
        }

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, userWithRole.Id.ToString()),
            new Claim(ClaimTypes.Name, userWithRole.Email),
            new Claim(ClaimTypes.Role, userWithRole.RoleName),
            new Claim("company_id", userWithRole.CompanyId.ToString()),
            new Claim("platform", "mobile"),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        var token = GenerateJwtToken(claims);

        return new LoginResponse
        {
            Id = userWithRole.Id,
            Token = token,
            Name = userWithRole.Name,
            Email = userWithRole.Email,
            RoleId = userWithRole.RoleId,
            Role = userWithRole.RoleName,
            CompanyId = userWithRole.CompanyId,
            Message = "Login Berhasil"
        };
    }

    // ============================================================
    // LOGIN PLATFORM (Super Admin)
    // Cek: platform_users.is_active = true
    // ============================================================
    public async Task<LoginResponse?> PlatformLogin(string email, string password)
    {
        var platformUser = await _context.PlatformUser
            .FirstOrDefaultAsync(u => u.Email == email);

        if (platformUser == null) return null;

        // Cek akun aktif
        if (!platformUser.IsActive) return null;

        // Verifikasi password
        if (!VerifyPassword(password, platformUser.Password)) return null;

        // Update last login
        platformUser.LastLoginAt = DateTime.Now;
        await _context.SaveChangesAsync();

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, platformUser.Id.ToString()),
            new Claim(ClaimTypes.Name, platformUser.Email),
            new Claim(ClaimTypes.Role, "Superadmin"),
            new Claim("platform", "web"),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        var token = GenerateJwtToken(claims);

        return new LoginResponse
        {
            Id = platformUser.Id,
            Token = token,
            Name = platformUser.Name,
            Email = platformUser.Email,
            RoleId = 0,
            Role = "Superadmin",
            CompanyId = null,
            Message = "Login Berhasil"
        };
    }

    // ============================================================
    // HELPERS
    // ============================================================
    private bool VerifyPassword(string inputPassword, string hashedPassword)
    {
        try
        {
            return BCrypt.Net.BCrypt.Verify(inputPassword, hashedPassword);
        }
        catch (BCrypt.Net.SaltParseException)
        {
            return false;
        }
    }

    private string GenerateJwtToken(Claim[] claims)
    {
        var jwtKey = _configuration["Jwt:Key"] ?? "IniKunciRahasiaAttendanceAPI2026YangSangatPanjangSekali123";
        var securityKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey));
        var credentials = new SigningCredentials(securityKey, SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: _configuration["Jwt:Issuer"],
            audience: _configuration["Jwt:Audience"],
            claims: claims,
            expires: DateTime.Now.AddHours(24),
            signingCredentials: credentials);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    public async Task<AuthResult> ForgotPassword(string email)
    {
        var user = await _context.User.FirstOrDefaultAsync(x => x.Email == email);
        if (user == null) return new AuthResult { Success = false, Message = "Email tidak ditemukan" };

        var otp = new Random().Next(100000, 999999).ToString();
        user.TokenAt = otp;
        user.TokenExpiredAt = DateTime.Now.AddMinutes(5);
        await _context.SaveChangesAsync();

        return new AuthResult { Success = true, Message = "OTP berhasil dibuat" };
    }

    public async Task<AuthResult> VerifyOtp(string email, string otp)
    {
        var user = await _context.User.FirstOrDefaultAsync(x => x.Email == email);
        if (user == null) return new AuthResult { Success = false, Message = "Email tidak ditemukan" };
        if (string.IsNullOrEmpty(user.TokenAt)) return new AuthResult { Success = false, Message = "OTP belum dibuat" };
        if (user.TokenAt != otp) return new AuthResult { Success = false, Message = "OTP tidak valid" };
        if (user.TokenExpiredAt == null || user.TokenExpiredAt < DateTime.Now) return new AuthResult { Success = false, Message = "OTP sudah kadaluarsa" };
        return new AuthResult { Success = true, Message = "OTP valid" };
    }

    public async Task<AuthResult> ResetPassword(string email, string otp, string password)
    {
        var user = await _context.User.FirstOrDefaultAsync(x => x.Email == email);
        if (user == null) return new AuthResult { Success = false, Message = "Email tidak ditemukan" };
        if (user.TokenAt != otp) return new AuthResult { Success = false, Message = "OTP tidak valid" };
        if (user.TokenExpiredAt == null || user.TokenExpiredAt < DateTime.Now) return new AuthResult { Success = false, Message = "OTP sudah kadaluarsa" };

        user.Password = BCrypt.Net.BCrypt.HashPassword(password);
        user.TokenAt = null;
        user.TokenExpiredAt = null;
        await _context.SaveChangesAsync();

        return new AuthResult { Success = true, Message = "Password berhasil diubah" };
    }
}
