/*
    STREETS OF NIGHT CITY V15.7.5
    2026 BY SLIM420
	LEGAL NOTICE & DISCLAIMER
Streets of Night City and all associated mods and files created by Slim420 are unofficial fan-made modifications for Cyberpunk 2077. They are not affiliated with, endorsed by, sponsored by, or in any way officially connected to CD PROJEKT RED, CD PROJEKT S.A., or any of their subsidiaries or affiliates. Cyberpunk 2077 and all related names, logos, and properties are trademarks of CD PROJEKT RED. All rights to the base game and its assets remain with their respective owners.
These mods are provided free of charge, as-is, with no warranty of any kind, expressed or implied. By downloading, installing, or using these mods, you acknowledge and agree that the creator (Slim420) bears no responsibility or liability for any damage - including but not limited to corruption of save files, game instability, software conflicts, data loss, or any other adverse effects - that may result from their use. Installation and use is entirely at your own risk.
These mods are not intended for commercial use and must not be sold, redistributed for profit, or repackaged without explicit written permission from the creator.

*/
import Codeware.UI.*
import RedscriptConfigFramework.*
public class StreetsOfNightCity_InitCheckRequest extends ScriptableSystemRequest {}
public class StreetsOfNightCity_ManageRequest extends ScriptableSystemRequest {}
public class StreetsOfNightCity_CleanupRequest extends ScriptableSystemRequest {}
public class StreetsOfNightCity_AmbientSpawnCheckRequest extends ScriptableSystemRequest {}
public class StreetsOfNightCity_ImmersiveSpawnCheckRequest extends ScriptableSystemRequest {}
public class StreetsOfNightCity_SpawnQueueRequest extends ScriptableSystemRequest {}
public class StreetsOfNightCity_AttitudeWatchdogRequest extends ScriptableSystemRequest {}
public class StreetsOfNightCity_System extends ScriptableSystem {
    private let settings: ref<StreetsOfNightCity_Settings>;
    private let m_wasImmersiveEnabled: Bool;
    private let factionRegistry: array<ref<SONC_FactionProfile>>;
    private let activePatrols: array<ref<SONC_PatrolSquad>>;
    private let cachedDistrictName: String;
    private let cachedIsHilly: Bool;
    private let lastDistrictCheck: Float;
    private let isInitialized: Bool;
    private let m_nextSquadID: Int32;
    private let m_validationToken: Float;
    private let m_factionDistrictCache: array<ref<SONC_FactionCacheEntry>>;
    private let m_districtNormalizationMap: array<ref<SONC_DistrictMapping>>;
    private let m_validSpawnCache: array<ref<SONC_CachedSpawnPoint>>;
    private let m_specPool: array<ref<DynamicEntitySpec>>;
    private let m_lastSpawnDuration: Float = 0.0;
    private let m_performanceMode: Bool = false;
    private let WATER_LEVEL: Float = 18.3;
    // Internal squad-lifecycle tuning. Not user settings on purpose - these
    // govern streaming and cleanup, not gameplay feel.
    private let MISSING_MEMBER_KEEP_DIST: Float = 40.0;   // hold a streamed-out ID only inside this range
    private let MISSING_MEMBER_KEEP_SEC: Float  = 30.0;   // ...and only this long after spawn
    private let EMPTY_SQUAD_GRACE_SEC: Float    = 8.0;    // wait before dropping an empty patrol
    private let EMPTY_CONFLICT_GRACE_SEC: Float = 15.0;   // conflicts get longer, they spawn in waves
    private let DESPAWN_CAM_CHECK_DIST: Float   = 150.0;  // only camera-test despawns this close
    private let m_patrolDaemons: array<ref<StreetsOfNightCity_PatrolDaemon>>;
    private let m_spawnQueue: array<ref<SONC_QueuedSpawn>>;
    private let m_nextSpawnTime: Float;
    private let m_lastSpawnedSquadID: Int32;
    private let m_cachedAmbHuman: Int32;
    private let m_cachedAmbDrone: Int32;
    private let m_cachedImmHuman: Int32;
    private let m_cachedImmDrone: Int32;
    private let m_reinforcedSquadIDs: array<Int32>;
    private let m_playerAggressedEntities: array<EntityID>;
    private let m_recentRoadDespawns: array<ref<SONC_RoadDespawnRecord>>;
    private let m_stuckDriveNodes: array<Vector4>;
    private let arasakaMechs: array<TweakDBID>;
    private let arasakaDrones: array<TweakDBID>;
    private let militechMechs: array<TweakDBID>;
    private let militechDrones: array<TweakDBID>;
    private let kangTaoMechs: array<TweakDBID>;
    private let kangTaoDrones: array<TweakDBID>;
    private let securityMechs: array<TweakDBID>;
    private let securityDrones: array<TweakDBID>;
    private let barghestMechs: array<TweakDBID>;
    private let barghestDrones: array<TweakDBID>;
    private let maelstromMechs: array<TweakDBID>;
    private let maelstromDrones: array<TweakDBID>;
    private let voodooBoysDrones: array<TweakDBID>;
    private let wraithDrones: array<TweakDBID>;
    private let sixthStreetMechs: array<TweakDBID>;
    private func PassesSpawnSafetyChecks(opt spawnPos: Vector4) -> Bool {
        let gi = this.GetGameInstance();
        let player = GetPlayer(gi);
        if !IsDefined(player) { return false; }
        let preventionSys = GameInstance.GetScriptableSystemsContainer(gi).Get(n"PreventionSystem") as PreventionSystem;
        if IsDefined(preventionSys) && preventionSys.IsPlayerInQuestArea() {
            if this.settings.debugLogging { StreetsOfNightCity_Logger.Log("Safety check failed: Player in quest area"); }
            return false;
        }
        if SONC_IsPlayerNearQuestMappin(10.0) {
            if this.settings.debugLogging { StreetsOfNightCity_Logger.Log("Safety check failed: Player near quest mappin"); }
            return false;
        }
        let sonc_bbSys  = GameInstance.GetBlackboardSystem(gi);
        let sonc_psmBB  = IsDefined(sonc_bbSys) ? sonc_bbSys.Get(GetAllBlackboardDefs().PlayerStateMachine) : null;
        if IsDefined(sonc_psmBB) && sonc_psmBB.GetInt(GetAllBlackboardDefs().PlayerStateMachine.SceneTier) > 1 {
            if this.settings.debugLogging { StreetsOfNightCity_Logger.Log("Safety check failed: Player in Braindance"); }
            return false;
        }
        if StatusEffectSystem.ObjectHasStatusEffectWithTag(player, n"NoCombat") {
            if this.settings.debugLogging { StreetsOfNightCity_Logger.Log("Safety check failed: Player has NoCombat tag"); }
            return false;
        }
        if StatusEffectSystem.ObjectHasStatusEffectWithTag(player, n"VehicleScene") {
            if this.settings.debugLogging { StreetsOfNightCity_Logger.Log("Safety check failed: Player in VehicleScene"); }
            return false;
        }
        let hasPosToCheck = spawnPos.X != 0.0 || spawnPos.Y != 0.0;
        if hasPosToCheck && !this.settings.allowSpawnsInRestrictedZones {
            let restrictedTypes: array<ESecurityAreaType>;
            ArrayPush(restrictedTypes, ESecurityAreaType.DISABLED);
            ArrayPush(restrictedTypes, ESecurityAreaType.DANGEROUS);
            if SONC_IsPointInAnyLoadedSecurityAreaRadius(spawnPos, restrictedTypes, true) {
                if this.settings.debugLogging { StreetsOfNightCity_Logger.Log("Safety check failed: Position in restricted security zone"); }
                return false;
            }
        }
        return true;
    }
    private func ShowNotification(title: String, message: String, isWarning: Bool) -> Void {
        let gi = this.GetGameInstance();
        let player = GetPlayer(gi);
        if !IsDefined(player) { return; }
        if isWarning { GameInstance.GetAudioSystem(gi).Play(n"ui_warning"); }
        else         { GameInstance.GetAudioSystem(gi).Play(n"ui_notification"); }
        // Previously this only played a sound and wrote a log line, so the
        // player never actually saw the text. Push it to the onscreen board.
        let notifyBB = GameInstance.GetBlackboardSystem(gi).Get(GetAllBlackboardDefs().UI_Notifications);
        if IsDefined(notifyBB) {
            let screenMsg: SimpleScreenMessage;
            screenMsg.isShown = true;
            screenMsg.duration = 6.0;
            screenMsg.message = title + " - " + message;
            notifyBB.SetVariant(GetAllBlackboardDefs().UI_Notifications.OnscreenMessage, ToVariant(screenMsg), true);
        }
        StreetsOfNightCity_Logger.Log("[" + title + "] " + message);
    }
    private func ShowWarning(title: String, message: String) -> Void {
        this.ShowNotification(title, message, true);
    }
    private func ShowCleanupNotification(cleanedCount: Int32) -> Void {
        this.ShowWarning(
            "Streets of Night City - Save Cleaned",
            "Removed " + ToString(cleanedCount) + " persistent entities. Please create a NEW SAVE now to make this fix permanent."
        );
    }
    public static func Get(gi: GameInstance) -> ref<StreetsOfNightCity_System> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"StreetsOfNightCity_System") as StreetsOfNightCity_System;
    }
    public func GetSettings() -> ref<StreetsOfNightCity_Settings> { return this.settings; }
    public func GetFactionProfilePublic(name: CName) -> ref<SONC_FactionProfile> { return this.GetFactionProfileByName(name); }
    public func IsStillValid() -> Bool { return this.isInitialized && this.m_validationToken > 0.0; }
    public func GetActivePatrols() -> array<ref<SONC_PatrolSquad>> { return this.activePatrols; }
    public func GetSpawnQueue() -> array<ref<SONC_QueuedSpawn>> { return this.m_spawnQueue; }
    private func OnAttach() -> Void {
        this.settings = new StreetsOfNightCity_Settings();
        let sonc_gi: GameInstance = this.GetGameInstance();
        let sonc_settingsProvider: ref<StreetsOfNightCity_SettingsProvider> = new StreetsOfNightCity_SettingsProvider();
        sonc_settingsProvider.Init(this.settings, this);
        DVRCF.Register(sonc_gi, "StreetsOfNightCity", "Streets Of Night City", "Ambient civilians, faction patrols, and conflict simulation.", sonc_settingsProvider);
        this.settings.InitializeWithGameInstance(sonc_gi);
        this.m_wasImmersiveEnabled = this.settings.enableImmersive;
        this.InitializeDistrictMap();
        this.LoadDatabase();
        this.activePatrols = [];
        this.m_factionDistrictCache = [];
        this.m_validSpawnCache = [];
        this.m_specPool = [];
        this.m_patrolDaemons = [];
        this.m_spawnQueue = [];
        this.m_nextSpawnTime = 0.0;
        this.m_lastSpawnedSquadID = -1;
        this.m_cachedAmbHuman = 0;
        this.m_cachedAmbDrone = 0;
        this.m_cachedImmHuman = 0;
        this.m_cachedImmDrone = 0;
        this.isInitialized = false;
        this.m_validationToken = 0.0;
        this.m_nextSquadID = 1;
        GameInstance.GetDelaySystem(this.GetGameInstance()).DelayScriptableSystemRequest(n"StreetsOfNightCity_System", new StreetsOfNightCity_CleanupRequest(), 2.0);
        StreetsOfNightCity_Logger.Log(s"System attached. Scheduling save file cleanup...");
    }
    protected cb func OnCleanupRequest(request: ref<StreetsOfNightCity_CleanupRequest>) -> Void {
        this.EmergencyCleanupAllEntities(true);
        GameInstance.GetDelaySystem(this.GetGameInstance()).DelayScriptableSystemRequest(n"StreetsOfNightCity_System", new StreetsOfNightCity_InitCheckRequest(), 1.0);
    }
    private func LoadDatabase() -> Void {
        this.factionRegistry = SONC_DataFactory.GetFactionRegistry();
        let db = SONC_DataFactory.GetMechDatabase();
        this.arasakaMechs = db.arasakaMechs;
        this.arasakaDrones = db.arasakaDrones;
        this.militechMechs = db.militechMechs;
        this.militechDrones = db.militechDrones;
        this.kangTaoMechs = db.kangTaoMechs;
        this.kangTaoDrones = db.kangTaoDrones;
        this.securityMechs = db.securityMechs;
        this.securityDrones = db.securityDrones;
        this.barghestMechs = db.barghestMechs;
        this.barghestDrones = db.barghestDrones;
        this.maelstromMechs = db.maelstromMechs;
        this.maelstromDrones = db.maelstromDrones;
        this.voodooBoysDrones = db.voodooBoysDrones;
        this.wraithDrones = db.wraithDrones;
        this.sixthStreetMechs = db.sixthStreetMechs;
    }
    private func OnDetach() -> Void {
        this.EmergencyCleanupAllEntities();
        this.ClearAllPatrols();
        this.m_patrolDaemons = [];
        this.isInitialized = false;
        this.m_validationToken = 0.0;
        StreetsOfNightCity_Logger.Log("System detached - cleanup complete");
    }
    private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void {
        this.activePatrols = [];
        this.isInitialized = false;
        this.settings = new StreetsOfNightCity_Settings();
        let sonc_gi: GameInstance = this.GetGameInstance();
        let sonc_settingsProvider: ref<StreetsOfNightCity_SettingsProvider> = new StreetsOfNightCity_SettingsProvider();
        sonc_settingsProvider.Init(this.settings, this);
        DVRCF.Register(sonc_gi, "StreetsOfNightCity", "Streets Of Night City", "Ambient civilians, faction patrols, and conflict simulation.", sonc_settingsProvider);
        this.settings.InitializeWithGameInstance(sonc_gi);
        this.m_wasImmersiveEnabled = this.settings.enableImmersive;
        this.InitializeDistrictMap();
        this.LoadDatabase();
        this.m_factionDistrictCache = [];
        this.m_validSpawnCache = [];
        this.m_specPool = [];
        this.m_patrolDaemons = [];
        this.m_spawnQueue = [];
        this.m_nextSpawnTime = 0.0;
        this.m_lastSpawnedSquadID = -1;
        this.cachedDistrictName = "";
        this.cachedIsHilly = false;
        this.lastDistrictCheck = 0.0;
        this.m_validationToken = 0.0;
        this.m_nextSquadID = 1;
        this.m_lastSpawnDuration = 0.0;
        this.m_performanceMode = false;
        this.m_cachedAmbHuman = 0;
        this.m_cachedAmbDrone = 0;
        this.m_cachedImmHuman = 0;
        this.m_cachedImmDrone = 0;
        GameInstance.GetDelaySystem(this.GetGameInstance()).DelayScriptableSystemRequest(n"StreetsOfNightCity_System", new StreetsOfNightCity_CleanupRequest(), 2.0);
        StreetsOfNightCity_Logger.Log("System restored from save. Scheduling save file cleanup...");
    }
    // announce=true only on the LOAD path. On detach the player is already
    // leaving, and what we delete there is our own live patrols, not save
    // leftovers - telling them to make a new save would be wrong.
    private func EmergencyCleanupAllEntities(opt announce: Bool) -> Void {
        let gi = this.GetGameInstance();
        let des = GameInstance.GetDynamicEntitySystem();
        if !IsDefined(des) { return; }
        let cleanedCount = 0;
        let entitiesToClean = des.GetTaggedIDs(n"SONC_NPC");
        let vehicleEntities = des.GetTaggedIDs(n"SONC_Vehicle");
        for entID in vehicleEntities {
            ArrayPush(entitiesToClean, entID);
        }
        for entID in entitiesToClean {
            if des.DeleteEntity(entID) {
                cleanedCount += 1;
            }
        }
        if cleanedCount > 0 {
            StreetsOfNightCity_Logger.Log("EMERGENCY CLEANUP: Removed " + ToString(cleanedCount) + " persistent entities.");
            if announce { this.ShowCleanupNotification(cleanedCount); }
        } else {
            StreetsOfNightCity_Logger.Log("Save file is clean. No persistent entities found.");
        }
    }
    protected cb func OnInitializationCheckRequest(request: ref<StreetsOfNightCity_InitCheckRequest>) -> Void {
        if this.isInitialized { return; }
        if this.CheckWorldReady() {
            StreetsOfNightCity_Logger.Log("Systems ready. Initializing loops.");
            this.OnPlayerReady();
        } else {
            GameInstance.GetDelaySystem(this.GetGameInstance()).DelayScriptableSystemRequest(n"StreetsOfNightCity_System", new StreetsOfNightCity_InitCheckRequest(), 1.0);
        }
    }
    public func OnPlayerReady() -> Void {
        if this.isInitialized { return; }
        this.isInitialized = true;
        this.m_validationToken = EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
        this.ScheduleImmersiveSpawnCheck();
        this.ScheduleAmbientSpawnCheck();
        this.ScheduleManageCheck(this.settings.manageCheckInterval);
        this.ScheduleSpawnQueueProcess(0.1);
        this.ScheduleAttitudeWatchdog();
        GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(new SONC_VoodooPlayerVehicleHackCallback(), 6.0);
        this.SanitizeStuckPlayerStatusEffects();
    }
    // V15.7.5 - BaseStatusEffect.Crippled is the parent record for the limb
    // crippling family. It is savable and nothing in the game clears it, so a
    // pre-15.7.5 Executioner hit could leave it stuck on the player forever,
    // which zeroes HasSandevistan. Strip it once on load so existing saves heal.
    private func SanitizeStuckPlayerStatusEffects() -> Void {
        let gi = this.GetGameInstance();
        let player = GetPlayer(gi);
        if !IsDefined(player) { return; }
        let statusSys = GameInstance.GetStatusEffectSystem(gi);
        if !IsDefined(statusSys) { return; }
        let playerID = player.GetEntityID();
        statusSys.RemoveStatusEffect(playerID, t"BaseStatusEffect.Crippled");
        StreetsOfNightCity_Logger.Log("[CLEANUP] Cleared BaseStatusEffect.Crippled from player (no-op if absent).");
    }
    public func ReloadSettings() -> Void {
        if this.m_wasImmersiveEnabled && !this.settings.enableImmersive {
            this.CleanupActiveConflicts();
            StreetsOfNightCity_Logger.Log("Immersive mode disabled - cleaning up.");
        }
        this.m_wasImmersiveEnabled = this.settings.enableImmersive;
    }
    private func CleanupActiveConflicts() -> Void {
        let gi = this.GetGameInstance();
        let i = ArraySize(this.activePatrols) - 1;
        while i >= 0 {
            let squad = this.activePatrols[i];
            if IsDefined(squad) && !squad.isAmbient && this.IsSquadInCombat(squad) {
                this.DespawnSquad(squad);
                ArrayErase(this.activePatrols, i);
            }
            i -= 1;
        }
    }
    private func ScheduleAmbientSpawnCheck() -> Void {
        if this.settings.enableAmbient {
            GameInstance.GetDelaySystem(this.GetGameInstance()).DelayScriptableSystemRequest(n"StreetsOfNightCity_System", new StreetsOfNightCity_AmbientSpawnCheckRequest(), this.settings.ambientSpawnInterval);
        }
    }
    protected cb func OnAmbientSpawnCheckRequest(request: ref<StreetsOfNightCity_AmbientSpawnCheckRequest>) -> Void {
        if this.settings.enableAmbient && this.ShouldSpawnAmbientGroup() { this.TrySpawnAmbientGroup(); }
        this.ScheduleAmbientSpawnCheck();
    }
    private func ScheduleImmersiveSpawnCheck() -> Void {
        if this.settings.enableImmersive {
            let player = GetPlayer(this.GetGameInstance());
            let actualDelay: Float;
            if IsDefined(player) {
                let districtName = this.GetPlayerDistrictName(player);
                if this.IsRuralArea(districtName) {
                    actualDelay = this.settings.badlandsSpawnInterval;
                } else {
                    actualDelay = this.settings.immersiveCitySpawnInterval;
                }
            } else {
                actualDelay = this.settings.immersiveCitySpawnInterval;
            }
            if this.m_lastSpawnDuration > 0.05 { this.m_performanceMode = true; }
            if this.m_lastSpawnDuration < 0.03 { this.m_performanceMode = false; }
            let baseDelay = actualDelay;
            if this.m_performanceMode {
                baseDelay *= 1.5;
                if this.m_lastSpawnDuration > 0.1 { baseDelay *= 1.5; }
                if ArraySize(this.activePatrols) > 20 { baseDelay *= 1.5; }
            }
            GameInstance.GetDelaySystem(this.GetGameInstance()).DelayScriptableSystemRequest(n"StreetsOfNightCity_System", new StreetsOfNightCity_ImmersiveSpawnCheckRequest(), baseDelay);
        }
    }
    protected cb func OnImmersiveSpawnCheckRequest(request: ref<StreetsOfNightCity_ImmersiveSpawnCheckRequest>) -> Void {
        let startTime = EngineTime.ToFloat(GameInstance.GetEngineTime(this.GetGameInstance()));
        let player = GetPlayer(this.GetGameInstance());
        if IsDefined(player) {
            if this.settings.enableImmersive && this.ShouldSpawnImmersiveGroup() { this.TrySpawnImmersiveGroup(); }
        }
        let endTime = EngineTime.ToFloat(GameInstance.GetEngineTime(this.GetGameInstance()));
        this.m_lastSpawnDuration = endTime - startTime;
        this.ScheduleImmersiveSpawnCheck();
    }
    protected cb func OnPatrolManageRequest(request: ref<StreetsOfNightCity_ManageRequest>) -> Void {
        this.ManageActiveGroups();
        this.PruneAggressionRegistry();
        let combatReg = SONC_CombatObjectRegistry.GetInstance(this.GetGameInstance());
        if IsDefined(combatReg) { combatReg.CompactAll(); }
        let envReg = SONC_EnvRegistry.GetInstance(this.GetGameInstance());
        if IsDefined(envReg) { envReg.CompactAll(); }
        this.ScheduleManageCheck(this.settings.manageCheckInterval);
    }
    private func ScheduleManageCheck(delay: Float) -> Void {
        GameInstance.GetDelaySystem(this.GetGameInstance()).DelayScriptableSystemRequest(n"StreetsOfNightCity_System", new StreetsOfNightCity_ManageRequest(), delay);
    }
    public func RegisterPlayerAggression(entityID: EntityID) -> Void {
        if !ArrayContains(this.m_playerAggressedEntities, entityID) {
            ArrayPush(this.m_playerAggressedEntities, entityID);
        }
    }
    public func UnregisterPlayerAggression(entityID: EntityID) -> Void {
        ArrayRemove(this.m_playerAggressedEntities, entityID);
    }
    private func PruneAggressionRegistry() -> Void {
        let gi = this.GetGameInstance();
        let i = ArraySize(this.m_playerAggressedEntities) - 1;
        while i >= 0 {
            let aggEnt = GameInstance.FindEntityByID(gi, this.m_playerAggressedEntities[i]) as ScriptedPuppet;
            let stale = true;
            if IsDefined(aggEnt) {
                if !aggEnt.IsDead() { stale = false; }
            }
            if stale { ArrayErase(this.m_playerAggressedEntities, i); }
            i -= 1;
        }
    }
    public func WasAggressedByPlayer(entityID: EntityID) -> Bool {
        return ArrayContains(this.m_playerAggressedEntities, entityID);
    }
    public func HasAnyPlayerAggression() -> Bool {
        return ArraySize(this.m_playerAggressedEntities) > 0;
    }
    public func IsSONCManagedEntity(entityID: EntityID) -> Bool {
        for squad in this.activePatrols {
            if IsDefined(squad) {
                if ArrayContains(squad.squadEntityIDs, entityID) { return true; }
            }
        }
        return false;
    }
    public func RecordRoadDespawn(position: Vector4) -> Void {
        let now = EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
        let i = ArraySize(this.m_recentRoadDespawns) - 1;
        while i >= 0 {
            let stale = now - this.m_recentRoadDespawns[i].time > 20.0;
            if stale { ArrayErase(this.m_recentRoadDespawns, i); }
            i -= 1;
        }
        let record = new SONC_RoadDespawnRecord();
        record.position = position;
        record.time = now;
        ArrayPush(this.m_recentRoadDespawns, record);
    }
    public func IsNearRecentRoadDespawn(position: Vector4, radius: Float) -> Bool {
        let now = EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
        for record in this.m_recentRoadDespawns {
            let fresh = now - record.time <= 20.0;
            let close = Vector4.Distance2D(position, record.position) <= radius;
            if fresh && close { return true; }
        }
        return false;
    }
    public func HasActiveConflictNear(position: Vector4, radius: Float) -> Bool {
        for squad in this.activePatrols {
            if IsDefined(squad) && squad.isConflict {
                let dist = Vector4.Distance(squad.lastKnownPosition, position);
                if dist <= radius { return true; }
            }
        }
        return false;
    }
    private func ScheduleAttitudeWatchdog() -> Void {
        GameInstance.GetDelaySystem(this.GetGameInstance()).DelayScriptableSystemRequest(n"StreetsOfNightCity_System", new StreetsOfNightCity_AttitudeWatchdogRequest(), 2.0);
    }
    protected cb func OnAttitudeWatchdogRequest(request: ref<StreetsOfNightCity_AttitudeWatchdogRequest>) -> Void {
        this.ReassertNeutralAttitudes();
        this.DeAggroAmbientSquads();
        this.ApplyProximityHostility();
        this.ScheduleAttitudeWatchdog();
    }
    private func ReassertNeutralAttitudes() -> Void {
        let gi = this.GetGameInstance();
        let player = GetPlayer(gi);
        if !IsDefined(player) { return; }
        let playerAtt = player.GetAttitudeAgent();
        if !IsDefined(playerAtt) { return; }
        for squad in this.activePatrols {
            if IsDefined(squad) {
                let isWraithHostile = Equals(squad.factionName, n"Wraiths") && this.settings.immersiveWraithsAlwaysHostile && !squad.isConflict;
                if !isWraithHostile {
                    for memberID in squad.squadEntityIDs {
                        let member = GameInstance.FindEntityByID(gi, memberID) as ScriptedPuppet;
                        if IsDefined(member) && !member.IsDead() {
                            let memberAtt = member.GetAttitudeAgent();
                            if IsDefined(memberAtt) {
                                let currentAttitude = memberAtt.GetAttitudeTowards(playerAtt);
                                // With globalAlwaysNeutral OFF a squad is ALLOWED to stay hostile,
                                // but only if its faction is meant to be and it is inside the
                                // hostility radius. Everything else gets cleaned up.
                                let allowedHostile = false;
                                if !this.settings.globalAlwaysNeutral {
                                    let wants = squad.wantsPlayerHostile;
                                    let near  = this.IsWithinPlayerHostilityRange(member.GetWorldPosition());
                                    allowedHostile = wants && near;
                                }
                                if Equals(currentAttitude, EAIAttitude.AIA_Hostile) && !allowedHostile {
                                    let tracker = member.GetTargetTrackerComponent();
                                    let playerIsLiveThreat = false;
                                    if IsDefined(tracker) {
                                        for t in tracker.GetHostileThreats(false) {
                                            let entAsPlayer = t.entity as PlayerPuppet;
                                            if IsDefined(entAsPlayer) { playerIsLiveThreat = true; }
                                        }
                                    }
                                    if !playerIsLiveThreat {
                                        memberAtt.SetAttitudeTowards(playerAtt, EAIAttitude.AIA_Neutral);
                                        if !squad.isConflict {
                                            if IsDefined(tracker) { tracker.ClearThreats(); }
                                        }
                                        StreetsOfNightCity_Logger.LogVerbose(s"[WATCHDOG] \(member.GetDisplayName()) (faction \(ToString(squad.factionName)), isConflict=\(ToString(squad.isConflict))) was Hostile with no live player threat -> reset to Neutral.", this.settings);
                                    } else {
                                        if squad.isConflict && !this.WasAggressedByPlayer(memberID) {
                                            memberAtt.SetAttitudeTowards(playerAtt, EAIAttitude.AIA_Neutral);
                                            TargetTrackingExtension.RemoveThreat(member, player);
                                            StreetsOfNightCity_Logger.LogVerbose(s"[WATCHDOG] \(member.GetDisplayName()) (faction \(ToString(squad.factionName)), isConflict=true) Hostile+player-tracked but player has NOT aggressed -> strip player threat.", this.settings);
                                        } else {
                                            StreetsOfNightCity_Logger.LogVerbose(s"[WATCHDOG] \(member.GetDisplayName()) (faction \(ToString(squad.factionName)), isConflict=\(ToString(squad.isConflict))) is Hostile AND player is a live tracked threat -> left alone (real ongoing engagement).", this.settings);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    private func ApplyProximityHostility() -> Void {
        if this.settings.globalAlwaysNeutral { return; }
        let gi = this.GetGameInstance();
        let player = GetPlayer(gi);
        if !IsDefined(player) { return; }
        let playerAtt = player.GetAttitudeAgent();
        if !IsDefined(playerAtt) { return; }
        for squad in this.activePatrols {
            if IsDefined(squad) && squad.wantsPlayerHostile && !squad.isConflict && !squad.isAmbient {
                for memberID in squad.squadEntityIDs {
                    let member = GameInstance.FindEntityByID(gi, memberID) as ScriptedPuppet;
                    if IsDefined(member) && !member.IsDead() {
                        let inRange = this.IsWithinPlayerHostilityRange(member.GetWorldPosition());
                        if inRange {
                            let memberAtt = member.GetAttitudeAgent();
                            if IsDefined(memberAtt) {
                                let current = memberAtt.GetAttitudeTowards(playerAtt);
                                if !Equals(current, EAIAttitude.AIA_Hostile) {
                                    memberAtt.SetAttitudeTowards(playerAtt, EAIAttitude.AIA_Hostile);
                                    StreetsOfNightCity_Logger.LogVerbose(s"[PROXIMITY] \(member.GetDisplayName()) (faction \(ToString(squad.factionName))) entered hostility radius -> Hostile toward player.", this.settings);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    private func DeAggroAmbientSquads() -> Void {
        let gi = this.GetGameInstance();
        for squadA in this.activePatrols {
            if IsDefined(squadA) && squadA.isAmbient {
                for memberAmbID in squadA.squadEntityIDs {
                    let memberAmb = GameInstance.FindEntityByID(gi, memberAmbID) as ScriptedPuppet;
                    if IsDefined(memberAmb) && !memberAmb.IsDead() {
                        let memberAmbAtt = memberAmb.GetAttitudeAgent();
                        let memberAmbTracker = memberAmb.GetTargetTrackerComponent();
                        if IsDefined(memberAmbTracker) {
                            let hadAmbientThreat = false;
                            for t in memberAmbTracker.GetHostileThreats(false) {
                                let threatPuppet = t.entity as ScriptedPuppet;
                                if IsDefined(threatPuppet) && !threatPuppet.IsDead() && threatPuppet.HasTag(n"SONC_Ambient") {
                                    hadAmbientThreat = true;
                                    if IsDefined(memberAmbAtt) {
                                        let threatAtt = threatPuppet.GetAttitudeAgent();
                                        if IsDefined(threatAtt) {
                                            memberAmbAtt.SetAttitudeTowards(threatAtt, EAIAttitude.AIA_Neutral);
                                            threatAtt.SetAttitudeTowards(memberAmbAtt, EAIAttitude.AIA_Neutral);
                                        }
                                    }
                                }
                            }
                            if hadAmbientThreat { memberAmbTracker.ClearThreats(); }
                        }
                    }
                }
            }
        }
    }
    protected cb func OnProcessSpawnQueueRequest(request: ref<StreetsOfNightCity_SpawnQueueRequest>) -> Void {
        let currentTime = EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
        if ArraySize(this.m_spawnQueue) > 0 && !this.m_spawnQueue[0].isConflict {
            if currentTime < this.m_nextSpawnTime {
                this.ScheduleSpawnQueueProcess(0.25);
                return;
            }
        }
        if ArraySize(this.m_spawnQueue) > 0 {
            let queuedSpawn = this.m_spawnQueue[0];
            ArrayErase(this.m_spawnQueue, 0);
            let targetSquad = this.GetSquadByID(queuedSpawn.squadID);
            if !IsDefined(targetSquad) {
                if this.settings.debugLogging {
                    StreetsOfNightCity_Logger.Log(" Squad " + ToString(queuedSpawn.squadID) + " removed - skipping spawn");
                }
                this.ScheduleSpawnQueueProcess(0.01);
                return;
            }
            this.ExecuteIndividualSpawn(queuedSpawn);
            let delay: Float;
            if queuedSpawn.isConflict {
                delay = 0.0;
            } else {
                let squadFinished = true;
                if ArraySize(this.m_spawnQueue) > 0 {
                    let nextQueued = this.m_spawnQueue[0];
                    if nextQueued.squadID == queuedSpawn.squadID { squadFinished = false; }
                }
                if squadFinished {
                    let player = GetPlayer(this.GetGameInstance());
                    let districtName = this.GetPlayerDistrictName(player);
                    let isRural = this.IsRuralArea(districtName);
                    if queuedSpawn.isAmbient {
                        delay = this.settings.ambientSpawnInterval;
                    } else if isRural {
                        delay = this.settings.badlandsSpawnInterval;
                    } else {
                        delay = this.settings.immersiveCitySpawnInterval;
                    }
                } else {
                    delay = 0.5;
                }
            }
            this.m_nextSpawnTime = currentTime + delay;
            this.ScheduleSpawnQueueProcess(0.01);
            return;
        }
        this.ScheduleSpawnQueueProcess(0.5);
    }
    private func ScheduleSpawnQueueProcess(delay: Float) -> Void {
        GameInstance.GetDelaySystem(this.GetGameInstance()).DelayScriptableSystemRequest(
            n"StreetsOfNightCity_System",
            new StreetsOfNightCity_SpawnQueueRequest(),
            delay
        );
    }
    private func ExecuteIndividualSpawn(queuedSpawn: ref<SONC_QueuedSpawn>) -> Void {
        let gi = this.GetGameInstance();
        let player = GetPlayer(gi);
        if !IsDefined(player) { return; }
        let spawnPos = queuedSpawn.validatedPosition.position;
        if !this.PassesSpawnSafetyChecks(spawnPos) {
            return;
        }
        let targetSquad = this.GetSquadByID(queuedSpawn.squadID);
        if !IsDefined(targetSquad) {
            if this.settings.debugLogging {
                StreetsOfNightCity_Logger.Log(" Squad no longer exists");
            }
            return;
        }
        let playerPos = player.GetWorldPosition();
        let finalDistance = Vector4.Distance(queuedSpawn.validatedPosition.position, playerPos);
        let settingsMinDist: Float;
        if queuedSpawn.isAmbient {
            settingsMinDist = this.settings.ambientMinSpawnDist;
        } else {
            settingsMinDist = this.settings.immersiveCityMinSpawnDist;
        }
        let absoluteMinDist = settingsMinDist * 0.8;
        if absoluteMinDist < 25.0 { absoluteMinDist = 25.0; }
        if finalDistance < absoluteMinDist {
            if this.settings.debugLogging {
                StreetsOfNightCity_Logger.Log(
                    s" Player too close: \(FloatToStringPrec(finalDistance, 1))m < \(FloatToStringPrec(absoluteMinDist, 1))m"
                );
            }
            return;
        }
        let groundSnap = this.FindGroundBeneath(spawnPos);
        if !this.IsValidSpawnPoint(groundSnap) {
            if this.settings.debugLogging {
                StreetsOfNightCity_Logger.Log(" Pre-spawn: no ground found beneath position");
            }
            return;
        }
        let heightAboveGround = spawnPos.Z - groundSnap.Z;
        if heightAboveGround > 4.0 || heightAboveGround < -2.0 {
            if this.settings.debugLogging {
                StreetsOfNightCity_Logger.Log(
                    s" Pre-spawn: floating position rejected | \(FloatToStringPrec(heightAboveGround, 1))m above ground"
                );
            }
            return;
        }
        let groundSnapDist = Vector4.Distance(groundSnap, playerPos);
        if groundSnapDist < absoluteMinDist {
            if this.settings.debugLogging {
                StreetsOfNightCity_Logger.Log(s" Pre-spawn: ground snap too close to player (\(FloatToStringPrec(groundSnapDist, 1))m)");
            }
            return;
        }
        let camSysPS = GameInstance.GetCameraSystem(gi);
        let camTransformPS = new Transform(
            new Vector4(0.0, 0.0, 0.0, 0.0),
            new Quaternion(0.0, 0.0, 0.0, 1.0)
        );
        camSysPS.GetActiveCameraWorldTransform(camTransformPS);
        let fovPS = camSysPS.GetActiveCameraFOV();
        let aspectRatioPS = camSysPS.GetAspectRatio();
        let inViewPS = groundSnapDist < 80.0 && SONC_IsPointInCameraView(gi, groundSnap, camTransformPS, fovPS, aspectRatioPS, 500.0, false);
        if inViewPS {
            if this.settings.debugLogging {
                StreetsOfNightCity_Logger.Log(" Pre-spawn: ground position still in camera view - skipping");
            }
            return;
        }
        let spec = this.GetEntitySpec();
        spec.recordID = queuedSpawn.record;
        spec.position = groundSnap;
        spec.orientation = queuedSpawn.validatedPosition.orientation;
        spec.alwaysSpawned = true;
        spec.persistState = false;
        spec.persistSpawn = false;
        ArrayPush(spec.tags, n"SONC_NPC");
        ArrayPush(spec.tags, n"PreventPersistence");
        ArrayPush(spec.tags, n"IgnorePersistency");
        ArrayPush(spec.tags, n"DynamicEntity");
        let id = GameInstance.GetDynamicEntitySystem().CreateEntity(spec);
        this.ReturnEntitySpec(spec);
        if !EntityID.IsDefined(id) {
            if this.settings.debugLogging {
                StreetsOfNightCity_Logger.Log(" Entity creation returned invalid ID");
            }
            return;
        }
        targetSquad.pendingVerifyCount += 1;
        let verifyCallback = new SONC_VerifyEntityCallback();
        verifyCallback.entityID = id;
        verifyCallback.squadID = queuedSpawn.squadID;
        verifyCallback.factionName = queuedSpawn.factionName;
        verifyCallback.isAmbient = queuedSpawn.isAmbient;
        verifyCallback.isConflict = queuedSpawn.isConflict;
        verifyCallback.finalDistance = finalDistance;
        verifyCallback.systemInstance = this;
        GameInstance.GetDelaySystem(gi).DelayCallback(verifyCallback, 0.5);
    }
    private func CheckWorldReady() -> Bool {
        let gi = this.GetGameInstance();
        if !IsDefined(GetPlayer(gi)) { return false; }
        if !IsDefined(GameInstance.GetScriptableSystemsContainer(gi).Get(n"PreventionSystem") as PreventionSystem) { return false; }
        return true;
    }
    private func GetPatrolCounts(out ambHuman: Int32, out ambDrone: Int32, out immHuman: Int32, out immDrone: Int32) -> Void {
        ambHuman = this.m_cachedAmbHuman;
        ambDrone = this.m_cachedAmbDrone;
        immHuman = this.m_cachedImmHuman;
        immDrone = this.m_cachedImmDrone;
    }
    private func AddToPatrolCounts(squad: ref<SONC_PatrolSquad>) -> Void {
        if squad.isAmbient {
            if squad.isMechanical { this.m_cachedAmbDrone += 1; } else { this.m_cachedAmbHuman += 1; }
        } else {
            if squad.isMechanical { this.m_cachedImmDrone += 1; } else { this.m_cachedImmHuman += 1; }
        }
    }
    private func RemoveFromPatrolCounts(squad: ref<SONC_PatrolSquad>) -> Void {
        if squad.isAmbient {
            if squad.isMechanical { this.m_cachedAmbDrone -= 1; } else { this.m_cachedAmbHuman -= 1; }
        } else {
            if squad.isMechanical { this.m_cachedImmDrone -= 1; } else { this.m_cachedImmHuman -= 1; }
        }
        if this.m_cachedAmbHuman < 0 { this.m_cachedAmbHuman = 0; }
        if this.m_cachedAmbDrone < 0 { this.m_cachedAmbDrone = 0; }
        if this.m_cachedImmHuman < 0 { this.m_cachedImmHuman = 0; }
        if this.m_cachedImmDrone < 0 { this.m_cachedImmDrone = 0; }
    }
    private func RebuildPatrolCounts() -> Void {
        this.m_cachedAmbHuman = 0;
        this.m_cachedAmbDrone = 0;
        this.m_cachedImmHuman = 0;
        this.m_cachedImmDrone = 0;
        for squad in this.activePatrols {
            if IsDefined(squad) {
                if squad.isAmbient {
                    if squad.isMechanical { this.m_cachedAmbDrone += 1; } else { this.m_cachedAmbHuman += 1; }
                } else {
                    if squad.isMechanical { this.m_cachedImmDrone += 1; } else { this.m_cachedImmHuman += 1; }
                }
            }
        }
    }
    private func ShouldSpawnAmbientGroup() -> Bool {
        let player = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) || this.IsPlayerInRestrictedState(player) { return false; }
        let ambHuman: Int32; let ambDrone: Int32;
        let immHuman: Int32; let immDrone: Int32;
        this.GetPatrolCounts(ambHuman, ambDrone, immHuman, immDrone);
        return (ambHuman < this.settings.ambientMaxHumanGroups) || (ambDrone < this.settings.ambientMaxDroneGroups);
    }
    private func ShouldSpawnImmersiveGroup() -> Bool {
        let player = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) || this.IsPlayerInRestrictedState(player) { return false; }
        let districtName = this.GetPlayerDistrictName(player);
        let isInBadlands = this.IsRuralArea(districtName);
        let ambHuman: Int32; let ambDrone: Int32;
        let immHuman: Int32; let immDrone: Int32;
        this.GetPatrolCounts(ambHuman, ambDrone, immHuman, immDrone);
        if isInBadlands {
            if player.IsInCombat() && !this.settings.badlandsAllowCombatSpawns { return false; }
            return (immHuman < this.settings.badlandsMaxPatrols) || (immDrone < this.settings.badlandsMaxDronePatrols);
        } else {
            if player.IsInCombat() && !this.settings.immersiveCityAllowCombatSpawns { return false; }
            return (immHuman < this.settings.immersiveCityMaxPatrols) || (immDrone < this.settings.immersiveCityMaxDronePatrols);
        }
    }
    private func IsPlayerInRestrictedState(player: ref<PlayerPuppet>) -> Bool {
        let gi       = this.GetGameInstance();
        let bbDefs   = GetAllBlackboardDefs();
        let bbSystem = GameInstance.GetBlackboardSystem(gi);
        if !IsDefined(bbSystem) { return false; }
        let psmBB    = bbSystem.Get(bbDefs.PlayerStateMachine);
        if !IsDefined(psmBB) { return false; }
        let sceneTier: Int32 = psmBB.GetInt(bbDefs.PlayerStateMachine.SceneTier);
        if sceneTier > 1 { return true; }
        if StatusEffectSystem.ObjectHasStatusEffectWithTag(player, n"NoCombat") { return true; }
        if StatusEffectSystem.ObjectHasStatusEffectWithTag(player, n"VehicleScene") { return true; }
        let swimState = psmBB.GetInt(bbDefs.PlayerStateMachine.Swimming);
        if swimState == EnumInt(gamePSMSwimming.Surface) || swimState == EnumInt(gamePSMSwimming.Diving) { return true; }
        let mountInfo = GameInstance.GetMountingFacility(gi).GetMountingInfoSingleWithObjects(player);
        if EntityID.IsDefined(mountInfo.parentId) { return true; }
        return false;
    }
    private func TrySpawnAmbientGroup() -> Bool {
        let player = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) { return false; }
        let playerPos = player.GetWorldPosition();
        let districtName = this.GetPlayerDistrictName(player);
        let factionFound: Bool;
        let currentFaction = this.GetFactionForDistrict(districtName, factionFound);
        if !factionFound { return false; }
        let ambHuman: Int32; let ambDrone: Int32;
        let immHuman: Int32; let immDrone: Int32;
        this.GetPatrolCounts(ambHuman, ambDrone, immHuman, immDrone);
        let canSpawnAmbHuman = ambHuman < this.settings.ambientMaxHumanGroups;
        let canSpawnAmbDrone = ambDrone < this.settings.ambientMaxDroneGroups;
        let districtIsCorpAligned = factionFound && this.IsCorpAlignedFaction(currentFaction.factionName);
        if canSpawnAmbDrone && districtIsCorpAligned && RandRange(0, 100) < 20 {
            let droneFaction = this.GetFactionProfileByName(n"CitySurveillance");
            if IsDefined(droneFaction) && this.IsFactionEnabled(n"CitySurveillance") {
                if this.SpawnFootGroup(droneFaction, false, true, true) > 0 {
                    return true;
                }
            }
        }
        if canSpawnAmbHuman {
            return this.SpawnAmbientIndividual(currentFaction);
        }
        return false;
    }
    private func FindFallbackSpawnPoint(center: Vector4, minRadius: Float, maxRadius: Float, opt skipRoadCheck: Bool) -> Vector4 {
        let gi = this.GetGameInstance();
        let aiNavSys = GameInstance.GetAINavigationSystem(gi);
        let player = GetPlayer(gi);
        if !IsDefined(player) { return new Vector4(0.0, 0.0, 0.0, 0.0); }
        let playerPos = player.GetWorldPosition();
        let interiorTypes: array<ESecurityAreaType>;
        ArrayPush(interiorTypes, ESecurityAreaType.SAFE);
        let attempts = 0;
        while attempts < 20 {
            let angle = RandRangeF(0.0, Pi() * 2.0);
            let dist = RandRangeF(minRadius, maxRadius);
            let test = center;
            test.X += CosF(angle) * dist;
            test.Y += SinF(angle) * dist;
            test.Z = playerPos.Z + RandRangeF(-50.0, 50.0);
            let nav = aiNavSys.FindPointInBoxForCharacter(test, new Vector4(30.0, 30.0, 50.0, 1.0), player);
            if Equals(nav.status, worldNavigationRequestStatus.OK) {
                let point = nav.point;
                if AbsF(point.Z - this.WATER_LEVEL) >= 0.1 {
                   let d = Vector4.Distance2D(point, playerPos);
                    if d >= minRadius && d <= maxRadius {
                        if !this.IsDefinitelyIndoor(point) {
                            if !SONC_IsPointInAnyLoadedSecurityAreaRadius(point, interiorTypes, true) {
                                let ground = this.FindGroundBeneath(point);
                                if this.IsValidSpawnPoint(ground) {
                                    if AbsF(point.Z - ground.Z) <= 3.0 {
                                        if AbsF(ground.Z - this.WATER_LEVEL) >= 0.5 {
                                            let notOnVehicle = skipRoadCheck || !this.IsPointOnVehiclePath(ground);
                                            if notOnVehicle {
                                                return ground;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            attempts += 1;
        }
        return new Vector4(0.0, 0.0, 0.0, 0.0);
    }
    private func SpawnAmbientIndividual(faction: ref<SONC_FactionProfile>) -> Bool {
        if this.IsPoliceBlockedHere(faction.factionName) { return false; }
        let player = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) { return false; }
        if Equals(faction.factionName, n"Psycho") { return false; }
        let playerPos = player.GetWorldPosition();
        if this.settings.debugLogging { StreetsOfNightCity_Logger.Log("[AMBIENT] Attempting spawn | Faction: " + ToString(faction.factionName)); }
        let ambAnchor = this.GetForwardAnchor(player);
        let validatedSpawn = this.FindPedestrianSpawnPoint(
            ambAnchor,
            this.settings.ambientMaxSpawnDist,
            this.settings.ambientMinSpawnDist
        );
        if !validatedSpawn.isValid {
            if this.settings.debugLogging { StreetsOfNightCity_Logger.Log("[AMBIENT] Primary failed | Reason: " + validatedSpawn.failureReason + " | Faction: " + ToString(faction.factionName)); }
            let fallbackPos = this.FindFallbackSpawnPoint(
                playerPos,
                this.settings.ambientMinSpawnDist,
                this.settings.ambientMaxSpawnDist
            );
            if !this.IsValidSpawnPoint(fallbackPos) {
                if this.settings.debugLogging { StreetsOfNightCity_Logger.Log("[AMBIENT] Fallback also failed | Faction: " + ToString(faction.factionName)); }
                return false;
            }
            let fallback = new SONC_ValidatedSpawnPoint();
            fallback.isValid = true;
            fallback.position = fallbackPos;
            fallback.distanceToPlayer = Vector4.Distance(fallbackPos, playerPos);
            fallback.orientation = this.SafeOrientationFor(fallbackPos);
            validatedSpawn = fallback;
        } else {
            if this.settings.debugLogging { StreetsOfNightCity_Logger.Log("[AMBIENT] Primary succeeded | Dist: " + FloatToStringPrec(validatedSpawn.distanceToPlayer, 1) + "m | Faction: " + ToString(faction.factionName)); }
        }
        if !this.PassesSpawnSafetyChecks(validatedSpawn.position) {
            return false;
        }
        if this.IsNearRecentRoadDespawn(validatedSpawn.position, 30.0) {
            if this.settings.debugLogging {
                StreetsOfNightCity_Logger.Log("[AMBIENT] Spawn skipped - too close to a recent road despawn | Faction: " + ToString(faction.factionName));
            }
            return false;
        }
        let spatialSysAmb = GameInstance.GetSpatialQueriesSystem(this.GetGameInstance());
        let vehOverlapResult: TraceResult;
        let vehCheckPos = validatedSpawn.position; vehCheckPos.Z += 0.5;
        let vehiclePresent = spatialSysAmb.Overlap(new Vector4(1.2, 1.2, 1.0, 1.0), vehCheckPos, new EulerAngles(), n"Vehicle", vehOverlapResult);
        if vehiclePresent { return false; }
        let record: TweakDBID;
        let selectedAppearance: CName;
        let isAppearanceBased: Bool = false;
        if ArraySize(faction.ambientCivilians) > 0 {
            record = faction.ambientCivilians[RandRange(0, ArraySize(faction.ambientCivilians))];
        } else if ArraySize(faction.ambientAppearances) > 0 {
            let entry = faction.ambientAppearances[RandRange(0, ArraySize(faction.ambientAppearances))];
            record = entry.recordID;
            selectedAppearance = entry.appearanceName;
            isAppearanceBased = true;
        } else if ArraySize(faction.elitePool) > 0 {
            record = this.PickNonPoliceRecord(faction.elitePool);
        } else {
            if this.settings.debugLogging { StreetsOfNightCity_Logger.Log("[AMBIENT] No NPC records found | Faction: " + ToString(faction.factionName)); }
            return false;
        }
        let squad = this.CreateSquad(validatedSpawn.position);
        squad.factionName = faction.factionName;
        squad.isAmbient = true;
        squad.isMechanical = false;
        ArrayPush(this.activePatrols, squad);
        this.AddToPatrolCounts(squad);
        let spec = this.GetEntitySpec();
        spec.recordID = record;
        if !Equals(selectedAppearance, n"") {
            spec.appearanceName = selectedAppearance;
        }
        spec.position = validatedSpawn.position;
        spec.alwaysSpawned = true;
        spec.persistState = false;
        spec.persistSpawn = false;
        ArrayPush(spec.tags, n"SONC_NPC");
        ArrayPush(spec.tags, n"SONC_Ambient");
        ArrayPush(spec.tags, n"PreventPersistence");
        ArrayPush(spec.tags, n"IgnorePersistency");
        ArrayPush(spec.tags, n"DynamicEntity");
        let id = GameInstance.GetDynamicEntitySystem().CreateEntity(spec);
        this.ReturnEntitySpec(spec);
        if !EntityID.IsDefined(id) {
            let retryPos = this.FindFallbackSpawnPoint(playerPos, this.settings.ambientMinSpawnDist, this.settings.ambientMaxSpawnDist);
            if !this.IsValidSpawnPoint(retryPos) || !this.PassesSpawnSafetyChecks(retryPos) {
                ArrayRemove(this.activePatrols, squad);
                this.RemoveFromPatrolCounts(squad);
                return false;
            }
            let retrySpec = this.GetEntitySpec();
            retrySpec.recordID = record;
            if !Equals(selectedAppearance, n"") { retrySpec.appearanceName = selectedAppearance; }
            retrySpec.position = retryPos;
            retrySpec.alwaysSpawned = true;
            retrySpec.persistState = false;
            retrySpec.persistSpawn = false;
            retrySpec.tags = [n"SONC_NPC", n"SONC_Ambient", n"PreventPersistence", n"IgnorePersistency", n"DynamicEntity"];
            id = GameInstance.GetDynamicEntitySystem().CreateEntity(retrySpec);
            this.ReturnEntitySpec(retrySpec);
            validatedSpawn.position = retryPos;
            if !EntityID.IsDefined(id) {
                ArrayRemove(this.activePatrols, squad);
                this.RemoveFromPatrolCounts(squad);
                return false;
            }
        }
        ArrayPush(squad.squadEntityIDs, id);
        let gi = this.GetGameInstance();
        let setupCb = new SONC_AmbientCrowdCallback();
        setupCb.npcID = id;
        setupCb.isAppearanceBased = isAppearanceBased;
        GameInstance.GetDelaySystem(gi).DelayCallback(setupCb, 1.5);
        let attCb = new StreetsOfNightCity_ConsolidatedAttitudeCallback();
        attCb.squadID = squad.squadID;
        attCb.factionName = squad.factionName;
        attCb.isConflict = false;
        attCb.isAmbient = true;
        attCb.systemInstance = this;
        GameInstance.GetDelaySystem(gi).DelayCallback(attCb, 1.0);
        return true;
    }
    private func TrySpawnImmersiveGroup() -> Bool {
        let player = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) { return false; }
        let districtName = this.GetPlayerDistrictName(player);
        let isRural = this.IsRuralArea(districtName);
        if isRural {
            return this.HandleBadlandsSpawn(districtName);
        } else {
            let ambHuman: Int32; let ambDrone: Int32;
            let immHuman: Int32; let immDrone: Int32;
            this.GetPatrolCounts(ambHuman, ambDrone, immHuman, immDrone);
            let canSpawnImmHuman = immHuman < this.settings.immersiveCityMaxPatrols;
            let canSpawnImmDrone = this.settings.immersiveEnableElites && (immDrone < this.settings.immersiveCityMaxDronePatrols);
            if !canSpawnImmHuman && !canSpawnImmDrone { return false; }
            let factionFound: Bool;
            let currentFaction = this.GetFactionForDistrict(districtName, factionFound);
            if !factionFound { return false; }
            if canSpawnImmHuman && canSpawnImmDrone {
                if RandRange(0, 100) < this.settings.immersiveCityEliteChance {
                    if this.TrySpawnRoamingMechPatrol(currentFaction, false) { return true; }
                    return this.SpawnImmersiveHuman(currentFaction);
                } else {
                    if this.SpawnImmersiveHuman(currentFaction) { return true; }
                    return this.TrySpawnRoamingMechPatrol(currentFaction, false);
                }
            } else if canSpawnImmDrone {
                return this.TrySpawnRoamingMechPatrol(currentFaction, false);
            } else if canSpawnImmHuman {
                return this.SpawnImmersiveHuman(currentFaction);
            }
        }
        return false;
    }
    private func HandleBadlandsSpawn(districtName: String) -> Bool {
        let ambHuman: Int32; let ambDrone: Int32;
        let immHuman: Int32; let immDrone: Int32;
        this.GetPatrolCounts(ambHuman, ambDrone, immHuman, immDrone);
        let canSpawnHuman = immHuman < this.settings.badlandsMaxPatrols;
        let canSpawnDrone = this.settings.immersiveEnableElites && (immDrone < this.settings.badlandsMaxDronePatrols);
        if !canSpawnHuman && !canSpawnDrone { return false; }
        let factionFound: Bool;
        let currentFaction = this.GetFactionForDistrict(districtName, factionFound);
        if !factionFound { return false; }
        if canSpawnHuman && canSpawnDrone {
            if RandRange(0, 100) < this.settings.badlandsEliteChance {
                if this.TrySpawnRoamingMechPatrol(currentFaction, false) { return true; }
                return this.SpawnBadlandsHuman(currentFaction);
            } else {
                if this.SpawnBadlandsHuman(currentFaction) { return true; }
                return this.TrySpawnRoamingMechPatrol(currentFaction, false);
            }
        } else if canSpawnDrone {
            return this.TrySpawnRoamingMechPatrol(currentFaction, false);
        } else {
            return this.SpawnBadlandsHuman(currentFaction);
        }
    }
    private func SpawnImmersiveHuman(faction: ref<SONC_FactionProfile>) -> Bool {
        let conflictChance = 0;
        let enabledRivals: array<CName>;
        for rival in faction.rivalFactions {
            if this.IsFactionEnabled(rival) { ArrayPush(enabledRivals, rival); }
        }
        if ArraySize(enabledRivals) > 0 {
            let agg = Cast<Float>(faction.baseAggression);
            if Equals(faction.factionType, SONC_FactionType.Corporation) { agg *= 3.0; }
            let baseAggression = agg * this.settings.immersiveCityConflictMultiplier;
            conflictChance = Cast<Int32>(baseAggression);
            if conflictChance > 80 { conflictChance = 80; }
        }
        if conflictChance > 0 && RandRange(0, 100) < conflictChance && !Equals(faction.factionName, n"CitySurveillance") {
            let rivalName = enabledRivals[RandRange(0, ArraySize(enabledRivals))];
            let rivalFaction = this.GetFactionProfileByName(rivalName);
            if IsDefined(rivalFaction) {
                if this.settings.debugLogging { StreetsOfNightCity_Logger.Log(">>> SPAWNING CONFLICT: " + ToString(faction.factionName) + " vs " + ToString(rivalFaction.factionName)); }
                if this.SpawnConflictEvent(faction, rivalFaction, false) { return true; }
                if this.settings.debugLogging { StreetsOfNightCity_Logger.Log(">>> CONFLICT SPAWN FAILED - Falling back to regular spawn"); }
            }
        }
        let vehicleRoll = RandRange(0, 100);
        if vehicleRoll < this.settings.immersiveCityVehicleChance {
            if this.TrySpawnVehicleSquad(faction, false) { return true; }
        }
        return this.SpawnFootGroup(faction, false, false, false) > 0;
    }
    private func SpawnBadlandsHuman(faction: ref<SONC_FactionProfile>) -> Bool {
    let conflictChance = this.settings.badlandsConflictChance;
    let enabledRivals: array<CName>;
    for rival in faction.rivalFactions {
        if this.IsFactionEnabled(rival) { ArrayPush(enabledRivals, rival); }
    }
    if ArraySize(enabledRivals) > 0 && RandRange(0, 100) < conflictChance {
        let rivalName = enabledRivals[RandRange(0, ArraySize(enabledRivals))];
        let rivalFaction = this.GetFactionProfileByName(rivalName);
        if IsDefined(rivalFaction) {
            if this.SpawnConflictEvent(faction, rivalFaction, true) { return true; }
        }
    }
    let isHunter = RandRange(0, 100) < this.settings.badlandsHunterChance;
    if this.TrySpawnVehicleSquad(faction, isHunter) { return true; }
    return this.SpawnFootGroup(faction, false, false, false) > 0;
}
    public func TrySpawnVehicleSquad(faction: ref<SONC_FactionProfile>, isHunter: Bool) -> Bool {
        if this.IsPoliceBlockedHere(faction.factionName) { return false; }
        if ArraySize(faction.vehiclePool) == 0 { return false; }
        let gi = this.GetGameInstance();
        let player = GetPlayer(gi);
        if !IsDefined(player) { return false; }
        let playerPos = player.GetWorldPosition();
        let playerForward = player.GetWorldForward();
        let districtName = this.GetPlayerDistrictName(player);
        let isRural = this.IsRuralArea(districtName);
        let minDist: Float;
        let maxDist: Float;
        if isRural {
            minDist = this.settings.badlandsMinSpawnDist;
            maxDist = this.settings.badlandsMaxSpawnDist;
        } else {
            minDist = this.settings.immersiveCityMinSpawnDist;
            maxDist = this.settings.immersiveCityMaxSpawnDist;
        }
        let bestRoadside: Vector4 = new Vector4(0.0, 0.0, 0.0, 0.0);
        let bestRoadScore: Float = -9999.0;
        let trafficNodes = SONC_GetNearbyVehicleSpawnPoints(playerPos, maxDist, minDist, 120.0, 60);
        if ArraySize(trafficNodes) > 0 {
            for nodeV3 in trafficNodes {
                let node = Vector4.Vector3To4(nodeV3);
                let dist = Vector4.Distance(node, playerPos);
                if dist >= minDist && dist <= maxDist {
                    let toNode = Vector4.Normalize(node - playerPos);
                    let alignment = Vector4.Dot(playerForward, toNode);
                    let lateralBias = (1.0 - AbsF(alignment)) * 40.0;
                    let forwardPenalty = MaxF(alignment, 0.0) * 30.0;
                    let distancePenalty = dist * 0.25;
                    let score = lateralBias - forwardPenalty - distancePenalty;
                    let nearby = SONC_GetNearbyVehicleSpawnPoints(node, 4.0, 0.0, 2.0, 6);
                    if ArraySize(nearby) <= 4 { score += 25.0; }
                    if score > bestRoadScore { bestRoadScore = score; bestRoadside = node; }
                }
            }
        }
        let spawnCandidate: Vector4;
        let isOffroad = false;
        if this.IsValidSpawnPoint(bestRoadside) && bestRoadScore > -2000.0 {
            spawnCandidate = bestRoadside;
        } else {
            spawnCandidate = this.FindValidOffroadSpawnPoint(playerPos, maxDist, minDist);
            isOffroad = true;
        }
        if !this.IsValidSpawnPoint(spawnCandidate) { return false; }
        let groundPos = this.FindGroundBeneath(spawnCandidate);
        if !this.IsValidSpawnPoint(groundPos) { return false; }
        let heightDiff = AbsF(spawnCandidate.Z - groundPos.Z);
        if heightDiff > 8.0 { return false; }
        let finalPos = groundPos;
        finalPos.Z += 0.4;
        let validation = this.ValidateSpawnPoint(finalPos, minDist, maxDist, false, false, !isOffroad);
        if !validation.isValid {
            if isOffroad { return false; }
            let fallbackPos = this.FindValidOffroadSpawnPoint(playerPos, maxDist, minDist);
            if !this.IsValidSpawnPoint(fallbackPos) { return false; }
            let fallbackGround = this.FindGroundBeneath(fallbackPos);
            if !this.IsValidSpawnPoint(fallbackGround) { return false; }
            let fallbackHeight = AbsF(fallbackPos.Z - fallbackGround.Z);
            if fallbackHeight > 8.0 { return false; }
            finalPos = fallbackGround;
            finalPos.Z += 0.4;
            let fallbackValidation = this.ValidateSpawnPoint(finalPos, minDist, maxDist, false, false, true);
            if !fallbackValidation.isValid { return false; }
            isOffroad = true;
        }
        let spatialSys = GameInstance.GetSpatialQueriesSystem(gi);
        let vehOverlap: TraceResult;
        let overlapBox = new Vector4(1.5, 1.5, 0.5, 1.0);
        let overlapPt = finalPos; overlapPt.Z += 0.3;
        if spatialSys.Overlap(overlapBox, overlapPt, new EulerAngles(), n"Vehicle", vehOverlap) { return false; }
        let finalOrient: Quaternion;
        let dirToPlayer = playerPos - finalPos;
        dirToPlayer.Z = 0.0;
        if Vector4.Length2D(dirToPlayer) > 3.0 {
            finalOrient = Quaternion.BuildFromDirectionVector(Vector4.Normalize(dirToPlayer));
        } else {
            finalOrient = Quaternion.BuildFromDirectionVector(playerForward);
        }
        let vehicleRecordID = this.PickNonPoliceRecord(faction.vehiclePool);
        let vehicleSpec = this.GetEntitySpec();
        vehicleSpec.recordID = vehicleRecordID;
        vehicleSpec.position = finalPos;
        vehicleSpec.orientation = finalOrient;
        vehicleSpec.alwaysSpawned = true;
        vehicleSpec.persistState = false;
        vehicleSpec.persistSpawn = false;
        ArrayPush(vehicleSpec.tags, n"SONC_Vehicle");
        ArrayPush(vehicleSpec.tags, n"PreventPersistence");
        ArrayPush(vehicleSpec.tags, n"IgnorePersistency");
        ArrayPush(vehicleSpec.tags, n"DynamicEntity");
        let vehicleID = GameInstance.GetDynamicEntitySystem().CreateEntity(vehicleSpec);
        this.ReturnEntitySpec(vehicleSpec);
        if !EntityID.IsDefined(vehicleID) { return false; }
        let finalDistance = Vector4.Distance(finalPos, playerPos);
        if this.settings.debugLogging {
            let hunterTag: String;
            if isHunter { hunterTag = " (Hunter)"; } else { hunterTag = ""; }
            let roadTag: String;
            if isOffroad { roadTag = "Offroad"; } else { roadTag = "Roadside"; }
            StreetsOfNightCity_Logger.Log(
                "[VEHICLE] " + ToString(faction.factionName) +
                hunterTag +
                " | Dist: " + FloatToStringPrec(finalDistance, 1) + "m" +
                " | " + roadTag +
                " | Score: " + FloatToStringPrec(bestRoadScore, 1)
            );
        }
        let cb = new StreetsOfNightCity_PostVehicleSpawnCallback();
        cb.vehicleID = vehicleID;
        cb.faction = faction;
        cb.spawnPoint = finalPos;
        cb.system = this;
        cb.isHunter = isHunter;
        GameInstance.GetDelaySystem(gi).DelayCallback(cb, 1.8 + RandRangeF(-0.4, 0.4));
        return true;
    }
    // Returns the new squad ID, or -1 on failure. Squad IDs start at 1, so
    // callers that only care about success test `> 0`.
    public func SpawnFootGroup(faction: ref<SONC_FactionProfile>, isConflict: Bool, opt isAmbient: Bool, opt isMechanical: Bool, opt searchAnchor: Vector4, opt useSearchAnchor: Bool) -> Int32 {
        if this.IsPoliceBlockedHere(faction.factionName) { return -1; }
        let player = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) { return -1; }
        let mountInfo = GameInstance.GetMountingFacility(this.GetGameInstance()).GetMountingInfoSingleWithObjects(player);
        if EntityID.IsDefined(mountInfo.parentId) { return -1; }
        let playerPos = player.GetWorldPosition();
        let districtName = this.GetPlayerDistrictName(player);
        let isRural = this.IsRuralArea(districtName);
        let minDist: Float;
        let maxDist: Float;
        if isRural {
            minDist = this.settings.badlandsMinSpawnDist;
            maxDist = this.settings.badlandsMaxSpawnDist;
        } else if isAmbient {
            minDist = this.settings.ambientMinSpawnDist;
            maxDist = this.settings.ambientMaxSpawnDist;
        } else {
            minDist = this.settings.immersiveCityMinSpawnDist;
            maxDist = this.settings.immersiveCityMaxSpawnDist;
        }
        let footAnchor = this.GetSpawnSearchAnchor(player);
        if useSearchAnchor {
            if this.IsValidSpawnPoint(searchAnchor) { footAnchor = searchAnchor; }
        }
        let validatedSpawn = this.FindPedestrianSpawnPoint(footAnchor, maxDist, minDist, !isAmbient);
        if !validatedSpawn.isValid {
            if this.settings.debugLogging {
                StreetsOfNightCity_Logger.Log("[FOOT] Primary failed - trying fallback | " + validatedSpawn.failureReason);
            }
            let fallbackPos = this.FindFallbackSpawnPoint(playerPos, minDist, maxDist, !isAmbient);
            if !this.IsValidSpawnPoint(fallbackPos) {
                if this.settings.debugLogging {
                    StreetsOfNightCity_Logger.Log("[FOOT] Fallback also failed - skipping");
                }
                return -1;
            }
            let fallback = new SONC_ValidatedSpawnPoint();
            fallback.isValid = true;
            fallback.position = fallbackPos;
            fallback.distanceToPlayer = Vector4.Distance(fallbackPos, playerPos);
            fallback.orientation = this.SafeOrientationFor(fallbackPos);
            validatedSpawn = fallback;
        }
        if this.settings.debugLogging {
            let spawnModeLog: String;
            if isAmbient { spawnModeLog = "AMBIENT"; } else { spawnModeLog = "IMMERSIVE"; }
            StreetsOfNightCity_Logger.Log(
                " Faction: " + ToString(faction.factionName) +
                " | Distance: " + FloatToStringPrec(validatedSpawn.distanceToPlayer, 1) + "m" +
                " | Mode: " + spawnModeLog
            );
        }
        return this.SpawnFootGroupAtPoint(faction, validatedSpawn, isConflict, isAmbient, isMechanical);
    }
    // Returns the new squad ID, or -1 on failure.
    private func SpawnFootGroupAtPoint(faction: ref<SONC_FactionProfile>, validatedSpawn: ref<SONC_ValidatedSpawnPoint>, isConflict: Bool, isAmbient: Bool, isMechanical: Bool) -> Int32 {
        let squad = this.CreateSquad(validatedSpawn.position);
        squad.factionName = faction.factionName;
        squad.isAmbient = isAmbient;
        squad.isMechanical = isMechanical;
        squad.isConflict = isConflict;
        ArrayPush(this.activePatrols, squad);
        this.AddToPatrolCounts(squad);
        if isMechanical {
            this.SpawnMechanicalSquad(faction, squad, validatedSpawn, isConflict, isAmbient);
            if ArraySize(squad.squadEntityIDs) == 0 {
                if this.settings.debugLogging {
                    StreetsOfNightCity_Logger.Log(" Mechanical spawn failed - removing squad");
                }
                if ArrayContains(this.activePatrols, squad) {
                    ArrayRemove(this.activePatrols, squad);
                    this.RemoveFromPatrolCounts(squad);
                }
                return -1;
            }
            return squad.squadID;
        } else {
            this.SpawnSquadMembers(faction, squad, validatedSpawn, isConflict, isAmbient);
            if ArrayContains(this.activePatrols, squad) { return squad.squadID; }
            return -1;
        }
    }
    private func SpawnConflictEvent(defenders: ref<SONC_FactionProfile>, attackers: ref<SONC_FactionProfile>, isBadlands: Bool) -> Bool {
        if this.IsPoliceBlockedHere(defenders.factionName) { return false; }
        if this.IsPoliceBlockedHere(attackers.factionName) { return false; }
        if Equals(defenders.factionName, attackers.factionName) {
            return this.SpawnFootGroup(defenders, false, false, false) > 0;
        }
        let player = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) { return false; }
        let playerPos = player.GetWorldPosition();
        let localDistrict = this.GetPlayerDistrictName(player);
        if (Equals(defenders.factionName, n"Barghest") || Equals(attackers.factionName, n"Barghest")) && !StrContains(localDistrict, "Dogtown") {
            return false;
        }
        let minDist: Float;
        let maxDist: Float;
        if isBadlands {
            minDist = this.settings.badlandsMinSpawnDist;
            maxDist = this.settings.badlandsMaxSpawnDist;
        } else {
            minDist = this.settings.immersiveCityMinSpawnDist;
            maxDist = this.settings.immersiveCityMaxSpawnDist;
        }
        let safetyDistSq: Float = minDist * minDist;
        let validAnchor: Vector4;
        let anchorFound = false;
        let conflictAnchor = this.GetForwardAnchor(player);
        let streetSpawn = this.FindPedestrianSpawnPoint(conflictAnchor, maxDist, minDist, true);
        if streetSpawn.isValid && this.ValidateConflictSpawnPoint(streetSpawn.position) {
            validAnchor = streetSpawn.position;
            anchorFound = true;
        }
        if !anchorFound { return false; }
        let defenderCluster = this.FindConflictClusterPoint(validAnchor, playerPos, playerPos, 8.0, 15.0, minDist, maxDist);
        if !this.IsValidSpawnPoint(defenderCluster) { defenderCluster = validAnchor; }
        let defenderPlayerDist = Vector4.Distance2D(defenderCluster, playerPos);
        if defenderPlayerDist < minDist || defenderPlayerDist > maxDist { return false; }
        let attackerCluster = this.FindConflictClusterPoint(validAnchor, defenderCluster, playerPos, 15.0, 25.0, minDist, maxDist);
        let attackerPlayerDist = Vector4.Distance2D(attackerCluster, playerPos);
        if !this.IsValidSpawnPoint(attackerCluster) || attackerPlayerDist < minDist || attackerPlayerDist > maxDist {
            let defDir = Vector4.Normalize(defenderCluster - validAnchor);
            let oppositePos = validAnchor - (defDir * 20.0);
            let aiNavSys = GameInstance.GetAINavigationSystem(this.GetGameInstance());
            let player2 = GetPlayer(this.GetGameInstance());
            let navFallback = aiNavSys.FindPointInBoxForCharacter(oppositePos, new Vector4(10.0, 10.0, 50.0, 1.0), player2);
            if Equals(navFallback.status, worldNavigationRequestStatus.OK) {
                attackerCluster = this.FindGroundBeneath(navFallback.point);
            } else {
                attackerCluster = this.FindGroundBeneath(oppositePos);
            }
            attackerPlayerDist = Vector4.Distance2D(attackerCluster, playerPos);
        }
        if !this.IsValidSpawnPoint(attackerCluster) || attackerPlayerDist < minDist || attackerPlayerDist > maxDist {
            attackerCluster = this.FindConflictClusterPoint(validAnchor, defenderCluster, playerPos, 10.0, 35.0, minDist, maxDist);
            attackerPlayerDist = Vector4.Distance2D(attackerCluster, playerPos);
        }
        if !this.IsValidSpawnPoint(attackerCluster) { return false; }
        if attackerPlayerDist < minDist || attackerPlayerDist > maxDist { return false; }
        if !this.ValidateConflictSpawnPoint(defenderCluster) || !this.ValidateConflictSpawnPoint(attackerCluster) { return false; }
        let separation = Vector4.Distance(defenderCluster, attackerCluster);
        if separation < 12.0 { return false; }
        if Vector4.DistanceSquared(playerPos, defenderCluster) < safetyDistSq || Vector4.DistanceSquared(playerPos, attackerCluster) < safetyDistSq { return false; }
        let validatedDefenderSpawn = this.ValidateSpawnPoint(defenderCluster, minDist, maxDist, true, false, true);
        if !validatedDefenderSpawn.isValid {
            if this.settings.debugLogging { StreetsOfNightCity_Logger.Log(" Defender spawn point rejected | reason: " + validatedDefenderSpawn.failureReason); }
            return false;
        }
        let defenderSquadID = this.SpawnFootGroupAtPoint(defenders, validatedDefenderSpawn, true, false, false);
        if defenderSquadID < 0 { return false; }
        let assaultStarted = this.TryStartConflictAssaultDrive(attackers, defenders, attackerCluster, defenderSquadID);
        if assaultStarted {
            StreetsOfNightCity_Logger.Log(
                " Conflict drive-in started | " + ToString(defenders.factionName) +
                " (squad " + ToString(defenderSquadID) + ") defending vs " + ToString(attackers.factionName) + " inbound"
            );
            return true;
        }
        StreetsOfNightCity_Logger.Log(
            " Conflict on foot | " + ToString(defenders.factionName) +
            " (squad " + ToString(defenderSquadID) + ") defending vs " + ToString(attackers.factionName) + " arriving on foot"
        );
        let validatedAttackerSpawn = this.ValidateSpawnPoint(attackerCluster, minDist, maxDist, true, false, true);
        if !validatedAttackerSpawn.isValid {
            if this.settings.debugLogging { StreetsOfNightCity_Logger.Log(" Attacker spawn point rejected | reason: " + validatedAttackerSpawn.failureReason); }
            let defenderSquad = this.GetSquadByID(defenderSquadID);
            if IsDefined(defenderSquad) { this.DespawnSquad(defenderSquad); ArrayRemove(this.activePatrols, defenderSquad); }
            return false;
        }
        let attackerSquadID = this.SpawnFootGroupAtPoint(attackers, validatedAttackerSpawn, true, false, false);
        if attackerSquadID < 0 {
            let defenderSquad = this.GetSquadByID(defenderSquadID);
            if IsDefined(defenderSquad) { this.DespawnSquad(defenderSquad); ArrayRemove(this.activePatrols, defenderSquad); }
            return false;
        }
        let forceCombat = new StreetsOfNightCity_ConflictStartCallback();
        forceCombat.defenderSquadID = defenderSquadID;
        forceCombat.attackerSquadID = attackerSquadID;
        forceCombat.systemInstance = this;
        GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(forceCombat, 1.5);
        StreetsOfNightCity_Logger.Log(
            " Conflict spawned | " + ToString(defenders.factionName) +
            " (squad " + ToString(defenderSquadID) + ")" +
            " vs " + ToString(attackers.factionName) +
            " (squad " + ToString(attackerSquadID) + ")"
        );
        return true;
    }
    private func FindConflictClusterPoint(anchor: Vector4, avoidPoint: Vector4, playerPos: Vector4, minDist: Float, maxDist: Float, minPlayerDist: Float, maxPlayerDist: Float) -> Vector4 {
        let gi = this.GetGameInstance();
        let aiNavSys = GameInstance.GetAINavigationSystem(gi);
        let player = GetPlayer(gi);
        let attempts = 0;
        while attempts < 10 {
            let angle = RandRangeF(0.0, Pi() * 2.0);
            let distance = RandRangeF(minDist, maxDist);
            let testPoint = anchor;
            testPoint.X += CosF(angle) * distance;
            testPoint.Y += SinF(angle) * distance;
            let testPlayerDist = Vector4.Distance2D(testPoint, playerPos);
            if Vector4.Distance(testPoint, avoidPoint) >= minDist && testPlayerDist >= minPlayerDist && testPlayerDist <= maxPlayerDist {
                let navResult = aiNavSys.FindPointInBoxForCharacter(testPoint, new Vector4(5.0, 5.0, 50.0, 1.0), player);
                if Equals(navResult.status, worldNavigationRequestStatus.OK) {
                    let groundPoint = this.FindGroundBeneath(navResult.point);
                    if this.IsValidSpawnPoint(groundPoint) {
                        let heightDiff = AbsF(navResult.point.Z - groundPoint.Z);
                        if heightDiff <= 3.0 {
                            let groundPlayerDist = Vector4.Distance2D(groundPoint, playerPos);
                            if groundPlayerDist >= minPlayerDist && groundPlayerDist <= maxPlayerDist {
                                if !this.IsDefinitelyIndoor(groundPoint) {
                                    if this.ValidateConflictSpawnPoint(groundPoint) {
                                        let clusterSpatial = GameInstance.GetSpatialQueriesSystem(gi);
                                        let losStart = anchor;
                                        losStart.Z += 1.2;
                                        let losEnd = groundPoint;
                                        losEnd.Z += 1.2;
                                        let losResult: TraceResult;
                                        let clusterBlocked = false;
                                        let anchorDist = Vector4.Distance(anchor, groundPoint);
                                        if clusterSpatial.SyncRaycastByCollisionGroup(losStart, losEnd, n"Static", losResult, false, false) {
                                            let hitD = Vector4.Distance(losStart, Vector4.Vector3To4(losResult.position));
                                            if hitD > 2.0 && hitD < (anchorDist - 2.0) { clusterBlocked = true; }
                                        }
                                        if !clusterBlocked {
                                            let camDist = Vector4.Distance2D(groundPoint, playerPos);
                                            if !this.IsPointCameraVisible(groundPoint, camDist) {
                                                return groundPoint;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            attempts += 1;
        }
        return new Vector4(0.0, 0.0, 0.0, 0.0);
    }
    private func SelectRecordForSquadMember(faction: ref<SONC_FactionProfile>, indexInSquad: Int32, isAmbient: Bool) -> TweakDBID {
        let record: TweakDBID;
        let gruntCount = ArraySize(faction.standardGrunts);
        let specialistPools: array<array<TweakDBID>>;
        if ArraySize(faction.meleeSpecialists) > 0 { ArrayPush(specialistPools, faction.meleeSpecialists); }
        if ArraySize(faction.rangedSpecialists) > 0 { ArrayPush(specialistPools, faction.rangedSpecialists); }
        if ArraySize(faction.netrunnerSpecialists) > 0 { ArrayPush(specialistPools, faction.netrunnerSpecialists); }
        if indexInSquad < 2 {
            if gruntCount > 0 {
                record = faction.standardGrunts[RandRange(0, gruntCount)];
            } else if ArraySize(specialistPools) > 0 {
                let firstPool = specialistPools[0];
                record = firstPool[RandRange(0, ArraySize(firstPool))];
            } else if ArraySize(faction.elitePool) > 0 {
                record = faction.elitePool[RandRange(0, ArraySize(faction.elitePool))];
            }
        } else {
            if ArraySize(specialistPools) > 0 && RandRange(0, 100) < 50 {
                let selectedPool = specialistPools[RandRange(0, ArraySize(specialistPools))];
                record = selectedPool[RandRange(0, ArraySize(selectedPool))];
            } else if gruntCount > 0 {
                record = faction.standardGrunts[RandRange(0, gruntCount)];
            } else if ArraySize(faction.elitePool) > 0 {
                record = faction.elitePool[RandRange(0, ArraySize(faction.elitePool))];
            }
        }
        let includeElites: Bool;
        let eliteChance: Int32;
        if isAmbient {
            includeElites = this.settings.ambientIncludeElites;
            eliteChance = 5;
        } else {
            includeElites = true;
            eliteChance = this.settings.immersiveEliteMemberChance;
        }
        if includeElites && RandRange(0, 100) < eliteChance && ArraySize(faction.elitePool) > 0 {
            record = faction.elitePool[RandRange(0, ArraySize(faction.elitePool))];
        }
        if this.IsPoliceRecord(record) && this.IsPlayerInNoPoliceZone() {
            if ArraySize(faction.standardGrunts) > 0 {
                record = this.PickNonPoliceRecord(faction.standardGrunts);
            }
            if this.IsPoliceRecord(record) && ArraySize(faction.elitePool) > 0 {
                record = this.PickNonPoliceRecord(faction.elitePool);
            }
        }
        return record;
    }
    // Returns the new squad ID, or -1 if no crew could be seated (the vehicle
    // is deleted in that case). Callers that do not need the ID may ignore it.
    public func SpawnAndMountVehicleSquad(vehicle: wref<VehicleObject>, faction: ref<SONC_FactionProfile>, isHunter: Bool) -> Int32 {
        let gi = this.GetGameInstance();
        let vehicleRecord = TweakDBInterface.GetVehicleRecord(vehicle.GetRecordID());
        let vehicleID = vehicle.GetEntityID();
        let isBike = false;
        if IsDefined(vehicleRecord) {
            if Equals(vehicleRecord.Type().Type(), gamedataVehicleType.Bike) { isBike = true; }
        }
        let availableSeats: array<CName>;
        if isBike {
            availableSeats = [n"seat_front_left"];
        } else {
            let allSeats: array<CName> = [n"seat_front_left", n"seat_front_right", n"seat_back_left", n"seat_back_right"];
            for seatName in allSeats {
                if !VehicleComponent.IsSlotOccupied(gi, vehicleID, seatName) {
                    ArrayPush(availableSeats, seatName);
                }
            }
        }
        // Clamp low: if the config ever hands back 0 the vehicle spawns with no
        // crew and gets deleted a line later, so no squad ever appears.
        let desiredSize = Min(Max(1, this.settings.vehicleCrewSize), ArraySize(availableSeats));
        if desiredSize == 0 {
            GameInstance.GetDynamicEntitySystem().DeleteEntity(vehicleID);
            return -1;
        }
        let vehiclePos = vehicle.GetWorldPosition();
        if !this.PassesSpawnSafetyChecks(vehiclePos) {
            GameInstance.GetDynamicEntitySystem().DeleteEntity(vehicle.GetEntityID());
            return -1;
        }
        let squad = this.CreateSquad(vehiclePos);
        squad.vehicleEntityID = vehicleID;
        squad.factionName = faction.factionName;
        squad.isHunter = isHunter;
        let groundCheck = this.FindGroundBeneath(vehiclePos);
        let i = 0;
        while i < desiredSize {
            let seatName = availableSeats[i];
            let isDriver = Equals(seatName, n"seat_front_left");
            let record = this.SelectRecordForSquadMember(faction, i, false);
            let rolls = 0;
            while rolls < 8 && !SONC_RecordCanRideVehicle(record) {
                record = this.SelectRecordForSquadMember(faction, i, false);
                rolls += 1;
            }
            if this.IsValidSpawnPoint(groundCheck) && SONC_RecordCanRideVehicle(record) {
                let heightDiff = AbsF(vehiclePos.Z - groundCheck.Z);
                if heightDiff <= 5.0 {
                    let spec = this.GetEntitySpec();
                    spec.recordID = record;
                    spec.position = vehiclePos;
                    spec.alwaysSpawned = true;
                    spec.persistState = false;
                    spec.persistSpawn = false;
                    ArrayPush(spec.tags, n"SONC_NPC");
                    ArrayPush(spec.tags, n"PreventPersistence");
                    ArrayPush(spec.tags, n"IgnorePersistency");
                    ArrayPush(spec.tags, n"DynamicEntity");
                    let npcID = GameInstance.GetDynamicEntitySystem().CreateEntity(spec);
                    this.ReturnEntitySpec(spec);
                    if EntityID.IsDefined(npcID) {
                        ArrayPush(squad.squadEntityIDs, npcID);
                        if isDriver { squad.driverID = npcID; }
                        let mountingFacility = GameInstance.GetMountingFacility(gi);
                        let slotId = new MountingSlotId(seatName);
                        let request = new MountingRequest();
                        request.lowLevelMountingInfo = new MountingInfo(npcID, vehicleID, slotId);
                        request.mountData.isInstant = true;
                        mountingFacility.Mount(request);
                    }
                }
            }
            i += 1;
        }
        if ArraySize(squad.squadEntityIDs) > 0 {
            ArrayPush(this.activePatrols, squad);
            this.AddToPatrolCounts(squad);
            let attCallback = new StreetsOfNightCity_ConsolidatedAttitudeCallback();
            attCallback.squadID = squad.squadID;
            attCallback.factionName = squad.factionName;
            attCallback.isConflict = false;
            attCallback.systemInstance = this;
            GameInstance.GetDelaySystem(gi).DelayCallback(attCallback, 1.0);
            if EntityID.IsDefined(squad.driverID) {
                let aiCallback = new StreetsOfNightCity_SetupVehicleAICallback();
                aiCallback.driverID = squad.driverID;
                aiCallback.squadIDs = squad.squadEntityIDs;
                aiCallback.factionName = squad.factionName;
                aiCallback.systemInstance = this;
                GameInstance.GetDelaySystem(gi).DelayCallback(aiCallback, 2.0);
            }
            if SONC_MilitaryTacticsEngine.IsMilitary(squad.factionName) {
                let tacticsDaemon = new SONC_MilitaryTacticsDaemon();
                tacticsDaemon.squadID = squad.squadID;
                tacticsDaemon.faction = squad.factionName;
                tacticsDaemon.systemInstance = this;
                GameInstance.GetDelaySystem(gi).DelayCallback(tacticsDaemon, 15.0);
            }
            return squad.squadID;
        }
        GameInstance.GetDynamicEntitySystem().DeleteEntity(vehicleID);
        return -1;
    }
    private func SpawnMechanicalSquad(faction: ref<SONC_FactionProfile>, squad: ref<SONC_PatrolSquad>, centerValidation: ref<SONC_ValidatedSpawnPoint>, isConflict: Bool, isAmbient: Bool) -> Void {
        let gi = this.GetGameInstance();
        let player = GetPlayer(gi);
        if !IsDefined(player) { return; }
        let playerPos = player.GetWorldPosition();
        let center = centerValidation.position;
        let camSysMech = GameInstance.GetCameraSystem(gi);
        let camTransformMech = new Transform(new Vector4(0.0, 0.0, 0.0, 0.0), new Quaternion(0.0, 0.0, 0.0, 1.0));
        camSysMech.GetActiveCameraWorldTransform(camTransformMech);
        let fovMech = camSysMech.GetActiveCameraFOV();
        let aspectRatioMech = camSysMech.GetAspectRatio();
        let count: Int32 = RandRange(this.settings.ambientMinDroneGroupSize, this.settings.ambientMaxDroneGroupSize + 1);
        if count <= 0 {
            ArrayRemove(this.activePatrols, squad);
            this.RemoveFromPatrolCounts(squad);
            return;
        }
        let spawnedCount = 0;
        let attemptNum = 0;
        let totalIter = 0;
        let mechRejGround = 0;
        let mechRejZone = 0;
        let mechRejClear = 0;
        let mechRejNear = 0;
        let mechRejView = 0;
        let mechRejCreate = 0;
        let maxAttempts = count * 5;
        let maxTotalIter = maxAttempts * 6;
        let dronePool = this.FilterPoliceRecords(this.GetDronePoolForFaction(faction.factionName));
        if ArraySize(dronePool) == 0 {
            ArrayRemove(this.activePatrols, squad);
            this.RemoveFromPatrolCounts(squad);
            return;
        }
        while spawnedCount < count && attemptNum < maxAttempts && totalIter < maxTotalIter {
            totalIter += 1;
            let angle = (Cast<Float>(spawnedCount) / Cast<Float>(count)) * (Pi() * 2.0);
            let radius = RandRangeF(3.0, 8.0);
            let spawnPos = center;
            spawnPos.X += CosF(angle) * radius;
            spawnPos.Y += SinF(angle) * radius;
            let record = dronePool[RandRange(0, ArraySize(dronePool))];
            let isFlyingUnit = Equals(ClassifyMechanical(record), SONC_MechanicalType.FlyingDrone);
            let posOK = true;
            if isFlyingUnit {
                spawnPos.Z += RandRangeF(5.0, 15.0);
            } else {
                let mechGround = this.FindGroundBeneath(spawnPos);
                if this.IsValidSpawnPoint(mechGround) {
                    spawnPos = mechGround;
                } else {
                    posOK = false;
                    mechRejGround += 1;
                }
            }
            let passesZone = posOK && this.PassesSpawnSafetyChecks(spawnPos);
            if !passesZone {
                if posOK { mechRejZone += 1; }
            } else {
                attemptNum += 1;
                let hasDroneClearance = true;
                if isFlyingUnit { hasDroneClearance = this.HasMinWallClearance(spawnPos, 2.0); }
                let mechPlaceOK = hasDroneClearance && this.IsValidSpawnPoint(spawnPos) && !this.IsDefinitelyIndoor(spawnPos);
                if !mechPlaceOK { mechRejClear += 1; }
                if mechPlaceOK {
                    let finalDistance = Vector4.Distance(spawnPos, playerPos);
                    let minDist = this.settings.ambientMinSpawnDist;
                    let inViewMech = false;
                    if isConflict {
                        minDist = 15.0;
                    } else {
                        inViewMech = finalDistance < 500.0 && SONC_IsPointInCameraView(gi, spawnPos, camTransformMech, fovMech, aspectRatioMech, 500.0, false);
                    }
                    if finalDistance < minDist { mechRejNear += 1; }
                    if finalDistance >= minDist && inViewMech { mechRejView += 1; }
                    if finalDistance >= minDist && !inViewMech {
                        let spec = this.GetEntitySpec();
                        spec.recordID = record;
                        spec.position = spawnPos;
                        spec.alwaysSpawned = true;
                        spec.persistState = false;
                        spec.persistSpawn = false;
                        ArrayPush(spec.tags, n"SONC_NPC");
                        if isFlyingUnit { ArrayPush(spec.tags, n"SONC_Drone"); } else { ArrayPush(spec.tags, n"SONC_Mech"); }
                        ArrayPush(spec.tags, n"PreventPersistence");
                        ArrayPush(spec.tags, n"IgnorePersistency");
                        ArrayPush(spec.tags, n"DynamicEntity");
                        let id = GameInstance.GetDynamicEntitySystem().CreateEntity(spec);
                        this.ReturnEntitySpec(spec);
                        if !EntityID.IsDefined(id) { mechRejCreate += 1; }
                        if EntityID.IsDefined(id) {
                            ArrayPush(squad.squadEntityIDs, id);
                            spawnedCount += 1;
                            if isFlyingUnit {
                                let dronePatrol = new SONC_DronePatrolCallback();
                                dronePatrol.npcID = id;
                                dronePatrol.centerPos = center;
                                GameInstance.GetDelaySystem(gi).DelayCallback(dronePatrol, 1.5);
                            }
                        }
                    }
                }
            }
        }
        if isConflict && ArraySize(squad.squadEntityIDs) == 0 {
            StreetsOfNightCity_Logger.Log(s"[CONFLICT] MECHDIAG none placed | want: \(ToString(count)) iter: \(ToString(totalIter)) rejGround: \(ToString(mechRejGround)) rejZone: \(ToString(mechRejZone)) rejClear: \(ToString(mechRejClear)) rejNear: \(ToString(mechRejNear)) rejView: \(ToString(mechRejView)) rejCreate: \(ToString(mechRejCreate))");
        }
        if ArraySize(squad.squadEntityIDs) > 0 {
            let attCallback = new StreetsOfNightCity_ConsolidatedAttitudeCallback();
            attCallback.squadID = squad.squadID;
            attCallback.factionName = faction.factionName;
            attCallback.isConflict = isConflict;
            attCallback.isAmbient = isAmbient;
            attCallback.systemInstance = this;
            GameInstance.GetDelaySystem(gi).DelayCallback(attCallback, 0.5);
        }
    }
    private func SpawnSquadMembers(faction: ref<SONC_FactionProfile>, squad: ref<SONC_PatrolSquad>, centerValidation: ref<SONC_ValidatedSpawnPoint>, isConflict: Bool, isAmbient: Bool) -> Void {
        let gi = this.GetGameInstance();
        let player = GetPlayer(gi);
        if !IsDefined(player) { return; }
        let playerPos = player.GetWorldPosition();
        let center = centerValidation.position;
        let minSafeDistance = centerValidation.distanceToPlayer * 0.8;
        let count: Int32;
        if isAmbient {
            if squad.isMechanical {
                count = RandRange(this.settings.ambientMinDroneGroupSize, this.settings.ambientMaxDroneGroupSize + 1);
            } else {
                count = 1;
            }
        } else if isConflict {
            count = RandRange(this.settings.conflictMinSquadSize, this.settings.conflictMaxSquadSize + 1);
        } else {
            count = RandRange(this.settings.immersiveMinSquadSize, this.settings.immersiveMaxSquadSize + 1);
        }
        if count <= 0 {
            ArrayRemove(this.activePatrols, squad);
            this.RemoveFromPatrolCounts(squad);
            return;
        }
        let aiNavSys = GameInstance.GetAINavigationSystem(gi);
        let validatedCount = 0;
        let maxAttempts = count * 8;
        if maxAttempts > 48 { maxAttempts = 48; }
        let attemptNum = 0;
        let totalIter = 0;
        let maxTotalIter = maxAttempts * 6;
        let validatedPositions: array<ref<SONC_ValidatedSpawnPoint>>;
        while validatedCount < count && attemptNum < maxAttempts && totalIter < maxTotalIter {
            totalIter += 1;
            let angle = (Cast<Float>(validatedCount) / Cast<Float>(count)) * (Pi() * 2.0);
            let radius = RandRangeF(2.0, 12.0);
            let roughPos = center;
            roughPos.X += CosF(angle) * radius;
            roughPos.Y += SinF(angle) * radius;
            let navResult = aiNavSys.FindPointInBoxForCharacter(roughPos, new Vector4(15.0, 15.0, 50.0, 1.0), player);
            let zoneSkip = false;
            if Equals(navResult.status, worldNavigationRequestStatus.OK) {
                let candidatePos = navResult.point;
                if this.IsValidSpawnPoint(candidatePos) {
                    let groundPos = this.FindGroundBeneath(candidatePos);
                    let groundIsValid = this.IsValidSpawnPoint(groundPos);
                    let heightDiff = AbsF(candidatePos.Z - groundPos.Z);
                    let notFloating = heightDiff <= 4.0;
                    let useGround = groundIsValid && notFloating;
                    if useGround {
                        let memberDist = Vector4.Distance(groundPos, playerPos);
                        let memberMinDist = MaxF(minSafeDistance * 0.75, 25.0);
                        if memberDist >= memberMinDist {
                            let interiorTypes: array<ESecurityAreaType>;
                            ArrayPush(interiorTypes, ESecurityAreaType.SAFE);
                            ArrayPush(interiorTypes, ESecurityAreaType.DISABLED);
                            ArrayPush(interiorTypes, ESecurityAreaType.DANGEROUS);
                            if SONC_IsPointInAnyLoadedSecurityAreaRadius(groundPos, interiorTypes, true) {
                                zoneSkip = true;
                            } else {
                                let memberValidation = new SONC_ValidatedSpawnPoint();
                                memberValidation.position = groundPos;
                                memberValidation.isValid = true;
                                memberValidation.distanceToPlayer = memberDist;
                                memberValidation.orientation = this.SafeOrientationFor(groundPos);
                                ArrayPush(validatedPositions, memberValidation);
                                validatedCount += 1;
                            }
                        }
                    }
                }
            }
            if !zoneSkip { attemptNum += 1; }
        }
        if ArraySize(validatedPositions) == 0 {
            if this.settings.debugLogging {
                StreetsOfNightCity_Logger.Log(" No valid positions | Faction: " + ToString(faction.factionName));
            }
            ArrayRemove(this.activePatrols, squad);
            this.RemoveFromPatrolCounts(squad);
            return;
        }
        let memberIndex = 0;
        for validatedPos in validatedPositions {
            let record = this.SelectRecordForSquadMember(faction, memberIndex, isAmbient);
            let queuedSpawn = new SONC_QueuedSpawn();
            queuedSpawn.record = record;
            queuedSpawn.validatedPosition = validatedPos;
            queuedSpawn.factionName = faction.factionName;
            queuedSpawn.isAmbient = isAmbient;
            queuedSpawn.isConflict = isConflict;
            queuedSpawn.squadID = squad.squadID;
            if memberIndex == 0 {
                if ArraySize(this.m_spawnQueue) == 0 {
                    queuedSpawn.isFirstInSquad = true;
                } else {
                    let lastQueued = this.m_spawnQueue[ArraySize(this.m_spawnQueue) - 1];
                    queuedSpawn.isFirstInSquad = (lastQueued.squadID != squad.squadID);
                }
            } else {
                queuedSpawn.isFirstInSquad = false;
            }
            ArrayPush(this.m_spawnQueue, queuedSpawn);
            memberIndex += 1;
        }
        if this.settings.debugLogging {
            let squadModeLog: String;
            if isAmbient { squadModeLog = "AMBIENT"; } else { squadModeLog = "IMMERSIVE"; }
            StreetsOfNightCity_Logger.Log(
                " " + ToString(faction.factionName) +
                " | Count: " + ToString(ArraySize(validatedPositions)) +
                " | Mode: " + squadModeLog +
                " | Attempts: " + ToString(attemptNum)
            );
        }
        let safeDelay = Cast<Float>(ArraySize(validatedPositions)) * 0.5 + 1.0;
        let attCallback = new StreetsOfNightCity_ConsolidatedAttitudeCallback();
        attCallback.squadID = squad.squadID;
        attCallback.factionName = faction.factionName;
        attCallback.isConflict = isConflict;
        attCallback.isAmbient = isAmbient;
        attCallback.systemInstance = this;
        GameInstance.GetDelaySystem(gi).DelayCallback(attCallback, safeDelay);
        let validateCallback = new SONC_ValidateSquadCallback();
        validateCallback.squadID = squad.squadID;
        validateCallback.systemInstance = this;
        GameInstance.GetDelaySystem(gi).DelayCallback(validateCallback, safeDelay + 4.0);
    }
    private func GetDronePoolForFaction(factionName: CName) -> array<TweakDBID> {
        if Equals(factionName, n"Arasaka") { return this.arasakaDrones; }
        if Equals(factionName, n"Militech") { return this.militechDrones; }
        if Equals(factionName, n"Security") { return this.securityDrones; }
        if Equals(factionName, n"NCPD") { return this.securityDrones; }
        if Equals(factionName, n"Barghest") { return this.barghestDrones; }
        if Equals(factionName, n"KangTao") { return this.kangTaoDrones; }
        if Equals(factionName, n"CitySurveillance") { return this.securityDrones; }
        if Equals(factionName, n"Maelstrom") { return this.maelstromDrones; }
        if Equals(factionName, n"VoodooBoys") { return this.voodooBoysDrones; }
        if Equals(factionName, n"Wraiths") { return this.wraithDrones; }
        return [];
    }
    private func GetMechPoolForFaction(factionName: CName) -> array<TweakDBID> {
        if Equals(factionName, n"Arasaka") { return this.arasakaMechs; }
        if Equals(factionName, n"Militech") { return this.militechMechs; }
        if Equals(factionName, n"Security") { return this.securityMechs; }
        if Equals(factionName, n"Barghest") { return this.barghestMechs; }
        if Equals(factionName, n"KangTao") { return this.kangTaoMechs; }
        return [];
    }
    private func TrySpawnRoamingMechPatrol(faction: ref<SONC_FactionProfile>, opt isAmbient: Bool) -> Bool {
        if this.IsPoliceBlockedHere(faction.factionName) { return false; }
        if !isAmbient && !this.settings.immersiveEnableElites { return false; }
        let player = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) { return false; }
        let playerPos = player.GetWorldPosition();
        let districtName = this.GetPlayerDistrictName(player);
        let isRural = this.IsRuralArea(districtName);
        let minDist: Float;
        let maxDist: Float;
        if isRural {
            minDist = this.settings.badlandsMinSpawnDist;
            maxDist = this.settings.badlandsMaxSpawnDist;
        } else {
            minDist = this.settings.immersiveCityMinSpawnDist;
            maxDist = this.settings.immersiveCityMaxSpawnDist;
        }
        let mechAnchor = this.GetSpawnSearchAnchor(player);
        let validatedSpawn = this.FindPedestrianSpawnPoint(mechAnchor, maxDist, minDist, !isAmbient);
        if !validatedSpawn.isValid { return false; }
        let spawnPoint = validatedSpawn.position;
        if !StreetsOfNightCity_IsOutdoorSpawnPoint(this.GetGameInstance(), spawnPoint) { return false; }
        if !this.PassesSpawnSafetyChecks(spawnPoint) { return false; }
        let pool: array<TweakDBID>;
        let isDrone = !isRural || RandRange(0, 100) < this.settings.immersiveDroneToMechRatio;
        if isDrone {
            pool = this.FilterPoliceRecords(this.GetDronePoolForFaction(faction.factionName));
        } else {
            pool = this.FilterPoliceRecords(this.GetMechPoolForFaction(faction.factionName));
        }
        if ArraySize(pool) == 0 { return false; }
        let unitID = pool[RandRange(0, ArraySize(pool))];
        let spec = this.GetEntitySpec();
        spec.recordID = unitID;
        spec.position = spawnPoint;
        spec.alwaysSpawned = true;
        spec.persistState = false;
        spec.persistSpawn = false;
        let tags: array<CName> = [n"SONC_NPC"];
        if isDrone { ArrayPush(tags, n"SONC_Drone"); } else { ArrayPush(tags, n"SONC_Mech"); }
        ArrayPush(tags, n"PreventPersistence");
        ArrayPush(tags, n"IgnorePersistency");
        ArrayPush(tags, n"DynamicEntity");
        spec.tags = tags;
        let entityID = GameInstance.GetDynamicEntitySystem().CreateEntity(spec);
        this.ReturnEntitySpec(spec);
        if !EntityID.IsDefined(entityID) { return false; }
        let squad = this.CreateSquad(spawnPoint);
        squad.factionName = faction.factionName;
        squad.isMechanical = true;
        squad.isAmbient = isAmbient;
        ArrayPush(squad.squadEntityIDs, entityID);
        ArrayPush(this.activePatrols, squad);
        this.AddToPatrolCounts(squad);
        let attCallback = new StreetsOfNightCity_ConsolidatedAttitudeCallback();
        attCallback.squadID = squad.squadID;
        attCallback.factionName = squad.factionName;
        attCallback.isConflict = false;
        attCallback.isAmbient = isAmbient;
        attCallback.systemInstance = this;
        GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(attCallback, 0.5);
        return true;
    }
    public func IsDefinitelyIndoor(point: Vector4) -> Bool {
        let interiorTypes: array<ESecurityAreaType>;
        ArrayPush(interiorTypes, ESecurityAreaType.SAFE);
        if SONC_IsPointInAnyLoadedSecurityAreaRadius(point, interiorTypes, true) { return true; }
        let spatialSystem = GameInstance.GetSpatialQueriesSystem(this.GetGameInstance());
        let traceResult: TraceResult;
        let skyStart = point;
        skyStart.Z += 2.0;
        let skyEnd = skyStart;
        skyEnd.Z += 40.0;
        if !spatialSystem.SyncRaycastByCollisionGroup(skyStart, skyEnd, n"Static", traceResult, false, false) {
            return false;
        }
        let wallCount = 0;
        let testHeight = point;
        testHeight.Z += 1.5;
        let directions: array<Vector4> = [
            new Vector4(1.0, 0.0, 0.0, 0.0), new Vector4(-1.0, 0.0, 0.0, 0.0),
            new Vector4(0.0, 1.0, 0.0, 0.0), new Vector4(0.0, -1.0, 0.0, 0.0)
        ];
        for direction in directions {
            let rayEnd = testHeight + (direction * 8.0);
            if spatialSystem.SyncRaycastByCollisionGroup(testHeight, rayEnd, n"Static", traceResult, false, false) {
                let hitDistSq = Vector4.DistanceSquared(testHeight, Vector4.Vector3To4(traceResult.position));
                if hitDistSq < 64.0 { wallCount += 1; }
            }
        }
        return wallCount >= 3;
    }
    private func IsStrictlyIndoors(point: Vector4) -> Bool {
        let wallCount = this.CheckFullEnclosure(point, GameInstance.GetSpatialQueriesSystem(this.GetGameInstance()));
        if wallCount >= 7 { return true; }
        let interiorTypes: array<ESecurityAreaType>;
        ArrayPush(interiorTypes, ESecurityAreaType.SAFE);
        if SONC_IsPointInAnyLoadedSecurityAreaRadius(point, interiorTypes, true) { return true; }
        return false;
    }
    private func CheckFullEnclosure(point: Vector4, spatialSystem: ref<SpatialQueriesSystem>) -> Int32 {
        let traceResult: TraceResult;
        let testHeight = point;
        testHeight.Z += 1.5;
        let directions: array<Vector4> = [
            new Vector4(1.0, 0.0, 0.0, 0.0), new Vector4(-1.0, 0.0, 0.0, 0.0),
            new Vector4(0.0, 1.0, 0.0, 0.0), new Vector4(0.0, -1.0, 0.0, 0.0),
            new Vector4(0.7, 0.7, 0.0, 0.0), new Vector4(-0.7, 0.7, 0.0, 0.0),
            new Vector4(0.7, -0.7, 0.0, 0.0), new Vector4(-0.7, -0.7, 0.0, 0.0)
        ];
        let wallCount = 0;
        for direction in directions {
            let rayEnd = testHeight + (direction * 8.0);
            if spatialSystem.SyncRaycastByCollisionGroup(testHeight, rayEnd, n"Static", traceResult, false, false) {
                let hitDist = Vector4.Distance(testHeight, Vector4.Vector3To4(traceResult.position));
                if hitDist < 8.0 { wallCount += 1; }
            }
        }
        return wallCount;
    }

    private func ManageActiveGroups() -> Void {
        let gi = this.GetGameInstance();
        let player = GetPlayer(gi);
        if !IsDefined(player) { return; }
        let playerPos    = player.GetWorldPosition();
        let currentTime  = EngineTime.ToFloat(GameInstance.GetSimTime(gi));
        let districtName = this.GetPlayerDistrictName(player);
        let isBadlands   = this.IsRuralArea(districtName);
        let conflictCeiling = this.settings.conflictMaxDurationSec;
        let needsRebuild = false;
        let i = ArraySize(this.activePatrols) - 1;
        while i >= 0 {
            let squad = this.activePatrols[i];
            if IsDefined(squad) {
                let livingCount = 0;
                let squadPos    = squad.lastKnownPosition;
                let isInCombat  = false;
                let m = ArraySize(squad.squadEntityIDs) - 1;
                while m >= 0 {
                    let memberID = squad.squadEntityIDs[m];
                    let member = GameInstance.FindEntityByID(gi, memberID) as ScriptedPuppet;
                    if IsDefined(member) {
                        if member.IsDead() {
                            ArrayErase(squad.squadEntityIDs, m);
                        } else {
                            livingCount += 1;
                            if livingCount == 1 { squadPos = member.GetWorldPosition(); }
                            let memberCombat = Equals(member.GetHighLevelStateFromBlackboard(), gamedataNPCHighLevelState.Combat);
                            if memberCombat { isInCombat = true; }
                            if this.settings.globalAlwaysNeutral && !squad.isConflict && memberCombat {
                                let npcAg = member.GetAttitudeAgent();
                                if IsDefined(npcAg) {
                                    npcAg.SetAttitudeTowards(player.GetAttitudeAgent(), EAIAttitude.AIA_Neutral);
                                }
                                let npcTr = member.GetTargetTrackerComponent();
                                if IsDefined(npcTr) { npcTr.ClearThreats(); }
                            }
                        }
                    } else {
                        let distToPlayer = Vector4.Distance2D(squad.lastKnownPosition, playerPos);
                        if distToPlayer > this.MISSING_MEMBER_KEEP_DIST {
                            ArrayErase(squad.squadEntityIDs, m);
                        } else if (currentTime - squad.spawnTime) > this.MISSING_MEMBER_KEEP_SEC {
                            ArrayErase(squad.squadEntityIDs, m);
                        } else {
                            livingCount += 1;
                        }
                    }
                    m -= 1;
                }
                if livingCount == 0 && EntityID.IsDefined(squad.vehicleEntityID) {
                    let vehicle = GameInstance.FindEntityByID(gi, squad.vehicleEntityID);
                    if IsDefined(vehicle) { livingCount += 1; squadPos = vehicle.GetWorldPosition(); }
                }
                if livingCount == 0 {
                    let hasPending = squad.pendingVerifyCount > 0;
                    for queued in this.m_spawnQueue {
                        if queued.squadID == squad.squadID { hasPending = true; }
                    }
                    let emptyGrace: Float;
                    if squad.isConflict { emptyGrace = this.EMPTY_CONFLICT_GRACE_SEC; } else { emptyGrace = this.EMPTY_SQUAD_GRACE_SEC; }
                    let squadAge   = currentTime - squad.spawnTime;
                    if !hasPending && squadAge >= emptyGrace {
                        this.UnregisterSquad(squad);
                        ArrayErase(this.activePatrols, i);
                    }
                } else {
                    squad.lastKnownPosition = squadPos;
                    let distToPlayer  = Vector4.Distance(squadPos, playerPos);
                    let lifetime      = currentTime - squad.spawnTime;
                    let shouldDespawn = false;
                    let despawnReason = "";
                    let spawnGraceSec: Float = this.settings.squadSpawnGraceSec;
                    let inGracePeriod = lifetime < spawnGraceSec;
                    if squad.isAmbient {
                        if !inGracePeriod && distToPlayer > this.settings.ambientDespawnDist {
                            shouldDespawn = true;
                            despawnReason = "Ambient: distance " + FloatToStringPrec(distToPlayer, 1) + "m";
                        }
                    } else {
                        let despawnDist: Float;
                        if isBadlands {
                            despawnDist = this.settings.badlandsDespawnDist;
                        } else {
                            despawnDist = this.settings.immersiveCityDespawnDist;
                        }
                        let combatCooldownSec: Float = this.settings.squadCombatCooldownSec;
                        if isInCombat { squad.lastCombatEndTime = currentTime; }
                        let recentlyInCombat = (currentTime - squad.lastCombatEndTime) < combatCooldownSec;
                        let effectiveDist: Float;
                        if isInCombat || recentlyInCombat { effectiveDist = despawnDist * 2.0; } else { effectiveDist = despawnDist; }
                        if !inGracePeriod && distToPlayer > effectiveDist {
                            shouldDespawn = true;
                            despawnReason = "Patrol: distance " + FloatToStringPrec(distToPlayer, 1) + "m";
                        }
                        let overCeiling = squad.isConflict && lifetime > conflictCeiling;
                        if !shouldDespawn && overCeiling {
                            shouldDespawn = true;
                            despawnReason = "Conflict: safety ceiling " + FloatToStringPrec(lifetime, 1) + "s";
                        }
                    }
                    if shouldDespawn && distToPlayer < this.DESPAWN_CAM_CHECK_DIST {
                        let camSysD = GameInstance.GetCameraSystem(gi);
                        let camTransformD = new Transform(new Vector4(0.0, 0.0, 0.0, 0.0), new Quaternion(0.0, 0.0, 0.0, 1.0));
                        camSysD.GetActiveCameraWorldTransform(camTransformD);
                        let fovD = camSysD.GetActiveCameraFOV();
                        let aspectD = camSysD.GetAspectRatio();
                        let visibleD = SONC_IsPointInCameraView(gi, squadPos, camTransformD, fovD, aspectD, 300.0, false);
                        if visibleD { shouldDespawn = false; }
                    }
                    if shouldDespawn {
                        if this.settings.debugLogging {
                            StreetsOfNightCity_Logger.Log("[DESPAWN] Squad " + ToString(squad.squadID) + " (" + ToString(squad.factionName) + ") | " + despawnReason);
                        }
                        this.DespawnSquad(squad);
                        ArrayErase(this.activePatrols, i);
                    }
                }
            } else {
                ArrayErase(this.activePatrols, i);
                needsRebuild = true;
            }
            i -= 1;
        }
        if needsRebuild { this.RebuildPatrolCounts(); }
    }
    public func DespawnSquad(squad: ref<SONC_PatrolSquad>) -> Void {
        if !IsDefined(squad) { return; }
        let i = ArraySize(this.m_patrolDaemons) - 1;
        while i >= 0 {
            let daemon = this.m_patrolDaemons[i];
            if IsDefined(daemon) {
                if daemon.m_squadID == squad.squadID {
                    daemon.Stop();
                    ArrayErase(this.m_patrolDaemons, i);
                }
            }
            i -= 1;
        }
        if IsDefined(squad) {
            this.RemoveFromPatrolCounts(squad);
            ArrayRemove(this.m_reinforcedSquadIDs, squad.squadID);
            let gi = this.GetGameInstance();
            for entID in squad.squadEntityIDs {
                this.UnregisterPlayerAggression(entID);
                SONC_SafeDeleteEntity(gi, entID);
            }
            SONC_SafeDeleteEntity(gi, squad.vehicleEntityID);
        }
    }
    private func UnregisterSquad(squad: ref<SONC_PatrolSquad>) -> Void {
        if !IsDefined(squad) { return; }
        let i = ArraySize(this.m_patrolDaemons) - 1;
        while i >= 0 {
            let daemon = this.m_patrolDaemons[i];
            if IsDefined(daemon) {
                if daemon.m_squadID == squad.squadID {
                    daemon.Stop();
                    ArrayErase(this.m_patrolDaemons, i);
                }
            }
            i -= 1;
        }
        this.RemoveFromPatrolCounts(squad);
        ArrayRemove(this.m_reinforcedSquadIDs, squad.squadID);
        let gi = this.GetGameInstance();
        for entID in squad.squadEntityIDs {
            this.UnregisterPlayerAggression(entID);
            SONC_SafeDeleteEntity(gi, entID);
        }
        SONC_SafeDeleteEntity(gi, squad.vehicleEntityID);
    }
    public func ClearAllPatrols() -> Void {
        while ArraySize(this.activePatrols) > 0 {
            let squad = this.activePatrols[0];
            this.DespawnSquad(squad);
            ArrayErase(this.activePatrols, 0);
        }
        this.m_cachedAmbHuman = 0;
        this.m_cachedAmbDrone = 0;
        this.m_cachedImmHuman = 0;
        this.m_cachedImmDrone = 0;
    }
public func EnforceSquadMemberFriendship(newMember: ref<ScriptedPuppet>, factionName: CName) -> Void {
        if !IsDefined(newMember) { return; }
        if Equals(factionName, n"Maelstrom_Royce") || Equals(factionName, n"Maelstrom_Brick") { return; }
        let newMemberID = newMember.GetEntityID();
        let newAttitude = newMember.GetAttitudeAgent();
        if !IsDefined(newAttitude) { return; }
        let gi = this.GetGameInstance();
        for patrol in this.activePatrols {
            if IsDefined(patrol) {
            if Equals(patrol.factionName, factionName) {
                for existingID in patrol.squadEntityIDs {
                    if existingID != newMemberID {
                        let existingNPC = GameInstance.FindEntityByID(gi, existingID) as ScriptedPuppet;
                        if IsDefined(existingNPC) && !existingNPC.IsDead() {
                            let existingAttitude = existingNPC.GetAttitudeAgent();
                            if IsDefined(existingAttitude) {
                                newAttitude.SetAttitudeTowards(existingAttitude, EAIAttitude.AIA_Friendly);
                                existingAttitude.SetAttitudeTowards(newAttitude, EAIAttitude.AIA_Friendly);
                            }
                        }
                    }
                }
            }
            }
        }
    }
    public func IsWithinPlayerHostilityRange(pos: Vector4) -> Bool {
        let player = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) { return false; }
        return Vector4.Distance(player.GetWorldPosition(), pos) <= this.settings.playerHostilityRadius;
    }
    public func MarkSquadWantsPlayerHostile(member: wref<ScriptedPuppet>) -> Void {
        let squad = this.FindSquadForMember(member);
        if IsDefined(squad) { squad.wantsPlayerHostile = true; }
    }
    public func DeterminePlayerAttitude(factionName: CName, isAmbient: Bool, npcAttitudeAgent: wref<AttitudeAgent>, player: wref<PlayerPuppet>) -> EAIAttitude {
        if isAmbient { return EAIAttitude.AIA_Neutral; }
        if this.settings.globalAlwaysNeutral {
            let wraithException = Equals(factionName, n"Wraiths") && this.settings.immersiveWraithsAlwaysHostile;
            if wraithException {
                StreetsOfNightCity_Logger.LogVerbose(s"[ATTITUDE] DeterminePlayerAttitude: Wraiths-always-hostile exception -> Hostile (globalAlwaysNeutral is ON).", this.settings);
                return EAIAttitude.AIA_Hostile;
            }
            return EAIAttitude.AIA_Neutral;
        }
        let wraithException2 = Equals(factionName, n"Wraiths") && this.settings.immersiveWraithsAlwaysHostile;
        if wraithException2 {
            StreetsOfNightCity_Logger.LogVerbose(s"[ATTITUDE] DeterminePlayerAttitude: Wraiths-always-hostile exception -> Hostile (globalAlwaysNeutral is OFF).", this.settings);
            return EAIAttitude.AIA_Hostile;
        }
        if IsDefined(npcAttitudeAgent) && IsDefined(player) {
            let defaultAttitude = npcAttitudeAgent.GetAttitudeTowards(player.GetAttitudeAgent());
            if Equals(defaultAttitude, EAIAttitude.AIA_Hostile) {
                StreetsOfNightCity_Logger.LogVerbose(s"[ATTITUDE] DeterminePlayerAttitude: faction \(ToString(factionName)) has vanilla Hostile default toward player and globalAlwaysNeutral is OFF -> Hostile.", this.settings);
                return EAIAttitude.AIA_Hostile;
            }
        }
        return EAIAttitude.AIA_Neutral;
    }
    public func SetSquadAttitudes(squadIDs: array<EntityID>, factionName: CName, isConflict: Bool, isAmbient: Bool) -> Void {
        let gi = this.GetGameInstance();
        let player = GetPlayer(gi);
        if !IsDefined(player) { return; }
        for id in squadIDs {
            let npc = GameInstance.FindEntityByID(gi, id) as ScriptedPuppet;
            if IsDefined(npc) && !npc.IsDead() {
                let alreadyExcluded = npc.HasTag(n"ICO_Exclude");
                if !alreadyExcluded { npc.AddTag(n"ICO_Exclude"); }
                let attAgent = npc.GetAttitudeAgent();
                if IsDefined(attAgent) {
                    let playerAttitude = EAIAttitude.AIA_Neutral;
                    if !isConflict {
                        playerAttitude = this.DeterminePlayerAttitude(factionName, isAmbient, attAgent, player);
                    }
                    if Equals(playerAttitude, EAIAttitude.AIA_Hostile) {
                        this.MarkSquadWantsPlayerHostile(npc);
                        if !this.IsWithinPlayerHostilityRange(npc.GetWorldPosition()) {
                            playerAttitude = EAIAttitude.AIA_Neutral;
                        }
                    }
                    attAgent.SetAttitudeTowards(player.GetAttitudeAgent(), playerAttitude);
                    if Equals(playerAttitude, EAIAttitude.AIA_Hostile) {
                        StreetsOfNightCity_Logger.LogVerbose(s"[SPAWN-ATTITUDE] SetSquadAttitudes: \(npc.GetDisplayName()) (faction \(ToString(factionName)), isConflict=\(ToString(isConflict)), isAmbient=\(ToString(isAmbient))) set Hostile toward player at spawn/squad-init.", this.settings);
                    } else {
                        let tracker = npc.GetTargetTrackerComponent();
                        if IsDefined(tracker) { tracker.ClearThreats(); }
                    }
                    for otherID in squadIDs {
                        if NotEquals(otherID, id) {
                            let other = GameInstance.FindEntityByID(gi, otherID) as ScriptedPuppet;
                            if IsDefined(other) && !other.IsDead() {
                                let otherAtt = other.GetAttitudeAgent();
                                if IsDefined(otherAtt) { attAgent.SetAttitudeTowards(otherAtt, EAIAttitude.AIA_Friendly); }
                            }
                        }
                    }
                    this.EnforceSquadMemberFriendship(npc, factionName);
                    if isAmbient {
                        for otherPatrol in this.activePatrols {
                            if IsDefined(otherPatrol) {
                            let diffFaction = !Equals(otherPatrol.factionName, factionName);
                            if otherPatrol.isAmbient && diffFaction {
                                for otherMemberID in otherPatrol.squadEntityIDs {
                                    let otherNpc = GameInstance.FindEntityByID(gi, otherMemberID) as ScriptedPuppet;
                                    if IsDefined(otherNpc) && !otherNpc.IsDead() {
                                        let otherAtt = otherNpc.GetAttitudeAgent();
                                        if IsDefined(otherAtt) {
                                            attAgent.SetAttitudeTowards(otherAtt, EAIAttitude.AIA_Neutral);
                                            otherAtt.SetAttitudeTowards(attAgent, EAIAttitude.AIA_Neutral);
                                        }
                                    }
                                }
                            }
                            }
                        }
                    }
                }
            }
        }
    }
    public func ShareThreatWithNearbyFriendlySquads(factionName: CName, position: Vector4, threat: wref<GameObject>) -> Void {
        if !IsDefined(threat) { return; }
        let gi = this.GetGameInstance();
        for squad in this.activePatrols {
            if IsDefined(squad) {
            if !Equals(squad.factionName, factionName) { } else {
                let dist = Vector4.Distance(squad.lastKnownPosition, position);
                if dist <= 40.0 {
                    for memberID in squad.squadEntityIDs {
                        let member = GameInstance.FindEntityByID(gi, memberID) as ScriptedPuppet;
                        if IsDefined(member) && !member.IsDead() {
                            let tracker = member.GetTargetTrackerComponent();
                            if IsDefined(tracker) {
                                let alreadyTracked = false;
                                for t in tracker.GetHostileThreats(false) {
                                    if Equals(t.entity, threat) { alreadyTracked = true; }
                                }
                                if !alreadyTracked {
                                    TargetTrackingExtension.InjectThreat(member, threat);
                                    let aiCtrl = member.GetAIControllerComponent();
                                    if IsDefined(aiCtrl) {
                                        aiCtrl.SendCommand(new AIInjectCombatThreatCommand());
                                        aiCtrl.SendCommand(new AIInjectCombatTargetCommand());
                                    }
                                }
                            }
                        }
                    }
                }
            }
            }
        }
    }
    private func IsCorpAlignedFaction(factionName: CName) -> Bool {
        if Equals(factionName, n"Arasaka")      { return true; }
        if Equals(factionName, n"Militech")     { return true; }
        if Equals(factionName, n"KangTao")      { return true; }
        if Equals(factionName, n"Security")     { return true; }
        if Equals(factionName, n"NCPD")         { return true; }
        if Equals(factionName, n"NetWatch")     { return true; }
        if Equals(factionName, n"Barghest")     { return true; }
        return false;
    }
    private func IsFactionEnabled(factionName: CName) -> Bool {
        if this.IsPoliceBlockedHere(factionName) { return false; }
        if Equals(factionName, n"Arasaka") { return this.settings.allowArasaka; }
        if Equals(factionName, n"Militech") { return this.settings.allowMilitech; }
        if Equals(factionName, n"KangTao") { return this.settings.allowKangTao; }
        if Equals(factionName, n"Security") || Equals(factionName, n"NCPD") || Equals(factionName, n"NetWatch") { return this.settings.allowSecurity; }
        if Equals(factionName, n"Maelstrom") || Equals(factionName, n"Maelstrom_Royce") || Equals(factionName, n"Maelstrom_Brick") { return this.settings.allowMaelstrom; }
        if Equals(factionName, n"TygerClaws_Yokai")  { return this.settings.allowTygerClawsYokai; }
        if Equals(factionName, n"TygerClaws_Kimen")  { return this.settings.allowTygerClawsKimen; }
        if Equals(factionName, n"Valentinos") { return this.settings.allowValentinos; }
        if Equals(factionName, n"SixthStreet") { return this.settings.allowSixthStreet; }
        if Equals(factionName, n"Animals") { return this.settings.allowAnimals; }
        if Equals(factionName, n"VoodooBoys") { return this.settings.allowVoodooBoys; }
        if Equals(factionName, n"Scavengers") { return this.settings.allowScavengers; }
        if Equals(factionName, n"TheMox") { return this.settings.allowMox; }
        if Equals(factionName, n"Wraiths") { return this.settings.allowWraiths; }
        if Equals(factionName, n"AfterlifeMercs") { return this.settings.allowAfterlifeMercs; }
        if Equals(factionName, n"Aldecaldos") { return this.settings.allowAldecaldos; }
        if Equals(factionName, n"Barghest") { return this.settings.allowBarghest; }
        if Equals(factionName, n"CitySurveillance") { return this.settings.allowCitySurveillance; }
        if Equals(factionName, n"Psycho") { return this.settings.allowPsycho; }
        return true;
    }
    private func InitializeDistrictMap() -> Void {
        this.m_districtNormalizationMap = [];
        let mapping: ref<SONC_DistrictMapping>;
        mapping = new SONC_DistrictMapping(); mapping.rawName = "Vista_Del_Rey"; mapping.normalized = "VistaDelRey"; ArrayPush(this.m_districtNormalizationMap, mapping);
        mapping = new SONC_DistrictMapping(); mapping.rawName = "Santo_Domingo"; mapping.normalized = "SantoDomingo"; ArrayPush(this.m_districtNormalizationMap, mapping);
        mapping = new SONC_DistrictMapping(); mapping.rawName = "Little_China"; mapping.normalized = "LittleChina"; ArrayPush(this.m_districtNormalizationMap, mapping);
        mapping = new SONC_DistrictMapping(); mapping.rawName = "Rancho_Coronado"; mapping.normalized = "RanchoCoronado"; ArrayPush(this.m_districtNormalizationMap, mapping);
        mapping = new SONC_DistrictMapping(); mapping.rawName = "Arasaka_Waterfront"; mapping.normalized = "ArasakaWaterfront"; ArrayPush(this.m_districtNormalizationMap, mapping);
        mapping = new SONC_DistrictMapping(); mapping.rawName = "North_Oak"; mapping.normalized = "NorthOak"; ArrayPush(this.m_districtNormalizationMap, mapping);
        mapping = new SONC_DistrictMapping(); mapping.rawName = "Charter_Hill"; mapping.normalized = "CharterHill"; ArrayPush(this.m_districtNormalizationMap, mapping);
        mapping = new SONC_DistrictMapping(); mapping.rawName = "Corpo_Plaza"; mapping.normalized = "CorpoPlaza"; ArrayPush(this.m_districtNormalizationMap, mapping);
        mapping = new SONC_DistrictMapping(); mapping.rawName = "TheGlen"; mapping.normalized = "Glen"; ArrayPush(this.m_districtNormalizationMap, mapping);
        mapping = new SONC_DistrictMapping(); mapping.rawName = "JapanTown"; mapping.normalized = "JapanTown"; ArrayPush(this.m_districtNormalizationMap, mapping);
        mapping = new SONC_DistrictMapping(); mapping.rawName = "West_Wind_Estate"; mapping.normalized = "WestWindEstate"; ArrayPush(this.m_districtNormalizationMap, mapping);
        mapping = new SONC_DistrictMapping(); mapping.rawName = "Coastview"; mapping.normalized = "Coastview"; ArrayPush(this.m_districtNormalizationMap, mapping);
        mapping = new SONC_DistrictMapping(); mapping.rawName = "Dogtown"; mapping.normalized = "Dogtown"; ArrayPush(this.m_districtNormalizationMap, mapping);
    }
    public func IsValidSpawnPoint(point: Vector4) -> Bool {
        if Vector4.IsXYZZero(point) { return false; }
        if point.Z < -100.0 || point.Z > 2000.0 { return false; }
        if AbsF(point.X) > 10000.0 || AbsF(point.Y) > 10000.0 { return false; }
        return true;
    }
    private func GenerateCircularSearchPoints(center: Vector4, minRadius: Float, maxRadius: Float, numPoints: Int32) -> array<Vector4> {
        let points: array<Vector4>;
        let angleStep = (Pi() * 2.0) / Cast<Float>(numPoints);
        let i = 0;
        while i < numPoints {
            let angle = Cast<Float>(i) * angleStep;
            let distance = RandRangeF(minRadius, maxRadius);
            let point = center;
            point.X += CosF(angle) * distance;
            point.Y += SinF(angle) * distance;
            ArrayPush(points, point);
            i += 1;
        }
        return points;
    }
    public func FindSquadForMember(member: wref<ScriptedPuppet>) -> ref<SONC_PatrolSquad> {
        if !IsDefined(member) { return null; }
        let memberID = member.GetEntityID();
        for squad in this.activePatrols {
            if IsDefined(squad) {
                if ArrayContains(squad.squadEntityIDs, memberID) { return squad; }
            }
        }
        return null;
    }
    public func FindSquadForMemberID(memberID: EntityID) -> ref<SONC_PatrolSquad> {
        for squad in this.activePatrols {
            if IsDefined(squad) {
                if ArrayContains(squad.squadEntityIDs, memberID) { return squad; }
            }
        }
        return null;
    }
    public func IsValidRivalFaction(candidateID: EntityID, ownFactionName: CName) -> Bool {
        if Equals(ownFactionName, n"") { return true; }
        let candidateSquad = this.FindSquadForMemberID(candidateID);
        if !IsDefined(candidateSquad) { return true; }
        return !Equals(candidateSquad.factionName, ownFactionName);
    }
    public func IsSquadInCombat(squad: ref<SONC_PatrolSquad>) -> Bool {
        if !IsDefined(squad) { return false; }
        let gi = this.GetGameInstance();
        for id in squad.squadEntityIDs {
            let npc = GameInstance.FindEntityByID(gi, id) as ScriptedPuppet;
            if IsDefined(npc) && !npc.IsDead() {
                if Equals(npc.GetHighLevelStateFromBlackboard(), gamedataNPCHighLevelState.Combat) { return true; }
            }
        }
        return false;
    }
    private func GetNextSquadID() -> Int32 {
        let id = this.m_nextSquadID;
        this.m_nextSquadID += 1;
        if this.m_nextSquadID < 0 { this.m_nextSquadID = 1; }
        return id;
    }
    public func HasSquadBeenReinforced(squadID: Int32) -> Bool {
        return ArrayContains(this.m_reinforcedSquadIDs, squadID);
    }
    public func MarkSquadReinforced(squadID: Int32) -> Void {
        if !ArrayContains(this.m_reinforcedSquadIDs, squadID) {
            ArrayPush(this.m_reinforcedSquadIDs, squadID);
        }
    }
    private func CreateSquad(spawnPoint: Vector4) -> ref<SONC_PatrolSquad> {
        let squad = new SONC_PatrolSquad();
        squad.squadID           = this.GetNextSquadID();
        squad.centerPoint       = spawnPoint;
        squad.lastKnownPosition = spawnPoint;
        squad.spawnTime         = EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
        squad.lastSeenTime      = 0.0;
        squad.combatStartTime   = 0.0;
        squad.lastCombatEndTime = 0.0;
        return squad;
    }
    private func SafeOrientationFor(position: Vector4) -> Quaternion {
        let gi          = this.GetGameInstance();
        let spatialSystem = GameInstance.GetSpatialQueriesSystem(gi);
        let rayStart    = position;
        rayStart.Z     += 1.2;
        let bestDir     = new Vector4(0.0, 1.0, 0.0, 0.0);
        let bestClearance = -1.0;
        let dirs: array<Vector4>;
        ArrayPush(dirs, new Vector4( 1.0,  0.0, 0.0, 0.0));
        ArrayPush(dirs, new Vector4(-1.0,  0.0, 0.0, 0.0));
        ArrayPush(dirs, new Vector4( 0.0,  1.0, 0.0, 0.0));
        ArrayPush(dirs, new Vector4( 0.0, -1.0, 0.0, 0.0));
        let traceResult: TraceResult;
        for dir in dirs {
            let rayEnd = rayStart + (dir * 6.0);
            let clearance = 6.0;
            if spatialSystem.SyncRaycastByCollisionGroup(rayStart, rayEnd, n"Static", traceResult, false, false) {
                clearance = Vector4.Distance(rayStart, Vector4.Vector3To4(traceResult.position));
            }
            if clearance > bestClearance { bestClearance = clearance; bestDir = dir; }
        }
        return Quaternion.BuildFromDirectionVector(bestDir);
    }
    private func FindValidOffroadSpawnPoint(center: Vector4, maxRadius: Float, minRadius: Float) -> Vector4 {
        let cachedPoint = this.GetCachedSpawnPoint(center, maxRadius);
        if this.IsValidSpawnPoint(cachedPoint) && !this.IsDefinitelyIndoor(cachedPoint) { return cachedPoint; }
        let gi = this.GetGameInstance();
        let player = GetPlayer(gi);
        let aiNavSys = GameInstance.GetAINavigationSystem(gi);
        let camSys = GameInstance.GetCameraSystem(gi);
        let camTransform = new Transform(new Vector4(0.0, 0.0, 0.0, 0.0), new Quaternion(0.0, 0.0, 0.0, 1.0));
        camSys.GetActiveCameraWorldTransform(camTransform);
        let fov = camSys.GetActiveCameraFOV();
        let aspectRatio = camSys.GetAspectRatio();
        let attempts = 0;
        let fallbackPoint: Vector4;
        while attempts < 30 {
            let angle = RandRangeF(0.0, 360.0) * 0.0174533;
            let distance = RandRangeF(minRadius, maxRadius);
            let testPoint = center;
            testPoint.X += CosF(angle) * distance;
            testPoint.Y += SinF(angle) * distance;
            let navResult = aiNavSys.FindPointInBoxForCharacter(testPoint, new Vector4(15.0, 15.0, 50.0, 1.0), player);
            if Equals(navResult.status, worldNavigationRequestStatus.OK) {
                let validPoint = navResult.point;
                if !this.IsDefinitelyIndoor(validPoint) {
                    if StreetsOfNightCity_IsOutdoorSpawnPoint(gi, validPoint) {
                        this.AddSpawnToCache(validPoint);
                        if !SONC_IsPointInCameraView(gi, validPoint, camTransform, fov, aspectRatio, 500.0, false) {
                            let groundPos = this.FindGroundBeneath(validPoint);
                            if this.IsValidSpawnPoint(groundPos) && !this.IsDefinitelyIndoor(groundPos) { return groundPos; }
                            if !Vector4.IsXYZZero(validPoint) { return validPoint; }
                        }
                        if !this.IsValidSpawnPoint(fallbackPoint) { fallbackPoint = validPoint; }
                    }
                }
            }
            attempts += 1;
        }
        if this.IsValidSpawnPoint(fallbackPoint) && !this.IsDefinitelyIndoor(fallbackPoint) {
            let groundPos = this.FindGroundBeneath(fallbackPoint);
            if this.IsValidSpawnPoint(groundPos) && !this.IsDefinitelyIndoor(groundPos) { return groundPos; }
            return fallbackPoint;
        }
        return new Vector4(0.0, 0.0, 0.0, 0.0);
    }
    public func FindPedestrianSpawnPoint(center: Vector4, maxRadius: Float, minRadius: Float, opt skipRoadCheck: Bool) -> ref<SONC_ValidatedSpawnPoint> {
        let gi = this.GetGameInstance();
        let player = GetPlayer(gi);
        if !IsDefined(player) {
            let failed = new SONC_ValidatedSpawnPoint();
            failed.isValid = false;
            failed.failureReason = "No player";
            return failed;
        }
        let playerPos = player.GetWorldPosition();
        if this.IsDefinitelyIndoor(playerPos) {
            let failed = new SONC_ValidatedSpawnPoint();
            failed.isValid = false;
            failed.failureReason = "Player is indoors";
            return failed;
        }
        let aiNavSys = GameInstance.GetAINavigationSystem(gi);
        let searchPoints = this.GenerateCircularSearchPoints(center, minRadius, maxRadius, 20);
        for searchPoint in searchPoints {
            let navResult = aiNavSys.FindPointInBoxForCharacter(searchPoint, new Vector4(20.0, 20.0, 50.0, 1.0), player);
            if Equals(navResult.status, worldNavigationRequestStatus.OK) {
                let candidatePoint = navResult.point;
                if this.IsValidSpawnPoint(candidatePoint) {
                    let validation = this.ValidateSpawnPoint(candidatePoint, minRadius, maxRadius, true, !skipRoadCheck, false);
                    if validation.isValid { return validation; }
                }
            }
        }
        let maxAttempts = 25;
        let attempt = 0;
        while attempt < maxAttempts {
            let angle = RandRangeF(0.0, Pi() * 2.0);
            let distance = RandRangeF(minRadius, maxRadius);
            let testPoint = center;
            testPoint.X += CosF(angle) * distance;
            testPoint.Y += SinF(angle) * distance;
            let navResult = aiNavSys.FindPointInBoxForCharacter(testPoint, new Vector4(25.0, 25.0, 50.0, 1.0), player);
            if Equals(navResult.status, worldNavigationRequestStatus.OK) {
                let candidatePoint = navResult.point;
                if this.IsValidSpawnPoint(candidatePoint) {
                    let validation = this.ValidateSpawnPoint(candidatePoint, minRadius, maxRadius, true, !skipRoadCheck, false);
                    if validation.isValid { return validation; }
                }
            }
            attempt += 1;
        }
        let attemptsZ = 0;
        while attemptsZ < 12 {
            let test = center;
            test.Z = playerPos.Z + RandRangeF(-30.0, 30.0);
            let nav = aiNavSys.FindPointInBoxForCharacter(test, new Vector4(18.0, 18.0, 50.0, 1.0), player);
            if Equals(nav.status, worldNavigationRequestStatus.OK) {
                let candidate = nav.point;
                let val = this.ValidateSpawnPoint(candidate, minRadius * 1.2, maxRadius * 1.3, true, !skipRoadCheck, false);
                if val.isValid { return val; }
            }
            attemptsZ += 1;
        }
        let playerNav = aiNavSys.FindPointInBoxForCharacter(playerPos, new Vector4(30.0, 30.0, 50.0, 1.0), player);
        if Equals(playerNav.status, worldNavigationRequestStatus.OK) {
            let safe = this.ValidateSpawnPoint(playerNav.point, minRadius * 1.5, maxRadius * 1.5, true, !skipRoadCheck, false);
            if safe.isValid { return safe; }
        }
        let bigBox = aiNavSys.FindPointInBoxForCharacter(playerPos, new Vector4(80.0, 80.0, 80.0, 1.0), player);
        if Equals(bigBox.status, worldNavigationRequestStatus.OK) {
            let bigSafe = this.ValidateSpawnPoint(bigBox.point, minRadius * 2.0, maxRadius * 3.0, true, true, false);
            if bigSafe.isValid { return bigSafe; }
        }
        let failed = new SONC_ValidatedSpawnPoint();
        failed.isValid = false;
        failed.failureReason = "All fallback layers exhausted after " + ToString(maxAttempts) + " attempts";
        return failed;
    }
    public func FindGroundBeneath(point: Vector4) -> Vector4 {
        let gi = this.GetGameInstance();
        let player = GetPlayer(gi);
        let isHilly = this.cachedIsHilly;
        let upRange: Float = 8.0;
        let downRange: Float = 40.0;
        let tolerance: Float = 35.0;
        if isHilly {
            downRange = 70.0;
            tolerance = 60.0;
        }
        let aiNavSys = GameInstance.GetAINavigationSystem(gi);
        let spatialSystem = GameInstance.GetSpatialQueriesSystem(gi);
        let traceResult: TraceResult;
        let rayStart = point; rayStart.Z += upRange;
        let rayEnd   = point; rayEnd.Z   -= downRange;
        let presets: array<CName> = [n"Terrain", n"Static"];
        for preset in presets {
            if spatialSystem.SyncRaycastByCollisionGroup(rayStart, rayEnd, preset, traceResult, false, false) {
                let groundPos = Vector4.Vector3To4(traceResult.position);
                groundPos.Z += 0.1;
                if AbsF(groundPos.Z - point.Z) <= tolerance {
                    let navCheck = aiNavSys.FindPointInBoxForCharacter(groundPos, new Vector4(3.0, 3.0, 4.0, 1.0), player);
                    if Equals(navCheck.status, worldNavigationRequestStatus.OK) {
                        if AbsF(navCheck.point.Z - groundPos.Z) <= 2.5 {
                            return groundPos;
                        }
                    }
                }
            }
        }
        let navFallback = aiNavSys.FindPointInBoxForCharacter(point, new Vector4(8.0, 8.0, downRange, 1.0), player);
        if Equals(navFallback.status, worldNavigationRequestStatus.OK) {
            let navPt = navFallback.point;
            let snapDrift = Vector4.Distance2D(navPt, point);
            if snapDrift <= 15.0 {
                if AbsF(navPt.Z - point.Z) <= tolerance { return navPt; }
            }
        }
        return new Vector4(0.0, 0.0, 0.0, 0.0);
    }
    public func ValidateConflictSpawnPoint(point: Vector4) -> Bool {
        if !this.IsValidSpawnPoint(point) { return false; }
        if this.IsStrictlyIndoors(point) { return false; }
        let restrictedTypes: array<ESecurityAreaType>;
        ArrayPush(restrictedTypes, ESecurityAreaType.DISABLED);
        ArrayPush(restrictedTypes, ESecurityAreaType.DANGEROUS);
        if SONC_IsPointInAnyLoadedSecurityAreaRadius(point, restrictedTypes, true) { return false; }
        let gi = this.GetGameInstance();
        let aiNavSys = GameInstance.GetAINavigationSystem(gi);
        let player = GetPlayer(gi);
        let navCheck = aiNavSys.FindPointInBoxForCharacter(point, new Vector4(8.0, 8.0, 50.0, 1.0), player);
        if !Equals(navCheck.status, worldNavigationRequestStatus.OK) { return false; }
        let navDist = Vector4.Distance2D(point, navCheck.point);
        if navDist > 12.0 { return false; }
        return true;
    }
    public func FindPedestrianSpawnPointEmergency(center: Vector4, maxRadius: Float, minRadius: Float) -> Vector4 {
        let gi = this.GetGameInstance();
        let aiNavSys = GameInstance.GetAINavigationSystem(gi);
        let player = GetPlayer(gi);
        if IsDefined(player) && this.IsDefinitelyIndoor(player.GetWorldPosition()) {
            return new Vector4(0.0, 0.0, 0.0, 0.0);
        }
        let attempts = 0;
        while attempts < 25 {
            let angle = RandRangeF(0.0, Pi() * 2.0);
            let distance = RandRangeF(minRadius, maxRadius);
            let testPoint = center;
            testPoint.X += CosF(angle) * distance;
            testPoint.Y += SinF(angle) * distance;
            let navResult = aiNavSys.FindPointInBoxForCharacter(testPoint, new Vector4(8.0, 8.0, 50.0, 1.0), player);
            if Equals(navResult.status, worldNavigationRequestStatus.OK) {
                let groundPoint = this.FindGroundBeneath(navResult.point);
                if this.IsValidSpawnPoint(groundPoint) {
                    let heightDiff = AbsF(navResult.point.Z - groundPoint.Z);
                    if heightDiff <= 3.0 {
                        if StreetsOfNightCity_IsOutdoorSpawnPoint(gi, groundPoint) && !this.IsPointOnVehiclePath(groundPoint) {
                            return groundPoint;
                        }
                    }
                }
            }
            attempts += 1;
        }
        if IsDefined(player) {
            let bigNav = aiNavSys.FindPointInBoxForCharacter(player.GetWorldPosition(), new Vector4(80.0, 80.0, 80.0, 1.0), player);
            if Equals(bigNav.status, worldNavigationRequestStatus.OK) {
                let groundPos = this.FindGroundBeneath(bigNav.point);
                if this.IsValidSpawnPoint(groundPos) && StreetsOfNightCity_IsOutdoorSpawnPoint(gi, groundPos) {
                    return groundPos;
                }
            }
        }
        return new Vector4(0.0, 0.0, 0.0, 0.0);
    }
    private func GetEntitySpec() -> ref<DynamicEntitySpec> {
        if ArraySize(this.m_specPool) > 0 {
            let last = ArraySize(this.m_specPool) - 1;
            let spec = this.m_specPool[last];
            ArrayErase(this.m_specPool, last);
            spec.tags = [];
            spec.recordID = TDBID.None();
            spec.alwaysSpawned = false;
            spec.persistState = false;
            spec.persistSpawn = false;
            spec.appearanceName = n"";
            spec.orientation = new Quaternion(0.0, 0.0, 0.0, 1.0);
            return spec;
        }
        return new DynamicEntitySpec();
    }
    private func ReturnEntitySpec(spec: ref<DynamicEntitySpec>) -> Void {
        if IsDefined(spec) && ArraySize(this.m_specPool) < 8 {
            ArrayPush(this.m_specPool, spec);
        }
    }
    private func GetCachedSpawnPoint(center: Vector4, radius: Float) -> Vector4 {
        let currentTime = EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
        let i = ArraySize(this.m_validSpawnCache) - 1;
        let found: Vector4 = new Vector4(0.0, 0.0, 0.0, 0.0);
        let didFind = false;
        while i >= 0 {
            let cached = this.m_validSpawnCache[i];
            let age = currentTime - cached.timestamp;
            if age >= 60.0 {
                ArrayErase(this.m_validSpawnCache, i);
            } else {
                if !didFind {
                    let dist = Vector4.Distance(center, cached.position);
                    if dist < radius && cached.useCount < 3 {
                        cached.useCount += 1;
                        cached.timestamp = currentTime;
                        found = cached.position;
                        didFind = true;
                    }
                }
            }
            i -= 1;
        }
        return found;
    }
    private func AddSpawnToCache(point: Vector4) -> Void {
        let newCachePoint = new SONC_CachedSpawnPoint();
        newCachePoint.position = point;
        newCachePoint.timestamp = EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
        newCachePoint.useCount = 1;
        ArrayPush(this.m_validSpawnCache, newCachePoint);
    }
    private func IsRuralArea(districtName: String) -> Bool {
        if StrContains(districtName, "Badlands") { return true; }
        if StrContains(districtName, "RedPeaks") { return true; }
        if StrContains(districtName, "RockyRidge") { return true; }
        if StrContains(districtName, "JacksonPlains") { return true; }
        if StrContains(districtName, "BiotechnicaFlats") { return true; }
        return false;
    }
    private func GetPlayerDistrictName(player: ref<PlayerPuppet>) -> String {
        if !IsDefined(player) { return ""; }
        let currentTime = EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
        if currentTime - this.lastDistrictCheck < 5.0 && !Equals(this.cachedDistrictName, "") {
            return this.cachedDistrictName;
        }
        let district = SONC_GetCurrentDistrict();
        if IsDefined(district) {
            let districtRecord = district.GetDistrictRecord();
            if IsDefined(districtRecord) {
                let raw = ToString(districtRecord.EnumName());
                if !Equals(raw, "") && !Equals(raw, "None") {
                    this.cachedDistrictName = this.NormalizeDistrictName(raw);
                    this.cachedIsHilly = this.IsRuralArea(this.cachedDistrictName) || StrContains(this.cachedDistrictName, "SantoDomingo") || StrContains(this.cachedDistrictName, "VistaDelRey") || StrContains(this.cachedDistrictName, "RanchoCoronado");
                    this.lastDistrictCheck = currentTime;
                    return this.cachedDistrictName;
                }
            }
        }
        // District lookup failed. Watson is flat, and FindGroundBeneath reads
        // cachedIsHilly WITHOUT calling this function - so it has to be set here
        // or a stale "hilly" flag survives into a flat district.
        this.cachedIsHilly = false;
        return "Watson";
    }
    public func IsPlayerInAVRestrictedDistrict(player: ref<PlayerPuppet>) -> Bool {
        let district = this.GetPlayerDistrictName(player);
        return this.IsNoPoliceDistrict(district);
    }
    private func IsNoPoliceDistrict(districtName: String) -> Bool {
        if StrContains(districtName, "Dogtown") { return true; }
        if StrContains(districtName, "Pacifica") { return true; }
        if StrContains(districtName, "Coastview") { return true; }
        if StrContains(districtName, "WestWindEstate") { return true; }
        return false;
    }
    private func IsPoliceFaction(factionName: CName) -> Bool {
        if Equals(factionName, n"NCPD") { return true; }
        if Equals(factionName, n"CitySurveillance") { return true; }
        if Equals(factionName, n"MaxTac") { return true; }
        if Equals(factionName, n"BorderPatrol") { return true; }
        return false;
    }
    public func IsPoliceBlockedHere(factionName: CName) -> Bool {
        if !this.IsPoliceFaction(factionName) { return false; }
        return this.IsPlayerInNoPoliceZone();
    }
    private func IsPlayerInNoPoliceZone() -> Bool {
        let player = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) { return false; }
        let district = this.GetPlayerDistrictName(player);
        return this.IsNoPoliceDistrict(district);
    }
    private func IsPoliceRecord(record: TweakDBID) -> Bool {
        if record == t"Character.arr_ncpd_drone_wyvern" { return true; }
        if record == t"Character.arr_ncpd_android_android2_ajax_ma" { return true; }
        if record == t"Vehicle.ncpd_archer_hella_heat_2" { return true; }
        if record == t"Vehicle.ncpd_archer_hella_heat_3" { return true; }
        if record == t"Vehicle.ncpd_brennan_apollo_bike" { return true; }
        if record == t"Vehicle.ncpd_hellhound_heat_5" { return true; }
        if record == t"Vehicle.ncpd_suv_chevalier_emperor_heat_4" { return true; }
        if record == t"Vehicle.ncpd_thorton_merrimac_police_heat_4" { return true; }
        if record == t"Vehicle.ncpd_villefort_cortes_heat_1" { return true; }
        if record == t"Vehicle.ncpd_villefort_cortes_heat_2" { return true; }
        return false;
    }
    private func FilterPoliceRecords(pool: array<TweakDBID>) -> array<TweakDBID> {
        if !this.IsPlayerInNoPoliceZone() { return pool; }
        let clean: array<TweakDBID>;
        for rec in pool {
            if !this.IsPoliceRecord(rec) { ArrayPush(clean, rec); }
        }
        return clean;
    }
    private func PickNonPoliceRecord(pool: array<TweakDBID>) -> TweakDBID {
        let picked: TweakDBID;
        if ArraySize(pool) == 0 { return picked; }
        let clean = this.FilterPoliceRecords(pool);
        if ArraySize(clean) == 0 { return pool[RandRange(0, ArraySize(pool))]; }
        picked = clean[RandRange(0, ArraySize(clean))];
        return picked;
    }
    private func NormalizeDistrictName(rawName: String) -> String {
        if Equals(rawName, "Watson") { return "Watson"; }
        if Equals(rawName, "Westbrook") { return "Westbrook"; }
        if Equals(rawName, "Heywood") { return "Heywood"; }
        for mapping in this.m_districtNormalizationMap {
            if StrContains(rawName, mapping.rawName) { return mapping.normalized; }
        }
        return rawName;
    }
    private func GetParentDistrict(subDistrict: String) -> String {
        if StrContains(subDistrict, "Kabuki") || StrContains(subDistrict, "LittleChina") || StrContains(subDistrict, "Northside") || StrContains(subDistrict, "ArasakaWaterfront") { return "Watson"; }
        if StrContains(subDistrict, "JapanTown") || StrContains(subDistrict, "NorthOak") || StrContains(subDistrict, "CharterHill") { return "Westbrook"; }
        if StrContains(subDistrict, "CorpoPlaza") || StrContains(subDistrict, "Downtown") { return "CityCenter"; }
        if StrContains(subDistrict, "Wellsprings") || StrContains(subDistrict, "Glen") || StrContains(subDistrict, "VistaDelRey") { return "Heywood"; }
        if StrContains(subDistrict, "Coastview") || StrContains(subDistrict, "WestWindEstate") || StrContains(subDistrict, "Dogtown") { return "Pacifica"; }
        if StrContains(subDistrict, "Arroyo") || StrContains(subDistrict, "RanchoCoronado") { return "SantoDomingo"; }
        if StrContains(subDistrict, "RedPeaks") || StrContains(subDistrict, "RockyRidge") || StrContains(subDistrict, "JacksonPlains") || StrContains(subDistrict, "BiotechnicaFlats") { return "Badlands"; }
        return subDistrict;
    }
    private func GetFactionProfileByName(name: CName) -> ref<SONC_FactionProfile> {
        for faction in this.factionRegistry {
            if Equals(faction.factionName, name) { return faction; }
        }
        return null;
    }
    public func GetFactionForDistrict(districtName: String, out found: Bool, opt depth: Int32) -> ref<SONC_FactionProfile> {
        let result: ref<SONC_FactionProfile>;
        found = false;
        if depth > 1 { return result; }
        let candidateFactions: array<ref<SONC_FactionProfile>>;
        let candidateWeights: array<Float>;
        let totalWeight: Float = 0.0;
        for faction in this.factionRegistry {
            if this.IsFactionEnabled(faction.factionName) {
                let foundTerritory = false;
                for territory in faction.territories {
                    if foundTerritory { } else {
                        if Equals(territory.districtName, districtName) && territory.spawnChance > 0.0 {
                            ArrayPush(candidateFactions, faction);
                            ArrayPush(candidateWeights, territory.spawnChance);
                            totalWeight += territory.spawnChance;
                            foundTerritory = true;
                        }
                    }
                }
            }
        }
        if ArraySize(candidateFactions) == 0 {
            let parentDistrict = this.GetParentDistrict(districtName);
            if !Equals(parentDistrict, "") && !Equals(parentDistrict, districtName) {
                return this.GetFactionForDistrict(parentDistrict, found, depth + 1);
            }
        }
        if ArraySize(candidateFactions) > 0 {
            let rnd = RandRangeF(0.0, totalWeight);
            let currentAccumulator: Float = 0.0;
            let k = 0;
            while k < ArraySize(candidateFactions) {
                currentAccumulator += candidateWeights[k];
                if rnd <= currentAccumulator { found = true; return candidateFactions[k]; }
                k += 1;
            }
            found = true;
            return candidateFactions[ArraySize(candidateFactions) - 1];
        }
        return result;
    }
    public func IsPointOnRoadSurface(point: Vector4) -> Bool {
        let gi = this.GetGameInstance();
        let spatialSys = GameInstance.GetSpatialQueriesSystem(gi);
        let boxSize = new Vector4(0.4, 0.4, 0.3, 0.0);
        let centre = point; centre.Z -= 0.2;
        let traceResult: TraceResult;
        let presets: array<CName> = [n"Static", n"Terrain", n"World Static", n"World Geometry", n"Obstacles"];
        for preset in presets {
            if spatialSys.Overlap(boxSize, centre, new EulerAngles(), preset, traceResult) {
                let matName = StrLower(ToString(traceResult.material));
                if StrContains(matName, "road") || StrContains(matName, "asphalt") || StrContains(matName, "tarmac") || StrContains(matName, "pavement") {
                    return true;
                }
            }
        }
        return false;
    }
    public func IsPointOnVehiclePath(point: Vector4) -> Bool {
        let gi = this.GetGameInstance();
        let spatialSystem = GameInstance.GetSpatialQueriesSystem(gi);
        let overlapResult: TraceResult;
        let boxSize = new Vector4(1.5, 1.5, 0.5, 1.0);
        let testPoint = point; testPoint.Z += 0.3;
        if spatialSystem.Overlap(boxSize, testPoint, new EulerAngles(), n"Vehicle", overlapResult) { return true; }
        let nearbyTrafficNodes = SONC_GetNearbyVehicleSpawnPoints(point, 8.0, 0.0, 3.0, 10);
        let nodeCount = ArraySize(nearbyTrafficNodes);
        if nodeCount >= 3 { return true; }
        if nodeCount >= 1 {
            let closestNode = Vector4.Vector3To4(nearbyTrafficNodes[0]);
            let distToNode = Vector4.Distance2D(point, closestNode);
            if distToNode < 5.5 { return true; }
        }
        let traceResult: TraceResult;
        let checkStart = point; checkStart.Z += 1.2;
        let directions: array<Vector4> = [
            new Vector4(1.0, 0.0, 0.0, 0.0),
            new Vector4(-1.0, 0.0, 0.0, 0.0),
            new Vector4(0.0, 1.0, 0.0, 0.0),
            new Vector4(0.0, -1.0, 0.0, 0.0)
        ];
        for direction in directions {
            let rayEnd = checkStart + (direction * 2.0);
            if spatialSystem.SyncRaycastByQueryPreset(checkStart, rayEnd, n"Vehicle", traceResult) { return true; }
        }
        return false;
    }
    public func IsRoadShapedPoint(point: Vector4) -> Bool {
        let gi = this.GetGameInstance();
        let nearNodes = SONC_GetNearbyVehicleSpawnPoints(point, 40.0, 0.0, 15.0, 1);
        if ArraySize(nearNodes) == 0 { return false; }
        let toNode = Vector4.Vector3To4(nearNodes[0]) - point;
        toNode.Z = 0.0;
        let alongLen = Vector4.Length2D(toNode);
        if alongLen < 0.5 { return false; }
        let along  = new Vector4(toNode.X / alongLen, toNode.Y / alongLen, 0.0, 0.0);
        let across = new Vector4(-along.Y, along.X, 0.0, 0.0);
        let halfWidth = 3.5;
        let probeBox  = new Vector4(1.5, 1.5, 3.0, 1.0);
        let aiNavSys  = GameInstance.GetAINavigationSystem(gi);
        let player    = GetPlayer(gi);
        if !IsDefined(player) { return false; }
        let sideA = point;
        sideA.X += across.X * halfWidth;
        sideA.Y += across.Y * halfWidth;
        let resultA = aiNavSys.FindPointInBoxForCharacter(sideA, probeBox, player);
        let okA = Equals(resultA.status, worldNavigationRequestStatus.OK);
        if !okA { return false; }
        let sideB = point;
        sideB.X -= across.X * halfWidth;
        sideB.Y -= across.Y * halfWidth;
        let resultB = aiNavSys.FindPointInBoxForCharacter(sideB, probeBox, player);
        let okB = Equals(resultB.status, worldNavigationRequestStatus.OK);
        if !okB { return false; }
        let flatA = AbsF(resultA.point.Z - point.Z) < 1.0;
        let flatB = AbsF(resultB.point.Z - point.Z) < 1.0;
        let bothFlat = flatA && flatB;
        return bothFlat;
    }
    public func IsLikelyRoad(point: Vector4) -> Bool {
        if this.IsPointOnRoadSurface(point) { return true; }
        if this.IsPointOnVehiclePath(point) { return true; }
        if this.IsRoadShapedPoint(point)    { return true; }
        return false;
    }
    private func FactionsShareTerritory(a: ref<SONC_FactionProfile>, b: ref<SONC_FactionProfile>) -> Bool {
        for territoryA in a.territories {
            for territoryB in b.territories {
                if Equals(territoryA.districtName, territoryB.districtName) { return true; }
            }
        }
        return false;
    }
    private func FactionsAreMutualRivals(a: ref<SONC_FactionProfile>, b: ref<SONC_FactionProfile>) -> Bool {
        let aHatesB = false;
        for rival in a.rivalFactions {
            if Equals(rival, b.factionName) { aHatesB = true; }
        }
        let bHatesA = false;
        for rival in b.rivalFactions {
            if Equals(rival, a.factionName) { bHatesA = true; }
        }
        return aHatesB && bHatesA;
    }
    private func TryStartConflictAssaultDrive(attackers: ref<SONC_FactionProfile>, defenders: ref<SONC_FactionProfile>, targetPoint: Vector4, defenderSquadID: Int32) -> Bool {
        if ArraySize(attackers.vehiclePool) == 0 {
            return false;
        }
        let mutualRivals = this.FactionsAreMutualRivals(attackers, defenders);
        if this.FactionsShareTerritory(attackers, defenders) && !mutualRivals {
            return false;
        }
        let gi = this.GetGameInstance();
        let player = GetPlayer(gi);
        if !IsDefined(player) {
            return false;
        }
        let playerPos = player.GetWorldPosition();
        let driveNodes = SONC_GetNearbyVehicleSpawnPoints(targetPoint, 100.0);
        if ArraySize(driveNodes) == 0 {
            StreetsOfNightCity_Logger.Log(s"[CONFLICT] Assault drive rejected - no road within 100m of fight at \(FloatToStringPrec(targetPoint.X, 0))/\(FloatToStringPrec(targetPoint.Y, 0))");
            return false;
        }
        let drivePoint = targetPoint;
        let driveOffset: Float = 999999.0;
        for driveNodeV3 in driveNodes {
            let driveNode = Vector4.Vector3To4(driveNodeV3);
            if !this.IsStuckDriveNode(driveNode) {
                let dnDist = Vector4.Distance2D(driveNode, targetPoint);
                if dnDist < driveOffset {
                    driveOffset = dnDist;
                    drivePoint  = driveNode;
                }
            }
        }
        if driveOffset > 500.0 {
            StreetsOfNightCity_Logger.Log(s"[CONFLICT] Assault drive rejected - every road node near \(FloatToStringPrec(targetPoint.X, 0))/\(FloatToStringPrec(targetPoint.Y, 0)) is on the stuck list");
            return false;
        }
        StreetsOfNightCity_Logger.Log(s"[CONFLICT] Drive target snapped to road | park: \(FloatToStringPrec(drivePoint.X, 0))/\(FloatToStringPrec(drivePoint.Y, 0)) fight: \(FloatToStringPrec(targetPoint.X, 0))/\(FloatToStringPrec(targetPoint.Y, 0)) walkIn: \(FloatToStringPrec(driveOffset, 1))m nodes100m: \(ToString(ArraySize(driveNodes)))");
        let nodes = SONC_GetNearbyVehicleSpawnPoints(targetPoint, 240.0, 90.0, 60.0, 40);
        if ArraySize(nodes) == 0 {
            return false;
        }
        let candidates: array<Vector4>;
        let rejectedFar = 0;
        let rejectedStuck = 0;
        for nodeV3 in nodes {
            let node = Vector4.Vector3To4(nodeV3);
            if Vector4.Distance(node, playerPos) < 70.0 {
                rejectedFar += 1;
            } else {
                if this.IsStuckDriveNode(node) {
                    rejectedStuck += 1;
                } else {
                    ArrayPush(candidates, node);
                }
            }
        }
        if ArraySize(candidates) == 0 {
            return false;
        }
        let ci = 0;
        while ci < ArraySize(candidates) - 1 {
            let cj = ci + 1;
            while cj < ArraySize(candidates) {
                let dI = Vector4.Distance(candidates[ci], targetPoint);
                let dJ = Vector4.Distance(candidates[cj], targetPoint);
                if dJ < dI {
                    let tmp = candidates[ci]; candidates[ci] = candidates[cj]; candidates[cj] = tmp;
                }
                cj += 1;
            }
            ci += 1;
        }
        let bestNode = new Vector4(0.0, 0.0, 0.0, 0.0);
        let groundPos = new Vector4(0.0, 0.0, 0.0, 0.0);
        let groundOk = false;
        let tried = 0;
        let rejectedGround = 0;
        let rejectedRoad = 0;
        let rejectedTraffic = 0;
        for cand in candidates {
            if !groundOk {
                tried += 1;
                let candGround = this.FindGroundBeneath(cand);
                if Vector4.IsXYZZero(candGround) {
                    rejectedGround += 1;
                } else {
                    if !SONC_IsPointOnRoadSurface(gi, candGround) {
                        rejectedRoad += 1;
                    } else {
                        if SONC_IsSpawnBlockedByVehicle(gi, candGround, 3.5) {
                            rejectedTraffic += 1;
                        } else {
                            bestNode  = cand;
                            groundPos = candGround;
                            groundOk  = true;
                        }
                    }
                }
            }
        }
        if !groundOk {
            return false;
        }
        groundPos.Z += 0.4;
        StreetsOfNightCity_Logger.Log(s"[CONFLICT] Assault spawn | DIAG spawnDist: \(FloatToStringPrec(Vector4.Distance2D(groundPos, targetPoint), 0))m nodes: \(ToString(ArraySize(nodes))) cands: \(ToString(ArraySize(candidates))) tried: \(ToString(tried)) rejNearPlayer: \(ToString(rejectedFar)) rejGround: \(ToString(rejectedGround)) rejRoad: \(ToString(rejectedRoad)) rejStuck: \(ToString(rejectedStuck)) rejTraffic: \(ToString(rejectedTraffic))");
        let dirToTarget = targetPoint - groundPos;
        dirToTarget.Z = 0.0;
        let spawnOrient: Quaternion;
        if Vector4.Length2D(dirToTarget) > 2.0 {
            spawnOrient = Quaternion.BuildFromDirectionVector(Vector4.Normalize(dirToTarget));
        } else {
            spawnOrient = new Quaternion(0.0, 0.0, 0.0, 1.0);
        }
        let vehicleRecordID = this.PickNonPoliceRecord(attackers.vehiclePool);
        let vehicleSpec = this.GetEntitySpec();
        vehicleSpec.recordID = vehicleRecordID;
        vehicleSpec.position = groundPos;
        vehicleSpec.orientation = spawnOrient;
        vehicleSpec.alwaysSpawned = true;
        vehicleSpec.persistState = false;
        vehicleSpec.persistSpawn = false;
        ArrayPush(vehicleSpec.tags, n"SONC_Vehicle");
        ArrayPush(vehicleSpec.tags, n"PreventPersistence");
        ArrayPush(vehicleSpec.tags, n"IgnorePersistency");
        ArrayPush(vehicleSpec.tags, n"DynamicEntity");
        let vehicleID = GameInstance.GetDynamicEntitySystem().CreateEntity(vehicleSpec);
        this.ReturnEntitySpec(vehicleSpec);
        if !EntityID.IsDefined(vehicleID) { return false; }
        let setup = new SONC_ConflictAssaultSetupCallback();
        setup.vehicleID = vehicleID;
        setup.faction = attackers;
        setup.defenderSquadID = defenderSquadID;
        setup.targetPoint = drivePoint;
        setup.fightPoint = targetPoint;
        setup.systemInstance = this;
        GameInstance.GetDelaySystem(gi).DelayCallback(setup, 1.8);
        return true;
    }
    public func MountConflictAssaultCrew(vehicle: wref<VehicleObject>, faction: ref<SONC_FactionProfile>) -> Int32 {
        let gi = this.GetGameInstance();
        let localVehicle = vehicle;
        if !IsDefined(localVehicle) { return -1; }
        let vehicleID = localVehicle.GetEntityID();
        let vehicleRecord = TweakDBInterface.GetVehicleRecord(localVehicle.GetRecordID());
        let isBike = false;
        if IsDefined(vehicleRecord) {
            if Equals(vehicleRecord.Type().Type(), gamedataVehicleType.Bike) { isBike = true; }
        }
        let availableSeats: array<CName>;
        if isBike {
            availableSeats = [n"seat_front_left"];
        } else {
            let allSeats: array<CName> = [n"seat_front_left", n"seat_front_right", n"seat_back_left", n"seat_back_right"];
            for seatName in allSeats {
                if !VehicleComponent.IsSlotOccupied(gi, vehicleID, seatName) {
                    ArrayPush(availableSeats, seatName);
                }
            }
        }
        // Clamp low: if the config ever hands back 0 the vehicle spawns with no
        // crew and gets deleted a line later, so no squad ever appears.
        let desiredSize = Min(Max(1, this.settings.vehicleCrewSize), ArraySize(availableSeats));
        StreetsOfNightCity_Logger.Log(s"[CONFLICT] Crew sizing | desiredSize: \(ToString(desiredSize)) | availableSeats: \(ToString(ArraySize(availableSeats))) | isBike: \(ToString(isBike))");
        if desiredSize <= 0 { return -1; }
        let vehiclePos = localVehicle.GetWorldPosition();
        let squad = this.CreateSquad(vehiclePos);
        squad.vehicleEntityID = vehicleID;
        squad.factionName = faction.factionName;
        squad.isConflict = true;
        let pendingMountIDs: array<EntityID>;
        let pendingMountSeats: array<CName>;
        let i = 0;
        while i < desiredSize {
            let seatName = availableSeats[i];
            let isDriver = Equals(seatName, n"seat_front_left");
            let record = this.SelectRecordForSquadMember(faction, i, false);
            let rolls = 0;
            while rolls < 8 && !SONC_RecordCanRideVehicle(record) {
                record = this.SelectRecordForSquadMember(faction, i, false);
                rolls += 1;
            }
            if !SONC_RecordCanRideVehicle(record) {
                StreetsOfNightCity_Logger.Log(s"[CONFLICT] Crew slot \(ToString(i)) skipped - no vehicle-capable record in \(ToString(faction.factionName)) pool after \(ToString(rolls)) rolls | last: \(TDBID.ToStringDEBUG(record))");
            } else {
                let spec = this.GetEntitySpec();
                spec.recordID = record;
                spec.position = vehiclePos;
                spec.alwaysSpawned = true;
                spec.persistState = false;
                spec.persistSpawn = false;
                ArrayPush(spec.tags, n"SONC_NPC");
                ArrayPush(spec.tags, n"PreventPersistence");
                ArrayPush(spec.tags, n"IgnorePersistency");
                ArrayPush(spec.tags, n"DynamicEntity");
                let npcID = GameInstance.GetDynamicEntitySystem().CreateEntity(spec);
                this.ReturnEntitySpec(spec);
                StreetsOfNightCity_Logger.Log(s"[CONFLICT] Crew slot \(ToString(i)) | seat: \(ToString(seatName)) | record: \(TDBID.ToStringDEBUG(record)) | spawned: \(ToString(EntityID.IsDefined(npcID))) | rerolls: \(ToString(rolls))");
                if EntityID.IsDefined(npcID) {
                    ArrayPush(squad.squadEntityIDs, npcID);
                    if isDriver { squad.driverID = npcID; }
                    ArrayPush(pendingMountIDs, npcID);
                    ArrayPush(pendingMountSeats, seatName);
                }
            }
            i += 1;
        }
        if ArraySize(squad.squadEntityIDs) == 0 { return -1; }
        if ArraySize(pendingMountIDs) > 0 {
            let mountCb = new SONC_ConflictCrewMountCallback();
            mountCb.vehicleID = vehicleID;
            mountCb.npcIDs = pendingMountIDs;
            mountCb.seatNames = pendingMountSeats;
            mountCb.attempt = 0;
            GameInstance.GetDelaySystem(gi).DelayCallback(mountCb, 0.5);
        }
        squad.state = SONC_SquadState.DrivingIn;
        ArrayPush(this.activePatrols, squad);
        this.AddToPatrolCounts(squad);
        let attCallback = new StreetsOfNightCity_ConsolidatedAttitudeCallback();
        attCallback.squadID = squad.squadID;
        attCallback.factionName = squad.factionName;
        attCallback.isConflict = true;
        attCallback.systemInstance = this;
        GameInstance.GetDelaySystem(gi).DelayCallback(attCallback, 1.0);
        return squad.squadID;
    }
    public func MarkStuckDriveNode(pos: Vector4) -> Void {
        if this.IsStuckDriveNode(pos) { return; }
        ArrayPush(this.m_stuckDriveNodes, pos);
        if ArraySize(this.m_stuckDriveNodes) > 24 {
            ArrayErase(this.m_stuckDriveNodes, 0);
        }
        StreetsOfNightCity_Logger.Log(s"[CONFLICT] STUCKNODE recorded \(FloatToStringPrec(pos.X, 0))/\(FloatToStringPrec(pos.Y, 0)) | listSize: \(ToString(ArraySize(this.m_stuckDriveNodes)))");
    }
    public func IsStuckDriveNode(pos: Vector4) -> Bool {
        for badNode in this.m_stuckDriveNodes {
            if Vector4.Distance2D(badNode, pos) < 12.0 { return true; }
        }
        return false;
    }
    public func ReleaseConflictDefenders(defenderSquadID: Int32) -> Void {
        let squad = this.GetSquadByID(defenderSquadID);
        if IsDefined(squad) {
            squad.isConflict = false;
            StreetsOfNightCity_Logger.Log("[CONFLICT] Drive-in failed - defenders released to normal patrol");
        }
    }
    public func GetSquadByID(squadID: Int32) -> ref<SONC_PatrolSquad> {
        for squad in this.activePatrols {
            if IsDefined(squad) && squad.squadID == squadID { return squad; }
        }
        return null;
    }
    public func IsSquadAlive(squad: ref<SONC_PatrolSquad>) -> Bool {
        if !IsDefined(squad) { return false; }
        let gi = this.GetGameInstance();
        for memberID in squad.squadEntityIDs {
            let member = GameInstance.FindEntityByID(gi, memberID) as ScriptedPuppet;
            if IsDefined(member) && !member.IsDead() { return true; }
        }
        if EntityID.IsDefined(squad.vehicleEntityID) {
            let vehicle = GameInstance.FindEntityByID(gi, squad.vehicleEntityID);
            if IsDefined(vehicle) { return true; }
        }
        return false;
    }

    public func RemoveSquad(squad: ref<SONC_PatrolSquad>) -> Void {
        if IsDefined(squad) { ArrayRemove(this.activePatrols, squad); }
    }
    public func IsPointCameraVisible(position: Vector4, distanceToPlayer: Float) -> Bool {
        let gi = this.GetGameInstance();
        let camSys = GameInstance.GetCameraSystem(gi);
        let camTransform = new Transform(new Vector4(0.0, 0.0, 0.0, 0.0), new Quaternion(0.0, 0.0, 0.0, 1.0));
        camSys.GetActiveCameraWorldTransform(camTransform);
        let fov = camSys.GetActiveCameraFOV();
        let aspectRatio = camSys.GetAspectRatio();
        return distanceToPlayer < this.settings.spawnCameraCheckRadius && SONC_IsPointInCameraView(gi, position, camTransform, fov, aspectRatio, 500.0, false);
    }
    private func ValidateSpawnPoint(position: Vector4, minDistance: Float, maxDistance: Float, requireOutdoor: Bool, checkVehiclePath: Bool, skipCameraCheck: Bool) -> ref<SONC_ValidatedSpawnPoint> {
        let result = new SONC_ValidatedSpawnPoint();
        result.position = position;
        result.isValid = false;
        result.failureReason = "";
        let gi = this.GetGameInstance();
        let player = GetPlayer(gi);
        if !IsDefined(player) { result.failureReason = "No player"; return result; }
        if !this.IsValidSpawnPoint(position) { result.failureReason = "Invalid coordinates"; return result; }
        let playerPos = player.GetWorldPosition();
        result.distanceToPlayer = Vector4.Distance2D(position, playerPos);
        let adjustedMinDistance = MaxF(minDistance, 15.0);
        if result.distanceToPlayer < adjustedMinDistance { result.failureReason = "Too close: " + FloatToStringPrec(result.distanceToPlayer, 1) + "m"; return result; }
        if result.distanceToPlayer > maxDistance { result.failureReason = "Too far: " + FloatToStringPrec(result.distanceToPlayer, 1) + "m"; return result; }
        if requireOutdoor {
            let interiorTypes: array<ESecurityAreaType>;
            ArrayPush(interiorTypes, ESecurityAreaType.SAFE);
            if SONC_IsPointInAnyLoadedSecurityAreaRadius(position, interiorTypes, true) { result.failureReason = "Safe area (interior)"; return result; }
        }
        if !skipCameraCheck {
            if this.IsPointCameraVisible(position, result.distanceToPlayer) {
                result.failureReason = "In camera view";
                return result;
            }
        }
        if checkVehiclePath {
            if this.IsPointOnVehiclePath(position) {
                if this.settings.debugLogging {
                    StreetsOfNightCity_Logger.Log(s"[ROAD CHECK] Spawn candidate rejected - too close to vehicle spawn point | Pos: \(ToString(position))");
                }
                result.failureReason = "On vehicle path"; return result;
            }
            if this.IsPointOnRoadSurface(position) {
                if this.settings.debugLogging {
                    StreetsOfNightCity_Logger.Log(s"[ROAD CHECK] Spawn candidate rejected - on road surface | Pos: \(ToString(position))");
                }
                result.failureReason = "On road surface"; return result;
            }
            if this.IsRoadShapedPoint(position) {
                if this.settings.debugLogging {
                    StreetsOfNightCity_Logger.Log(s"[ROAD CHECK] Spawn candidate rejected - road-shaped (width heuristic) | Pos: \(ToString(position))");
                }
                result.failureReason = "Road-shaped"; return result;
            }
        }
        result.isValid = true;
        result.orientation = this.SafeOrientationFor(position);
        return result;
    }
    public func SpawnReinforcementsAt(factionName: CName, origin: Vector4) -> Int32 {
        if !this.isInitialized { return -1; }
        if !this.settings.enableImmersive { return -1; }
        if !this.IsFactionEnabled(factionName) { return -1; }
        if !this.PassesSpawnSafetyChecks(origin) { return -1; }
        let faction = this.GetFactionProfileByName(factionName);
        if !IsDefined(faction) { return -1; }
        if ArraySize(faction.standardGrunts) == 0 { return -1; }
        return this.SpawnFootGroup(faction, false, false, false, origin, true);
    }
	public func SpawnDroneReinforcementsAt(factionName: CName, origin: Vector4) -> Int32 {
        if !this.isInitialized {
            StreetsOfNightCity_Logger.Log("[CONFLICT] DRONEDIAG reject: not initialized");
            return -1;
        }
        if !this.settings.enableImmersive {
            StreetsOfNightCity_Logger.Log("[CONFLICT] DRONEDIAG reject: enableImmersive is off");
            return -1;
        }
        if !this.IsFactionEnabled(factionName) {
            StreetsOfNightCity_Logger.Log(s"[CONFLICT] DRONEDIAG reject: faction disabled | \(ToString(factionName))");
            return -1;
        }
        if !this.PassesSpawnSafetyChecks(origin) {
            StreetsOfNightCity_Logger.Log(s"[CONFLICT] DRONEDIAG reject: safety checks at \(FloatToStringPrec(origin.X, 0))/\(FloatToStringPrec(origin.Y, 0))");
            return -1;
        }
        let faction = this.GetFactionProfileByName(factionName);
        if !IsDefined(faction) {
            StreetsOfNightCity_Logger.Log(s"[CONFLICT] DRONEDIAG reject: no faction profile | \(ToString(factionName))");
            return -1;
        }
        let droneSquadID = this.SpawnFootGroup(faction, false, false, true, origin, true);
        if droneSquadID < 0 {
            StreetsOfNightCity_Logger.Log(s"[CONFLICT] DRONEDIAG reject: SpawnFootGroup failed | \(ToString(factionName)) at \(FloatToStringPrec(origin.X, 0))/\(FloatToStringPrec(origin.Y, 0))");
            return -1;
        }
        return droneSquadID;
    }
    public func SpawnConflictDronesAtPoint(factionName: CName, fightPoint: Vector4) -> Int32 {
        if !this.isInitialized { return -1; }
        if !this.IsFactionEnabled(factionName) {
            StreetsOfNightCity_Logger.Log(s"[CONFLICT] DRONEDIAG reject: faction disabled | \(ToString(factionName))");
            return -1;
        }
        let faction = this.GetFactionProfileByName(factionName);
        if !IsDefined(faction) {
            StreetsOfNightCity_Logger.Log(s"[CONFLICT] DRONEDIAG reject: no faction profile | \(ToString(factionName))");
            return -1;
        }
        let gi = this.GetGameInstance();
        let player = GetPlayer(gi);
        if !IsDefined(player) { return -1; }
        let playerPos = player.GetWorldPosition();
        let validated = this.FindPedestrianSpawnPoint(fightPoint, 35.0, 8.0, true);
        if !validated.isValid {
            let emergency = this.FindPedestrianSpawnPointEmergency(fightPoint, 35.0, 8.0);
            if !this.IsValidSpawnPoint(emergency) {
                StreetsOfNightCity_Logger.Log(s"[CONFLICT] DRONEDIAG reject: no pedestrian point within 35m of \(FloatToStringPrec(fightPoint.X, 0))/\(FloatToStringPrec(fightPoint.Y, 0)) | \(validated.failureReason)");
                return -1;
            }
            let fallback = new SONC_ValidatedSpawnPoint();
            fallback.isValid          = true;
            fallback.position         = emergency;
            fallback.distanceToPlayer = Vector4.Distance(emergency, playerPos);
            fallback.orientation      = this.SafeOrientationFor(emergency);
            validated = fallback;
        }
        let droneSquadID = this.SpawnFootGroupAtPoint(faction, validated, true, false, true);
        if droneSquadID < 0 {
            StreetsOfNightCity_Logger.Log(s"[CONFLICT] DRONEDIAG reject: mechanical spawn failed at \(FloatToStringPrec(validated.position.X, 0))/\(FloatToStringPrec(validated.position.Y, 0))");
            return -1;
        }
        StreetsOfNightCity_Logger.Log(s"[CONFLICT] DRONESPAWN at \(FloatToStringPrec(validated.position.X, 0))/\(FloatToStringPrec(validated.position.Y, 0)) | fightDist: \(FloatToStringPrec(Vector4.Distance2D(validated.position, fightPoint), 1))m playerDist: \(FloatToStringPrec(validated.distanceToPlayer, 0))m");
        return droneSquadID;
    }
    public func LaunchConflictDroneAssault(factionName: CName, fightPoint: Vector4, defenderSquadID: Int32) -> Bool {
        let droneSquadID = this.SpawnConflictDronesAtPoint(factionName, fightPoint);
        if droneSquadID < 0 {
            StreetsOfNightCity_Logger.Log(s"[CONFLICT] DRONEASSAULT declined | faction: \(ToString(factionName)) at \(FloatToStringPrec(fightPoint.X, 0))/\(FloatToStringPrec(fightPoint.Y, 0))");
            return false;
        }
        let gi = this.GetGameInstance();
        let enemyIDs: array<EntityID>;
        let defenders = this.GetSquadByID(defenderSquadID);
        if IsDefined(defenders) {
            for memberID in defenders.squadEntityIDs {
                let member = GameInstance.FindEntityByID(gi, memberID) as ScriptedPuppet;
                if IsDefined(member) && !member.IsDead() { ArrayPush(enemyIDs, memberID); }
            }
        }
        let engage = SONC_DroneReinforceEngageCallback.Create(droneSquadID, enemyIDs);
        GameInstance.GetDelaySystem(gi).DelayCallback(engage, 5.0);
        let defFound  = IsDefined(defenders);
        let defMembers = 0;
        if defFound { defMembers = ArraySize(defenders.squadEntityIDs); }
        StreetsOfNightCity_Logger.Log(s"[CONFLICT] DRONEASSAULT squad: \(ToString(droneSquadID)) faction: \(ToString(factionName)) at \(FloatToStringPrec(fightPoint.X, 0))/\(FloatToStringPrec(fightPoint.Y, 0)) targets: \(ToString(ArraySize(enemyIDs))) defSquad: \(ToString(defenderSquadID)) defFound: \(ToString(defFound)) defMembers: \(ToString(defMembers))");
        return true;
    }
    public func SpawnVehicleReinforcementsAt(factionName: CName, origin: Vector4, enemyIDs: array<EntityID>) -> Bool {
        if !this.isInitialized { return false; }
        if !this.settings.enableImmersive { return false; }
        if !this.IsFactionEnabled(factionName) { return false; }
        if !this.PassesSpawnSafetyChecks(origin) { return false; }
        let faction = this.GetFactionProfileByName(factionName);
        if !IsDefined(faction) { return false; }
        if ArraySize(faction.vehiclePool) == 0 { return false; }
        let gi = this.GetGameInstance();
        let player = GetPlayer(gi);
        if !IsDefined(player) { return false; }
        let playerPos     = player.GetWorldPosition();
        let playerForward = player.GetWorldForward();
        let districtName  = this.GetPlayerDistrictName(player);
        let isRural       = this.IsRuralArea(districtName);
        let minDist: Float;
        let maxDist: Float;
        if isRural {
            minDist = this.settings.badlandsMinSpawnDist;
            maxDist = this.settings.badlandsMaxSpawnDist;
        } else {
            minDist = this.settings.immersiveCityMinSpawnDist;
            maxDist = this.settings.immersiveCityMaxSpawnDist;
        }
        let bestRoadside: Vector4 = new Vector4(0.0, 0.0, 0.0, 0.0);
        let bestRoadScore: Float  = -9999.0;
        let trafficNodes = SONC_GetNearbyVehicleSpawnPoints(playerPos, maxDist, minDist, 120.0, 60);
        if ArraySize(trafficNodes) > 0 {
            for nodeV3 in trafficNodes {
                let node = Vector4.Vector3To4(nodeV3);
                let dist = Vector4.Distance(node, playerPos);
                if dist >= minDist && dist <= maxDist {
                    let toNode        = Vector4.Normalize(node - playerPos);
                    let alignment     = Vector4.Dot(playerForward, toNode);
                    let forwardBias   = MaxF(alignment, 0.0) * 60.0;
                    let distPenalty   = dist * 0.25;
                    let score         = forwardBias - distPenalty;
                    let nearby        = SONC_GetNearbyVehicleSpawnPoints(node, 4.0, 0.0, 2.0, 6);
                    if ArraySize(nearby) <= 4 { score += 25.0; }
                    if score > bestRoadScore { bestRoadScore = score; bestRoadside = node; }
                }
            }
        }
        let spawnCandidate: Vector4;
        let isOffroad = false;
        if this.IsValidSpawnPoint(bestRoadside) && bestRoadScore > -2000.0 {
            spawnCandidate = bestRoadside;
        } else {
            spawnCandidate = this.FindValidOffroadSpawnPoint(playerPos, maxDist, minDist);
            isOffroad = true;
        }
        if !this.IsValidSpawnPoint(spawnCandidate) {
            return false;
        }
        let groundPos    = this.FindGroundBeneath(spawnCandidate);
        if !this.IsValidSpawnPoint(groundPos) {
            return false;
        }
        if AbsF(spawnCandidate.Z - groundPos.Z) > 8.0 {
            return false;
        }
        let finalPos   = groundPos;
        finalPos.Z    += 0.4;
        let validation = this.ValidateSpawnPoint(finalPos, minDist, maxDist, false, true, !isOffroad);
        if !validation.isValid {
            return false;
        }
        let dirToPlayer = playerPos - finalPos;
        dirToPlayer.Z   = 0.0;
        let finalOrient: Quaternion;
        if Vector4.Length2D(dirToPlayer) > 3.0 {
            finalOrient = Quaternion.BuildFromDirectionVector(Vector4.Normalize(dirToPlayer));
        } else {
            finalOrient = Quaternion.BuildFromDirectionVector(playerForward);
        }
        let vehicleRecordID = this.PickNonPoliceRecord(faction.vehiclePool);
        let vehicleSpec     = this.GetEntitySpec();
        vehicleSpec.recordID     = vehicleRecordID;
        vehicleSpec.position     = finalPos;
        vehicleSpec.orientation  = finalOrient;
        vehicleSpec.alwaysSpawned  = true;
        vehicleSpec.persistState   = false;
        vehicleSpec.persistSpawn   = false;
        ArrayPush(vehicleSpec.tags, n"SONC_Vehicle");
        ArrayPush(vehicleSpec.tags, n"PreventPersistence");
        ArrayPush(vehicleSpec.tags, n"IgnorePersistency");
        ArrayPush(vehicleSpec.tags, n"DynamicEntity");
        let vehicleID = GameInstance.GetDynamicEntitySystem().CreateEntity(vehicleSpec);
        this.ReturnEntitySpec(vehicleSpec);
        if !EntityID.IsDefined(vehicleID) { return false; }
        let cb         = new SONC_ReinforcePostVehicleCallback();
        cb.vehicleID   = vehicleID;
        cb.faction     = faction;
        cb.spawnPoint  = finalPos;
        cb.system      = this;
        cb.enemyIDs    = enemyIDs;
        GameInstance.GetDelaySystem(gi).DelayCallback(cb, 1.8 + RandRangeF(-0.4, 0.4));
        StreetsOfNightCity_Logger.Log("[DRONE REINF] Vehicle dispatched | Faction: " + NameToString(factionName));
        return true;
    }
    private func GetSpawnSearchAnchor(player: ref<PlayerPuppet>) -> Vector4 {
        let playerPos = player.GetWorldPosition();
        if player.IsInCombat() {
            let tracker = player.GetTargetTrackerComponent();
            if IsDefined(tracker) {
                let threats = tracker.GetHostileThreats(false);
                let bestDist = 999999.0;
                let bestPos = new Vector4(0.0, 0.0, 0.0, 0.0);
                let found = false;
                for threat in threats {
                    let obj = threat.entity as GameObject;
                    if IsDefined(obj) {
                        let pos = obj.GetWorldPosition();
                        let dist = Vector4.Distance(pos, playerPos);
                        if dist < bestDist {
                            bestDist = dist;
                            bestPos = pos;
                            found = true;
                        }
                    }
                }
                if found { return bestPos; }
            }
        }
        let fwd = player.GetWorldForward();
        let anchor = playerPos;
        anchor.X += fwd.X * 20.0;
        anchor.Y += fwd.Y * 20.0;
        return anchor;
    }
    private func GetForwardAnchor(player: ref<PlayerPuppet>) -> Vector4 {
        let playerPos = player.GetWorldPosition();
        let fwd = player.GetWorldForward();
        let anchor = playerPos;
        anchor.X += fwd.X * 20.0;
        anchor.Y += fwd.Y * 20.0;
        return anchor;
    }
    private func HasMinWallClearance(probeOrigin: Vector4, minClearance: Float) -> Bool {
        let spatialSys = GameInstance.GetSpatialQueriesSystem(this.GetGameInstance());
        let traceResult: TraceResult;
        let dirs: array<Vector4>;
        ArrayPush(dirs, new Vector4( 1.0,  0.0, 0.0, 0.0));
        ArrayPush(dirs, new Vector4(-1.0,  0.0, 0.0, 0.0));
        ArrayPush(dirs, new Vector4( 0.0,  1.0, 0.0, 0.0));
        ArrayPush(dirs, new Vector4( 0.0, -1.0, 0.0, 0.0));
        for dir in dirs {
            let rayEnd = probeOrigin + (dir * minClearance);
            if spatialSys.SyncRaycastByCollisionGroup(probeOrigin, rayEnd, n"Static", traceResult, false, false) { return false; }
        }
        return true;
    }
}
