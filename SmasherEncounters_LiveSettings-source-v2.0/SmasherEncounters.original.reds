enum SmasherHackType {
    None = 0,
    Vehicle = 1,
    Spawn = 2
}

public class SE_DelayDaemon extends DelayCallback {
    let gi: GameInstance;
    let delayID: DelayID;
    let isActive: Bool = false;
    let delay: Float = 1.00;
    let isAffectedByTimeDilation: Bool = false;

    func Start(gi: GameInstance, delay: Float, opt isAffectedByTimeDilation: Bool) -> Void {
        if this.IsActive() { return; };
        this.gi = gi;
        this.delay = delay;
        this.isAffectedByTimeDilation = isAffectedByTimeDilation;
        let delaySys = GameInstance.GetDelaySystem(gi);
        this.delayID = delaySys.DelayCallback(this, delay, isAffectedByTimeDilation);
        this.isActive = true;
    };

    func Stop() -> Void {
        if !this.IsActive() { return; };
        let delaySys = GameInstance.GetDelaySystem(this.gi);
        delaySys.CancelCallback(this.delayID);
        this.isActive = false;
    };

    func IsActive() -> Bool { return this.isActive; };

    func Repeat() -> Void {
        if !this.IsActive() { return; };
        let delaySys = GameInstance.GetDelaySystem(this.gi);
        this.delayID = delaySys.DelayCallback(this, this.delay, this.isAffectedByTimeDilation);
    };
}

@addMethod(Vector4)
public static func SE_Vector4To2(v4: Vector4) -> Vector2 {
    return new Vector2(v4.X, v4.Y);
}

public func SE_IsPointInPolygon(point: Vector2, polygon: array<Vector2>) -> Bool {
    let numPoints = ArraySize(polygon);
    if numPoints < 3 { return false; };
    let minX = polygon[0].X;
    let maxX = polygon[0].X;
    let minY = polygon[0].Y;
    let maxY = polygon[0].Y;
    for p in polygon {
        minX = MinF(p.X, minX);
        maxX = MaxF(p.X, maxX);
        minY = MinF(p.Y, minY);
        maxY = MaxF(p.Y, maxY);
    };
    if point.X < minX || point.X > maxX || point.Y < minY || point.Y > maxY { return false; };
    let isInside: Bool = false;
    let i: Int32 = 0;
    let j: Int32 = numPoints - 1;
    while i < numPoints {
        let denominator = polygon[j].Y - polygon[i].Y;
        if denominator != 0.0 && NotEquals((polygon[i].Y > point.Y), (polygon[j].Y > point.Y))
        && (point.X < (polygon[j].X - polygon[i].X) * (point.Y - polygon[i].Y) / denominator + polygon[i].X) {
            isInside = !isInside;
        };
        j = i;
        i += 1;
    };
    return isInside;
}

public func SE_GetCameraFrustumPoints(cam_transform: Transform, fov: Float, aspect_ratio: Float, far_distance: Float) -> array<Vector4> {
    let points: array<Vector4>;
    let cam_pos = cam_transform.GetPosition();
    let cam_fwd = cam_transform.GetForward();
    let cam_up = cam_transform.GetUp();
    let cam_right = cam_transform.GetRight();
    let near_distance = 0.4;
    let near_height = 2.0 * TanF(fov / 2.0) * near_distance;
    let near_width = near_height * aspect_ratio;
    let near_center = cam_pos + cam_fwd * near_distance;
    let far_height = 2.0 * TanF(fov / 2.0) * far_distance;
    let far_width = far_height * aspect_ratio;
    let far_center = cam_pos + cam_fwd * far_distance;
    ArrayPush(points, near_center + (cam_up * (near_height / 2.0)) - (cam_right * (near_width / 2.0)));
    ArrayPush(points, near_center + (cam_up * (near_height / 2.0)) + (cam_right * (near_width / 2.0)));
    ArrayPush(points, near_center - (cam_up * (near_height / 2.0)) - (cam_right * (near_width / 2.0)));
    ArrayPush(points, near_center - (cam_up * (near_height / 2.0)) + (cam_right * (near_width / 2.0)));
    ArrayPush(points, far_center + (cam_up * (far_height / 2.0)) - (cam_right * (far_width / 2.0)));
    ArrayPush(points, far_center + (cam_up * (far_height / 2.0)) + (cam_right * (far_width / 2.0)));
    ArrayPush(points, far_center - (cam_up * (far_height / 2.0)) - (cam_right * (far_width / 2.0)));
    ArrayPush(points, far_center - (cam_up * (far_height / 2.0)) + (cam_right * (far_width / 2.0)));
    return points;
}

public func SE_IsPointInCameraView(gi: GameInstance, point: Vector4, cam_pos: Vector4, frustum_points: array<Vector4>, up_fwd: Vector4, down_fwd: Vector4, check_sight_block: Bool) -> Bool {
    let horizontal_plane_points: array<Vector2> = [Vector4.SE_Vector4To2(frustum_points[0]), Vector4.SE_Vector4To2(frustum_points[1]), Vector4.SE_Vector4To2(frustum_points[4]), Vector4.SE_Vector4To2(frustum_points[5])];
    let p_distance = Vector4.Distance2D(cam_pos, point);
    let frustum_up = frustum_points[1] + (up_fwd * p_distance);
    let frustum_down = frustum_points[3] + (down_fwd * p_distance);
    if !SE_IsPointInPolygon(Vector4.SE_Vector4To2(point), horizontal_plane_points) { return false; };
    if point.Z > frustum_up.Z || point.Z < frustum_down.Z { return false; };
    let tr: TraceResult;
    if check_sight_block {
        if GameInstance.GetSpatialQueriesSystem(gi).SyncRaycastByQueryPreset(cam_pos, point, n"Sight Blocker", tr) { return false; };
    };
    return true;
}

public func SE_IsPointInAnyLoadedSecurityAreaRadius(point: Vector4, zone_types: array<ESecurityAreaType>, opt check_height: Bool) -> Bool {
    let gi: GameInstance = GetGameInstance();
    let smasherSys = GameInstance.GetSmasherEncountersSystem(gi);
    if !IsDefined(smasherSys) { return false; };
    
    if !IsDefined(smasherSys.m_areasResource) {
        let depot = GameInstance.GetResourceDepot();
        let token = depot.LoadResource(r"base\\worlds\\03_night_city\\_compiled\\default\\03_night_city.areas");
        smasherSys.m_areasResource = token.GetResource() as gameAreaResource;
    };
    
    if !IsDefined(smasherSys.m_areasResource) { return false; };

    for zone in smasherSys.m_areasResource.cookedData {
        let zone_pos_v4 = Vector4.Vector3To4(zone.position);
        let dist_to_zone_sq = Vector4.DistanceSquared(point, zone_pos_v4);
        if dist_to_zone_sq < zone.radius * zone.radius {
            let zone_ent = GameInstance.FindEntityByID(gi, zone.entityID) as SecurityArea;
            if IsDefined(zone_ent) {
                let zone_type = zone_ent.GetController().GetPS().GetSecurityAreaType();
                if ArrayContains(zone_types, zone_type) && SE_IsPointInSecurityAreaRadius(point, zone, check_height) { return true; };
            };
        };
    };
    return false;
}

public func SE_IsPointInSecurityAreaRadius(point: Vector4, zone: gameCookedAreaData, opt check_height: Bool) -> Bool {
    let zone_pos_v4 = Vector4.Vector3To4(zone.position);
    let dist_to_zone_sq = Vector4.DistanceSquared(point, zone_pos_v4);
    if dist_to_zone_sq >= zone.radius * zone.radius { return false; };
    if !check_height { return true; };
    let volume = zone.volume as gamemappinsOutlineMappinVolume;
    if !IsDefined(volume) { return true; };
    let zone_height = volume.height;
    return point.Z < zone.position.Z + zone_height && point.Z > zone.position.Z - zone_height;
}

public final static func SE_HasSpaceInFrontOfPoint(queryPosition: Vector4, queryDirection: Vector4, groundClearance: Float, areaWidth: Float, areaLength: Float, areaHeight: Float) -> Bool {
    let boxDimensions: Vector4;
    let boxOrientation: EulerAngles;
    let fitTestOvelap: TraceResult;
    let normalizedDirection = queryDirection;
    normalizedDirection.Z = 0.0;
    normalizedDirection = Vector4.Normalize(normalizedDirection);
    boxDimensions.X = areaWidth * 0.5;
    boxDimensions.Y = areaLength * 0.5;
    boxDimensions.Z = areaHeight * 0.5;
    queryPosition.Z += boxDimensions.Z + groundClearance;
    queryPosition += boxDimensions.Y * normalizedDirection;
    boxOrientation = Quaternion.ToEulerAngles(Quaternion.BuildFromDirectionVector(normalizedDirection));
    let sqs = GameInstance.GetSpatialQueriesSystem(GetGameInstance());
    return !sqs.Overlap(boxDimensions, queryPosition, boxOrientation, n"Static", fitTestOvelap) && !sqs.Overlap(boxDimensions, queryPosition, boxOrientation, n"Vehicle", fitTestOvelap) && !sqs.Overlap(boxDimensions, queryPosition, boxOrientation, n"Dynamic", fitTestOvelap);
}

public func SE_GetDistrictManager() -> ref<DistrictManager> {
    let preventionSys = GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"PreventionSystem") as PreventionSystem;
    if !IsDefined(preventionSys) { return null; };
    return preventionSys.m_districtManager;
}

public func SE_IsPlayerNearQuestMappin(min_distance: Float) -> Bool {
    let pins: array<ref<IMappin>> = GameInstance.GetMappinSystem(GetGameInstance()).GetAllMappins();
    for p in pins {
        if p.IsActive() && p.IsQuestMappin() {
            if (p as QuestMappin).IsInsideTrigger() || p.GetDistanceToPlayer() < min_distance { return true; };
        };
    };
    return false;
}





@wrapMethod(AIActionHelper)
public final static func TryChangingAttitudeToHostile(owner: ref<ScriptedPuppet>,
                                                      target: ref<GameObject>) -> Bool {
    let gi: GameInstance = GetGameInstance();
    let smasherSys = GameInstance.GetSmasherEncountersSystem(gi);
    let targetPuppet: ref<ScriptedPuppet>;
    if IsDefined(smasherSys) && smasherSys.IsSmasherEventInProgress() && (owner.IsPrevention() || owner.GetEntityID() == smasherSys.smasherID) {
        targetPuppet = target as ScriptedPuppet;
        if IsDefined(targetPuppet) && (targetPuppet.IsCivilian() || targetPuppet.IsCrowd()) {
            return false;
        };
    };
    return wrappedMethod(owner, target);
};

@wrapMethod(MinimapStealthMappinController)
protected func Update() -> Void {
    let gi: GameInstance = GetGameInstance();
    let smasherSys = GameInstance.GetSmasherEncountersSystem(gi);
    if !IsDefined(smasherSys) {
        wrappedMethod();
        return;
    }
    let smasherID = smasherSys.smasherID;
    if (this.m_mappin as StealthMappin).GetGameObject().GetEntityID() == smasherID {
        if !smasherSys.isSmasherDefeated() {
            this.SetForceShow(false);
            this.SetForceHide(true);
            return;
        } else {
            this.SetForceShow(true);
            this.SetForceHide(false);
        };
    };
    wrappedMethod();
};


@wrapMethod(MinimapContainerController)
public func CreateMappinUIProfile(mappin: wref<IMappin>,
                                  mappinVariant: gamedataMappinVariant, 
                                  customData: ref<MappinControllerCustomData>) -> MappinUIProfile {
    let UIProfile = wrappedMethod(mappin, mappinVariant, customData);
    let smasherSys = GameInstance.GetSmasherEncountersSystem(GetGameInstance());
    if IsDefined(smasherSys) && Equals(mappin.GetNewMappinID(), smasherSys.smasherMappinID) {
        return MappinUIProfile.Create(r"base\\gameplay\\gui\\widgets\\minimap\\minimap_world_encounter_mappin.inkwidget",
                                      t"MappinUISpawnProfile.WorldEncounter",
                                      t"MinimapMappinUIProfile.SmasherEncountersEvent");
    };
    return UIProfile;
};

@wrapMethod(StackRelaxedState)
public func GetDesiredHighLevelState(context: ScriptExecutionContext) -> gamedataNPCHighLevelState {
    let smasherSys = GameInstance.GetSmasherEncountersSystem(GetGameInstance());
    if IsDefined(smasherSys) && smasherSys.IsSmasherEventInProgress()
    && context.GetOwner().GetEntityID() == smasherSys.smasherID {
        return gamedataNPCHighLevelState.Alerted;
    };
    return wrappedMethod(context);
}

@wrapMethod(RelaxedState)
public func GetDesiredHighLevelState(context: ScriptExecutionContext) -> gamedataNPCHighLevelState {
    let smasherSys = GameInstance.GetSmasherEncountersSystem(GetGameInstance());
    if IsDefined(smasherSys) && smasherSys.IsSmasherEventInProgress()
    && context.GetOwner().GetEntityID() == smasherSys.smasherID {
        return gamedataNPCHighLevelState.Alerted;
    };
    return wrappedMethod(context);
}

@wrapMethod(ReactionManagerComponent)
private final func ShouldTriggerAggressiveCrowdNPCCombat(stimEvent: ref<StimuliEvent>) -> Bool {
    let smasherSys = GameInstance.GetSmasherEncountersSystem(GetGameInstance());
    if IsDefined(smasherSys) && smasherSys.IsSmasherEventInProgress() && !smasherSys.isSmasherDefeated() {
        return false;
    };
    return wrappedMethod(stimEvent);
};

@wrapMethod(DamageSystem)
private final func ProcessVehicleHit(hitEvent: ref<gameHitEvent>) -> Void {
    let gi: GameInstance = GetGameInstance();
    let smasherSys = GameInstance.GetSmasherEncountersSystem(gi);
    let vehicleHitEvent: ref<gameVehicleHitEvent> = hitEvent as gameVehicleHitEvent;
    wrappedMethod(hitEvent);
    if IsDefined(vehicleHitEvent)
    && IsDefined(smasherSys)
    && smasherSys.IsSmasherEventInProgress()
    && hitEvent.target == GameInstance.FindEntityByID(gi, smasherSys.smasherID) {
        hitEvent.attackComputed.MultAttackValue(0.10);
    };
};



@wrapMethod(GameObject)
public final static func ChangeAttitudeToHostile(owner: wref<GameObject>,
                                                 target: wref<GameObject>) -> Void {
    let gi: GameInstance = GetGameInstance();
    let smasherSys = GameInstance.GetSmasherEncountersSystem(gi);
    let targetPuppet: ref<ScriptedPuppet>;
    if IsDefined(smasherSys) && smasherSys.IsSmasherEventInProgress()
    && (owner.IsPrevention() || owner.GetEntityID() == smasherSys.smasherID) {
        targetPuppet = target as ScriptedPuppet;
        if IsDefined(targetPuppet) && (targetPuppet.IsCivilian() || targetPuppet.IsCrowd()) {
            return;
        };
    };
    wrappedMethod(owner, target);
};

@addMethod(GameInstance)
public final static func GetSmasherEncountersSystem(self: GameInstance) -> ref<SmasherEncountersEventSystem> {
    let container = GameInstance.GetScriptableSystemsContainer(self);
    if !IsDefined(container) { return null; };
    return container.Get(n"SmasherEncountersEventSystem") as SmasherEncountersEventSystem;
};

class SmasherEncountersEventStarterDaemon extends SE_DelayDaemon {
    func Call() -> Void {
        let smasherSys = GameInstance.GetSmasherEncountersSystem(this.gi);
        if !IsDefined(smasherSys) { return; };
        if smasherSys.TryStartNewSmasherEvent() {
            this.Stop();
        } else {
            if smasherSys.p_spawnPoints > 0.0 && !smasherSys.IsSafeToSpawn() {
                 smasherSys.CleanupSmasherEvent(true, "Event starter failed safety check");
                 this.Stop();
                 return;
            };
            this.Repeat();
        };
    };
}



class SmasherEncountersPlayerSecondsAwayDaemon extends SE_DelayDaemon {
    let smasher_detatched_pos: Vector4;
    let cached_distance_threshold: Float = 100.00;
    let seconds: Int32;

    func Call() -> Void {
        let smasherSys = GameInstance.GetSmasherEncountersSystem(this.gi);
        if !IsDefined(smasherSys) { return; };
        let player_pos = GetPlayer(this.gi).GetWorldPosition();
        let distance = Vector4.Distance(player_pos, this.smasher_detatched_pos);
        this.seconds += 1;
        if distance > this.cached_distance_threshold || this.seconds > 2 {
            smasherSys.OnPlayerSecondAway(distance, Cast<Uint16>(this.seconds));
        };
        this.Repeat();
    };
}

public class SmasherDeathListener extends ScriptStatPoolsListener {
    public let smasher: wref<NPCPuppet>;

    protected cb func OnStatPoolAdded() -> Bool {
        if !IsDefined(this.smasher) {
            return false;
        };
        let gi: GameInstance = this.smasher.GetGame();
        let statPoolsSystem = GameInstance.GetStatPoolsSystem(gi);
        let smasher_stats_ID = Cast<StatsObjectID>(this.smasher.GetEntityID());
        let smasherSys = GameInstance.GetSmasherEncountersSystem(gi);
        if !IsDefined(smasherSys) {
            return false;
        };
        
        let limit: Float = RandRangeF(10.0, 40.0);
        
        statPoolsSystem.RequestSettingStatPoolValueCustomLimit(smasher_stats_ID,
                                                               gamedataStatPoolType.Health,
                                                               limit,
                                                               null);
    };

    protected cb func OnStatPoolCustomLimitReached(value: Float) -> Bool {
        if !IsDefined(this.smasher) {
            return false;
        };
        let gi: GameInstance = GetGameInstance();
        let smasherSys = GameInstance.GetSmasherEncountersSystem(gi);
        if !IsDefined(smasherSys) {
            return false;
        };
        
        smasherSys.OnSmasherCowardEscape(this.smasher, value);
    };

    protected cb func OnStatPoolMinValueReached(value: Float) -> Bool {
        if !IsDefined(this.smasher) {
            return false;
        };
        let gi: GameInstance = GetGameInstance();
        let smasherSys = GameInstance.GetSmasherEncountersSystem(gi);
        if !IsDefined(smasherSys) {
            return false;
        };
        if !smasherSys.isSmasherDefeated() {
            smasherSys.OnSmasherIsDead(this.smasher);
        };
    };
}

class SmasherEncountersLastEncounterSecondsDaemon extends SE_DelayDaemon {
    let losCheckCounter: Int32 = 0;
    let losCheckInterval: Int32 = 4; 
    let lastHasLineOfSight: Bool = true; 
    
    func Start(gi: GameInstance, opt isAffectedByTimeDilation: Bool) -> Void {
        super.Start(gi, 0.5, isAffectedByTimeDilation);
    };

