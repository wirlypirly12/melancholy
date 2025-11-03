local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

if not LPH_OBFUSCATED then
	LPH_NO_VIRTUALIZE = function(...)
		return ...
	end
	LPH_JIT_MAX = function(...)
		return ...
	end
	LPH_NO_UPVALUES = function(...)
		return ...
	end
end

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Lib = {
	Flags = {},
	Options = {},
}

if not isfolder("melancholy") then
	makefolder("melancholy")
end

local _UpdatedLibrary = false
if not isfile("melancholy\\menu.lua") then
	writefile(
		"melancholy\\menu.lua",
		game:HttpGet("https://raw.githubusercontent.com/wirlypirly12/informant.wtf/refs/heads/main/src.lua")
	)
else
	local Menu = readfile("melancholy\\menu.lua")
	local MenuData =
		game:HttpGet("https://raw.githubusercontent.com/wirlypirly12/informant.wtf/refs/heads/main/src.lua")
	if Menu ~= MenuData then
		_UpdatedLibrary = true
		writefile("melancholy\\menu.lua", MenuData)
	end
end

local _Rig = {
	["HumanoidRootPart"] = 1,
	["Head"] = 2,
	["FakeHead"] = 2,
	["HeadHB"] = 2,
	["UpperTorso"] = 1,
	["LowerTorso"] = 1.25,
	["LeftUpperArm"] = 1,
	["LeftLowerArm"] = 1,
	["LeftHand"] = 1,
	["RightUpperArm"] = 1,
	["RightLowerArm"] = 1,
	["RightHand"] = 1,
	["LeftUpperLeg"] = 0.75,
	["LeftLowerLeg"] = 0.75,
	["LeftFoot"] = 0.75,
	["RightUpperLeg"] = 0.75,
	["RightLowerLeg"] = 0.75,
	["RightFoot"] = 0.75,
	["BackC4"] = true,
}

local Modules = {}
function CreateModule(Name, Data, HighPriority)
	coroutine.wrap(function()
		repeat
			task.wait()
		until next(Lib.Flags) ~= nil
		if Data.Init then
			local Before = collectgarbage("count")
			if not LPH_OBFUSCATED then
				print("Starting: " .. Name)
				print("Upvalues: " .. #getupvalues(Data.Init))
				local Init
				Init = hookfunction(Data.Init, function()
					local Success, Result = pcall(Init)
					if Success then
						local Message = tostring(Result)
						Message = Result and Message or "OK"
						print("Started: " .. Message)
					else
						print("Error: " .. Result)
					end
				end)
			end
			Data:Init()
			print("Init: " .. string.format("%.2f", math.abs((collectgarbage("count") - Before) / 1024)) .. "kB")
			print("=====================")
		end

		if Data.Tick then
			Data.Tick = LPH_JIT_MAX(LPH_NO_UPVALUES(Data.Tick))
		end

		Data.Name = Name
		Data.__Loaded = true
		Data._PRIORITY = HighPriority
		Modules[Name] = Data
	end)()
end

function SetModule(Name, Status)
	local Module = Modules[Name]
	if Module then
		Modules[Name].__Loaded = Status or false
	end
end

local Utility = {}
do
	function Utility:Stratify(i, n)
		return (i - 0.5 + math.random()) / n
	end

	function Utility:IsPressing(Key)
		return not UserInputService:GetFocusedTextBox() and UserInputService:IsKeyDown(Key)
	end

	function Utility:Millify(num)
		return num / 1000
	end

	function Utility:BuildSpreadState(SpreadStats, Client, Weapon, IsSniper)
		local Spread = SpreadStats.Value

		local standValue = SpreadStats:FindFirstChild("Stand") and SpreadStats.Stand.Value or 0
		local CrouchValue = SpreadStats:FindFirstChild("Crouch") and SpreadStats.Crouch.Value or standValue
		if Client.fullycrouched and Client.fullycrouched() then
			Spread += CrouchValue
		else
			Spread += standValue
		end

		if Spread <= 20 and not Weapon:FindFirstChild("SMGThing") then
			Spread = Spread / 10
		end

		if IsSniper then
			local ForcedADS = (Lib and Lib.Flags and Lib.Flags["AutoScope"]) and 1 or (Client.adsmodifier or 0)
			Spread *= (1 - ForcedADS)
		end

		if Weapon.Name == "Negev" and (Client.numShots or 0) >= 16 then
			Spread = 0
		end

		local Additional = Client.spread2 or 0
		local FireSpread = Client.firespread or 0
		local RecoilMag = (Client.getrec and Client.getrec() or 0)

		return math.max(0, Spread), Additional, FireSpread, RecoilMag
	end

	function Utility:FolderExist(FolderName)
		return isfolder("melancholy\\" .. FolderName)
	end

	function Utility:GetPartThickness(Part, Hitpos, Direction)
		local CF = Part.CFrame
		local Size = Part.Size

		local LocalHit = CF:PointToObjectSpace(Hitpos)
		local LocalDirection = CF:VectorToObjectSpace(Direction.Unit)

		local Half = Size / 2
		local TMin = -math.huge
		local TMax = math.huge

		local axes = { "X", "Y", "Z" }
		for _, axis in ipairs(axes) do
			local d = LocalDirection[axis]
			if d ~= 0 then
				local t1 = (-Half[axis] - LocalHit[axis]) / d
				local t2 = (Half[axis] - LocalHit[axis]) / d
				if t1 > t2 then
					t1, t2 = t2, t1
				end
				TMin = math.max(TMin, t1)
				TMax = math.min(TMax, t2)
			end
		end

		return math.max(0, TMax - TMin)
	end

	Utility.RayParams = RaycastParams.new()
	Utility.RayParams.FilterType = Enum.RaycastFilterType.Exclude
	Utility.RayParams.FilterDescendantsInstances = {}

	function Utility:Visible(TargetPart)
		local Internal = Modules["Internal"]
		if not Internal or not Internal.MapSpawned then
			return
		end

		if Internal.IgnoreList ~= Utility.RayParams.FilterDescendantsInstances then
			Utility.RayParams.FilterDescendantsInstances = Internal.IgnoreList
		end

		local Origin = Camera.CFrame.Position
		if not TargetPart or not TargetPart.Position then
			return false
		end

		local Direction = TargetPart.Position - Origin

		local Result = workspace:Raycast(Origin, Direction, Utility.RayParams)
		if Result and Result.Instance then
			local Character = TargetPart:FindFirstAncestorOfClass("Model")
			return Character and Result.Instance:IsDescendantOf(Character)
		end
		return true
	end

	function Utility:Capture(Character)
		local Captured = {}
		for i, Inst in next, Character:GetChildren() do
			if _Rig[Inst.Name] ~= nil then
				local Position, IsOnScreen = Camera:WorldToViewportPoint(Inst.Position)
				local Entry = Captured[Inst.Name] or {}
				Entry.OnScreen = Position.Z > 0
				Entry._2d = Vector2.new(Position.X, Position.Y)
				Entry.Part = Inst

				Captured[Inst.Name] = Entry
			elseif Inst.Name == "Humanoid" then
				Captured[Inst.Name] = Inst
			end
		end
		return Captured
	end

	function Utility:Render(Type, Props)
		local NewDrawing = Drawing.new(Type)
		if Type == "Circle" then
			NewDrawing.Filled = false
			NewDrawing.Thickness = 1
			NewDrawing.Position = Camera.ViewportSize / 2
		elseif Type == "Line" then
			NewDrawing.Thickness = 1
			NewDrawing.From = Camera.ViewportSize / 2
		end

		NewDrawing.Visible = false

		if Props then
			for Prop, Value in next, Props do
				NewDrawing[Prop] = Value
			end
		end

		return NewDrawing
	end

	function Utility:ShotOffset(Angle, Magnitude)
		local Rad = math.rad(Angle)
		local X = -math.cos(Rad) * Magnitude
		local Y = math.sin(Rad) * Magnitude
		return X, Y
	end

	CreateModule("Utility", Utility)
end

local Internal = {}
do
	local Client = getsenv(LocalPlayer.PlayerGui.Client)
	Internal.MyGun = nil
	Internal.LastRecoil = {}
	Internal.Weapons = ReplicatedStorage.Weapons
	Internal.Hits = {}

	Internal.Client = Client

	function Internal:Encode(Position)
		return Vector3.new(
			((Position.X - 74312) * 4 + 1325) * 13,
			(Position.Y + 3183421) * 4 - 4201432,
			(Position.Z * 41 - 581357) * 2
		)
	end

	function Internal:LogHit(WeaponName, Hit, DamageModifer, HitChance)
		local HitBacktrack = false

		if Modules["Players"] and Modules.Players:HitBacktrack(Hit) then
			HitBacktrack = true
			Hit = Modules.Players:GetRealPart(Hit)
		end

		local Char = Hit.Parent
		local Player = Players:GetPlayerFromCharacter(Char)

		if not Internal.MyGun or not _Rig[Hit.Name] then
			return
		end

		local HitID = tostring(tick()) .. "_" .. tostring(math.random(1000, 9999))
		local PredictedDamage = (Internal.MyGun.Damage * _Rig[Hit.Name]) * DamageModifer
		local OldHealth = Char.Humanoid.Health

		Internal.PendingHits = Internal.PendingHits or {}
		Internal.PendingHits[HitID] = {
			WeaponName = WeaponName,
			Hit = Hit,
			DamageModifer = DamageModifer,
			Player = Player,
			Char = Char,
			Timestamp = tick(),
			PredictedDamage = PredictedDamage,
			OldHealth = OldHealth,
			HitChance = HitChance,
			HitBacktrack = HitBacktrack,
		}

		task.spawn(function()
			local MaxWaitTime = math.min(LocalPlayer:GetNetworkPing() * 0.5 + 0.2, 1.0)
			local ElapsedTime = 0
			local CheckInterval = 0.016

			while ElapsedTime < MaxWaitTime and Internal.PendingHits[HitID] do
				task.wait(CheckInterval)
				ElapsedTime = ElapsedTime + CheckInterval

				if not Char:FindFirstChild("Humanoid") then
					Internal:ProcessHitResult(HitID, true, "kill", 100)
					return
				end

				if Char.Humanoid.Health < OldHealth then
					local ActualDamage = OldHealth - Char.Humanoid.Health
					local Accuracy = math.abs(ActualDamage - PredictedDamage) / PredictedDamage

					if Accuracy < 0.15 then
						Internal:ProcessHitResult(HitID, true, "hit", ActualDamage)
					else
						Internal:ProcessHitResult(HitID, true, "damage_mismatch", ActualDamage)
					end
					return
				end
			end

			if Internal.PendingHits[HitID] then
				Internal:ProcessHitResult(HitID, false, "timeout", 0)
			end
		end)
	end

	function Internal:ProcessHitResult(HitID, DidHit, Reason, ActualDamage)
		local HitData = Internal.PendingHits[HitID]
		if not HitData then
			return
		end

		Internal.PendingHits[HitID] = nil

		if Lib.Flags["EventsEnabled"] then
			if Lib.Flags["HitNotifications"] and library then
				local Status = DidHit and (ActualDamage == 100 and "killed" or "hit") or "missed"
				local DamageString = DidHit and string.format("%.0f", ActualDamage) or "?"
				local RemainingHealth = DidHit and math.clamp(HitData.Char.Humanoid.Health, 0, 100) or ""
				local HitChanceString = HitData.HitChance and string.format("%.0f", HitData.HitChance) or ""

				local Message = Status
					.. " "
					.. ((HitData.Player ~= nil and HitData.Player.Name) or "unknown")
					.. " in the "
					.. tostring(HitData.Hit):gsub("HB", ""):gsub("Fake", "")
					.. " for "
					.. DamageString
					.. "hp with "
					.. HitData.WeaponName
					.. " ("
					.. (DidHit and RemainingHealth or Reason)
					.. " hp remaining) "
					.. ((HitData.HitChance ~= nil) and ("(" .. HitChanceString .. " hc) ") or "")
					.. ((HitData.HitBacktrack ~= false) and "(backtrack) " or "")

				print("[melancholy] " .. Message)
				library:SendNotification(Message, Lib.Flags["HitDuration"])
			end

			if DidHit and Lib.Flags["HitSoundEnabled"] and Modules["SoundManager"] then
				local SoundManager = Modules.SoundManager
				if _Rig[HitData.Hit.Name] == 2 then
					local Sound = Lib.Flags["HeadShotSound"] == "Global" and Lib.Flags["HitSound"]
						or Lib.Flags["HeadShotSound"]
					SoundManager:PlaySound(Sound, (Lib.Flags["HeadShotSoundVolume"] / 100) * 2)
				else
					SoundManager:PlaySound(Lib.Flags["HitSound"], (Lib.Flags["HitSoundVolume"] / 100) * 2)
				end
			end
		end

		Internal.Hits[#Internal.Hits + 1] = {
			Gun = HitData.WeaponName,
			Hit = HitData.Hit,
			DamageModifer = HitData.DamageModifer,
			Confirmed = DidHit,
			ActualDamage = ActualDamage,
			Reason = Reason,
		}
	end

	function Internal:IsShooting()
		if not Internal.MyGun then
			return Client.vars.Held == true
		end

		if Client.numShots > 0 and (os.clock() - Internal.MyGun.LastShot) < 0.07 then
			return true
		end
	end

	function Internal:Hit(Hit, Position, Gun, Resolve, DamageModifier)
		-- game.ReplicatedStorage.Events.HitPart:FireServer(l_v480_0, v499, l_gun_1.Name, v405, v206:WaitForChild("Gun"), nil, damagemodifier, v405 == 48, v495, l_CurrentCamera_1.CFrame.p, game.Workspace.DistributedTime.Value, l_v482_0, true, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil);
		if Gun and Hit and Position then
			local Position = Resolve and Vector3.new() / 0 / 0 or Internal:Encode(Position)
			ReplicatedStorage.Events.HitPart:FireServer(
				Hit,
				Position,
				Gun.Name,
				Gun.Range.Value,
				LocalPlayer.Character:FindFirstChild("Gun"),
				nil,
				DamageModifier or 1,
				false,
				false,
				Camera.CFrame.p,
				workspace.DistributedTime.Value,
				0,
				true,
				nil,
				nil,
				nil,
				nil,
				nil,
				nil,
				nil,
				nil,
				nil,
				nil,
				nil,
				nil,
				nil
			)
		end
	end

	function Internal:IsSpraying(threshold)
		return Client.numShots >= threshold
	end

	function Internal:GetShootingState()
		return {
			Held = Client.vars.Held,
			Held2 = Client.vars.Held2,
			FireVariant = Client.firevariant,
			FireVariant2 = Client.firevariant2,
			FireSpread = Client.firespread,
			Mode = Client.mode,
		}
	end

	function Internal:FetchGun(Gun)
		Gun = Gun or Client.gun
		if typeof(Gun) == "Instance" then
			local Firerate = Gun:FindFirstChild("FireRate")
			local Damage = Gun:FindFirstChild("DMG")
			local Penetration = Gun:FindFirstChild("Penetration")
			local Range = Gun:FindFirstChild("Range")
			local Spread = Gun:FindFirstChild("Spread")

			if Firerate and Damage and Penetration and Range and Spread then
				return {
					Firerate = Firerate.Value,
					Damage = Damage.Value,
					Penetration = Penetration.Value,
					Range = Range.Value,
					Spread = Spread.Value,
					_Gun = Gun,
					LastShot = 0,
					LastDouble = 0,
				}
			end
		end
	end

	function Internal:Shoot()
		if not Internal.MyGun then
			return
		end

		if (os.clock() - Internal.MyGun.LastShot) >= Internal.MyGun.Firerate then
			Client.firebullet()
		end
	end

	_FireTrampoline = nil
	_GetPatTrampoline = nil
	_LoadAmmoTrampoline = nil
	-- DETOUR(s)
	function _LoadAmmo(...)
		if Lib.Flags["InfAmmo"] then
			Client.vars.ammocount = 1000
			Client.vars.amomcount2 = 1000
			Client.vars.ammocount3 = 1000
			print("hopoked")
			return
		end

		return _LoadAmmoTrampoline(...)
	end

	function _FireBullet(...)
		if library and library.open then
			return
		end

		if Internal.MyGun and Internal.MyGun.LastShot then
			Internal.MyGun.LastShot = os.clock()
		end

		local ScopeChanged = false
		if
			Lib.Flags["AutoScope"]
			and Client.gun:FindFirstChild("Scoped")
			and getupvalue(Client.updateads, 1) == false
		then
			setupvalue(Client.updateads, 1, true)
			ScopeChanged = true
			Client.updateads()
			task.wait(0.04)
		end

		local OldSilentCFrame = nil
		local OldRagebotCFrame = nil

		local SilentAim = Modules["SilentAim"]
		local Ragebot = Modules["Ragebot"]

		-- rcs
		local X, Y = nil
		if next(Internal.LastRecoil) ~= nil and not Lib.Flags["RemoveRecoil"] then
			X, Y = Utility:ShotOffset(Internal.LastRecoil.Angle, Internal.LastRecoil.Mag)
		end

		-- silent aim
		if
			SilentAim
			and Lib.Flags["SilentAimMode"] == "Normal"
			and SilentAim.Target.AimBone ~= nil
			and (math.random() * 100) <= Lib.Flags["SilentAimHitChance"]
		then
			OldSilentCFrame = Camera.CFrame
			Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, SilentAim.Target.AimBone.Part.Position)
			if X and Y then
				Camera.CFrame *= CFrame.Angles(math.rad(-Y), math.rad(-X), 0)
			end
		end

		-- ragebot hook
		if Ragebot and Ragebot.Target and Ragebot.Target.Bone then
			OldRagebotCFrame = Lib.Flags["RageSilent"] and Camera.CFrame or nil
			Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, Ragebot.Target.Bone.Position)
			if X and Y then
				Camera.CFrame *= CFrame.Angles(math.rad(-Y), math.rad(-X), 0)
			end
		end

		_FireTrampoline(...)

		if
			ScopeChanged
			and Lib.Flags["AutoScope"]
			and Client.gun:FindFirstChild("Scoped")
			and getupvalue(Client.updateads, 1) == true
		then
			ScopeChanged = false
			setupvalue(Client.updateads, 1, false)
		end

		if Lib.Flags["DoubleTap"] and (os.clock() - Internal.MyGun.LastDouble) >= 0.07 then
			Internal.MyGun.LastDouble = os.clock()
			Client.firebullet()
		end

		if Ragebot and Ragebot.OriginalPosition then
			if LocalPlayer.Character and LocalPlayer.Character.HumanoidRootPart then
				LocalPlayer.Character:SetPrimaryPartCFrame(CFrame.new(Ragebot.OriginalPosition))
				Ragebot:OriginalNil()
			end
		end

		if not OldRagebotCFrame and OldSilentCFrame then
			Camera.CFrame = OldSilentCFrame
		end

		if OldRagebotCFrame then
			Camera.CFrame = OldRagebotCFrame
		end

		if X and Y and (SilentAim and Lib.Flags["SilentAimMode"] == "Normal") then
			Camera.CFrame *= CFrame.Angles(math.rad(-Y), math.rad(-X), 0)
		end
	end

	function _GetPat(n, ...)
		local Data = _GetPatTrampoline(n, ...)
		Internal.LastRecoil = {
			Angle = Data.fAngle,
			Mag = Data.fMagnitude,
		}
		return Data
	end

	local Hooked = false

	Internal.Origin = Camera.CFrame.p

	function Internal:Init()
		if not Client then
			return false
		end

		Internal.MyGun = Internal:FetchGun()
		Internal.FPS = 60
		Internal.Frames = 0

		Internal.MapSpawned = workspace:FindFirstChild("Map")
			and workspace.Map:FindFirstChild("Clips")
			and workspace.Map:FindFirstChild("SpawnPoints")
		Internal.IgnoreList = Internal.MapSpawned
				and {
					workspace.Debris,
					workspace.Ray_Ignore,
					Camera,
					workspace.Map.Clips,
					workspace.Map.SpawnPoints,
					LocalPlayer.Character,
				}
			or {}

		Internal.InGame = not workspace.Status.Preparation.Value
		Internal.Warmup = ReplicatedStorage.Warmup.Value
		Internal.LastFPSCheck = 0
		_FireTrampoline = hookfunction(Client.firebullet, _FireBullet)
		_GetPatTrampoline = hookfunction(Client.getpat, _GetPat)
		_LoadAmmoTrampoline = hookfunction(Client.loadammo, _LoadAmmo)
	end

	function Internal:Tick()
		Internal.Frames += 1

		if not self.MyGun or self.MyGun._Gun ~= Client.gun then
			Internal.MyGun = Internal:FetchGun()
		end

		Internal.GameMode = ReplicatedStorage.gametype.Value
		Internal.InGame = not workspace.Status.Preparation.Value
		Internal.Warmup = ReplicatedStorage.Warmup.Value
		Internal.MapSpawned = workspace:FindFirstChild("Map")
				and workspace.Map:FindFirstChild("Clips")
				and workspace.Map:FindFirstChild("SpawnPoints")
			or false

		Internal.IgnoreList = Internal.MapSpawned
				and {
					workspace.Debris,
					workspace.Ray_Ignore,
					Camera,
					workspace.Map.Clips,
					workspace.Map.SpawnPoints,
					LocalPlayer.Character,
				}
			or {}

		if (os.clock() - Internal.LastFPSCheck) >= 1 then
			Internal.FPS = Internal.Frames
			Internal.Frames = 0
			Internal.LastFPSCheck = os.clock()
		end

		if Hooked then
			return
		end

		Hooked = true

		Internal.OldNameCall = hookmetamethod(
			game,
			"__namecall",
			LPH_NO_VIRTUALIZE(function(self, ...)
				local Method = getnamecallmethod()
				local ExploitCalling = checkcaller()

				local Args = { ... }

				if Method == "FireServer" then
					if self.Name == "HitPart" then
						local EntityModule = Modules["Players"]

						local TargetPart
						if EntityModule and EntityModule:HitBacktrack(Args[1]) then
							TargetPart = EntityModule:GetRealPart(Args[1])
						end

						if TargetPart then
							Args[1] = TargetPart
							Args[2] = Internal:Encode(TargetPart.Position)
						end

						if Lib.Flags["RagebotResolver"] then
							Args[2] = Vector3.new() / 0 / 0
						end

						task.spawn(function()
							local Hit = Args[1]
							if Hit and _Rig[Hit.Name] ~= nil then
								Internal:LogHit(Args[3], Hit, Args[7], Modules.Ragebot and Modules.Ragebot.HitChance)
							end
						end)

						-- l_v480_0
						-- v499
						-- l_gun_1.Name
						-- v405
						-- v206:WaitForChild("Gun")
						-- nil,
						-- damagemodifier
						-- v405 == 48
						-- v495
						-- l_CurrentCamera_1.CFrame.p
						-- game.Workspace.DistributedTime.Value
						-- l_v482_0
						--  true
						-- nil
						-- nil
						-- nil
						-- nil
						-- nil,
						-- nil
						-- nil
						-- nil
						-- nil
						-- nil
						-- nil
						-- nil
						-- nil

						return Internal.OldNameCall(
							self,
							Args[1],
							Args[2],
							Args[3],
							Args[4],
							Args[5],
							nil,
							Args[7],
							Args[8],
							Args[9],
							Args[10],
							Args[11],
							Args[12],
							true,
							nil,
							nil,
							nil,
							nil,
							nil,
							nil,
							nil,
							nil,
							nil,
							nil,
							nil,
							nil,
							nil
						)
					elseif
						Method == "FindPartOnRayWithIgnoreList"
						and tostring(getcallingscript()) == "Client"
						and Args[1].Origin == Camera.CFrame.Position
					then
						local SilentAim = Modules["SilentAim"]
						if
							SilentAim
							and Lib.Flags["SilentAimMode"] == "pSilent"
							and SilentAim.Target.Angle ~= nil
							and (math.random() * 100) <= Lib.Flags["SilentAimHitChance"]
						then
							Args[1] = Ray.new(Args[1].Origin, SilentAim.Target.Angle)
						end

						Internal.Origin = Args[1].Origin

						return Internal.OldNameCall(self, unpack(Args))
					elseif self.Name == "ApplyGun" then
						local GunName = Args[1]
						if GunName == "Banana" or GunName == "Crowbar" then
							Args[1] = "Karambit"
						end

						return Internal.OldNameCall(self, Args[1], Args[2], nil, nil, nil, nil, nil, nil, nil, nil, nil)
					end
				elseif Method == "SetAttribute" then
					if self == LocalPlayer.Character and Args[1] == "Speed" then
						if Lib.Flags["NoSlowDown"] and Args[2] == Client.curspd then
							Args[2] = 250
						end

						if Lib.Flags["SpeedHack"] then
							Args[2] = Lib.Flags["SpeedHackSpeed"] * 10
						end

						return Internal.OldNameCall(self, unpack(Args))
					end
				end
				return Internal.OldNameCall(self, ...)
			end)
		)
	end

	CreateModule("Internal", Internal)
