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

    // ── Unit of Measurement ───────────────────────────
    [BsonElement("unitType")]
    public string UnitType { get; set; } = string.Empty; // "Liquid" | "Solid" | "Count"

    /// Smallest stored unit — never changes after creation
    /// Liquid → mL | Solid → g | Count → pcs
    [BsonElement("baseUnit")]
    public string BaseUnit { get; set; } = "pcs";

    /// The unit staff prefers to see / use when viewing or transacting
    /// e.g. staff registered in L → preferredUnit = "L"
    /// Display: convert from baseUnit to preferredUnit for UI
    [BsonElement("preferredUnit")]
    public string PreferredUnit { get; set; } = "pcs";

    /// For Count type: how many base units per 1 pack/box
    [BsonElement("conversionFactor")]
    public double ConversionFactor { get; set; } = 1;

    /// Always stored in base unit (mL / g / pcs)
    [BsonElement("quantity")]
    public double Quantity { get; set; } = 0;

    [BsonElement("minStock")]
    public double MinStock { get; set; } = 0;

    [BsonElement("maxStock")]
    public double MaxStock { get; set; } = 0;

    [BsonElement("description")]
    public string Description { get; set; } = string.Empty;

    [BsonElement("imageUrl")]
    public string ImageUrl { get; set; } = string.Empty;

    [BsonElement("date")]
    public DateTime Date { get; set; } = DateTime.UtcNow;
}