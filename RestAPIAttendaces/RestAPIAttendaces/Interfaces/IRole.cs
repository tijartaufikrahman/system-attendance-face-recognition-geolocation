namespace RestAPIAttendaces.Interfaces
{
    public interface IRole
    {
        Task<List<Role>> GetAll();
        Task<Role?> GetById(int id);
        Task<Role> Create(Role role);
        Task<bool> Update(int id, Role role);
        Task<(bool success, string? error)> Delete(int id);
    }
}