end

local lastUpdate = 0
local updateInterval = 1 / 60

RunService.RenderStepped:Connect(LPH_NO_VIRTUALIZE(function(dt)
	local now = os.clock()

	for i, v in next, Modules do
		if typeof(v) == "table" and v.Tick and v.__Loaded == true then
			if v.Name == "Visuals" or v.Name == "Players" or v.Name == "Ragebot" or v.Name == "Movement" then
				v:Tick(dt)
			else
				if now - lastUpdate >= updateInterval then
					v:Tick(dt)
				end
			end
		end
	end

	if now - lastUpdate >= updateInterval then
		lastUpdate = now
	end
end))

local EntityModule = {}
do
	EntityModule.Players = {}
	EntityModule.Characters = {}
	EntityModule.EntityFolder = Instance.new("Model", ReplicatedStorage)
	EntityModule.BacktrackData = {}

	function EntityModule:IsEnemy(Entry)
		return Internal.GameMode == "deathmatch" and true
			or Entry.Team and LocalPlayer.Team and LocalPlayer.Team ~= Entry.Team
			or false
	end

	function EntityModule:HitBacktrack(Part)
		return Part.Parent == EntityModule.EntityFolder
	end

	function EntityModule:GetRealPart(Part)
		for _, PlayerData in next, EntityModule.BacktrackData do
			for i, backtrack in next, PlayerData do
				if Part == backtrack.Ghost then
					return backtrack.Real
				end
			end
		end
	end

	function EntityModule:Add(Player)
		if Player == nil then
			return
		end

		local Entry = {}

		Entry.Plr = Player
		Entry.Alive = false
		Entry.Name = Player.Name
		Entry.Team = Player.Team
		Entry.Enemy = EntityModule:IsEnemy(Entry)

		Entry.Rig = {}
		Entry.Drawings = {}

		Entry.Health = 0
		Entry.MaxHealth = 0
		Entry.Humanoid = nil
		Entry.Char = nil
		Entry.Armor = 0
		Entry.HasArmor = false
		Entry.LastStep = 0
		Entry.Backtrack = {}
		Entry.Samples = {}

		Entry.Step = LPH_JIT_MAX(function()
			local Character = Player.Character
			if Character then
				if Player ~= LocalPlayer and not EntityModule.BacktrackData[Player] and next(Entry.Rig) then
					local BTData = {}
					local Samples = {}
					local BacktrackData = {}

					for i, v in next, Entry.Rig do
						if
							type(_Rig[i]) == "number"
							and i ~= "HumanoidRootPart"
							and i ~= "Head"
							and i ~= "FakeHead"
							and not BTData[i]
						then
							print("Created part")
							local GhostPart = v.Part:Clone()
							GhostPart:ClearAllChildren()
							GhostPart.Anchored = true
							GhostPart.CanCollide = false
							GhostPart.Transparency = 0.5
							GhostPart.Material = Enum.Material.ForceField
							GhostPart.Name = v.Part.Name
							GhostPart.Parent = EntityModule.EntityFolder

							BacktrackData[i] = GhostPart
							BTData[i] = {
								Ghost = GhostPart,
								Real = v.Part,
							}
							Samples[i] = {}
						end
					end

					EntityModule.BacktrackData[Player] = BTData
					Entry.Backtrack = BacktrackData
					Entry.Samples = Samples

					print("Backtrack created for player")
				end

				if Lib.Flags["HistorySettings"] ~= "None" then
					local DELAY_TIME = Lib.Flags["HistorySettings"] == "Maximum" and 4
						or Lib.Flags["HistorySettings"] == "Minimum" and 0.3
						or Lib.Flags["HistorySettings"] == "Extended" and 2
						or 1
					for key, ghost in pairs(Entry.Backtrack) do
						if not Entry.Enemy or Player == LocalPlayer or not Entry.Alive then
							ghost.Transparency = 1
							continue
						end

						local History = Entry.Samples[key]
						local originalPart = Entry.Rig[key] and Entry.Rig[key].Part

						if History and originalPart then
							ghost.Color = Lib.Flags["HistoryColor"] or ghost.Color
							ghost.Anchored = true
							ghost.Transparency = Lib.Options["HistoryColor"].trans

							-- add snapshot
							table.insert(History, {
								CFrame = originalPart.CFrame,
								Time = tick(),
							})

							if not originalPart.Parent then
								ghost:Destroy()
								Entry.Backtrack[key] = nil
								Entry.Samples[key] = nil
								continue
							end

							while History[1] and (tick() - History[1].Time) >= DELAY_TIME do
								ghost.CFrame = History[1].CFrame
								table.remove(History, 1)
							end
						end
					end
				end

				local Humanoid = Character:FindFirstChild("Humanoid")
				Entry.Char = Character
				EntityModule.Characters[Player] = Entry.Char

				local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
				if Humanoid and HumanoidRootPart then
					Entry.Humanoid = Humanoid
					--Entry.Rig = Utility:Capture(Character);
					Entry.Health = Humanoid.Health
					Entry.MaxHealth = Humanoid.MaxHealth
					Entry.Alive = Entry.Health > 0
						and Entry.Health <= Entry.MaxHealth
						and not Character:FindFirstChildWhichIsA("ForceField")

					local Kevlar = Player:FindFirstChild("Kevlar")
					if Kevlar then
						Entry.HasArmor = Kevlar.Value > 0
						Entry.Armor = Kevlar.Value
					else
						Entry.HasArmor = false
						Entry.Armor = 0
					end
				elseif Entry.Alive or next(Entry.Rig) ~= nil then
					Entry.Alive = false
					Entry.Rig = {}
					Entry.Humanoid = nil
					Entry.Char = nil
					EntityModule.Characters[Player] = nil

					EntityModule.BacktrackData[Player] = nil
					for i, v in next, Entry.Backtrack do
						v:Destroy()
						Entry.Backtrack[i] = nil
						Entry.Samples[i] = nil
					end

					Entry.Samples = {}
					Entry.Backtrack = {}
				end
			else
				Entry.Char = nil
				Entry.Alive = false
				EntityModule.Characters[Player] = nil
				EntityModule.BacktrackData[Player] = nil
				if next(Entry.Backtrack) ~= nil then
					for i, v in next, Entry.Backtrack do
						v:Destroy()
						Entry.Backtrack[i] = nil
						Entry.Samples[i] = nil
					end
				end
				Entry.Samples = {}
				Entry.Backtrack = {}
			end

			Entry.LastStep = os.clock()
		end)

		Entry.TeamConnection = Player:GetPropertyChangedSignal("Team"):Connect(function()
			if Player.Team == nil or LocalPlayer.Team == nil then
				repeat
					task.wait()
				until Player.Team and LocalPlayer.Team
			end

			Entry.Team = Player.Team

			if Player == LocalPlayer then
				for i, v in next, EntityModule.Players do
					EntityModule.Players[i].Enemy = EntityModule:IsEnemy(v)
				end
			end

			Entry.Enemy = EntityModule:IsEnemy(Entry)
			EntityModule.Players[Player] = Entry
		end)
		EntityModule.Players[Player] = Entry
		if Player == LocalPlayer then
			EntityModule.LocalPlayer = EntityModule.Players[Player]
		end
	end

	function EntityModule:Remove(Player)
		local Entry = EntityModule.Players[Player]
		if not Entry then
			return
		end
		if Entry.TeamConnection then
			Entry.TeamConnection:Disconnect()
		end
		for i, v in next, Entry.Drawings do
			if typeof(v) ~= "table" then
				v:Remove()
			end
		end
		for i, v in next, Entry.Drawings.Skeleton do
			if typeof(v) ~= "table" then
				v:Remove()
			end
		end

		EntityModule.Characters[Player] = nil
		EntityModule.BacktrackData[Player] = nil

		if next(Entry.Backtrack) ~= nil then
			for i, v in next, Entry.Backtrack do
				v:Destroy()
				Entry.Backtrack[i] = nil
				Entry.Samples[i] = nil
			end
		end

		Entry.Samples = {}
		Entry.Backtrack = {}

		EntityModule.Players[Player] = nil
	end

	Players.PlayerAdded:Connect(function(Player)
		return EntityModule:Add(Player)
	end)

	Players.PlayerRemoving:Connect(function(Player)
		return EntityModule:Remove(Player)
	end)

	function EntityModule:Init()
		for i, Player in next, Players:GetPlayers() do
			EntityModule:Add(Player)
		end
	end

	function EntityModule:Tick()
		for i, Player in next, EntityModule.Players do
			if Player.Alive then
				EntityModule.Players[i].Rig = Utility:Capture(Player.Char)
			end

			if (os.clock() - Player.LastStep) >= updateInterval then
				Player:Step()
			end
		end

		for i, v in next, Players:GetPlayers() do
			if not EntityModule.Players[v] then
				EntityModule:Add(v)
			end
		end
	end

	CreateModule("Players", EntityModule)
end

local Combat = {}
do
	function Combat:GetTarget(Origin, Maximum)
		if not Origin then
			return
		end

		local LowestDistance = math.huge
		local BestPlayer = nil

		for i, Player in next, EntityModule.Players do
			if not Player.Enemy or not Player.Alive then
				continue
			end

			local Root = Player.Rig["HumanoidRootPart"]
			if not Root or not Root.OnScreen then
				continue
			end

			local Distance = (Origin - Root._2d).Magnitude
			if Distance > Maximum then
				continue
			end

			if Distance < LowestDistance then
				LowestDistance = Distance
				BestPlayer = Player
			end
		end

		return BestPlayer
	end

	function Combat:GetOrigin(OriginName)
		local Middle = Camera.ViewportSize / 2
		local Mouse = UserInputService:GetMouseLocation()
		local Returned = nil

		if OriginName == "Center" then
			Returned = Middle
		elseif OriginName == "Mouse" then
			Returned = Vector2.new(Mouse.X, Mouse.Y)
		end

		return Returned
	end

	function Combat:GetFinal(BoneList, Entry, Origin, VisCheck)
		local FinalBone = nil
		local ClosestDistance = math.huge
		for key, Bone in next, BoneList do
			local RigPart = Entry.Rig[Bone]
			if not RigPart then
				continue
			end

			if VisCheck and not Utility:Visible(RigPart) then
				continue
			end

			local Distance = (Origin - RigPart._2d).Magnitude
			if Distance < ClosestDistance then
				ClosestDistance = Distance
				FinalBone = RigPart
			end
		end

		return FinalBone, ClosestDistance
	end

	CreateModule("Combat", Combat)
end

