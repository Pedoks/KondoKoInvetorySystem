using KondoKoInventorySystem_Backend.DTOs;
using KondoKoInventorySystem_Backend.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace KondoKoInventorySystem_Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class KeysController : ControllerBase
{
    private readonly IKeysService _keysService;

    public KeysController(IKeysService keysService)
    {
        _keysService = keysService;
    }

    // GET api/keys
    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var keys = await _keysService.GetAllAsync();
        return Ok(keys);
    }

    // GET api/keys/{id}
    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(string id)
    {
        var key = await _keysService.GetByIdAsync(id);
        if (key == null) return NotFound(new { message = "Key not found." });
        return Ok(key);
    }

    // POST api/keys
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] KeyDto dto)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        try
        {
            var created = await _keysService.CreateAsync(dto);
            return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    // PUT api/keys/{id}
    [HttpPut("{id}")]
    public async Task<IActionResult> Update(string id, [FromBody] KeyDto dto)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var updated = await _keysService.UpdateAsync(id, dto);
        if (updated == null) return NotFound(new { message = "Key not found." });
        return Ok(updated);
    }

    // DELETE api/keys/{id}
    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(string id)
    {
        var deleted = await _keysService.DeleteAsync(id);
        if (!deleted) return NotFound(new { message = "Key not found." });
        return Ok(new { message = "Key deleted successfully." });
    }


// GET api/keys/groups
[HttpGet("groups")]
public async Task<IActionResult> GetAllGroups()
{
    var groups = await _keysService.GetAllGroupsAsync();
    return Ok(groups);
}

// GET api/keys/group/{groupId}
[HttpGet("group/{groupId}")]
public async Task<IActionResult> GetGroupById(string groupId)
{
    var group = await _keysService.GetGroupByIdAsync(groupId);
    if (group == null) return NotFound(new { message = "Group not found." });
    return Ok(group);
}

// POST api/keys/add-to-group
[HttpPost("add-to-group")]
public async Task<IActionResult> AddKeyToGroup([FromBody] AddKeyToGroupDto dto)
{
    if (!ModelState.IsValid) return BadRequest(ModelState);
    try
    {
        var created = await _keysService.AddKeyToGroupAsync(dto);
        return Ok(created);
    }
    catch (InvalidOperationException ex)
    {
        return Conflict(new { message = ex.Message });
    }
    catch (KeyNotFoundException ex)
    {
        return NotFound(new { message = ex.Message });
    }
}
}