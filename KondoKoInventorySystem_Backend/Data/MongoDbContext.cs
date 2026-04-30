using KondoKoInventorySystem_Backend.Models;
using Microsoft.Extensions.Options;
using MongoDB.Driver;

namespace KondoKoInventorySystem_Backend.Data;

public class MongoDbContext
{
    private readonly IMongoDatabase _database;

    public MongoDbContext(IOptions<MongoDbSettings> settings)
    {
        
        var connectionString = Environment.GetEnvironmentVariable("MONGO_URI")
            ?? settings.Value.ConnectionString
            ?? throw new InvalidOperationException("MONGO_URI is not set.");

        var client = new MongoClient(connectionString);
        _database = client.GetDatabase(settings.Value.DatabaseName);
    }

    public IMongoCollection<User> Users =>
        _database.GetCollection<User>("Users");

    public IMongoCollection<Key> Keys =>
         _database.GetCollection<Key>("Keys");

    public IMongoCollection<KeyTransaction> KeyTransactions =>
        _database.GetCollection<KeyTransaction>("KeyTransactions");

    public IMongoCollection<Item> Items =>
        _database.GetCollection<Item>("Items");

    public IMongoCollection<ItemTransaction> ItemTransactions =>
        _database.GetCollection<ItemTransaction>("ItemTransactions");
}