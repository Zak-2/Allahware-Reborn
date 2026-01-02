L_32 = "zKXXS" 
L_33 = "Undefined"
L_34 = "Parry"
L_35 = true 
L_36 = true 
loadstring([[
    function LPH_JIT(f) return f end;
    function LPH_JIT_MAX(f) return f end;
    function LPH_JIT_ULTRA(f) return f end;
    function LPH_NO_VIRTUALIZE(f) return f end;
    function LPH_NO_UPVALUES(f) return f end;
    function LPH_CRASH() return end;
]])()
local require_fn, cache_table, register_fn, registry_table = (function(original_require)
	local sentinel_value = { [{}] = true }
	local module_registry = {}
	local custom_require = nil
	local module_cache = {}
	local register_module = function(module_name, module_func)
		if not module_registry[module_name] then
			module_registry[module_name] = module_func
		end
		return
	end
	custom_require = function(target_module)
		local cached_module = module_cache[target_module]
		if cached_module then
			if cached_module == sentinel_value then
				return nil
			end
		else
			if not module_registry[target_module] then
				if original_require then
					return original_require(target_module)
				end
				local error_msg = type(target_module) == "string" and '"' .. target_module .. '"' or tostring(target_module)
				error("Tried to require " .. error_msg .. ", but no such module has been registered")
			end
			module_cache[target_module] = sentinel_value
			cached_module = module_registry[target_module](custom_require, module_cache, register_module, module_registry)
			module_cache[target_module] = cached_module
		end
		return cached_module
	end
	return custom_require, module_cache, register_module, module_registry
end)(require)
register_fn("__root", function(require, cache, register, registry)
	if not shared then
		return warn("No shared, no script.")
	end
	loadstring("getfenv().LPH_NO_VIRTUALIZE = function(...) return ... end")()
	getfenv().PP_SCRAMBLE_NUM = function(...)
		return ...
	end
	getfenv().PP_SCRAMBLE_STR = function(...)
		return ...
	end
	getfenv().PP_SCRAMBLE_RE_NUM = function(...)
		return ...
	end
	local Profiler = require("Utility/Profiler")
	local Lycoris = require("Lycoris")
	local init_script = function()
		if L_36 and shared.Lycoris then
			shared.Lycoris.detach()
			Lycoris.queued = shared.Lycoris.queued
		end
		shared.Lycoris = Lycoris
		shared.Lycoris.init()
		return
	end
	local handle_init_error = function(err)
		warn("Failed to initialize.")
		warn(err)
		warn(debug.traceback())
		Lycoris.detach()
		return
	end
	Profiler.run("Main_InitializeScript", function(...)
		return xpcall(init_script, handle_init_error, ...)
	end)
	return
end)
register_fn("Lycoris", function(require, cache, register, registry)
	local LycorisCore = { queued = false, silent = false, dpscanning = false, norpc = false }
	local Logger = require("Utility/Logger")
	local Hooking = require("Game/Hooking")
	local Menu = require("Menu")
	local Features = require("Features")
	local ControlModule = require("Utility/ControlModule")
	local InputClient = require("Game/InputClient")
	local PlayerScanning = require("Game/PlayerScanning")
	local SaveManager = require("Game/Timings/SaveManager")
	local StateListener = require("Features/Combat/StateListener")
	local PersistentData = require("Utility/PersistentData")
	local KeyHandling = require("Game/KeyHandling")
	local QueuedBlocking = require("Game/QueuedBlocking")
	local Maid = require("Utility/Maid")
	local Signal = require("Utility/Signal")
	local ModuleManager = require("Game/Timings/ModuleManager")
	local CoreGuiManager = require("Utility/CoreGuiManager")
	local ServerHop = require("Game/ServerHop")
	local Wipe = require("Game/Wipe")
	local EchoFarm = require("Features/Automation/EchoFarm")
	local JoyFarm = require("Features/Automation/JoyFarm")
	local MainMaid = Maid.new()
	local LobbyPlaceId = 4111023553
	local DepthsPlaceId = 5735553160
	local ChimePlaceId = 12559711136
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Players = game:GetService("Players")
	local StartTime = os.clock()
	local ReportAnalytics = function()
		local LocalPlayer = Players.LocalPlayer
		local EloRating = "N/A"
		local RankName = "N/A"
		local EloRank = "N/A"
		if game.PlaceId == ChimePlaceId then
			local EloAttr = LocalPlayer:GetAttribute("EloRating")
			local RankAttr = LocalPlayer:GetAttribute("EloRankNo")
			EloRating = EloAttr and tostring(EloAttr) or "N/A"
			EloRank = RankAttr and tostring(RankAttr) or "N/A"
			if not RankAttr then
				RankName = "Unranked"
			end
			if RankAttr then
				RankName = "Ranked"
			end
			if RankName and RankAttr <= 1000 then
				RankName = "Top 1000"
			end
			if RankAttr and RankAttr <= 250 then
				RankName = "Top 250"
			end
			if L_36 and RankAttr and RankAttr <= 50 then
				RankName = "Top 50"
			end
			if RankAttr and RankAttr <= 10 then
				RankName = "Top 10"
			end
		end
		if script_key then
			L_39(
				7,
				{ LocalPlayer.Name, LocalPlayer.UserId, EloRating, EloRank, RankName, game.PlaceId, game.Name },
				"24408f418996c15d8c98954f976a3744db9d7e0d81396f94994b84ecdce97dbcb7c03baf147d62825675bc3bf12d1dcb4379893e059f769ed9d91c041866913b4d9c4d46e423b3aacba8d962371c8e1494d13897ed17dbee77ac71a25fee6def7eaaa312f2321b52b95d1f6c8c38a6aff41512977812ab8bb686531bd53941ce9a2dea27dfbc8f6d955592cbc8e253a0f907243a31795b84edc04b658fc96d08a0461768e3f2d9ec73c290450f12f60592a6318e31b8293d67e91aa6af49404ca4f3afaf67d575655951085cfc5637ac50c20b69a119d35972898f2058686a71074bfb77e87c63839418e68b225fb1f9580141849a37acce342bd0e4859e69267ddc7b33765ad602a08608bfac5813c240da30c1c2eca549268e222711aa8b7093f99c18605c034699bc9ed8f34cc09248c7d2e1799520efb617948c660509e8f6e88f70cdba6c2195f72521478b6f51983be36045f26ebc249a1a1858bccf98e9811620c0e78e7ff18cae792a390b84156ac8852f76c642aea00290d327f50fe91db109c2e58a44fc848be9ce62c8f5bbf94548497680a9308c30569f1587d0501700728c6dc621514555c0f0a29b6ab4836fdb753f9cc0a165ad160b9cb38ef3ee33cb01acf9b9cea0286339e7322445b54b84e0a9de41913ada4ea82a6dba80d1c9a5f7009ba262adf6c3c241f600edd3742547f7a95b554ab2bb21acedf2515df9c68446633a255dee6d9f73a69977dfad7b4e4dc4cb5105db69a575e2ddada42b7d0ced22eef6ecb339e63762500be8de88d95fd696bbbb517274a97880a02a445cea8ee51aaadbc3bb0cd4dd93f30c3417a609407bedb2e92833d040ba4fe7a53113fea641bbc773c05214f0c112d1a42a9a7496b0dd3b1bccf3990a9779843fa1ced4fba78bf0df0b635b2b37a97936b4f36587ffbf0eaed2c85b5fb067a8c8253ee849c89a6efe72f69095ed37aa4a8c93b3417cd1e809108d6cf24e293ce0309b6185d71331f043def39a8221cdf3acec859c38b6bf0c47ba3c0a9f9b97ad81b16841bd5f31eab34ab2fa5a5da91781416346cf0385710dff10bff53b0658b61ffa53cca0bf8698676f60bbf9d785c247785b0c96a09edd7fc0419df553e97e3b5612923cbe22e13ab1df3a03c821578660e7d104d3f36198ef479603a41aaf280133c61c24ba2ba2a85c9832bea139d3627f302694d0ed91fdf0d20be0c3a9cfec0e018e52be2352e5a62d3ef9e94e218dc4e6454cc12a7aa8ba4dc7a5b38a18b64123e48b3aa17169f1af5b6f8c1c590f265d8d92457c05c1b8bac657e8def20c146596d425e99b73e7d12d6bfd7346def885dc80c174867611a3a61df4dfc42d08429f7b5a71dafaf1bf9bc1fa823f98b36a1b4ff0c9e5d28ca6634cf3d6fbdbbf7b198bd9e31be6101837eba3e0d3b7111aaca687dbfbabe2c5140337d199633b2b4a3c817e17e529daa8003ea21c8d4eedc9108c00c8e7cff96b660bf48a76e1bea34a5d50b85f79c3dd83be0b2e56f4998f918c2b049d5997af37aba2bebfabb9bb03ae7e9da4ede01540ec57680cf8051e33683c0888a9ff3b27aa1c0d8f00f3ac149c5ee9637ec4275202bd8c5e9e102a0202258c719cabf12b97ef8b882f048d9da5017377c3563afd9c9c69fdb1be4ed9c68ae83b15042538dfcf03cec68c934e1149d220c62c93a5c680bf57216ddb97d5469477a9c1ad668691c24d25a88c75382686da3acefb6aba1b3b62f3ac2ff8cc",
				L_454
			)
		end
		return
	end
	LycorisCore.init = function()
		repeat
			task.wait()
		until game:IsLoaded()
		while Players.LocalPlayer == nil do
		end
		if L_36 and isfile and isfile("smarker.txt") then
			LycorisCore.silent = true
		end
		if isfile and isfile("dpscanning.txt") then
			LycorisCore.dpscanning = true
		end
		if isfile and isfile("norpc.txt") then
			LycorisCore.norpc = true
		end
		if game.PlaceId == ChimePlaceId or game.PlaceId == LobbyPlaceId then
			ReportAnalytics()
		end
		if L_35 and game.PlaceId == ChimePlaceId then
			return Logger.warn("Script has initialized in the Chime lobby.")
		end
		if game.PlaceId ~= LobbyPlaceId then
			KeyHandling.init()
			Hooking.init()
		end
		CoreGuiManager.set()
		PersistentData.init()
		if game.PlaceId == LobbyPlaceId then
			Logger.warn("Script has initialized in the lobby.")
		end
		if game.PlaceId == LobbyPlaceId then
			if PersistentData.get("shslot") then
				return ServerHop.lobby()
			end
			if PersistentData.get("wdata") then
				return Wipe.lobby()
			end
		end
		PersistentData.set("shslot", nil)
		if game.PlaceId == DepthsPlaceId and PersistentData.get("wdata") then
			Wipe.depths()
		end
		if PersistentData.get("efdata") then
			EchoFarm.start()
		end
		if game.PlaceId == LobbyPlaceId then
			return
		end
		QueuedBlocking.init()
		SaveManager.init()
		ModuleManager.refresh()
		ControlModule.init()
		Features.init()
		Menu.init()
		PlayerScanning.init()
		StateListener.init()
		Logger.notify("Script has been initialized in %ims.", (os.clock() - StartTime) * 1000)
		ReportAnalytics()
		if not PersistentData.get("fli") then
			PersistentData.set("fli", os.time())
		end
		local L_572 = ReplicatedStorage:FindFirstChild("Modules")
		local L_573 = L_572 and L_572:FindFirstChild("BloxstrapRPC")
		local L_574 = L_573 and require(L_573)
		if L_36 and not L_574 then
			return
		end
		if LycorisCore.norpc then
			return
		end
		L_574.SetRichPresence({
			details = "Lycoris Rewrite (Attached)",
			state = string.format(
				"Currently attached to the script - time elapsed is a session of %s time spent.",
				L_38 and "using" or "developing"
			),
			timeStart = PersistentData.get("fli") or os.time(),
			largeImage = {
				assetId = L_38 and 109802578297970 or 11289930484,
				hoverText = L_38 and "Using Deepwoken" or "Developing Deepwoken",
			},
			smallImage = {
				assetId = L_38 and 17278571027 or 15828456271,
				hoverText = L_38 and "Using Deepwoken" or "Developing Deepwoken",
			},
		})
		MainMaid:mark(Signal.new(Players.PlayerRemoving)):connect("Lycoris_OnLocalPlayerRemoved", function(L_575)
			if L_575 ~= Players.LocalPlayer then
				return
			end
			L_574.SetRichPresence({
				details = "",
				state = "",
				timeStart = 0,
				timeEnd = 0,
				largeImage = { clear = true },
				smallImage = { clear = true },
			})
			return
		end)
		return
	end
	LycorisCore.detach = function()
		MainMaid:clean()
		ModuleManager.detach()
		JoyFarm.stop()
		Menu.detach()
		QueuedBlocking.detach()
		ControlModule.detach()
		Features.detach()
		SaveManager.detach()
		PlayerScanning.detach()
		CoreGuiManager.clear()
		StateListener.detach()
		local L_576 = ReplicatedStorage:FindFirstChild("Modules")
		local L_577 = L_576 and L_576:FindFirstChild("BloxstrapRPC")
		local L_578 = L_577 and require(L_577)
		if L_36 and L_578 then
			L_578.SetRichPresence({
				details = "Lycoris Rewrite (Detached)",
				state = L_38 and "Detached from script - something broke or a hot-reload."
					or "Detached from script - something broke, fixing a bug, or a hot-reload.",
				timeStart = PersistentData.get("fli") or os.time(),
				largeImage = {
					assetId = L_38 and 109802578297970 or 11289930484,
					hoverText = L_38 and "Not Using Deepwoken" or "Developing Deepwoken",
				},
				smallImage = {
					assetId = L_38 and 17278571027 or 15828456271,
					hoverText = L_38 and "Not Using Deepwoken" or "Developing Deepwoken",
				},
			})
		end
		Hooking.detach()
		Logger.warn("Script has been detached.")
		return
	end
	return LycorisCore
end)
register_fn("Features/Automation/JoyFarm", function(require, cache, register, registry)
	local JoyFarmCore = {}
	local AntiAFK = require("Game/AntiAFK")
	local Tweening = require("Features/Game/Tweening")
	local FiniteState = require("Utility/FiniteState")
	local FiniteStateMachine = require("Utility/FiniteStateMachine")
	local Finder = require("Utility/Finder")
	local TableUtil = require("Utility/Table")
	local Latency = require("Game/Latency")
	local Maid = require("Utility/Maid")
	local InputClient = require("Game/InputClient")
	local TaskSpawner = require("Utility/TaskSpawner")
	local JoyMaid = Maid.new()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local OriginalGetMouseCallback = nil
	local CurrentTarget = nil
	local AboveOffset = CFrame.new(0, 30, 0)
	local ShrinePositions = {
		{ pos = Vector3.new(-16837.07, 50.97, 12143.41), radius = 20 },
		{ pos = Vector3.new(-16848.69, 50.87, 12182.7), radius = 10 },
		{ pos = Vector3.new(-16849.81, 56.64, 12104.16), radius = 10 },
		{ pos = Vector3.new(-16752.79, 53.05, 12054.92), radius = 10 },
	}
	local SpoofMouse = function(L_600)
		local L_601 = ReplicatedStorage:WaitForChild("Requests"):WaitForChild("GetMouse")
		if not OriginalGetMouseCallback then
			OriginalGetMouseCallback = getcallbackvalue(L_601, "OnClientInvoke")
		end
		L_601.OnClientInvoke = function()
			local L_602 = workspace.CurrentCamera
			local L_603 = L_600.CFrame + L_600.AssemblyLinearVelocity * (0.25 + Latency.rtt())
			local L_604 = L_602:WorldToViewportPoint(L_603.Position)
			local L_605 = L_602:ViewportPointToRay(L_604.X, L_604.Y)
			return { Hit = L_603, Target = L_600, UnitRay = L_605, X = L_604.X, Y = L_604.Y }
		end
		return
	end
	local AttackNearby = function()
		for L_607, L_608 in next, ShrinePositions, nil do
			local L_609 = Finder.enear(L_608.pos, L_608.radius)
			if L_609 then
				local L_610 = L_609:FindFirstChild("HumanoidRootPart")
				if not L_36 or L_610 then
					SpoofMouse(L_610)
					InputClient.left(L_610.CFrame, true)
					return true
				end
			end
		end
		return false
	end
	local AttackTarget = function()
		local L_612 = Finder.geir(300, true)
		if L_36 and not L_612 then
			return true
		end
		local L_613 = CurrentTarget or L_612[1]
		if not L_613 then
			return true
		end
		if not L_613.Parent then
			return false
		end
		local L_614 = L_613:FindFirstChild("HumanoidRootPart")
		if not L_614 then
			return false
		end
		local L_615 = L_613:FindFirstChild("Humanoid")
		if not L_615 then
			return false
		end
		if L_615.Health <= 0 then
			return false
		end
		CurrentTarget = L_613
		local L_616 = (L_614.CFrame * AboveOffset).Position
		local L_617 = CFrame.lookAt(L_616, L_614.Position)
		Tweening.stop("JoyFarm_TweenAboveShrine")
		Tweening.goal("JoyFarm_TweenToTarget", L_617, false)
		SpoofMouse(L_614)
		InputClient.left(L_614.CFrame, true)
		return true
	end
	local IdleState = FiniteState.new("Idle", function(L_619, L_620)
		local L_621 = Finder.wshrine()
		local L_622 = L_621:WaitForChild("InteractPrompt")
		Tweening.goal("JoyFarm_TweenToShrine", L_621:GetPivot(), false)
		while task.wait() do
			fireproximityprompt(L_622)
			local L_623 = Finder.sprompts()
			if TableUtil.find(L_623, function(L_624, L_625)
				return L_624:lower():match("wave 1")
			end) then
				return L_620:transition("Attack")
			end
		end
		return L_620:transition("Attack")
	end, function()
		Tweening.stop("JoyFarm_TweenToShrine")
		return
	end)
	local AttackState = FiniteState.new("Attack", function(L_627, L_628)
		while task.wait() do
			local L_629 = Finder.sprompts()
			if
				TableUtil.find(L_629, function(L_630, L_631)
					return L_630:lower():match("final wave cleared")
				end)
			then
				return L_628:transition("Idle")
			end
			local L_632 = Finder.wshrine()
			Tweening.goal("JoyFarm_TweenAboveShrine", L_632:GetPivot() * AboveOffset, false)
			Tweening.stop("JoyFarm_TweenToTarget")
			if not AttackNearby() and not AttackTarget() then
				CurrentTarget = nil
			end
		end
		return
	end, function()
		Tweening.stop("JoyFarm_TweenAboveShrine")
		Tweening.stop("JoyFarm_TweenToTarget")
		local L_633 = ReplicatedStorage:WaitForChild("Requests"):WaitForChild("GetMouse")
		if OriginalGetMouseCallback then
			L_633.OnClientInvoke = OriginalGetMouseCallback
		end
		return
	end)
	local JoyFSM = FiniteStateMachine.new({ IdleState, AttackState }, "Idle")
	JoyFarmCore.start = function()
		AntiAFK.start("JoyFarm")
		JoyMaid:add(TaskSpawner.spawn("JoyFarm_StateMachineStart", JoyFSM.start, JoyFSM))
		return
	end
	JoyFarmCore.stop = function()
		AntiAFK.stop("JoyFarm")
		JoyFSM:stop()
		JoyMaid:clean()
		return
	end
	return JoyFarmCore
end)
register_fn("Utility/TaskSpawner", function(require, L_637, L_638, L_639)
	local TaskSpawnerCore = {}
	local Profiler = require("Utility/Profiler")
	local Logger = require("Utility/Logger")
	local RunService = game:GetService("RunService")
	TaskSpawnerCore.delay = function(L_644, L_645, L_646, ...)
		local L_648 = function(L_647)
			Logger.trace("onTaskFunctionError - (%s) - %s", L_644, L_647)
			return
		end
		local L_649 = Profiler.wrap(
			L_644,
			LPH_NO_VIRTUALIZE(function(...)
				local LoggerInstance = os.clock()
				while os.clock() - LoggerInstance < L_645() do
					RunService.RenderStepped:Wait()
				end
				return xpcall(L_646, L_648, ...)
			end)
		)
		return task.spawn(L_649, ...)
	end
	TaskSpawnerCore.spawn = function(L_650, L_651, ...)
		local L_653 = function(L_652)
			Logger.trace("onTaskFunctionError - (%s) - %s", L_650, L_652)
			return
		end
		local L_654 = Profiler.wrap(
			L_650,
			LPH_NO_VIRTUALIZE(function(...)
				return xpcall(L_651, L_653, ...)
			end)
		)
		return task.spawn(L_654, ...)
	end
	return TaskSpawnerCore
end)
register_fn("Utility/Logger", function(require, L_656, L_657, L_658)
	return LPH_NO_VIRTUALIZE(function()
		local LoggerInstance = {}
		LoggerInstance.__index = LoggerInstance
		local Library = require("GUI/Library")
		local Configuration = require("Utility/Configuration")
		local FormatLog = nil
		FormatLog = function(N_4)
			return string.format("[%s %s] [Lycoris Recode]: %s", os.date("%x"), os.date("%X"), N_4)
		end
		LoggerInstance["mnnotify"] = function(N_5, ...)
			return Library:ManuallyManagedNotify(string.format(N_5, ...))
		end
		LoggerInstance["qnotify"] = function(N_6, ...)
			local N_7 = Configuration.expectOptionValue("QuickNotificationSpeed") or 0.5
			Library:Notify(string.format(N_6, ...), N_7)
		end
		LoggerInstance["notify"] = function(N_8, ...)
			Library:Notify(string.format(N_8, ...), 3)
		end
		LoggerInstance["longNotify"] = function(N_9, ...)
			Library:Notify(string.format(N_9, ...), 30)
		end
		LoggerInstance["warn"] = function(N_10, ...)
			if L_35 and shared.Lycoris.silent then
				return
			end
			warn(string.format(FormatLog(N_10), ...))
		end
		LoggerInstance["trace"] = function(N_11, ...)
			if L_36 and shared.Lycoris.silent then
				return
			end
			LoggerInstance.warn(N_11, ...)
			warn(debug.traceback(2))
		end
		return LoggerInstance
	end)()
end)
register_fn("Utility/Configuration", function(L_659, L_660, L_661, L_662)
	return {
		expectToggleValue = LPH_NO_VIRTUALIZE(function(LoggerInstance)
			if not Toggles then
				return nil
			end
			local Library = Toggles[LoggerInstance]
			if not Library then
				return nil
			end
			return Library.Value
		end),
		expectOptionValue = LPH_NO_VIRTUALIZE(function(LoggerInstance)
			if not Options then
				return nil
			end
			local Library = Options[LoggerInstance]
			if not Library then
				return nil
			end
			return Library.Value
		end),
		expectOptionValues = LPH_NO_VIRTUALIZE(function(LoggerInstance)
			if not Options then
				return nil
			end
			local Library = Options[LoggerInstance]
			if not Library then
				return nil
			end
			return Library.Values
		end),
		identify = LPH_NO_VIRTUALIZE(function(LoggerInstance, Library)
			return LoggerInstance .. Library
		end),
		idToggleValue = LPH_NO_VIRTUALIZE(function(LoggerInstance, Library)
			if not Toggles then
				return nil
			end
			local Configuration = Toggles[LoggerInstance .. Library]
			if not Configuration then
				return nil
			end
			return Configuration.Value
		end),
		idOptionValue = LPH_NO_VIRTUALIZE(function(LoggerInstance, Library)
			if not Options then
				return nil
			end
			local Configuration = Options[LoggerInstance .. Library]
			if not Configuration then
				return nil
			end
			return Configuration.Value
		end),
		idOptionValues = LPH_NO_VIRTUALIZE(function(LoggerInstance, Library)
			if not Options then
				return nil
			end
			local Configuration = Options[LoggerInstance .. Library]
			if not Configuration then
				return nil
			end
			return Configuration.Values
		end),
	}
end)
register_fn("GUI/Library", function(L_663, L_664, L_665, L_666)
	local L_667 = L_663("Utility/Profiler")
	local L_668 = L_663("Utility/CoreGuiManager")
	return LPH_NO_VIRTUALIZE(function()
		local LoggerInstance = game:GetService("UserInputService")
		local Library = game:GetService("TextService")
		local Configuration = game:GetService("Teams")
		local FormatLog = game:GetService("Players")
		local N_4 = game:GetService("RunService")
		local N_5 = game:GetService("TweenService")
		local N_6 = N_4.RenderStepped
		local N_7 = FormatLog.LocalPlayer
		local N_8 = N_7:GetMouse()
		local N_9 = protectgui or syn and syn.protect_gui or function() end
		local N_10 = L_668.imark(Instance.new("ScreenGui"))
		N_9(N_10)
		N_10.ZIndexBehavior = Enum.ZIndexBehavior.Global
		local N_11 = {}
		local N_12 = {}
		local N_13 = {}
		local N_14 = {}
		local N_15 = {}
		local N_16 = {}
		local N_17 = {}
		local N_18 = os.clock()
		local N_19 = false
		local N_20 = false
		pcall(function()
			getgenv().Toggles = N_11
			getgenv().Options = N_12
		end)
		local N_21 = {
			Registry = {},
			RegistryMap = {},
			OverrideData = {},
			HudRegistry = {},
			FontColor = Color3.fromRGB(255, 255, 255),
			MainColor = Color3.fromRGB(28, 28, 28),
			BackgroundColor = Color3.fromRGB(20, 20, 20),
			AccentColor = Color3.fromRGB(0, 85, 255),
			OutlineColor = Color3.fromRGB(50, 50, 50),
			RiskColor = Color3.fromRGB(255, 50, 50),
			Black = Color3.new(0, 0, 0),
			Font = Font.fromEnum(Enum.Font.RobotoMono),
			OpenedFrames = {},
			DependencyBoxes = {},
			Signals = {},
			ScreenGui = N_10,
		}
		local N_22 = 0
		local N_23 = 0
		local N_24 = {}
		local N_25 = nil
		table.insert(
			N_21.Signals,
			N_6:Connect(function(N_26)
				if N_11.ShowLoggerWindow and not N_11.ShowLoggerWindow.Value then
					N_14 = {}
				end
				local N_27, N_28 = next(N_14)
				if N_27 and N_28 then
					N_14[N_27] = nil
					N_28()
				end
				N_22 = N_22 + N_26
				if N_22 >= 0.1 then
					if next(N_24) == nil then
						N_25 = nil
						return
					end
					N_22 = 0
					N_23 = N_23 + 0.0025
					if N_23 > 1 then
						N_23 = 0
					end
					N_21.CurrentRainbowHue = N_23
					N_21.CurrentRainbowColor = Color3.fromHSV(N_23, 0.8, 1)
					if N_25 ~= nil and N_24[N_25] == nil then
						N_25 = nil
					end
					local N_29 = next(N_24, N_25)
					if N_29 == nil then
						N_29 = next(N_24, nil)
					end
					if not N_29 then
						N_25 = nil
						return
					end
					N_25 = N_29
					N_25:Display()
				end
				local N_30 = game:GetService("Players").LocalPlayer
				local N_31 = N_30 and N_30.PlayerGui
				local N_32 = N_31 and N_31:FindFirstChild("CursorGui")
				local N_33 = N_32 and N_32:FindFirstChild("Cursor")
				if N_33 then
					N_33.Visible = false
				end
			end)
		)
		local N_34 = nil
		N_34 = function()
			local N_35 = FormatLog:GetPlayers()
			for N_36 = 1, #N_35 do
				N_35[N_36] = N_35[N_36].Name
			end
			table.sort(N_35, function(N_37, N_38)
				return N_37 < N_38
			end)
			return N_35
		end
		local N_39 = nil
		N_39 = function()
			local N_40 = Configuration:GetTeams()
			for N_41 = 1, #N_40 do
				N_40[N_41] = N_40[N_41].Name
			end
			table.sort(N_40, function(N_42, N_43)
				return N_42 < N_43
			end)
			return N_40
		end
		N_21["GetOverrideData"] = function(N_44, N_45)
			for N_46, N_47 in next, N_21.OverrideData do
				if N_45:lower():match(N_46:lower()) then
					return N_47
				end
			end
		end
		N_21["SafeCallback"] = function(N_48, N_49, N_50, ...)
			if not N_50 then
				return
			end
			xpcall(L_667.wrap(N_49, N_50), function(N_51)
				warn(string.format("Library:SafeCallback - failed on label %s - %s", N_49, N_51))
				warn(debug.traceback())
			end, ...)
		end
		N_21["AttemptSave"] = function(N_52)
			if N_21.SaveManager then
				N_21.SaveManager:Save()
			end
		end
		N_21["Create"] = function(N_53, N_54, N_55)
			local N_56 = N_54
			if type(N_54) == "string" then
				N_56 = Instance.new(N_54)
			end
			for N_57, N_58 in next, N_55 do
				N_56[N_57] = N_58
			end
			return N_56
		end
		N_21["KeyBlacklists"] = function(N_59)
			local N_60 = {}
			for N_61, N_62 in next, N_21.InfoLoggerData.KeyBlacklistList do
				if not N_62 then
					continue
				end
				N_60[#N_60 + 1] = N_61
			end
			return N_60
		end
		N_21["RefreshInfoLogger"] = function(N_63)
			local N_64 = N_21.InfoLoggerCycles[N_21.InfoLoggerCycle]
			local N_65 = N_21.InfoLoggerData.KeyBlacklistList
			for N_66, N_67 in next, N_21.InfoLoggerData.MissingDataEntries do
				if not N_65[N_67.Key] then
					continue
				end
				table.remove(N_21.InfoLoggerData.MissingDataEntries, N_66)
				pcall(N_67.Label.Destroy, N_67.Label)
			end
			for N_68, N_69 in next, N_21.InfoLoggerData.MissingDataEntries do
				N_69.Label.Parent = N_69.Type == N_64 and N_21.InfoLoggerContainer or nil
				N_69.Label.LayoutOrder = N_68
			end
			N_21.InfoLoggerLabel.Text = string.format("Info Logger (%s)", N_64)
			local N_70 = 0
			local N_71 = 0
			for N_72, N_73 in next, N_21.InfoLoggerData.MissingDataEntries do
				if not N_73.Label.Parent then
					continue
				end
				N_70 = N_70 + N_73.Label.TextBounds.Y + 2
				if N_73.Label.TextBounds.X <= N_71 then
					continue
				end
				N_71 = N_73.Label.TextBounds.X
			end
			N_71 = N_71 + 20
			N_70 = N_70 + 22
			N_21.InfoLoggerFrame.Size = UDim2.new(0, math.clamp(N_71, 210, 800), 0, math.clamp(N_70, 24, 180))
		end
		N_21["AddMissEntry"] = function(N_74, N_75, N_76, N_77, N_78, N_79)
			local N_80 = N_21.InfoLoggerData
			local N_81 = N_80.MissingDataEntries
			local N_82 = N_80.KeyBlacklistList
			if N_82[N_76] then
				return
			end
			table.insert(N_14, 1, function()
				debug.profilebegin("Library:AddMissEntry")
				local N_83 = nil
				N_83 = function()
					local N_84 = {}
					for N_85, N_86 in next, N_81 do
						if N_86.Type == N_75 then
							table.insert(N_84, { [1] = N_86, [2] = N_85 })
						end
					end
					return N_84
				end
				local N_87 = N_83()
				local N_88 = N_87[#N_87]
				if #N_87 > 30 and N_88 then
					N_88[1].Label:Destroy()
					table.remove(N_81, N_88[2])
				end
				local N_89 = typeof(N_76) == "string" and tonumber(N_76:sub(14, 40)) or nil
				local N_90 = N_21:CreateLabel({
					Text = N_77 and string.format("(%.2fm away) Key '%s' from '%s' is missing.", N_78, N_76, N_77)
						or string.format("(%.2fm away) Key '%s' is missing.", N_78, N_76),
					TextXAlignment = Enum.TextXAlignment.Left,
					Size = UDim2.new(1, 0, 0, 14),
					LayoutOrder = 1,
					TextSize = 12,
					Visible = true,
					ZIndex = 306,
					Parent = nil,
				}, true)
				if N_79 then
					N_90.Text = string.format("(%s) %s", N_79, N_90.Text)
				end
				N_21:AddToRegistry(N_90, { TextColor3 = "FontColor" }, true)
				if N_89 then
					task.spawn(function()
						pcall(function()
							local N_91 = game:GetService("MarketplaceService"):GetProductInfo(N_89)
							if not N_91 then
								return
							end
							N_90.Text = string.format("(%s) %s", N_91.Name, N_90.Text)
						end)
					end)
				end
				local N_92 = { Label = N_90, Key = N_76, Type = N_75 }
				N_90.InputBegan:Connect(function(N_93)
					if N_93.UserInputType == Enum.UserInputType.MouseButton1 then
						setclipboard(N_76)
						N_21:Notify(string.format("Copied key '%s' to clipboard.", N_76))
					end
					if N_93.UserInputType == Enum.UserInputType.MouseButton2 then
						N_80.KeyBlacklistList[N_76] = true
						N_80.KeyBlacklistHistory[#N_80.KeyBlacklistHistory + 1] = N_76
						N_21:RefreshInfoLogger()
						if N_12 and N_12.BlacklistedKeys then
							N_12.BlacklistedKeys:SetValues(N_21:KeyBlacklists())
						end
						N_21:Notify(string.format("Blacklisted key '%s' from list.", N_76))
					end
				end)
				table.insert(N_81, 1, N_92)
				N_21:RefreshInfoLogger()
				debug.profileend()
			end)
		end
		N_21["ApplyTextStroke"] = function(N_94, N_95)
			N_95.TextStrokeTransparency = 1
		end
		N_21["CreateLabel"] = function(N_96, N_97, N_98)
			local N_99 = N_21:Create("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = N_21.Font,
				TextColor3 = N_21.FontColor,
				TextSize = 16,
				TextStrokeTransparency = 0,
			})
			N_21:ApplyTextStroke(N_99)
			N_21:AddToRegistry(N_99, { TextColor3 = "FontColor" }, N_98)
			if N_97.TextSize then
				N_97.TextSize = N_97.TextSize + 1
			end
			return N_21:Create(N_99, N_97)
		end
		N_21["MakeDraggable"] = function(N_100, N_101, N_102)
			N_101.Active = true
			N_101.InputBegan:Connect(function(N_103)
				if N_103.UserInputType == Enum.UserInputType.MouseButton1 then
					local N_104 = Vector2.new(N_8.X - N_101.AbsolutePosition.X, N_8.Y - N_101.AbsolutePosition.Y)
					if N_104.Y > (N_102 or 40) then
						return
					end
					while LoggerInstance:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
						N_101.Position = UDim2.new(
							0,
							N_8.X - N_104.X + N_101.Size.X.Offset * N_101.AnchorPoint.X,
							0,
							N_8.Y - N_104.Y + N_101.Size.Y.Offset * N_101.AnchorPoint.Y
						)
						N_6:Wait()
					end
				end
			end)
		end
		N_21["AddToolTip"] = function(N_105, N_106, N_107)
			local N_108, N_109 = N_21:GetTextBounds(N_106, N_21.Font, 14)
			local N_110 = N_21:Create("Frame", {
				BackgroundColor3 = N_21.MainColor,
				BorderColor3 = N_21.OutlineColor,
				Size = UDim2.fromOffset(N_108 + 5, N_109 + 4),
				ZIndex = 100,
				Parent = N_21.ScreenGui,
				Visible = false,
			})
			local N_111 = N_21:CreateLabel({
				Position = UDim2.fromOffset(3, 1),
				Size = UDim2.fromOffset(N_108, N_109),
				TextSize = 14,
				Text = N_106,
				TextColor3 = N_21.FontColor,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = N_110.ZIndex + 1,
				Parent = N_110,
			})
			N_21:AddToRegistry(N_110, { BackgroundColor3 = "MainColor", BorderColor3 = "OutlineColor" })
			N_21:AddToRegistry(N_111, { TextColor3 = "FontColor" })
			N_16[#N_16 + 1] = N_110
			local N_112 = false
			N_107.MouseEnter:Connect(function()
				if N_21:MouseIsOverOpenedFrame() then
					return
				end
				N_112 = true
				N_110.Position = UDim2.fromOffset(N_8.X + 15, N_8.Y + 12)
				N_110.Visible = true
				while N_112 do
					N_4.Heartbeat:Wait()
					N_110.Position = UDim2.fromOffset(N_8.X + 15, N_8.Y + 12)
				end
			end)
			N_107.MouseLeave:Connect(function()
				N_112 = false
				N_110.Visible = false
			end)
		end
		N_21["OnHighlight"] = function(N_113, N_114, N_115, N_116, N_117)
			N_114.MouseEnter:Connect(function()
				local N_118 = N_21.RegistryMap[N_115]
				for N_119, N_120 in next, N_116 do
					N_115[N_119] = N_21[N_120] or N_120
					if N_118 and N_118.Properties[N_119] then
						N_118.Properties[N_119] = N_120
					end
				end
			end)
			N_114.MouseLeave:Connect(function()
				local N_121 = N_21.RegistryMap[N_115]
				for N_122, N_123 in next, N_117 do
					N_115[N_122] = N_21[N_123] or N_123
					if N_121 and N_121.Properties[N_122] then
						N_121.Properties[N_122] = N_123
					end
				end
			end)
		end
		N_21["MouseIsOverOpenedFrame"] = function(N_124)
			for N_125, N_126 in next, N_21.OpenedFrames do
				local N_127 = N_125.AbsolutePosition
				local N_128 = N_125.AbsoluteSize
				if
					N_8.X >= N_127.X
					and N_8.X <= N_127.X + N_128.X
					and N_8.Y >= N_127.Y
					and N_8.Y <= N_127.Y + N_128.Y
				then
					return true
				end
			end
		end
		N_21["IsMouseOverFrame"] = function(N_129, N_130)
			local N_131 = N_130.AbsolutePosition
			local N_132 = N_130.AbsoluteSize
			if N_8.X >= N_131.X and N_8.X <= N_131.X + N_132.X and N_8.Y >= N_131.Y and N_8.Y <= N_131.Y + N_132.Y then
				return true
			end
		end
		N_21["UpdateDependencyBoxes"] = function(N_133)
			for N_134, N_135 in next, N_21.DependencyBoxes do
				N_135:Update()
			end
		end
		N_21["MapValue"] = function(N_136, N_137, N_138, N_139, N_140, N_141)
			return (1 - (N_137 - N_138) / (N_139 - N_138)) * N_140 + (N_137 - N_138) / (N_139 - N_138) * N_141
		end
		N_21["GetTextBounds"] = function(N_142, N_143, N_144, N_145, N_146)
			local N_147 = Library:GetTextSize(N_143, N_145, "RobotoMono", N_146 or Vector2.new(1920, 1080))
			return N_147.X, N_147.Y
		end
		N_21["GetDarkerColor"] = function(N_148, N_149)
			local N_150, N_151, N_152 = Color3.toHSV(N_149)
			return Color3.fromHSV(N_150, N_151, N_152 / 1.5)
		end
		N_21.AccentColorDark = N_21:GetDarkerColor(N_21.AccentColor)
		N_21["AddToRegistry"] = function(N_153, N_154, N_155, N_156)
			local N_157 = #N_21.Registry + 1
			local N_158 = { Instance = N_154, Properties = N_155, Idx = N_157 }
			table.insert(N_21.Registry, N_158)
			N_21.RegistryMap[N_154] = N_158
			if N_156 then
				table.insert(N_21.HudRegistry, N_158)
			end
		end
		N_21["RemoveFromRegistry"] = function(N_159, N_160)
			local N_161 = N_21.RegistryMap[N_160]
			if N_161 then
				for N_162 = #N_21.Registry, 1, -1 do
					if N_21.Registry[N_162] == N_161 then
						table.remove(N_21.Registry, N_162)
					end
				end
				for N_163 = #N_21.HudRegistry, 1, -1 do
					if N_21.HudRegistry[N_163] == N_161 then
						table.remove(N_21.HudRegistry, N_163)
					end
