using KondoKoInventorySystem_Backend.Data;
using KondoKoInventorySystem_Backend.DTOs;
using KondoKoInventorySystem_Backend.Models;
using MongoDB.Driver;

namespace KondoKoInventorySystem_Backend.Services;

public class KeysService : IKeysService
{
    private readonly MongoDbContext _context;

    public KeysService(MongoDbContext context)
    {
        _context = context;
    }

    public async Task<List<KeyResponseDto>> GetAllAsync()
    {
        var keys = await _context.Keys.Find(_ => true).ToListAsync();
        return keys.Select(MapToResponse).ToList();
    }

    public async Task<KeyResponseDto?> GetByIdAsync(string id)
    {
        var key = await _context.Keys.Find(k => k.Id == id).FirstOrDefaultAsync();
        return key == null ? null : MapToResponse(key);
    }

    public async Task<KeyResponseDto> CreateAsync(KeyDto dto)
    {
        // ── Barcode uniqueness check ──────────────────────
        if (!string.IsNullOrWhiteSpace(dto.Barcode))
        {
            var existing = await _context.Keys
                .Find(k => k.Barcode == dto.Barcode)
                .FirstOrDefaultAsync();

            if (existing != null)
                throw new InvalidOperationException(
                    $"Barcode '{dto.Barcode}' already exists.");
        }

        var key = new Key
        {
            Barcode    = dto.Barcode,
            OwnersName = dto.OwnersName,
            Unit       = dto.Unit,
            KeyType    = dto.KeyType,
            UnitStatus = dto.UnitStatus,
            KeyHolder  = dto.KeyHolder,
            KeyCode    = dto.KeyCode,
            Date       = dto.Date
        };

        await _context.Keys.InsertOneAsync(key);
        return MapToResponse(key);
    }

    public async Task<KeyResponseDto?> UpdateAsync(string id, KeyDto dto)
    {
        var update = Builders<Key>.Update
            .Set(k => k.Barcode,    dto.Barcode)
            .Set(k => k.OwnersName, dto.OwnersName)
            .Set(k => k.Unit,       dto.Unit)
            .Set(k => k.KeyType,    dto.KeyType)
            .Set(k => k.UnitStatus, dto.UnitStatus)
            .Set(k => k.KeyHolder,  dto.KeyHolder)
            .Set(k => k.KeyCode,    dto.KeyCode)
            .Set(k => k.Date,       dto.Date);

        var result = await _context.Keys.UpdateOneAsync(k => k.Id == id, update);

        if (result.MatchedCount == 0) return null;

        return await GetByIdAsync(id);
    }

    public async Task<bool> DeleteAsync(string id)
    {
        var result = await _context.Keys.DeleteOneAsync(k => k.Id == id);
        return result.DeletedCount > 0;
    }

    private static KeyResponseDto MapToResponse(Key key) => new()
    {
        Id         = key.Id ?? "",
        Barcode    = key.Barcode,
        OwnersName = key.OwnersName,
        Unit       = key.Unit,
        KeyType    = key.KeyType,
        UnitStatus = key.UnitStatus,
        KeyHolder  = key.KeyHolder,
        KeyCode    = key.KeyCode,
        Date       = key.Date
    };
}