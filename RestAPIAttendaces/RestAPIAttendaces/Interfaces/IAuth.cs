using RestAPIAttendaces.DTOs;

namespace RestAPIAttendaces.Interfaces
{
    public interface IAuth
    {
        Task<LoginResponse?> Login(string email, string password);
        Task<LoginResponse?> MobileLogin(string email, string password);
        Task<LoginResponse?> PlatformLogin(string email, string password);
        Task<AuthResult> ForgotPassword(string email);
        Task<AuthResult> VerifyOtp(string email, string otp);
        Task<AuthResult> ResetPassword(string email, string otp, string password);
    }
}
