namespace RestAPIAttendaces.Interfaces
{
    public interface IUser
    {
        Task<List<User>> GetAll();
        Task<User?> GetById(int id);
        Task<User> Create(User user);
        Task<bool> Update(int id, User user);
        Task<(bool success, string? error)> Delete(int id);
    }
}
