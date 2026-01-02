# Lycoris Script Deobfuscation and Analysis

This report provides a deobfuscated version of the provided Lua script, focusing on meaningful identifier names, and a detailed explanation of its core functionality and architecture. The script is a large, modular program, likely a sophisticated exploit or utility for a Roblox game, given the frequent references to game services, place IDs, and combat features.

## 1. Deobfuscated Code Snippets

Due to the script's immense size (nearly 60,000 lines), the full deobfuscated code cannot be displayed here. Below are key sections of the deobfuscated code that reveal the script's architecture and main logic.

### A. Custom Module System (The Loader)

The script uses a custom module loading system, a common technique for obfuscation and dependency management in large Lua projects.

\`\`\`lua
local require_fn, module_cache, register_fn, module_registry = (function(original_require)
	local sentinel_value = { [{}] = true }
	local module_registry = {}
	local custom_require = nil
	local module_cache = {}
	
	local register_module = function(module_name, module_func)
		if not module_registry[module_name] then
			module_registry[module_name] = module_func
		end
	end
	
	custom_require = function(target_module)
		local cached_module = module_cache[target_module]
		if cached_module then
			-- ... cache check logic ...
		else
			if not module_registry[target_module] then
				-- ... error or fallback to original require ...
			end
			module_cache[target_module] = sentinel_value
			cached_module = module_registry[target_module](custom_require, module_cache, register_module, module_registry)
			module_cache[target_module] = cached_module
		end
		return cached_module
	end
	return custom_require, module_cache, register_module, module_registry
end)(require)
\`\`\`

### B. Root Initialization (`__root`)

This is the entry point that sets up the environment and executes the main script logic.

\`\`\`lua
register_fn("__root", function(require, cache, register, registry)
	if not shared then
		return warn("No shared, no script.")
	end
	
	-- Bypass/mock obfuscation checks
	loadstring("getfenv().LPH_NO_VIRTUALIZE = function(...) return ... end")()
	getfenv().PP_SCRAMBLE_NUM = function(...) return ... end
	-- ... other scramble mocks ...
	
	local Profiler = require("Utility/Profiler")
	local Lycoris = require("Lycoris")
	
	local init_script = function()
		if L_36 and shared.Lycoris then
			shared.Lycoris.detach() -- Hot-reload/cleanup previous instance
			Lycoris.queued = shared.Lycoris.queued
		end
		shared.Lycoris = Lycoris
		shared.Lycoris.init()
	end
	
	local handle_init_error = function(err)
		warn("Failed to initialize.")
		warn(err)
		warn(debug.traceback())
		Lycoris.detach()
	end
	
	Profiler.run("Main_InitializeScript", function(...)
		return xpcall(init_script, handle_init_error, ...)
	end)
end)
\`\`\`

### C. Lycoris Core Module (Main Logic)

The central module responsible for coordinating all features.

\`\`\`lua
register_fn("Lycoris", function(require, cache, register, registry)
	local LycorisCore = { queued = false, silent = false, dpscanning = false, norpc = false }
	
	-- Module Dependencies
	local Logger = require("Utility/Logger")
	local Hooking = require("Game/Hooking")
	local Menu = require("Menu")
	local Features = require("Features")
	-- ... many other modules ...
	local ServerHop = require("Game/ServerHop")
	local Wipe = require("Game/Wipe")
	local EchoFarm = require("Features/Automation/EchoFarm")
	local JoyFarm = require("Features/Automation/JoyFarm")
	
	-- Game Place IDs (Likely Deepwoken)
	local LobbyPlaceId = 4111023553
	local DepthsPlaceId = 5735553160
	local ChimePlaceId = 12559711136
	
	local ReportAnalytics = function()
		-- Gathers player stats (Name, UserId, EloRating, EloRank, RankName)
		-- and sends them via an obfuscated function (L_39) along with a large, fixed string (likely a key or payload).
	end
	
	LycorisCore.init = function()
		-- Wait for game and local player to load
		-- Check for local files ("smarker.txt", "dpscanning.txt", "norpc.txt") to set flags
		
		-- Place-specific initialization logic (KeyHandling, Hooking, etc.)
		
		-- Handles automated actions based on persistent data
		if PersistentData.get("shslot") then return ServerHop.lobby() end
		if PersistentData.get("wdata") then return Wipe.lobby() end
		if PersistentData.get("efdata") then EchoFarm.start() end
		
		-- Initialize all sub-modules (QueuedBlocking, SaveManager, Features, Menu, etc.)
		
		-- Discord Rich Presence (RPC) setup via BloxstrapRPC module
		-- ... sets status to "Lycoris Rewrite (Attached)" ...
	end
	
	LycorisCore.detach = function()
		-- Cleans up all resources using the MainMaid utility
		-- Calls detach on all initialized sub-modules (JoyFarm.stop(), Menu.detach(), etc.)
		-- Clears Discord Rich Presence status
	end
	
	return LycorisCore
end)
\`\`\`

## 2. Explanation of Script Sections

The script is a highly structured, modular program designed to inject and manage a set of features within a Roblox game environment.

### 2.1. Module System and Environment Setup

The script begins with a **custom module loader** that mimics the standard Lua `require` function. This system is crucial for managing the script's vast number of internal components.

| Identifier | Deobfuscated Name | Functionality |
| :--- | :--- | :--- |
| `L_520` | `require_fn` | The function used to load registered modules. |
| `L_522` | `register_fn` | The function used to register a new module by name and function. |
| `L_513` | `module_cache` | Stores already loaded modules to prevent redundant loading. |
| `L_511` | `module_registry` | A table mapping module names (e.g., "Utility/Logger") to their initialization functions. |

The initial `loadstring` block (lines 6-13) and the `getfenv()` calls in the `__root` module are **anti-obfuscation measures**. They define dummy functions (`LPH_JIT`, `LPH_NO_VIRTUALIZE`, `PP_SCRAMBLE_*`) that are typically used by commercial Lua obfuscators. By defining these functions to simply return their arguments, the script ensures that the obfuscator's runtime checks are bypassed or neutralized, allowing the code to run correctly.

### 2.2. Root Initialization (`__root`)

The `__root` module acts as the script's main entry point. Its primary role is to ensure a safe and controlled launch of the `Lycoris` core.

1.  **Environment Check:** It first verifies the existence of the `shared` global table, which is a common indicator of a working script executor environment.
2.  **Safe Execution:** It uses the `Profiler` module's `run` function in conjunction with `xpcall` (a protected call) to execute the main `init_script`. This mechanism ensures that if any error occurs during initialization, the `handle_init_error` function is called to log the error traceback and cleanly `detach` the script, preventing a full crash.
3.  **Hot-Reloading:** The `init_script` function checks if a previous instance of `Lycoris` exists in the `shared` table. If so, it calls `shared.Lycoris.detach()` to perform a clean shutdown before loading the new instance, enabling seamless hot-reloading.

### 2.3. Lycoris Core Module

The `Lycoris` module is the heart of the script, managing all features and lifecycle events.

#### A. Configuration and Constants
The module defines three critical Roblox `PlaceId` constants, strongly suggesting the target game is **Deepwoken**:

| Constant | Place ID | Likely Location |
| :--- | :--- | :--- |
| `LobbyPlaceId` | `4111023553` | The main game lobby or hub. |
| `DepthsPlaceId` | `5735553160` | The Depths/Underworld area. |
| `ChimePlaceId` | `12559711136` | The Chime/Arena lobby (PvP area). |

It also initializes a configuration table (`LycorisCore`) with flags that can be set via external files:
*   `silent`: If `smarker.txt` exists, suppresses warnings/notifications.
*   `dpscanning`: If `dpscanning.txt` exists, enables deep player scanning.
*   `norpc`: If `norpc.txt` exists, disables Discord Rich Presence integration.

#### B. Initialization (`init`)
The `init` function orchestrates the script's launch:
1.  **Game Loading:** It waits for the game and the local player to fully load.
2.  **Place-Specific Logic:** It executes different initialization routines based on the current `PlaceId`. For instance, `KeyHandling` and `Hooking` are skipped if the player is in the main `LobbyPlaceId`.
3.  **Automation/Utility:** It initializes a large number of utility and feature modules, including `Menu`, `Features`, `PlayerScanning`, and `StateListener`.
4.  **Persistent Actions:** It checks `PersistentData` for flags indicating pending automated actions:
    *   `shslot`: Triggers a `ServerHop.lobby()` action.
    *   `wdata`: Triggers a `Wipe.lobby()` or `Wipe.depths()` action, suggesting a feature to automate character wiping or progression.
    *   `efdata`: Triggers `EchoFarm.start()`, indicating an automation feature for farming in the game.
5.  **Analytics and RPC:**
    *   `ReportAnalytics` is called to gather and transmit player data (Elo rating, rank, etc.) along with a large, obfuscated payload string. This is likely a form of license verification or a data collection mechanism.
    *   It attempts to load and use the `BloxstrapRPC` module to set a custom Discord Rich Presence status, indicating the script is "Attached" and showing game-specific assets.

#### C. Detachment (`detach`)
The `detach` function provides a clean shutdown mechanism. It uses a `Maid` utility (`MainMaid`) to automatically clean up connections and threads. It explicitly calls the `detach` or `stop` method on all major sub-modules, ensuring that all hooks, threads, and UI elements are removed from the game environment.

### 2.4. Example Feature Module: JoyFarm

The `JoyFarm` module is an example of a complex automation feature within the script.

| Identifier | Deobfuscated Name | Functionality |
| :--- | :--- | :--- |
| `L_587` | `FiniteStateMachine` | Core utility for managing the automation flow. |
| `L_635` | `JoyFSM` | The main state machine instance. |
| `L_626` | `IdleState` | State where the script waits for the wave to start. It uses `Finder.wshrine()` to locate a shrine, tweens the player to it, and uses `fireproximityprompt` to interact. |
| `L_634` | `AttackState` | State where the script engages enemies. It uses `Finder.enear()` to find nearby enemies and `Finder.geir()` to find a general target. |
| `L_606` | `SpoofMouse` | A critical function that hijacks the game's `GetMouse` request. It calculates the position of the current target's `HumanoidRootPart` and spoofs the mouse to aim at it, compensating for latency (`Latency.rtt()`). |

The `JoyFarm` module automates a wave-based combat encounter (likely the "Joy" or "Shrine of Joy" trial in Deepwoken). It transitions between an `IdleState` (waiting at the shrine) and an `AttackState` (fighting enemies), using advanced techniques like mouse spoofing and player movement tweening to execute the combat automatically.

***

This deobfuscation reveals a highly organized and feature-rich script, utilizing advanced Lua/Luau programming patterns (module systems, FSMs, utility classes like `Maid` and `Signal`) to provide a comprehensive set of in-game utilities and automation features.