local World = {}
do
	World.Lighting = {
		Outdoor = Lighting.OutdoorAmbient,
		Normal = Lighting.Ambient,
		Time = Lighting.ClockTime,
	}

	World.Camera = {
		Min = LocalPlayer.CameraMinZoomDistance,
		Max = LocalPlayer.CameraMaxZoomDistance,
		FOV = Camera.FieldOfView,
	}

	function World:Init()
		local oldNewIndex
		oldNewIndex = hookmetamethod(
			game,
			"__newindex",
			LPH_NO_VIRTUALIZE(function(self, key, value)
				local ExploitCalled = checkcaller()

				if not ExploitCalled then
					if self == Lighting then
						if key == "Ambient" then
							World.Lighting.Normal = value
						elseif key == "OutdoorAmbient" then
							World.Lighting.Outdoor = value
						elseif key == "ClockTime" then
							World.Lighting.Time = value
						end
					elseif self == LocalPlayer then
						-- LocalPlayer.CameraMinZoomDistance
						if key == "CameraMinZoomDistance" then
							World.Camera.Min = value
						elseif key == "CameraMaxZoomDistance" then
							World.Camera.Max = value
						end
					elseif self == Camera then
						if key == "FieldOfView" then
							World.Camera.FOV = value
							if Lib.Flags["FOVSlider"] and Lib.Flags["WorldEnabled"] then
								return
							end
						end
					end
				end
				return oldNewIndex(self, key, value)
			end)
		)

		local oldIndex
		oldIndex = hookmetamethod(
			game,
			"__index",
			LPH_NO_VIRTUALIZE(function(self, key)
				local ExploitCalled = checkcaller()
				if not ExploitCalled then
					if self == Lighting then
						if key == "Ambient" then
							return World.Lighting.Normal
						elseif key == "OutdoorAmbient" then
							return World.Lighting.Outdoor
						elseif key == "ClockTime" then
							return World.Lighting.Time
						end
					elseif self == Camera then
						if key == "FieldOfView" then
							return World.Camera.FOV
						end
					elseif key == "Value" then
						-- if self.Name == "Spread" and Lib.Flags["RemoveSpread"] then
						-- 	return 0
						-- end
						if Lib.Flags["RemoveSpread"] then
							if self.Name == "Spread" then
								return 0
							elseif self.Name == "Stand" then
								return 0
							elseif self.Name == "Crouch" then
								return 0
							end
						end
						if self.Name == "Recoil" and Lib.Flags["RemoveRecoil"] then
							return 0
						end
					elseif key == "Transparency" and _Rig[self.Name] ~= nil then
						return 0
					end
				end

				return oldIndex(self, key)
			end)
		)
	end

	function World:Tick()
		-- Ambience
		if Lib.Flags["AmbientChanger"] and Lib.Flags["WorldEnabled"] then
			local TargetColor = Lib.Flags["AmbientChangerColor"]
			if Lighting.OutdoorAmbient ~= TargetColor then
				Lighting.OutdoorAmbient = TargetColor
			end
			if Lighting.Ambient ~= TargetColor then
				Lighting.Ambient = TargetColor
			end
		else
			if Lighting.Ambient ~= World.Lighting.Normal then
				Lighting.Ambient = World.Lighting.Normal
			end
			if Lighting.OutdoorAmbient ~= World.Lighting.Outdoor then
				Lighting.OutdoorAmbient = World.Lighting.Outdoor
			end
		end

		if Lib.Flags["TimeChanger"] and Lib.Flags["WorldEnabled"] then
			if Lighting.ClockTime ~= Lib.Flags["SpecifiedTime"] then
				Lighting.ClockTime = Lib.Flags["SpecifiedTime"]
			end
		else
			if Lighting.ClockTime ~= World.Lighting.Time then
				Lighting.ClockTime = World.Lighting.Time
			end
		end

		if Lib.Flags["ThirdPerson"] and Lib.Flags["WorldEnabled"] then
			local TargetDistance = Lib.Flags["ThirdPersonDistance"]
			if LocalPlayer.CameraMinZoomDistance ~= TargetDistance then
				LocalPlayer.CameraMinZoomDistance = TargetDistance
			end

			if LocalPlayer.CameraMaxZoomDistance ~= TargetDistance then
				LocalPlayer.CameraMaxZoomDistance = TargetDistance
			end
		elseif EntityModule.LocalPlayer.Alive then
			if LocalPlayer.CameraMaxZoomDistance ~= World.Camera.Max then
				LocalPlayer.CameraMaxZoomDistance = World.Camera.Max
			end

			if LocalPlayer.CameraMinZoomDistance ~= World.Camera.Min then
				LocalPlayer.CameraMinZoomDistance = World.Camera.Min
			end
		end

		if Lib.Flags["FOVSlider"] then
			if World.Camera.FOV < 70 and not Lib.Flags["OverrideZoom"] then
				Camera.FieldOfView = World.Camera.FOV
			elseif Camera.FieldOfView ~= Lib.Flags["FOVAmount"] then
				Camera.FieldOfView = Lib.Flags["FOVAmount"]
			end
		else
			if Camera.FieldOfView ~= World.Camera.FOV then
				Camera.FieldOfView = World.Camera.FOV
			end
		end
	end

	CreateModule("World", World)
end

local CameraController = {}
do
	function CameraController:Init()
		CameraController.Arms = {}
		CameraController.ArmsVisible = true
		CameraController.Gun = {}
	end

	function CameraController:FindPhysical(Arms)
		for i, v in next, Arms:GetChildren() do
			if v.Name:find("Arms") then
				return v
			end
		end
		return nil
	end

	function CameraController:GetArm()
		local ArmData = {}

		local Arms = Camera:FindFirstChild("Arms")
		if not Arms then
			return false
		end
		local PhsyicalArms = Arms:FindFirstChild("IDFArms") or Arms:FindFirstChild("ECArms") or self:FindPhysical(Arms)
		if not PhsyicalArms then
			return false
		end

		for i, Part in next, PhsyicalArms:GetDescendants() do
			if Part.ClassName ~= "Part" and Part.ClassName ~= "MeshPart" and Part.ClassName ~= "SpecialMesh" then
				continue
			end
			ArmData[Part.Name] = Part
		end

		return ArmData
	end

	function CameraController:GetGun()
		local GunData = {}

		local Arms = Camera:FindFirstChild("Arms")
		if not Arms then
			return false
		end

		for i, Part in next, Arms:GetChildren() do
			if Part.ClassName ~= "Part" and Part.ClassName ~= "MeshPart" and Part.ClassName ~= "SpecialMesh" then
				continue
			end
			GunData[Part.Name] = Part
		end

		return GunData
	end

	function CameraController:HideArm()
		CameraController.ArmsVisible = false
		if not self.Arms then
			return
		end

		for i, Asset in next, self.Arms do
			if Asset.ClassName == "SpecialMesh" then
				Asset.TextureId = ""
				continue
			end
			if Asset.ClassName ~= "Part" and Asset.ClassName ~= "MeshPart" then
				continue
			end

			if Asset and Asset.Transparency ~= 1 then
				Asset.Transparency = 1
			end
		end

		for i, Asset in next, self.Gun do
			if Asset.ClassName == "SpecialMesh" then
				Asset.TextureId = ""
				continue
			end
			if Asset.ClassName ~= "Part" and Asset.ClassName ~= "MeshPart" then
				continue
			end

			if Asset and Asset.Transparency ~= 1 then
				Asset.Transparency = 1
			end
		end
	end
	CameraController.ArmsModified = false

	function CameraController:Tick()
		CameraController.Arms = self:GetArm() or {}
		CameraController.Gun = self:GetGun() or {}

		if Lib.Flags["ThirdPerson"] and Lib.Flags["WorldEnabled"] then
			self:HideArm()
		elseif not CameraController.ArmsVisible then
			CameraController.ArmsVisible = true
			Internal.Client.usethatgun()
		end

		-- CameraController:UpdateViewModel()
	end
	CreateModule("CameraController", CameraController)
end

local Legitbot = {}
do
	-- Legitbot.Target

	Legitbot.Drawings = {}

	function Legitbot:Init()
		Legitbot.RenderCircle = Lib.Flags["LegitbotFOVRendered"]
		Legitbot.Size = Lib.Flags["LegitBotFOV"]
		Legitbot.Origin = Camera.ViewportSize / 2
		Legitbot.Target = {}
		Legitbot.LastYield = 0
	end

	function Legitbot:Tick(dt)
		self.Origin = Combat:GetOrigin(Lib.Flags["LegitbotOrigin"])

		local Line = Legitbot.Drawings.Line
		local TargetEntry = Combat:GetTarget(self.Origin, self.Size)

		local SwitchDelay = Lib.Flags["LegitSwitchDelay"] / 1000
		if
			self.Target.Entry
			and self.Target.Time
			and SwitchDelay > 0
			and self.Target.Entry ~= TargetEntry
			and (os.clock() - self.Target.Time) < SwitchDelay
		then
			if Line then
				Line.Visible = false
			end
			return
		end

		if
			Lib.Flags["LegitbotReactionTime"] > 0
			and not self.Target.Start
			and (os.clock() - Legitbot.LastYield) < Lib.Flags["LegitbotReactionTime"] / 1000
		then
			Line.Visible = false
			return
		end

		Legitbot.LastYield = os.clock()

		if self.Target.Entry ~= TargetEntry then
			self.Target.Progress = 0
		end
		self.Target.Entry = TargetEntry
		self.Target.Point = (self.Target and self.Target.Point ~= Vector2.zero) and self.Target.Point or Vector2.zero

		if not self.Target.Entry or not Lib.Flags["Legitbot"] or not Line or not Internal.MyGun then
			if Line then
				Line.Visible = false
			end
			return
		end

		if self.Target.Point ~= Vector2.zero and Lib.Flags["LegitbotLine"] then
			Line.To = self.Target.Point
			Line.Visible = true
		else
			Line.Visible = false
		end

		local Mode = Lib.Flags["LegitbotMode"]
		if
			(Mode == "Normal" and not Internal:IsShooting())
			or (Mode == "Spray" and (not Internal:IsSpraying(Lib.Flags["SprayThreshold"]) or not Internal:IsShooting()))
		then
			return
		end

		local BoneList = Lib.Flags["LegitBotBone"]
		local FinalBone, ClosestDistance =
			Combat:GetFinal(BoneList, self.Target.Entry, self.Origin, Lib.Flags["LegitbotVisCheck"])

		if FinalBone then
			local SmoothingPercent = math.clamp(Lib.Flags["LegitbotSmoothing"], 0, 99)
			local SmoothFactor = math.clamp(1 - (SmoothingPercent / 100), 0, 1)
			local DistanceScale = math.clamp(ClosestDistance / 100, 0, 1)
			local DistanceFactor = DistanceScale ^ 0.5
			local FinalLerp = SmoothFactor * DistanceFactor
			FinalLerp = math.clamp(FinalLerp, 0, 1)

			local step = math.clamp(FinalLerp * dt * Internal.FPS, 0, 1)
			Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position, FinalBone.Part.Position), step)

			if not self.Target.Start then
				self.Target.Start = os.clock()
			end

			Line.To = FinalBone._2d
			Line.Visible = Lib.Flags["LegitbotLine"]
		end
	end

	CreateModule("Legitbot", Legitbot)
end

local SilentAim = {}
do
	SilentAim.Drawings = {}

	function SilentAim:Init()
		SilentAim.RenderCircle = true
		SilentAim.Size = 40
		SilentAim.Origin = Camera.ViewportSize / 2
		SilentAim.pSilent = true
		SilentAim.Target = {}
		SilentAim.LastYield = 0
	end

	function SilentAim:Tick()
		self.Origin = Combat:GetOrigin(Lib.Flags["SilentAimOrigin"])

		local Line = self.Drawings.Line
		local TargetEntry = Combat:GetTarget(self.Origin, self.Size)

		local SwitchDelay = Lib.Flags["SilentSwitchDelay"] / 1000
		if
			self.Target.Entry
			and self.Target.Time
			and SwitchDelay > 0
			and self.Target.Entry ~= TargetEntry
			and (os.clock() - self.Target.Time) < SwitchDelay
		then
			if Line then
				Line.Visible = false
			end
			return
		end

		if
			Lib.Flags["SilentReactionTime"] > 0
			and not self.Target.Start
			and (os.clock() - SilentAim.LastYield) < Lib.Flags["SilentReactionTime"] / 1000
		then
			Line.Visible = false
			return
		end

		SilentAim.LastYield = os.clock()

		self.Target = {}
		self.Target.Entry = TargetEntry
		self.Target.Point = (self.Target and self.Target.Point) or Vector2.zero

		if not self.Target.Entry or not Lib.Flags["SilentAim"] or not Line or not Internal.MyGun then
			if Line then
				Line.Visible = false
			end
			self.Target.Point = Vector2.zero
			return
		end

		if self.Target.Point ~= Vector2.zero and Lib.Flags["SilentAimLine"] then
			Line.To = self.Target.Point
			Line.Visible = true
		else
			Line.Visible = false
		end

		local BoneList = Lib.Flags["SilentAimBone"]
		local FinalBone, ClosestDistance =
			Combat:GetFinal(BoneList, self.Target.Entry, self.Origin, Lib.Flags["SilentAimVisCheck"])

		if FinalBone then
			self.Target.Angle = (FinalBone.Part.Position - Camera.CFrame.p)
			self.Target.AimBone = FinalBone
			self.Target.Point = FinalBone._2d
			self.Target.Time = os.clock()

			if not self.Target.Start then
				self.Target.Start = os.clock()
			end

			Line.To = FinalBone._2d
			Line.Visible = Lib.Flags["SilentAimLine"]
		end
	end

	CreateModule("SilentAim", SilentAim)
end