    func Call() -> Void {
        let smasherSys = GameInstance.GetSmasherEncountersSystem(this.gi);
        if !IsDefined(smasherSys) {
            this.Stop();
            return;
        };

        smasherSys.UpdatePendingSmsDelivery();
        
        let delaySys = GameInstance.GetDelaySystem(this.gi);

        if smasherSys.IsSmasherEventInProgress() && !smasherSys.isSmasherDefeated() {
            if EntityID.IsDefined(smasherSys.smasherID) {
                let smasher = GameInstance.FindEntityByID(this.gi, smasherSys.smasherID) as GameObject;
                if IsDefined(smasher) {
                    let player = GetPlayer(this.gi);
                    if IsDefined(player) {
                        let smasherPos = smasher.GetWorldPosition();
                        smasherSys.m_lastBufferUpdatePos = smasherPos;
                        let dist = Vector4.Distance(player.GetWorldPosition(), smasherPos);
                        if dist > 150.0 {
                            FTLog(s"[SmasherEncounters] Player escaped! Distance: \(dist)m. Ending event.");
                            smasherSys.CleanupSmasherEvent(true, "Player escaped (distance check)");
                        } else if smasherSys.IsSmasherCombatStarted() {
                            let smasherPuppet = smasher as NPCPuppet;
                            if IsDefined(smasherPuppet) {
                                let smasher_tt = smasherPuppet.GetTargetTrackerComponent();
                                if IsDefined(smasher_tt) {
                                    smasher_tt.AddThreat(player, true, player.GetWorldPosition(), 1.0, 10.0, true);
                                };

                                this.losCheckCounter += 1;
                                let shouldCheckLOS = (this.losCheckCounter >= this.losCheckInterval);
                                
                                if shouldCheckLOS {
                                    this.losCheckCounter = 0;
                                    let spatialQueriesSys = GameInstance.GetSpatialQueriesSystem(this.gi);
                                    let tr: TraceResult;
                                    let smasherEyePos = smasher.GetWorldPosition();
                                    smasherEyePos.Z += 2.0;
                                    let playerEyePos = player.GetWorldPosition();
                                    playerEyePos.Z += 1.5;
                                    
                                    let hasLineOfSight = !spatialQueriesSys.SyncRaycastByQueryPreset(smasherEyePos, playerEyePos, n"Sight Blocker", tr);
                                    this.lastHasLineOfSight = hasLineOfSight;
                                    
                                    let isAttacking = Equals(smasherPuppet.GetHighLevelStateFromBlackboard(), gamedataNPCHighLevelState.Combat);
                                    
                                    if !hasLineOfSight && !isAttacking {
                                        smasherSys.p_notSeenTimer += 0.5;
                                        if smasherSys.p_notSeenTimer >= 10.0 {
                                            smasherSys.CleanupSmasherEvent(true, "Smasher lost player for 10s");
                                        };
                                    } else {
                                        smasherSys.p_notSeenTimer = 0.0;
                                    };
                                } else {
                                    let isAttacking = Equals(smasherPuppet.GetHighLevelStateFromBlackboard(), gamedataNPCHighLevelState.Combat);
                                    
                                    if !this.lastHasLineOfSight && !isAttacking {
                                        smasherSys.p_notSeenTimer += 0.5;
                                        if smasherSys.p_notSeenTimer >= 10.0 {
                                            smasherSys.CleanupSmasherEvent(true, "Smasher lost player for 10s");
                                        };
                                    } else {
                                        smasherSys.p_notSeenTimer = 0.0;
                                    };
                                };
                            };
                        };
                    };
                } else {
                    let player = GetPlayer(this.gi);
                    if IsDefined(player) {
                        let distToLastPos = Vector4.Distance(player.GetWorldPosition(), smasherSys.m_lastBufferUpdatePos);
                        smasherSys.p_notSeenTimer += 0.5;
                        if distToLastPos > 150.0 || smasherSys.p_notSeenTimer >= 10.0 {
                             smasherSys.CleanupSmasherEvent(true, "Player escaped (entity lost timeout/distance)");
                        };
                    };
                };
            } else if Equals(smasherSys.p_pendingDistrictName, n"") {
                smasherSys.CleanupSmasherEvent(true, "Event active but no entity/pending district");
            };
        };

        smasherSys.m_spawnUpdateTick += 1;
        
        let player = GetPlayer(this.gi);
        if IsDefined(player) && PlayerPuppet.GetSceneTier(player) != 1 {
            SmasherHUDSystem.GetInstance(this.gi).RefreshDangerMeter();
            this.Repeat();
            return;
        };

        if smasherSys.settings.OnlyAfterHanako && GameInstance.GetQuestsSystem(this.gi).GetFact(n"q112_done") <= 0 {
            SmasherHUDSystem.GetInstance(this.gi).RefreshDangerMeter();
            this.Repeat();
            return;
        };

        let totalPoints = smasherSys.p_spawnPoints;

        if smasherSys.m_spawnUpdateTick % 60 == 0 {
            if !smasherSys.IsSmasherEventInProgress() {
                let districts: array<CName> = [n"CityCenter", n"Watson", n"Westbrook", n"Heywood", n"SantoDomingo", n"Pacifica", n"Badlands", n"Dogtown"];
                let playerDistrict = smasherSys.m_cachedDistrict;

                for district in districts {
                    let warningThreshold = Equals(NameToString(district), playerDistrict) ? 80.0 : 95.0;

                    if totalPoints >= warningThreshold {
                        if smasherSys.HasContactedDistrict(district) && !smasherSys.HasActiveWarning(district) {
                            smasherSys.SendWarningSMS(NameToString(district));
                            ArrayPush(smasherSys.p_districtsWithActiveWarning, district);
                        };
                    } else if totalPoints < (warningThreshold - 10.0) {
                        smasherSys.RemoveActiveWarning(district);
                    };
                };
            };

            let now = Cast<Int32>(GameInstance.GetTimeSystem(this.gi).GetGameTimeStamp());
            smasherSys.CleanupTimestamps(smasherSys.p_arasakaKillTimestamps, now, 86400); // 24h
            smasherSys.CleanupTimestamps(smasherSys.p_sandyUsageTimestamps, now, 28800); // 8h 
            smasherSys.CleanupTimestamps(smasherSys.p_berserkUsageTimestamps, now, 28800); // 8h 
            smasherSys.CleanupTimestamps(smasherSys.p_overclockUsageTimestamps, now, 28800); // 8h 
            smasherSys.CleanupTimestamps(smasherSys.p_edgerunnerFuryTimestamps, now, 43200); // 12h 
        };

        if smasherSys.m_spawnUpdateTick % 5 == 0 {
            let district_record = smasherSys.GetReliableDistrictRecord();
            if IsDefined(district_record) {
                smasherSys.m_cachedDistrict = district_record.EnumName();

                if !smasherSys.IsSmasherEventInProgress() && ArraySize(smasherSys.m_encounterPointBuffer) < smasherSys.m_maxBufferSize {
                    let playerPos = GetPlayer(this.gi).GetWorldPosition();
                    if !Vector4.IsXYZZero(playerPos) {
                        let potentialPoint = smasherSys.getSmasherSpawnPoint(playerPos, smasherSys.m_cachedDistrict);
                        if !Vector4.IsXYZZero(potentialPoint) {
                            ArrayPush(smasherSys.m_encounterPointBuffer, potentialPoint);
                        };
                    };
                };
            };
        };
        
        if totalPoints >= 100.0 {
            if !smasherSys.p_isWaitingForSpawnSafety {
                smasherSys.p_isWaitingForSpawnSafety = true;
                FTLog("[SmasherEncounters] Reached 100 points. Initiating spawn procedure.");
            };

            if smasherSys.p_isWaitingForSpawnSafety && smasherSys.IsSafeToSpawn() {
                smasherSys.p_isWaitingForSpawnSafety = false;
                smasherSys.RequestStartSmasherEvent();
            };
        };

        SmasherHUDSystem.GetInstance(this.gi).RefreshDangerMeter();

        this.Repeat();
    };
}

class SmasherBreathingDaemon extends SE_DelayDaemon {
    func Call() -> Void {
        let player = GetPlayer(this.gi);
        if IsDefined(player) {
            let breathEvt: ref<SoundPlayEvent> = new SoundPlayEvent();
            breathEvt.soundName = n"ono_v_breath_fast";
            player.QueueEvent(breathEvt);
        };
        this.Repeat();
    };
}

struct SmasherLightComponentContainer {
    public let lightComponent: wref<gameLightComponent>;
    public let initialColor: Color;
}

class SmasherFlickerLightsDaemon extends SE_DelayDaemon {
    let isOff: Bool = false;
    let hasChangedColor: Bool = false;
    let lightColors: array<SmasherLightComponentContainer>;
    let m_cls: wref<CityLightSystem>;

    func Call() -> Void {
        let smasherSys = GameInstance.GetSmasherEncountersSystem(this.gi);
        if !IsDefined(smasherSys) || !smasherSys.IsSmasherEventInProgress() || !smasherSys.settings.EnablePreSpawnEffects {
            this.Stop();
            return;
        };

        if !IsDefined(this.m_cls) {
            this.m_cls = GameInstance.GetScriptableSystemsContainer(this.gi).Get(n"CityLightSystem") as CityLightSystem;
        }

        if !this.hasChangedColor {
            let redColor: Color;
            redColor.Red = Cast<Uint8>(255u);
            redColor.Green = Cast<Uint8>(0u);
            redColor.Blue = Cast<Uint8>(0u);

            let i = 0;
            while i < ArraySize(smasherSys.m_trackedLights) {
                let comp = smasherSys.m_trackedLights[i];
                if IsDefined(comp) {
                    let container: SmasherLightComponentContainer;
                    container.lightComponent = comp;
                    container.initialColor = comp.color;
                    ArrayPush(this.lightColors, container);

                    comp.SetColor(redColor);
                };
                i += 1;
            };
            this.hasChangedColor = true;
        };

        if IsDefined(this.m_cls) {
            let request = new ForceCLSStateRequest();
            request.sourceName = n"SmasherEncounterGlitches";
            request.priority = EPriority.Absolute;
            request.removePreviousRequests = true;
            request.savable = false;

            if this.isOff {
                request.state = ECLSForcedState.DEFAULT;
                this.isOff = false;
            } else {
                request.state = ECLSForcedState.ForcedOFF;
                this.isOff = true;
            };
            this.m_cls.QueueRequest(request);
        };

        this.delay = RandRangeF(1.0, 2.0);
        this.Repeat();
    };

    func Stop() -> Void {
        super.Stop();

        if this.hasChangedColor {
            let i = 0;
            while i < ArraySize(this.lightColors) {
                let container = this.lightColors[i];
                if IsDefined(container.lightComponent) {
                    container.lightComponent.SetColor(container.initialColor);
                };
                i += 1;
            };
            ArrayClear(this.lightColors);
            this.hasChangedColor = false;
        };

        if IsDefined(this.m_cls) {
            let request = new ForceCLSStateRequest();
            request.state = ECLSForcedState.DEFAULT;
            request.sourceName = n"SmasherEncounterGlitches";
            request.removePreviousRequests = true;
            this.m_cls.QueueRequest(request);
        };
    };
}


class SmasherEncountersSpawnDelayCallback extends DelayCallback {
    let smasherSpec: ref<DynamicEntitySpec>;
    let districtName: String;

    func Call() -> Void {
        let gi: GameInstance = GetGameInstance();
        let smasherSys = GameInstance.GetSmasherEncountersSystem(gi);
        if !IsDefined(smasherSys) { return; };
        
        let player = GetPlayer(gi);
        let center: Vector4 = player.GetWorldPosition();
        let new_spawn_point = smasherSys.getSmasherSpawnPoint(center, this.districtName);

        if Vector4.IsXYZZero(new_spawn_point) {
            smasherSys.CleanupSmasherEvent(true, "No valid spawn point found");
            return;
        };

        this.smasherSpec.position = new_spawn_point;
        
        smasherSys.ExecuteSpawn(this.smasherSpec);
    };
}

class SmasherStatMultiplierApplyCallback extends DelayCallback {
    let smasher: wref<NPCPuppet>;

    func Call() -> Void {
        if IsDefined(this.smasher) {
            let smasherSys = GameInstance.GetSmasherEncountersSystem(GetGameInstance());
            if IsDefined(smasherSys) {
                smasherSys.ApplySmasherStatMultipliers(this.smasher);
            };
        };
    };
}

class SmasherSupportUnitSpawnerDaemon extends SE_DelayDaemon {
    func Call() -> Void {
        let smasherSys = GameInstance.GetSmasherEncountersSystem(this.gi);
        if !IsDefined(smasherSys) {
            this.Stop();
            return;
        };
        
        if !smasherSys.IsSmasherCombatStarted() || smasherSys.isSmasherDefeated() {
            this.Stop();
            return;
        };
        
        if IsDefined(smasherSys.settings) && !smasherSys.settings.EnableSmasherSupportUnits {
            this.Stop();
            return;
        };

        let districtName = smasherSys.GetReliableDistrictRecord().EnumName();
        let chance = Cast<Float>(smasherSys.GetSupportUnitChance(districtName)) * smasherSys.settings.DifficultyMultiplier;
        let roll = RandRangeF(0.0, 100.0);
        
        FTLog(s"[SmasherEncounters] Support attempt - Chance: \(chance)%, Roll: \(roll)");
        
        if roll < chance {
            smasherSys.SpawnSupportUnit();
        };
        
        let minDelay = 180.0 / smasherSys.settings.DifficultyMultiplier;
        let maxDelay = 240.0 / smasherSys.settings.DifficultyMultiplier;
        this.delay = RandRangeF(minDelay, maxDelay);
        this.Repeat();
    };
}

class SmasherCombatEffectsDaemon extends SE_DelayDaemon {
    func Call() -> Void {
        let smasherSys = GameInstance.GetSmasherEncountersSystem(this.gi);
        
        if !IsDefined(smasherSys) {
            this.Stop();
            return;
        };
        
        if !smasherSys.IsSmasherCombatStarted() || smasherSys.isSmasherDefeated() {
            this.Stop();
            return;
        };
        
        if IsDefined(smasherSys.settings) && !smasherSys.settings.EnableSmasherCombatEffects {
            this.Stop();
            return;
        };

        let smasher = GameInstance.FindEntityByID(this.gi, smasherSys.smasherID) as GameObject;
        if IsDefined(smasher) {
            let player = GetPlayer(this.gi);
            if IsDefined(player) {
                let dist = Vector4.Distance(player.GetWorldPosition(), smasher.GetWorldPosition());
                if dist > 100.0 {
                    smasherSys.CleanupSmasherEvent(true, "Combat effects distance check");
                    return;
                };
            };
        } else {
            smasherSys.CleanupSmasherEvent(true, "Combat effects entity lost");
            return;
        };

        let level = smasherSys.p_smasherLevel;
        let chance = (2.0 + Cast<Float>(level - 60) * 0.1) * smasherSys.settings.DifficultyMultiplier;
        
        if Cast<Float>(RandRange(0, 100)) < chance {
            this.ApplyRandomEffectPackage();
        }

        let minDelay = 7.0 / (1.0 + smasherSys.settings.DifficultyMultiplier * 0.05);
        let maxDelay = 14.0 / (1.0 + smasherSys.settings.DifficultyMultiplier * 0.05);
        this.delay = RandRangeF(minDelay, maxDelay);
        this.Repeat();
    };

    private func ApplyRandomEffectPackage() -> Void {
        let player = GetPlayer(this.gi);
        if !IsDefined(player) {
            return;
        };
        
        let smasherSys = GameInstance.GetSmasherEncountersSystem(this.gi);
        if !IsDefined(smasherSys) {
            return;
        };

        smasherSys.PlayRandomScream();

        let pID = player.GetEntityID();
        let ses = GameInstance.GetStatusEffectSystem(this.gi);
        if !IsDefined(ses) {
            return;
        };
        
        let roll = RandRange(1, 6);

        switch roll {
            case 1:
                GameObjectEffectHelper.StartEffectEvent(player, n"blood_onscreen", true);
                ses.ApplyStatusEffect(pID, t"BaseStatusEffect.Electrocuted");
                ses.ApplyStatusEffect(pID, t"BaseStatusEffect.BaseBrainMelt");
                ses.ApplyStatusEffect(pID, t"BaseStatusEffect.BikeKnockdown");
                break;
            case 2:
                GameObjectEffectHelper.StartEffectEvent(player, n"blood_onscreen", true);
                ses.ApplyStatusEffect(pID, t"BaseStatusEffect.Electrocuted");
                ses.ApplyStatusEffect(pID, t"BaseStatusEffect.LocomotionMalfunction");
                break;
            case 3:
                ses.ApplyStatusEffect(pID, t"BaseStatusEffect.Electrocuted");
                ses.ApplyStatusEffect(pID, t"BaseStatusEffect.BossWeaponMalfunctionLvl4PlusPlus");
                break;
            case 4:
                GameObjectEffectHelper.StartEffectEvent(player, n"blood_onscreen", true);
                ses.ApplyStatusEffect(pID, t"BaseStatusEffect.Electrocuted");
                ses.ApplyStatusEffect(pID, t"BaseStatusEffect.CyberwareMalfunction");
                break;
            case 5:
                ses.ApplyStatusEffect(pID, t"BaseStatusEffect.Electrocuted");
                ses.ApplyStatusEffect(pID, t"AIQuickHackStatusEffect.HackBlind");
                break;
        };
    };
}

class SmasherVehicleHackDaemon extends SE_DelayDaemon {
    let m_hackProgress: Float = 0.0;
    let m_vehicle: wref<VehicleObject>;
    public let m_showingUI: Bool = false;
    public let m_hackUIVisible: Bool = false;
    let m_hackTriggered: Bool = false;

    
    func Call() -> Void {
        let smasherSys = GameInstance.GetSmasherEncountersSystem(this.gi);
        if !IsDefined(smasherSys) {
            this.ResetHack();
            this.Stop();
            return;
        };
        
        let player = GetPlayer(this.gi);
        if !IsDefined(player) {
            this.ResetHack();
            this.Repeat();
            return;
        };
        
        let playerVehicle = player.GetMountedVehicle();
        
        if !IsDefined(smasherSys.settings) || !smasherSys.settings.EnableVehicleHacking {
            this.ResetHack();
            this.Repeat();
            return;
        };
        
        if !smasherSys.IsSmasherEventInProgress()
           || smasherSys.isSmasherDefeated()
           || !IsDefined(playerVehicle) {
            this.ResetHack();
            this.Repeat();
            return;
        };
        
        let vehicleSpeed = AbsF(playerVehicle.GetCurrentSpeed());
        if vehicleSpeed < 1.0 {
            this.ResetHack();
            this.Repeat();
            return;
        };
        
        this.m_vehicle = playerVehicle;
        
        if !this.m_hackUIVisible {
            let hackSpeed: Float;
            if this.m_showingUI {
                hackSpeed = 9.0; 
            } else {
                hackSpeed = 10.0;
            };
            this.m_hackProgress += hackSpeed;
        }

        
        if this.m_hackProgress >= 20.0 && !this.m_showingUI {
            smasherSys.ShowBreakAttackChoice();
            this.m_showingUI = true;
        };

        
        if this.m_hackProgress >= 100.0 && !this.m_hackTriggered {
            this.StopVehicle();
            this.m_hackTriggered = true;
        };
        
        this.Repeat();

    };
    
    public func StartHackUI() -> Void {
        if this.m_hackUIVisible { return; };
        this.m_hackUIVisible = true;
        let player = GetPlayer(this.gi);

        if IsDefined(this.m_vehicle) {
            GameObjectEffectHelper.StartEffectEvent(this.m_vehicle, n"immobilized", false);
        };
        
        let soundEvt: ref<SoundPlayEvent> = new SoundPlayEvent();
        soundEvt.soundName = n"dev_turret_hacking";
        player.QueueEvent(soundEvt);

        let smasherSys = GameInstance.GetSmasherEncountersSystem(this.gi);
        if IsDefined(smasherSys) {
            smasherSys.StartSmasherMinigame("Vehicle Subsystem Breach", SmasherHackType.Vehicle);
        }
        
        this.m_showingUI = true;
    };
    
    func StopVehicle() -> Void {
        if !IsDefined(this.m_vehicle) { return; };
        
        let player = GetPlayer(this.gi);
        
        this.m_vehicle.SetVehicleRemoteControlled(true, false, false);
        
        this.m_vehicle.ActivateNetrunnerQuickhack(VehicleNetrunnerQuickhackType.ForceBrakes);
        
        this.m_vehicle.ForceBrakesUntilStoppedOrFor(15.0);
        this.m_vehicle.TurnEngineOn(false);
        
        GameObjectEffectHelper.StartEffectEvent(this.m_vehicle, n"emp_hit", true);
        GameObjectEffectHelper.StartEffectEvent(player, n"blood_onscreen", true);
        
        let pID = player.GetEntityID();
        let ses = GameInstance.GetStatusEffectSystem(this.gi);
        if IsDefined(ses) {
            ses.ApplyStatusEffect(pID, t"BaseStatusEffect.Electrocuted");
            ses.ApplyStatusEffect(pID, t"BaseStatusEffect.CyberwareMalfunction");
        }
    };
    
