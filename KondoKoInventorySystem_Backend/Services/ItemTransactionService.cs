using KondoKoInventorySystem_Backend.Data;
using KondoKoInventorySystem_Backend.DTOs;
using KondoKoInventorySystem_Backend.Models;
using MongoDB.Driver;

namespace KondoKoInventorySystem_Backend.Services;

public class ItemTransactionService : IItemTransactionService
{
    private readonly MongoDbContext _context;

    public ItemTransactionService(MongoDbContext context)
    {
        _context = context;
    }

    // ── Stock In (Consumable) ─────────────────────────────
    public async Task<ItemTransactionResponseDto> StockInAsync(
        string barcode, string userId, string userName, int quantity, string photoProofUrl)
    {
        var item = await _context.Items
            .Find(i => i.Barcode == barcode || i.Id == barcode)
            .FirstOrDefaultAsync()
            ?? throw new KeyNotFoundException($"No item found with barcode '{barcode}'.");

        if (item.ItemType != "Consumable")
            throw new InvalidOperationException("StockIn is only for Consumable items.");

        // Increase quantity
        var updateItem = Builders<Item>.Update
            .Inc(i => i.Quantity, quantity);
        await _context.Items.UpdateOneAsync(i => i.Id == item.Id, updateItem);

        var transaction = new ItemTransaction
        {
            ItemId          = item.Id ?? "",
            ItemName        = item.ItemName,
            UserId          = userId,
            UserName        = userName,
            TransactionType = "StockIn",
            Quantity        = quantity,
            PhotoProofUrl   = photoProofUrl,
            CheckOutDate    = DateTime.UtcNow,
            Status          = null
        };

        await _context.ItemTransactions.InsertOneAsync(transaction);
        return MapToResponse(transaction);
    }

    // ── Stock Out (Consumable) ────────────────────────────
    public async Task<ItemTransactionResponseDto> StockOutAsync(
        string barcode, string userId, string userName, int quantity, string photoProofUrl)
    {
        var item = await _context.Items
            .Find(i => i.Barcode == barcode || i.Id == barcode)
            .FirstOrDefaultAsync()
            ?? throw new KeyNotFoundException($"No item found with barcode '{barcode}'.");

        if (item.ItemType != "Consumable")
            throw new InvalidOperationException("StockOut is only for Consumable items.");

        if (item.Quantity < quantity)
            throw new InvalidOperationException(
                $"Insufficient stock. Available: {item.Quantity}, Requested: {quantity}.");

        // Decrease quantity
        var updateItem = Builders<Item>.Update
            .Inc(i => i.Quantity, -quantity);
        await _context.Items.UpdateOneAsync(i => i.Id == item.Id, updateItem);

        var transaction = new ItemTransaction
        {
            ItemId          = item.Id ?? "",
            ItemName        = item.ItemName,
            UserId          = userId,
            UserName        = userName,
            TransactionType = "StockOut",
            Quantity        = quantity,
            PhotoProofUrl   = photoProofUrl,
            CheckOutDate    = DateTime.UtcNow,
            Status          = null
        };

        await _context.ItemTransactions.InsertOneAsync(transaction);
        return MapToResponse(transaction);
    }

    // ── Scan Barcode (NonConsumable) ──────────────────────
    public async Task<ItemScanResultDto> ScanBarcodeAsync(string barcode)
    {
        var item = await _context.Items
            .Find(i => i.Barcode == barcode)
            .FirstOrDefaultAsync()
            ?? throw new KeyNotFoundException($"No item found with barcode '{barcode}'.");

        // Check if currently issued
        var activeTransaction = await _context.ItemTransactions
            .Find(t => t.ItemId == item.Id && t.Status == "Issued")
            .FirstOrDefaultAsync();

        return new ItemScanResultDto
        {
            ItemId   = item.Id ?? "",
            Barcode  = item.Barcode,
            ItemName = item.ItemName,
            ItemType = item.ItemType,
            ImageUrl = item.ImageUrl,
            Status   = activeTransaction == null ? "Available" : "Issued",
            IssuedTo = activeTransaction?.UserName
        };
    }