local Visuals = {}
do
	Visuals.Color = Color3.fromRGB(0, 165, 255)
	Visuals.Rendered = {}

	Visuals.RenderBox = true
	Visuals.RenderHealthBar = true
	Visuals.RenderFilled = true
	Visuals.RenderArmorbar = true

	Visuals.HighlightModel = Instance.new("Model", workspace)
	Visuals.HighlightModel.Name = HttpService:GenerateGUID(false):gsub("-", "")

	Visuals.Highlight = Instance.new("Highlight", Visuals.HighlightModel)
	Visuals.Highlight.Enabled = false

	Visuals.OutlineSize = 2

	local Positions = {
		["Top"] = 1,
		["Bottom"] = 2,
		["Left"] = 3,
		["Right"] = 4,
	}

	Visuals.HealthbarPosition = Positions["Left"]
	Visuals.ArmorbarPosition = Positions["Right"]
	Visuals.ShowTeam = true
	Visuals.Chammed = {}

	function Visuals:CreateChamEntry(Entry)
		local Rig = Entry.Rig
		local PlayerFolder = Instance.new("Folder", Visuals.ChamFolder)
		PlayerFolder.Name = Entry.Name
		for i, v in next, Rig do
			if typeof(v) ~= "table" then
				continue
			end

			local PartEntry = _Rig[i]
			if PartEntry and type(PartEntry) == "number" then
				local part = PartEntry.Part
				local adornment = Instance.new("BoxHandleAdornment", PlayerFolder)
				adornment.Name = i
				adornment.Adornee = part
				adornment.AlwaysOnTop = true
				adornment.ZIndex = 10
				adornment.Parent = part
			end
		end
	end

	function Visuals:Cham(Entry)
		local FolderEntry = Visuals.ChamFolder:FindFirstChild(Entry.Name)
		if not FolderEntry then
			Visuals:CreateChamEntry(Entry)
		end
	end

	function Visuals:Layout()
		return {
			BoxOutline = Utility:Render("Square", {
				Filled = false,
				Thickness = 1,
			}),
			HealthbarOutline = Utility:Render("Square", {
				Filled = true,
				Thickness = 1,
			}),
			ArmorbarOutline = Utility:Render("Square", {
				Filled = true,
				Thickness = 1,
			}),
			BoxFilled = Utility:Render("Square", {
				Filled = true,
				Thickness = 1,
			}),
			Box = Utility:Render("Square", {
				Filled = false,
				Thickness = 1,
			}),
			Armorbar = Utility:Render("Square", {
				Filled = true,
				Thickness = 1,
			}),
			Healthbar = Utility:Render("Square", {
				Filled = false,
				Thickness = 1,
			}),
			Name = Utility:Render("Text", {
				Text = "wat",
				Font = 2,
			}),
		}
	end

	Visuals.SkeletonLayout = {
		{ "Head", "UpperTorso" },

		-- shoulders
		{ "Neck", "LeftShoulder" },
		{ "Neck", "RightShoulder" },
		{ "RightShoulder", "LeftUpperArm" },
		{ "LeftShoulder", "RightUpperArm" },

		-- right arm
		{ "RightUpperArm", "RightLowerArm" },
		{ "RightLowerArm", "RightHand" },

		-- left arm
		{ "LeftUpperArm", "LeftLowerArm" },
		{ "LeftLowerArm", "LeftHand" },

		-- connect lower torso
		{ "UpperTorso", "LowerTorso" },

		-- lower torso -> legs
		{ "LowerTorso", "LeftUpperLeg" },
		{ "LowerTorso", "RightUpperLeg" },

		-- left leg
		{ "LeftUpperLeg", "LeftLowerLeg" },
		{ "LeftLowerLeg", "LeftFoot" },

		-- right leg
		{ "RightUpperLeg", "RightLowerLeg" },
		{ "RightLowerLeg", "RightFoot" },
	}

	function Visuals:CircleTick()
		local SilentAimSize = Lib.Flags["DynamicSilentFOV"]
				and math.max((Lib.Flags["SilentAimFOV"] * (Camera.FieldOfView / 70)), Lib.Flags["SilentAimFOV"])
			or Lib.Flags["SilentAimFOV"]

		local LegitbotSize = Lib.Flags["DynamicLegitFOV"]
				and math.max((Lib.Flags["LegitBotFOV"] * (Camera.FieldOfView / 70)), Lib.Flags["LegitBotFOV"])
			or Lib.Flags["LegitBotFOV"]

		SilentAim.Drawings.Circle.Radius = SilentAimSize
		Legitbot.Drawings.Circle.Radius = LegitbotSize

		Legitbot.Drawings.Circle.Visible = Lib.Flags["RenderLegitBot"]
		SilentAim.Drawings.Circle.Visible = Lib.Flags["RenderSilentAim"]

		Legitbot.Drawings.Circle.Color = Lib.Flags["LegitBotFOVColor"]
		SilentAim.Drawings.Circle.Color = Lib.Flags["SilentAimFOVColor"]

		Legitbot.Drawings.Circle.Transparency = 1 - Lib.Options["LegitBotFOVColor"].trans
		SilentAim.Drawings.Circle.Transparency = 1 - Lib.Options["SilentAimFOVColor"].trans

		Legitbot.Size = LegitbotSize
		SilentAim.Size = SilentAimSize

		Legitbot.Drawings.Line.Color = Lib.Flags["LegitBotLineColor"]
		SilentAim.Drawings.Line.Color = Lib.Flags["SilentAimLineColor"]

		Legitbot.Drawings.Line.Transparency = 1 - Lib.Options["LegitBotLineColor"].trans
		SilentAim.Drawings.Line.Transparency = 1 - Lib.Options["SilentAimLineColor"].trans

		SilentAim.Drawings.Circle.Position = SilentAim.Origin
		Legitbot.Drawings.Circle.Position = Legitbot.Origin
	end

	function Visuals:RenderPlayer(Player)
		local Entry = EntityModule.Players[Player]
		if not Entry then
			return false
		end

		EntityModule.Players[Player].Drawings = Visuals:Layout()
		local Skeleton = {}
		for i, v in next, self.SkeletonLayout do
			Skeleton[i .. "Outline"] = Utility:Render("Line")
			Skeleton[i] = Utility:Render("Line")
		end
		EntityModule.Players[Player].Drawings.Skeleton = Skeleton

		return true
	end

	function Visuals:GetPadding(Padding, Position)
		local PaddingVec = Vector2.zero
		if Position == 1 then
			PaddingVec = Vector2.new(0, -Padding)
		elseif Position == 2 then
			PaddingVec = Vector2.new(0, Padding)
		elseif Position == 3 then
			PaddingVec = Vector2.new(-Padding, 0)
		elseif Position == 4 then
			PaddingVec = Vector2.new(Padding, 0)
		end
		return PaddingVec
	end

	function Visuals:Update(Entry, VisCheck)
		if not Entry.Alive then
			return
		end

		local Rig = Entry.Rig
		if not Rig then
			return
		end

		local RootPart = Rig["HumanoidRootPart"]
		local Humanoid = Rig["Humanoid"]
		local Head = Rig["Head"]

		if not RootPart or not Humanoid or not Head then
			return
		end

		if VisCheck and not Utility:Visible(RootPart.Part) then
			return
		end

		local TopOffset = Vector3.new(0, 0.80, 0)
		local BottomOffset = Vector3.new(0, -1.25, 0)

		local Top3D = Head.Part.Position + TopOffset
		local Bottom3D = RootPart.Part.Position - Vector3.new(0, Humanoid.HipHeight, 0) + BottomOffset

		local Top2D, TopOnScreen = Camera:WorldToViewportPoint(Top3D)
		local Bottom2D, BottomOnScreen = Camera:WorldToViewportPoint(Bottom3D)

		if not RootPart.OnScreen or not Head.OnScreen or not TopOnScreen or not BottomOnScreen then
			return
		end

		local Height = Bottom2D.Y - Top2D.Y
		local Width = Height * 0.50

		local CenterX = (Top2D.X + Bottom2D.X) / 2
		local CenterY = (Top2D.Y + Bottom2D.Y) / 2

		local HalfWidth = Width / 2
		local HalfHeight = Height / 2

		local TopLeft = Vector2.new(CenterX - HalfWidth, CenterY - HalfHeight)
		local TopRight = Vector2.new(CenterX + HalfWidth, CenterY - HalfHeight)
		local BottomLeft = Vector2.new(CenterX - HalfWidth, CenterY + HalfHeight)
		local BottomRight = Vector2.new(CenterX + HalfWidth, CenterY + HalfHeight)
		local TopMiddle = Vector2.new(CenterX, CenterY - HalfHeight)
		local BottomMiddle = Vector2.new(CenterX, CenterY + HalfHeight)

		return {
			TopLeft = TopLeft,
			TopRight = TopRight,
			BottomLeft = BottomLeft,
			BottomRight = BottomRight,
			TopMiddle = TopMiddle,
			BottomMiddle = BottomMiddle,
			Center = Vector2.new(CenterX, CenterY),
			Width = Width,
			Height = Height,
			Scale = math.clamp(1 / ((RootPart.Part.Position - Camera.CFrame.p).Magnitude / 20), 0.5, 1.5),
		}
	end

	function Visuals:DestroyDrawings(Player)
		local Entry = EntityModule.Players[Player]
		if Entry then
			for i, v in next, Entry.Drawings do
				if typeof(v) ~= "table" then
					v:Remove()
				end
			end

			if Entry.Drawings.Skeleton then
				for i, v in next, Entry.Drawings.Skeleton do
					v:Remove()
				end
			end
		end
	end

	function Visuals:Init()
		SilentAim.Drawings.Line = Utility:Render("Line", { Color = Color3.fromRGB(0, 255, 0) })
		SilentAim.Drawings.Circle = Utility:Render("Circle", { Color = Color3.fromRGB(0, 255, 0) })

		Legitbot.Drawings.Line = Utility:Render("Line", { Color = Color3.fromRGB(255, 0, 0) })
		Legitbot.Drawings.Circle = Utility:Render("Circle", { Color = Color3.fromRGB(255, 0, 0) })

		Players.PlayerRemoving:Connect(Visuals.DestroyDrawings)

		Visuals.ChamFolder = Instance.new("Folder", workspace)
		Visuals.ChamFolder.Name = HttpService:GenerateGUID(false):gsub("-", "")
	end

	function Visuals:Skeleton(Entry, Drawings)
		local Rig = Entry.Rig
		if not Rig.Head or not Rig.UpperTorso or not Rig.LowerTorso then
			return
		end

		local FakePoints = {}

		if Rig.Head._2d and Rig.UpperTorso._2d then
			FakePoints.Neck = {
				_2d = (Rig.Head._2d + Rig.UpperTorso._2d) / 2,
				OnScreen = Rig.Head.OnScreen and Rig.UpperTorso.OnScreen,
			}
		end

		if FakePoints.Neck then
			local Neck = FakePoints.Neck._2d

			local ShoulderOffsetX = 3.5
			local ShoulderOffsetY = 1.5
			local InwardOffsetX = 1.5

			FakePoints.LeftShoulder = {
				_2d = Neck + Vector2.new(-(ShoulderOffsetX - InwardOffsetX), ShoulderOffsetY),
				OnScreen = FakePoints.Neck.OnScreen,
			}
			FakePoints.RightShoulder = {
				_2d = Neck + Vector2.new(ShoulderOffsetX - InwardOffsetX, ShoulderOffsetY),
				OnScreen = FakePoints.Neck.OnScreen,
			}
		end

		for i, SkeletonLayout in next, self.SkeletonLayout do
			local Drawing = Drawings.Skeleton[i]
			local DrawingOutline = Drawings.Skeleton[i .. "Outline"]
			if Drawing and DrawingOutline then
				local FromPart = Rig[SkeletonLayout[1]] or FakePoints[SkeletonLayout[1]]
				local ToPart = Rig[SkeletonLayout[2]] or FakePoints[SkeletonLayout[2]]

				if not FromPart or not ToPart or not FromPart.OnScreen or not ToPart.OnScreen then
					Drawing.Visible = false
					continue
				end

				Drawing.From = FromPart._2d
				Drawing.To = ToPart._2d
				Drawing.Visible = Lib.Flags["SkeletonEnabled"]
				Drawing.Color = Lib.Flags["SkeletonColor"]
				Drawing.Transparency = 1 - Lib.Options["SkeletonColor"].trans

				DrawingOutline.From = Drawing.From
				DrawingOutline.Visible = Drawing.Visible and Lib.Flags["OutlineEnabled"]
				DrawingOutline.To = Drawing.To
				DrawingOutline.Thickness = Drawing.Thickness + (Visuals.OutlineSize / 4)
				DrawingOutline.Color = Color3.fromRGB(0, 0, 0)
			end
		end
	end

	function Visuals:HideDrawings(Drawings)
		for i, v in next, Drawings do
			if typeof(v) == "table" then
				Visuals:HideDrawings(v)
			else
				v.Visible = false
			end
		end
	end

	function Visuals:GetBarPos(BarPosition, Points, OutlineSize, Percent)
		local OutlinePos, OutSize, Position, Size = nil

		if BarPosition == 1 then
			OutlinePos = Points.TopLeft - Vector2.new(0, 2.5) - Vector2.new(OutlineSize / 2, OutlineSize / 2)
			OutSize = Vector2.new(Points.Width, 1) + Vector2.new(2, 2)

			Position = Points.TopLeft - Vector2.new(0, 2.5)
			Size = Vector2.new(Points.Width * Percent, 1)
		elseif BarPosition == 2 then
			OutlinePos = Points.BottomLeft + Vector2.new(0, 2.5) - Vector2.new(OutlineSize / 2, OutlineSize / 2)
			OutSize = Vector2.new(Points.Width, 1) + Vector2.new(2, 2)

			Position = Points.BottomLeft + Vector2.new(0, 2.5)
			Size = Vector2.new(Points.Width * Percent, 1)
		elseif BarPosition == 3 then
			OutlinePos = Points.TopLeft - Vector2.new(2.5, 0) - Vector2.new(OutlineSize / 2, OutlineSize / 2)
			OutSize = Vector2.new(1, Points.Height) + Vector2.new(2, 2)

			Position = Points.TopLeft - Vector2.new(2.5, 0) + Vector2.new(0, Points.Height * (1 - Percent)) -- * (1 - Percent)
			Size = Vector2.new(1, Points.Height * Percent)
		elseif BarPosition == 4 then
			OutlinePos = Points.TopRight + Vector2.new(2.5, 0) - Vector2.new(OutlineSize / 2, OutlineSize / 2)
			OutSize = Vector2.new(1, Points.Height) + Vector2.new(OutlineSize, OutlineSize)

			Position = Points.TopRight + Vector2.new(2.5, 0) + Vector2.new(0, Points.Height * (1 - Percent))
			Size = Vector2.new(1, Points.Height * Percent)
		end

		return OutlinePos, OutSize, Position, Size
	end

	function Visuals:Tick()
		Visuals:CircleTick()

		local HealthbarPosition = Positions[Lib.Flags["HealthbarPosition"]]
		local ArmorbarPosition = Positions[Lib.Flags["KevlarbarPosition"]]
		local ESPEnabled = Lib.Flags["ESPEnabled"]
		local RenderTeam = Lib.Flags["RenderTeam"]
		local BoxEnabled = Lib.Flags["BoxEnabled"]
		local OutlineEnabled = Lib.Flags["OutlineEnabled"]
		local BoxFilled = Lib.Flags["BoxFilled"]
		local HealthbarEnabled = Lib.Flags["HealthbarEnabled"]
		local KevlarbarEnabled = Lib.Flags["KevlarbarEnabled"]
		local SkeletonEnabled = Lib.Flags["SkeletonEnabled"]
		local ESPVisCheck = Lib.Flags["ESPVisCheck"]
		local ChamsEnabled = Lib.Flags["ChamsEnabled"]
		local NameEnabled = Lib.Flags["NameEnabled"]

		for i, Player in next, Players:GetPlayers() do
			local Entry = EntityModule.Players[Player]
			if not Entry or Player == LocalPlayer then
				continue
			end

			if next(Entry.Drawings) == nil then
				self:RenderPlayer(Player)
			end

			local Points = self:Update(Entry, ESPVisCheck)

			if not Points or (not RenderTeam and not Entry.Enemy) or not ESPEnabled then
				self:HideDrawings(Entry.Drawings)
				continue
			end

			local Padding = {
				Armor = ArmorbarPosition == HealthbarPosition and true or false,
			}

			local Drawings = Entry.Drawings

			if SkeletonEnabled then
				Visuals:Skeleton(Entry, Drawings)
			end

			--Visuals:Cham(Player)

			local Box = Drawings.Box
			local BoxOutline = Drawings.BoxOutline
			local BoxFill = Drawings.BoxFilled

			local Name = Drawings.Name

			local Healthbar = Drawings.Healthbar
			local HealthbarOutline = Drawings.HealthbarOutline

			local Armorbar = Drawings.Armorbar
			local ArmorbarOutline = Drawings.ArmorbarOutline

			local OutlineSize = Visuals.OutlineSize

			-- box outline
			BoxOutline.Visible = BoxEnabled and OutlineEnabled
			BoxOutline.Position = Box.Position - Vector2.new(OutlineSize / 2, OutlineSize / 2)
			BoxOutline.Size = Box.Size + Vector2.new(OutlineSize, OutlineSize)
			BoxOutline.Color = Color3.fromRGB(0, 0, 0)

			-- box
			Box.Position = Points.TopLeft
			Box.Color = Lib.Flags["BoxColor"]
			Box.Transparency = 1 - Lib.Options["BoxColor"].trans
			Box.Size = Vector2.new(Points.Width, Points.Height)
			Box.Visible = BoxEnabled

			-- box fill
			BoxFill.Color = Lib.Flags["BoxFillColor"]
			BoxFill.Transparency = 1 - Lib.Options["BoxFillColor"].trans
			BoxFill.Position = Points.TopLeft + Vector2.new(1, 1)
			BoxFill.Size = Vector2.new(Points.Width - 2, Points.Height - 2)
			BoxFill.Visible = BoxFilled and Box.Visible

			-- name
			Name.Color = Lib.Flags["NameColor"]
			Name.Transparency = 1 - Lib.Options["NameColor"].trans
			Name.Position = Points.TopMiddle - Vector2.new(Name.TextBounds.X / 2, Name.TextBounds.Y + 2)
			Name.Text = Player.Name
			Name.Size = math.clamp(Points.Height * 0.3, 8, 16)
			Name.Outline = OutlineEnabled
			Name.Visible = NameEnabled
			-- health bar
			local HealthPercent = math.clamp(Entry.Health / Entry.MaxHealth, 0, 1)
			local HealthOutlinePos, HealthOutSize, HealthPosition, HealthSize =
				Visuals:GetBarPos(HealthbarPosition, Points, OutlineSize, HealthPercent)

			Healthbar.Filled = true
			HealthbarOutline.Filled = true

			Healthbar.Color = Lib.Flags["HealthBarColor"]
			Healthbar.Transparency = 1 - Lib.Options["HealthBarColor"].trans
			HealthbarOutline.Color = Color3.fromRGB(0, 0, 0)

			HealthbarOutline.Visible = HealthbarEnabled and OutlineEnabled
			Healthbar.Visible = HealthbarEnabled

			if HealthPosition and HealthSize and HealthOutSize and HealthOutlinePos then
				Healthbar.Position = HealthPosition
				Healthbar.Size = HealthSize

				HealthbarOutline.Position = HealthOutlinePos
				HealthbarOutline.Size = HealthOutSize
			end

			-- armor / kevlar bar
			local ArmorPercent = math.clamp(Entry.Armor / 100, 0, 1)
			local ArmorOutlinePos, ArmorOutSize, ArmorPosition, ArmorSize =
				Visuals:GetBarPos(ArmorbarPosition, Points, OutlineSize, ArmorPercent)

			Armorbar.Filled = true
			ArmorbarOutline.Visible = true

			Armorbar.Color = Lib.Flags["KevlarbarColor"]
			Armorbar.Transparency = 1 - Lib.Options["KevlarbarColor"].trans
			ArmorbarOutline.Color = Color3.fromRGB(0, 0, 0)

			Armorbar.Visible = KevlarbarEnabled and Entry.HasArmor
			ArmorbarOutline.Visible = Armorbar.Visible and OutlineEnabled

			if ArmorOutlinePos and ArmorOutSize and ArmorPosition and ArmorSize then
				local PaddingNum = Visuals:GetPadding(4, ArmorbarPosition)
				local PaddingVec = (Padding.Armor and PaddingNum or Vector2.zero)

				Armorbar.Position = ArmorPosition + PaddingVec
				Armorbar.Size = ArmorSize

				ArmorbarOutline.Position = ArmorOutlinePos + PaddingVec
				ArmorbarOutline.Size = ArmorOutSize
			end
		end
	end

	CreateModule("Visuals", Visuals)
end

local Network = {}
do
	function Network:Init()
		Network.PlayerSettings = {}
		Network.LastAttempt = 0

		Players.PlayerRemoving:Connect(function(Plr)
			Network.PlayerSettings[Plr.Name] = nil
		end)
	end

	function Network:Tick()
		for Player, Settings in next, self.PlayerSettings do
			if Player == LocalPlayer then
				continue
			end

			local PlayerObject = Players:FindFirstChild(Player)
			if not PlayerObject then
				continue
			end

			local Entry = EntityModule.Players[PlayerObject]
			if not Entry then
				continue
			end

			if
				Settings.KillPlayer
				and Entry.Alive
				and Entry.Enemy
				and Internal.MyGun
				and Internal.InGame
				and ((os.clock() - self.LastAttempt) > 0.1)
			then
				self.LastAttempt = os.clock()
				Internal:Hit(Entry.Rig["Head"].Part, Entry.Rig["Head"].Part.Position, Internal.MyGun._Gun, true, 10)
			end
		end
	end

	CreateModule("Network", Network)
end

