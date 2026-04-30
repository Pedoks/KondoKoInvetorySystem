using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace KondoKoInventorySystem_Backend.Models;

public class Item
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string? Id { get; set; }

    [BsonElement("barcode")]
    public string Barcode { get; set; } = string.Empty;

    [BsonElement("itemName")]
    public string ItemName { get; set; } = string.Empty;

    [BsonElement("itemType")]
    public string ItemType { get; set; } = string.Empty; // "Consumable" or "NonConsumable"

    [BsonElement("quantity")]
    public int Quantity { get; set; } = 0;

    [BsonElement("minStock")]
    public int MinStock { get; set; } = 0;

    [BsonElement("maxStock")]
    public int MaxStock { get; set; } = 0;

    [BsonElement("description")]
    public string Description { get; set; } = string.Empty;

    [BsonElement("imageUrl")]
    public string ImageUrl { get; set; } = string.Empty;

    [BsonElement("date")]
    public DateTime Date { get; set; } = DateTime.UtcNow;
}