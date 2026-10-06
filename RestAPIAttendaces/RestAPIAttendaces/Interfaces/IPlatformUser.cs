namespace RestAPIAttendaces.Interfaces
{
    public interface IPlatformUser
    {
        Task<List<PlatformUser>> GetAll();
        Task<PlatformUser?> GetById(int id);
        Task<PlatformUser?> GetByEmail(string email);
        Task<PlatformUser> Create(PlatformUser user);
        Task<bool> Update(int id, PlatformUser user);
        Task<bool> Delete(int id);
    }
}