    func ResetHack() -> Void {
        if this.m_showingUI {
            let player = GetPlayer(this.gi);
            
            if IsDefined(this.m_vehicle) {
                GameObjectEffectHelper.StopEffectEvent(this.m_vehicle, n"immobilized");
                
                this.m_vehicle.SetVehicleRemoteControlled(false, false, false);
                this.m_vehicle.TurnEngineOn(true);
            };
        };
        this.m_hackProgress = 0.0;
        this.m_showingUI = false;
        this.m_hackUIVisible = false;
        this.m_hackTriggered = false;

    };
    
    func Stop() -> Void {
        this.ResetHack();
        super.Stop();
    };
}

class SmasherEncountersPeriodicSpawnCheckDaemon extends SE_DelayDaemon {
    func Call() -> Void {
        let smasherSys = GameInstance.GetSmasherEncountersSystem(this.gi);
        if !IsDefined(smasherSys) {
            this.Stop();
            return;
        };

        if !smasherSys.IsSmasherEventInProgress() && !smasherSys.isSmasherDefeated() {
            let chance = smasherSys.p_spawnPoints * 0.1;
            let roll = RandF() * 100.0;

            if roll < chance && smasherSys.IsSafeToSpawn() {
                FTLog(s"[SmasherEncounters] Spawn check roll succeeded (\(chance)%). Starting event.");
                smasherSys.RequestStartSmasherEvent();
            };
        };

        this.Repeat();
    };
}

struct PointTimestamp {
    let timestamp: Int32;
    let points: Float;
}

public class SmasherEncountersEventSystem extends ScriptableSystem {
    persistent let p_spawnPoints: Float;
    persistent let p_isWaitingForSpawnSafety: Bool = false;
    persistent let isSmasherEventInProgress: Bool = false;
    private let isCleaningUp: Bool = false;
    persistent let smasherID: EntityID;
    persistent let p_spawnDelayID: DelayID;
    let smasherMappinID: NewMappinID;
    persistent let smasherIsDead: Bool = false;
    persistent let isSmasherCombatStarted: Bool = false;
    persistent let p_notSeenTimer: Float;
    let m_callbacksRegistered: Bool;
    let m_spawnUpdateTick: Int32;
    private let p_awaitingBreakAttackChoice: Bool;
    private let p_activeHackType: SmasherHackType;
    private let p_hackingStateListener: ref<CallbackHandle>;
    persistent let p_pendingDistrictName: CName;

    let m_cachedDistrict: String;


    persistent let p_smasherLevel: Int32;
    persistent let p_smasherEscapeCount: Int32;

    persistent let p_lastSmasherAppearance_CityCenter: Int32;
    persistent let p_lastSmasherAppearance_Watson: Int32;
    persistent let p_lastSmasherAppearance_Westbrook: Int32;
    persistent let p_lastSmasherAppearance_Heywood: Int32;
    persistent let p_lastSmasherAppearance_SantoDomingo: Int32;
    persistent let p_lastSmasherAppearance_Pacifica: Int32;
    persistent let p_lastSmasherAppearance_Badlands: Int32;
    persistent let p_lastSmasherAppearance_Dogtown: Int32;

    let lastEncounterSecondsDaemon: ref<SmasherEncountersLastEncounterSecondsDaemon>;
    let periodicSpawnCheckDaemon: ref<SmasherEncountersPeriodicSpawnCheckDaemon>;
    let smasherDeathListener: ref<SmasherDeathListener>;
    let playerSecondsAwayDaemon: ref<SmasherEncountersPlayerSecondsAwayDaemon>;
    let breathingDaemon: ref<SmasherBreathingDaemon>;
    let flickerDaemon: ref<SmasherFlickerLightsDaemon>;
    let supportUnitDaemon: ref<SmasherSupportUnitSpawnerDaemon>;
    let combatEffectsDaemon: ref<SmasherCombatEffectsDaemon>;
    let vehicleHackDaemon: ref<SmasherVehicleHackDaemon>;
    let m_trackedLights: array<wref<gameLightComponent>>;

    persistent let isSmasherSmsUnlocked: Bool = false;
    persistent let usedSmsHashes: array<CName>;
    persistent let lastSmasherSmsHash: CName;
    persistent let p_contactedDistricts: array<CName>;
    persistent let p_districtsWithActiveWarning: array<CName>;

    persistent let p_pendingRewardSmsAt: Float;
    persistent let p_pendingRewardSmsDistrict: CName;
    persistent let p_pendingWarningSmsTimes: array<Float>;
    persistent let p_pendingWarningSmsDistricts: array<CName>;

    let m_smasherContactListener: ref<IScriptable>;

    persistent let spawnedSupportIDs: array<EntityID>;
    persistent let p_arasakaKillTimestamps: array<PointTimestamp>;
    persistent let p_sandyUsageTimestamps: array<PointTimestamp>;
    persistent let p_berserkUsageTimestamps: array<PointTimestamp>;
    persistent let p_overclockUsageTimestamps: array<PointTimestamp>;
    persistent let p_edgerunnerFuryTimestamps: array<PointTimestamp>;

    public let m_encounterPointBuffer: array<Vector4>;
    public let m_maxBufferSize: Int32 = 5;
    public let m_lastBufferUpdatePos: Vector4;
    let settings: ref<SmasherEncountersSettings>;
    let m_areasResource: ref<gameAreaResource>;
    persistent let p_smasherStatsAppliedTo: EntityID;
    persistent let p_smasherStatMultAppliedTo: EntityID;
    
    private func OnAttach() -> Void {
        this.InitializeSystem();
    };

    private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void {
        this.InitializeSystem();
    };

    private func InitializeSystem() -> Void {
        ModSettings.RegisterListenerToModifications(this);
        if !IsDefined(this.settings) {
            this.settings = new SmasherEncountersSettings();
        };
        if !this.IsModEnabled() { return; };
        if this.p_smasherLevel == 0 { this.p_smasherLevel = 60; }

        if !IsDefined(this.m_smasherContactListener) {
            this.m_smasherContactListener = SE_CreateAndRegisterSmasherContact(GetGameInstance());
        };

        this.RegisterCallbacks();
        this.StartNewMinutesSinceLastEncounterCallback();

        if !IsDefined(this.periodicSpawnCheckDaemon) {
            this.periodicSpawnCheckDaemon = new SmasherEncountersPeriodicSpawnCheckDaemon();
            this.periodicSpawnCheckDaemon.Start(GetGameInstance(), 600.0, true);
        };
    }

    private func GetDistrictBaseMultiplier(key: String) -> Float {
        switch key {
            case "CityCenter": return 1.5;
            case "Watson": return 1.0;
            case "Westbrook": return 0.8;
            case "Heywood": return 0.6;
            case "SantoDomingo": return 0.4;
            case "Pacifica": return 0.3;
            case "Badlands": return 0.2;
            case "Dogtown": return 0.1;
        };
        return 0.0;
    }

    private func GetLastAppearanceTime(key: String) -> Int32 {
        switch key {
            case "CityCenter": return this.p_lastSmasherAppearance_CityCenter;
            case "Watson": return this.p_lastSmasherAppearance_Watson;
            case "Westbrook": return this.p_lastSmasherAppearance_Westbrook;
            case "Heywood": return this.p_lastSmasherAppearance_Heywood;
            case "SantoDomingo": return this.p_lastSmasherAppearance_SantoDomingo;
            case "Pacifica": return this.p_lastSmasherAppearance_Pacifica;
            case "Badlands": return this.p_lastSmasherAppearance_Badlands;
            case "Dogtown": return this.p_lastSmasherAppearance_Dogtown;
        };
        return 0;
    }

    private func RegisterCallbacks() -> Void {
        if this.m_callbacksRegistered {
            return;
        }

        GameInstance.GetCallbackSystem().RegisterCallback(n"Entity/Attached", this, n"OnEntityAttached")
            .AddTarget(EntityTarget.RecordID(t"Devices.ElectricLight"))
            .AddTarget(EntityTarget.RecordID(t"Character.Smasher"))
            .AddTarget(EntityTarget.RecordID(t"Character.SmasherEncounters_Smasher"));

        GameInstance.GetCallbackSystem().RegisterCallback(n"Entity/Detached", this, n"OnEntityDetached")
            .AddTarget(EntityTarget.RecordID(t"Character.Smasher"))
            .AddTarget(EntityTarget.RecordID(t"Character.SmasherEncounters_Smasher"));

        this.m_callbacksRegistered = true;
    }

    public cb func OnModSettingsChange() -> Void {
        this.InitializePersistentState();
        if IsDefined(this.settings) && !this.settings.EnableSmasherCombatEffects && IsDefined(this.combatEffectsDaemon) {
            this.combatEffectsDaemon.Stop();
            this.combatEffectsDaemon = null;
        };
        if IsDefined(this.settings) && !this.settings.EnableSmasherSupportUnits && IsDefined(this.supportUnitDaemon) {
            this.supportUnitDaemon.Stop();
            this.supportUnitDaemon = null;
        };
        SmasherHUDSystem.GetInstance(this.GetGameInstance()).OnSettingsChanged();
    };

    private func InitializePersistentState() -> Void {
        if !IsDefined(this.settings) {
            this.settings = new SmasherEncountersSettings();
        };
        if this.p_smasherLevel == 0 { this.p_smasherLevel = 60; }
    }

    public func IsModEnabled() -> Bool {
        if IsDefined(this.settings) { return this.settings.ModEnabled; };
        return true;
    };

    public func ShowBreakAttackChoice() -> Void {
        if IsDefined(this.settings) && !this.settings.EnableHackDisruption { return; };
        if this.p_awaitingBreakAttackChoice { return; };
        this.p_awaitingBreakAttackChoice = true;

        let gi = this.GetGameInstance();
        let bboard = GameInstance.GetBlackboardSystem(gi).Get(GetAllBlackboardDefs().UIInteractions);
        
        let data: InteractionChoiceHubData;
        data.active = true;
        data.title = "Smasher Attack";
        
        let choice: InteractionChoiceData;
        choice.localizedName = "Disrupt Smasher’s hack";

        choice.inputAction = n"ChoiceApply"; // 'F'
        ArrayPush(data.choices, choice);
        
        bboard.SetVariant(GetAllBlackboardDefs().UIInteractions.InteractionChoiceHub, data);
    }

    public func HideBreakAttackChoice() -> Void {
        this.p_awaitingBreakAttackChoice = false;
        let gi = this.GetGameInstance();
        let bboard = GameInstance.GetBlackboardSystem(gi).Get(GetAllBlackboardDefs().UIInteractions);
        
        let data: InteractionChoiceHubData;
        data.active = false;
        
        bboard.SetVariant(GetAllBlackboardDefs().UIInteractions.InteractionChoiceHub, data);
    }

    public func StartSmasherMinigame(name: String, hackType: SmasherHackType) -> Void {
        let gi = this.GetGameInstance();
        let player = GetPlayer(gi);
        let bbNetwork = GameInstance.GetBlackboardSystem(gi).Get(GetAllBlackboardDefs().NetworkBlackboard);
        let bbMinigame = GameInstance.GetBlackboardSystem(gi).Get(GetAllBlackboardDefs().HackingMinigame);
        
        this.p_activeHackType = hackType;
        
        if !IsDefined(this.p_hackingStateListener) {
            this.p_hackingStateListener = bbMinigame.RegisterListenerInt(GetAllBlackboardDefs().HackingMinigame.State, this, n"OnMinigameStateChanged");
        };

        bbNetwork.SetInt(GetAllBlackboardDefs().NetworkBlackboard.DevicesCount, 1);
        bbNetwork.SetBool(GetAllBlackboardDefs().NetworkBlackboard.OfficerBreach, false);
        bbNetwork.SetBool(GetAllBlackboardDefs().NetworkBlackboard.RemoteBreach, true);
        bbNetwork.SetString(GetAllBlackboardDefs().NetworkBlackboard.NetworkName, name);
        bbNetwork.SetVariant(GetAllBlackboardDefs().NetworkBlackboard.MinigameDef, ToVariant(t"minigame_v2.DefaultItemMinigameVeryHard"));
        bbNetwork.SetInt(GetAllBlackboardDefs().NetworkBlackboard.Attempt, 1);
        bbNetwork.SetEntityID(GetAllBlackboardDefs().NetworkBlackboard.DeviceID, player.GetEntityID());
        
        bbMinigame.SetInt(GetAllBlackboardDefs().HackingMinigame.State, 1); // 1 = InProgress
    }

