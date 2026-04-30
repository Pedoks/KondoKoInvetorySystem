using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace KondoKoInventorySystem_Backend.Models;

public class ItemTransaction
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string? Id { get; set; }

    [BsonElement("itemId")]
    public string ItemId { get; set; } = string.Empty;

    [BsonElement("itemName")]
    public string ItemName { get; set; } = string.Empty;

    [BsonElement("userId")]
    public string UserId { get; set; } = string.Empty;

    [BsonElement("userName")]
    public string UserName { get; set; } = string.Empty;

    [BsonElement("transactionType")]
    public string TransactionType { get; set; } = string.Empty; // "StockIn" / "StockOut" / "Issued" / "Returned"

    [BsonElement("quantity")]
    public int Quantity { get; set; } = 1;

    [BsonElement("photoProofUrl")]
    public string? PhotoProofUrl { get; set; } = null;

    [BsonElement("checkOutDate")]
    public DateTime CheckOutDate { get; set; } = DateTime.UtcNow;

    [BsonElement("checkInDate")]
    public DateTime? CheckInDate { get; set; } = null;

    [BsonElement("status")]
    public string? Status { get; set; } = null; // "Issued" / "Returned" for NonConsumable, null for Consumable
}