    // ── Issue Item (NonConsumable) ────────────────────────
    public async Task<ItemTransactionResponseDto> IssueItemAsync(
        string barcode, string userId, string userName)
    {
        var item = await _context.Items
            .Find(i => i.Barcode == barcode)
            .FirstOrDefaultAsync()
            ?? throw new KeyNotFoundException($"No item found with barcode '{barcode}'.");

        if (item.ItemType != "NonConsumable")
            throw new InvalidOperationException("Issue is only for NonConsumable items.");

        // Check if already issued
        var existing = await _context.ItemTransactions
            .Find(t => t.ItemId == item.Id && t.Status == "Issued")
            .FirstOrDefaultAsync();

        if (existing != null)
            throw new InvalidOperationException(
                $"Item '{item.ItemName}' is already issued to {existing.UserName}.");

        var transaction = new ItemTransaction
        {
            ItemId          = item.Id ?? "",
            ItemName        = item.ItemName,
            UserId          = userId,
            UserName        = userName,
            TransactionType = "Issued",
            Quantity        = 1,
            PhotoProofUrl   = null,
            CheckOutDate    = DateTime.UtcNow,
            Status          = "Issued"
        };

        await _context.ItemTransactions.InsertOneAsync(transaction);
        return MapToResponse(transaction);
    }

    // ── Return Item (NonConsumable) ───────────────────────
    public async Task<ItemTransactionResponseDto> ReturnItemAsync(
        string barcode, string userId)
    {
        var item = await _context.Items
            .Find(i => i.Barcode == barcode)
            .FirstOrDefaultAsync()
            ?? throw new KeyNotFoundException($"No item found with barcode '{barcode}'.");

        var transaction = await _context.ItemTransactions
            .Find(t => t.ItemId == item.Id && t.Status == "Issued")
            .FirstOrDefaultAsync()
            ?? throw new InvalidOperationException(
                $"Item '{item.ItemName}' is not currently issued.");

        var update = Builders<ItemTransaction>.Update
            .Set(t => t.CheckInDate,     DateTime.UtcNow)
            .Set(t => t.Status,          "Returned")
            .Set(t => t.TransactionType, "Returned");

        await _context.ItemTransactions.UpdateOneAsync(
            t => t.Id == transaction.Id, update);

        transaction.CheckInDate     = DateTime.UtcNow;
        transaction.Status          = "Returned";
        transaction.TransactionType = "Returned";

        return MapToResponse(transaction);
    }

    // ── My Issued (currently issued to me) ────────────────
    public async Task<List<ItemTransactionResponseDto>> GetMyIssuedAsync(string userId)
    {
        var transactions = await _context.ItemTransactions
            .Find(t => t.UserId == userId && t.Status == "Issued")
            .SortByDescending(t => t.CheckOutDate)
            .ToListAsync();

        return transactions.Select(MapToResponse).ToList();
    }

    // ── My History ────────────────────────────────────────
    public async Task<List<ItemTransactionResponseDto>> GetMyHistoryAsync(string userId)
    {
        var transactions = await _context.ItemTransactions
            .Find(t => t.UserId == userId)
            .SortByDescending(t => t.CheckOutDate)
            .ToListAsync();

        return transactions.Select(MapToResponse).ToList();
    }

    // ── Global History ────────────────────────────────────
    public async Task<List<ItemTransactionResponseDto>> GetGlobalHistoryAsync()
    {
        var transactions = await _context.ItemTransactions
            .Find(_ => true)
            .SortByDescending(t => t.CheckOutDate)
            .ToListAsync();

        return transactions.Select(MapToResponse).ToList();
    }

    // ── Map ───────────────────────────────────────────────
    private static ItemTransactionResponseDto MapToResponse(ItemTransaction t) => new()
    {
        Id              = t.Id ?? "",
        ItemId          = t.ItemId,
        ItemName        = t.ItemName,
        UserId          = t.UserId,
        UserName        = t.UserName,
        TransactionType = t.TransactionType,
        Quantity        = t.Quantity,
        PhotoProofUrl   = t.PhotoProofUrl,
        CheckOutDate    = t.CheckOutDate,
        CheckInDate     = t.CheckInDate,
        Status          = t.Status
    };
}