    protected cb func OnMinigameStateChanged(state: Int32) -> Void {
        if state == 2 || state == 3 { // 2 = Succeeded, 3 = Failed
            let succeeded = (state == 2);
            
            if IsDefined(this.p_hackingStateListener) {
                let bbMinigame = GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().HackingMinigame);
                bbMinigame.UnregisterListenerInt(GetAllBlackboardDefs().HackingMinigame.State, this.p_hackingStateListener);
                this.p_hackingStateListener = null;
            };

            switch this.p_activeHackType {
                case SmasherHackType.Vehicle:
                    if succeeded {
                        if IsDefined(this.vehicleHackDaemon) {
                            this.vehicleHackDaemon.Stop();
                        };
                        this.GiveQuickhackMaterialReward();
                    } else {
                        if IsDefined(this.vehicleHackDaemon) {
                            this.vehicleHackDaemon.m_hackUIVisible = false;
                            this.vehicleHackDaemon.m_hackProgress = 100.0;
                        };
                        this.ApplyMinigameFailurePenalty();
                    };
                    break;
                case SmasherHackType.Spawn:
                    if succeeded {
                        FTLog("[SmasherEncounters] Hack succeeded, canceling spawn.");
                        this.CancelSmasherSpawn();
                        this.GiveQuickhackMaterialReward();
                    } else {
                        FTLog("[SmasherEncounters] Hack failed, attempting immediate spawn.");
                        if !EntityID.IsDefined(this.smasherID) && NotEquals(this.p_pendingDistrictName, n"") {
                             FTLog(s"[SmasherEncounters] Pending district: \(NameToString(this.p_pendingDistrictName))");
                             GameInstance.GetDelaySystem(this.GetGameInstance()).CancelCallback(this.p_spawnDelayID);
                             
                             let districtNameStr = NameToString(this.p_pendingDistrictName);
                             let player = GetPlayer(this.GetGameInstance());
                             let new_center = player.GetWorldPosition();
                             let new_spawn_point = this.getSmasherSpawnPoint(new_center, districtNameStr);
                             
                             if !Vector4.IsXYZZero(new_spawn_point) {
                                  FTLog(s"[SmasherEncounters] New spawn point: \(new_spawn_point)");
                                  let smasherSpec = this.GetSmasherEntitySpec(districtNameStr);
                                  smasherSpec.position = new_spawn_point;
                                  this.ExecuteSpawn(smasherSpec);
                                  this.p_pendingDistrictName = n"";
                             } else {
                                  FTLog("[SmasherEncounters] WARNING: Could not find valid spawn point for immediate spawn! Aborting.");
                                  this.CleanupSmasherEvent(true, "Immediate spawn failed - no valid point");
                             }
                        } else {
                             FTLog(s"[SmasherEncounters] Immediate spawn condition not met: smasherID defined? \(EntityID.IsDefined(this.smasherID)), district: \(NameToString(this.p_pendingDistrictName))");
                        }
                        this.ApplyMinigameFailurePenalty();
                    };
                    break;
            };


            this.p_activeHackType = SmasherHackType.None;
        };
    }
    
    
    private func GiveQuickhackMaterialReward() -> Void {
        let player = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) { return; };
        
        let transactionSys = GameInstance.GetTransactionSystem(this.GetGameInstance());
        let materialID = t"Items.QuickHackLegendaryMaterial1";
        let baseAmount = RandRange(5, 11);
        
        let multiplier: Float = 1.0;
        if IsDefined(this.settings) {
            multiplier = this.settings.QuickhackMaterialMultiplier;
        };
        let finalAmount = Cast<Int32>(Cast<Float>(baseAmount) * multiplier);
        
        transactionSys.GiveItem(player, ItemID.FromTDBID(materialID), finalAmount);
    }

    
    private func ApplyMinigameFailurePenalty() -> Void {
        let player = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) { return; };
        
        let ses = GameInstance.GetStatusEffectSystem(this.GetGameInstance());
        let playerID = player.GetEntityID();
        
        if IsDefined(ses) {
            ses.ApplyStatusEffect(playerID, t"BaseStatusEffect.Electrocuted");
            ses.ApplyStatusEffect(playerID, t"BaseStatusEffect.CyberwareMalfunction");
        }
    }


    public func TriggerBreakAttackHack() -> Void {
        this.HideBreakAttackChoice();

        if IsDefined(this.vehicleHackDaemon) && this.vehicleHackDaemon.m_showingUI && !this.vehicleHackDaemon.m_hackUIVisible {
             this.vehicleHackDaemon.StartHackUI();
             return;
        };

        if this.isSmasherEventInProgress && !EntityID.IsDefined(this.smasherID) {
            this.StartSmasherMinigame("Unauthorized Signal Detected", SmasherHackType.Spawn);
        };


    }


    private cb func OnEntityAttached(evt: ref<EntityLifecycleEvent>) -> Void {
        let entity = evt.GetEntity();
        if !IsDefined(entity) { return; };
        
        if entity.GetEntityID() == this.smasherID {
            let smasher = entity as NPCPuppet;
            if IsDefined(smasher) {
                 this.OnSmasherAttached(smasher, !this.isSmasherCombatStarted);
            }
            return;
        }

        
        let components = entity.GetComponents();
        let i = 0;
        while i < ArraySize(components) {
            let comp = components[i] as gameLightComponent;
            if IsDefined(comp) {
                ArrayPush(this.m_trackedLights, comp);
            }
            i += 1;
        }
    }

    private cb func OnEntityDetached(evt: ref<EntityLifecycleEvent>) -> Void {
        let entity = evt.GetEntity();
        if !IsDefined(entity) { return; };
        
        if entity.GetEntityID() == this.smasherID {
             this.OnSmasherDetached();
        }
        
        let components = entity.GetComponents();
        let i = 0;
        while i < ArraySize(components) {
            let comp = components[i] as gameLightComponent;
            if IsDefined(comp) {
                let j = 0;
                while j < ArraySize(this.m_trackedLights) {
                    if this.m_trackedLights[j] == comp {
                        ArrayErase(this.m_trackedLights, j);
                    } else {
                        j += 1;
                    }
                }
            }
            i += 1;
        }
    }



    func TryStartNewSmasherEvent() -> Bool {
        if !this.IsModEnabled() { return false; };
        let gi: GameInstance = GetGameInstance();
        if GameInstance.GetQuestsSystem(gi).GetFact(n"q005_done") <= 0 {
            return false;
        };
        let player = GetPlayer(gi);
        let preventionSys = GameInstance.GetScriptableSystemsContainer(gi).Get(n"PreventionSystem") as PreventionSystem;
        let district_name = this.GetReliableDistrictRecord().EnumName();
        let center: Vector4 = player.GetWorldPosition();
        let player_vehicle = player.GetMountedVehicle() as VehicleObject;
        if this.isSmasherEventInProgress {
            return false;
        };

        if EntityID.IsDefined(this.smasherID) {
            return false;
        };

        let scene_tier = PlayerPuppet.GetSceneTier(player);
        if scene_tier != 1 {
            return false;
        };

        if IsDefined(player_vehicle) && player_vehicle.IsInAir() {
            return false;
        };

        if IsDefined(player_vehicle) {
            let speed = player_vehicle.GetCurrentSpeed();
            if speed > AbsF(50.01) {
                return false;
            };
        };

        let smasher_spawn_point = this.getSmasherSpawnPoint(center, district_name);

        if Vector4.IsXYZZero(smasher_spawn_point) {
            return false;
        };

        let smasherSpec = this.GetSmasherEntitySpec(district_name);
        smasherSpec.position = smasher_spawn_point;
        this.m_lastBufferUpdatePos = smasher_spawn_point;

        let pID = player.GetEntityID();
        let ses = GameInstance.GetStatusEffectSystem(gi);
        let effectRoll = RandRange(1, 6);

        if this.settings.EnablePreSpawnEffects {
            GameObjectEffectHelper.StartEffectEvent(player, n"blood_onscreen", true);

            if IsDefined(ses) {
                switch effectRoll {
                    case 1:
                        ses.ApplyStatusEffect(pID, t"BaseStatusEffect.NoSandevistanGlitch");
                        ses.ApplyStatusEffect(pID, t"BaseStatusEffect.BreathingSick");
                        break;
                    case 2:
                        ses.ApplyStatusEffect(pID, t"BaseStatusEffect.NoSandevistanGlitch");
                        ses.ApplyStatusEffect(pID, t"BaseStatusEffect.BikeKnockdown");
                        ses.ApplyStatusEffect(pID, t"BaseStatusEffect.BreathingHeavy");
                        break;
                    case 3:
                        ses.ApplyStatusEffect(pID, t"BaseStatusEffect.JohnnySicknessMedium");
                        ses.ApplyStatusEffect(pID, t"BaseStatusEffect.CyberwareMalfunction");
                        ses.ApplyStatusEffect(pID, t"BaseStatusEffect.KurtTakedownKnockdown");
                        break;
                    case 4:
                        ses.ApplyStatusEffect(pID, t"BaseStatusEffect.Bleeding");
                        ses.ApplyStatusEffect(pID, t"BaseStatusEffect.BaseBrainMelt");
                        ses.ApplyStatusEffect(pID, t"BaseStatusEffect.BreathingHeavy");
                        ses.ApplyStatusEffect(pID, t"BaseStatusEffect.CyberwareMalfunction");
                        break;
                    case 5:
                        ses.ApplyStatusEffect(pID, t"AIQuickHackStatusEffect.HackBlind");
                        ses.ApplyStatusEffect(pID, t"BaseStatusEffect.BossWeaponMalfunctionLvl4PlusPlus");
                        break;
                };
            }

            let breathEvt: ref<SoundPlayEvent> = new SoundPlayEvent();
            breathEvt.soundName = n"ono_v_breath_fast";
            player.QueueEvent(breathEvt);

            this.breathingDaemon = new SmasherBreathingDaemon();
            this.breathingDaemon.Start(gi, 1.50, true);

            this.flickerDaemon = new SmasherFlickerLightsDaemon();
            this.flickerDaemon.Start(gi, 0.2, true);
        };

        SaveLocksManager.RequestSaveLockAdd(gi, n"SmasherEncountersEventInProgress");
        FastTravelSystem.AddFastTravelLock(n"SmasherEncountersEventInProgress", gi);
        this.isSmasherEventInProgress = true;
        this.smasherIsDead = false;

        let spawnCallback = new SmasherEncountersSpawnDelayCallback();
        spawnCallback.smasherSpec = smasherSpec;
        spawnCallback.districtName = district_name;
        
        this.p_pendingDistrictName = StringToName(district_name);

        this.p_spawnDelayID = GameInstance.GetDelaySystem(gi).DelayCallback(spawnCallback, 10.0, true);

        this.ShowBreakAttackChoice();



        if IsDefined(this.settings) && this.settings.EnableVehicleHacking {
            this.vehicleHackDaemon = new SmasherVehicleHackDaemon();
            this.vehicleHackDaemon.Start(gi, 1.0, false);
        };

        if IsDefined(this.lastEncounterSecondsDaemon) {
            this.lastEncounterSecondsDaemon.Stop();
        }
        
        return true;
    };

    func GetDistrictKey(districtName: String) -> String {
        let districtRecord = TweakDBInterface.GetDistrictRecord(TDBID.Create("Districts." + districtName));
        if IsDefined(districtRecord) {
            let parent = districtRecord.ParentDistrict();
            if IsDefined(parent) {
                return parent.EnumName();
            }
        }

        switch districtName {
            case "CityCenter":
            case "CorpoPlaza":
            case "Downtown":
                return "CityCenter";
            case "Westbrook":
            case "JapanTown":
            case "CharterHill":
            case "NorthOaks":
                return "Westbrook";
            case "Watson":
            case "Northside":
            case "LittleChina":
            case "Kabuki":
            case "ArasakaWaterfront":
                return "Watson";
            case "Heywood":
            case "Glen":
            case "VistaDelRey":
            case "Wellsprings":
                return "Heywood";
            case "SantoDomingo":
            case "Arroyo":
            case "RanchoCoronado":
                return "SantoDomingo";
            case "Pacifica":
            case "Coastview":
            case "WestWindEstate":
                return "Pacifica";
            case "Dogtown":
                return "Dogtown";
            default:
                return "Badlands";
        };
    };

    func RequestStartSmasherEvent() -> Void {
        let gi: GameInstance = GetGameInstance();
        if IsDefined(this.lastEncounterSecondsDaemon) {
            this.lastEncounterSecondsDaemon.Stop();
        }
        let starter = new SmasherEncountersEventStarterDaemon();
        starter.Start(gi, 1.00, false);
    };

    func SpawnSmasher(smasher_spec: ref<DynamicEntitySpec>) -> EntityID {
        let dynamicEntSys = GameInstance.GetDynamicEntitySystem();
        return dynamicEntSys.CreateEntity(smasher_spec);
    };

    func ExecuteSpawn(smasherSpec: ref<DynamicEntitySpec>) -> Void {
        let gi: GameInstance = GetGameInstance();
        let smasherID = this.SpawnSmasher(smasherSpec);
        
        this.smasherID = smasherID;
        this.p_pendingDistrictName = n"";

        let districtName = this.GetReliableDistrictRecord().EnumName();
        this.RecordSmasherAppearance(districtName);
    }

    private func RecordSmasherAppearance(districtName: String) -> Void {
        let now = Cast<Int32>(GameInstance.GetTimeSystem(this.GetGameInstance()).GetGameTimeStamp());
        let key = this.GetDistrictKey(districtName);
        switch key {
            case "CityCenter": this.p_lastSmasherAppearance_CityCenter = now; break;
            case "Watson": this.p_lastSmasherAppearance_Watson = now; break;
            case "Westbrook": this.p_lastSmasherAppearance_Westbrook = now; break;
            case "Heywood": this.p_lastSmasherAppearance_Heywood = now; break;
            case "SantoDomingo": this.p_lastSmasherAppearance_SantoDomingo = now; break;
            case "Pacifica": this.p_lastSmasherAppearance_Pacifica = now; break;
            case "Badlands": this.p_lastSmasherAppearance_Badlands = now; break;
            case "Dogtown": this.p_lastSmasherAppearance_Dogtown = now; break;
        };
    }

    public func CalculateMultiplier(opt districtKey: String) -> Float {
        let gi: GameInstance = this.GetGameInstance();
        let player = GetPlayer(gi);
        let playerID = Cast<StatsObjectID>(player.GetEntityID());
        let statsSys = GameInstance.GetStatsSystem(gi);
        let multiplier: Float = 1.0;

        let key: String;
        if Equals(districtKey, "") {
            key = this.GetDistrictKey(this.GetReliableDistrictRecord().EnumName());
        } else {
            key = districtKey;
        };

        let districtBase: Float = this.GetDistrictBaseMultiplier(key);

        if GameTime.Hours(GameInstance.GetTimeSystem(gi).GetGameTime()) >= 22 || GameTime.Hours(GameInstance.GetTimeSystem(gi).GetGameTime()) < 5 {
            districtBase *= 1.2;
        };

        let now = Cast<Int32>(GameInstance.GetTimeSystem(gi).GetGameTimeStamp());
        let lastAppearance = this.GetLastAppearanceTime(key);

        if lastAppearance > 0 && (now - lastAppearance) < 259200 {
            districtBase *= 1.2;
        };

        multiplier += districtBase;

        if GameInstance.GetQuestsSystem(gi).GetFact(n"q112_done") > 0 { multiplier += 0.3; };

        multiplier += MinF(statsSys.GetStatValue(playerID, gamedataStatType.StreetCred) * 0.01, 0.5);

        let currentHumanity = statsSys.GetStatValue(playerID, gamedataStatType.HumanityAllocated);
        let humanityBonus = currentHumanity * 0.001;
        if currentHumanity > (statsSys.GetStatValue(playerID, gamedataStatType.HumanityTotalMaxValue) - statsSys.GetStatValue(playerID, gamedataStatType.HumanityOverallocationPossible)) {
            humanityBonus *= 2.0;
        };
        multiplier += MinF(humanityBonus, 1.5);

        let activeWeapon = GameInstance.GetTransactionSystem(gi).GetItemInSlot(player, t"AttachmentSlots.WeaponRight");
        if IsDefined(activeWeapon) {
            let wID = Cast<StatsObjectID>(activeWeapon.GetEntityID());
            if Equals(ItemID.GetTDBID(activeWeapon.GetItemID()), t"Items.Preset_Silverhand_3516") || Equals(ItemID.GetTDBID(activeWeapon.GetItemID()), t"Items.VHard_50_CoolRef_Weapon11") {
                multiplier += 0.3;
            } else if statsSys.GetStatValue(wID, gamedataStatType.IsItemIconic) > 0.0 {
                multiplier += 0.1;
            };
        };

        let heat = (GameInstance.GetScriptableSystemsContainer(gi).Get(n"PreventionSystem") as PreventionSystem).GetHeatStage();
        if Equals(heat, EPreventionHeatStage.Heat_1) { multiplier += 0.1; }
        else if Equals(heat, EPreventionHeatStage.Heat_2) { multiplier += 0.2; }
        else if Equals(heat, EPreventionHeatStage.Heat_3) { multiplier += 0.3; }
        else if Equals(heat, EPreventionHeatStage.Heat_4) { multiplier += 0.4; };

        if this.IsNearArasakaHotspot(player.GetWorldPosition()) { multiplier += 1.0; };

        return multiplier;
    }

    private func CallArasakaBackup(count: Int32) -> Void {
        let gi = GetGameInstance();
        let arr: array<TweakDBID>;
        
        let i = 0;
        while i < count {
            let roll = RandRange(0, 3);
            if roll == 0 {
                 ArrayPush(arr, t"SmasherEncounters.ArasakaBackup_Vehicle1");
            } else if roll == 1 {
                 ArrayPush(arr, t"SmasherEncounters.ArasakaBackup_Vehicle2");
            } else {
                 ArrayPush(arr, t"SmasherEncounters.ArasakaBackup_Vehicle3");
            }
            i += 1;
        }

        let node = new questDynamicSpawnSystemNodeDefinition();
        let nodeType = new questDynamicVehicleSpawn_NodeType();

        nodeType.distanceRange = new Vector2(25.0, 100.0);
        nodeType.spawnDirectionPreference = questSpawnDirectionPreference.InFront;

        let uniqueWaveId = s"smasherArasakaBackup_\(RandRange(-999999999, 999999999))";
        nodeType.waveTag = StringToName(uniqueWaveId);
        nodeType.VehicleData = arr;

        node.id = Cast<Uint16>(0);
        node.type = nodeType;
        
        GameInstance.GetQuestsSystem(gi).ExecuteNode(node);
    }
    
    private func CallBackupForEscape() -> Void {
        let district_name = this.GetReliableDistrictRecord().EnumName();
        let chance: Int32 = 0;
        let key = this.GetDistrictKey(district_name);
        
        switch key {
            case "CityCenter": chance = 95; break;
            case "Watson": chance = 70; break;
            case "Westbrook": chance = 70; break;
            case "Heywood": chance = 50; break;
            case "SantoDomingo": chance = 40; break;
            case "Pacifica": chance = 30; break;
            case "Dogtown": chance = 1; break;
            default: chance = 20; break;
        }

        if chance < 0 { chance = 0; };
        
        if RandRange(0, 100) < chance {
            let count: Int32 = RandRange(1, 3);
            this.CallArasakaBackup(count);
        }
    }

    func OnSmasherFirstAttached(smasher: ref<NPCPuppet>) -> Void {
        if !IsDefined(smasher) {
            return;
        };
        
        let gi: GameInstance = GetGameInstance();
        let player = GetPlayer(gi);
        if !IsDefined(player) {
            return;
        };

        this.PlaySmasherMusic();
        this.PlayRandomScream();
        this.RemovePreEncounterEffects(player);
        
        let delaySys = GameInstance.GetDelaySystem(gi);
        let smasherID = smasher.GetEntityID();
        let smasher_tt = smasher.GetTargetTrackerComponent();
        if !IsDefined(smasher_tt) {
            return;
        };
        
        this.smasherIsDead = false;
        this.isSmasherEventInProgress = true;
        let attitudeAgent = smasher.GetAttitudeAgent();
        let attitudeSys = GameInstance.GetAttitudeSystem(gi);
        if !IsDefined(attitudeAgent) || !IsDefined(attitudeSys) {
            return;
        };
        attitudeAgent.SetAttitudeGroup(n"arasaka");
        
        attitudeSys.SetAttitudeGroupRelationfromTweakPersistent(t"Attitudes.Group_Arasaka", t"Attitudes.Group_Civilian", EAIAttitude.AIA_Friendly);
        attitudeSys.SetAttitudeGroupRelationfromTweakPersistent(t"Attitudes.Group_Arasaka", t"Attitudes.Group_Police", EAIAttitude.AIA_Friendly);
        attitudeSys.SetAttitudeGroupRelationfromTweakPersistent(t"Attitudes.Group_Arasaka", t"Attitudes.Group_Player", EAIAttitude.AIA_Hostile);
        
        attitudeSys.SetAttitudeRelation(n"arasaka", n"player", EAIAttitude.AIA_Hostile);
        attitudeAgent.SetAttitudeTowards(player.GetAttitudeAgent(), EAIAttitude.AIA_Hostile);

        smasher_tt.SetThreatBaseMul(player, 100.00);
        TargetTrackingExtension.InjectThreat(smasher, player, 1.0, -1.0);
        
        NPCPuppet.ChangeHighLevelState(smasher, gamedataNPCHighLevelState.Combat);
        smasher_tt.AddThreat(player, true, player.GetWorldPosition(), 1.0, 1000.0, true);
        smasher_tt.SetThreatPersistence(player, true, 1u);

        smasher.GetAIControllerComponent().SetBehaviorArgument(n"LookAtTarget", player);

        StimBroadcasterComponent.BroadcastStim(smasher,
                                               gamedataStimType.SpreadFear,
                                               50.00);

        this.OnSmasherCombatStarted(smasher);
    };

    func OnSmasherAttached(smasher: ref<NPCPuppet>, isFirstAttach: Bool) -> Void {
        if !IsDefined(smasher) {
            return;
        };
        
        if isFirstAttach {
            this.OnSmasherFirstAttached(smasher);
            this.ApplySmasherLevel(smasher, this.p_smasherLevel);

            let multCallback = new SmasherStatMultiplierApplyCallback();
            multCallback.smasher = smasher;
            GameInstance.GetDelaySystem(GetGameInstance()).DelayCallback(multCallback, 2.0, false);
        };
        let gi: GameInstance = GetGameInstance();

        GameInstance.GetGodModeSystem(gi).RemoveGodMode(smasher.GetEntityID(), gameGodModeType.Invulnerable, n"SmasherEncountersImmortal");
        
        let delaySys = GameInstance.GetDelaySystem(gi);
        let smasher_stats_ID = Cast<StatsObjectID>(smasher.GetEntityID());

        if IsDefined(this.smasherDeathListener) {
            let statPoolsSystem = GameInstance.GetStatPoolsSystem(gi);
            if IsDefined(statPoolsSystem) {
                statPoolsSystem.RequestUnregisteringListener(smasher_stats_ID, gamedataStatPoolType.Health, this.smasherDeathListener);
            };
            this.smasherDeathListener = null;
        }

        this.smasherDeathListener = new SmasherDeathListener();
        this.smasherDeathListener.smasher = smasher;
        GameInstance.GetStatPoolsSystem(gi).RequestRegisteringListener(smasher_stats_ID,
                                                                       gamedataStatPoolType.Health,
                                                                       this.smasherDeathListener);
        if !this.isSmasherDefeated() {
            let mappinSys = GameInstance.GetMappinSystem(gi);
            if IsDefined(mappinSys) {
                mappinSys.UnregisterMappin(this.smasherMappinID);
                this.smasherMappinID = this.RegisterSmasherMappin(smasher);
            }
        };

        if IsDefined(this.playerSecondsAwayDaemon) {
            this.playerSecondsAwayDaemon.Stop();
        };

        if IsDefined(this.flickerDaemon) {
            this.flickerDaemon.Stop();
            this.flickerDaemon = null;
        };
        if this.isSmasherEventInProgress && this.settings.EnablePreSpawnEffects {
            this.flickerDaemon = new SmasherFlickerLightsDaemon();
            this.flickerDaemon.Start(gi, 0.2, true);
        };

        if IsDefined(this.combatEffectsDaemon) {
            this.combatEffectsDaemon.Stop();
            this.combatEffectsDaemon = null;
        };
        if IsDefined(this.supportUnitDaemon) {
            this.supportUnitDaemon.Stop();
            this.supportUnitDaemon = null;
        };
        
        if this.isSmasherCombatStarted {
            if this.settings.EnableSmasherCombatEffects {
                this.combatEffectsDaemon = new SmasherCombatEffectsDaemon();
                let combatMin = 5.0 / (1.0 + this.settings.DifficultyMultiplier * 0.05);
                let combatMax = 10.0 / (1.0 + this.settings.DifficultyMultiplier * 0.05);
                this.combatEffectsDaemon.Start(gi, RandRangeF(combatMin, combatMax), false);
            };

            if this.settings.EnableSmasherSupportUnits {
                this.supportUnitDaemon = new SmasherSupportUnitSpawnerDaemon();
                let supportMin = 180.0 / this.settings.DifficultyMultiplier;
                let supportMax = 240.0 / this.settings.DifficultyMultiplier;
                this.supportUnitDaemon.Start(gi, RandRangeF(supportMin, supportMax), false);
            };
        };
    };

    func RegisterSmasherMappin(smasher: ref<NPCPuppet>) -> NewMappinID {
        let mappinSys = GameInstance.GetMappinSystem(this.GetGameInstance());
        let pin_data = new MappinData();
        let dummy_v3: Vector3;
        pin_data.mappinType = t"Mappins.SmasherEncounters_Smasher_Mappin_Definition";
        pin_data.variant = gamedataMappinVariant.HuntForPsychoVariant;
        pin_data.active = true;
        pin_data.visibleThroughWalls = true;
        return mappinSys.RegisterMappinWithObject(pin_data,
                                                  smasher,
                                                  n"roleMappin",
                                                  dummy_v3);
    };

    func OnSmasherCombatStarted(smasher: ref<NPCPuppet>) -> Void {
        if this.isSmasherCombatStarted || !IsDefined(smasher) {
            return;
        };

        let gi: GameInstance = GetGameInstance();
        let smasherStimBroadcaster = smasher.GetStimBroadcasterComponent();
        this.isSmasherCombatStarted = true;
        this.p_notSeenTimer = 0.0;

        if IsDefined(this.breathingDaemon) {
            this.breathingDaemon.Stop();
            this.breathingDaemon = null;
        };

        let player = GetPlayer(gi);
        if IsDefined(player) {
            this.RemovePreEncounterEffects(player);
        };

        if IsDefined(smasherStimBroadcaster) {
            smasherStimBroadcaster.AddActiveStimuli(smasher,
                                                   gamedataStimType.VehicleHit,
                                                   -1.00,
                                                   150.00);
        };
        StimBroadcasterComponent.BroadcastStim(smasher,
                                               gamedataStimType.Terror,
                                               150.00);
                                               
        if this.settings.EnableSmasherSupportUnits {
            this.supportUnitDaemon = new SmasherSupportUnitSpawnerDaemon();
            let supportMin = 180.0 / this.settings.DifficultyMultiplier;
            let supportMax = 240.0 / this.settings.DifficultyMultiplier;
            this.supportUnitDaemon.Start(gi, RandRangeF(supportMin, supportMax), false);
        };

        if this.settings.EnableSmasherCombatEffects {
            this.combatEffectsDaemon = new SmasherCombatEffectsDaemon();
            let combatMin = 5.0 / (1.0 + this.settings.DifficultyMultiplier * 0.05);
            let combatMax = 10.0 / (1.0 + this.settings.DifficultyMultiplier * 0.05);
            this.combatEffectsDaemon.Start(gi, RandRangeF(combatMin, combatMax), false);
        };
    };

    func OnSmasherDetached() -> Void {
        if this.isCleaningUp {
            return;
        };

        let gi: GameInstance = GetGameInstance();

        if IsDefined(this.flickerDaemon) {
            this.flickerDaemon.Stop();
            this.flickerDaemon = null;
        };

        if IsDefined(this.combatEffectsDaemon) {
            this.combatEffectsDaemon.Stop();
            this.combatEffectsDaemon = null;
        };

        if IsDefined(this.supportUnitDaemon) {
            this.supportUnitDaemon.Stop();
            this.supportUnitDaemon = null;
        };

        let player = GetPlayer(gi);
        if IsDefined(player) && IsDefined(player.GetMountedVehicle()) {
            this.CleanupSmasherEvent(true, "Smasher detached while player in vehicle");
            return;
        };

        let detatched_pos: Vector4;
        let smasher = GameInstance.FindEntityByID(gi, this.smasherID) as GameObject;
        
        if IsDefined(smasher) {
            detatched_pos = smasher.GetWorldPosition();
        } else if !Vector4.IsXYZZero(this.m_lastBufferUpdatePos) {
            detatched_pos = this.m_lastBufferUpdatePos;
        } else if IsDefined(player) {
            detatched_pos = player.GetWorldPosition();
        };

        if IsDefined(player) && Vector4.Distance(player.GetWorldPosition(), detatched_pos) > 100.0 {
            this.CleanupSmasherEvent(true, "Smasher detached while player far away");
            return;
        };

        let playerSecondsAwayDaemon = new SmasherEncountersPlayerSecondsAwayDaemon();
        this.playerSecondsAwayDaemon = playerSecondsAwayDaemon;
        this.playerSecondsAwayDaemon.smasher_detatched_pos = detatched_pos;
        this.playerSecondsAwayDaemon.Start(gi, 0.5, true);
    };

    func isSmasherDefeated() -> Bool {
        return this.smasherIsDead;
    };

    func IsSmasherEventInProgress() -> Bool {
        return this.isSmasherEventInProgress;
    };

    func IsSmasherCombatStarted() -> Bool {
        return this.isSmasherCombatStarted;
    };


    func OnSmasherIsDead(smasher: wref<NPCPuppet>) -> Void {
        if this.smasherIsDead || !IsDefined(smasher) {
            return;
        };
        this.smasherIsDead = true;
        
        this.CommonCleanup(smasher);
        this.CleanupSmasherEvent(true, "Smasher is dead");
    };

    func OnSmasherCowardEscape(smasher: wref<NPCPuppet>, healthPct: Float) -> Void {
        if this.smasherIsDead {
            return;
        };
        this.PlayRandomScream();
        this.smasherIsDead = true;
        let gi: GameInstance = GetGameInstance();
        let smasher_tt = smasher.GetTargetTrackerComponent();
        let escapePos: Vector4 = smasher.GetWorldPosition();
        let player = GetPlayer(gi);
        let playerID = player.GetEntityID();
        let statusEffectSystem = GameInstance.GetStatusEffectSystem(gi);
        
        if IsDefined(smasher_tt) {
            smasher_tt.ClearThreats();
        }
        escapePos.Z += 1000.00;
        
        if IsDefined(GameInstance.GetTeleportationFacility(gi)) {
            GameInstance.GetTeleportationFacility(gi).Teleport(smasher, escapePos, Quaternion.ToEulerAngles(smasher.GetWorldOrientation()));
        };

        if IsDefined(statusEffectSystem) {
            statusEffectSystem.ApplyStatusEffect(playerID, t"AdamSmasher.EMP_Shield_Knockdown");
            statusEffectSystem.ApplyStatusEffect(playerID, t"BaseStatusEffect.LegendaryFlashGrenade");
        };
        
        FTLog("[SmasherEncounters] Smasher escaped.");
        this.p_smasherEscapeCount += 1;
        if this.p_smasherLevel < 100 {
            this.p_smasherLevel += 1;
        }
        
        this.CallBackupForEscape();

        let smasherLevel: Int32 = this.p_smasherLevel;
        
        let components: Int32 = 5;
        
        let healthDiff: Int32 = Cast<Int32>(50.0 - healthPct);
        if healthDiff > 0 {
            components += healthDiff * 5;
        };

        components += Cast<Int32>(Cast<Float>(smasherLevel) * 2.0);

        let multiplier: Float = 1.0;
        if IsDefined(this.settings) {
            multiplier = this.settings.LegendaryComponentMultiplier;
        };
        let finalComponents = Cast<Int32>(Cast<Float>(components) * multiplier);

        if IsDefined(GameInstance.GetTransactionSystem(gi)) {
            GameInstance.GetTransactionSystem(gi).GiveItemByTDBID(player, t"Items.LegendaryMaterial1", finalComponents);
        };


        let district_name = this.GetReliableDistrictRecord().EnumName();
        this.ScheduleRewardSMS(district_name);

        this.CommonCleanup(smasher);
        this.CleanupSmasherEvent();
    }
    
    private func CommonCleanup(smasher: wref<NPCPuppet>) -> Void {
         if !IsDefined(smasher) {
             return;
         };
         
         let gi: GameInstance = GetGameInstance();
         let mappinSys = GameInstance.GetMappinSystem(gi);
         let smasherStimBroadcaster = smasher.GetStimBroadcasterComponent();
         let smasher_tt = smasher.GetTargetTrackerComponent();
         let smasher_stats_ID = Cast<StatsObjectID>(smasher.GetEntityID());
         
         this.isSmasherCombatStarted = false;
         if IsDefined(mappinSys) {
             mappinSys.UnregisterMappin(this.smasherMappinID);
         };
         
         if IsDefined(smasher_tt) {
            let player = GetPlayer(gi);
            if IsDefined(player) {
                smasher_tt.RemoveThreatBeliefAccuracyMinValue(player, n"SmasherEncounter");
            };
         };

         if IsDefined(smasherStimBroadcaster) {
             smasherStimBroadcaster.RemoveActiveStimuliByName(smasher,
                                                            gamedataStimType.VehicleHit);
             smasherStimBroadcaster.RemoveActiveStimuliByName(smasher,
                                                            gamedataStimType.Terror);
         };
         
         if IsDefined(this.smasherDeathListener) {
             let statPoolsSystem = GameInstance.GetStatPoolsSystem(gi);
             if IsDefined(statPoolsSystem) {
                 statPoolsSystem.RequestUnregisteringListener(smasher_stats_ID,
                                                              gamedataStatPoolType.Health,
                                                              this.smasherDeathListener);
             };
             this.smasherDeathListener = null;
         };
         
         this.smasherIsDead = true;
         
         if IsDefined(this.supportUnitDaemon) {
            this.supportUnitDaemon.Stop();
            this.supportUnitDaemon = null;
         }

         if IsDefined(this.combatEffectsDaemon) {
            this.combatEffectsDaemon.Stop();
            this.combatEffectsDaemon = null;
         }

         if IsDefined(this.vehicleHackDaemon) {
            this.vehicleHackDaemon.Stop();
            this.vehicleHackDaemon = null;
         }
    }


    func OnPlayerSecondAway(distance: Float, second: Uint16) -> Void {
        if distance > 100.00 || second > Cast<Uint16>(5) {
            if IsDefined(this.playerSecondsAwayDaemon) {
                this.playerSecondsAwayDaemon.Stop();
            };
            this.CleanupSmasherEvent(true, "Player seconds away timeout");
        };
    };

    func CleanupSmasherEvent(opt isFullCleanup: Bool, opt reason: String) -> Void {
        if this.isCleaningUp {
            return;
        };
        if Equals(reason, "") { reason = "Unspecified"; };
        FTLog(s"[SmasherEncounters] CleanupSmasherEvent started. Reason: \(reason) (full cleanup: \(isFullCleanup)).");
        this.isCleaningUp = true;
        this.HideBreakAttackChoice();
        
        let gi: GameInstance = GetGameInstance();


        if isFullCleanup && this.isSmasherEventInProgress && !this.smasherIsDead {
            FTLog("[SmasherEncounters] Resetting spawn points after encounter.");
        };
        let mappinSys = GameInstance.GetMappinSystem(gi);
        let attitudeSys = GameInstance.GetAttitudeSystem(gi);
        if IsDefined(mappinSys) {
            mappinSys.UnregisterMappin(this.smasherMappinID);
        }

        if IsDefined(this.breathingDaemon) {
            this.breathingDaemon.Stop();
        };

        if IsDefined(this.flickerDaemon) {
            this.flickerDaemon.Stop();
        } else {
            let cls = GameInstance.GetScriptableSystemsContainer(gi).Get(n"CityLightSystem") as CityLightSystem;
            if IsDefined(cls) {
                let request = new ForceCLSStateRequest();
                request.state = ECLSForcedState.DEFAULT;
                request.sourceName = n"SmasherEncounterGlitches";
                request.removePreviousRequests = true;
                cls.QueueRequest(request);
            };
        };
        ArrayClear(this.m_trackedLights);
        
        if IsDefined(this.supportUnitDaemon) {
            this.supportUnitDaemon.Stop();
        }

        if IsDefined(this.combatEffectsDaemon) {
            this.combatEffectsDaemon.Stop();
        }

        if IsDefined(this.vehicleHackDaemon) {
            this.vehicleHackDaemon.Stop();
        }

        let player = GetPlayer(gi);
        if IsDefined(player) {
            this.RemovePreEncounterEffects(player);
        }

        if EntityID.IsDefined(this.smasherID) {
            GameInstance.GetDynamicEntitySystem().DeleteEntity(this.smasherID);
            this.smasherID = new EntityID();
        };
        
        if isFullCleanup {
            for supportID in this.spawnedSupportIDs {
                if EntityID.IsDefined(supportID) {
                    GameInstance.GetDynamicEntitySystem().DeleteEntity(supportID);
                }
            }
            ArrayClear(this.spawnedSupportIDs);

            if IsDefined(attitudeSys) {
                attitudeSys.SetAttitudeGroupRelationfromTweakPersistent(t"Attitudes.Group_Arasaka",
                                                                        t"Attitudes.Group_Civilian",
                                                                        EAIAttitude.AIA_Neutral);
                attitudeSys.SetAttitudeGroupRelationfromTweakPersistent(t"Attitudes.Group_Arasaka",
                                                                        t"Attitudes.Group_Police",
                                                                        EAIAttitude.AIA_Neutral);
                attitudeSys.SetAttitudeGroupRelationfromTweakPersistent(t"Attitudes.Group_Arasaka",
                                                                        t"Attitudes.Group_Player",
                                                                        EAIAttitude.AIA_Neutral);
            }
        };

        this.p_spawnPoints = 0.0;
        this.p_notSeenTimer = 0.0;
        this.p_isWaitingForSpawnSafety = false;

        ArrayClear(this.p_arasakaKillTimestamps);
        ArrayClear(this.p_sandyUsageTimestamps);
        ArrayClear(this.p_berserkUsageTimestamps);
        ArrayClear(this.p_overclockUsageTimestamps);
        ArrayClear(this.p_edgerunnerFuryTimestamps);

        this.StartNewMinutesSinceLastEncounterCallback();
        SaveLocksManager.RequestSaveLockRemove(gi, n"SmasherEncountersEventInProgress");
        FastTravelSystem.RemoveFastTravelLock(n"SmasherEncountersEventInProgress", gi);
        this.isSmasherEventInProgress = false;
        this.isSmasherCombatStarted = false;
        this.smasherIsDead = false;
        this.p_pendingDistrictName = n"";
        this.PlaySmasherMusic(true);
        if IsDefined(this.lastEncounterSecondsDaemon) {
            this.lastEncounterSecondsDaemon.Start(gi, 1.00, true);
        };

        if IsDefined(this.periodicSpawnCheckDaemon) {
            this.periodicSpawnCheckDaemon.Start(gi, 600.0, true);
        };
        
        this.isCleaningUp = false;
    };

    public func CancelSmasherSpawn() -> Void {
        let gi: GameInstance = GetGameInstance();
        GameInstance.GetDelaySystem(gi).CancelCallback(this.p_spawnDelayID);
        this.CleanupSmasherEvent(false, "Hacking cancellation");
        this.p_pendingDistrictName = n"";
        FTLog("[SmasherEncounters] Smasher spawn attempt canceled via network breach.");
    }

    func GetSmasherEntitySpec(district_name: String) -> ref<DynamicEntitySpec> {
        let smasherSpec: ref<DynamicEntitySpec> = new DynamicEntitySpec();
        smasherSpec.recordID = t"Character.SmasherEncounters_Smasher";
        smasherSpec.persistState = false;
        smasherSpec.persistSpawn = false;
        smasherSpec.alwaysSpawned = false;
        smasherSpec.tags = [n"SmasherEncounters_npc_smasher"];
        return smasherSpec;
    };

    func StartNewMinutesSinceLastEncounterCallback() -> Void {
        let gi: GameInstance = this.GetGameInstance();
        if IsDefined(this.lastEncounterSecondsDaemon) {
            this.lastEncounterSecondsDaemon.Stop();
        };
        let lastEncounterSecondsDaemon = new SmasherEncountersLastEncounterSecondsDaemon();
        this.lastEncounterSecondsDaemon = lastEncounterSecondsDaemon;
        lastEncounterSecondsDaemon.Start(gi, 1.0, true);
    };

    func AddSpawnPoints(points: Float) -> Float {
        if this.settings.OnlyAfterHanako && GameInstance.GetQuestsSystem(this.GetGameInstance()).GetFact(n"q112_done") <= 0 {
            return 0.0;
        }
        let finalPoints = points * this.CalculateMultiplier();
        this.p_spawnPoints += finalPoints;
        if this.p_spawnPoints > 100.0 { this.p_spawnPoints = 100.0; }
        if this.p_spawnPoints < 0.0 { this.p_spawnPoints = 0.0; }
        return finalPoints;
    };

    func RollForSpawn() -> Bool {
        return this.p_spawnPoints >= 100.0;
    }

    func IsSafeToSpawn() -> Bool {
        let gi: GameInstance = this.GetGameInstance();
        let preventionSys = GameInstance.GetScriptableSystemsContainer(gi).Get(n"PreventionSystem") as PreventionSystem;
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        let questsContentSystem = GameInstance.GetQuestsContentSystem(gi);
        
        if EntityID.IsDefined(this.smasherID) || this.isSmasherEventInProgress {
            return false;
        };

        if this.IsInSafeZone(player.GetWorldPosition()) {
            return false;
        };

        let player_vehicle = player.GetMountedVehicle() as VehicleObject;
        if IsDefined(player_vehicle) && player_vehicle.IsInAir() {
            return false;
        };

        let scene_tier = PlayerPuppet.GetSceneTier(player);
        if scene_tier != 1
        || (IsDefined(preventionSys) && preventionSys.IsPlayerInQuestArea())
        || (IsDefined(questsContentSystem) && questsContentSystem.IsTokensActivationBlocked())
        || SE_IsPlayerNearQuestMappin(50.00)
        || StatusEffectSystem.ObjectHasStatusEffectWithTag(player, n"NoCombat")
        || StatusEffectSystem.ObjectHasStatusEffectWithTag(player, n"VehicleScene")
        || player.GetPuppetStateBlackboard().GetBool(GetAllBlackboardDefs().PuppetState.InAirAnimation)
        || Equals(player.m_securityAreaTypeE3HACK, ESecurityAreaType.SAFE) {
            return false;
        };

        return true;
    }

    func ShouldStartSmasherEvent() -> Bool {
        return this.IsSafeToSpawn() && this.RollForSpawn();
    };

    func getSmasherSpawnPoint(center: Vector4, district_name: String) -> Vector4 {
        let gi: GameInstance = this.GetGameInstance();
        let NavSys = GameInstance.GetNavigationSystem(gi);
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        let security_zone_filters = [ESecurityAreaType.SAFE, ESecurityAreaType.RESTRICTED, ESecurityAreaType.DANGEROUS, ESecurityAreaType.DISABLED];

        let player_fwd: Vector4 = player.GetWorldForward();
        let pursuit_points: array<Vector4>;
        let fallback_pursuit_points: array<Vector4>;
        
        let camSys = GameInstance.GetCameraSystem(gi);
        let camTransform: Transform;
        camSys.GetActiveCameraWorldTransform(camTransform);
        let camPos = camTransform.GetPosition();
        let camFwd = camTransform.GetForward();
        let camFOV = camSys.GetActiveCameraFOV();
        let camAspectRatio = camSys.GetAspectRatio();
        
        let frustum_points = SE_GetCameraFrustumPoints(camTransform, camFOV, camAspectRatio, 500.0);
        let up_fwd = Vector4.RotateAxis(camFwd, new Vector4(-1.0, 0.0, 0.0, 1.0), Deg2Rad(camFOV / camAspectRatio));
        let down_fwd = Vector4.RotateAxis(camFwd, new Vector4(1.0, 0.0, 0.0, 1.0), Deg2Rad(camFOV / camAspectRatio));

        let attempts: Int32 = 0;
        let currentMinDist: Float = 75.0;
        let currentMaxDist: Float = 175.0;
        
        let bestFallbackFound: Bool = false;
        let bestFallbackPoint: Vector4;

        while attempts < 3 {
            if attempts == 1 { currentMinDist = 50.0; currentMaxDist = 150.0; }
            else if attempts == 2 { currentMinDist = 20.0; currentMaxDist = 120.0; };

            if NavSys.FindPursuitPointsRange(center, center, player_fwd, currentMinDist, currentMaxDist, 10, false, NavGenAgentSize.Human, pursuit_points, fallback_pursuit_points) {
                for point in pursuit_points {
                    if !SE_IsPointInAnyLoadedSecurityAreaRadius(point, security_zone_filters, true) && SE_HasSpaceInFrontOfPoint(point, player_fwd, 0.5, 2.0, 2.0, 3.0) {
                        if !SE_IsPointInCameraView(gi, point, camPos, frustum_points, up_fwd, down_fwd, true) { return point; };
                        if !bestFallbackFound { bestFallbackPoint = point; bestFallbackFound = true; };
                    };
                };
                for point in fallback_pursuit_points {
                    if !SE_IsPointInAnyLoadedSecurityAreaRadius(point, security_zone_filters, true) && SE_HasSpaceInFrontOfPoint(point, player_fwd, 0.5, 2.0, 2.0, 3.0) {
                        if !SE_IsPointInCameraView(gi, point, camPos, frustum_points, up_fwd, down_fwd, true) { return point; };
                        if !bestFallbackFound { bestFallbackPoint = point; bestFallbackFound = true; };
                    };
                };
            };
            attempts += 1;
        };
        return bestFallbackFound ? bestFallbackPoint : new Vector4(0.0, 0.0, 0.0, 0.0);
    }

    public func PrintSpawnPoints() -> Void {
        let gi: GameInstance = this.GetGameInstance();
        let player = GetPlayer(gi);
        let statsSys = GameInstance.GetStatsSystem(gi);
        let playerID = Cast<StatsObjectID>(player.GetEntityID());
        let district_record = this.GetReliableDistrictRecord();
        let districtName = district_record.EnumName();
        let key = this.GetDistrictKey(districtName);

        FTLog("---------------------------------------");
        FTLog(s"[SmasherEncounters] Location: \(districtName)");
        FTLog(s" > Smasher Level: \(this.p_smasherLevel)");
        FTLog(s" > DANGER LEVEL MULTIPLIER: \(this.CalculateMultiplier())");
        
        FTLog(s"   - District base: +\(this.GetDistrictBaseMultiplier(key))");

        if GameTime.Hours(GameInstance.GetTimeSystem(gi).GetGameTime()) >= 22 || GameTime.Hours(GameInstance.GetTimeSystem(gi).GetGameTime()) < 5 {
             FTLog("   - Night (District x1.2): Active");
        };

        if (Cast<Int32>(GameInstance.GetTimeSystem(gi).GetGameTimeStamp()) - this.GetLastAppearanceTime(key)) < 259200 {
             FTLog("   - Smasher appeared here recently (within 72h, District x1.2): Active");
        };

        if GameInstance.GetQuestsSystem(gi).GetFact(n"q112_done") > 0 { FTLog("   - After Parade (q112): +0.3"); };

        let credBonus = MinF(statsSys.GetStatValue(playerID, gamedataStatType.StreetCred) * 0.01, 0.5);
        if credBonus > 0.0 { FTLog(s"   - Street Cred: +\(credBonus)"); };

        let currentHumanity = statsSys.GetStatValue(playerID, gamedataStatType.HumanityAllocated);
        let humanityBonus = currentHumanity * 0.001;
        if currentHumanity > (statsSys.GetStatValue(playerID, gamedataStatType.HumanityTotalMaxValue) - statsSys.GetStatValue(playerID, gamedataStatType.HumanityOverallocationPossible)) {
            humanityBonus *= 2.0;
        };
        humanityBonus = MinF(humanityBonus, 1.5);
        if humanityBonus > 0.0 { FTLog(s"   - Humanity: +\(humanityBonus)"); };

        let activeWeapon = GameInstance.GetTransactionSystem(gi).GetItemInSlot(player, t"AttachmentSlots.WeaponRight");
        if IsDefined(activeWeapon) {
            let wID = Cast<StatsObjectID>(activeWeapon.GetEntityID());
            if Equals(ItemID.GetTDBID(activeWeapon.GetItemID()), t"Items.Preset_Silverhand_3516") || Equals(ItemID.GetTDBID(activeWeapon.GetItemID()), t"Items.VHard_50_CoolRef_Weapon11") {
                FTLog("   - Malorian 3516: +0.3");
            } else if statsSys.GetStatValue(wID, gamedataStatType.IsItemIconic) > 0.0 {
                FTLog("   - Iconic Weapon: +0.1");
            };
        };

        let heat = (GameInstance.GetScriptableSystemsContainer(gi).Get(n"PreventionSystem") as PreventionSystem).GetHeatStage();
        if Equals(heat, EPreventionHeatStage.Heat_1) { FTLog("   - Wanted Level 1: +0.1"); }
        else if Equals(heat, EPreventionHeatStage.Heat_2) { FTLog("   - Wanted Level 2: +0.2"); }
        else if Equals(heat, EPreventionHeatStage.Heat_3) { FTLog("   - Wanted Level 3: +0.3"); }
        else if Equals(heat, EPreventionHeatStage.Heat_4) { FTLog("   - Wanted Level 4: +0.4"); };

        if this.IsNearArasakaHotspot(player.GetWorldPosition()) { FTLog("   - Arasaka Hotspot: +1.0"); };

        if this.isSmasherEventInProgress { FTLog(" >> STATUS: Event in progress (Smasher is active)"); }
        else if this.p_isWaitingForSpawnSafety { FTLog(" >> STATUS: Spawn pending (Waiting for safe conditions)"); }
        else { FTLog(" >> STATUS: Actively accumulating threat points..."); };
        FTLog("---------------------------------------");
    }


    public func HasContactedDistrict(district: CName) -> Bool {
        return ArrayContains(this.p_contactedDistricts, district);
    }

    public func HasActiveWarning(district: CName) -> Bool {
        return ArrayContains(this.p_districtsWithActiveWarning, district);
    }

    public func RemoveActiveWarning(district: CName) -> Void {
        let i = 0;
        while i < ArraySize(this.p_districtsWithActiveWarning) {
            if Equals(this.p_districtsWithActiveWarning[i], district) {
                ArrayErase(this.p_districtsWithActiveWarning, i);
                return;
            };
            i += 1;
        };
    }

    public func SendWarningSMS(districtKey: String) -> Void {
        let gi: GameInstance = this.GetGameInstance();
        let nowGame: Float = GameInstance.GetTimeSystem(gi).GetGameTimeStamp();

        ArrayPush(this.p_pendingWarningSmsTimes, nowGame + Cast<Float>(RandRange(1, 3)) * 60.0);
        ArrayPush(this.p_pendingWarningSmsDistricts, StringToName(districtKey));
    }

    public func ScheduleRewardSMS(districtName: String) -> Void {
        let gi: GameInstance = this.GetGameInstance();
        let minMinutes: Int32 = 50;
        let maxMinutes: Int32 = 60;

        switch districtName {
            case "CityCenter":
            case "CorpoPlaza":
            case "Downtown":
                minMinutes = 5; maxMinutes = 15;
                break;
            case "Westbrook":
            case "JapanTown":
            case "CharterHill":
            case "NorthOaks":
                minMinutes = 15; maxMinutes = 25;
                break;
            case "Watson":
            case "Northside":
            case "LittleChina":
            case "Kabuki":
            case "ArasakaWaterfront":
                minMinutes = 20; maxMinutes = 30;
                break;
            case "Heywood":
            case "Glen":
            case "VistaDelRey":
            case "Wellsprings":
                minMinutes = 30; maxMinutes = 40;
                break;
            default:
                minMinutes = 50; maxMinutes = 60;
                break;
        };

        let nowGame: Float = GameInstance.GetTimeSystem(gi).GetGameTimeStamp();
        this.p_pendingRewardSmsDistrict = StringToName(districtName);
        this.p_pendingRewardSmsAt = nowGame + Cast<Float>(RandRange(minMinutes, maxMinutes)) * 60.0;
    }

    public func UpdatePendingSmsDelivery() -> Void {
        let gi: GameInstance = this.GetGameInstance();
        let nowGame: Float = GameInstance.GetTimeSystem(gi).GetGameTimeStamp();

        let i: Int32 = 0;
        while i < ArraySize(this.p_pendingWarningSmsTimes) {
            if nowGame >= this.p_pendingWarningSmsTimes[i] {
                let districtKey = NameToString(this.p_pendingWarningSmsDistricts[i]);
                ArrayErase(this.p_pendingWarningSmsTimes, i);
                ArrayErase(this.p_pendingWarningSmsDistricts, i);
                this.DeliverWarningSMS(districtKey);
            } else {
                i += 1;
            };
        };

        if this.p_pendingRewardSmsAt > 0.0 && nowGame >= this.p_pendingRewardSmsAt {
            let districtName = NameToString(this.p_pendingRewardSmsDistrict);
            this.p_pendingRewardSmsAt = 0.0;
            this.p_pendingRewardSmsDistrict = n"";
            this.DeliverRewardSMS(districtName);
        };
    }

    public func DeliverRewardSMS(districtName: String) -> Void {
        let gi: GameInstance = GetGameInstance();
        let player = GetPlayer(gi);

        this.isSmasherSmsUnlocked = true;

        let minMoney: Int32 = 1000;
        let maxMoney: Int32 = 1500;
        let districtKey: String = this.GetDistrictKey(districtName);

        switch districtKey {
            case "CityCenter":
                minMoney = 5000; maxMoney = 7000;
                break;
            case "Westbrook":
                minMoney = 3000; maxMoney = 5000;
                break;
            case "Watson":
                minMoney = 2500; maxMoney = 3000;
                break;
            case "Heywood":
                minMoney = 2000; maxMoney = 2500;
                break;
            case "SantoDomingo":
                minMoney = 1500; maxMoney = 2000;
                break;
            case "Pacifica":
                minMoney = 1000; maxMoney = 1500;
                break;
            case "Dogtown":
                minMoney = 500; maxMoney = 1000;
                break;
            default:
                minMoney = 500; maxMoney = 1000;
                break;
        };

        if !ArrayContains(this.p_contactedDistricts, StringToName(districtKey)) {
            ArrayPush(this.p_contactedDistricts, StringToName(districtKey));
        };

        let finalID = this.PickUnusedSmsID(SmasherSmsRepository.GetMessageIDsForDistrict(districtKey), StringToName("Badlands_0"));
        this.lastSmasherSmsHash = finalID;
        let finalMessage = SmasherSmsRepository.GetMessageText(finalID);

        let moneyAmount = RandRange(minMoney / 100, (maxMoney / 100) + 1) * 100;
        if IsDefined(this.settings) {
            moneyAmount = Cast<Int32>(Cast<Float>(moneyAmount) * this.settings.SmsRewardMultiplier);
        };
        GameInstance.GetTransactionSystem(gi).GiveItemByTDBID(player, t"Items.money", moneyAmount);

        SE_PushSmasherSms(gi, finalMessage);
    }

    public func DeliverWarningSMS(districtKey: String) -> Void {
        let gi: GameInstance = GetGameInstance();

        this.isSmasherSmsUnlocked = true;

        let finalID = this.PickUnusedSmsID(SmasherSmsRepository.GetWarningMessageIDsForDistrict(districtKey), StringToName("Warning_" + districtKey + "_0"));
        this.lastSmasherSmsHash = finalID;
        let finalMessage = SmasherSmsRepository.GetMessageText(finalID);

        SE_PushSmasherSms(gi, finalMessage);
    }

    private func PickUnusedSmsID(allIDs: array<CName>, fallbackID: CName) -> CName {
        let availableIDs: array<CName>;
        let i: Int32 = 0;

        while i < ArraySize(allIDs) {
            let id = allIDs[i];
            if !ArrayContains(this.usedSmsHashes, id) {
                ArrayPush(availableIDs, id);
            };
            i += 1;
        };

        if ArraySize(availableIDs) == 0 {
            let newUsedHashes: array<CName>;
            i = 0;
            while i < ArraySize(this.usedSmsHashes) {
                let existingId = this.usedSmsHashes[i];
                if !ArrayContains(allIDs, existingId) {
                    ArrayPush(newUsedHashes, existingId);
                };
                i += 1;
            };
            this.usedSmsHashes = newUsedHashes;

            i = 0;
            while i < ArraySize(allIDs) {
                ArrayPush(availableIDs, allIDs[i]);
                i += 1;
            };
        };

        if ArraySize(availableIDs) > 0 {
            let finalID = availableIDs[RandRange(0, ArraySize(availableIDs))];
            ArrayPush(this.usedSmsHashes, finalID);
            return finalID;
        };

        return fallbackID;
    }

    private func IsNearArasakaHotspot(playerPos: Vector4) -> Bool {
        let hotspots: array<Vector4>;
        
        ArrayPush(hotspots, new Vector4(-1445.0, 122.0, 15.0, 1.0));
        
        ArrayPush(hotspots, new Vector4(-2087.0, 2090.0, 18.0, 1.0));
        
        ArrayPush(hotspots, new Vector4(511.0, 1249.0, 229.0, 1.0));

        ArrayPush(hotspots, new Vector4(-1555.0, 2997.0, 7.3, 1.0));

        for hotspot in hotspots {
            if Vector4.Distance(playerPos, hotspot) <= 400.0 {
                return true;
            };
        };
        return false;
    }

    private func IsInSafeZone(pos: Vector4) -> Bool {
        let safeZones: array<Vector4>;
        
        ArrayPush(safeZones, new Vector4(-1382.3, 1270.4, 123.1, 1.0));

        for zone in safeZones {
            if Vector4.Distance(pos, zone) <= 400.0 {
                return true;
            };
        };
        return false;
    }

    private func ApplySmasherLevel(smasher: ref<ScriptedPuppet>, targetLevel: Int32) -> Void {
        let sid: StatsObjectID = Cast<StatsObjectID>(smasher.GetEntityID());
        if this.p_smasherStatsAppliedTo == smasher.GetEntityID() { return; };
        this.p_smasherStatsAppliedTo = smasher.GetEntityID();
        
        let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(smasher.GetGame());
        
        if !IsDefined(stats) { return; };
        
        if targetLevel > 100 { targetLevel = 100; }
        
        let levelF: Float = Cast<Float>(targetLevel);

        let curLVL: Float = stats.GetStatValue(sid, gamedataStatType.Level);
        let dLVL: Float = levelF - curLVL;
        if AbsF(dLVL) > 0.5 {
            stats.AddSavedModifier(sid, RPGManager.CreateStatModifier(gamedataStatType.Level, gameStatModifierType.Additive, dLVL));
        };

        let curPL: Float = stats.GetStatValue(sid, gamedataStatType.PowerLevel);
        let dPL: Float = levelF - curPL;
        if AbsF(dPL) > 0.5 {
            stats.AddSavedModifier(sid, RPGManager.CreateStatModifier(gamedataStatType.PowerLevel, gameStatModifierType.Additive, dPL));
        };

        if targetLevel > 60 {
            let bonusLevels: Float = levelF - 60.0;

            let hpBonus: Float = bonusLevels * 100.0;
            stats.AddSavedModifier(sid, RPGManager.CreateStatModifier(gamedataStatType.Health, gameStatModifierType.Additive, hpBonus));

            let dmgBonus: Float = bonusLevels * 0.5;
            stats.AddSavedModifier(sid, RPGManager.CreateStatModifier(gamedataStatType.NPCDamage, gameStatModifierType.Additive, dmgBonus));

            let armorBonus: Float = bonusLevels * 0.01;
            stats.AddSavedModifier(sid, RPGManager.CreateStatModifier(gamedataStatType.Armor, gameStatModifierType.Additive, armorBonus));

        };

    }

    public func ApplySmasherStatMultipliers(smasher: ref<NPCPuppet>) -> Void {
        let gi: GameInstance = this.GetGameInstance();
        let sid: StatsObjectID = Cast<StatsObjectID>(smasher.GetEntityID());

        if this.p_smasherStatMultAppliedTo == smasher.GetEntityID() { return; };

        let stats = GameInstance.GetStatsSystem(gi);
        if !IsDefined(stats) { return; };
        this.p_smasherStatMultAppliedTo = smasher.GetEntityID();

        let hpMult: Float = 1.0;
        let armorMult: Float = 1.0;
        let dmgMult: Float = 1.0;
        if IsDefined(this.settings) {
            hpMult = this.settings.SmasherHealthMultiplier;
            armorMult = this.settings.SmasherArmorMultiplier;
            dmgMult = this.settings.SmasherDamageMultiplier;
        };

        let statPoolsSystem = GameInstance.GetStatPoolsSystem(gi);

        if AbsF(hpMult - 1.0) > 0.01 {
            stats.AddSavedModifier(sid, RPGManager.CreateStatModifier(gamedataStatType.Health, gameStatModifierType.AdditiveMultiplier, hpMult - 1.0));
            if IsDefined(statPoolsSystem) {
                let healthPercent: Float = statPoolsSystem.GetStatPoolValue(sid, gamedataStatPoolType.Health, true);
                statPoolsSystem.RequestSettingStatPoolValue(sid, gamedataStatPoolType.Health, healthPercent, null, true);
            };
        };

        if AbsF(armorMult - 1.0) > 0.01 {
            stats.AddSavedModifier(sid, RPGManager.CreateStatModifier(gamedataStatType.Armor, gameStatModifierType.AdditiveMultiplier, armorMult - 1.0));
        };

        if AbsF(dmgMult - 1.0) > 0.01 {
            stats.AddSavedModifier(sid, RPGManager.CreateStatModifier(gamedataStatType.NPCDamage, gameStatModifierType.AdditiveMultiplier, dmgMult - 1.0));
        };
    }
    
    
    func GetSupportUnitChance(district_name: String) -> Int32 {
        let key = this.GetDistrictKey(district_name);
        switch key {
            case "CityCenter": return 40;
            case "Watson": return 25;
            case "Westbrook": return 25;
            case "Heywood": return 20;
            case "SantoDomingo": return 15;
            case "Pacifica": return 5;
            default: return 0;
        };
    }
    
    func SpawnSupportUnit() -> Void {
        if IsDefined(this.settings) && !this.settings.EnableSmasherSupportUnits {
            return;
        };

        let gi: GameInstance = GetGameInstance();
        let player = GetPlayer(gi);
        let center = player.GetWorldPosition();
        let navSys = GameInstance.GetNavigationSystem(gi);
        let player_fwd = player.GetWorldForward();
        
        let pursuit_points: array<Vector4>;
        let fallback_pursuit_points: array<Vector4>;
        
        if !IsDefined(navSys) { return; };
        
        let success = navSys.FindPursuitPointsRange(center, center, player_fwd, 50.0, 150.0, 5, false, NavGenAgentSize.Human, pursuit_points, fallback_pursuit_points);
        
        let spawnPos: Vector4;
        if success && ArraySize(pursuit_points) > 0 {
            spawnPos = pursuit_points[0];
        } else if success && ArraySize(fallback_pursuit_points) > 0 {
            spawnPos = fallback_pursuit_points[0];
        } else {
            FTLog("[SmasherEncounters] Support spawn failed: No navigation points found near player.");
            return;
        };
        
        FTLog(s"[SmasherEncounters] Spawning support unit at \(spawnPos)");
        
        let totalWeight = 100;
        let randomVal = RandRange(0, totalWeight);
        let currentWeight = 0;
        
        currentWeight += 40;
        if randomVal < currentWeight {
            this.SpawnSpecificSupport(t"Character.arasaka_netrunner_netrunner2_yukimura_wa_rare", spawnPos);
            return;
        };
        
        currentWeight += 40;
        if randomVal < currentWeight {
            this.SpawnSpecificSupport(t"Character.arasaka_sniper_sniper3_ashura_ma_elite", spawnPos);
            return;
        };
        
        currentWeight += 20;
        if randomVal < currentWeight {
            this.SpawnSpecificSupport(t"Character.arasaka_ninja_fmelee3_katana_ma_elite", spawnPos);
            return;
        };
    }
    
    private func SpawnSpecificSupport(record: TweakDBID, pos: Vector4) -> Void {
        let spec = new DynamicEntitySpec();
        spec.recordID = record;
        spec.position = pos;
        spec.persistState = false;
        spec.persistSpawn = false;
        spec.alwaysSpawned = false;
        let entityID = GameInstance.GetDynamicEntitySystem().CreateEntity(spec);
        if EntityID.IsDefined(entityID) {
            ArrayPush(this.spawnedSupportIDs, entityID);
        }
    }
    private func RemovePreEncounterEffects(player: ref<PlayerPuppet>) -> Void {
        let gi = player.GetGame();
        let ses = GameInstance.GetStatusEffectSystem(gi);
        let pID = player.GetEntityID();
        
        if IsDefined(ses) {
            ses.RemoveStatusEffect(pID, t"BaseStatusEffect.NoSandevistanGlitch");
            ses.RemoveStatusEffect(pID, t"BaseStatusEffect.BreathingSick");
            ses.RemoveStatusEffect(pID, t"BaseStatusEffect.LocomotionMalfunction");
            ses.RemoveStatusEffect(pID, t"BaseStatusEffect.BikeKnockdown");
            ses.RemoveStatusEffect(pID, t"BaseStatusEffect.BreathingHeavy");
            ses.RemoveStatusEffect(pID, t"BaseStatusEffect.JohnnySicknessMedium");
            ses.RemoveStatusEffect(pID, t"BaseStatusEffect.CyberwareMalfunction");
            ses.RemoveStatusEffect(pID, t"BaseStatusEffect.KurtTakedownKnockdown");
            ses.RemoveStatusEffect(pID, t"BaseStatusEffect.Bleeding");
            ses.RemoveStatusEffect(pID, t"BaseStatusEffect.BaseBrainMelt");
            ses.RemoveStatusEffect(pID, t"AIQuickHackStatusEffect.HackBlind");
            ses.RemoveStatusEffect(pID, t"BaseStatusEffect.BossWeaponMalfunctionLvl4PlusPlus");
            ses.RemoveStatusEffect(pID, t"BaseStatusEffect.BlackwallMechanicalOverload");
        }
        
        GameObjectEffectHelper.StopEffectEvent(player, n"blood_onscreen");

        if IsDefined(this.breathingDaemon) {
            this.breathingDaemon.Stop();
        };
        
        let stopBreathEvt: ref<SoundStopEvent> = new SoundStopEvent();
        stopBreathEvt.soundName = n"ono_v_breath_fast";
        player.QueueEvent(stopBreathEvt);
    }

    public func RegisterArasakaKill() -> Void {
        let now = Cast<Int32>(GameInstance.GetTimeSystem(this.GetGameInstance()).GetGameTimeStamp());
        let actualPoints = this.AddSpawnPoints(this.settings.ArasakaKillPoints);
        let pointEntry: PointTimestamp;
        pointEntry.timestamp = now;
        pointEntry.points = actualPoints;
        ArrayPush(this.p_arasakaKillTimestamps, pointEntry);
        this.CleanupTimestamps(this.p_arasakaKillTimestamps, now, 86400); // 24h 
    }

    public func RegisterCyberwareUsage(tag: CName) -> Void {
        let gi = this.GetGameInstance();
        let now = Cast<Int32>(GameInstance.GetTimeSystem(gi).GetGameTimeStamp());
        if Equals(tag, n"SandevistanPlayerBuff") {
            let actualPoints = this.AddSpawnPoints(this.settings.SandevistanPoints);
            let pointEntry: PointTimestamp;
            pointEntry.timestamp = now;
            pointEntry.points = actualPoints;
            ArrayPush(this.p_sandyUsageTimestamps, pointEntry);
            this.CleanupTimestamps(this.p_sandyUsageTimestamps, now, 28800); // 8h 

            if this.isSmasherEventInProgress && !this.smasherIsDead {
                let smasher = GameInstance.FindEntityByID(gi, this.smasherID) as NPCPuppet;
                if IsDefined(smasher) && !StatusEffectSystem.ObjectHasStatusEffect(smasher, t"BaseStatusEffect.SandevistanBuff") {
                    GameInstance.GetStatusEffectSystem(gi).ApplyStatusEffect(smasher.GetEntityID(), t"BaseStatusEffect.SandevistanBuff");
                };
            };
        }
        else if Equals(tag, n"Berserk") {
            let actualPoints = this.AddSpawnPoints(this.settings.BerserkPoints);
            let pointEntry: PointTimestamp;
            pointEntry.timestamp = now;
            pointEntry.points = actualPoints;
            ArrayPush(this.p_berserkUsageTimestamps, pointEntry);
            this.CleanupTimestamps(this.p_berserkUsageTimestamps, now, 28800); // 8h
        }
        else if Equals(tag, n"Overclock") {
            let actualPoints = this.AddSpawnPoints(this.settings.OverclockPoints);
            let pointEntry: PointTimestamp;
            pointEntry.timestamp = now;
            pointEntry.points = actualPoints;
            ArrayPush(this.p_overclockUsageTimestamps, pointEntry);
            this.CleanupTimestamps(this.p_overclockUsageTimestamps, now, 28800); // 8h 
        };
    }

    public func RegisterEdgerunnerFury() -> Void {
        let gi = this.GetGameInstance();
        let now = Cast<Int32>(GameInstance.GetTimeSystem(gi).GetGameTimeStamp());
        let actualPoints = this.AddSpawnPoints(this.settings.EdgerunnerFuryPoints);
        let pointEntry: PointTimestamp;
        pointEntry.timestamp = now;
        pointEntry.points = actualPoints;
        ArrayPush(this.p_edgerunnerFuryTimestamps, pointEntry);
        this.CleanupTimestamps(this.p_edgerunnerFuryTimestamps, now, 43200); // 12h 
    }

    private func CleanupTimestamps(out arr: array<PointTimestamp>, now: Int32, limit: Int32) -> Void {
        let i = 0;
        while i < ArraySize(arr) {
            if (now - arr[i].timestamp) > limit {
                this.p_spawnPoints -= arr[i].points;
                if this.p_spawnPoints < 0.0 { this.p_spawnPoints = 0.0; };
                ArrayErase(arr, i);
            } else {
                i += 1;
            };
        };
    }

    public func GetReliableDistrictRecord() -> ref<District_Record> {
        let dm = SE_GetDistrictManager();
        if !IsDefined(dm) { return TweakDBInterface.GetDistrictRecord(t"Districts.Watson"); }
        let district = dm.GetCurrentDistrict();
        
        if !IsDefined(district) && ArraySize(dm.m_visitedDistricts) > 0 {
            return TweakDBInterface.GetDistrictRecord(ArrayLast(dm.m_visitedDistricts));
        }
        
        if IsDefined(district) {
            return district.GetDistrictRecord();
        }

        return TweakDBInterface.GetDistrictRecord(t"Districts.Watson");
    }

    public func OnDistrictChanged() -> Void {
        let district_record = this.GetReliableDistrictRecord();
        this.m_cachedDistrict = district_record.EnumName();
        
        if !this.IsSmasherEventInProgress() && ArraySize(this.m_encounterPointBuffer) < this.m_maxBufferSize {
            let playerPos = GetPlayer(this.GetGameInstance()).GetWorldPosition();
            let potentialPoint = this.getSmasherSpawnPoint(playerPos, this.m_cachedDistrict);
            if !Vector4.IsXYZZero(potentialPoint) {
                ArrayPush(this.m_encounterPointBuffer, potentialPoint);
            };
        };
    }

    public func PlayRandomScream() -> Void {
        let player = GetPlayer(this.GetGameInstance());
        if IsDefined(player) {
            let roll = RandRange(1, 5);
            let soundName: CName;

            switch roll {
                case 1: soundName = n"ono_v_fear_panic_scream"; break;
                case 2: soundName = n"ono_v_effort_long"; break;
                case 3: soundName = n"ono_v_death_short"; break;
                case 4: soundName = n"ono_v_fall"; break;
            };

            let screamEvt: ref<SoundPlayEvent> = new SoundPlayEvent();
            screamEvt.soundName = soundName;
            player.QueueEvent(screamEvt);
        };
    }

    public func PlaySmasherMusic(opt stop: Bool) -> Void {
        let player = GetPlayer(this.GetGameInstance());
        if IsDefined(player) {
            if !stop && !this.settings.EnableMusic {
                return;
            };
            let musicEvt: ref<SoundPlayEvent> = new SoundPlayEvent();
            if stop {
                musicEvt.soundName = n"mus_q115_going_solo_adam_smasher_STOP";
            } else {
                musicEvt.soundName = n"mus_q115_going_solo_adam_smasher_START";
            };
            player.QueueEvent(musicEvt);
        };
    }
}

