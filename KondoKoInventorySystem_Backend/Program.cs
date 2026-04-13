using KondoKoInventorySystem_Backend.Data;
using KondoKoInventorySystem_Backend.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.Text;
using DotNetEnv; 

var builder = WebApplication.CreateBuilder(args);

// ── ADD THIS: Configure Kestrel to listen on all interfaces ──
//builder.WebHost.ConfigureKestrel(options =>
//{
    // Listen on all network interfaces for port 5053
 //   options.ListenAnyIP(5053);
    
    // Also keep localhost for debugging (optional)
    // options.ListenLocalhost(5053);
///});

Env.Load(); 

// MongoDB
builder.Services.Configure<MongoDbSettings>(
    builder.Configuration.GetSection("MongoDbSettings"));
builder.Services.AddSingleton<MongoDbContext>();

// Services
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IKeysService, KeysService>();
builder.Services.AddScoped<IKeyTransactionService, KeyTransactionService>();

// JWT
var jwtSecret = Environment.GetEnvironmentVariable("JWT_SECRET")
    ?? builder.Configuration["Jwt:Secret"]
    ?? throw new InvalidOperationException("JWT_SECRET is not set.");

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecret)),
            ValidateIssuer = false,
            ValidateAudience = false
        };
    });

builder.Services.AddAuthorization();
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// CORS for Flutter
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
        policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader());
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors("AllowAll");
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

// ── ADD THIS: Print the URLs where the app is running ──
Console.WriteLine("=== Server Starting ===");
Console.WriteLine($"Local URL: http://localhost:5053");
Console.WriteLine($"Network URL: http://{GetLocalIpAddress()}:5053");
Console.WriteLine("========================");

app.Run();

// ── ADD THIS helper method to get local IP address ──
static string GetLocalIpAddress()
{
    var host = System.Net.Dns.GetHostEntry(System.Net.Dns.GetHostName());
    foreach (var ip in host.AddressList)
    {
        if (ip.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork)
        {
            return ip.ToString();
        }
    }
    return "127.0.0.1";
}