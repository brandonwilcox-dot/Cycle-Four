# Blender MCP Setup & Troubleshooting

## Current Status

**MCP Server:** ✓ Running and connected to Blender 5.1.2 at localhost:9876  
**MCP Tools Discovery:** ✗ ToolSearch unable to find Blender MCP tools  
**Expected Tools:** `execute_blender_code`, `get_scene_info`, `get_object_info`, etc.

---

## Setup Configuration

### .mcp.json Entry
**Location:** `D:\AI\Cycle Four\.mcp.json`

```json
{
  "mcpServers": {
    "blender": {
      "command": "C:\\Users\\Brand\\.local\\bin\\uvx.exe",
      "args": ["blender-mcp"]
    }
  }
}
```

### Prerequisites Installed
- ✓ `uvx` installed at `C:\Users\Brand\.local\bin\uvx.exe`
- ✓ `blender-mcp` package available via uvx
- ✓ Blender 5.1.2 with MCP addon enabled
- ✓ Addon listening on localhost:9876

### Verification Command
```bash
C:\Users\Brand\.local\bin\uvx.exe blender-mcp --help
```
**Output:** Server connects successfully to Blender, exchanges commands.

---

## Problem: Tools Not Discoverable

### Symptoms
- ToolSearch patterns (`execute_blender_code`, `blender`, `blender mcp`) return no matches
- Server is running and connected (confirmed via direct invocation)
- Other MCPs (Godot) are discoverable normally

### Root Cause Analysis

**Hypothesis 1: Tool Registration Delay**
- MCP server may need time after connection to register tools
- Solution: Restart Claude Code and wait 30+ seconds before searching

**Hypothesis 2: MCP Configuration Issue**
- Server started but tool schema not published to client
- Solution: Verify `.mcp.json` is loaded, restart Claude Code fully

**Hypothesis 3: Tool Name Mismatch**
- Tools may be namespaced differently than expected
- Tools might not follow standard `mcp__<server>__<toolname>` pattern
- Solution: Query server directly for tool list

**Hypothesis 4: Incomplete MCP Server Initialization**
- Server may require explicit "ready" message to client
- Solution: Check server logs for connection/handshake status

---

## Troubleshooting Steps

### Step 1: Verify MCP Server is Running
```bash
C:\Users\Brand\.local\bin\uvx.exe blender-mcp 2>&1 | head -20
```
**Expected output:**
```
BlenderMCP is an MCP server...
BlenderMCP server starting up
Connected to Blender at localhost:9876
Created new persistent connection to Blender
```

### Step 2: Check Blender Addon Status
In Blender 5.1.2:
1. Edit → Preferences → Add-ons
2. Search "blender-mcp"
3. Verify addon is **enabled** (checkbox checked)
4. Verify Python console shows no errors

### Step 3: Verify .mcp.json Syntax
```bash
python -m json.tool D:\AI\Cycle\ Four\.mcp.json
```
Should output valid JSON with no errors.

### Step 4: Restart Claude Code
1. Fully quit Claude Code (not just window close)
2. Wait 5 seconds
3. Relaunch Claude Code
4. Wait 30 seconds for MCP server to initialize
5. Try ToolSearch again

### Step 5: Check MCP Server Logs
Look for files in:
- `C:\Users\Brand\AppData\Local\Temp\claude\...` (Claude logs)
- `C:\Users\Brand\.local\bin\` (uvx logs if available)

### Step 6: Query Available Tools Directly
If tools are still not discoverable, try calling directly:
```
Tool name pattern: mcp__<uuid>__execute_blender_code
```
(UUID would be printed by Claude when loading MCPs)

---

## Direct Access Solution Path

Once tools are discoverable, direct access workflow:

### Option A: Via ToolSearch + Direct Invocation
1. ToolSearch finds `mcp__blender__<toolname>` tools
2. Call `execute_blender_code` with Python code string
3. Code executes in Blender, results returned

### Option B: If ToolSearch Still Fails
1. Attempt direct tool invocation with guessed name: `mcp__blender__execute_blender_code`
2. If that fails, check error message for actual tool name
3. Use actual name in subsequent calls

### Option C: Fallback to Socket Communication
If MCP registration fails entirely:
1. Use direct socket connection to localhost:9876
2. Send commands as JSON over socket
3. Parse responses directly

---

## Expected Behavior Once Working

```
User: "Use Blender MCP to generate Architect Commander"
↓
Claude: execute_blender_code("
  import bpy
  # Generate commander geometry
  # Create armature/rigging
  # Export as GLTF
")
↓
Blender: Executes Python, returns status/file path
↓
Result: GLTF file created at D:\AI\Cycle Four\assets\models\commanders\architect_acl.glb
```

---

## Next Actions

1. **Verify MCP is running:** Run Step 1 verification
2. **Restart Claude Code completely:** Full quit + relaunch
3. **Test ToolSearch:** Search for "execute_blender_code"
4. **If found:** Proceed with Commander generation
5. **If not found:** Run troubleshooting steps 2-6, then retry

---

## References
- Blender MCP Repo: https://github.com/ahujasid/blender-mcp
- MCP Protocol Spec: https://spec.modelcontextprotocol.io/
- uvx Documentation: https://docs.astral.sh/uv/