@wrapMethod(PlayerPuppet)
protected cb func OnDistrictChanged(evt: ref<PlayerEnteredNewDistrictEvent>) -> Bool {
    wrappedMethod(evt);
    let smasherSys = GameInstance.GetSmasherEncountersSystem(this.GetGame());
    if IsDefined(smasherSys) {
        smasherSys.OnDistrictChanged();
    };
}

@wrapMethod(PlayerPuppet)
protected cb func OnStatusEffectApplied(evt: ref<ApplyStatusEffectEvent>) -> Void {
    wrappedMethod(evt);
    let gameplayTags: array<CName> = evt.staticData.GameplayTags();
    let smasherSys = GameInstance.GetSmasherEncountersSystem(this.GetGame());
    
    if IsDefined(smasherSys) {
        if ArrayContains(gameplayTags, n"SandevistanPlayerBuff") { smasherSys.RegisterCyberwareUsage(n"SandevistanPlayerBuff"); }
        else if ArrayContains(gameplayTags, n"Berserk") { smasherSys.RegisterCyberwareUsage(n"Berserk"); }
        else if ArrayContains(gameplayTags, n"Overclock") { smasherSys.RegisterCyberwareUsage(n"Overclock"); }
        else if ArrayContains(gameplayTags, n"InFury") { smasherSys.RegisterEdgerunnerFury(); };
    };
}

