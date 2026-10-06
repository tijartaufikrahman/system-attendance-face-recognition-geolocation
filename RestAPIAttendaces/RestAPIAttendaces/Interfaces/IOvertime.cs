namespace RestAPIAttendaces.Interfaces
{
    public interface IOvertime
    {
        Task<List<Overtime>> GetAll(int? companyId = null);
        Task<Overtime?> GetById(int id);
        Task<List<Overtime>> GetByUserId(int userId, int? companyId = null);
        Task<Overtime> Create(Overtime overtime);
        Task<bool> Update(int id, Overtime overtime);
        Task<bool> Delete(int id);
    }
}
