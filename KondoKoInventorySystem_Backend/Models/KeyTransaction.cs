using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace KondoKoInventorySystem_Backend.Models;

public class KeyTransaction
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string? Id { get; set; }

    [BsonElement("keyId")]
    public string KeyId { get; set; } = string.Empty;

    [BsonElement("barcode")]
    public string Barcode { get; set; } = string.Empty;

    [BsonElement("unit")]
    public string Unit { get; set; } = string.Empty;

    [BsonElement("userId")]
    public string UserId { get; set; } = string.Empty;

    [BsonElement("userName")]
    public string UserName { get; set; } = string.Empty;

    [BsonElement("checkOutDate")]
    public DateTime CheckOutDate { get; set; } = DateTime.UtcNow;

    [BsonElement("checkInDate")]
    public DateTime? CheckInDate { get; set; } = null;

    [BsonElement("status")]
    public string Status { get; set; } = "CheckedOut"; // CheckedOut | CheckedIn
}