@addMethod(PlayerPuppet)
public func CheckSmasher() -> Void {
    let smasherSys = GameInstance.GetSmasherEncountersSystem(this.GetGame());
    if IsDefined(smasherSys) {
        smasherSys.PrintSpawnPoints();
    };
}

@wrapMethod(ScriptedPuppet)
protected func RewardKiller(killer: wref<GameObject>, killType: gameKillType, isAnyDamageNonlethal: Bool) -> Void {
    wrappedMethod(killer, killType, isAnyDamageNonlethal);
    
    let gi = GetGameInstance();
    let player = GetPlayer(gi);
    if IsDefined(killer as PlayerPuppet) && !player.IsReplacer() {
        let npcAffiliation: gamedataAffiliation;
        
        if (this as ScriptedPuppet).IsMaxTac() {
            npcAffiliation = gamedataAffiliation.NCPD;
        } else {
            let npcRecord = this.GetRecord();
            if IsDefined(npcRecord) {
                let affiliationRecord = npcRecord.Affiliation();
                if IsDefined(affiliationRecord) {
                    npcAffiliation = affiliationRecord.Type();
                } else {
                    return;
                };
            } else {
                return;
            };
        };

        if Equals(npcAffiliation, gamedataAffiliation.Arasaka) && !isAnyDamageNonlethal && NotEquals(killType, gameKillType.Defeat) {
            let smasherSys = GameInstance.GetSmasherEncountersSystem(gi);
            if IsDefined(smasherSys) {
                smasherSys.RegisterArasakaKill();
            };
        };
    };
}

