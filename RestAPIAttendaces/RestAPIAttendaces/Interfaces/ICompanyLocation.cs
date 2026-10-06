namespace RestAPIAttendaces.Interfaces
{
    public interface ICompanyLocation
    {
        Task<List<CompanyLocation>> GetAll();
        Task<CompanyLocation?> GetById(int id);
        Task<List<CompanyLocation>> GetByCompanyId(int companyId);
        Task<CompanyLocation> Create(CompanyLocation location);
        Task<bool> Update(int id, CompanyLocation location);
        Task<(bool success, string? error)> Delete(int id);
    }
}
