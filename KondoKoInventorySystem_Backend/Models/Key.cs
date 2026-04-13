// KondoKoInventorySystem_Backend/Models/Key.cs

using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace KondoKoInventorySystem_Backend.Models;

public class Key
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string? Id { get; set; }

    [BsonElement("barcode")]
    public string Barcode { get; set; } = string.Empty;

    [BsonElement("ownersName")]
    public string OwnersName { get; set; } = string.Empty;

    [BsonElement("unit")]
    public string Unit { get; set; } = string.Empty;

    [BsonElement("keyType")]
    public string KeyType { get; set; } = string.Empty;

    [BsonElement("unitStatus")]
    public string UnitStatus { get; set; } = string.Empty;

    [BsonElement("keyHolder")]
    public string KeyHolder { get; set; } = string.Empty;

    [BsonElement("keyCode")]
    public string KeyCode { get; set; } = string.Empty;

    [BsonElement("date")]
    public DateTime Date { get; set; } = DateTime.UtcNow;

    // NEW: Group ID for grouping keys from same unit/owner
    [BsonElement("groupId")]
    public string? GroupId { get; set; }
}