public class SmasherEncountersSettings {
    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "General")
    @runtimeProperty("ModSettings.category.order", "0")
    @runtimeProperty("ModSettings.displayName", "Mod Enabled")
    @runtimeProperty("ModSettings.description", "Master toggle to enable or disable the entire mod.")
    public let ModEnabled: Bool = true;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "General")
    @runtimeProperty("ModSettings.displayName", "BETA: Enable Combat Music")
    @runtimeProperty("ModSettings.description", "Enables epic music during the encounter with Adam Smasher. It may be buggy sometimes.")
    public let EnableMusic: Bool = false;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "General")
    @runtimeProperty("ModSettings.displayName", "Activate Only After Hanako Quest")
    @runtimeProperty("ModSettings.description", "If enabled, Smasher encounters will only start after completing kidnapping Hanako quest.")
    public let OnlyAfterHanako: Bool = false;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "General")
    @runtimeProperty("ModSettings.displayName", "Enable Pre-spawn Visual Effects")
    @runtimeProperty("ModSettings.description", "Enables visual glitches before Smasher appears.")
    public let EnablePreSpawnEffects: Bool = true;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "Difficulty")
    @runtimeProperty("ModSettings.displayName", "Difficulty Multiplier")
    @runtimeProperty("ModSettings.description", "Increases support unit spawn frequency and combat effect chances.")
    @runtimeProperty("ModSettings.step", "0.1")
    @runtimeProperty("ModSettings.min", "0.1")
    @runtimeProperty("ModSettings.max", "10.0")
    public let DifficultyMultiplier: Float = 1.0;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "Difficulty")
    @runtimeProperty("ModSettings.displayName", "Enable Combat Effects")
    @runtimeProperty("ModSettings.description", "Allows Smasher to apply random combat status effects during the fight.")
    public let EnableSmasherCombatEffects: Bool = true;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "Difficulty")
    @runtimeProperty("ModSettings.displayName", "Enable Support Unit Spawns")
    @runtimeProperty("ModSettings.description", "Allows Arasaka support units to spawn during the Smasher fight.")
    public let EnableSmasherSupportUnits: Bool = true;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "General")
    @runtimeProperty("ModSettings.displayName", "Enable Vehicle Hacking")
    @runtimeProperty("ModSettings.description", "Allows Smasher to take control of your vehicle while driving.")
    public let EnableVehicleHacking: Bool = true;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "General")
    @runtimeProperty("ModSettings.displayName", "Breach Minigame Time Limit")
    @runtimeProperty("ModSettings.description", "Time in seconds to solve the breach minigame.")
    @runtimeProperty("ModSettings.step", "1.0")
    @runtimeProperty("ModSettings.min", "5.0")
    @runtimeProperty("ModSettings.max", "60.0")
    public let BreachMinigameTimeLimit: Float = 15.0;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "General")
    @runtimeProperty("ModSettings.displayName", "Enable Hack Disruption")
    @runtimeProperty("ModSettings.description", "Allows you to attempt to disrupt Smasher's hacking (F).")
    public let EnableHackDisruption: Bool = true;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "General")
    @runtimeProperty("ModSettings.displayName", "Points Per Arasaka Kill")
    @runtimeProperty("ModSettings.description", "Spawn points earned per Arasaka member killed.")
    @runtimeProperty("ModSettings.step", "0.1")
    @runtimeProperty("ModSettings.min", "0.0")
    @runtimeProperty("ModSettings.max", "100.0")
    public let ArasakaKillPoints: Float = 2.0;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "General")
    @runtimeProperty("ModSettings.displayName", "Points Per Sandevistan Use")
    @runtimeProperty("ModSettings.description", "Spawn points earned per Sandevistan activation.")
    @runtimeProperty("ModSettings.step", "0.1")
    @runtimeProperty("ModSettings.min", "0.0")
    @runtimeProperty("ModSettings.max", "100.0")
    public let SandevistanPoints: Float = 0.4;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "General")
    @runtimeProperty("ModSettings.displayName", "Points Per Berserk Use")
    @runtimeProperty("ModSettings.description", "Spawn points earned per Berserk activation.")
    @runtimeProperty("ModSettings.step", "0.1")
    @runtimeProperty("ModSettings.min", "0.0")
    @runtimeProperty("ModSettings.max", "100.0")
    public let BerserkPoints: Float = 0.3;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "General")
    @runtimeProperty("ModSettings.displayName", "Points Per Overclock Use")
    @runtimeProperty("ModSettings.description", "Spawn points earned per Overclock activation.")
    @runtimeProperty("ModSettings.step", "0.1")
    @runtimeProperty("ModSettings.min", "0.0")
    @runtimeProperty("ModSettings.max", "100.0")
    public let OverclockPoints: Float = 0.2;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "General")
    @runtimeProperty("ModSettings.displayName", "Points Per Edgerunner Fury")
    @runtimeProperty("ModSettings.description", "Spawn points earned per Edgerunner Fury activation.")
    @runtimeProperty("ModSettings.step", "0.1")
    @runtimeProperty("ModSettings.min", "0.0")
    @runtimeProperty("ModSettings.max", "100.0")
    public let EdgerunnerFuryPoints: Float = 10.0;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "Rewards")
    @runtimeProperty("ModSettings.displayName", "Quickhack Material Multiplier")
    @runtimeProperty("ModSettings.description", "Multiplier for legendary quickhack materials from successful breach minigames (5-10 base).")
    @runtimeProperty("ModSettings.step", "0.1")
    @runtimeProperty("ModSettings.min", "0.0")
    @runtimeProperty("ModSettings.max", "10.0")
    public let QuickhackMaterialMultiplier: Float = 1.0;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "Rewards")
    @runtimeProperty("ModSettings.displayName", "Legendary Component Multiplier")
    @runtimeProperty("ModSettings.description", "Multiplier for legendary components from defeating Smasher.")
    @runtimeProperty("ModSettings.step", "0.1")
    @runtimeProperty("ModSettings.min", "0.0")
    @runtimeProperty("ModSettings.max", "10.0")
    public let LegendaryComponentMultiplier: Float = 1.0;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "Rewards")
    @runtimeProperty("ModSettings.displayName", "SMS Reward Money Multiplier")
    @runtimeProperty("ModSettings.description", "Multiplier for eddie rewards from Unknown Number SMS.")
    @runtimeProperty("ModSettings.step", "0.1")
    @runtimeProperty("ModSettings.min", "0.0")
    @runtimeProperty("ModSettings.max", "10.0")
    public let SmsRewardMultiplier: Float = 1.0;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "Difficulty")
    @runtimeProperty("ModSettings.displayName", "Smasher Health Multiplier")
    @runtimeProperty("ModSettings.description", "Multiplies Smasher's starting Health.")
    @runtimeProperty("ModSettings.step", "0.1")
    @runtimeProperty("ModSettings.min", "0.1")
    @runtimeProperty("ModSettings.max", "10.0")
    public let SmasherHealthMultiplier: Float = 1.0;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "Difficulty")
    @runtimeProperty("ModSettings.displayName", "Smasher Armor Multiplier")
    @runtimeProperty("ModSettings.description", "Multiplies Smasher's starting Armor.")
    @runtimeProperty("ModSettings.step", "0.1")
    @runtimeProperty("ModSettings.min", "0.1")
    @runtimeProperty("ModSettings.max", "10.0")
    public let SmasherArmorMultiplier: Float = 1.0;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "Difficulty")
    @runtimeProperty("ModSettings.displayName", "Smasher Damage Multiplier")
    @runtimeProperty("ModSettings.description", "Multiplies Smasher's starting damage.")
    @runtimeProperty("ModSettings.step", "0.1")
    @runtimeProperty("ModSettings.min", "0.1")
    @runtimeProperty("ModSettings.max", "10.0")
    public let SmasherDamageMultiplier: Float = 1.0;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "Danger Meter")
    @runtimeProperty("ModSettings.displayName", "Enable Danger Meter")
    public let DangerMeterEnabled: Bool = true;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "Danger Meter")
    @runtimeProperty("ModSettings.displayName", "Enable Visibility Threshold")
    @runtimeProperty("ModSettings.description", "If enabled, the danger meter will only appear after reaching a certain number of points.")
    public let DangerMeterThresholdEnabled: Bool = false;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "Danger Meter")
    @runtimeProperty("ModSettings.displayName", "Danger Meter Visibility Threshold")
    @runtimeProperty("ModSettings.description", "Number of points required for the danger meter to become visible.")
    @runtimeProperty("ModSettings.step", "1.0")
    @runtimeProperty("ModSettings.min", "0.0")
    @runtimeProperty("ModSettings.max", "100.0")
    public let DangerMeterThreshold: Float = 50.0;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "Danger Meter")
    @runtimeProperty("ModSettings.displayName", "Danger Meter Position X")
    @runtimeProperty("ModSettings.step", "1.0")
    @runtimeProperty("ModSettings.min", "0.0")
    @runtimeProperty("ModSettings.max", "3840.0")
    public let DangerMeterPosX: Float = 1630.0;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "Danger Meter")
    @runtimeProperty("ModSettings.displayName", "Danger Meter Position Y")
    @runtimeProperty("ModSettings.step", "1.0")
    @runtimeProperty("ModSettings.min", "0.0")
    @runtimeProperty("ModSettings.max", "2160.0")
    public let DangerMeterPosY: Float = 265.0;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "Danger Meter")
    @runtimeProperty("ModSettings.displayName", "Danger Meter Opacity")
    @runtimeProperty("ModSettings.step", "0.05")
    @runtimeProperty("ModSettings.min", "0.0")
    @runtimeProperty("ModSettings.max", "1.0")
    public let DangerMeterOpacity: Float = 0.25;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "Danger Meter")
    @runtimeProperty("ModSettings.displayName", "Danger Meter Width")
    @runtimeProperty("ModSettings.step", "1.0")
    @runtimeProperty("ModSettings.min", "100.0")
    @runtimeProperty("ModSettings.max", "1000.0")
    public let DangerMeterWidth: Float = 215.0;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "Danger Meter")
    @runtimeProperty("ModSettings.displayName", "Danger Meter Height")
    @runtimeProperty("ModSettings.step", "1.0")
    @runtimeProperty("ModSettings.min", "2.0")
    @runtimeProperty("ModSettings.max", "50.0")
    public let DangerMeterHeight: Float = 5.0;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "Danger Meter")
    @runtimeProperty("ModSettings.displayName", "Danger Meter Color: Red")
    @runtimeProperty("ModSettings.step", "1.0")
    @runtimeProperty("ModSettings.min", "0.0")
    @runtimeProperty("ModSettings.max", "255.0")
    public let DangerMeterColorR: Float = 255.0;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "Danger Meter")
    @runtimeProperty("ModSettings.displayName", "Danger Meter Color: Green")
    @runtimeProperty("ModSettings.step", "1.0")
    @runtimeProperty("ModSettings.min", "0.0")
    @runtimeProperty("ModSettings.max", "255.0")
    public let DangerMeterColorG: Float = 0.0;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "Danger Meter")
    @runtimeProperty("ModSettings.displayName", "Danger Meter Color: Blue")
    @runtimeProperty("ModSettings.step", "1.0")
    @runtimeProperty("ModSettings.min", "0.0")
    @runtimeProperty("ModSettings.max", "255.0")
    public let DangerMeterColorB: Float = 0.0;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "Danger Meter")
    @runtimeProperty("ModSettings.displayName", "Enable Danger Meter Icon")
    public let DangerMeterIconEnabled: Bool = true;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "Danger Meter")
    @runtimeProperty("ModSettings.displayName", "Danger Meter Icon Size")
    @runtimeProperty("ModSettings.step", "1.0")
    @runtimeProperty("ModSettings.min", "5.0")
    @runtimeProperty("ModSettings.max", "100.0")
    public let DangerMeterIconSize: Float = 20.0;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "Danger Meter")
    @runtimeProperty("ModSettings.displayName", "Danger Meter Icon Offset X")
    @runtimeProperty("ModSettings.step", "1.0")
    @runtimeProperty("ModSettings.min", "-200.0")
    @runtimeProperty("ModSettings.max", "200.0")
    public let DangerMeterIconOffsetX: Float = 0.0;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "Danger Meter")
    @runtimeProperty("ModSettings.displayName", "Danger Meter Icon Offset Y")
    @runtimeProperty("ModSettings.step", "1.0")
    @runtimeProperty("ModSettings.min", "-200.0")
    @runtimeProperty("ModSettings.max", "200.0")
    public let DangerMeterIconOffsetY: Float = 40.0;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "Danger Meter")
    @runtimeProperty("ModSettings.displayName", "Danger Meter Icon Color: Red")
    @runtimeProperty("ModSettings.step", "1.0")
    @runtimeProperty("ModSettings.min", "0.0")
    @runtimeProperty("ModSettings.max", "255.0")
    public let DangerMeterIconColorR: Float = 255.0;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "Danger Meter")
    @runtimeProperty("ModSettings.displayName", "Danger Meter Icon Color: Green")
    @runtimeProperty("ModSettings.step", "1.0")
    @runtimeProperty("ModSettings.min", "0.0")
    @runtimeProperty("ModSettings.max", "255.0")
    public let DangerMeterIconColorG: Float = 0.0;

    @runtimeProperty("ModSettings.mod", "Adam Smasher Encounters")
    @runtimeProperty("ModSettings.category", "Danger Meter")
    @runtimeProperty("ModSettings.displayName", "Danger Meter Icon Color: Blue")
    @runtimeProperty("ModSettings.step", "1.0")
    @runtimeProperty("ModSettings.min", "0.0")
    @runtimeProperty("ModSettings.max", "255.0")
    public let DangerMeterIconColorB: Float = 0.0;
}