local SkinChanger = {}
do
	function SkinChanger:Init()
		SkinChanger.Skins = {}
		SkinChanger.Guns = {}
		SkinChanger.Knives = {}

		SkinChanger.SelectedSkins = {
			-- Gun = Skin
		}

		SkinChanger.KnivesVarianted = {
			-- Knife = Variant
		}

		SkinChanger.GlovesVarianted = {
			-- Glove = Variant
		}

		getgenv().GlovesVarianted = SkinChanger.GlovesVarianted
		getgenv().KnivesVarianted = SkinChanger.KnivesVarianted
		getgenv().SelectedSkins = SkinChanger.SelectedSkins

		if not SkinChanger:CacheGun() then
			return "failed to cache guns"
		end

		for i, Gun in next, SkinChanger.Guns do
			local Skins = SkinChanger:CacheSkins(Gun)
			if not Skins then
				return "failed to cache skins"
			end
			SkinChanger.Skins[Gun] = Skins
		end

		SkinChanger.Knives = SkinChanger:CacheKnives()

		local oldUseThatGun
		oldUseThatGun = hookfunc(Internal.Client.usethatgun, function(v254, v255, v256)
			if Lib.Flags["SkinChanger"] then
				local Client = Internal.Client
				if Client.gun then
					local Skin = SkinChanger.SelectedSkins[tostring(Client.gun)]

					if Skin ~= nil then
						local IsSecondary = Client.equipped == "secondary"
						local AlreadySkinned = false
						if IsSecondary and Client.secondaryskin == Skin then
							AlreadySkinned = true
						elseif not IsSecondary and Client.primaryskin == Skin then
							AlreadySkinned = true
						end

						if not Lib.Flags["ForceSkinChange"] then
							if
								(
									IsSecondary
									and (Client.secondaryskin ~= "Stock" and Client.secondaryowner ~= LocalPlayer.Name)
								)
								or (
									not IsSecondary
									and (Client.primaryskin ~= "Stock" and Client.primaryowner ~= LocalPlayer.Name)
								)
							then
								return oldUseThatGun(v254, v255, v256)
							end
						end

						if not AlreadySkinned then
							SkinChanger:ApplySkin(Skin, IsSecondary)
						end
					end
				end
			end

			return oldUseThatGun(v254, v255, v256)
		end)
	end

	function SkinChanger:GetGloveVariants(GloveName)
		local GloveFolder = ReplicatedStorage:FindFirstChild("Gloves")
		local Glove = nil
		local GloveVariants = nil

		if GloveFolder then
			Glove = GloveFolder:FindFirstChild(GloveName)
		end

		if Glove then
			GloveVariants = {}
			for i, v in next, Glove:GetChildren() do
				table.insert(GloveVariants, v.Name)
			end
		end
		return GloveVariants or { "None" }
	end

	function SkinChanger:UpdateGlove(Glove, Variant)
		if not Lib.Flags["SkinChanger"] or not SkinChanger.__Loaded then
			return
		end

		local CTSkins = getupvalue(Internal.Client.setcharacter, 17)
		local TSkins = getupvalue(Internal.Client.setcharacter, 18)

		local SkinFolder = LocalPlayer:FindFirstChild("SkinFolder")
		local TFolder = SkinFolder:FindFirstChild("TFolder")
		local CTFolder = SkinFolder:FindFirstChild("CTFolder")

		if Glove == "Default" then
			CTSkins.GloveOver = false
			TSkins.GloveOver = false
			if CTFolder and CTFolder:FindFirstChild("Glove") then
				CTFolder.Glove.Value = ""
			end
			if TFolder and TFolder:FindFirstChild("Glove") then
				TFolder.Glove.Value = ""
			end
		else
			local FullName = Glove .. "_" .. Variant

			if SkinFolder then
				if Variant == "Stock" then
					if CTFolder and CTFolder:FindFirstChild("Glove") then
						CTFolder.Glove.Value = ""
					end
					if TFolder and TFolder:FindFirstChild("Glove") then
						TFolder.Glove.Value = ""
					end
				else
					if CTFolder and CTFolder:FindFirstChild("Glove") then
						CTFolder.Glove.Value = Variant
					end
					if TFolder and TFolder:FindFirstChild("Glove") then
						TFolder.Glove.Value = Variant
					end
				end
			end

			CTSkins.GloveOver = true
			TSkins.GloveOver = true

			TSkins.Glove = {
				[1] = FullName,
			}

			CTSkins.Glove = {
				[1] = FullName,
			}
		end

		SkinChanger.GlovesVarianted = SkinChanger.GlovesVarianted or {}
		SkinChanger.GlovesVarianted[Glove] = Variant

		if not Internal.Warmup then
			coroutine.wrap(Internal.Client.setcharacter)()
		elseif library then
			library:SendNotification(Glove .. " " .. Variant .. " will be applied upon character reset", 3)
		end
	end

	function SkinChanger:UpdateKnife(Knife, Variant)
		if not Lib.Flags["SkinChanger"] or not SkinChanger.__Loaded then
			return
		end

		local KnifeVariants = SkinChanger:GetKnifeVariants(Knife)
		if not KnifeVariants or #KnifeVariants < 1 and Knife ~= "Default" then
			return
		end

		local CTSkins = getupvalue(Internal.Client.setcharacter, 17)
		local TSkins = getupvalue(Internal.Client.setcharacter, 18)

		local SkinFolder = LocalPlayer:FindFirstChild("SkinFolder")
		local TFolder = SkinFolder:FindFirstChild("TFolder")
		local CTFolder = SkinFolder:FindFirstChild("CTFolder")

		if Knife == "Default" then
			CTSkins.KnifeOver = false
			TSkins.KnifeOver = false
			if CTFolder and CTFolder:FindFirstChild("Knife") then
				CTFolder.Knife.Value = ""
			end

			if TFolder and TFolder:FindFirstChild("Knife") then
				TFolder.Knife.Value = ""
			end
		else
			local FullName = Knife .. "_" .. Variant
			if SkinFolder then
				if Variant == "Stock" then
					if CTFolder and CTFolder:FindFirstChild("Knife") then
						CTFolder.Knife.Value = ""
					end

					if TFolder and TFolder:FindFirstChild("Knife") then
						TFolder.Knife.Value = ""
					end
				else
					if CTFolder and CTFolder:FindFirstChild("Knife") then
						CTFolder.Knife.Value = Variant
					end

					if TFolder and TFolder:FindFirstChild("Knife") then
						TFolder.Knife.Value = Variant
					end
				end
			end

			CTSkins.KnifeOver = true
			TSkins.KnifeOver = true

			TSkins.Knife = {
				[1] = FullName,
			}

			CTSkins.Knife = {
				[1] = FullName,
			}
		end

		SkinChanger.KnivesVarianted[Knife] = Variant
		if not Internal.Warmup then
			coroutine.wrap(Internal.Client.setcharacter)()
		elseif library then
			library:SendNotification(Knife .. " " .. Variant .. " will be applied upon character reset", 3)
		end
	end

	function SkinChanger:CacheKnives()
		local Knifes = {}
		local KnivesFolder = ReplicatedStorage.Knives
		for i, v in next, KnivesFolder:GetChildren() do
			table.insert(Knifes, v.Name)
		end
		return Knifes
	end

	function SkinChanger:GetKnives()
		local KnifeNames = {}
		for i, v in next, Internal.Client.CurrentKnives do
			if v == "M9 Bayonet" or v == "Flip Knife" then
				continue
			end

			table.insert(KnifeNames, v)
		end
		return KnifeNames
	end

	function SkinChanger:GetKnifeVariants(KnifeName)
		return SkinChanger:GetSkins(KnifeName)
	end

	function SkinChanger:SkinChanged(Gun)
		if tostring(Gun) == Internal.Client.gun and Lib.Flags["SkinChanger"] then
			coroutine.wrap(Internal.Client.usethatgun)()
		end
	end

	getgenv().ImportSkins = function(SkinsTable, KnifeTable, GloveTable)
		if SkinsTable then
			SkinChanger.SelectedSkins = SkinsTable
			getgenv().SelectedSkins = SkinChanger.SelectedSkins
		end

		if KnifeTable then
			SkinChanger.KnivesVarianted = KnifeTable
			getgenv().KnivesVarianted = SkinChanger.KnivesVarianted
		end

		if GloveTable then
			SkinChanger.GlovesVarianted = GloveTable
			getgenv().GlovesVarianted = SkinChanger.GlovesVarianted
		end

		if library then
			local Imported = 0
			for i, v in next, { SkinsTable, KnifeTable, GloveTable } do
				for i, skin in next, v do
					Imported += 1
				end
			end
			library:SendNotification("Imported " .. tostring(Imported) .. " skins from config!", 5)
		end
	end

	function SkinChanger:ApplySkin(Skin, IsSecondary)
		if IsSecondary then
			Internal.Client.secondaryskin = Skin
			Internal.Client.secondaryowner = LocalPlayer.Name
		else
			Internal.Client.primaryskin = Skin
			Internal.Client.primaryowner = LocalPlayer.Name
		end

		Internal.Client.updateInventory()
	end

	function SkinChanger:CacheGun()
		local SkinsFolder = ReplicatedStorage:FindFirstChild("Skins")
		if not SkinsFolder then
			return false
		end

		for i, v in next, SkinsFolder:GetChildren() do
			table.insert(SkinChanger.Guns, v.Name)
		end
		return true
	end

	function SkinChanger:CacheSkins(Gun)
		local GunData = {}
		local GunSkins = ReplicatedStorage.Skins[Gun]
		if not GunSkins then
			return false
		end
		for i, SkinName in next, GunSkins:GetChildren() do
			table.insert(GunData, tostring(SkinName))
		end
		return GunData
	end

	function SkinChanger:GetGuns()
		return SkinChanger.Guns
	end

	function SkinChanger:GetSkins(Gun)
		if not SkinChanger.Skins then
			return
		end
		local entry = SkinChanger.Skins[Gun]
		if not entry then
			return
		end
		return entry
	end

	CreateModule("SkinChanger", SkinChanger)
end

local FontManager = {}
do
	FontManager.Fonts = {}
end

