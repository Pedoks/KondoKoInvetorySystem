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

    // ── MODIFIED: CreateAsync with grouping support ──────────────────────
    public async Task<KeyResponseDto> CreateAsync(KeyDto dto)
    {
        // Barcode uniqueness check
        if (!string.IsNullOrWhiteSpace(dto.Barcode))
        {
            var existing = await _context.Keys
                .Find(k => k.Barcode == dto.Barcode)
                .FirstOrDefaultAsync();

            if (existing != null)
                throw new InvalidOperationException($"Barcode '{dto.Barcode}' already exists.");
        }

        // Check if a group already exists with same OwnersName and Unit
        var existingGroupKey = await _context.Keys
            .Find(k => k.OwnersName == dto.OwnersName && k.Unit == dto.Unit && k.GroupId != null)
            .FirstOrDefaultAsync();

        string? groupId = existingGroupKey?.GroupId;

        var key = new Key
        {
            Barcode = dto.Barcode,
            OwnersName = dto.OwnersName,
            Unit = dto.Unit,
            KeyType = dto.KeyType,
            UnitStatus = dto.UnitStatus,
            KeyHolder = dto.KeyHolder,
            KeyCode = dto.KeyCode,
            Date = dto.Date,
            GroupId = groupId ?? null
        };

        await _context.Keys.InsertOneAsync(key);

        // If this is the first key in a potential group, update its GroupId to its own Id
        if (groupId == null && key.Id != null)
        {
            var update = Builders<Key>.Update.Set(k => k.GroupId, key.Id);
            await _context.Keys.UpdateOneAsync(k => k.Id == key.Id, update);
            key.GroupId = key.Id;
        }

        return MapToResponse(key);
    }

    public async Task<KeyResponseDto?> UpdateAsync(string id, KeyDto dto)
    {
        var update = Builders<Key>.Update
            .Set(k => k.Barcode, dto.Barcode)
            .Set(k => k.OwnersName, dto.OwnersName)
            .Set(k => k.Unit, dto.Unit)
            .Set(k => k.KeyType, dto.KeyType)
            .Set(k => k.UnitStatus, dto.UnitStatus)
            .Set(k => k.KeyHolder, dto.KeyHolder)
            .Set(k => k.KeyCode, dto.KeyCode)
            .Set(k => k.Date, dto.Date);

        var result = await _context.Keys.UpdateOneAsync(k => k.Id == id, update);

        if (result.MatchedCount == 0) return null;

        return await GetByIdAsync(id);
    }

    public async Task<bool> DeleteAsync(string id)
    {
        var result = await _context.Keys.DeleteOneAsync(k => k.Id == id);
        return result.DeletedCount > 0;
    }

    // ── NEW: Get all groups ──────────────────────────────────────────────
    public async Task<List<KeyGroupResponseDto>> GetAllGroupsAsync()
    {
        var allKeys = await _context.Keys.Find(_ => true).ToListAsync();

        // Group by composite key (GroupId)
        var groups = allKeys
            .Where(k => !string.IsNullOrEmpty(k.GroupId))
            .GroupBy(k => k.GroupId)
            .Select(g => MapToGroupResponse(g.Key!, g.ToList()))
            .OrderBy(g => g.Unit)
            .ToList();

        // Also include standalone keys (no group) as their own groups
        var standaloneKeys = allKeys.Where(k => string.IsNullOrEmpty(k.GroupId)).ToList();
        foreach (var key in standaloneKeys)
        {
            groups.Add(MapToGroupResponse(key.Id!, new List<Key> { key }));
        }

        return groups;
    }

    // ── NEW: Get group by ID ─────────────────────────────────────────────
    public async Task<KeyGroupResponseDto?> GetGroupByIdAsync(string groupId)
    {
        var keys = await _context.Keys.Find(k => k.GroupId == groupId).ToListAsync();
        if (keys == null || keys.Count == 0) return null;

        // Get the representative key for group info
        var repKey = keys.First();

        // Get all active transactions to calculate availability
        var activeTransactions = await _context.KeyTransactions
            .Find(t => t.Status == "CheckedOut")
            .ToListAsync();

        var checkedOutKeyIds = activeTransactions.Select(t => t.KeyId).ToHashSet();
        var availableCount = keys.Count(k => !checkedOutKeyIds.Contains(k.Id));

        return new KeyGroupResponseDto
        {
            GroupId = groupId,
            OwnersName = repKey.OwnersName,
            Unit = repKey.Unit,
            UnitStatus = repKey.UnitStatus,
            KeyHolder = repKey.KeyHolder,
            KeyCode = repKey.KeyCode,
            Date = repKey.Date,
            TotalKeys = keys.Count,
            AvailableKeys = availableCount,
            Keys = keys.Select(MapToResponse).ToList()
        };
    }

    // ── NEW: Add key to existing group ───────────────────────────────────
    public async Task<KeyResponseDto> AddKeyToGroupAsync(AddKeyToGroupDto dto)
    {
        // Verify group exists
        var existingGroup = await _context.Keys.Find(k => k.GroupId == dto.GroupId).FirstOrDefaultAsync();
        if (existingGroup == null)
            throw new KeyNotFoundException($"Group '{dto.GroupId}' not found.");

        // Check barcode uniqueness
        var existingBarcode = await _context.Keys.Find(k => k.Barcode == dto.Barcode).FirstOrDefaultAsync();
        if (existingBarcode != null)
            throw new InvalidOperationException($"Barcode '{dto.Barcode}' already exists.");

        var newKey = new Key
        {
            Barcode = dto.Barcode,
            OwnersName = existingGroup.OwnersName,
            Unit = existingGroup.Unit,
            KeyType = dto.KeyType,
            UnitStatus = existingGroup.UnitStatus,
            KeyHolder = existingGroup.KeyHolder,
            KeyCode = existingGroup.KeyCode,
            Date = existingGroup.Date,
            GroupId = dto.GroupId
        };

        await _context.Keys.InsertOneAsync(newKey);
        return MapToResponse(newKey);
    }

    // ── Private mapping methods ─────────────────────────────────────────
    private static KeyResponseDto MapToResponse(Key key) => new()
    {
        Id = key.Id ?? "",
        Barcode = key.Barcode,
        OwnersName = key.OwnersName,
        Unit = key.Unit,
        KeyType = key.KeyType,
        UnitStatus = key.UnitStatus,
        KeyHolder = key.KeyHolder,
        KeyCode = key.KeyCode,
        Date = key.Date
    };

    private KeyGroupResponseDto MapToGroupResponse(string groupId, List<Key> keys)
    {
        var repKey = keys.First();

        // Get all active transactions to calculate availability
        // Note: This is a simplified calculation - you may want to optimize this
        var activeTransactions = _context.KeyTransactions
            .Find(t => t.Status == "CheckedOut")
            .ToList();
        
        var checkedOutKeyIds = activeTransactions.Select(t => t.KeyId).ToHashSet();
        var availableCount = keys.Count(k => !checkedOutKeyIds.Contains(k.Id));

        return new KeyGroupResponseDto
        {
            GroupId = groupId,
            OwnersName = repKey.OwnersName,
            Unit = repKey.Unit,
            UnitStatus = repKey.UnitStatus,
            KeyHolder = repKey.KeyHolder,
            KeyCode = repKey.KeyCode,
            Date = repKey.Date,
            TotalKeys = keys.Count,
            AvailableKeys = availableCount,
            Keys = keys.Select(MapToResponse).ToList()
        };
    }
}