@wrapMethod(PlayerPuppet)
protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
    wrappedMethod(action, consumer);
    if Equals(ListenerAction.GetName(action), n"ChoiceApply") && ListenerAction.IsButtonJustPressed(action) {
        let smasherSys = GameInstance.GetSmasherEncountersSystem(this.GetGame());
        if IsDefined(smasherSys) && smasherSys.p_awaitingBreakAttackChoice {
            smasherSys.TriggerBreakAttackHack();
        };
    };
}

@wrapMethod(HackingMinigameGameController)
protected cb func OnInitialize() -> Void {

    wrappedMethod();
    
    let bbNetwork = this.GetBlackboardSystem().Get(GetAllBlackboardDefs().NetworkBlackboard);
    let networkName = bbNetwork.GetString(GetAllBlackboardDefs().NetworkBlackboard.NetworkName);
    
    if Equals(networkName, "Vehicle Subsystem Breach") || Equals(networkName, "Unauthorized Signal Detected") {
        let bbMinigame = this.GetBlackboardSystem().Get(GetAllBlackboardDefs().HackingMinigame);
        let variant = bbMinigame.GetVariant(GetAllBlackboardDefs().HackingMinigame.MinigameDefaults);
        if IsDefined(variant) {
            let data = FromVariant<MinigameData>(variant);
            data.timerWaitsForInteraction = false;
            data.bufferSize = 8u;
            
            let smasherSys = GameInstance.GetSmasherEncountersSystem(GetGameInstance());
            if IsDefined(smasherSys) {
                data.timeLimit = smasherSys.settings.BreachMinigameTimeLimit;
            } else {
                data.timeLimit = 15.0;
            };

            bbMinigame.SetVariant(GetAllBlackboardDefs().HackingMinigame.MinigameDefaults, ToVariant(data));
        }


    }

}

public final class inkBorderConcrete extends inkBorder {}

class SmasherDangerMeterSmoothDaemon extends SE_DelayDaemon {
    func Start(gi: GameInstance, opt isAffectedByTimeDilation: Bool) -> Void {
        super.Start(gi, 0.0166, isAffectedByTimeDilation); // ~60 FPS
    };

    func Call() -> Void {
        let hud = SmasherHUDSystem.GetInstance(this.gi);
        if IsDefined(hud) {
            hud.UpdateSmooth();
        };
        this.Repeat();
    };
}

public class SmasherDangerMeter extends inkCanvas {
    private let m_rootWidget: ref<inkCanvas>;
    private let m_bg: ref<inkRectangle>;
    private let m_border: ref<inkBorderConcrete>;
    private let m_fullBar: ref<inkRectangle>;
    private let m_icon: ref<inkImage>;
    
    private let m_width: Float = 400.0;
    private let m_height: Float = 10.0;
    private let m_currentProgress: Float = 0.0;
    private let m_targetProgress: Float = 0.0;
    
    public func Create(parent: ref<inkCompoundWidget>, name: CName, posX: Float, posY: Float, width: Float, height: Float) -> Void {
        this.m_width = width;
        this.m_height = height;

        let canvas: ref<inkCanvas> = new inkCanvas();
        canvas.SetName(name);
        canvas.SetAnchor(inkEAnchor.TopLeft);
        canvas.SetHAlign(inkEHorizontalAlign.Left);
        canvas.SetVAlign(inkEVerticalAlign.Top);
        canvas.SetSize(Vector2(this.m_width + 50.0, 100.0));
        canvas.SetMargin(inkMargin(posX, posY, 0.0, 0.0));
        this.m_rootWidget = canvas;
        canvas.Reparent(parent);

        let icon: ref<inkImage> = new inkImage();
        icon.SetName(n"icon");
        icon.SetAnchor(inkEAnchor.TopLeft);
        icon.SetAnchorPoint(Vector2(0.5, 0.5));
        icon.SetMargin(inkMargin(-10.0, 40.0, 0.0, 0.0));
        icon.SetSize(Vector2(20.0, 20.0));
        icon.SetAtlasResource(r"base\\gameplay\\gui\\common\\icons\\mappin_icons.inkatlas");
        icon.SetTexturePart(n"hunt_for_psycho");
        icon.SetTintColor(HDRColor(1.0, 0.0, 0.0, 1.0));
        icon.Reparent(canvas);
        this.m_icon = icon;

        let bg: ref<inkRectangle> = new inkRectangle();
        bg.SetName(n"bg");
        bg.SetMargin(inkMargin(5.0, 40.0, 0.0, 0.0));
        bg.SetOpacity(0.3);
        bg.SetShear(Vector2(0.5, 0.0));
        bg.SetSize(Vector2(this.m_width, this.m_height));
        bg.SetTintColor(HDRColor(0.2, 0.0, 0.0, 1.0));
        bg.Reparent(canvas);
        this.m_bg = bg;

        let border: ref<inkBorderConcrete> = new inkBorderConcrete();
        border.SetName(n"border");
        border.SetMargin(inkMargin(5.0, 40.0, 0.0, 0.0));
        border.SetOpacity(0.5);
        border.SetShear(Vector2(0.5, 0.0));
        border.SetSize(Vector2(this.m_width, this.m_height + 2.0));
        border.SetThickness(2.0);
        border.SetTintColor(HDRColor(1.0, 0.0, 0.0, 1.0));
        border.Reparent(canvas);
        this.m_border = border;

        let full: ref<inkRectangle> = new inkRectangle();
        full.SetName(n"full");
        full.SetMargin(inkMargin(5.0, 40.0, 0.0, 0.0));
        full.SetShear(Vector2(0.5, 0.0));
        full.SetSize(Vector2(0.0, this.m_height));
        full.SetTintColor(HDRColor(1.0, 0.0, 0.0, 1.0));
        full.Reparent(canvas);
        this.m_fullBar = full;
    }

    public func Update() -> Void {
        if AbsF(this.m_targetProgress - this.m_currentProgress) > 0.001 {
            this.m_currentProgress += (this.m_targetProgress - this.m_currentProgress) * 0.05;
            this.SetBarSize(this.m_currentProgress);
        }
    }

    public func SetProgress(progress: Float) -> Void {
        this.m_targetProgress = ClampF(progress, 0.0, 1.0);
    }

    private func SetBarSize(progress: Float) -> Void {
        if IsDefined(this.m_fullBar) {
            this.m_fullBar.SetSize(Vector2(this.m_width * progress, this.m_height));
        }
    }

    public func SetVisible(visible: Bool) -> Void {
        if IsDefined(this.m_rootWidget) {
            this.m_rootWidget.SetVisible(visible);
        }
    }

    public func SetOpacity(opacity: Float) -> Void {
        if IsDefined(this.m_rootWidget) {
            this.m_rootWidget.SetOpacity(opacity);
        }
    }

    public func SetPosition(posX: Float, posY: Float) -> Void {
        if IsDefined(this.m_rootWidget) {
            this.m_rootWidget.SetMargin(inkMargin(posX, posY, 0.0, 0.0));
        }
    }

    public func SetSize(width: Float, height: Float) -> Void {
        this.m_width = width;
        this.m_height = height;
        if IsDefined(this.m_rootWidget) {
            this.m_rootWidget.SetSize(Vector2(this.m_width + 50.0, 100.0));
        }
        if IsDefined(this.m_bg) {
            this.m_bg.SetSize(Vector2(this.m_width, this.m_height));
        }
        if IsDefined(this.m_border) {
            this.m_border.SetSize(Vector2(this.m_width, this.m_height + 2.0));
        }
    }

    public func SetColor(r: Float, g: Float, b: Float) -> Void {
        let color = HDRColor(r / 255.0, g / 255.0, b / 255.0, 1.0);
        if IsDefined(this.m_fullBar) {
            this.m_fullBar.SetTintColor(color);
        }
        if IsDefined(this.m_border) {
            this.m_border.SetTintColor(color);
        }
    }

    public func SetIconVisible(visible: Bool) -> Void {
        if IsDefined(this.m_icon) {
            this.m_icon.SetVisible(visible);
        }
    }

    public func SetIconSize(size: Float) -> Void {
        if IsDefined(this.m_icon) {
            this.m_icon.SetSize(Vector2(size, size));
        }
    }

    public func SetIconPosition(offsetX: Float, offsetY: Float) -> Void {
        if IsDefined(this.m_icon) {
            this.m_icon.SetMargin(inkMargin(offsetX - 10.0, offsetY, 0.0, 0.0));
        }
    }

    public func SetIconColor(r: Float, g: Float, b: Float) -> Void {
        let color = HDRColor(r / 255.0, g / 255.0, b / 255.0, 1.0);
        if IsDefined(this.m_icon) {
            this.m_icon.SetTintColor(color);
        }
    }
}

public class SmasherHUDSystem extends ScriptableSystem {
    private let m_dangerMeter: ref<SmasherDangerMeter>;
    private let m_playerAttachedCallbackID: Uint32;
    private let m_smoothDaemon: ref<SmasherDangerMeterSmoothDaemon>;
    private let m_scannerCallback: ref<CallbackHandle>;
    private let m_braindanceCallback: ref<CallbackHandle>;

    public final static func GetInstance(gi: GameInstance) -> ref<SmasherHUDSystem> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"SmasherHUDSystem") as SmasherHUDSystem;
    }

    private func OnAttach() -> Void {
        this.m_playerAttachedCallbackID = GameInstance.GetPlayerSystem(this.GetGameInstance()).RegisterPlayerPuppetAttachedCallback(this, n"OnPlayerAttached");
        this.RegisterUIStateListeners();
        if !IsDefined(this.m_smoothDaemon) {
            this.m_smoothDaemon = new SmasherDangerMeterSmoothDaemon();
            this.m_smoothDaemon.Start(this.GetGameInstance(), true);
        }
    }

    private func OnDetach() -> Void {
        GameInstance.GetPlayerSystem(this.GetGameInstance()).UnregisterPlayerPuppetAttachedCallback(this.m_playerAttachedCallbackID);
        this.UnregisterUIStateListeners();
        if IsDefined(this.m_smoothDaemon) {
            this.m_smoothDaemon.Stop();
            this.m_smoothDaemon = null;
        }
    }

    private func RegisterUIStateListeners() -> Void {
        let bbSys = GameInstance.GetBlackboardSystem(this.GetGameInstance());
        let allDefs = GetAllBlackboardDefs();
        this.m_scannerCallback = bbSys.Get(allDefs.UI_Scanner).RegisterListenerBool(allDefs.UI_Scanner.UIVisible, this, n"OnScannerVisibilityChanged");
        this.m_braindanceCallback = bbSys.Get(allDefs.Braindance).RegisterListenerBool(allDefs.Braindance.IsActive, this, n"OnBraindanceChanged");
    }

    private func UnregisterUIStateListeners() -> Void {
        let bbSys = GameInstance.GetBlackboardSystem(this.GetGameInstance());
        let allDefs = GetAllBlackboardDefs();
        if IsDefined(this.m_scannerCallback) {
            bbSys.Get(allDefs.UI_Scanner).UnregisterListenerBool(allDefs.UI_Scanner.UIVisible, this.m_scannerCallback);
            this.m_scannerCallback = null;
        };
        if IsDefined(this.m_braindanceCallback) {
            bbSys.Get(allDefs.Braindance).UnregisterListenerBool(allDefs.Braindance.IsActive, this.m_braindanceCallback);
            this.m_braindanceCallback = null;
        };
    }

    protected cb func OnScannerVisibilityChanged(value: Bool) -> Bool {
        this.RefreshDangerMeter();
    }

    protected cb func OnBraindanceChanged(value: Bool) -> Bool {
        this.RefreshDangerMeter();
    }

    public func IsBlockedByGameState() -> Bool {
        let gi = this.GetGameInstance();
        let player = GetPlayer(gi);
        if !IsDefined(player) { return true; };
        if PlayerPuppet.GetSceneTier(player) != 1 { return true; };

        let allDefs = GetAllBlackboardDefs();
        let bbSys = GameInstance.GetBlackboardSystem(gi);

        let scanBB = bbSys.Get(allDefs.UI_Scanner);
        if IsDefined(scanBB) && scanBB.GetBool(allDefs.UI_Scanner.UIVisible) { return true; };

        let bdBB = bbSys.Get(allDefs.Braindance);
        if IsDefined(bdBB) && bdBB.GetBool(allDefs.Braindance.IsActive) { return true; };

        return false;
    }

    public func RefreshDangerMeter() -> Void {
        let gi = this.GetGameInstance();
        let smasherSys = GameInstance.GetSmasherEncountersSystem(gi);
        if !IsDefined(smasherSys) || !IsDefined(smasherSys.settings) {
            this.UpdateDanger(0.0, false);
            return;
        };

        if smasherSys.IsSmasherEventInProgress() || smasherSys.isSmasherDefeated()
        || !smasherSys.settings.DangerMeterEnabled {
            this.UpdateDanger(0.0, false);
            return;
        };

        let totalPoints = smasherSys.p_spawnPoints;
        let isVisible = true;
        if smasherSys.settings.DangerMeterThresholdEnabled && totalPoints < smasherSys.settings.DangerMeterThreshold {
            isVisible = false;
        };
        if isVisible && this.IsBlockedByGameState() {
            isVisible = false;
        };
        this.UpdateDanger(totalPoints / 100.0, isVisible);
    }

    protected cb func OnPlayerAttached(playerPuppet: ref<GameObject>) -> Void {
        let player = playerPuppet as PlayerPuppet;
        if IsDefined(player) {
            this.Init(player);
        }
    }

    public func UpdateSmooth() -> Void {
        if IsDefined(this.m_dangerMeter) {
            this.m_dangerMeter.Update();
        }
    }

    public func OnSettingsChanged() -> Void {
        let gi = this.GetGameInstance();
        let smasherSys = GameInstance.GetSmasherEncountersSystem(gi);
        if IsDefined(this.m_dangerMeter) && IsDefined(smasherSys) {
            this.m_dangerMeter.SetVisible(smasherSys.settings.DangerMeterEnabled);
            this.m_dangerMeter.SetPosition(smasherSys.settings.DangerMeterPosX, smasherSys.settings.DangerMeterPosY);
            this.m_dangerMeter.SetOpacity(smasherSys.settings.DangerMeterOpacity);
            this.m_dangerMeter.SetSize(smasherSys.settings.DangerMeterWidth, smasherSys.settings.DangerMeterHeight);
            this.m_dangerMeter.SetColor(smasherSys.settings.DangerMeterColorR, smasherSys.settings.DangerMeterColorG, smasherSys.settings.DangerMeterColorB);
            
            this.m_dangerMeter.SetIconVisible(smasherSys.settings.DangerMeterIconEnabled);
            this.m_dangerMeter.SetIconSize(smasherSys.settings.DangerMeterIconSize);
            this.m_dangerMeter.SetIconPosition(smasherSys.settings.DangerMeterIconOffsetX, smasherSys.settings.DangerMeterIconOffsetY);
            this.m_dangerMeter.SetIconColor(smasherSys.settings.DangerMeterIconColorR, smasherSys.settings.DangerMeterIconColorG, smasherSys.settings.DangerMeterIconColorB);
        }
    }

    public func Init(player: ref<PlayerPuppet>) -> Void {
        let gi = this.GetGameInstance();
        let inkSystem = GameInstance.GetInkSystem();
        if !IsDefined(inkSystem) { return; }
        let inkHUD = inkSystem.GetLayer(n"inkHUDLayer").GetVirtualWindow();

        let hudRoot = inkHUD.GetWidgetByPathName(n"Root") as inkCompoundWidget;
        if !IsDefined(hudRoot) {
            hudRoot = inkHUD;
        };

        if !IsDefined(this.m_dangerMeter) {
            let smasherSys = GameInstance.GetSmasherEncountersSystem(gi);
            if !IsDefined(smasherSys) { return; }
            this.m_dangerMeter = new SmasherDangerMeter();
            this.m_dangerMeter.Create(hudRoot, n"SmasherDangerMeter", smasherSys.settings.DangerMeterPosX, smasherSys.settings.DangerMeterPosY, smasherSys.settings.DangerMeterWidth, smasherSys.settings.DangerMeterHeight);
            this.m_dangerMeter.SetOpacity(smasherSys.settings.DangerMeterOpacity);
            this.m_dangerMeter.SetVisible(smasherSys.settings.DangerMeterEnabled);
            this.m_dangerMeter.SetColor(smasherSys.settings.DangerMeterColorR, smasherSys.settings.DangerMeterColorG, smasherSys.settings.DangerMeterColorB);

            this.m_dangerMeter.SetIconVisible(smasherSys.settings.DangerMeterIconEnabled);
            this.m_dangerMeter.SetIconSize(smasherSys.settings.DangerMeterIconSize);
            this.m_dangerMeter.SetIconPosition(smasherSys.settings.DangerMeterIconOffsetX, smasherSys.settings.DangerMeterIconOffsetY);
            this.m_dangerMeter.SetIconColor(smasherSys.settings.DangerMeterIconColorR, smasherSys.settings.DangerMeterIconColorG, smasherSys.settings.DangerMeterIconColorB);
        }
    }

    public func UpdateDanger(progress: Float, visible: Bool) -> Void {
        if IsDefined(this.m_dangerMeter) {
            this.m_dangerMeter.SetVisible(visible);
            this.m_dangerMeter.SetProgress(progress);
        }
    }
}

@wrapMethod(UISystem)
public final func PushGameContext(context: UIGameContext) -> Void {
    wrappedMethod(context);
    let smasherSys = GameInstance.GetSmasherEncountersSystem(GetGameInstance());
    if IsDefined(smasherSys) {
        SmasherHUDSystem.GetInstance(GetGameInstance()).RefreshDangerMeter();
    }
}

@wrapMethod(UISystem)
public final func PopGameContext(context: UIGameContext, opt invalidate: Bool) -> Void {
    wrappedMethod(context, invalidate);
    let smasherSys = GameInstance.GetSmasherEncountersSystem(GetGameInstance());
    if IsDefined(smasherSys) {
        SmasherHUDSystem.GetInstance(GetGameInstance()).RefreshDangerMeter();
    }
}

@wrapMethod(UISystem)
public final func ResetGameContext() -> Void {
    wrappedMethod();
    let smasherSys = GameInstance.GetSmasherEncountersSystem(GetGameInstance());
    if IsDefined(smasherSys) {
        SmasherHUDSystem.GetInstance(GetGameInstance()).RefreshDangerMeter();
    }
}

@wrapMethod(TakeOverControlSystem)
public final static func CreateInputHint(context: GameInstance, isVisible: Bool) -> Void {
    wrappedMethod(context, isVisible);
    if !isVisible {
        SmasherHUDSystem.GetInstance(context).RefreshDangerMeter();
    }
}
