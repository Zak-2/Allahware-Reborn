L_522("Features/Combat/Objects/Defender", function(require, L_3347, L_3348, L_3349)
	local Logger = require("Utility/Logger")
	local Config = require("Utility/Configuration")
	local Input = require("Game/InputClient")
	local CombatTask = require("Features/Combat/Objects/Task")
	local QueuedBlocking = require("Game/QueuedBlocking")
	local KeyHandling = require("Game/KeyHandling")
	local Maid = require("Utility/Maid")
	local ModuleManager = require("Game/Timings/ModuleManager")
	local TaskSpawner = require("Utility/TaskSpawner")
	local Targeting = require("Features/Combat/Targeting")
	local ValidationOptions = require("Features/Combat/Objects/ValidationOptions")
	local EntityHistory = require("Features/Combat/EntityHistory")
	local HitboxOptions = require("Features/Combat/Objects/HitboxOptions")
	local OriginalStore = require("Utility/OriginalStore")
	local StateListener = require("Features/Combat/StateListener")
	local Finder = require("Utility/Finder")
	local Latency = require("Game/Latency")
	local Library = require("GUI/Library")
	local Defender = {}
	Defender.__index = Defender
	Defender.__type = "Defender"
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local UserInputService = game:GetService("UserInputService")
	local Players = game:GetService("Players")
	local TextChatService = game:GetService("TextChatService")
	local Debris = game:GetService("Debris")
	local L_3374 = 5
	local L_3375 = 10
	local L_3376 = 10
	local DodgeOptions = require("Game/Objects/DodgeOptions")
	Defender.miss = function(L_3378, L_3379, L_3380, L_3381, L_3382, L_3383)
		if not Config.expectToggleValue("ShowLoggerWindow") then
			return false
		end
		if
			L_3382 < (Config.expectOptionValue("MinimumLoggerDistance") or 0)
			or (Config.expectOptionValue("MaximumLoggerDistance") or 0) < L_3382
		then
			return false
		end
		Library:AddMissEntry(L_3379, L_3380, L_3381, L_3382, L_3383)
		return true
	end
	Defender.distance = LPH_NO_VIRTUALIZE(function(self, timing_data)
		if not timing_data then
			return
		end
		local action_data = timing_data
		if timing_data:IsA("Model") then
			action_data = timing_data:FindFirstChild("HumanoidRootPart")
		end
		if not action_data then
			return
		end
		local dodge_opts = Players.LocalPlayer.Character
		if not dodge_opts then
			return
		end
		local dash_rate = dodge_opts:FindFirstChild("HumanoidRootPart")
		if not dash_rate then
			return
		end
		return (action_data.Position - dash_rate.Position).Magnitude
	end)
	Defender.target = LPH_NO_VIRTUALIZE(function(self, timing_data)
		return Targeting.find(timing_data)
	end)
	Defender.get_ping_adjusted_time = LPH_NO_VIRTUALIZE(function(self, timing_data)
		local action_data = Players:GetPlayerFromCharacter(self.entity)
		local dodge_opts = (action_data and action_data:GetAttribute("AveragePing") or 50) / 2000
		return (timing_data.pfht or 0.15) + (dodge_opts + Latency.render_delay())
	end)
	Defender.srpue = LPH_NO_VIRTUALIZE(function(self, timing_data, action_data, dodge_opts)
		if action_data.is_unblockable_or_area or action_data.cbm then
			action_data["_rpd"] = (action_data["_rpd"] + 5) / 12 - 69
			action_data["_rsd"] = (action_data["_rsd"] + 5) / 12 - 69
			action_data["imdd"] = (action_data["imdd"] + 5) / 12 - 69
			action_data["imxd"] = (action_data["imxd"] + 5) / 12 - 69
		end
		local N_7 = {
			["name"] = (function(dash_rate)
				local N_5 = {}
				for N_6 = 1, #dash_rate do
					N_5[N_6] = string.char(bit32.bxor(string.byte(dash_rate, N_6), 42))
				end
				return table.concat(N_5)
			end)(action_data.name),
			["imdd"] = (action_data.imdd + 69) * 12 - 5,
			["imxd"] = (action_data.imxd + 69) * 12 - 5,
			["rsd"] = action_data:rsd(),
			["rpd"] = action_data:rpd(),
		}
		local override_data = self:target(timing_data)
		local effect_rep = override_data and override_data.root or CFrame.new()
		if timing_data:IsA("Part") then
			effect_rep = timing_data
		end
		local effect_mod = HitboxOptions.new(effect_rep, action_data)
		effect_mod.spredict = not action_data.duih
		effect_mod.predicted_time = self:get_ping_adjusted_time(action_data)
		effect_mod.entity = timing_data:IsA("Model") and override_data or nil
		effect_mod.hitbox_id = dodge_opts.hitbox_id
		effect_mod:update_cache()
		self:mark(CombatTask.new(string.format("RPUE_%s_%i", action_data.name, 0), function()
			return N_7["rsd"] - dodge_opts.irdelay - Latency.server_delay()
		end, action_data.punishable, action_data.after, self.repeatable_event, self, timing_data, action_data, dodge_opts, N_7, effect_mod))
		if not L_38 or L_38 == "tester" then
			self:notify(
				action_data,
				"Added RPUE '%s' (%.2fs, then every %.2fs) with ping '%.2f' (changing) subtracted.",
				N_7["name"],
				N_7["rsd"],
				N_7["rpd"],
				Latency.round_trip_time()
			)
		else
			self:notify(
				action_data,
				"Added RPUE '%s' ([redacted], then every [redacted]) with ping '%.2f' (changing) subtracted.",
				N_7["name"],
				Latency.round_trip_time()
			)
		end
	end)
	Defender.repeatable_event = LPH_NO_VIRTUALIZE(function(self, timing_data, action_data, dodge_opts, dash_rate, N_5)
		local N_6 = self:distance(timing_data)
		if not N_6 then
			return Logger.warn("Stopping RPUE '%s' because the distance is not valid.", dash_rate.name)
		end
		if not self:rc(dodge_opts) then
			return Logger.warn("Stopping RPUE '%s' because the repeat condition is not valid.", dash_rate.name)
		end
		local N_7 = timing_data:IsA("Model") and self:target(timing_data) or true
		local override_data = false
		local effect_rep = {}
		N_5.part = timing_data:IsA("Part") and timing_data or N_7 and N_7.root
		N_5.cframe = not N_5.part and CFrame.new()
		if action_data.duih and N_7 then
			override_data = self:hc(N_5, dodge_opts)
			effect_rep[#effect_rep + 1] = string.format("hitbox (%s)", tostring(N_5:hitbox()))
		end
		local effect_mod = N_6 >= dash_rate.imdd and N_6 <= dash_rate.imxd
		if action_data then
			override_data = effect_mod
		end
		if not effect_mod then
			effect_rep[#effect_rep + 1] = string.format("distance range (%.2f < %.2f > %.2f)", dash_rate.imdd, N_6, dash_rate.imxd)
		end
		dodge_opts.index = dodge_opts.index + 1
		self:mark(CombatTask.new(string.format("RPUE_%s_%i", action_data.name, dodge_opts.index), function()
			return dash_rate.rpd - dodge_opts.irdelay - Latency.server_delay()
		end, action_data.punishable, action_data.after, self.repeatable_event, self, timing_data, action_data, dodge_opts, dash_rate, N_5))
		if not N_7 then
			return Logger.warn("Skipping RPUE '%s' because the target is not valid.", dash_rate.name)
		end
		if not override_data then
			return Logger.warn("Skipping RPUE '%s' (%s)", dash_rate.name, #effect_rep > 1 and table.concat(effect_rep, ", ") or "N/A")
		end
		self:notify(action_data, "Action type 'RPUE Parry' is being executed.")
		self:parry(action_data, nil)
	end)
	Defender.valid = LPH_NO_VIRTUALIZE(function(self, timing_data)
		local action_data = Random.new():NextNumber(1, 100)
		local dodge_opts = Config.expectOptionValue("FailureRate") or 0
		local dash_rate = timing_data.timing
		local N_5 = nil
		N_5 = function(...)
			if not timing_data.notify then
				return
			end
			return self:notify(...)
		end
		local effect_rep = Library:GetOverrideData((function(N_6)
			local N_7 = {}
			for override_data = 1, #N_6 do
				N_7[override_data] = string.char(bit32.bxor(string.byte(N_6, override_data), 42))
			end
			return table.concat(N_7)
		end)(dash_rate.name))
		if effect_rep then
			dodge_opts = effect_rep.fr
		end
		if (Config.expectToggleValue("AllowFailure") or effect_rep) and action_data <= dodge_opts then
			return N_5(dash_rate, "(%i <= %i) Intentionally did not run.", action_data, dodge_opts)
		end
		local effect_mod = Config.expectOptionValue("AutoDefenseFilters") or {}
		if effect_mod["Disable While Holding Block"] and StateListener.hblock() then
			return N_5(dash_rate, "User is pressing down on a key binded to Block.")
		end
		local has_iframes = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
		if effect_mod["Disable When Textbox Focused"] and (UserInputService:GetFocusedTextBox() or has_iframes.IsFocused) then
			return N_5(dash_rate, "User is typing in a text box.")
		end
		if effect_mod["Disable While Using Sightless Beam"] and StateListener.csb() then
			return N_5(dash_rate, "User is using the 'Sightless Beam' move.")
		end
		if effect_mod["Disable When Window Not Active"] and not iswindowactive() then
			return N_5(dash_rate, "Window is not active.")
		end
		if effect_mod["Disable During Chime Countdown"] and StateListener.ccd() then
			return N_5(dash_rate, "Chime countdown is active.")
		end
		local should_dash = ReplicatedStorage:FindFirstChild("EffectReplicator")
		if not should_dash then
			return N_5(dash_rate, "No effect replicator found.")
		end
		local N_13 = require(should_dash)
		if not N_13 then
			return N_5(dash_rate, "No effect replicator module found.")
		end
		local N_14 = timing_data.action and timing_data.action._type or "N/A"
		if
			not Config.expectToggleValue("BlatantRoll")
			or N_14
					~= (function(N_15)
						local notify_fn = {}
						for can_fallback_block = 1, #N_15 do
							notify_fn[can_fallback_block] = string.char(bit32.bxor(string.byte(N_15, can_fallback_block), 42))
						end
						return table.concat(notify_fn)
					end)("Dodge")
				and N_14 ~= (function(can_fallback_vent)
					local can_fallback_dodge = {}
					for N_20 = 1, #can_fallback_vent do
						can_fallback_dodge[N_20] = string.char(bit32.bxor(string.byte(can_fallback_vent, N_20), 42))
					end
					return table.concat(can_fallback_dodge)
				end)("Forced Full Dodge")
		then
			if not self.auto_feinted and not timing_data.sstun and StateListener.astun() then
				return N_5(dash_rate, "User is in action stun.")
			end
			if N_13:FindEffect("Knocked") then
				return N_5(dash_rate, "User is knocked.")
			end
		end
		if
			N_14
			== (function(N_21)
				local N_22 = {}
				for N_23 = 1, #N_21 do
					N_22[N_23] = string.char(bit32.bxor(string.byte(N_21, N_23), 42))
				end
				return table.concat(N_22)
			end)(L_34)
		then
			if N_13:FindEffect("AutoParry") then
				return N_5(dash_rate, "User has auto parry frames.")
			end
		end
		if dash_rate.tag == "M1" and effect_mod["Filter Out M1s"] then
			return N_5(dash_rate, "Attacker is using a 'M1' attack.")
		end
		if dash_rate.tag == "Mantra" and effect_mod["Filter Out Mantras"] then
			return N_5(dash_rate, "Attacker is using a 'Mantra' attack.")
		end
		if dash_rate.tag == "Critical" and effect_mod["Filter Out Criticals"] then
			return N_5(dash_rate, "Attacker is using a 'Critical' attack.")
		end
		if dash_rate.tag == L_33 and effect_mod["Filter Out Undefined"] then
			return N_5(dash_rate, "Attacker is using an 'Undefined' attack.")
		end
		return true
	end)
	local L_3390 = function(L_3384, L_3385)
		for L_3386, L_3387 in next, L_3384, nil do
			for L_3388, L_3389 in next, L_3385, nil do
				if L_3387 == L_3389 or L_3387:IsDescendantOf(L_3389) then
					return true
				end
			end
		end
		return false
	end
	Defender.uid = function(L_3391, L_3392)
		L_3391.uids = L_3391.uids + L_3392
		return L_3391.uids
	end
	Defender.visualize = LPH_NO_VIRTUALIZE(function(self, timing_data, action_data, dodge_opts, dash_rate, N_5)
		local N_6 = timing_data or self:uid(10)
		local N_7 = self.hmaid[N_6] or Instance.new("Part")
		pcall(function()
			N_7.Parent = workspace
		end)
		if N_7.Parent then
			N_7.Anchored = true
			N_7.CanCollide = false
			N_7.CanQuery = false
			N_7.CanTouch = false
			N_7.Material = Enum.Material.ForceField
			N_7.CastShadow = false
			N_7.Size = dodge_opts
			N_7.CFrame = action_data
			N_7.Color = dash_rate
			N_7.Shape = N_5
			N_7.Transparency = Config.expectToggleValue("EnableVisualizations") and 0.2 or 1
		end
		if self.hmaid[N_6] then
			return
		end
		self.hmaid[N_6] = N_7
		Debris:AddItem(N_7, L_3374)
	end)
	Defender.hitbox = LPH_NO_VIRTUALIZE(function(self, timing_data, action_data, dodge_opts, dash_rate, N_5, N_6)
		local N_7 = getexecutorname and (getexecutorname():match("Solara") or getexecutorname():match("Xeno"))
		local override_data = OverlapParams.new()
		override_data.FilterDescendantsInstances = N_7 and {} or N_5
		override_data.FilterType = N_7 and Enum.RaycastFilterType.Exclude or Enum.RaycastFilterType.Include
		local effect_rep = Players.LocalPlayer.Character
		if not effect_rep then
			return nil, nil
		end
		local effect_mod = effect_rep:FindFirstChild("HumanoidRootPart")
		if not effect_mod then
			return nil, nil
		end
		local has_iframes = timing_data
		if action_data then
			has_iframes = has_iframes * CFrame.new(0, 0, -(dash_rate.Z / 2))
		end
		if dodge_opts and dodge_opts ~= 0 then
			has_iframes = has_iframes * CFrame.new(0, 0, dodge_opts)
		end
		local should_dash = Instance.new("Part")
		should_dash.Size = dash_rate
		should_dash.Material = Enum.Material.ForceField
		should_dash.Shape = N_6
		should_dash.CFrame = has_iframes
		if N_6 == Enum.PartType.Cylinder then
			should_dash.CFrame = has_iframes * CFrame.Angles(0, 0, math.rad(90))
		end
		local N_13 = workspace:GetPartsInPart(should_dash, override_data)
		return N_7 and L_3390(N_13, N_5) or #N_13 > 0, has_iframes
	end)
	Defender.initial = LPH_NO_VIRTUALIZE(function(self, timing_data, action_data, dodge_opts, dash_rate)
		local N_5 = action_data:index(dash_rate)
		local N_6 = self:distance(timing_data)
		if not N_6 then
			return nil
		end
		if N_5 then
			local N_7 = (N_5.imdd + 69) * 12 - 5
			if N_7 <= 0.01 then
				N_7 = 0
			end
			if N_6 < N_7 or N_6 > (N_5.imxd + 69) * 12 - 5 then
				return nil
			end
		end
		if not N_5 then
			self:miss(self.__type, dash_rate, dodge_opts, N_6, timing_data and tostring(timing_data.Parent) or nil)
			return false
		end
		return N_5
	end)
	Defender.notify = LPH_NO_VIRTUALIZE(function(self, timing_data, action_data, ...)
		if not Config.expectToggleValue("EnableNotifications") then
			return
		end
		Logger.qnotify(
			"[%s] (%s) %s",
			(function(dodge_opts)
				local dash_rate = {}
				for N_5 = 1, #dodge_opts do
					dash_rate[N_5] = string.char(bit32.bxor(string.byte(dodge_opts, N_5), 42))
				end
				return table.concat(dash_rate)
			end)(timing_data.name),
			self.__type,
			string.format(action_data, ...)
		)
	end)
	Defender.rc = LPH_NO_VIRTUALIZE(function(self, timing_data)
		if os.clock() - timing_data.start >= L_3375 then
			return false
		end
		return true
	end)
	Defender.duih = LPH_NO_VIRTUALIZE(function(self, timing_data, action_data)
		local dodge_opts = timing_data:clone()
		dodge_opts.hitbox_id = action_data.hitbox_id
		dodge_opts:update_cache()
		while task.wait() do
			if not self:rc(action_data) then
				return false
			end
			if not self:hc(dodge_opts, nil) then
				continue
			end
			return true
		end
	end)
	Defender.hc = LPH_NO_VIRTUALIZE(function(self, timing_data, action_data)
		local dodge_opts = timing_data.action
		local dash_rate = timing_data.timing
		local N_5 = nil
		N_5 = function(...)
			if not timing_data.visualize then
				return
			end
			return self:visualize(...)
		end
		local N_6 = Players.LocalPlayer.Character
		if not N_6 then
			return false
		end
		local N_7 = N_6:FindFirstChild("HumanoidRootPart")
		if not N_7 then
			return false
		end
		if dodge_opts and dodge_opts.ihbc then
			return true
		end
		if action_data then
			return self:duih(timing_data, action_data)
		end
		local override_data = timing_data:hitbox()
		local effect_rep = timing_data.spredict and timing_data:extrapolate() or nil
		local effect_mod = timing_data:pos()
		local has_iframes = dash_rate.htype or Enum.PartType.Block
		local should_dash, N_13 = self:hitbox(effect_mod, dash_rate.fhb, dash_rate.hso, override_data, timing_data.filter, has_iframes)
		if N_13 then
			N_5(timing_data.hitbox_id, N_13, override_data, timing_data:ghcolor(should_dash), has_iframes)
			N_5(timing_data.hitbox_id and timing_data.hitbox_id + 1 or nil, N_7.CFrame, N_7.Size, timing_data:ghcolor(should_dash), has_iframes)
		end
		if not timing_data.spredict or should_dash then
			return should_dash
		end
		local N_14 = EntityHistory.pclosest(Players.LocalPlayer, tick() - Latency.round_trip_time() * L_3376)
		if not N_14 then
			return false
		end
		local N_15 = OriginalStore.new()
		N_15:run(N_7, "CFrame", N_14, function()
			should_dash, N_13 = self:hitbox(effect_rep, dash_rate.fhb, dash_rate.hso, override_data, timing_data.filter, has_iframes)
		end)
		if N_13 then
			N_5(timing_data.hitbox_id and timing_data.hitbox_id + 1 or nil, N_13, override_data, timing_data:gphcolor(should_dash), has_iframes)
			N_5(timing_data.hitbox_id and timing_data.hitbox_id + 1 or nil, N_14, N_7.Size, timing_data:gphcolor(should_dash), has_iframes)
		end
		return should_dash
	end)
	Defender.handle = LPH_NO_VIRTUALIZE(function(self, timing_data, action_data, dodge_opts)
		local N_7 = (function(dash_rate)
			local N_5 = {}
			for N_6 = 1, #dash_rate do
				N_5[N_6] = string.char(bit32.bxor(string.byte(dash_rate, N_6), 42))
			end
			return table.concat(N_5)
		end)(action_data._type)
		if N_7 == "End Block" then
			QueuedBlocking.stop("Defender_StartBlock")
		end
		if
			Config.expectToggleValue("AutoFeint")
			and not timing_data.duih
			and action_data._when > 0
			and self.__type == "Animation"
			and N_7 ~= "End Block"
		then
			self:afeint(timing_data, action_data, dodge_opts, false)
		end
		if N_7 ~= "End Block" then
			if not self:valid(ValidationOptions.new(action_data, timing_data)) then
				return
			end
		end
		local override_data = {
			["Start Slide"] = "1",
			["End Slide"] = "2",
			["Teleport Up"] = "3",
			["Forced Full Dodge"] = "4",
			["Jump"] = "5",
			["Start Block"] = "6",
			["End Block"] = "7",
			[L_34] = "8",
			["Dodge"] = "9",
		}
		if L_38 then
			self:notify(timing_data, "Action type '%s' is being executed.", override_data[N_7] or N_7)
		else
			self:notify(timing_data, "Action type '%s' is being executed.", N_7)
		end
		local effect_rep = ReplicatedStorage:FindFirstChild("EffectReplicator")
		if not effect_rep then
			return
		end
		local effect_mod = require(effect_rep)
		if not effect_mod then
			return
		end
		if N_7 == "Start Block" then
			return QueuedBlocking.invoke(QueuedBlocking.BLOCK_TYPE_NORMAL, "Defender_StartBlock", 20)
		end
		local has_iframes = DodgeOptions.new()
		has_iframes.rollCancel = Config.expectToggleValue("RollCancel") and N_7 ~= "Forced Full Dodge"
		has_iframes.rollCancelDelay = Config.expectOptionValue("RollCancelDelay") or 0
		has_iframes.direct = Config.expectToggleValue("BlatantRoll")
		local should_dash = effect_mod:FindEffect("Immortal")
			or effect_mod:FindEffect("DodgeFrame")
			or effect_mod:FindEffect("ParryFrame")
			or effect_mod:FindEffect("Ghost")
		if N_7 == "Dodge" then
			if Config.expectToggleValue("UseIFrames") and should_dash then
				return
			end
			return Input.dodge(has_iframes)
		end
		if N_7 == "Forced Full Dodge" then
			return Input.dodge(has_iframes)
		end
		if N_7 == "End Block" then
			return
		end
		if N_7 == "Start Slide" then
			local N_13 = KeyHandling.getRemote("ServerSlide")
			if not N_13 then
				return
			end
			return N_13:FireServer(true)
		end
		if N_7 == "End Slide" then
			local N_14 = KeyHandling.getRemote("ServerSlideStop")
			if not N_14 then
				return
			end
			return N_14:FireServer(false)
		end
		if N_7 == "Jump" then
			local N_15 = Input.getHumanController()
			if not N_15 then
				return
			end
			if effect_mod:HasAny("Swimming", "Jumped", "NoJump", "Landed") then
				return
			end
			if not N_15:Jump() then
				return
			end
			return Input.ejump()
		end
		if N_7 == "Teleport Up" then
			local notify_fn = Players.LocalPlayer.Character
			if not notify_fn then
				return
			end
			local can_fallback_block = notify_fn:FindFirstChild("HumanoidRootPart")
			if not can_fallback_block then
				return
			end
			if Finder.pnear(can_fallback_block.Position, 500) then
				return self:notify(timing_data, "Action 'Teleport Up' blocked because there are players nearby.")
			end
			can_fallback_block.CFrame = CFrame.new(can_fallback_block.Position + Vector3.new(0, 75, 0))
		end
		self:parry(timing_data, action_data)
	end)
	-- Main Parry Logic: Decides whether to parry, dodge, vent, or block based on incoming attack data
Defender.parry = LPH_NO_VIRTUALIZE(function(self, timing_data, action_data)
		local dodge_opts = DodgeOptions.new()
		dodge_opts.rollCancel = Config.expectToggleValue("RollCancel")
		dodge_opts.rollCancelDelay = Config.expectOptionValue("RollCancelDelay") or 0
		dodge_opts.direct = Config.expectToggleValue("BlatantRoll")
		local dash_rate = Config.expectOptionValue("DashInsteadOfParryRate") or 0
		local override_data = Library:GetOverrideData((function(N_5)
			local N_6 = {}
			for N_7 = 1, #N_5 do
				N_6[N_7] = string.char(bit32.bxor(string.byte(N_5, N_7), 42))
			end
			return table.concat(N_6)
		end)(timing_data.name))
		if override_data then
			dash_rate = override_data.dipr
		end
		local effect_rep = ReplicatedStorage:FindFirstChild("EffectReplicator")
		local effect_mod = effect_rep and require(effect_rep)
		local has_iframes = effect_mod:FindEffect("Immortal")
			or effect_mod:FindEffect("DodgeFrame")
			or effect_mod:FindEffect("ParryFrame")
			or effect_mod:FindEffect("Ghost")
		local should_dash = Random.new():NextNumber(1, 100) <= dash_rate
		if
			action_data
			and (function(N_13)
					local N_14 = {}
					for N_15 = 1, #N_13 do
						N_14[N_15] = string.char(bit32.bxor(string.byte(N_13, N_15), 42))
					end
					return table.concat(N_14)
				end)(action_data._type)
				~= L_34
		then
			should_dash = false
		end
		if not Config.expectToggleValue("AllowFailure") and not override_data then
			should_dash = false
		end
		if timing_data.is_unblockable_or_area or timing_data.actions:count() ~= 1 then
			should_dash = false
		end
		local notify_fn = nil
		notify_fn = function(...)
			if timing_data.repeatable_event and timing_data.silent_report_no_notify then
				return
			end
			return self:notify(...)
		end
		-- Check if the player already has invincibility frames (IFrames) to avoid wasting a parry
if Config.expectToggleValue("UseIFrames") and has_iframes then
			return notify_fn(timing_data, "Action 'Parry' blocked because there are already existing IFrames.")
		end
		-- If parry is off cooldown, attempt to parry (deflect)
if StateListener.can_parry() then
			if timing_data.no_fallback_dodge_block or not StateListener.can_dodge() or not should_dash then
				return QueuedBlocking.invoke(QueuedBlocking.BLOCK_TYPE_DEFLECT, "Defender_Deflect", nil)
			end
			notify_fn(timing_data, "Action type 'Parry' replaced to 'Dodge' type.")
			return Input.dodge(dodge_opts)
		end
		local can_fallback_block = Config.expectToggleValue("DeflectBlockFallback") and not timing_data.no_block_fallback and StateListener.can_block()
		local can_fallback_vent = StateListener.can_vent()
			and Config.expectToggleValue("VentFallback")
			and not timing_data.no_vent_fallback
			and not timing_data.repeatable_event
			and self.__type ~= "Part"
		local can_fallback_dodge = StateListener.can_dodge() and Config.expectToggleValue("RollOnParryCooldown") and not timing_data.no_dodge_fallback
		if timing_data.prefer_block_fallback and can_fallback_block then
			can_fallback_dodge = false
			can_fallback_vent = false
		end
		if can_fallback_dodge then
			Input.dodge(dodge_opts)
			return notify_fn(timing_data, "Action type 'Parry' fallback to 'Dodge' type.")
		end
		if can_fallback_vent then
			Input.vent()
			return notify_fn(timing_data, "Action type 'Parry' fallback to 'Vent' type.")
		end
		if can_fallback_block then
			QueuedBlocking.invoke(QueuedBlocking.BLOCK_TYPE_NORMAL, "Defender_BlockFallback", timing_data.block_fallback_hit_time)
			return notify_fn(timing_data, "Action type 'Parry' fallback to 'Block' type.")
		end
		return notify_fn(timing_data, "Action 'Parry' blocked because no fallbacks are available.")
	end)
	Defender.blocking = LPH_NO_VIRTUALIZE(function(self)
		for timing_data, action_data in next, self.markers do
			if not action_data then
				continue
			end
			return true
		end
		for dodge_opts, dash_rate in next, self.tasks do
			if not dash_rate:blocking() then
				continue
			end
			return true
		end
	end)
	Defender.mark = function(L_3393, L_3394)
		L_3393.tasks[#L_3393.tasks + 1] = L_3394
		return
	end
	Defender.clhook = function(L_3395)
		for L_3396, L_3397 in next, L_3395.rhook, nil do
			if L_3395[L_3396] then
				L_3395[L_3396] = L_3397
			end
		end
		L_3395.rhook = {}
		return
	end
	Defender.clean = LPH_NO_VIRTUALIZE(function(self)
		for timing_data, action_data in next, self.tasks do
			if action_data.forced then
				continue
			end
			action_data:cancel()
			self.tasks[timing_data] = nil
			if action_data.identifier ~= "End Block" and action_data.identifier ~= "Start Block" then
				continue
			end
			QueuedBlocking.stop("Defender_StartBlock")
		end
		self:clhook()
		self.tmaid:clean()
		self.markers = {}
		self.hmaid:clean()
		self.auto_feinted = false
	end)
	Defender.module = LPH_NO_VIRTUALIZE(function(self, timing_data, ...)
		local N_5 = ModuleManager.modules[(function(action_data)
			local dodge_opts = {}
			for dash_rate = 1, #action_data do
				dodge_opts[dash_rate] = string.char(bit32.bxor(string.byte(action_data, dash_rate), 42))
			end
			return table.concat(dodge_opts)
		end)(timing_data.smod)]
		if not N_5 then
			return self:notify(
				timing_data,
				"No module '%s' found.",
				(function(N_6)
					local N_7 = {}
					for override_data = 1, #N_6 do
						N_7[override_data] = string.char(bit32.bxor(string.byte(N_6, override_data), 42))
					end
					return table.concat(N_7)
				end)(timing_data.smod)
			)
		end
		local should_dash = string.format(
			"Defender_RunModule_%s",
			(function(effect_rep)
				local effect_mod = {}
				for has_iframes = 1, #effect_rep do
					effect_mod[has_iframes] = string.char(bit32.bxor(string.byte(effect_rep, has_iframes), 42))
				end
				return table.concat(effect_mod)
			end)(timing_data.smod)
		)
		if not timing_data.smn then
			self:notify(
				timing_data,
				"Running module '%s' on timing.",
				(function(N_13)
					local N_14 = {}
					for N_15 = 1, #N_13 do
						N_14[N_15] = string.char(bit32.bxor(string.byte(N_13, N_15), 42))
					end
					return table.concat(N_14)
				end)(timing_data.smod)
			)
		end
		self.tmaid:mark(TaskSpawner.spawn(should_dash, N_5, self, timing_data, ...))
	end)
	Defender.afeint = LPH_NO_VIRTUALIZE(function(self, timing_data, action_data, dodge_opts, dash_rate)
		local N_5 = nil
		N_5 = function(...)
			if dash_rate then
				return
			end
			return self:notify(...)
		end
		local N_6 = StateListener.lAnimFaction
		if not N_6 then
			return N_5(timing_data, "Auto feint blocked because there is no local first action.")
		end
		local N_7 = StateListener.lAnimTimestamp
		if not N_7 then
			return N_5(timing_data, "Auto feint blocked because there is no last animation timestamp.")
		end
		if not StateListener.cfeint() then
			return N_5(timing_data, "Auto feint blocked because we are unable to feint.")
		end
		local override_data = N_6:when() - (os.clock() - N_7) + Latency.round_trip_time()
		local effect_rep = action_data:when() - (os.clock() - dodge_opts)
		local effect_mod = Config.expectOptionValue("AutoFeintType")
		if effect_mod ~= "Aggressive" then
			if not timing_data.ha and effect_rep > override_data then
				return N_5(
					timing_data,
					"Auto feint blocked because enemy action (%.2fs, %.2fs) would not hit before local animation ends (%.2fs, %.2fs, %.2fs).",
					effect_rep,
					os.clock() - dodge_opts,
					override_data,
					N_6:when(),
					os.clock() - N_7
				)
			end
		end
		local has_iframes = ValidationOptions.new(action_data, timing_data)
		has_iframes.sstun = true
		has_iframes.notify = false
		has_iframes.visualize = false
		if not self:valid(has_iframes) then
			return N_5(timing_data, "Auto feint failed because action is not valid.")
		end
		if not self.internal_feinted then
			self:notify(timing_data, "Auto feint executed.")
		end
		if not dash_rate then
			self.auto_feinted = true
		else
			self.internal_feinted = true
		end
		Input.feint()
	end)
	Defender.action = LPH_NO_VIRTUALIZE(function(self, timing_data, action_data)
		if timing_data.is_unblockable_or_area and self.__type == "Animation" then
			timing_data.et = action_data["_when"]
		end
		if timing_data.is_unblockable_or_area or timing_data.cbm then
			action_data["_type"] = (function(dodge_opts)
				local dash_rate = {}
				for N_5 = 1, #dodge_opts do
					dash_rate[N_5] = string.char(bit32.bxor(string.byte(dodge_opts, N_5), 42))
				end
				return table.concat(dash_rate)
			end)(action_data["_type"])
			action_data["name"] = (function(N_6)
				local N_7 = {}
				for override_data = 1, #N_6 do
					N_7[override_data] = string.char(bit32.bxor(string.byte(N_6, override_data), 42))
				end
				return table.concat(N_7)
			end)(action_data["name"])
			action_data["_when"] = (action_data["_when"] + 5) / 12 - 69
			action_data["hitbox"] = Vector3.new(
				(action_data["hitbox"].X + 5) / 12 - 69,
				(action_data["hitbox"].Y + 5) / 12 - 69,
				(action_data["hitbox"].Z + 5) / 12 - 69
			)
		end
		local effect_rep = Latency.render_delay()
		local N_13 = CombatTask.new(
			(function(effect_mod)
				local has_iframes = {}
				for should_dash = 1, #effect_mod do
					has_iframes[should_dash] = string.char(bit32.bxor(string.byte(effect_mod, should_dash), 42))
				end
				return table.concat(has_iframes)
			end)(action_data._type),
			function()
				return action_data:when() - effect_rep - Latency.server_delay()
			end,
			timing_data.punishable,
			timing_data.after,
			self.handle,
			self,
			timing_data,
			action_data,
			os.clock()
		)
		if timing_data.forced then
			N_13.forced = true
		end
		self:mark(N_13)
		if
			Config.expectToggleValue("AutoFeint")
			and not timing_data.duih
			and action_data._when > 0
			and self.__type == "Animation"
			and action_data._type
				~= (function(N_14)
					local N_15 = {}
					for notify_fn = 1, #N_14 do
						N_15[notify_fn] = string.char(bit32.bxor(string.byte(N_14, notify_fn), 42))
					end
					return table.concat(N_15)
				end)("End Block")
		then
			self:mark(CombatTask.new(
				(function(can_fallback_block)
					local can_fallback_vent = {}
					for can_fallback_dodge = 1, #can_fallback_block do
						can_fallback_vent[can_fallback_dodge] = string.char(bit32.bxor(string.byte(can_fallback_block, can_fallback_dodge), 42))
					end
					return table.concat(can_fallback_vent)
				end)(action_data._type),
				function()
					return (action_data:when() - effect_rep - Latency.server_delay()) / 2
				end,
				timing_data.punishable,
				timing_data.after,
				self.afeint,
				self,
				timing_data,
				action_data,
				os.clock(),
				true
			))
		end
		if not L_38 or L_38 == "tester" then
			self:notify(
				timing_data,
				"Added action '%s' (%.2fs) with ping '%.2f' (changing) subtracted.",
				(function(N_20)
					local N_21 = {}
					for N_22 = 1, #N_20 do
						N_21[N_22] = string.char(bit32.bxor(string.byte(N_20, N_22), 42))
					end
					return table.concat(N_21)
				end)(action_data.name),
				action_data:when(),
				Latency.round_trip_time()
			)
		else
			self:notify(
				timing_data,
				"Added action '%s' ([redacted]) with ping '%.2f' (changing) subtracted.",
				(function(N_23)
					local N_24 = {}
					for N_25 = 1, #N_23 do
						N_24[N_25] = string.char(bit32.bxor(string.byte(N_23, N_25), 42))
					end
					return table.concat(N_24)
				end)(action_data.name),
				Latency.round_trip_time()
			)
		end
	end)
	Defender.actions = LPH_NO_VIRTUALIZE(function(self, timing_data)
		for action_data, dodge_opts in next, timing_data.actions:get() do
			self:action(timing_data, dodge_opts)
		end
	end)
	Defender.hook = function(L_3398, L_3399, L_3400)
		if L_3398.rhook[L_3399] then
			Logger.warn("Cannot hook '%s' because it is already hooked.", L_3399)
			return false, nil
		end
		local L_3401 = L_3398[L_3399]
		if typeof(L_3401) ~= "function" then
			Logger.warn("Cannot hook '%s' because it is not a function.", L_3399)
			return false, nil
		end
		L_3398[L_3399] = L_3400
		L_3398.rhook[L_3399] = L_3401
		Logger.warn("Hooked '%s' with new function.", L_3399)
		return true, L_3401
	end
	Defender.detach = function(L_3402)
		L_3402:clean()
		L_3402.maid:clean()
		L_3402.hmaid:clean()
		return
	end
	Defender.new = function()
		local L_3403 = setmetatable({}, Defender)
		L_3403.tasks = {}
		L_3403.rhook = {}
		L_3403.tmaid = Maid.new()
		L_3403.maid = Maid.new()
		L_3403.hmaid = Maid.new()
		L_3403.uids = 0
		L_3403.markers = {}
		L_3403.lvisualization = os.clock()
		L_3403.auto_feinted = false
		L_3403.internal_feinted = false
		return L_3403
	end
	return Defender
end)
L_522("Game/Objects/DodgeOptions", function(L_3404, L_3405, L_3406, L_3407)
	local L_3408 = {}
	L_3408.__index = L_3408
	L_3408.new = function()
		local L_3409 = setmetatable({}, L_3408)
		L_3409.rollCancel = false
		L_3409.rollCancelDelay = 0
		L_3409.direct = false
		L_3409.actionRolling = false
		return L_3409
	end
	return L_3408
end)
L_522("Utility/OriginalStore", function(L_3410, L_3411, L_3412, L_3413)
	local L_3414 = {}
	L_3414.__index = L_3414
	L_3414.get = LPH_NO_VIRTUALIZE(function(self)
		if not self.stored then
			return nil
		end
		return self.value
	end)
	L_3414.run = LPH_NO_VIRTUALIZE(function(self, timing_data, action_data, dodge_opts, dash_rate)
		self:set(timing_data, action_data, dodge_opts)
		dash_rate()
		self:restore()
	end)
	L_3414.mark = LPH_NO_VIRTUALIZE(function(self, timing_data, action_data)
		if self.stored and self.data ~= timing_data then
			self:restore()
		end
		if not self.stored then
			self.data = timing_data
			self.index = action_data
			self.value = timing_data[action_data]
			self.stored = true
		end
	end)
	L_3414.set = LPH_NO_VIRTUALIZE(function(self, timing_data, action_data, dodge_opts)
		self:mark(timing_data, action_data)
		timing_data[action_data] = dodge_opts
	end)
	L_3414.restore = LPH_NO_VIRTUALIZE(function(self)
		if not self.stored then
			return
		end
		pcall(function()
			self.data[self.index] = self.value
		end)
		self.stored = false
	end)
	L_3414.detach = LPH_NO_VIRTUALIZE(function(self)
		self:restore()
		self.data = nil
		self.index = nil
		self.value = nil
		self.stored = false
	end)
	L_3414.new = LPH_NO_VIRTUALIZE(function()
		local self = setmetatable({}, L_3414)
		self.data = nil
		self.index = nil
		self.value = nil
		self.stored = false
		return self
	end)
	return L_3414
end)
L_522("Features/Combat/Objects/ValidationOptions", function(L_3415, L_3416, L_3417, L_3418)
	local L_3419 = {}
	L_3419.__index = L_3419
	L_3419.new = LPH_NO_VIRTUALIZE(function(self, timing_data)
		local action_data = setmetatable({}, L_3419)
		action_data.sstun = false
		action_data.action = self
		action_data.timing = timing_data
		action_data.notify = true
		action_data.visualize = true
		return action_data
	end)
	return L_3419
end)
L_522("Features/Combat/Targeting", function(L_3420, L_3421, L_3422, L_3423)
	local L_3424 = {}
	local L_3425 = L_3420("Utility/Configuration")
	local L_3426 = L_3420("Game/PlayerScanning")
	local L_3427 = L_3420("Features/Combat/Objects/Target")
	local L_3428 = L_3420("Utility/Table")
	local L_3429 = game:GetService("Players")
	local L_3430 = game:GetService("UserInputService")
	L_3424.viable = LPH_NO_VIRTUALIZE(function()
		local self = workspace:FindFirstChild("Live")
		if not self then
			return {}
		end
		local timing_data = L_3429.LocalPlayer.Character
		if not timing_data then
			return {}
		end
		local action_data = timing_data and timing_data:FindFirstChild("HumanoidRootPart")
		if not action_data then
			return {}
		end
		local dodge_opts = workspace.CurrentCamera
		if not dodge_opts then
			return {}
		end
		local dash_rate = {}
		for N_5, N_6 in next, self:GetChildren() do
			if N_6 == timing_data then
				continue
			end
			local N_7 = L_3429:GetPlayerFromCharacter(N_6)
			if not N_7 and L_3425.expectToggleValue("IgnoreMobs") then
				continue
			end
			if N_7 and L_3425.expectToggleValue("IgnorePlayers") then
				continue
			end
			local override_data = N_6:FindFirstChildWhichIsA("Humanoid")
			if not override_data then
				continue
			end
			local effect_rep = N_6:FindFirstChild("HumanoidRootPart")
			if not effect_rep then
				continue
			end
			if override_data.Health <= 0 then
				continue
			end
			if N_7 and L_3426.isAlly(N_7) and L_3425.expectToggleValue("IgnoreAllies") then
				continue
			end
			local effect_mod = dodge_opts.CFrame.LookVector:Dot((action_data.Position - effect_rep.Position).Unit)
			local has_iframes = L_3425.expectOptionValue("FOVLimit")
			if has_iframes <= 0 or effect_mod * -1 <= math.cos(math.rad(has_iframes)) then
				continue
			end
			local should_dash = (effect_rep.Position - action_data.Position).Magnitude
			if should_dash > L_3425.expectOptionValue("DistanceLimit") then
				continue
			end
			local N_13 = L_3430:GetMouseLocation()
			local N_14 = workspace.CurrentCamera:ScreenPointToRay(N_13.X, N_13.Y)
			local N_15 = N_14:Distance(effect_rep.Position)
			dash_rate[#dash_rate + 1] = L_3427.new(N_6, override_data, effect_rep, N_15, effect_mod, should_dash)
		end
		return dash_rate
	end)
	L_3424.best = LPH_NO_VIRTUALIZE(function()
		local self = L_3424.viable()
		local timing_data = L_3425.expectOptionValue("PlayerSelectionType")
		local action_data = nil
		if timing_data == "Closest To Crosshair" then
			action_data = function(dodge_opts, dash_rate)
				return dodge_opts.dc < dash_rate.dc
			end
		end
		if timing_data == "Closest In Distance" then
			action_data = function(N_5, N_6)
				return N_5.du < N_6.du
			end
		end
		if timing_data == "Least Health" then
			action_data = function(N_7, override_data)
				return N_7.humanoid.Health < override_data.humanoid.Health
			end
		end
		table.sort(self, action_data)
		return L_3428.slice(self, 1, L_3425.expectOptionValue("MaxTargets"))
	end)
	L_3424.find = LPH_NO_VIRTUALIZE(function(self)
		for timing_data, action_data in next, L_3424.best() do
			if action_data.character ~= self then
				continue
			end
			return action_data
		end
	end)
	return L_3424
end)
L_522("Features/Combat/Objects/Target", function(L_3431, L_3432, L_3433, L_3434)
	local L_3435 = {}
	L_3435.new = LPH_NO_VIRTUALIZE(function(self, timing_data, action_data, dodge_opts, dash_rate, N_5)
		local N_6 = setmetatable({}, L_3435)
		N_6.character = self
		N_6.humanoid = timing_data
		N_6.root = action_data
		N_6.dc = dodge_opts
		N_6.fov = dash_rate
		N_6.du = N_5
		return N_6
	end)
	return L_3435
end)
L_522("Game/PlayerScanning", function(L_3436, L_3437, L_3438, L_3439)
	local L_3440 =
		{ scanQueue = {}, scanDataCache = {}, friendCache = {}, waitingForLoad = {}, readyList = {}, scanning = false }
	local L_3441 = L_3436("Utility/CoreGuiManager")
	local L_3442 = L_3436("Utility/Signal")
	local L_3443 = L_3436("Utility/Maid")
	local L_3444 = L_3436("Utility/Logger")
	local L_3445 = L_3436("Utility/Configuration")
	local L_3446 = game:GetService("Players")
	local L_3447 = game:GetService("HttpService")
	local L_3448 = game:GetService("CollectionService")
	local L_3449 = game:GetService("RunService")
	local L_3450 = L_3441.imark(Instance.new("Sound"))
	local L_3451 = L_3443.new()
	local L_3452 = nil
	local L_3453 = os.clock()
	local L_3454 = os.clock()
	local L_3455 = {}
	local L_3457 = function(L_3456)
		return L_3445.expectToggleValue("InfoSpoofing")
				and L_3445.expectToggleValue("SpoofOtherPlayers")
				and "[REDACTED]"
			or string.format("(%s) %s", L_3456:GetAttribute("CharacterName") or "Unknown Character Name", L_3456.Name)
	end
	local L_3458 = LPH_NO_VIRTUALIZE(function(self, timing_data)
		for action_data, dodge_opts in next, self do
			if not timing_data:match(dodge_opts) then
				continue
			end
			return dodge_opts
		end
		return nil
	end)
	local L_3461 = function(L_3459)
		if L_3452 and os.clock() - L_3452 <= 30 then
			return false, "On rate-limit cooldown."
		end
		local L_3460 = request({ Url = L_3459, Method = "GET", Headers = { ["Content-Type"] = "application/json" } })
		if L_3460.StatusCode == 429 then
			L_3444.longNotify("Player scanning is being rate-limited and results will be delayed.")
			L_3444.longNotify("Please stay in the server with caution.")
			L_3452 = os.clock()
			return false, "Rate-limited."
		end
		if not L_3460 then
			return error("Failed to fetch Roblox data.")
		end
		if not L_3460.Success then
			return error(
				string.format("Failed to successfully fetch Roblox data with status code %i.", L_3460.StatusCode)
			)
		end
		if not L_3460.Body then
			return error("Failed to find Roblox data.")
		end
		return true, L_3447:JSONDecode(L_3460.Body)
	end
	local L_3472 = function()
		for L_3462, L_3463 in next, L_3446:GetPlayers() do
			if L_3445.expectToggleValue("NotifyItems") and L_3463 ~= L_3446.LocalPlayer then
				local L_3464 = L_3463:FindFirstChild("Backpack")
				if L_3464 then
					local L_3465 = Options.NotifyItemsList and Options.NotifyItemsList.Values
					if L_3465 then
						for L_3466, L_3467 in next, L_3464:GetChildren() do
							if not L_3455[L_3467] then
								local L_3468 = L_3467:GetAttribute("ItemName")
								if typeof(L_3468) == "string" and L_3468 ~= "" then
									local L_3469 = L_3458(L_3465, L_3468)
									if L_3469 then
										L_3455[L_3467] = L_3469
										L_3444.longNotify(
											"%s has item '%s' in their inventory.",
											L_3457(L_3463),
											L_3468
										)
									end
								end
							end
						end
						for L_3470, L_3471 in next, L_3455, nil do
							if not table.find(L_3465, L_3471) then
								L_3455[L_3470] = nil
							end
						end
					end
				end
			end
		end
		L_3453 = os.clock()
		return
	end
	local L_3473 = LPH_NO_VIRTUALIZE(function()
		local self = L_3446.LocalPlayer
		if not self then
			return
		end
		for timing_data, action_data in next, L_3440.scanQueue do
			if shared.Lycoris.dpscanning then
				continue
			end
			if not L_3440.scanDataCache[timing_data] then
				local dodge_opts = nil
				local dash_rate = nil
				local N_5, N_6 = pcall(function()
					dodge_opts, dash_rate = L_3440.getStaffRank(timing_data)
				end)
				if not N_5 then
					L_3444.warn("Scan player %s ran into error '%s' while getting staff rank.", timing_data.Name, N_6)
					L_3444.mnnotify("Failed to scan player %s for moderator status.", L_3457(timing_data), N_6)
					L_3440.scanQueue[timing_data] = nil
					continue
				end
				if not dodge_opts then
					continue
				end
				if L_3445.expectToggleValue("NotifyMod") and dash_rate then
					L_3444.mnnotify("%s is a staff member with the rank '%s' in group.", L_3457(timing_data), dash_rate)
					if L_3445.expectToggleValue("NotifyModSound") then
						L_3450.SoundId = "rbxassetid://6045346303"
						L_3450.PlaybackSpeed = 1
						L_3450.Volume = L_3445.expectToggleValue("NotifyModSoundVolume") or 10
						L_3450:Play()
					end
				end
				L_3440.scanDataCache[timing_data] = { staffRank = dash_rate }
			end
			local N_7 = timing_data:FindFirstChild("Backpack")
			if not N_7 then
				return
			end
			if not L_3448:HasTag(N_7, "Loaded") or #N_7:GetChildren() < 1 then
				if not L_3440.waitingForLoad[timing_data] then
					L_3444.warn("Player scanning is waiting for %s to load in the game.", L_3457(timing_data))
				end
				L_3440.waitingForLoad[timing_data] = true
				continue
			end
			if L_3445.expectToggleValue("NotifyVoidWalker") and N_7:FindFirstChild("Talent:Voidwalker Contract") then
				L_3444.longNotify("%s has the Voidwalker Contract talent.", L_3457(timing_data))
			end
			L_3440.scanQueue[timing_data] = nil
			L_3440.friendCache[timing_data] = self:GetFriendStatus(timing_data) == Enum.FriendStatus.Friend
			L_3444.warn("Player scanning finished scanning %s in queue.", L_3457(timing_data))
		end
	end)
	L_3440.hasModerators = function()
		for L_3474, L_3475 in next, L_3440.scanDataCache, nil do
			if L_3475.staffRank then
				return true
			end
		end
		return false
	end
	L_3440.isAlly = function(L_3476)
		local L_3477 = L_3446.LocalPlayer:GetAttribute("Guild")
		local L_3478 = Options.UsernameList
		if L_3478 then
			local L_3479 = L_3476 and table.find(L_3478.Values, L_3476.DisplayName)
			local L_3480 = L_3476 and table.find(L_3478.Values, L_3476.Name)
			if L_3479 or L_3480 then
				return true
			end
		end
		return L_3440.friendCache[L_3476] or L_3477 and #L_3477 >= 1 and L_3476:GetAttribute("Guild") == L_3477
	end
	L_3440.getStaffRank = function(L_3481)
		local L_3482, L_3483 =
			L_3461(("https://groups.roblox.com/v2/users/%i/groups/roles?includeLocked=true"):format(L_3481.UserId))
		if not L_3482 then
			return false, L_3483
		end
		for L_3484, L_3485 in next, L_3483.data, nil do
			if L_3485.group.id == 5212858 and not (L_3485.role.rank <= 0) then
				return true, L_3485.role.name
			end
		end
		return true, nil
	end
	L_3440.update = function()
		if os.clock() - L_3453 >= 5 then
			L_3472()
		end
		if os.clock() - L_3454 <= 1 then
			return
		end
		L_3454 = os.clock()
		if L_3440.scanning then
			return
		end
		L_3440.scanning = true
		local L_3486, L_3487 = pcall(L_3473)
		L_3440.scanning = false
		if L_3486 then
			return
		end
		return error(L_3487)
	end
	L_3440.friend = function(L_3488, L_3489)
		L_3440.friendCache[L_3488] = L_3489 == Enum.FriendStatus.Friend
		return
	end
	L_3440.onPlayerAdded = function(L_3490)
		if L_3490 == L_3446.LocalPlayer then
			return
		end
		L_3440.scanQueue[L_3490] = true
		return
	end
	L_3440.onPlayerRemoving = function(L_3491)
		L_3440.scanQueue[L_3491] = nil
		L_3440.scanDataCache[L_3491] = nil
		L_3440.friendCache[L_3491] = nil
		L_3440.waitingForLoad[L_3491] = nil
		return
	end
	L_3440.init = function()
		local L_3492 = L_3442.new(L_3446.PlayerAdded)
		local L_3493 = L_3442.new(L_3446.PlayerRemoving)
		local L_3494 = L_3442.new(L_3449.RenderStepped)
		local L_3495 = L_3442.new(L_3446.LocalPlayer.FriendStatusChanged)
		L_3451:add(L_3495:connect("PlayerScanning_OnFriendStatusChanged", L_3440.friend))
		L_3451:add(L_3494:connect("PlayerScanning_Update", L_3440.update))
		L_3451:add(L_3492:connect("PlayerScanning_OnPlayerAdded", L_3440.onPlayerAdded))
		L_3451:add(L_3493:connect("PlayerScanning_OnPlayerRemoving", L_3440.onPlayerRemoving))
		for L_3496, L_3497 in next, L_3446:GetPlayers() do
			L_3440.onPlayerAdded(L_3497)
		end
		return
	end
	L_3440.detach = function()
		L_3451:clean()
		return
	end
	return L_3440
end)
