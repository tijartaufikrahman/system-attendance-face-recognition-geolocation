using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace RestAPIAttendaces.Controllers
{
    [Route("api/face-embeddings")]
    public class FaceEmbeddingController : BaseApiController
    {
        private readonly AppDbContext _db;
        private readonly IWebHostEnvironment _environment;

        public FaceEmbeddingController(AppDbContext db, IWebHostEnvironment environment)
        {
            _db = db;
            _environment = environment;
        }

        [HttpGet("me")]
        public async Task<IActionResult> GetMine()
        {
            var userId = GetUserId();
            if (userId <= 0) return Unauthorized();

            var embeddings = await _db.FaceEmbedding
                .AsNoTracking()
                .Where(item => item.UserId == userId)
                .ToListAsync();

            return Ok(new { registered = embeddings.Count > 0 });
        }

        [HttpGet("me/vector")]
        public async Task<IActionResult> GetMyVector()
        {
            var userId = GetUserId();
            if (userId <= 0) return Unauthorized();

            var embeddings = await _db.FaceEmbedding
                .AsNoTracking()
                .Where(item => item.UserId == userId)
                .ToListAsync();
            if (embeddings.Count == 0)
                return NotFound(new { Message = "Data wajah belum terdaftar." });

            var vectors = new List<List<float>>();
            foreach (var embedding in embeddings)
            {
                try
                {
                    using var document = JsonDocument.Parse(embedding.EmbeddingVector);
                    if (document.RootElement.ValueKind != JsonValueKind.Array ||
                        document.RootElement.GetArrayLength() == 0)
                        continue;

                    if (document.RootElement[0].ValueKind == JsonValueKind.Array)
                    {
                        var poseVectors = JsonSerializer.Deserialize<List<List<float>>>(
                            embedding.EmbeddingVector);
                        if (poseVectors != null)
                            vectors.AddRange(poseVectors.Where(vector => vector.Count > 0));
                    }
                    else
                    {
                        var vector = JsonSerializer.Deserialize<List<float>>(
                            embedding.EmbeddingVector);
                        if (vector != null && vector.Count > 0) vectors.Add(vector);
                    }
                }
                catch (JsonException)
                {
                    // Skip corrupt legacy embedding records.
                }
            }

            if (vectors.Count == 0)
                return StatusCode(500, new { Message = "Data embedding wajah tidak valid." });

            return Ok(new { embeddings = vectors });
        }

        [HttpPost("me")]
        public async Task<IActionResult> SaveMine(
            [FromForm] string embeddingsJson,
            [FromForm] List<IFormFile> photos)
        {
            var userId = GetUserId();
            if (userId <= 0) return Unauthorized();

            List<List<float>>? embeddings;
            try
            {
                embeddings = JsonSerializer.Deserialize<List<List<float>>>(embeddingsJson);
            }
            catch (JsonException)
            {
                embeddings = null;
            }

            if (embeddings == null || embeddings.Count != 3 || embeddings.Any(vector => vector.Count == 0))
                return BadRequest(new { Message = "Embedding wajah wajib diisi." });

            if (embeddings.Any(vector => vector.Any(value => float.IsNaN(value) || float.IsInfinity(value))))
                return BadRequest(new { Message = "Embedding wajah tidak valid." });

            if (photos == null || photos.Count != 3)
                return BadRequest(new { Message = "Tiga foto wajah wajib dikirim." });

            var folder = Path.Combine(
                _environment.WebRootPath ?? Path.Combine(_environment.ContentRootPath, "wwwroot"),
                "uploads",
                "faces",
                userId.ToString());
            foreach (var photo in photos)
            {
                if (photo.Length == 0)
                    return BadRequest(new { Message = "Foto wajah tidak boleh kosong." });

                var extension = Path.GetExtension(photo.FileName).ToLowerInvariant();
                if (extension is not ".jpg" and not ".jpeg" and not ".png")
                    return BadRequest(new { Message = "Foto harus berformat JPG atau PNG." });
            }

            if (Directory.Exists(folder))
                Directory.Delete(folder, recursive: true);
            Directory.CreateDirectory(folder);
            var savedFiles = new List<string>();
            foreach (var photo in photos)
            {
                var extension = Path.GetExtension(photo.FileName).ToLowerInvariant();
                var fileName = $"{DateTime.UtcNow:yyyyMMddHHmmssfff}_{Guid.NewGuid():N}{extension}";
                var path = Path.Combine(folder, fileName);
                await using var stream = System.IO.File.Create(path);
                await photo.CopyToAsync(stream);
                savedFiles.Add(Path.Combine("uploads", "faces", userId.ToString(), fileName));
            }

            var previousEmbeddings = await _db.FaceEmbedding
                .Where(item => item.UserId == userId)
                .ToListAsync();

            var now = DateTime.Now;
            var faceEmbedding = previousEmbeddings.FirstOrDefault();
            if (faceEmbedding == null)
            {
                faceEmbedding = new FaceEmbedding
                {
                    UserId = userId,
                    EmbeddingVector = JsonSerializer.Serialize(embeddings),
                    CreatedAt = now,
                    CreatedBy = userId
                };
                _db.FaceEmbedding.Add(faceEmbedding);
            }
            else
            {
                faceEmbedding.EmbeddingVector = JsonSerializer.Serialize(embeddings);
                faceEmbedding.UpdatedAt = now;
                faceEmbedding.UpdatedBy = userId;
                _db.FaceEmbedding.RemoveRange(previousEmbeddings.Skip(1));
            }

            await _db.SaveChangesAsync();
            return Ok(new
            {
                registered = true,
                embeddingCount = embeddings.Count,
                embeddingSize = embeddings[0].Count,
                photos = savedFiles
            });
        }

        [HttpDelete("me")]
        public async Task<IActionResult> DeleteMine()
        {
            var userId = GetUserId();
            if (userId <= 0) return Unauthorized();

            var faceEmbeddings = await _db.FaceEmbedding
                .Where(item => item.UserId == userId)
                .ToListAsync();
            if (faceEmbeddings.Count == 0)
                return NotFound(new { Message = "Data wajah belum terdaftar." });

            var folder = Path.Combine(
                _environment.WebRootPath ?? Path.Combine(_environment.ContentRootPath, "wwwroot"),
                "uploads",
                "faces",
                userId.ToString());

            if (Directory.Exists(folder))
                Directory.Delete(folder, recursive: true);

            _db.FaceEmbedding.RemoveRange(faceEmbeddings);
            await _db.SaveChangesAsync();
            return Ok(new { Message = "Data wajah berhasil dihapus." });
        }
    }
}
