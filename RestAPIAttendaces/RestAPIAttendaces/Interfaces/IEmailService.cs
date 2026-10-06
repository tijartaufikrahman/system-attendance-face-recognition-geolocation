namespace RestAPIAttendaces.Interfaces
{
    public interface IEmailService
    {
        Task SendCredentialsEmail(string recipientEmail, string name, string email, string password);
    }
}
