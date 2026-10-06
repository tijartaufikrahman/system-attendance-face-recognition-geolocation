using System.Net;
using System.Net.Mail;
using RestAPIAttendaces.Interfaces;

namespace RestAPIAttendaces.Services
{
    public class EmailService : IEmailService
    {
        private readonly IConfiguration _configuration;

        public EmailService(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        public async Task SendCredentialsEmail(string recipientEmail, string name, string email, string password)
        {
            var host = _configuration["EmailSettings:Host"];
            var port = int.Parse(_configuration["EmailSettings:Port"]!);
            var senderEmail = _configuration["EmailSettings:Email"];
            var senderPassword = _configuration["EmailSettings:Password"];

            using var smtpClient = new SmtpClient(host)
            {
                Port = port,
                Credentials = new NetworkCredential(senderEmail, senderPassword),
                EnableSsl = true
            };

            var mailMessage = new MailMessage
            {
                From = new MailAddress(senderEmail!),
                Subject = "Akun Anda - Sistem Absensi",
                Body = $@"
                    <div style='font-family:Arial,sans-serif;max-width:500px;margin:0 auto;padding:20px;'>
                        <h2 style='color:#111827;border-bottom:1px solid #e5e7eb;padding-bottom:10px;'>Akun Anda Telah Dibuat</h2>
                        <p style='color:#374151;font-size:14px;'>Halo <strong>{name}</strong>,</p>
                        <p style='color:#374151;font-size:14px;'>Akun Anda untuk aplikasi absensi telah dibuat oleh admin. Berikut informasi login Anda:</p>
                        <div style='background:#f9fafb;border:1px solid #e5e7eb;border-radius:8px;padding:16px;margin:16px 0;'>
                            <p style='margin:0 0 8px 0;color:#6b7280;font-size:12px;'>Email:</p>
                            <p style='margin:0 0 12px 0;color:#111827;font-size:14px;font-weight:bold;'>{email}</p>
                            <p style='margin:0 0 8px 0;color:#6b7280;font-size:12px;'>Password:</p>
                            <p style='margin:0;color:#111827;font-size:14px;font-weight:bold;font-family:monospace;background:#e5e7eb;padding:8px;border-radius:4px;'>{password}</p>
                        </div>
                        <p style='color:#dc2626;font-size:13px;'>⚠️ Silakan ganti password Anda setelah login pertama kali demi keamanan.</p>
                        <hr style='border:none;border-top:1px solid #e5e7eb;margin:20px 0;' />
                        <p style='color:#9ca3af;font-size:11px;'>Email ini dikirim otomatis oleh Sistem Absensi. Jika Anda tidak merasa mendaftar, abaikan email ini.</p>
                    </div>",
                IsBodyHtml = true
            };

            mailMessage.To.Add(recipientEmail);

            await smtpClient.SendMailAsync(mailMessage);
        }
    }
}
