using KondoKoInventorySystem_Backend.Data;
using KondoKoInventorySystem_Backend.DTOs;
using KondoKoInventorySystem_Backend.Models;
using Microsoft.IdentityModel.Tokens;
using MongoDB.Driver;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace KondoKoInventorySystem_Backend.Services;

public class AuthService : IAuthService
{
    private readonly MongoDbContext _context;
    private readonly IConfiguration _configuration;

    public AuthService(MongoDbContext context, IConfiguration configuration)
    {
        _context = context;
        _configuration = configuration;
    }

    public async Task<AuthResponseDto?> RegisterAsync(RegisterDto dto)
    {
        // Check if email already exists
        var existing = await _context.Users
            .Find(u => u.Email == dto.Email)
            .FirstOrDefaultAsync();

        if (existing != null)
            return null;

        var user = new User
        {
            FirstName = dto.FirstName,
            Surname = dto.Surname,
            Email = dto.Email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(dto.Password)
        };

        await _context.Users.InsertOneAsync(user);

        return new AuthResponseDto
        {
            Token = GenerateToken(user),
            Email = user.Email,
            FirstName = user.FirstName,
            Surname = user.Surname
        };
    }

    public async Task<AuthResponseDto?> LoginAsync(LoginDto dto)
    {
        var user = await _context.Users
            .Find(u => u.Email == dto.Email)
            .FirstOrDefaultAsync();

        if (user == null)
            return null;

        if (!BCrypt.Net.BCrypt.Verify(dto.Password, user.PasswordHash))
            return null;

        return new AuthResponseDto
        {
            Token = GenerateToken(user),
            Email = user.Email,
            FirstName = user.FirstName,
            Surname = user.Surname
        };
    }

    private string GenerateToken(User user)
    {
        var secret = Environment.GetEnvironmentVariable("JWT_SECRET")
            ?? _configuration["Jwt:Secret"]
            ?? throw new InvalidOperationException("JWT_SECRET is not set.");

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, user.Id ?? ""),
            new Claim(ClaimTypes.Email, user.Email),
            new Claim(ClaimTypes.GivenName, user.FirstName),
            new Claim(ClaimTypes.Surname, user.Surname)
        };

        var token = new JwtSecurityToken(
            claims: claims,
            expires: DateTime.UtcNow.AddDays(7),
            signingCredentials: creds
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}