local KillSay = {}
do
	function KillSay:Init()
		if not isfolder("melancholy\\Counter Blox\\KillSay") then
			makefolder("melancholy\\Counter Blox\\KillSay")
		end
	end

	function KillSay:GetSources()
		local Sources = listfiles("melancholy\\Counter Blox\\KillSay")
		local SourceNames = {}

		for i, v in next, Sources do
			local Name = v:gsub("melancholy\\Counter Blox\\KillSay", ""):gsub(".txt", "")
			SourceNames[#SourceNames + 1] = Name
		end
		return SourceNames
	end

	CreateModule("KillSayHelper", KillSay)
end

local SoundManager = {}
do
	SoundManager.HitSounds = {
		"Cod",
		"Metal",
		"Beep",
		"Punch",
		"Roblox",
		"Skeet",
		"Error",
		"Jeff",
		"Vas",
	}
	SoundManager.Sounds = {}
	function SoundManager:Init()
		SoundManager.Source = "melancholy\\Counter Blox\\sounds"
		if not isfolder(SoundManager.Source) then
			makefolder(SoundManager.Source)
		end

		SoundManager:FetchSonuds()

		if next(SoundManager.Sounds) == nil then
			return false
		end
	end

	function SoundManager:GetSounds()
		local Sounds = listfiles("melancholy\\Counter Blox\\sounds")
		local NewSounds = {}
		for i, v in next, Sounds do
			local SoundName = v:gsub("melancholy\\Counter Blox\\sounds\\", ""):gsub(".wav", "")
			NewSounds[i] = SoundName

			if not table.find(SoundManager.HitSounds, SoundName) then
				print("Cached sound: " .. SoundName)

				local SoundID = getcustomasset(v)
				SoundManager:CreateSound(SoundName, SoundID)
				table.insert(SoundManager.HitSounds, SoundName)
			end
		end

		return NewSounds
	end

	function SoundManager:FetchSonuds()
		local Repo = "https://github.com/wirlypirly12/informant.wtf/raw/refs/heads/main/sounds/"
		for i, SoundName in next, SoundManager.HitSounds do
			local Link = Repo .. SoundName:lower() .. ".wav"
			local Path = SoundManager.Source .. "\\" .. SoundName .. ".wav"
			if not isfile(Path) then
				writefile(Path, game:HttpGet(Link))
			end

			local SoundID = getcustomasset(Path)
			SoundManager:CreateSound(SoundName, SoundID)
		end
	end

	function SoundManager:CreateSound(Name, SoundID)
		print(Name)
		local Sound = Instance.new("Sound", SoundService)
		Sound.SoundId = SoundID
		SoundManager.Sounds[Name] = Sound
	end

	function SoundManager:PlaySound(Name, Volume)
		local Sound = SoundManager.Sounds[Name]
		if not Sound then
			return false
		end

		Sound.Volume = Volume
		Sound:Play()
	end

	CreateModule("SoundManager", SoundManager)
end

local Ragebot = {}
do
	getgenv().LoadRagebotSettings = function(RageSettings)
		Ragebot.GunSettings = RageSettings
	end

	getgenv().GetRageSettings = function()
		return Ragebot.GunSettings or {}
	end
	getgenv().RagebotSettings = true
	function Ragebot:GetHitChance(ShooterPosition, TargetPart, Weapon, Samples, IsSniper, Mode, AccuracySD)
		local Client = Internal.Client
		local SpreadStats = Weapon and Weapon:FindFirstChild("Spread")
		if not TargetPart or not SpreadStats or not SpreadStats:FindFirstChild("Recoil") then
			return 0
		end

		local accuracy = AccuracySD or Client.accuracy_sd or 1
		local mode = Mode or Client.mode or "automatic"
		local isSniper = IsSniper ~= nil and IsSniper or Weapon:FindFirstChild("snipo") ~= nil

		local Spread, AdditionalSpread, FireSpread, RecoilMag =
			Utility:BuildSpreadState(SpreadStats, Client, Weapon, isSniper, Lib)

		local Hits = 0
		local pellets = Weapon:FindFirstChild("Bullets") and math.max(1, Weapon.Bullets.Value) or 1
		local shotsFired = Client.numShots or 0

		for i = 1, Samples do
			local MovementPenalty = 0
			if Client.curspd and Client.maxyvel then
				local SpeedRatio = math.min(Client.curspd / (Client.maxyvel or 16), 1)
				MovementPenalty = SpeedRatio * 2
			end

			local TotalSpread = (Spread + AdditionalSpread + MovementPenalty) * accuracy

			local AimDirection = (TargetPart.Position - ShooterPosition).Unit
			local AimCF = CFrame.new(Vector3.new(), AimDirection)

			local hitSample = false

			for pellet = 1, pellets do
				local ShotIndex = shotsFired + i
				local pat = Client.getpat(ShotIndex)

				local angle = math.rad(pat.fAngle or 90)
				local mag = pat.fMagnitude or 0

				local ModeMultiplier = 1
				if mode == "semi" then
					ModeMultiplier = 0.55
				elseif mode == "automatic" then
					ModeMultiplier = 1.5
				end

				local theta = Utility:Stratify(i, Samples) * math.pi * 2
				local exp = isSniper and 1 or 0.25
				local radius = TotalSpread * (Utility:Stratify(pellet, pellets) ^ exp) * ModeMultiplier

				local randX = radius * math.cos(theta)
				local randY = radius * math.sin(theta)

				local recoilScale = 1
				if mode == "semi" then
					recoilScale = 0
				end

				local offsetX = -math.cos(angle) * mag * FireSpread * accuracy * recoilScale + randX
				local offsetY = math.sin(angle) * mag * RecoilMag * accuracy * recoilScale + randY

				local perturb = CFrame.Angles(offsetY, offsetX, 0)
				local Direction = (AimCF * perturb).lookVector

				local Raycast = Ray.new(ShooterPosition, Direction * 1000)
				local HitPart = select(1, workspace:FindPartOnRayWithWhitelist(Raycast, { TargetPart }, false, true))

				if HitPart then
					hitSample = true
					break
				end
			end

			if hitSample then
				Hits += 1
			end
		end

		return (Hits / Samples) * 100
	end

	function Ragebot:Init()
		Ragebot.GunSettings = {
			["Global"] = {
				Bones = { "Head" },
				MultiPoints = { "Head" },
				PointSize = 75,
				MinDamage = 55,
				MinHitchance = 79,
				Perferbody = false,
				Forcebody = false,
				GroupEnabled = false,
			},
		}

		Ragebot.Guns = {
			["Rifle"] = {
				"AK47",
				"M4A4",
				"M4A1",
			},
			["Scout"] = {
				"Scout",
			},
			["Desert Eagle"] = {
				"DesertEagle",
			},
			["R8 Revolver"] = {
				"R8",
			},
			["Pistol"] = {
				"P2000",
				"Glock",
				"FiveSeven",
				"USP",
				"CZ",
			},
			["AWP"] = {
				"AWP",
			},
			["Auto Sniper"] = {
				"G3SG1",
			},
		}

		Ragebot.Target = {}
		Ragebot.BoneGroups = {
			["Legs"] = {
				"LeftUpperLeg",
				"LeftLowerLeg",
				"RightUpperLeg",
				"RightLowerLeg",
			},
			["Arms"] = {
				"LeftUpperArm",
				"LeftLowerArm",
				"RightUpperArm",
				"RightLowerArm",
			},
			["Stomach"] = {
				"UpperTorso",
				"LowerTorso",
			},
			["Head"] = {
				"Head",
				"HeadHB",
				"FakeHead",
			},
			["Hands"] = {
				"LeftHand",
				"RightHand",
			},
			["Feet"] = {
				"LeftFoot",
				"RightFoot",
			},
		}

		Ragebot.PeekAssistCircle = game:GetObjects("rbxassetid://334727500")[1] -- sumthing
		Ragebot.PeekAssistCircle.Size = Vector3.new(4.5, 0.1, 4.5)
		Ragebot.PeekAssistCircle.CanCollide = false
		Ragebot.PeekAssistCircle.Parent = ReplicatedStorage
	end

	function Ragebot:GetGunCatergory(Gun)
		local GunRCat = nil
		for GunCat, GunData in next, self.Guns do
			for key, GunName in next, GunData do
				if GunName == Gun then
					GunRCat = GunCat
					break
				end
			end
		end
		return GunRCat
	end

	function Ragebot:GetCatergorySettings(Catergory)
		local Entry = self.GunSettings[Catergory]
		if not Entry then
			if self.GunSettings.Global.GroupEnabled then
				return self.GunSettings.Global
			end

			return
		end

		if not Entry.GroupEnabled then
			if self.GunSettings.Global.GroupEnabled then
				return self.GunSettings.Global
			end
			return
		end

		return Entry
	end

	-- function Ragebot:ApplySettings(Group)
	-- 	assert(typeof(Group) ~= "table", "Group is not a table");
	-- 	for i, v in next, Group do
	-- 		local Entry = self.GunSettings[i];
	-- 		if Entry then
	-- 			self.GunSettings[i] = v;
	-- 		end
	-- 	end
	-- end

	function Ragebot:GetTarget(MaxAngle)
		local Target = nil
		local Closest = math.huge

		for i, v in next, EntityModule.Players do
			if not v.Alive or i == LocalPlayer then
				continue
			end

			if not v.Enemy then
				continue
			end

			local HumanoidRoot = v.Rig and v.Rig.HumanoidRootPart
			if not HumanoidRoot then
				continue
			end

			local Dot = Camera.CFrame.LookVector:Dot((HumanoidRoot.Part.Position - Camera.CFrame.p).Unit)
			local Angle = math.deg(math.acos(Dot))

			if Angle > MaxAngle then
				continue
			end

			if Angle < Closest then
				Closest = Angle
				Target = v
			end
		end
		return Target
	end

	function Ragebot:GetGunSettings(Gun)
		local GunCat = Ragebot:GetGunCatergory(Gun)
		if not GunCat then
			if self.GunSettings.Global.GroupEnabled then
				return self.GunSettings.Global
			end

			return
		end

		local CatSettings = Ragebot:GetCatergorySettings(GunCat)
		if CatSettings then
			return CatSettings
		end
	end

	-- retarded
	function Ragebot:OriginalNil()
		Ragebot.OriginalPosition = nil
		Ragebot.PeekAssistCircle.Parent = ReplicatedStorage
	end

	function Ragebot:PeekAssist()
		local LocalEntry = EntityModule.Players[LocalPlayer]
		if not LocalEntry or not LocalEntry.Alive then
			Ragebot.PeekAssistCircle.Parent = ReplicatedStorage
			Ragebot.OriginalPosition = nil
			return
		end

		if
			Lib.Flags["PeekAssist"]
			and Ragebot.PeekAssistCircle.Parent == ReplicatedStorage
			and Lib.Flags["PeekAssistBind"]
		then
			Ragebot.OriginalPosition = LocalEntry.Rig.HumanoidRootPart.Part.Position
			Ragebot.PeekAssistCircle.Parent = Internal.MapSpawned and workspace.Ray_Ignore or workspace

			local Origin = ((LocalEntry.Rig["LeftFoot"].Part.Position + LocalEntry.Rig["RightFoot"].Part.Position) / 2)
				+ Vector3.new(0, 2, 0)
			local Params = RaycastParams.new()
			Params.FilterDescendantsInstances = Internal.IgnoreList
			Params.FilterType = Enum.RaycastFilterType.Exclude

			local Hit = workspace:Raycast(Origin, Vector3.new(0, -1, 0) * 50, Params)

			if Hit then
				Ragebot.PeekAssistCircle.CFrame = CFrame.new(Hit.Position)
				Ragebot.PeekAssistCircle.Color = Lib.Flags["PeekAssistCircleColor"]
				Ragebot.PeekAssistCircle.Transparency = Lib.Options["PeekAssistCircleColor"].trans
			end
		elseif
			not Lib.Flags["PeekAssistBind"]
			or not Lib.Flags["PeekAssist"] and Ragebot.PeekAssistCircle.Parent ~= ReplicatedStorage
		then
			Ragebot.PeekAssistCircle.Parent = ReplicatedStorage
			Ragebot.OriginalPosition = nil
		end
	end

	function Ragebot:GetBones(BoneList, GunSettings, Target, Multipoints, HC, IsBackTrack)
		local TargetBones = {}
		for i, BoneCategory in next, BoneList do
			local BoneData = Ragebot.BoneGroups[BoneCategory]
			if not BoneData then
				continue
			end

			for i, BoneName in next, BoneData do
				local RigPart = Target.Rig[BoneName]
				if IsBackTrack then
					local Part = nil
					for ghostKey, ghost in pairs(Target.Backtrack) do
						if ghost.Name == BoneName then
							Part = ghost
							break
						end
					end

					if not Part then
						continue
					end

					RigPart = {
						Part = Part,
					}
				end

				if not RigPart then
					continue
				end

				if GunSettings.MultiPoints[BoneCategory] then
					for _, offset in next, Multipoints do
						local TargetPos = RigPart.Part.Position + offset

						local CanShoot = false
						local AutowallResult

						if Lib.Flags["RagebotAutoWall"] then
							AutowallResult =
								Ragebot:Autowall(Camera.CFrame.p, TargetPos, Internal.MyGun.Penetration, Target.Char)
							CanShoot = AutowallResult.Stopped
								and AutowallResult.HitCharacter
								and AutowallResult.DamageMod > 0
						elseif Utility:Visible(RigPart.Part) then
							CanShoot = true
						end

						if CanShoot then
							local Multiplier = _Rig[RigPart.Part.Name]
							local Damage = (Internal.MyGun.Damage * Multiplier)
							if AutowallResult then
								Damage *= AutowallResult.DamageMod
							end

							if Damage >= GunSettings.MinDamage then
								table.insert(TargetBones, {
									Damage = Damage,
									HitChance = HC,
									Part = RigPart.Part,
									Bone = RigPart,
								})
							end
						end
					end
				else
					local CanShoot = false
					local AutowallResult

					if Lib.Flags["RagebotAutoWall"] then
						AutowallResult = Ragebot:Autowall(
							Camera.CFrame.p,
							RigPart.Part.Position,
							Internal.MyGun.Penetration,
							Target.Char
						)
						CanShoot = AutowallResult.Stopped
							and AutowallResult.HitCharacter
							and AutowallResult.DamageMod > 0
					elseif Utility:Visible(RigPart.Part) then
						CanShoot = true
					end

					if CanShoot then
						local Multiplier = _Rig[RigPart.Part.Name]
						local Damage = (Internal.MyGun.Damage * Multiplier)

						if Damage >= GunSettings.MinDamage then
							table.insert(TargetBones, {
								Damage = Damage,
								HitChance = HC,
								Part = RigPart.Part,
								Bone = RigPart,
							})
						end
					end
				end
			end
		end

		return TargetBones
	end

	function Ragebot:Tick()
		self:PeekAssist()

		EntityModule.EntityFolder.Parent = Lib.Flags["HistorySettings"] == "None" and ReplicatedStorage or workspace

		local LocalEntry = EntityModule.Players[LocalPlayer]
		if not LocalEntry.Alive then
			Ragebot.HitChance = nil
			return
		end

		if not Internal.MyGun or not Lib.Flags["Ragebot"] then
			Ragebot.HitChance = nil
			Ragebot.Target = {}
			return
		end

		local Target = Ragebot:GetTarget(Lib.Flags["RageFOV"])
		if not Target then
			Ragebot.HitChance = nil
			Ragebot.Target = {}
			return
		end

		local GunSettings = Ragebot:GetGunSettings(Internal.MyGun._Gun.Name)
		if not GunSettings then
			Ragebot.HitChance = nil
			return
		end

		local radius = 0.05 + (0.5 - 0.05) * GunSettings.PointSize
		local Multipoints = {
			Vector3.new(0, 0, 0),
			Vector3.new(radius, 0, 0),
			Vector3.new(-radius, 0, 0),
			Vector3.new(0, radius, 0),
			Vector3.new(0, -radius, 0),
			Vector3.new(radius / 2, radius / 2, 0),
		}

		local BoneList = GunSettings.Bones or {}
		local AllBones = {}

		local IsSniper = Internal.MyGun._Gun:FindFirstChild("snipo") ~= nil
			or Internal.MyGun._Gun:FindFirstChild("Scoped") ~= nil
		local Mode = Internal.Client.mode or "automatic"
		local Accuracy = Internal.Client.accuracy_sd or 1

		-- current target bones
		local BonesNow = Ragebot:GetBones(BoneList, GunSettings, Target, Multipoints, nil)
		if #BonesNow > 0 then
			local HC = Ragebot:GetHitChance(
				Camera.CFrame.p,
				Target.Rig.HumanoidRootPart.Part,
				Internal.MyGun._Gun,
				64,
				IsSniper,
				Mode,
				Accuracy
			)
			if HC >= GunSettings.MinHitchance then
				for _, b in next, BonesNow do
					table.insert(AllBones, b)
				end
			end
		end

		-- backtrack bones
		if Lib.Flags["AimAtHistory"] and Target.Backtrack then
			local BonesBT = Ragebot:GetBones(BoneList, GunSettings, Target, Multipoints, nil, true)
			if #BonesBT > 0 then
				local BestBone = BonesBT[1]
				local HCbt = Ragebot:GetHitChance(
					Camera.CFrame.p,
					BestBone.Part,
					Internal.MyGun._Gun,
					64,
					IsSniper,
					Mode,
					Accuracy
				)
				if HCbt >= GunSettings.MinHitchance then
					for _, b in next, BonesBT do
						--b.HitChance = Ragebot:GetHitChance(Camera.CFrame.p, b.Part, Internal.MyGun._Gun, 64, IsSniper, Mode, Accuracy)
						table.insert(AllBones, b)
					end
				end
			end
		end

		-- table.sort(AllBones, function(a, b)
		-- 	if GunSettings.Perferbody then
		-- 		return a.HitChance > b.HitChance
		-- 	else
		-- 		return a.Damage > b.Damage
		-- 	end
		-- end)

		table.sort(AllBones, function(a, b)
			return a.Damage > b.Damage
		end)

		if #AllBones > 0 then
			local MainBone = AllBones[1]

			Ragebot.Target = { Bone = MainBone.Part }
			Ragebot.HitChance = MainBone.HitChance

			if Lib.Flags["AutoStop"] and LocalEntry.Alive then
				LocalPlayer.Character.HumanoidRootPart.Velocity = Vector3.zero
			end

			if Lib.Flags["RagebotAutoShoot"] then
				Internal:Shoot()
			end
		else
			Ragebot.HitChance = nil
			Ragebot.Target = {}
		end
	end

	function Ragebot:Autowall(StartPosition, EndPosition, PenetrationPower, TargetChar)
		PenetrationPower = PenetrationPower * 0.01 or 1000

		local Result = {
			DamageMod = 1,
			Penetrations = 0,
			Stopped = false,
		}
		local IgnoreList = { table.unpack(Internal.IgnoreList) }

		local Direction = (EndPosition - StartPosition)
		local TotalDistance = Direction.Magnitude

		if TotalDistance <= 0 then
			return Result
		end

		local DirUnit = Direction.Unit

		local TotalPenetration = 0
		local PenetrationCount = 0
		local MaterialMultiplier, DamageModifier = 1
		local MaxPenetrations = 4

		local CurrentOrigin = StartPosition
		local RemainingDistance = TotalDistance

		while true do
			if RemainingDistance <= 0 then
				Result.Stopped = true
				break
			end

			local ray = Ray.new(CurrentOrigin, DirUnit * RemainingDistance)
			local HitPart, HitPos, HitNormal = workspace:FindPartOnRayWithIgnoreList(ray, IgnoreList)
			if not HitPart then
				Result.Stopped = true
				break
			end

			local Material = HitPart.Material
			if Material == Enum.Material.DiamondPlate then
				MaterialMultiplier = 3
			elseif
				Material == Enum.Material.CorrodedMetal
				or Material == Enum.Material.Metal
				or Material == Enum.Material.Concrete
				or Material == Enum.Material.Brick
			then
				MaterialMultiplier = 2
			end

			if HitPart.Name == "Grate" or Material == Enum.Material.Wood or Material == Enum.Material.WoodPlanks then
				MaterialMultiplier = 0.1
			end

			if
				HitPart.Transparency == 1
				or HitPart.CanCollide == false
				or HitPart.Name == "Glass"
				or HitPart.Name == "Cardboard"
			then
				MaterialMultiplier = 0
			end

			if
				HitPart.Parent
				and (
					HitPart.Parent:FindFirstChild("Humanoid")
					or HitPart.Parent.ClassName == "Accessory"
					or HitPart.Parent.ClassName == "Hat"
				)
			then
				MaterialMultiplier = 0.1
			end

			if HitPart.Name == "nowallbang" then
				MaterialMultiplier = 100
			end

			local Thickness = Utility:GetPartThickness(HitPart, HitPos, DirUnit) * MaterialMultiplier
			TotalPenetration = math.min(PenetrationPower, TotalPenetration + Thickness)

			local IsPlayer = false
			local Parent = HitPart.Parent
			if Parent and Parent:FindFirstChild("Humanoid") and Parent:IsA("Model") then
				IsPlayer = true
			end

			local Solid = (MaterialMultiplier ~= 0)

			if IsPlayer and Parent == TargetChar then
				Result.HitPart = HitPart
				Result.HitPos = HitPos
				Result.HitCharacter = Parent
				Result.Penetrations = PenetrationCount
				DamageModifier = 1 - TotalPenetration / PenetrationPower
				if DamageModifier < 0 then
					DamageModifier = 0
				end

				Result.DamageMod = DamageModifier
				Result.Stopped = true
				break
			end

			if Solid and not (Parent and Parent:FindFirstChild("Humanoid")) then
				Result.HitPart = HitPart
				Result.HitPos = HitPos
			end

			if MaterialMultiplier > 0 then
				PenetrationCount += 1
			end

			DamageModifier = 1 - TotalPenetration / PenetrationPower
			if DamageModifier < 0 then
				DamageModifier = 0
			end

			table.insert(IgnoreList, HitPart)
			CurrentOrigin = HitPos + DirUnit * 0.01
			RemainingDistance = RemainingDistance - (HitPos - CurrentOrigin).Magnitude

			if TotalPenetration >= PenetrationPower or PenetrationCount >= MaxPenetrations then
				Result.Penetrations = PenetrationCount
				Result.DamageMod = DamageModifier
				Result.Stopped = true
				break
			end
		end

		Result.Penetrations = PenetrationCount
		Result.DamageMod = DamageModifier
		return Result
	end

	CreateModule("Ragebot", Ragebot)
end

local Movement = {}
do
	-- function Movement:Init()

	-- end

	function Movement:ApplyVelocity(RootPart, Direction, MaxSpeed, AccelerationRate, Dt)
		local Vel = RootPart.AssemblyLinearVelocity
		local Horizontal = Vector3.new(Vel.X, 0, Vel.Z)

		local SpeedAlongDir = Horizontal:Dot(Direction)
		local RemainingSpeed = MaxSpeed - SpeedAlongDir
		local AddSpeed = math.min(AccelerationRate * Dt, RemainingSpeed)

		if AddSpeed > 0 then
			RootPart.AssemblyLinearVelocity += Vector3.new(Direction.X, 0, Direction.Z) * AddSpeed
		end
	end

	function Movement:GetMovementDir()
		local Direction = Vector3.zero

		if Utility:IsPressing(Enum.KeyCode.W) then
			Direction += Camera.CFrame.LookVector
		end

		if Utility:IsPressing(Enum.KeyCode.A) then
			Direction -= Camera.CFrame.RightVector
		end

		if Utility:IsPressing(Enum.KeyCode.S) then
			Direction -= Camera.CFrame.LookVector
		end

		if Utility:IsPressing(Enum.KeyCode.D) then
			Direction += Camera.CFrame.RightVector
		end

		if Direction.Magnitude > 0 then
			Direction = Direction.Unit
		end
		Direction = Vector3.new(Direction.X, 0, Direction.Z)
		return Direction
	end

	function Movement:OnEdge(Origin: CFrame)
		Origin = Origin.Position + (Origin.LookVector * 1.5)
		local Result = workspace:Raycast(Origin, Vector3.new(0, -4, 0), Utility.RayParams)
	end

	function Movement:Tick(Dt)
		local localPlayer = EntityModule.Players[LocalPlayer]

		if not localPlayer.Alive or not Lib.Flags["MovementEnabled"] then
			return
		end

		local Humanoid: Humanoid = localPlayer.Rig.Humanoid
		local RootPart = localPlayer.Rig.HumanoidRootPart
		if not Humanoid or not RootPart or not Internal.InGame then
			return
		end

		if Lib.Flags["BunnyHop"] and not Movement:InAir(Humanoid) and Utility:IsPressing(Enum.KeyCode.Space) then
			-- jump
			Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		elseif
			Lib.Flags["BunnyHop"]
			and Utility:IsPressing(Enum.KeyCode.Space)
			and Lib.Flags["AutoStrafe"] ~= "None"
		then
			-- apply momentum
			--ootPart.Part.Velocity *= 10

			-- in the air
			local StrafeMode = Lib.Flags["AutoStrafe"]

			local Direction = Movement:GetMovementDir()
			local MaxSpeed = Lib.Flags["StrafeSpeed"]

			if StrafeMode == "Acceleration" then
				Movement:ApplyVelocity(RootPart.Part, Direction, MaxSpeed, 2000, Dt)
			elseif StrafeMode == "Instant" and Direction.Magnitude > 0 then
				local NewVelocity = Direction * MaxSpeed
				RootPart.Part.Velocity = Vector3.new(NewVelocity.X, RootPart.Part.Velocity.Y, NewVelocity.Z)
			end
		end
	end

	function Movement:InAir(Humanoid: Humanoid)
		local State = Humanoid:GetState()
		return State == Enum.HumanoidStateType.Jumping
			or State == Enum.HumanoidStateType.Freefall
			or State == Enum.HumanoidStateType.FallingDown and State ~= Enum.HumanoidStateType.Climbing
	end

	CreateModule("Movement", Movement)
end

do
	-- Credits To The Original Devs @xz, @goof (ui)
	local library = dofile("melancholy\\menu.lua")
	library.cheatname = "melancholy"
	library.gamename = "Counter Blox"
	library.fileext = ".mlnch"

	library:init()

	Lib.Flags = library.flags
	Lib.Options = library.options
	Lib.Window = library.NewWindow({
		title = "melancholy",
		size = UDim2.new(0, 600, 0, 700),
	})

	Lib.Tabs = {
		Combat = Lib.Window:AddTab("Combat"),
		Rage = Lib.Window:AddTab("Rage"),
		Visuals = Lib.Window:AddTab("Visuals"),
		Misc = Lib.Window:AddTab("Misc"),
		Movement = Lib.Window:AddTab("Movement"),
		Settings = library:CreateSettingsTab(Lib.Window),
	}

	local Sections = {
		-- Combat Tab
		Legitbot = Lib.Tabs.Combat:AddSection("Legitbot", 1),
		SilentAim = Lib.Tabs.Combat:AddSection("Silent Aim", 2),

		-- Rage Tab
		WeaponType = Lib.Tabs.Rage:AddSection("Weapon type", 1),
		Aimbot = Lib.Tabs.Rage:AddSection("Aimbot", 1),
		Other = Lib.Tabs.Rage:AddSection("Other", 2),
		AntiAim = Lib.Tabs.Rage:AddSection("Anti-aimbot angles", 2),
		-- Visuals Tab
		ESP = Lib.Tabs.Visuals:AddSection("ESP", 1),
		Colors = Lib.Tabs.Visuals:AddSection("Colors", 2),
		CombatVis = Lib.Tabs.Visuals:AddSection("Combat Visuals", 2),
		OtherESP = Lib.Tabs.Visuals:AddSection("Other", 1),
		-- Misc Tab
		SkinChanger = Lib.Tabs.Misc:AddSection("Skin Changer", 2),
		Hooks = Lib.Tabs.Misc:AddSection("Events", 1),
		World = Lib.Tabs.Misc:AddSection("World", 1),
		Network = Lib.Tabs.Misc:AddSection("Network", 2),
		Killsay = Lib.Tabs.Misc:AddSection("Kill Say", 2),
		-- movement tab
		PlayerMovement = Lib.Tabs.Movement:AddSection("Player", 1),
	}

	-- movement tab
	do
		local PlayerMovement = Sections.PlayerMovement

		PlayerMovement:AddToggle({
			text = "Master switch",
			flag = "MovementEnabled",
			tooltip = "Enable main movement group",
		})

		PlayerMovement:AddSeparator({
			text = "Main",
		})

		PlayerMovement:AddToggle({
			text = "Bunny hop",
			flag = "BunnyHop",
			tooltip = "Automatically jump when pressing space",
		})

		PlayerMovement:AddList({
			text = "Auto strafe",
			flag = "AutoStrafe",
			values = {
				"None",
				"Acceleration",
				"Instant",
			},
			value = "None",
			tooltip = "Control your character in the air easier with auto strafer\nNone - You must strafe manually\nAcceleration - Similar to CS2's sub-tick bunny hop, strafe speed acts as a max speed\nInstant - Bunny hop you'd find in most Counter blox scripts, just instant & fast bunny hop",
		})

		PlayerMovement:AddSlider({
			text = "Strafe speed",
			min = 1,
			max = 300,
			increment = 1,
			tooltip = 'The speed you will bunny hop at, strafe speed is ignored if auto strafe is set to "None"',
			value = 16,
			flag = "StrafeSpeed",
		})

		-- PointSize = Aimbot:AddSlider{
		-- 	text = "Point size",
		-- 	suffix = "%",
		-- 	min = 0,
		-- 	max = 100,
		-- 	increment = 1,
		-- 	flag = "RagePointSize",
		-- 	tooltip = "Size of the multipoints",
		-- 	value = 85,
		-- 	callback = function(MultiSize)
		-- 		local Settings = Ragebot.GunSettings[Lib.Flags["WeaponGroup"]]
		-- 		if Settings then
		-- 			Settings.PointSize = MultiSize
		-- 		else
		-- 			print("No settings")
		-- 		end
		-- 	end
		-- }

		PlayerMovement:AddToggle({
			text = "Edge jump",
			flag = "EdgeJump",
			tooltip = "Jump automatically when walking off something",
		})

		PlayerMovement:AddToggle({
			text = "Quick stop",
			flag = "QuickStop",
			tooltip = "Makes your character stop faster",
		})

		PlayerMovement:AddToggle({
			text = "No Weapon Slowdown",
			flag = "NoSlowDown",
			tooltip = "Big weapons will not affect your speed",
		})

		PlayerMovement:AddToggle({
			text = "Speed hack",
			flag = "SpeedHack",
			tooltip = "Classic speed hack... duh",
		})

		PlayerMovement:AddSlider({
			text = "Speed",
			flag = "SpeedHackSpeed",
			tooltip = "Your desired speed hack speed",
			min = 10,
			max = 100,
			increment = 1,
			value = 20,
		})
	end

	-- Rage tab
	do
		local WeaponType = Sections.WeaponType

		local GroupEnabled = nil
		local Bonedropdown = nil
		local MultipointDropdown = nil
		local PointSize = nil
		local MinDamage = nil
		local MinHitchance = nil
		local Perferbody = nil
		local Forcebody = nil

		WeaponType:AddList({
			text = "Weapon Group",
			flag = "WeaponGroup",
			tooltip = "Choose specific min-damage and hitchance per gun class",
			value = "Global",
			values = {
				"Global",
				"Scout",
				"Auto Sniper",
				"AWP",
				"R8 Revolver",
				"Desert Eagle",
				"Pistol",
				"Rifle",
			},
			callback = function(SelectedGun)
				if not Ragebot.__Loaded then
					return
				end

				local Settings = Ragebot.GunSettings[SelectedGun]
				if not Settings then
					local NewSettings = {
						Bones = { "Head" },
						MultiPoints = { "Head" },
						PointSize = 75,
						MinDamage = 55,
						MinHitchance = 79,
						Perferbody = false,
						Forcebody = false,
						GroupEnabled = false,
					}

					Ragebot.GunSettings[SelectedGun] = NewSettings
					Settings = NewSettings
				end

				if Settings.Bones and Bonedropdown then
					Bonedropdown:Select(Settings.Bones)
				end

				if Settings.MultiPoints and MultipointDropdown then
					MultipointDropdown:Select(Settings.MultiPoints)
				end

				if Settings.PointSize ~= nil and PointSize then
					PointSize:SetValue(Settings.PointSize)
				end

				if Settings.MinDamage ~= nil and MinDamage then
					MinDamage:SetValue(Settings.MinDamage)
				end

				if Settings.Perferbody ~= nil and Perferbody then
					Perferbody:SetState(Settings.Perferbody)
				end

				if Settings.MinHitchance ~= nil and MinHitchance then
					MinHitchance:SetValue(Settings.MinHitchance)
				end

				if Settings.Forcebody ~= nil and Forcebody then
					Forcebody:SetState(Settings.Forcebody)
				end

				if Settings.GroupEnabled ~= nil and GroupEnabled then
					GroupEnabled:SetState(Settings.GroupEnabled)
				end
			end,
			multi = false,
		})

		GroupEnabled = WeaponType:AddToggle({
			text = "Enable",
			flag = "WeaponGroupEnabled",
			tooltip = "Allows the ragebot to use the settings for the weapon group",
			callback = function(State)
				local Settings = Ragebot.GunSettings[Lib.Flags["WeaponGroup"]]
				if Settings then
					Settings.GroupEnabled = State
				else
					print("No settings")
				end
			end,
		})

		local Aimbot = Sections.Aimbot

		Aimbot:AddToggle({
			text = "Master Switch",
			flag = "Ragebot",
			tooltip = "Automatically aim at targets when shooting",
		})

		Bonedropdown = Aimbot:AddList({
			text = "Bones",
			values = {
				"Head",
				"Stomach",
				"Arms",
				"Legs",
				"Hands",
				"Feet",
			},
			value = "Head",
			multi = true,
			tooltip = "Selected aim bones",
			flag = "RageBotBones",
			callback = function(BoneList)
				local Settings = Ragebot.GunSettings[Lib.Flags["WeaponGroup"]]
				if Settings then
					Settings.Bones = BoneList
				else
					print("No settings")
				end
			end,
		})

		MultipointDropdown = Aimbot:AddList({
			text = "Multi-point",
			values = {
				"Head",
				"Stomach",
				"Arms",
				"Legs",
				"Hands",
				"Feet",
			},
			value = "Head",
			multi = true,
			tooltip = "Selected multi points",
			flag = "RageBotMultiPoints",
			callback = function(MultiPoints)
				local Settings = Ragebot.GunSettings[Lib.Flags["WeaponGroup"]]
				if Settings then
					Settings.MultiPoints = MultiPoints
				else
					print("No settings")
				end
			end,
		})

		PointSize = Aimbot:AddSlider({
			text = "Point size",
			suffix = "%",
			min = 0,
			max = 100,
			increment = 1,
			flag = "RagePointSize",
			tooltip = "Size of the multipoints",
			value = 85,
			callback = function(MultiSize)
				local Settings = Ragebot.GunSettings[Lib.Flags["WeaponGroup"]]
				if Settings then
					Settings.PointSize = MultiSize
				else
					print("No settings")
				end
			end,
		})

		MinHitchance = Aimbot:AddSlider({
			text = "Mimimum hit chance",
			suffix = "%",
			min = 0,
			max = 100,
			increment = 1,
			flag = "RageHitChance",
			tooltip = "The minimum chance before the ragebot will shoot (only applicable on angles mode)",
			value = 95,
			callback = function(HitChance)
				local Settings = Ragebot.GunSettings[Lib.Flags["WeaponGroup"]]
				if Settings then
					Settings.MinHitchance = HitChance
				else
					print("No settings")
				end
			end,
		})

		MinDamage = Aimbot:AddSlider({
			text = "Minimum damage",
			suffix = "dmg",
			min = 0,
			max = 100,
			increment = 1,
			flag = "RageMinDamage",
			tooltip = "The minimum damage before the ragebot will shoot",
			value = 80,
			callback = function(MinDamage)
				local Settings = Ragebot.GunSettings[Lib.Flags["WeaponGroup"]]
				if Settings then
					Settings.MinDamage = MinDamage
				else
					print("No settings")
				end
			end,
		})

		Perferbody = Aimbot:AddToggle({
			text = "Perfer safest",
			flag = "PerferBodyAim",
			tooltip = "Hit the body part with the highest hit chance",
			callback = function(State)
				local Settings = Ragebot.GunSettings[Lib.Flags["WeaponGroup"]]
				if Settings then
					Settings.Perferbody = State
				else
					print("No settings")
				end
			end,
		})

		Forcebody = Aimbot:AddToggle({
			text = "Force body",
			tooltip = "Always aim at the body",
			flag = "ForceBodyAim",
			callback = function(State)
				local Settings = Ragebot.GunSettings[Lib.Flags["WeaponGroup"]]
				if Settings then
					Settings.Forcebody = State
				else
					print("No settings")
				end
			end,
		})

		Aimbot:AddToggle({
			text = "Auto stop",
			flag = "AutoStop",
			tooltip = "Makes you stop moving before firing",
		})

		Aimbot:AddToggle({
			text = "Auto scope",
			tooltip = "Auto scope before you shoot for highest accuracy",
			flag = "AutoScope",
		})

		local Other = Sections.Other

		Other:AddList({
			text = "History",
			flag = "HistorySettings",
			values = {
				"None",
				"Minimum",
				"Extended",
				"Maximum",
			},
			tooltip = "See players as they were a couple seconds ago\nNone - Disabled history altogether\nMinimum - 300 millisecond history\nExtended - 2 second history\nMaximum - 4 second history",
			value = "None",
		})

		Other:AddToggle({
			text = "Aim at history",
			tooltip = "Ragebot will fallback to the history if the target is not able to be hit.",
			flag = "AimAtHistory",
		})

		Other:AddToggle({
			text = "Automatic fire",
			tooltip = "Shoot when the ragebot has a target",
			flag = "RagebotAutoShoot",
		})

		Other:AddToggle({
			text = "Aim through walls",
			tooltip = "Target player through walls that are penetrable",
			flag = "RagebotAutoWall",
		})

		Other:AddToggle({
			text = "Silent aim",
			tooltip = "Spoof your camera angles to always look at the target",
			flag = "RageSilent",
		})

		Other:AddToggle({
			text = "Remove recoil",
			flag = "RemoveRecoil",
			tooltip = "Ignore recoil when shooting",
		})

		Other:AddToggle({
			text = "Remove spread",
			flag = "RemoveSpread",
			tooltip = "Ignore spread while shooting",
		})

		Other:AddToggle({
			text = "Infinite ammo",
			flag = "InfAmmo",
			tooltip = "Never run out of ammo",
		})

		Other:AddToggle({
			text = "Resolver",
			flag = "RagebotResolver",
			tooltip = "Enables advanced resolver that corrects fast paced enemiee",
		})

		Other:AddToggle({
			text = "Double tap",
			flag = "DoubleTap",
			tooltip = "Shoot twice with one bullet being removed",
		})

		Other:AddToggle({
			text = "Quick peek assist",
			flag = "PeekAssist",
			tooltip = "Teleport back to your original position when shooting",
		}):AddBind({
			text = "Peek Assist",
			flag = "PeekAssistBind",
			tooltip = "Hold this to do peek assist",
			mode = "hold",
			bind = "None",
		})

		Other:AddSlider({
			text = "Maximum FOV",
			min = 1,
			max = 180,
			suffix = " degrees",
			increment = 1,
			value = 180,
			flag = "RageFOV",
		})

		local AntiAim = Sections.AntiAim

		AntiAim:AddToggle({
			text = "Master switch",
			flag = "AntiAim",
			tooltip = "Enable anti aim, purely cosmetic against people who use pSilent",
		})

		AntiAim:AddList({
			text = "Yaw Modifier",
			values = {
				"Static",
				"Jitter",
				"Sine",
			},
			value = "Static",
			flag = "YawModifier",
		})

		AntiAim:AddList({
			text = "Pitch",
			values = {
				"None",
				"Zero",
				"Up",
				"Down",
				"Custom",
			},
			value = "None",
			flag = "AntiAimPitch",
		})

		AntiAim:AddList({
			text = "Yaw base",
			values = {
				"Local View",
				"Back",
				"Forward",
				"Left",
				"Right",
			},
			value = "Local View",
			flag = "AntiAimBase",
		})

		AntiAim:AddList({
			text = "Yaw offset",
			values = {
				"180",
				"-180",
				"Custom",
			},
			value = "180",
			flag = "AntiAimOffset",
		})

		AntiAim:AddSlider({
			text = "Custom offset",
			min = -180,
			max = 180,
			increment = 1,
			value = 0,
			flag = "AntiAimCustomOffset",
			suffix = "dg",
		})
	end

	local NetworkSection = Sections.Network
	do
		local SpecToggle, KillToggle = nil

		local PlayerDropdown = NetworkSection:AddList({
			text = "Player list",
			flag = "SelectedPlayer",
			tooltip = "Choose selected player",
			value = LocalPlayer.Name,
			values = function()
				local plrs = {}
				for i, v in next, Players:GetPlayers() do
					if v == LocalPlayer then
						table.insert(plrs, v.Name)
						continue
					end

					table.insert(plrs, v.Name)
				end
				return plrs
			end,
			callback = function(selected)
				if not Network.__Loaded then
					return
				end

				local Settings = Network.PlayerSettings[selected]
				if Settings and KillToggle then
					KillToggle:SetState(Settings.KillPlayer)
				elseif not Settings then
					Network.PlayerSettings[selected] = {
						KillPlayer = false,
					}
					KillToggle:SetState(false)
				end
			end,
		})

		Players.PlayerRemoving:Connect(function(Player)
			if Lib.Flags["SelectedPlayer"] == Player.Name then
				PlayerDropdown:Select(nil)
			end
		end)

		KillToggle = NetworkSection:AddToggle({
			text = "Kill player",
			flag = "KillPlayer",
			tooltip = "Kill chosen player",
			risky = true,
			callback = function(state)
				if Network.__Loaded and Network.PlayerSettings[Lib.Flags["SelectedPlayer"]] then
					Network.PlayerSettings[Lib.Flags["SelectedPlayer"]].KillPlayer = state
				end
			end,
		})
		KillToggle:AddBind({
			text = "Kill player",
			flag = "KillPlayerBind",
			tooltip = "Hold to kill this person",
			mode = "hold",
			bind = "None",
			risky = true,
			state = false,
			nomouse = true,
			noindicator = false,
			callback = function(state)
				KillToggle:SetState(state)
			end,
		})
	end

	local KillSay = Sections.Killsay
	do
		KillSay:AddToggle({
			text = "Master switch",
			flag = "KillSay",
			tooltip = "Chat messages when you kill someone, you can include custom macros into your kill say\n{Gun} - Replaces with what gun you are using\n{Damage} - Replaces with how much damage you did to the player\n{BodyPart} - Replaces with the body part you hit{Player} - Replaces with the player name you hit",
		})

		KillSay:AddList({
			flag = "KillSaySource",
			text = "Selected File",
			tooltip = "Selected source file of the kill say. expects a .txt formatted file, seperate the different sentences with a new line",
			values = function()
				return {
					"File1",
					"File2",
					"File3",
				}
			end,
			value = "Killsay1",
		})
	end

	local World = Sections.World
	do
		World:AddToggle({
			text = "Master switch",
			flag = "WorldEnabled",
			tooltip = "Enable the world features",
		})

		World:AddSeparator({
			text = "Lighting",
		})

		World:AddToggle({
			text = "Change world color",
			flag = "AmbientChanger",
			tooltip = "Change the world color",
		})

		World:AddToggle({
			text = "Time changer",
			flag = "TimeChanger",
			tooltip = "Change the time of day",
		})

		World:AddSlider({
			text = "Time",
			flag = "SpecifiedTime",
			suffix = " hour",
			min = 1,
			max = 24,
			increment = 1,
			tooltip = "Specified Time to change too",
		})
		World:AddSeparator({
			text = "Camera",
		})

		local ThirdPersonToggle = World:AddToggle({
			text = "Third Person",
			flag = "ThirdPerson",
			tooltip = "See yourself in third person????",
		})

		ThirdPersonToggle:AddBind({
			text = "Third Person",
			tooltip = "Press to toggle third person",
			mode = "toggle",
			bind = "None",
			flag = "ThirdPersonBind",
			state = false,
			nomouse = false,
			risky = false,
			noindicator = false,
			callback = function(state)
				ThirdPersonToggle:SetState(state)
			end,
		})

		World:AddSlider({
			text = "Third Person distance",
			flag = "ThirdPersonDistance",
			suffix = " studs",
			min = 2,
			max = 15,
			tooltip = "The distance from your character",
			increment = 1,
			value = 10,
		})

		World:AddToggle({
			text = "Field of view",
			flag = "FOVSlider",
			tooltip = "Changes your camera's field of view",
		})

		World:AddSlider({
			text = "Field of view amount",
			flag = "FOVAmount",
			suffix = " degrees",
			min = 70,
			max = 120,
			increment = 1,
			value = 100,
		})

		World:AddToggle({
			text = "Override zoom",
			flag = "OverrideZoom",
			tooltip = "Ignores FOV Changes done by the zoom system",
		})
	end

	local CombatVis = Sections.CombatVis
	do
		CombatVis:AddToggle({

			text = "Render Legitbot field of view",
			flag = "RenderLegitBot",
			tooltip = "Choose if you want the field of view to show",
		})
		CombatVis:AddToggle({

			text = "Render Silent Aim field of view",
			flag = "RenderSilentAim",
			tooltip = "Choose if you want the field of view to show",
		})

		CombatVis:AddToggle({

			text = "Legitbot target line",
			flag = "LegitBotLine",
			tooltip = "Draws a line to the Legitbot Target",
		})

		CombatVis:AddToggle({

			text = "Silent Aim target line",
			flag = "SilentAimLine",
			tooltip = "Draws a line to the silent aim target",
		})
	end

	local Color = Sections.Colors
	do
		Color:AddColor({

			text = "Box",
			flag = "BoxColor",
			tooltip = "Choose the Box color",
			color = Color3.new(0, 0.67, 1),
			open = false,
			trans = 0,
		})

		Color:AddColor({

			text = "Box fill",
			flag = "BoxFillColor",
			tooltip = "Choose the Fill Box color",
			color = Color3.new(0.368627, 0.368627, 0.368627),
			open = false,
			trans = 0.4,
		})
		Color:AddColor({
			text = "Name",
			flag = "NameColor",
			tooltip = "Choose the Name color",
			color = Color3.new(1, 1, 1),
			open = false,
			trans = 0,
		})
		Color:AddColor({

			text = "Skeleton",
			flag = "SkeletonColor",
			tooltip = "Choose the Skeleton color",
			open = false,
			trans = 0,
		})

		Color:AddColor({

			text = "Health bar",
			flag = "HealthBarColor",
			tooltip = "Choose the Healthbar color",
			color = Color3.new(0.168627, 1, 0),
			open = false,
			trans = 0,
		})

		Color:AddColor({

			text = "Kevlar bar",
			flag = "KevlarbarColor",
			tooltip = "Choose the Kevlar bar color",
			color = Color3.new(0, 0.55, 1),
			open = false,
			trans = 0,
		})

		Color:AddColor({

			text = "Legitbot field of view",
			flag = "LegitBotFOVColor",
			tooltip = "Choose the field of view color",
			open = false,
			trans = 0,
		})

		Color:AddColor({
			text = "Silent Aim field of view",
			flag = "SilentAimFOVColor",
			tooltip = "Choose the field of view color",
			open = false,
			trans = 0,
		})

		Color:AddColor({

			text = "Legitbot target line",
			flag = "LegitBotLineColor",
			tooltip = "Choose the line color",
			open = false,
			trans = 0,
		})

		Color:AddColor({

			text = "Silent Aim target line",
			flag = "SilentAimLineColor",
			tooltip = "Choose the line color",
			open = false,
			trans = 0,
		})

		Color:AddColor({

			text = "World color",
			flag = "AmbientChangerColor",
			tooltip = "Choose the world color",
			open = false,
			trans = 0,
		})

		Color:AddColor({
			text = "Peek assist",
			flag = "PeekAssistCircleColor",
			tooltip = "Choose the peek assist circle color",
			open = false,
			trans = 0,
		})

		Color:AddColor({
			text = "History",
			flag = "HistoryColor",
			tooltip = "Choose the history color",
			open = false,
			trans = 0,
		})
	end

	local ESP = Sections.ESP
	do
		ESP:AddToggle({
			text = "Master switch",
			flag = "ESPEnabled",
			tooltip = "Enable overlays",
		})

		ESP:AddToggle({

			text = "Render team",
			flag = "RenderTeam",
			tooltip = "Enable team overlay",
		})

		ESP:AddToggle({
			text = "Visible only",
			flag = "ESPVisCheck",
			tooltip = "Only render visible people",
		})

		ESP:AddToggle({

			text = "Outline",
			flag = "OutlineEnabled",
			tooltip = "Enable outlines",
		})

		ESP:AddSeparator({
			text = "Overlays",
		})

		ESP:AddToggle({

			text = "Box",
			flag = "BoxEnabled",
			tooltip = "Renders a box over players",
		})

		ESP:AddToggle({

			text = "Fill box",
			flag = "BoxFilled",
			tooltip = "Fills the rendered box",
		})

		ESP:AddToggle({
			text = "Name",
			flag = "NameEnabled",
			tooltip = "Render the player's name",
		})

		ESP:AddToggle({

			text = "Skeleton",
			flag = "SkeletonEnabled",
			tooltip = "Renders lines From one bone of the character To another bone",
		})

		ESP:AddToggle({

			text = "Health bar",
			flag = "HealthbarEnabled",
			tooltip = "Renders a bar representing their health on the player",
		})

		ESP:AddToggle({
			text = "Kevlar bar",
			flag = "KevlarbarEnabled",
			tooltip = "Renders a bar representing their Kevlar (or armor) on the player",
		})

		ESP:AddList({
			text = "Health bar position",
			value = "Left",
			values = {
				"Top",
				"Left",
				"Right",
				"Bottom",
			},
			multi = false,
			tooltip = "Choose where the Health bar is rendered at relative to the player",
			flag = "HealthbarPosition",
		})

		ESP:AddList({
			text = "Kevlar bar position",
			value = "Right",
			values = {
				"Top",
				"Left",
				"Right",
				"Bottom",
			},
			flag = "KevlarbarPosition",
			multi = false,
			tooltip = "Choose where the Kevlar bar is rendeered at relative to the player",
		})
	end

	local ESPOther = Sections.OtherESP
	do
		ESPOther:AddToggle({
			text = "Bullet Tracer",
			flag = "TracerEnabled",
			tooltip = "Creates a beam from your gun to what you hit",
		})

		ESPOther:AddSlider({
			text = "Lifetime",
			flag = "TracerLifetime",
			tooltip = "The length of the bullet tracer",
			min = 1,
			max = 15,
			value = 3,
			increment = 1,
			suffix = " seconds",
		})

		ESPOther:AddList({
			text = "Texture",
			values = {
				"Lazer",
			},
			value = "Lazer",
			flag = "TracerTexture",
			tooltip = "What the tracer will loook like",
		})
	end

	local Hooks = Sections.Hooks
	do
		Hooks:AddToggle({
			text = "Master switch",
			flag = "EventsEnabled",
			tooltip = "Enable the event section",
		})

		Hooks:AddSeparator({
			text = "Hit Notification",
		})

		Hooks:AddToggle({
			text = "Enabled",
			flag = "HitNotifications",
			tooltip = "Get information about who you hit and how much you hit them for.",
		})

		Hooks:AddSlider({
			text = "Notification timer",
			flag = "HitDuration",
			tooltip = "Duration of the hit notification",
			min = 1,
			max = 15,
			increment = 1,
			value = 1,
			suffix = " seconds",
		})

		Hooks:AddSeparator({
			text = "Hit Sound",
		})

		Hooks:AddToggle({
			text = "Enabled",
			flag = "HitSoundEnabled",
			tooltip = "Play sound on hit",
			enabled = true,
		})

		Hooks:AddList({
			text = "Headshot sound",
			value = "Global",
			values = function()
				local Sounds = SoundManager:GetSounds()
				if Sounds and #Sounds > 0 then
					return { "Global", table.unpack(Sounds) }
				else
					return { "Global" }
				end
			end,
			flag = "HeadShotSound",
			multi = false,
			tooltip = "Sound that will play when you shoot somebody in the head, If its global it will fallback to the regular hit sound",
		})
		Hooks:AddList({
			text = "Hit sound",
			flag = "HitSound",
			value = "Skeet",
			values = function()
				local Sounds = SoundManager:GetSounds()
				if Sounds and #Sounds > 0 then
					local FilteredSounds = {}
					for _, sound in next, Sounds do
						if sound ~= "Global" then
							table.insert(FilteredSounds, sound)
						end
					end
					return FilteredSounds
				else
					return { "Skeet" }
				end
			end,
			multi = false,
			tooltip = "Sound that will play on bullet hit",
		})

		Hooks:AddSlider({
			text = "Headshot sound volume",
			flag = "HeadShotSoundVolume",
			tooltip = "Volume of the headshot sound",
			min = 1,
			max = 100,
			suffix = "%",
			value = 85,
			increment = 1,
		})
		Hooks:AddSlider({
			text = "Hit sound volume",
			flag = "HitSoundVolume",
			tooltip = "Volume of the hit sound",
			min = 1,
			max = 100,
			suffix = "%",
			value = 85,
			increment = 1,
		})
	end

	local SkinChangerSection = Sections.SkinChanger
	do
		SkinChangerSection:AddToggle({
			text = "Master switch",
			flag = "SkinChanger",
			tooltip = "Enable skin changer",
		})

		SkinChangerSection:AddToggle({
			text = "Force Skin",
			flag = "ForceSkinChange",
			tooltip = "Skin's every gun you hold regardless of if you bought it or not",
			callback = function(State)
				local SkinChanger = Modules["SkinChanger"]
				if State and SkinChanger and SkinChanger.__Loaded and Internal.MyGun then
					local Gun = Internal.MyGun._Gun.Name
					local Skin = SkinChanger.SelectedSkins[Gun]
					if Skin then
						SkinChanger:SkinChanged(Gun)
					end
				end
			end,
		})

		SkinChangerSection:AddSeparator({
			text = "Primary",
		})

		local PrimarySkinDropdown, SecondarySkinDropdown = nil

		SkinChangerSection:AddList({
			text = "Primary gun",
			flag = "PrimaryGun",
			tooltip = "Select primary weapon to skin",
			values = function()
				return {
					"AK47",
					"M4A4",
					"AWP",
					"Galil",
					"Famas",
					"Scout",
					"SG",
					"AUG",
					"G3SG1",
					"M4A1",
					"MP9",
					"MP7",
					"P90",
					"Bizon",
					"Nova",
					"XM",
					"SawedOff",
					"M249",
					"Negev",
					"MAC10",
					"UMP",
					"MAG7",
					"MP7-SD",
				}
			end,
			callback = function(SelectedPrimary)
				if not PrimarySkinDropdown or not SkinChanger.__Loaded then
					return
				end

				local Skin = SkinChanger.SelectedSkins[SelectedPrimary]
				if Skin then
					PrimarySkinDropdown:Select(Skin)
				else
					PrimarySkinDropdown:Select("Stock")
				end
			end,
			value = "AK47",
			multi = false,
		})

		PrimarySkinDropdown = SkinChangerSection:AddList({
			text = "Primary skin",
			flag = "PrimarySkin",
			tooltip = "Select skin for primary weapon",
			values = function()
				local Skins = SkinChanger:GetSkins(Lib.Flags["PrimaryGun"])
				if Skins and #Skins > 0 then
					return { "Stock", table.unpack(Skins) }
				else
					return { "Stock", "Abyss", "Redline" }
				end
			end,
			callback = function(SelectedSkin)
				if not SkinChanger.__Loaded then
					return
				end
				local SelectedGun = Lib.Flags["PrimaryGun"]
				SkinChanger.SelectedSkins[SelectedGun] = SelectedSkin
				SkinChanger:SkinChanged(SelectedGun)
			end,
			value = "Stock",
			multi = false,
		})

		SkinChangerSection:AddSeparator({
			text = "Secondary",
		})

		SkinChangerSection:AddList({
			text = "Secondary gun",
			flag = "SecondaryGun",
			tooltip = "Select secondary weapon to skin",
			values = function()
				return {
					"Glock",
					"USP",
					"P250",
					"FiveSeven",
					"Tec9",
					"DualBerettas",
					"P2000",
					"R8",
					"DesertEagle",
					"CZ",
				}
			end,
			callback = function(SelectedSecondary)
				if not SecondarySkinDropdown or not SkinChanger.__Loaded then
					return
				end
				local Skin = SkinChanger.SelectedSkins[SelectedSecondary]
				if Skin then
					SecondarySkinDropdown:Select(Skin)
				else
					SecondarySkinDropdown:Select("Stock")
				end
			end,
			value = "Glock",
			multi = false,
		})

		SecondarySkinDropdown = SkinChangerSection:AddList({
			text = "Secondary skin",
			flag = "SecondarySkin",
			tooltip = "Select skin for secondary weapon",
			values = function()
				local Skins = SkinChanger:GetSkins(Lib.Flags["SecondaryGun"])
				if Skins and #Skins > 0 then
					return { "Stock", table.unpack(Skins) }
				else
					return { "Stock", "Water Elemental", "Crimson Web" }
				end
			end,
			callback = function(SelectedSkin)
				if not SkinChanger.__Loaded then
					return
				end
				local SelectedGun = Lib.Flags["SecondaryGun"]
				SkinChanger.SelectedSkins[SelectedGun] = SelectedSkin
				SkinChanger:SkinChanged(SelectedGun)
			end,
			value = "Stock",
			multi = false,
		})

		SkinChangerSection:AddSeparator({
			text = "Melee",
		})

		local VariantDropdown = nil

		SkinChangerSection:AddList({
			text = "Knife model",
			flag = "Knife",
			tooltip = "Select skin to knife - wat",
			values = function()
				local Knives = SkinChanger:GetKnives()
				if Knives and #Knives > 0 then
					return { "Default", table.unpack(Knives) }
				else
					return { "Defualt" }
				end
			end,
			risky = false,
			callback = function(model)
				if VariantDropdown and SkinChanger.KnivesVarianted[model] then
					VariantDropdown:Select(SkinChanger.KnivesVarianted[model])
				elseif VariantDropdown then
					local Variants = SkinChanger:GetKnifeVariants(model)
					local SelectedVariant = model[1]
					if Variants and table.find(Variants, "Stock") then
						SelectedVariant = "Stock"
					elseif not Variants then
						SelectedVariant = "Stock"
					end
					VariantDropdown:Select(SelectedVariant)
				end

				if SkinChanger.__Loaded then
					SkinChanger:UpdateKnife(model, Lib.Flags["KnifeSkin"])
				end
			end,
			value = "Default",
			multi = false,
		})

		VariantDropdown = SkinChangerSection:AddList({
			text = "Knife variant",
			flag = "KnifeSkin",
			tooltip = "Select knife variant for the selected knife model",
			values = function()
				local Skins = SkinChanger:GetSkins(Lib.Flags["Knife"])
				if Skins and #Skins > 0 then
					return Skins
				else
					return { "Stock" }
				end
			end,
			callback = function(variant)
				if SkinChanger.__Loaded then
					SkinChanger:UpdateKnife(Lib.Flags["Knife"], variant)
				end
			end,
			value = "Stock",
			multi = false,
		})

		SkinChangerSection:AddSeparator({
			text = "Glove",
		})

		local GloveVariantDropdown = nil

		SkinChangerSection:AddList({
			text = "Glove model",
			flag = "Glove",
			tooltip = "Select glove model",
			values = function()
				return { "Default", "Sports Glove", "Strapped Glove", "Fingerless Glove", "Handwraps" }
			end,
			callback = function(model)
				if GloveVariantDropdown and SkinChanger.GlovesVarianted[model] then
					GloveVariantDropdown:Select(SkinChanger.GlovesVarianted[model])
				elseif GloveVariantDropdown then
					local Variants = SkinChanger:GetGloveVariants(model)
					local SelectedVariant = "Stock"
					if Variants then
						SelectedVariant = Variants[1]
					end

					GloveVariantDropdown:Select(SelectedVariant)
				end
				if SkinChanger.__Loaded then
					SkinChanger:UpdateGlove(model, Lib.Flags["GloveSkin"])
				end
			end,
			value = "Default",
			multi = false,
		})

		GloveVariantDropdown = SkinChangerSection:AddList({
			text = "Glove skin",
			flag = "GloveSkin",
			tooltip = "Select skin for glove",
			values = function()
				local Skins = SkinChanger:GetGloveVariants(Lib.Flags["Glove"])
				if Skins and #Skins > 0 then
					return Skins
				else
					return { "Stock" }
				end
			end,
			callback = function(variant)
				if SkinChanger.__Loaded then
					SkinChanger:UpdateGlove(Lib.Flags["Glove"], variant)
				end
			end,
			value = "Stock",
			multi = false,
		})
	end

	local Legitbot = Sections.Legitbot
	do
		Legitbot:AddToggle({
			text = "Master switch",
			flag = "Legitbot",
			tooltip = "Moves your camera (or mouse) to a target",
		})

		Legitbot:AddToggle({
			text = "Occlusion check",
			flag = "LegitbotVisCheck",
			tooltip = "Will not activate legitbot magnetization if the target is not visible",
		})

		Legitbot:AddToggle({
			text = "Dynamic FOV",
			flag = "DynamicLegitFOV",
			tooltip = "Scales your field of view circle with your camera's field of view.",
		})

		Legitbot:AddSeparator({
			text = "Settings",
		})

		Legitbot:AddList({
			text = "Legitbot mode",
			flag = "LegitbotMode",
			multi = false,
			tooltip = "Select Legitbot mode\n- Normal mode Magnetizes your crosshair while your shooting\n- Spray mode waits for you to spray a specified amount of bullets before enabling the assistance",
			value = "Normal",
			values = {
				"Normal",
				"Spray",
			},
		})

		Legitbot:AddList({
			text = "Scan origin",
			flag = "LegitbotOrigin",
			multi = false,
			tooltip = "Select Legitbot origin\n- Center will be at the center of your screen\n- Mouse will be your mouse location",
			values = {
				"Center",
				"Mouse",
			},
			value = "Center",
		})

		Legitbot:AddList({
			text = "Aim bone",
			flag = "LegitBotBone",
			multi = true,
			value = "UpperTorso",
			tooltip = "Select Legitbot aim bone",
			values = {
				"Head",
				"UpperTorso",
				"LowerTorso",
				"LeftUpperArm",
				"RightUpperArm",
				"LeftLowerArm",
				"RightLowerArm",
				"LeftUpperLeg",
				"RightUpperLeg",
				"LeftLowerleg",
				"RightLowerLeg",
			},
		})

		Legitbot:AddSlider({
			text = "Switch delay",
			flag = "LegitSwitchDelay",
			increment = 1,
			value = 50,
			max = 1000,
			min = 0,
			tooltip = "Amount of time passed before the Legitbot will switch targets upon a new target being registered",
			suffix = "ms",
		})

		Legitbot:AddSlider({
			text = "Reaction time",
			increment = 1,
			value = 50,
			max = 1000,
			min = 0,
			tooltip = "Amount of time passed before the Legitbot will recognize the player in your crosshair",
			suffix = "ms",
			flag = "LegitbotReactionTime",
		})

		Legitbot:AddSlider({
			text = "Smoothing",
			flag = "LegitbotSmoothing",
			suffix = "%",
			min = 0,
			max = 100,
			tooltip = "Legitbot smoothness\n- 0 blatant\n- 100 smooth as butter",
			increment = 1,
			value = 85,
		})

		Legitbot:AddSlider({
			text = "Spray threshold",
			flag = "SprayThreshold",
			suffix = " shots",
			min = 1,
			max = 30,
			tooltip = "How many shots before the legitbot activates",
			increment = 1,
			value = 2,
		})

		Legitbot:AddSlider({
			text = "Field Of View",
			flag = "LegitBotFOV",
			suffix = " pixels",
			value = 180,
			min = 1,
			max = 700,
			increment = 2,
			tooltip = "Determines how much of your screen the Legitbot will scan targets for",
		})
	end

	local SilentAim = Sections.SilentAim
	do
		SilentAim:AddToggle({
			text = "Master switch",
			flag = "SilentAim",
			tooltip = 'Looks at the player without "silently"',
			risky = false,
		})

		SilentAim:AddToggle({
			text = "Occlusion check",
			flag = "SilentAimVisCheck",
			tooltip = "Will not activate Silent Aim if the target is not visible",
		})

		SilentAim:AddToggle({
			text = "Dynamic FOV",
			flag = "DynamicSilentFOV",
			tooltip = "Scales your field of view circle with your camera's field of view.",
		})

		SilentAim:AddSeparator({
			text = "Settings",
		})

		SilentAim:AddList({
			text = "Silent Aim mode",
			flag = "SilentAimMode",
			multi = false,
			tooltip = "Select Silent Aim mode\n- Normal mode will not ignore spread & recoil\n- pSilent ignores spread & recoil completley.",
			value = "Normal",
			values = {
				"Normal",
				"pSilent",
			},
		})

		SilentAim:AddList({
			text = "Scan origin",
			flag = "SilentAimOrigin",
			value = "Center",
			values = {
				"Center",
				"Mouse",
			},
			multi = false,
			tooltip = "Select Silent Aim origin\n- Center will be at the center of your screen\n- Mouse will be your mouse location",
		})

		SilentAim:AddList({
			text = "Aim bone",
			flag = "SilentAimBone",
			multi = true,
			tooltip = "Select Silent Aim bone",
			value = "UpperTorso",
			values = {
				"Head",
				"UpperTorso",
				"LowerTorso",
				"LeftUpperArm",
				"RightUpperArm",
				"LeftLowerArm",
				"RightLowerArm",
				"LeftUpperLeg",
				"RightUpperLeg",
				"LeftLowerleg",
				"RightLowerLeg",
			},
		})

		SilentAim:AddSlider({
			text = "Switch delay",
			flag = "SilentSwitchDelay",
			increment = 1,
			max = 1000,
			min = 0,
			tooltip = "Amount of time passed before the Silent Aim will switch targets upon a new target being registered",
			suffix = "ms",
			value = 50,
		})

		SilentAim:AddSlider({
			text = "Reaction time",
			increment = 1,
			max = 1000,
			min = 0,
			tooltip = "Amount of time passed before the silent aim will recognize the player in your crosshair",
			suffix = "ms",
			flag = "SilentReactionTime",
			value = 50,
		})

		SilentAim:AddSlider({
			text = "Hit chance",
			flag = "SilentAimHitChance",
			suffix = "%",
			value = 100,
			min = 0,
			max = 100,
			increment = 1,
			tooltip = "The chance (x/100) of the Silent Aim activating on shot",
		})

		SilentAim:AddSlider({
			text = "Field Of View",
			flag = "SilentAimFOV",
			suffix = " pixels",
			value = 180,
			min = 1,
			max = 700,
			increment = 2,
			tooltip = "Determines how much of your screen the Silent Aim will scan targets for",
		})
	end
	if _UpdatedLibrary then
		library:SendNotification("Updated library to newest version", 5)
		print("Updated menu data")
	end
	library:SendNotification("Menu loaded", 5)
end

print("[melancholy] welcome to melancholy!")
