using KondoKoInventorySystem_Backend.Data;
using KondoKoInventorySystem_Backend.DTOs;
using KondoKoInventorySystem_Backend.Models;
using MongoDB.Driver;

namespace KondoKoInventorySystem_Backend.Services;

public class KeyTransactionService : IKeyTransactionService
{
    private readonly MongoDbContext _context;

    public KeyTransactionService(MongoDbContext context)
    {
        _context = context;
    }

    // ── Scan barcode → return key status ─────────────────
    public async Task<KeyScanResultDto> ScanBarcodeAsync(string barcode)
    {
        var key = await _context.Keys
            .Find(k => k.Barcode == barcode)
            .FirstOrDefaultAsync();

        if (key == null)
            throw new KeyNotFoundException($"No key found with barcode '{barcode}'.");

        // Check if currently checked out
        var activeTransaction = await _context.KeyTransactions
            .Find(t => t.KeyId == key.Id && t.Status == "CheckedOut")
            .FirstOrDefaultAsync();

        return new KeyScanResultDto
        {
            KeyId        = key.Id ?? "",
            Barcode      = key.Barcode,
            Unit         = key.Unit,
            KeyType      = key.KeyType,
            Status       = activeTransaction == null ? "Available" : "CheckedOut",
            CheckedOutBy = activeTransaction?.UserName
        };
    }

    // ── Check Out ─────────────────────────────────────────
    public async Task<KeyTransactionResponseDto> CheckOutAsync(
        string barcode, string userId, string userName)
    {
        var key = await _context.Keys
            .Find(k => k.Barcode == barcode)
            .FirstOrDefaultAsync()
            ?? throw new KeyNotFoundException(
                $"No key found with barcode '{barcode}'.");

        // Already checked out?
        var existing = await _context.KeyTransactions
            .Find(t => t.KeyId == key.Id && t.Status == "CheckedOut")
            .FirstOrDefaultAsync();

        if (existing != null)
            throw new InvalidOperationException(
                $"Key '{key.Unit}' is already checked out by {existing.UserName}.");

        var transaction = new KeyTransaction
        {
            KeyId        = key.Id ?? "",
            Barcode      = key.Barcode,
            Unit         = key.Unit,
            UserId       = userId,
            UserName     = userName,
            CheckOutDate = DateTime.UtcNow,
            CheckInDate  = null,
            Status       = "CheckedOut"
        };

        await _context.KeyTransactions.InsertOneAsync(transaction);
        return MapToResponse(transaction);
    }

    // ── Check In ──────────────────────────────────────────
    public async Task<KeyTransactionResponseDto> CheckInAsync(
        string barcode, string userId)
    {
        var key = await _context.Keys
            .Find(k => k.Barcode == barcode)
            .FirstOrDefaultAsync()
            ?? throw new KeyNotFoundException(
                $"No key found with barcode '{barcode}'.");

        var transaction = await _context.KeyTransactions
            .Find(t => t.KeyId == key.Id && t.Status == "CheckedOut")
            .FirstOrDefaultAsync()
            ?? throw new InvalidOperationException(
                $"Key '{key.Unit}' is not currently checked out.");

        var update = Builders<KeyTransaction>.Update
            .Set(t => t.CheckInDate, DateTime.UtcNow)
            .Set(t => t.Status, "CheckedIn");

        await _context.KeyTransactions.UpdateOneAsync(
            t => t.Id == transaction.Id, update);

        transaction.CheckInDate = DateTime.UtcNow;
        transaction.Status      = "CheckedIn";

        return MapToResponse(transaction);
    }

    // ── My Active (currently checked out by me) ───────────
    public async Task<List<KeyTransactionResponseDto>> GetMyActiveAsync(string userId)
    {
        var transactions = await _context.KeyTransactions
            .Find(t => t.UserId == userId && t.Status == "CheckedOut")
            .SortByDescending(t => t.CheckOutDate)
            .ToListAsync();

        return transactions.Select(MapToResponse).ToList();
    }

    // ── My History ────────────────────────────────────────
    public async Task<List<KeyTransactionResponseDto>> GetMyHistoryAsync(string userId)
    {
        var transactions = await _context.KeyTransactions
            .Find(t => t.UserId == userId)
            .SortByDescending(t => t.CheckOutDate)
            .ToListAsync();

        return transactions.Select(MapToResponse).ToList();
    }

    // ── Global History ────────────────────────────────────
    public async Task<List<KeyTransactionResponseDto>> GetGlobalHistoryAsync()
    {
        var transactions = await _context.KeyTransactions
            .Find(_ => true)
            .SortByDescending(t => t.CheckOutDate)
            .ToListAsync();

        return transactions.Select(MapToResponse).ToList();
    }

    // ── Map ───────────────────────────────────────────────
    private static KeyTransactionResponseDto MapToResponse(KeyTransaction t) => new()
    {
        Id           = t.Id ?? "",
        KeyId        = t.KeyId,
        Barcode      = t.Barcode,
        Unit         = t.Unit,
        UserId       = t.UserId,
        UserName     = t.UserName,
        CheckOutDate = t.CheckOutDate,
        CheckInDate  = t.CheckInDate,
        Status       = t.Status
    };
}