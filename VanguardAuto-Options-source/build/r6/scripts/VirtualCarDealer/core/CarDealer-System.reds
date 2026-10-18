module CarDealer.System
import CarDealer.Classes.PurchasableVehicleBundle
import CarDealer.Classes.PurchasableVehicleVariant
import CarDealer.Classes.AutofixerItemData
import CarDealer.Utils.CarDealerLog
import CarDealer.Localization.VanguardAutoLocalization
import CarDealer.Calendar.VanguardAutoCalendar
import VAO.Settings.VanguardAutoOptions

@if(ModuleExists("VehiclePersistence.System"))
import VehiclePersistence.System.PersistentVehicleSystem

public class PurchasableVehicleSystem extends ScriptableSystem {
  private persistent let m_vanguardCoverageAlertsMode: Int32;

  private persistent let m_vanguardMutedAlertCategories: array<Int32>;

  private func EnsureVanguardAlertPreferences() -> Void {
    if this.m_vanguardCoverageAlertsMode == 0 {
      this.m_vanguardCoverageAlertsMode = this.m_promoAlertsDisabled ? 2 : 1;
    };
  }

  public func AreVanguardAlertSectionEnabled(coverage: Bool) -> Bool {
    this.EnsureVanguardAlertPreferences();
    return coverage ? this.m_vanguardCoverageAlertsMode != 2 : !this.m_promoAlertsDisabled;
  }

  public func ToggleVanguardAlertSection(coverage: Bool) -> Void {
    this.EnsureVanguardAlertPreferences();
    if coverage {
      this.m_vanguardCoverageAlertsMode = this.m_vanguardCoverageAlertsMode == 2 ? 1 : 2;
    } else {
      this.m_promoAlertsDisabled = !this.m_promoAlertsDisabled;
    };
    this.m_vanguardAlertsRevision += 1;
  }

  public func IsVanguardAlertCategorySelected(category: Int32) -> Bool {
    return !ArrayContains(this.m_vanguardMutedAlertCategories, category);
  }

  public func IsVanguardAlertCategoryEnabled(category: Int32) -> Bool {
    return this.AreVanguardAlertSectionEnabled(category >= 100) && this.IsVanguardAlertCategorySelected(category);
  }

  public func ToggleVanguardAlertCategory(category: Int32) -> Void {
    if !((category >= 1 && category <= 6) || (category >= 101 && category <= 106)) { return; };
    if !this.AreVanguardAlertSectionEnabled(category >= 100) { return; };
    if ArrayContains(this.m_vanguardMutedAlertCategories, category) {
      ArrayRemove(this.m_vanguardMutedAlertCategories, category);
    } else {
      ArrayPush(this.m_vanguardMutedAlertCategories, category);
    };
    this.m_vanguardAlertsRevision += 1;
  }

  public func GetVanguardPhoneAlertCategory(kind: Int32) -> Int32 {
    if kind >= 1001 && kind <= 1018 || kind == 3010 { return 3; };
    if kind >= 2000 && kind <= 2200 { return 4; };
    if kind == 3004 { return 2; };
    if kind == 3201 { return 5; };
    if kind == 3101 || kind == 3102 { return 104; };
    if kind == 3103 || kind == 3104 { return 106; };
    if kind == 3110 || kind == 3111 || kind == 3114 { return 105; };
    if kind >= 3100 && kind < 3200 { return 103; };
    return 1;
  }

  public func IsVanguardPhoneAlertKindEnabled(kind: Int32) -> Bool {
    return this.IsVanguardAlertCategoryEnabled(this.GetVanguardPhoneAlertCategory(kind));
  }

  public func IsVanguardPhoneAlertEnabledAt(index: Int32) -> Bool {
    let count: Int32 = ArraySize(this.m_vanguardPhoneMessageKinds);
    if index < 1 || index > count { return false; };
    return this.IsVanguardPhoneAlertKindEnabled(this.m_vanguardPhoneMessageKinds[count - index]);
  }

  private persistent let m_vanguardCoveragePhoneUnreadCount: Int32;
  private persistent let m_vanguardPhoneUnreadSplitReady: Bool;

  private func EnsureVanguardPhoneUnreadSplit() -> Void {
    let count: Int32 = ArraySize(this.m_vanguardPhoneMessageKinds);
    let i: Int32;
    if this.m_vanguardPhoneUnreadSplitReady { return; };
    this.m_vanguardPhoneUnreadSplitReady = true;
    this.m_vanguardPhoneUnreadCount = Min(count, Max(0, this.m_vanguardPhoneUnreadCount));
    i = count - this.m_vanguardPhoneUnreadCount;
    while i < count {
      if this.GetVanguardPhoneAlertCategory(this.m_vanguardPhoneMessageKinds[i]) >= 100 {
        this.m_vanguardCoveragePhoneUnreadCount += 1;
      };
      i += 1;
    };
    this.m_vanguardPhoneUnreadCount -= this.m_vanguardCoveragePhoneUnreadCount;
  }

  public func GetVanguardCoveragePhoneUnreadCount() -> Int32 {
    this.EnsureVanguardPhoneUnreadSplit();
    return this.m_vanguardCoveragePhoneUnreadCount;
  }

  public func ResetVanguardCoveragePhoneUnreadCount() -> Void {
    this.EnsureVanguardPhoneUnreadSplit();
    this.m_vanguardCoveragePhoneUnreadCount = 0;
  }

  public func GetVanguardAllPhoneUnreadCount() -> Int32 {
    this.EnsureVanguardPhoneUnreadSplit();
    return this.m_vanguardPhoneUnreadCount + this.m_vanguardCoveragePhoneUnreadCount;
  }

  public func GetVanguardPhoneAlertCategoryAt(index: Int32) -> Int32 {
    let count: Int32 = ArraySize(this.m_vanguardPhoneMessageKinds);
    if index < 1 || index > count { return 0; };
    return this.GetVanguardPhoneAlertCategory(this.m_vanguardPhoneMessageKinds[count - index]);
  }

  public func GetVanguardCurrentPhoneMinute() -> Int32 {
    return this.GetCurrentGameMinute();
  }

  public func GetVanguardPhoneHistoryMinuteAt(index: Int32) -> Int32 {
    this.NormalizeVanguardPhoneHistoryArrays();
    let count: Int32 = ArraySize(this.m_vanguardPhoneMessageMinutes);
    if index < 1 || index > count { return 0; };
    return this.m_vanguardPhoneMessageMinutes[count - index];
  }

  public func GetVanguardGeneralHistoryCount() -> Int32 {
    let i: Int32 = 0;
    let count: Int32 = 0;
    while i < ArraySize(this.m_vanguardPhoneMessageKinds) {
      if this.GetVanguardPhoneAlertCategory(this.m_vanguardPhoneMessageKinds[i]) < 100 {
        count += 1;
      };
      i += 1;
    };
    return count;
  }

  public func GetVanguardGeneralHistoryText(index: Int32) -> String {
    let i: Int32 = ArraySize(this.m_vanguardPhoneMessageKinds) - 1;
    let count: Int32 = 0;
    if index < 1 { return ""; };
    while i >= 0 {
      if this.GetVanguardPhoneAlertCategory(this.m_vanguardPhoneMessageKinds[i]) < 100 {
        count += 1;
        if count == index { return this.GetPhoneMessageTextAt(i); };
      };
      i -= 1;
    };
    return "";
  }

  private persistent let m_vanguardCreditEvents: array<Int32>;
  private persistent let m_marmurAutoEventContractSerials: array<Int32>;
  private persistent let m_vanguardCreditEventHead: Int32;
  private persistent let m_vanguardCreditApplicationSerial: Int32;
  private let m_marmurFinancialCreditReady: Bool;
  private let m_marmurCreditHeartbeat: Float;
  private let m_marmurCreditScore: Int32;
  private let m_marmurCreditLimit: Int32;
  private let m_marmurCreditOutstanding: Int32;
  private let m_marmurCreditAPR: Int32;
  private let m_marmurCreditBaseDecision: Int32;

  public persistent let vanguardParkingVehicleIDs: array<TweakDBID>;
  public persistent let vanguardParkingLiveVehicleIDs: array<TweakDBID>;
  public persistent let vanguardParkingPositions: array<Vector4>;
  public persistent let vanguardParkingObserved: array<Bool>;
  public let vanguardParkingEntityIDs: array<EntityID>;
  public let vanguardDispatchPending: Bool;
  public let vanguardDispatchVehicleID: TweakDBID;
  public let vanguardDispatchExpectedVehicleID: TweakDBID;
  public let vanguardDispatchDueAt: Float;
  public let vanguardDispatchStartedAt: Float;
  public let vanguardDispatchDuration: Float;
  public let vanguardDispatchDistance: Float;
  public let vanguardDispatchHasObservedOrigin: Bool;
  public let vanguardDispatchStartPosition: Vector4;
  public let vanguardDispatchCurrentPosition: Vector4;
  public let vanguardDispatchTargetPosition: Vector4;
  public let vanguardDispatchMappinID: NewMappinID;

  private let m_marmurCreditRegistrationSession: Int32;

  private let m_marmurCreditRegistrationCount: Int32;

  private let m_marmurCreditRegistrationSequence: Int32;

  private let m_marmurLastServiceSession: Int32;
  public func GetMarmurLoanServicingVersion() -> Int32 { return 1; }
  public func ApplyMarmurFinancedPackageCancellation(serial: Int32) -> Bool {
    let index: Int32 = this.GetNCGTPerformancePackageIndexBySerial(serial);
    let i: Int32;
    let id: TweakDBID;
    let total: Int32;
    let paid: Int32;
    let refund: Int32;
    let remaining: Int32;
    let player: ref<PlayerPuppet>;
    let qs: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    let key: CName = StringToName("marmur_auto_package_cancel_" + IntToString(serial));
    if !this.IsMarmurBankAutoFinanceAvailable() || !IsDefined(qs) || serial <= 0 || index < 0 { return false; };
    if qs.GetFact(key) == 1 { return true; };
    if this.m_ncgtPerformanceTransactionStates[index] != 1 || !this.m_ncgtPerformanceFinanced[index]
      || this.m_ncgtPerformancePaymentModes[index] != 2 { return false; };
    id = this.m_ncgtPerformanceVehicleIDs[index];
    i = this.GetFinanceContractIndex(id);
    if i < 0 || i >= ArraySize(this.m_financePaidAmounts) || i >= ArraySize(this.m_financeTotalDue)
      || i >= ArraySize(this.m_financeMonthlyPayments) || i >= ArraySize(this.m_financeDownPayments)
      || i >= ArraySize(this.m_financeRemainingMonths) { return false; };
    total = this.m_ncgtPerformanceRollbackFinanceTotals[index];
    paid = this.m_financePaidAmounts[i];
    if total <= 0 || this.m_financeTotalDue[i] < total || paid < 0 || paid > this.m_financeTotalDue[i]
      || this.m_ncgtPerformanceRollbackFinanceMonthly[index] <= 0
      || this.m_ncgtPerformanceRollbackFinanceDownPayments[index] < 0 { return false; };
    refund = Max(0, this.m_ncgtPerformanceRollbackRefunds[index]) + Max(0, paid - total);
    remaining = Max(1, this.m_financeRemainingMonths[i]);
    player = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if refund > 0 && (!IsDefined(player) || !IsDefined(this.m_transactionSystem)) { return false; };
    this.RegisterVanguardCreditContract(id, true);
    this.CaptureVanguardMaturedObligations(id);
    this.m_financeTotalDue[i] = total;
    this.m_financeDownPayments[i] = this.m_ncgtPerformanceRollbackFinanceDownPayments[index];
    this.m_financePaidAmounts[i] = Min(paid, total);
    if paid <= 0 { this.m_financeMonthlyPayments[i] = Max(1, this.m_ncgtPerformanceRollbackFinanceMonthly[index]); }
    else { this.m_financeMonthlyPayments[i] = Max(1, (Max(0, total - paid) + remaining - 1) / remaining); };
    this.RecordVanguardCreditAdjustment(id);
    if this.GetFinanceRemainingBalanceByIndex(i) <= 0 { this.RemovePaidVanguardCreditContract(id); };
    if refund > 0 { this.m_transactionSystem.GiveItem(player, MarketSystem.Money(), refund); };
    qs.SetFact(key, 1);
    this.m_financeContractsDirty = true;
    return true;
  }
  public func AuthorizeMarmurCoverageRepossession(contractIndex: Int32, contractSerial: Int32) -> Bool {
    let i: Int32 = contractIndex - 1;
    let qs: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    if !this.IsMarmurBankAutoFinanceAvailable() || !IsDefined(qs) || contractSerial <= 0
      || i < 0 || i >= ArraySize(this.m_financeVehicleIDs)
      || this.EnsureFinanceContractSerial(this.m_financeVehicleIDs[i]) != contractSerial { return false; };
    qs.SetFact(StringToName("marmur_auto_coverage_repo_" + IntToString(contractSerial)), 1);
    return true;
  }
  public func HasMarmurCoverageRepossessionAuthorization(id: TweakDBID) -> Bool {
    let qs: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    let serial: Int32 = this.EnsureFinanceContractSerial(id);
    if !IsDefined(qs) || serial <= 0 { return false; };
    return qs.GetFact(StringToName("marmur_auto_coverage_repo_" + IntToString(serial))) == 1;
  }

  public func GetVanguardCreditReportingVersion() -> Int32 { return 1; }

  public func SetMarmurFinancialCreditProfile(ready: Bool, score: Int32, limit: Int32, outstanding: Int32, apr: Int32, decision: Int32) -> Void {
    this.m_marmurFinancialCreditReady = ready && score >= 0 && score <= 850 && limit >= 0 && outstanding >= 0 && apr > 0;
    this.m_marmurCreditScore = score;
    this.m_marmurCreditLimit = limit;
    this.m_marmurCreditOutstanding = outstanding;
    this.m_marmurCreditAPR = apr;
    this.m_marmurCreditBaseDecision = decision;
    this.m_marmurCreditHeartbeat = EngineTime.ToFloat(GameInstance.GetEngineTime(this.GetGameInstance()));
  }

  public func IsMarmurFinancialCreditAvailable() -> Bool {
    let now: Float = EngineTime.ToFloat(GameInstance.GetEngineTime(this.GetGameInstance()));
    return this.m_marmurFinancialCreditReady && this.IsMarmurBankAutoFinanceAvailable()
      && now >= this.m_marmurCreditHeartbeat && now - this.m_marmurCreditHeartbeat <= 3.00;
  }

  public func GetFinancialCreditScore(player: ref<PlayerPuppet>) -> Int32 {
    return this.IsMarmurFinancialCreditAvailable() ? this.m_marmurCreditScore : 0;
  }

  public func GetFinancialCreditLabel(player: ref<PlayerPuppet>) -> String {
    let score: Int32 = this.GetFinancialCreditScore(player);
    if !this.IsMarmurFinancialCreditAvailable() { return "UNAVAILABLE"; };
    if score <= 0 { return "NO HISTORY"; };
    if score < 580 { return "POOR"; };
    if score < 670 { return "FAIR"; };
    if score < 740 { return "GOOD"; };
    return "EXCELLENT";
  }

  public func GetFinancialCreditSummary(player: ref<PlayerPuppet>) -> String {
    if !this.IsMarmurFinancialCreditAvailable() { return "--"; };
    if this.m_marmurCreditScore <= 0 { return "NO HISTORY"; };
    return IntToString(this.m_marmurCreditScore);
  }

  public func GetFinancialCreditTint(player: ref<PlayerPuppet>) -> CName {
    let score: Int32 = this.GetFinancialCreditScore(player);
    if score <= 0 { return n"MainColors.Grey"; };
    if score < 580 { return n"MainColors.Red"; };
    if score < 670 { return n"MarmurCredit.Orange"; };
    if score < 740 { return n"MarmurCredit.Blue"; };
    return n"MainColors.Green";
  }
  public func GetMarmurCreditAvailableLimit(releasedDebt: Int32) -> Int32 {
    if !this.IsMarmurFinancialCreditAvailable() { return 0; };
    return Max(0, this.m_marmurCreditLimit - Max(0, this.m_marmurCreditOutstanding - Max(0, releasedDebt)));
  }
  public func GetMarmurCreditDecisionCode(principal: Int32, releasedDebt: Int32) -> Int32 {
    if !this.IsMarmurFinancialCreditAvailable() { return 1; };
    if this.GetVanguardCreditEventCount() > 0 { return 10; };
    if principal <= 0 { return 2; };
    if this.m_marmurCreditBaseDecision != 0 && this.m_marmurCreditBaseDecision != 7 { return this.m_marmurCreditBaseDecision; };
    if this.m_marmurCreditScore <= 0 { return 6; };
    if principal > this.GetMarmurCreditAvailableLimit(releasedDebt) { return 7; };
    return 0;
  }

  public func GetMarmurCreditDecisionText(principal: Int32, releasedDebt: Int32) -> String {
    let code: Int32 = this.GetMarmurCreditDecisionCode(principal, releasedDebt);
    switch code {
      case 0: return "Eligible under your current Marmur financial credit profile.";
      case 1: return "Marmur credit services are unavailable. Install the matching Marmur credit update and try again.";
      case 2: return "The amount financed must be greater than zero.";
      case 3: return "Open a Marmur Bank account before applying for financing.";
      case 4: return "New borrowing is restricted following a loan default.";
      case 5: return "Bring overdue loan payments current before applying for more credit.";
      case 6: return "No credit history. Build repayment history with a Marmur starter personal loan first.";
      case 7: return "The amount financed exceeds available credit after existing loans. Lower the price or increase the down payment.";
      case 10: return "Marmur is updating your loan records. Please try again once the records are synchronized.";
    };
    return "Marmur Bank could not approve this financial credit profile.";
  }

  public func GetCreditReleasedByTradeIn(ids: array<TweakDBID>) -> Int32 {
    let seen: array<TweakDBID>;
    let released: Int32 = 0;
    let contract: TweakDBID;
    let owned: array<ref<AutofixerItemData>> = this.GetOwnedVehiclesData();
    for id in ids {
      for data in owned {
        if IsDefined(data) && Equals(data.vehicleID, id) && this.IsTradeInDataEligible(data) {
          contract = this.GetFinanceContractIDForTradeInID(id);
          if TDBID.IsValid(contract) && !ArrayContains(seen, contract) {
            ArrayPush(seen, contract);
            released += Max(0, this.GetFinanceRemainingBalance(contract));
          };
        };
      };
    };
    return Min(this.m_marmurCreditOutstanding, released);
  }

  private func GetVanguardCreditFact(serial: Int32, field: String) -> Int32 {
    let qs: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    if !IsDefined(qs) || serial <= 0 { return 0; };
    return qs.GetFact(StringToName("vanguard_credit_" + IntToString(serial) + "_" + field));
  }

  private func SetVanguardCreditFact(serial: Int32, field: String, value: Int32) -> Void {
    let qs: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    if IsDefined(qs) && serial > 0 { qs.SetFact(StringToName("vanguard_credit_" + IntToString(serial) + "_" + field), value); };
  }

  private func QueueVanguardCreditEvent(kind: Int32, serial: Int32, amount: Int32, required: Int32, balance: Int32,
    original: Int32, installment: Int32, interval: Int32, dueDay: Int32, nextDay: Int32, eventDay: Int32,
    imported: Int32, arrears: Int32, oldestDay: Int32, advance: Int32) -> Void {
    let seq: Int32;
    if serial > 0 {
      seq = this.GetVanguardCreditFact(serial, "sequence") + 1;
      this.SetVanguardCreditFact(serial, "sequence", seq);
    } else {
      this.m_vanguardCreditApplicationSerial += 1;
      seq = this.m_vanguardCreditApplicationSerial;
    };
    ArrayPush(this.m_vanguardCreditEvents, kind);
    ArrayPush(this.m_vanguardCreditEvents, serial);
    ArrayPush(this.m_vanguardCreditEvents, seq);
    ArrayPush(this.m_vanguardCreditEvents, amount);
    ArrayPush(this.m_vanguardCreditEvents, required);
    ArrayPush(this.m_vanguardCreditEvents, balance);
    ArrayPush(this.m_vanguardCreditEvents, original);
    ArrayPush(this.m_vanguardCreditEvents, installment);
    ArrayPush(this.m_vanguardCreditEvents, interval);
    ArrayPush(this.m_vanguardCreditEvents, dueDay);
    ArrayPush(this.m_vanguardCreditEvents, nextDay);
    ArrayPush(this.m_vanguardCreditEvents, eventDay);
    ArrayPush(this.m_vanguardCreditEvents, imported);
    ArrayPush(this.m_vanguardCreditEvents, arrears);
    ArrayPush(this.m_vanguardCreditEvents, oldestDay);
    ArrayPush(this.m_vanguardCreditEvents, advance);
  }

  public func GetVanguardCreditEventCount() -> Int32 {
    return Max(0, (ArraySize(this.m_vanguardCreditEvents) / 16) - this.m_vanguardCreditEventHead);
  }

  public func GetVanguardCreditEventField(field: Int32) -> Int32 {
    let index: Int32 = this.m_vanguardCreditEventHead * 16 + field - 1;
    if field < 1 || field > 16 || this.GetVanguardCreditEventCount() <= 0 || index >= ArraySize(this.m_vanguardCreditEvents) { return 0; };
    return this.m_vanguardCreditEvents[index];
  }

  public func AcknowledgeVanguardCreditEvent(serial: Int32, sequence: Int32) -> Bool {
    if this.GetVanguardCreditEventCount() <= 0 || this.GetVanguardCreditEventField(2) != serial || this.GetVanguardCreditEventField(3) != sequence { return false; };
    this.m_vanguardCreditEventHead += 1;
    if this.GetVanguardCreditEventCount() == 0 {
      ArrayClear(this.m_vanguardCreditEvents);
      this.m_vanguardCreditEventHead = 0;
    };
    return true;
  }
  public func InitializeVanguardCreditContracts() -> Void {
    let session: Int32;
    let count: Int32;
    let serial: Int32;
    let complete: Bool = true;
    if !this.IsMarmurBankAutoFinanceAvailable() { return; };
    session = this.GetOdometerSession();
    count = ArraySize(this.m_financeVehicleIDs);
    if session > 0 && this.m_marmurCreditRegistrationSession == session
      && this.m_marmurCreditRegistrationCount == count
      && this.m_marmurCreditRegistrationSequence == this.m_financeContractSerialSequence { return; };

    for id in this.m_financeVehicleIDs {
      this.RegisterVanguardCreditContract(id, true);
      serial = this.EnsureFinanceContractSerial(id);
      if this.GetFinanceRemainingBalance(id) > 0 && this.GetVanguardCreditFact(serial, "registered") <= 0 {
        complete = false;
      };
    };

    if complete && session > 0 {
      this.m_marmurCreditRegistrationSession = session;
      this.m_marmurCreditRegistrationCount = ArraySize(this.m_financeVehicleIDs);
      this.m_marmurCreditRegistrationSequence = this.m_financeContractSerialSequence;
    };
  }
  private func RegisterVanguardCreditContract(id: TweakDBID, imported: Bool) -> Void {
    let i: Int32 = this.GetFinanceContractIndex(id);
    let serial: Int32;
    let balance: Int32;
    let interval: Int32;
    let due: Int32;
    let installment: Int32;
    let arrears: Int32 = 0;
    let oldest: Int32 = 0;
    let defaultIndex: Int32;
    if i < 0 { return; };
    serial = this.EnsureFinanceContractSerial(id);
    if this.GetVanguardCreditFact(serial, "registered") > 0 { return; };
    balance = this.GetFinanceRemainingBalanceByIndex(i);
    if balance <= 0 { return; };
    interval = this.GetFinancePaymentFrequencyIntervalMinutes(this.GetFinancePaymentFrequency(id));
    due = this.m_financeNextPaymentMinutes[i];
    installment = this.CalculateFinanceScheduledPaymentAmount(this.m_financeMonthlyPayments[i], this.GetFinancePaymentFrequency(id), balance);
    defaultIndex = this.GetFinanceDefaultIndex(id);
    if imported && defaultIndex >= 0 {
      arrears = Min(balance, installment);
      oldest = this.m_financeDefaultStartMinutes[defaultIndex];
      this.SetVanguardCreditFact(serial, "arrears_count", 1);
      this.SetVanguardCreditFact(serial, "arrears_head", 1);
      this.SetVanguardCreditFact(serial, "arrears_1_minute", oldest);
      this.SetVanguardCreditFact(serial, "arrears_1_amount", arrears);
    };
    this.SetVanguardCreditFact(serial, "registered", 1);
    this.SetVanguardCreditFact(serial, "balance", balance);
    this.SetVanguardCreditFact(serial, "cycle_amount", installment);
    this.SetVanguardCreditFact(serial, "arrears", arrears);
    this.SetVanguardCreditFact(serial, "oldest_minute", oldest);
    this.SetVanguardCreditFact(serial, "last_due_minute", arrears > 0 ? oldest : due - interval);
    this.QueueVanguardCreditEvent(1, serial, 0, 0, balance, this.m_financeTotalDue[i], installment, interval / 1440,
      0, due / 1440, this.GetCurrentGameMinute() / 1440, imported ? 1 : 0, arrears, oldest / 1440, 0);
    if this.IsVehicleRepossessed(id) { this.RecordVanguardCreditRepossession(id); };
  }
  private func QueueVanguardCreditApplication() -> Void {
    this.QueueVanguardCreditEvent(7, 0, 0, 0, 0, 0, 0, 0, 0, 0, this.GetCurrentGameMinute() / 1440, 0, 0, 0, 0);
  }
  private func StoreVanguardCreditPaidAmount(i: Int32, amount: Int32) -> Void {
    while ArraySize(this.m_financePaidAmounts) <= i {
      ArrayPush(this.m_financePaidAmounts, this.GetLegacyFinancePaidAmountByIndex(ArraySize(this.m_financePaidAmounts)));
    };
    this.m_financePaidAmounts[i] = Min(this.m_financeTotalDue[i], Max(0, amount));
  }
  private func DebitVanguardCreditWallet(player: ref<GameObject>, amount: Int32) -> Bool {
    let before: Int32;
    let after: Int32;
    if !this.IsMarmurBankAutoFinanceAvailable() { return false; };

    if !IsDefined(player) || amount <= 0 { return false; };
    before = this.m_transactionSystem.GetItemQuantity(player, MarketSystem.Money());
    if before < amount { return false; };
    this.m_transactionSystem.RemoveItemByTDBID(player, t"Items.money", amount);
    after = this.m_transactionSystem.GetItemQuantity(player, MarketSystem.Money());
    if before - after == amount { return true; };

    if before > after { this.m_transactionSystem.GiveItem(player, MarketSystem.Money(), before - after); };
    return false;
  }

  private func GetVanguardCreditCashDue(id: TweakDBID) -> Int32 {
    let serial: Int32 = this.EnsureFinanceContractSerial(id);
    let required: Int32 = this.GetVanguardCreditFact(serial, "cycle_amount");
    let advance: Int32 = this.GetVanguardCreditFact(serial, "advance");
    return Min(this.GetFinanceRemainingBalance(id), Max(0, required - advance));
  }
  private func ApplyVanguardCreditArrearsPayment(serial: Int32, amount: Int32) -> Void {
    let remaining: Int32 = Min(amount, this.GetVanguardCreditFact(serial, "arrears"));
    let applied: Int32 = remaining;
    let head: Int32 = Max(1, this.GetVanguardCreditFact(serial, "arrears_head"));
    let count: Int32 = this.GetVanguardCreditFact(serial, "arrears_count");
    let row: Int32;
    let debit: Int32;
    let key: String;
    while remaining > 0 && head <= count {
      key = "arrears_" + IntToString(head) + "_";
      row = this.GetVanguardCreditFact(serial, key + "amount");
      debit = Min(row, remaining);
      this.SetVanguardCreditFact(serial, key + "amount", row - debit);
      remaining -= debit;
      if row <= debit { head += 1; } else { break; };
    };
    this.SetVanguardCreditFact(serial, "arrears", Max(0, this.GetVanguardCreditFact(serial, "arrears") - applied));
    this.SetVanguardCreditFact(serial, "arrears_head", head);
    this.SetVanguardCreditFact(serial, "oldest_minute", head <= count ? this.GetVanguardCreditFact(serial, "arrears_" + IntToString(head) + "_minute") : 0);
    this.SetVanguardCreditFact(serial, "advance", this.GetVanguardCreditFact(serial, "advance") + Max(0, amount - applied));
  }
  private func RecordVanguardCreditPayment(id: TweakDBID, amount: Int32, after: Int32, closed: Bool) -> Void {
    let serial: Int32 = this.EnsureFinanceContractSerial(id);
    this.ApplyVanguardCreditArrearsPayment(serial, amount);
    this.SetVanguardCreditFact(serial, "balance", after);
    this.QueueVanguardCreditEvent(closed ? 4 : 2, serial, amount, 0, after, 0, 0, 0, 0, 0, this.GetCurrentGameMinute() / 1440, 0, 0, 0, 0);
  }
  private func RecordVanguardCreditDue(id: TweakDBID, required: Int32, cash: Int32, after: Int32, due: Int32, nextDue: Int32) -> Void {
    let serial: Int32 = this.EnsureFinanceContractSerial(id);
    let advance: Int32 = this.GetVanguardCreditFact(serial, "advance");
    let applied: Int32 = Min(required, advance);
    let shortfall: Int32 = Max(0, required - applied - cash);
    let row: Int32;
    let key: String;
    this.SetVanguardCreditFact(serial, "advance", advance - applied);
    if shortfall > 0 {
      row = this.GetVanguardCreditFact(serial, "arrears_count") + 1;
      key = "arrears_" + IntToString(row) + "_";
      this.SetVanguardCreditFact(serial, "arrears_count", row);
      this.SetVanguardCreditFact(serial, key + "amount", shortfall);
      this.SetVanguardCreditFact(serial, key + "minute", due);
      if this.GetVanguardCreditFact(serial, "arrears") == 0 {
        this.SetVanguardCreditFact(serial, "oldest_minute", due);
        this.SetVanguardCreditFact(serial, "arrears_head", row);
      };
      this.SetVanguardCreditFact(serial, "arrears", this.GetVanguardCreditFact(serial, "arrears") + shortfall);
    };
    this.SetVanguardCreditFact(serial, "last_due_minute", due);
    this.SetVanguardCreditFact(serial, "balance", after);
    this.QueueVanguardCreditEvent(3, serial, cash, required, after, 0, 0, 0, due / 1440, nextDue / 1440, due / 1440, 0, 0, 0, 0);
  }
  private func RecordVanguardCreditSchedule(id: TweakDBID) -> Void {
    let i: Int32 = this.GetFinanceContractIndex(id);
    let serial: Int32 = this.EnsureFinanceContractSerial(id);
    if i < 0 { return; };
    this.QueueVanguardCreditEvent(6, serial, 0, 0, this.GetFinanceRemainingBalanceByIndex(i), this.m_financeTotalDue[i],
      this.GetVanguardCreditFact(serial, "cycle_amount"), this.GetFinancePaymentFrequencyIntervalMinutes(this.GetFinancePaymentFrequency(id)) / 1440,
      0, this.m_financeNextPaymentMinutes[i] / 1440, this.GetCurrentGameMinute() / 1440, 0, 0, 0, 0);
  }
  private func RecordVanguardCreditAdjustment(id: TweakDBID) -> Void {
    let i: Int32 = this.GetFinanceContractIndex(id);
    let serial: Int32 = this.EnsureFinanceContractSerial(id);
    let after: Int32;
    let excess: Int32;
    if i < 0 || this.GetVanguardCreditFact(serial, "registered") == 0 { return; };
    after = this.GetFinanceRemainingBalanceByIndex(i);
    this.QueueVanguardCreditEvent(8, serial, Max(0, this.GetVanguardCreditFact(serial, "balance") - after), 0, after, this.m_financeTotalDue[i],
      this.CalculateFinanceScheduledPaymentAmount(this.m_financeMonthlyPayments[i], this.GetFinancePaymentFrequency(id), Max(1, after)),
      this.GetFinancePaymentFrequencyIntervalMinutes(this.GetFinancePaymentFrequency(id)) / 1440, 0,
      this.m_financeNextPaymentMinutes[i] / 1440, this.GetCurrentGameMinute() / 1440, 0, 0, 0, 0);
    excess = Max(0, this.GetVanguardCreditFact(serial, "arrears") - after);
    if excess > 0 { this.ApplyVanguardCreditArrearsPayment(serial, excess); };
    if this.GetVanguardCreditFact(serial, "arrears") == 0 { this.ClearFinanceDefaultState(id); };
    this.SetVanguardCreditFact(serial, "balance", after);
    this.SetVanguardCreditFact(serial, "cycle_amount", this.CalculateFinanceScheduledPaymentAmount(this.m_financeMonthlyPayments[i], this.GetFinancePaymentFrequency(id), Max(1, after)));
  }
  private func RecordVanguardCreditRepossession(id: TweakDBID) -> Void {
    let serial: Int32 = this.EnsureFinanceContractSerial(id);
    if this.GetVanguardCreditFact(serial, "repo_recorded") > 0 { return; };
    this.SetVanguardCreditFact(serial, "repo_recorded", 1);
    this.QueueVanguardCreditEvent(5, serial, 0, 0, this.GetFinanceRemainingBalance(id), 0, 0, 0, 0, 0, this.GetCurrentGameMinute() / 1440, 0, 0, 0, 0);
  }
  private func RemovePaidVanguardCreditContract(id: TweakDBID) -> Void {
    let wasRepossessed: Bool = this.IsVehicleRepossessed(id);
    this.RemoveFinanceContractSilent(id);

    if wasRepossessed && !ArrayContains(this.m_financeRepossessedVehicleIDs, id) {
      ArrayPush(this.m_financeRepossessedVehicleIDs, id);
      this.RemoveRepossessedVehicleFromWorld(id);
    };
  }
  private func CaptureVanguardMaturedObligations(id: TweakDBID) -> Void {
    let i: Int32 = this.GetFinanceContractIndex(id);
    let serial: Int32;
    let due: Int32;
    let interval: Int32;
    let required: Int32;
    let balance: Int32;
    let count: Int32 = 0;
    let now: Int32 = this.GetCurrentGameMinute();
    if !this.IsMarmurBankAutoFinanceAvailable() { return; };

    if i < 0 || this.IsVehicleRepossessed(id) { return; };
    serial = this.EnsureFinanceContractSerial(id);
    interval = this.GetFinancePaymentFrequencyIntervalMinutes(this.GetFinancePaymentFrequency(id));
    due = this.m_financeNextPaymentMinutes[i];

    while due <= now && count < 4096 {
      balance = this.GetFinanceRemainingBalanceByIndex(i);
      if due > this.GetVanguardCreditFact(serial, "last_due_minute") {
        required = Min(this.GetVanguardCreditFact(serial, "cycle_amount"), Max(0, balance - this.GetVanguardCreditFact(serial, "arrears")) + this.GetVanguardCreditFact(serial, "advance"));
        if required <= 0 { break; };
        this.RecordVanguardCreditDue(id, required, 0, balance, due, due + interval);
        if this.GetVanguardCreditFact(serial, "arrears") > 0 {
          this.StartFinanceDefaultState(id, this.GetVanguardCreditFact(serial, "oldest_minute"), required,
            this.GetFinanceRemainingMonths(id), this.GetFinanceTermMonthsForVehicle(id), this.GetFinanceMonthlyPaymentForVehicle(id));
        };
      };
      due += interval;
      this.m_financeNextPaymentMinutes[i] = due;
      this.SetVanguardCreditFact(serial, "cycle_amount", this.CalculateFinanceScheduledPaymentAmount(this.m_financeMonthlyPayments[i], this.GetFinancePaymentFrequency(id), Max(1, balance)));
      count += 1;
    };
  }
  private func ServiceVanguardCreditContract(id: TweakDBID, player: ref<PlayerPuppet>, lenderServicing: Bool) -> Void {
    let i: Int32 = this.GetFinanceContractIndex(id);
    let serial: Int32 = this.EnsureFinanceContractSerial(id);
    let now: Int32 = this.GetCurrentGameMinute();
    let due: Int32;
    let interval: Int32;
    let balance: Int32;
    let required: Int32;
    let cash: Int32;
    let collected: Int32;
    let arrears: Int32;
    let after: Int32;
    let count: Int32 = 0;
    let autoPay: Bool = lenderServicing && this.IsMarmurBankAutoFinanceAvailable() && this.IsFinanceAutoPayEnabled(id);
    if !lenderServicing || !this.IsMarmurBankAutoFinanceAvailable() { return; };

    if i < 0 || this.IsVehicleRepossessed(id) { return; };
    interval = this.GetFinancePaymentFrequencyIntervalMinutes(this.GetFinancePaymentFrequency(id));
    arrears = this.GetVanguardCreditFact(serial, "arrears");
    if autoPay && arrears > 0 && now < this.GetVanguardCreditFact(serial, "oldest_minute") + 10080 {
      cash = Min(arrears, this.GetFinanceRemainingBalanceByIndex(i));
      if cash > 0 && this.TryDebitFinanceAutoPay(player, id, cash) {
        after = this.GetFinanceRemainingBalanceByIndex(i) - cash;
        this.RecordVanguardCreditPayment(id, cash, after, after == 0);
        this.StoreVanguardCreditPaidAmount(i, this.GetFinancePaidAmountByIndex(i) + cash);
        this.ClearFinanceDefaultState(id);
        this.PushFinanceEventWithPaymentSource(id, after == 0 ? 4 : 2, cash, this.GetFinanceRemainingMonths(id), this.m_financeTerms[i], this.m_financeMonthlyPayments[i], this.GetFinancePaymentSource(id));
        if after == 0 { this.RemovePaidVanguardCreditContract(id); return; };
      };
    };
    due = this.m_financeNextPaymentMinutes[i];
    this.QueueFinancePaymentReminderEvents(id, due, now, this.GetVanguardCreditCashDue(id), this.m_financeRemainingMonths[i], this.m_financeTerms[i], this.m_financeMonthlyPayments[i], false, this.IsFinancePaymentDelinquent(id));
    while due <= now && count < 4 {
      balance = this.GetFinanceRemainingBalanceByIndex(i);
      if due > this.GetVanguardCreditFact(serial, "last_due_minute") {
        required = Min(this.GetVanguardCreditFact(serial, "cycle_amount"), Max(0, balance - this.GetVanguardCreditFact(serial, "arrears")) + this.GetVanguardCreditFact(serial, "advance"));
        if required <= 0 { break; };
        cash = Max(0, required - this.GetVanguardCreditFact(serial, "advance"));
        collected = 0;
        if autoPay && cash > 0 && this.GetVanguardCreditFact(serial, "arrears") == 0 {
          if this.TryDebitFinanceAutoPay(player, id, cash) { collected = cash; };
        };
        after = balance - collected;
        this.RecordVanguardCreditDue(id, required, collected, after, due, due + interval);
        if collected > 0 { this.StoreVanguardCreditPaidAmount(i, this.GetFinancePaidAmountByIndex(i) + collected); };
        if this.GetVanguardCreditFact(serial, "arrears") > 0 {
          this.StartFinanceDefaultStateWithEventKind(id, this.GetVanguardCreditFact(serial, "oldest_minute"), required,
            this.m_financeRemainingMonths[i], this.m_financeTerms[i], this.m_financeMonthlyPayments[i], autoPay ? 13 : 9);
        } else { this.ClearFinanceDefaultState(id); };
        if after <= 0 {
          this.PushFinanceEventWithPaymentSource(id, 4, collected, 0, this.m_financeTerms[i], this.m_financeMonthlyPayments[i], this.GetFinancePaymentSource(id));
          this.RemovePaidVanguardCreditContract(id);
          return;
        };
        this.m_financeRemainingMonths[i] = Max(1, (after + this.m_financeMonthlyPayments[i] - 1) / this.m_financeMonthlyPayments[i]);
        if collected > 0 { this.PushFinanceEventWithPaymentSource(id, 2, collected, this.m_financeRemainingMonths[i], this.m_financeTerms[i], this.m_financeMonthlyPayments[i], this.GetFinancePaymentSource(id)); };
      };
      due += interval;
      this.m_financeNextPaymentMinutes[i] = due;
      this.SetVanguardCreditFact(serial, "cycle_amount", this.CalculateFinanceScheduledPaymentAmount(this.m_financeMonthlyPayments[i], this.GetFinancePaymentFrequency(id), Max(1, this.GetFinanceRemainingBalanceByIndex(i))));
      count += 1;
    };
    if due <= now && count >= 4 { this.m_financeContractsDirty = true; };
  }

  public func GetActiveFinanceScheduledCashDueAt(contractIndex: Int32) -> Int32 {
    let i: Int32 = contractIndex - 1;
    let id: TweakDBID;
    let serial: Int32;
    let arrears: Int32;
    if i < 0 || i >= ArraySize(this.m_financeVehicleIDs) { return 0; };
    id = this.m_financeVehicleIDs[i];
    serial = this.EnsureFinanceContractSerial(id);
    if this.GetVanguardCreditFact(serial, "registered") == 0 { return this.GetFinanceScheduledPaymentAmountByIndex(i); };
    arrears = this.GetVanguardCreditFact(serial, "arrears");
    return arrears > 0 ? Min(arrears, this.GetFinanceRemainingBalanceByIndex(i)) : this.GetVanguardCreditCashDue(id);
  }

  public func GetActiveFinanceNextDueDayAt(contractIndex: Int32) -> Int32 {
    let i: Int32 = contractIndex - 1;
    if i < 0 || i >= ArraySize(this.m_financeNextPaymentMinutes) { return 0; };
    return this.m_financeNextPaymentMinutes[i] / 1440;
  }

  public func GetActiveFinancePastDueAmountAt(contractIndex: Int32) -> Int32 {
    let i: Int32 = contractIndex - 1;
    let serial: Int32;
    if i < 0 || i >= ArraySize(this.m_financeVehicleIDs) { return 0; };
    serial = this.EnsureFinanceContractSerial(this.m_financeVehicleIDs[i]);
    if this.GetVanguardCreditFact(serial, "registered") == 0 && this.IsFinancePaymentDelinquent(this.m_financeVehicleIDs[i]) {
      return this.GetFinanceScheduledPaymentAmountByIndex(i);
    };
    return this.GetVanguardCreditFact(serial, "arrears");
  }

  public func GetActiveFinanceOldestUnpaidDueDayAt(contractIndex: Int32) -> Int32 {
    let i: Int32 = contractIndex - 1;
    let serial: Int32;
    let d: Int32;
    if i < 0 || i >= ArraySize(this.m_financeVehicleIDs) { return 0; };
    serial = this.EnsureFinanceContractSerial(this.m_financeVehicleIDs[i]);
    if this.GetVanguardCreditFact(serial, "registered") == 0 {
      d = this.GetFinanceDefaultIndex(this.m_financeVehicleIDs[i]);
      if d >= 0 { return this.m_financeDefaultStartMinutes[d] / 1440; };
    };
    return this.GetVanguardCreditFact(serial, "oldest_minute") / 1440;
  }

  private persistent let m_odometerIDs: array<TweakDBID>;

  private persistent let m_odometerMeters: array<Double>;

  private let m_odometerSession: Int32;

  private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void {
    this.m_odometerSession = 0;
    this.m_marmurFinancialCreditReady = false;
  }

  public func GetOdometerSession() -> Int32 {
    if this.m_odometerSession == 0 { this.m_odometerSession = RandRange(1, 2000000000); };
    return this.m_odometerSession;
  }

  public func GetOdometerMeters(id: TweakDBID) -> Double {
    let index: Int32 = ArrayFindFirst(this.m_odometerIDs, this.GetCanonicalVehicleRecordID(id));
    if index < 0 || index >= ArraySize(this.m_odometerMeters) { return Cast<Double>(0.0); };
    return this.m_odometerMeters[index];
  }

  public func StoreOdometerMeters(id: TweakDBID, meters: Double) -> Bool {
    let canonical: TweakDBID = this.GetCanonicalVehicleRecordID(id);
    let index: Int32;
    if !TDBID.IsValid(canonical) || !IsDefined(TweakDBInterface.GetVehicleRecord(canonical))
      || !(meters >= Cast<Double>(0.0) && meters <= Cast<Double>(1000000000.0)) { return false; };
    index = ArrayFindFirst(this.m_odometerIDs, canonical);
    if index < 0 {
      ArrayPush(this.m_odometerIDs, canonical);
      ArrayPush(this.m_odometerMeters, meters);
    } else {

      if meters > this.m_odometerMeters[index] { this.m_odometerMeters[index] = meters; };
    };
    return true;
  }

  public func GetOdometerGarageIDs() -> array<TweakDBID> {
    let result: array<TweakDBID>;
    let vehicles: array<PlayerVehicle>;
    let canonical: TweakDBID;
    if !IsDefined(this.m_vehicleSystem) { return result; };
    this.m_vehicleSystem.GetPlayerUnlockedVehicles(vehicles);
    for persistentVehicle in GetPersistentVehicles(this.GetGameInstance()) {
      ArrayPush(vehicles, persistentVehicle);
    };
    for vehicle in vehicles {
      canonical = this.GetCanonicalVehicleRecordID(vehicle.recordID);
      if TDBID.IsValid(canonical) && !ArrayContains(result, canonical)
        && !ArrayContains(this.m_soldVehicles, vehicle.recordID)
        && !ArrayContains(this.m_soldVehicles, canonical) {
        ArrayPush(result, canonical);
      };
    };
    return result;
  }

  public func GetMileageAdjustedValue(id: TweakDBID, baseValue: Int32) -> Int32 {

    let retention: Float = MaxF(0.40, 1.0 - Cast<Float>(this.GetOdometerMeters(id)) / 160934400.0);
    return Max(0, Cast<Int32>(Cast<Float>(Max(0, baseValue)) * retention));
  }

  public static func FormatOdometer(meters: Double) -> String {
    let deciMiles: Int32 = Cast<Int32>(meters / Cast<Double>(160.9344) + Cast<Double>(0.5));
    return IntToString(deciMiles / 10) + "." + IntToString(deciMiles % 10) + " MI";
  }

  public func GetOwnedVehiclesData() -> array<ref<AutofixerItemData>> {
    let result: array<ref<AutofixerItemData>> = this.GetOwnedVehiclesDataBase();
    for item in result {
      item.odometerMeters = this.GetOdometerMeters(item.vehicleID);
      item.price = this.GetMileageAdjustedValue(item.vehicleID, item.price);
    };
    return result;
  }

  public func SellOwnedVehicle(player: ref<GameObject>, data: ref<AutofixerItemData>) -> Void {
    let fresh: array<ref<AutofixerItemData>>;
    if !IsDefined(player) || !IsDefined(data) { return; };
    fresh = this.GetOwnedVehiclesData();
    for item in fresh {
      if Equals(item.vehicleID, data.vehicleID) {

        this.SellOwnedVehicleBase(player, item);
        return;
      };
    };
  }

  public let m_storeVehicles: array<ref<PurchasableVehicleBundle>>;

  public let m_nextBrowserLandingState: Int32 = 7;

  public let m_vehicleSystem: ref<VehicleSystem>;

  public let m_transactionSystem: ref<TransactionSystem>;

  private let m_marmurOwnedVehicleSnapshot: array<ref<AutofixerItemData>>;

  public let m_sellPriceModifier: Float = 0.25;

  public let m_fallbackPrice: Int32 = 40000;

  private persistent let m_soldVehicles: array<TweakDBID>;

  private let m_soldVehicleLedgerRevision: Int32;

  private persistent let m_pendingVehicleIDs: array<TweakDBID>;

  private persistent let m_pendingModes: array<Int32>;

  private persistent let m_pendingReadyTimes: array<Int32>;

  private persistent let m_followupVehicleIDs: array<TweakDBID>;

  private persistent let m_followupModes: array<Int32>;

  private persistent let m_followupTimes: array<Int32>;

  private persistent let m_saleFollowupVehicleIDs: array<TweakDBID>;

  private persistent let m_saleFollowupTimes: array<Int32>;

  private persistent let m_readyVehicleIDs: array<TweakDBID>;

  private persistent let m_readyModes: array<Int32>;

  private persistent let m_readyReleaseTimes: array<Int32>;

  private persistent let m_dealershipPurchases: Int32;

  private persistent let m_dealershipSales: Int32;

  private persistent let m_lastSaleMinute: Int32;

  private persistent let m_financeVehicleIDs: array<TweakDBID>;

  private persistent let m_financeTerms: array<Int32>;

  private persistent let m_financeMonthlyPayments: array<Int32>;

  private persistent let m_financeRemainingMonths: array<Int32>;

  private persistent let m_financeNextPaymentMinutes: array<Int32>;

  private persistent let m_financeTotalDue: array<Int32>;

  private persistent let m_financeDownPayments: array<Int32>;

  private persistent let m_financeInterestPercents: array<Int32>;

  private persistent let m_financePaidAmounts: array<Int32>;

  private persistent let m_financeStreetCredVehicleIDs: array<TweakDBID>;

  private persistent let m_financeOriginalStreetCredLevels: array<Int32>;

  private persistent let m_financePaymentFrequencyVehicleIDs: array<TweakDBID>;

  private persistent let m_financePaymentFrequencies: array<Int32>;

  private persistent let m_financeAutoPayVehicleIDs: array<TweakDBID>;

  private persistent let m_financeAutoPayEnabled: array<Bool>;

  private persistent let m_financePaymentSourceVehicleIDs: array<TweakDBID>;

  private persistent let m_financePaymentSources: array<Int32>;

  private persistent let m_financeContractSerialVehicleIDs: array<TweakDBID>;

  private persistent let m_financeContractSerials: array<Int32>;

  private persistent let m_financeContractSerialSequence: Int32;

  private persistent let m_coverageVehicleIDs: array<TweakDBID>;

  private let m_coverageRuntimeAliasVehicleIDs: array<TweakDBID>;

  private let m_coverageRuntimeAliasPolicyIDs: array<TweakDBID>;

  private persistent let m_coverageDeductibleOption: Int32;

  private persistent let m_coveragePaymentFrequency: Int32;

  private persistent let m_coverageTermMonths: Int32;

  private persistent let m_coveragePolicySerial: Int32;

  private persistent let m_coverageTermStartMinute: Int32;

  private persistent let m_coverageTermEndMinute: Int32;

  private persistent let m_coverageLastTermPremium: Int32;

  private persistent let m_coverageLastPaymentAmount: Int32;

  private persistent let m_coverageAtFaultSurchargeBasisPoints: Int32;

  private persistent let m_coverageAtFaultAccidentCount: Int32;

  private persistent let m_coverageLastAccidentMinute: Int32;

  private persistent let m_coverageGoodDriverStartMinute: Int32;

  private persistent let m_coverageGoodDriverRewardedTermStartMinute: Int32;

  private persistent let m_coverageGoodDriverRewardedStartMinute: Int32;

  private persistent let m_coverageGoodDriverRewardedVersion: Int32;

  private persistent let m_coverageGoodDriverRefundIssuedThisTerm: Bool;

  private persistent let m_coverageTotalLossVehicleIDs: array<TweakDBID>;

  private persistent let m_uninsuredDestroyedVehicleIDs: array<TweakDBID>;

  private persistent let m_coverageTotalLossClaimNumbers: array<Int32>;

  private persistent let m_coverageTotalLossValues: array<Int32>;

  private persistent let m_coverageTotalLossDeductibles: array<Int32>;

  private persistent let m_coverageTotalLossSettlements: array<Int32>;

  private persistent let m_coverageTotalLossLoanBalances: array<Int32>;

  private persistent let m_coverageTotalLossBankPayments: array<Int32>;

  private persistent let m_coverageTotalLossPlayerDeposits: array<Int32>;

  private persistent let m_coverageTotalLossRemainingLoans: array<Int32>;

  private persistent let m_coverageTotalLossIssuedMinutes: array<Int32>;

  private persistent let m_coverageTotalLossStatuses: array<Int32>;

  private persistent let m_coverageLastTotalLossSettlementMinute: Int32;
  private persistent let m_coverageLastTotalLossDenialMinute: Int32;

  private persistent let m_coverageFraudStrikeCount: Int32;
  private persistent let m_coverageFraudSuspensionExpirationMinute: Int32;
  private persistent let m_coverageFraudPermanentlyTerminated: Bool;
  private persistent let m_coverageFraudLastIncidentMinute: Int32;
  private persistent let m_coverageFraudLastVehicleID: TweakDBID;
  private persistent let m_coverageFraudLastCause: Int32;
  private persistent let m_coverageFraudTerminatedPolicySerial: Int32;
  private persistent let m_coverageFraudSuspensionCompletionNotified: Bool;

  private persistent let m_coverageFraudDestroyedVehicleIDs: array<TweakDBID>;

  private let m_coverageFraudExclusionMigrationRunning: Bool;
  private let m_coverageFraudExclusionMigrationComplete: Bool;

  private let m_coverageLastAdjudicationClaimCreated: Bool;

  private persistent let m_coverageTotalLossDespawnRequestClaimNumbers: array<Int32>;

  private persistent let m_coverageTotalLossDespawnQueueVersion: Int32;

  private persistent let m_financeDefaultVehicleIDs: array<TweakDBID>;

  private persistent let m_financeDefaultStartMinutes: array<Int32>;

  private persistent let m_financeRepossessedVehicleIDs: array<TweakDBID>;

  private persistent let m_promoAlertsDisabled: Bool;
  private persistent let m_vanguardAlertsRevision: Int32;

  private persistent let m_selectedPromotionCode: Int32;

  private persistent let m_promoAlertEventKinds: array<Int32>;

  private persistent let m_promoAlertEventMinutes: array<Int32>;

  private persistent let m_financeEventVehicleIDs: array<TweakDBID>;

  private persistent let m_financeEventKinds: array<Int32>;

  private persistent let m_financeEventMinutes: array<Int32>;

  private persistent let m_financeEventAmounts: array<Int32>;

  private persistent let m_financeEventRemainingMonths: array<Int32>;

  private persistent let m_financeEventTerms: array<Int32>;

  private persistent let m_financeEventMonthlyPayments: array<Int32>;

  private persistent let m_financeEventPaymentSources: array<Int32>;

  private persistent let m_ncgtAppreciationVehicleIDs: array<TweakDBID>;

  private persistent let m_ncgtAppreciationPurchasePrices: array<Int32>;

  private persistent let m_ncgtAppreciationDiscountBps: array<Int32>;

  private persistent let m_ncgtAppreciationSerials: array<Int32>;

  private persistent let m_ncgtAppreciationFinanced: array<Bool>;

  private persistent let m_ncgtAppreciationIssueMinutes: array<Int32>;

  private persistent let m_ncgtAppreciationSequence: Int32;

  private persistent let m_ncgtAppreciationLastCommittedVehicleID: TweakDBID;

  private persistent let m_ncgtAppreciationLastCommittedSerial: Int32;

  private persistent let m_ncgtAppreciationLastCommittedCheckoutToken: Int32;

  private persistent let m_ncgtAppreciationLastCommittedSavings: Int32;

  private persistent let m_ncgtAppreciationLastCommittedMinute: Int32;

  private let m_ncgtAppreciationIntegrationAvailable: Bool;

  private let m_ncgtAppreciationIntegrationAPIVersion: Int32;

  private let m_ncgtAppreciationIntegrationHeartbeatAt: Float;

  private let m_ncgtAppreciationNoticePendingVehicleID: TweakDBID;

  private let m_ncgtAppreciationNoticePendingSerial: Int32;

  private let m_marmurBankAutoFinanceIntegrationAvailable: Bool;

  private let m_marmurBankAutoFinanceIntegrationAPIVersion: Int32;

  private let m_marmurBankAutoFinanceIntegrationHeartbeatAt: Float;

  private let m_marmurBankAutoFinanceLeaseObservedThisSession: Bool;

  private let m_marmurBankAutoFinanceStartupGraceUntil: Float;

  private persistent let m_ncgtAppreciationReservedVehicleID: TweakDBID;

  private persistent let m_ncgtAppreciationReservedSerial: Int32;

  private persistent let m_ncgtAppreciationReservedCheckoutToken: Int32;

  private persistent let m_ncgtAppreciationReservedParentRevision: Int32;

  private persistent let m_ncgtAppreciationReservedSavings: Int32;

  private let m_ncgtPerformanceIntegrationAvailable: Bool;

  private let m_ncgtPerformanceIntegrationAPIVersion: Int32;

  private let m_ncgtPerformanceIntegrationHeartbeatAt: Float;

  private persistent let m_ncgtPerformanceVehicleIDs: array<TweakDBID>;

  private persistent let m_ncgtPerformanceVehicleClasses: array<Int32>;

  private persistent let m_ncgtPerformancePackageCodes: array<Int32>;

  private persistent let m_ncgtPerformancePartsSubtotals: array<Int32>;

  private persistent let m_ncgtPerformanceLaborTotals: array<Int32>;

  private persistent let m_ncgtPerformanceVoucherBps: array<Int32>;

  private persistent let m_ncgtPerformanceDiscounts: array<Int32>;

  private persistent let m_ncgtPerformanceFinalTotals: array<Int32>;

  private persistent let m_ncgtPerformancePaymentModes: array<Int32>;

  private persistent let m_ncgtPerformanceTransactionStates: array<Int32>;

  private persistent let m_ncgtPerformanceSerials: array<Int32>;

  private persistent let m_ncgtPerformanceInstalledRevisions: array<Int32>;

  private persistent let m_ncgtPerformanceFailureCodes: array<Int32>;

  private persistent let m_ncgtPerformanceVehiclePrices: array<Int32>;

  private persistent let m_ncgtPerformanceFinanced: array<Bool>;

  private persistent let m_ncgtPerformanceRollbackRefunds: array<Int32>;

  private persistent let m_ncgtPerformanceRollbackFinanceTotals: array<Int32>;

  private persistent let m_ncgtPerformanceRollbackFinanceMonthly: array<Int32>;

  private persistent let m_ncgtPerformanceRollbackFinanceDownPayments: array<Int32>;

  private persistent let m_ncgtPerformanceSequence: Int32;

  private persistent let m_financeNoticeVehicleIDs: array<TweakDBID>;

  private persistent let m_financeNoticeKinds: array<Int32>;

  private persistent let m_financeNoticeCycleMinutes: array<Int32>;

  private persistent let m_lastPromoCampaignAlertMinute: Int32;

  private persistent let m_lastPromoCampaignAlertCode: Int32;

  private persistent let m_vanguardPhoneMessageKinds: array<Int32>;
  private persistent let m_vanguardPhoneMessageVehicleIDs: array<TweakDBID>;
  private persistent let m_vanguardPhoneMessageAmounts: array<Int32>;
  private persistent let m_vanguardPhoneMessageAux1: array<Int32>;
  private persistent let m_vanguardPhoneMessageAux2: array<Int32>;
  private persistent let m_vanguardPhoneMessageMinutes: array<Int32>;
  private persistent let m_vanguardPhoneUnreadCount: Int32;
  private persistent let m_vanguardPhoneDeliveredCount: Int32;
  private persistent let m_vanguardLastPhoneMessageKind: Int32;
  private persistent let m_vanguardLastPhoneMessageVehicleID: TweakDBID;
  private persistent let m_vanguardLastPhoneMessageAmount: Int32;
  private persistent let m_vanguardLastPhoneMessageAux1: Int32;
  private persistent let m_vanguardLastPhoneMessageAux2: Int32;
  private persistent let m_vanguardLastPhoneMessageMinute: Int32;

  private persistent let m_vanguardDeferredPhoneMessageKinds: array<Int32>;
  private persistent let m_vanguardDeferredPhoneMessageVehicleIDs: array<TweakDBID>;
  private persistent let m_vanguardDeferredPhoneMessageAmounts: array<Int32>;
  private persistent let m_vanguardDeferredPhoneMessageAux1: array<Int32>;
  private persistent let m_vanguardDeferredPhoneMessageAux2: array<Int32>;
  private persistent let m_vanguardDeferredPhoneMessageMinutes: array<Int32>;

  private let m_vanguardDeliveryRequestPending: Bool;
  private let m_vanguardDeliveryRequestVehicleID: TweakDBID;
  private let m_vanguardDeliveryRequestLocation: Int32;
  private let m_vanguardDeliveryRequestSequence: Int32;
  private let m_vanguardDeliveryLastStatus: Int32;

  private let m_pendingOrdersResolved: Bool;
  private let m_deactivateVehiclesDirty: Bool;
  private let m_lastDeactivateSoldVehiclesMinute: Int32;
  private let m_lastFinanceUpdateMinute: Int32;
  private let m_lastFinanceUpdateContractCount: Int32;
  private let m_financeContractsDirty: Bool;
  private let m_lastPromoCampaignScanMinute: Int32;

  private let m_uninstalledVehicleReconcileRunning: Bool;

  private let m_uninstalledVehicleReconcileComplete: Bool;

  private let m_hasUninstalledVehicleReconcileMinute: Bool;

  private let m_lastUninstalledVehicleReconcileMinute: Int32;

  private persistent let m_uninstalledVehicleRetirementIDs: array<TweakDBID>;

  public final static func GetInstance(gameInstance: GameInstance) -> ref<PurchasableVehicleSystem> {
    let system: ref<PurchasableVehicleSystem> = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(n"CarDealer.System.PurchasableVehicleSystem") as PurchasableVehicleSystem;
    return system;
  }

  public func QueueVanguardDeliveryRequest(id: TweakDBID, locationCode: Int32) -> Bool {
    let normalizedLocationCode: Int32 = locationCode;

    if !this.IsInstalledVehicleRecord(id) {
      return false;
    };

    if normalizedLocationCode <= 0 {
      normalizedLocationCode = 1;
    };

    this.m_vanguardDeliveryRequestVehicleID = id;
    this.m_vanguardDeliveryRequestLocation = normalizedLocationCode;
    this.m_vanguardDeliveryRequestSequence += 1;
    if this.m_vanguardDeliveryRequestSequence <= 0 {
      this.m_vanguardDeliveryRequestSequence = 1;
    };
    this.m_vanguardDeliveryRequestPending = true;
    this.m_vanguardDeliveryLastStatus = 0;

    SetFactValue(this.GetGameInstance(), n"vanguard_auto_delivery_request", this.m_vanguardDeliveryRequestSequence);
    SetFactValue(this.GetGameInstance(), n"vanguard_auto_delivery_location", normalizedLocationCode);
    SetFactValue(this.GetGameInstance(), n"vanguard_auto_delivery_status", 0);
    return true;
  }

  public func HasVanguardDeliveryRequest() -> Bool {
    return this.m_vanguardDeliveryRequestPending;
  }

  public func GetVanguardDeliveryRequestSequence() -> Int32 {
    return this.m_vanguardDeliveryRequestSequence;
  }

  public func GetVanguardDeliveryRequestLocation() -> Int32 {
    return this.m_vanguardDeliveryRequestLocation;
  }

  public func GetVanguardDeliveryLastStatus() -> Int32 {
    return this.m_vanguardDeliveryLastStatus;
  }

  public func GetVanguardDeliveryRequestVehicleRecord() -> String {
    if !this.m_vanguardDeliveryRequestPending || !TDBID.IsValid(this.m_vanguardDeliveryRequestVehicleID) {
      return "";
    };

    return TDBID.ToStringDEBUG(this.m_vanguardDeliveryRequestVehicleID);
  }

  public func GetVanguardDeliveryRequestVehicleID() -> TweakDBID {
    if !this.m_vanguardDeliveryRequestPending || !TDBID.IsValid(this.m_vanguardDeliveryRequestVehicleID) {
      return TDBID.Create("");
    };

    return this.m_vanguardDeliveryRequestVehicleID;
  }

  public func ClearVanguardDeliveryRequest(sequence: Int32, status: Int32) -> Void {
    if sequence <= 0 || sequence == this.m_vanguardDeliveryRequestSequence {
      this.m_vanguardDeliveryRequestPending = false;
      this.m_vanguardDeliveryLastStatus = status;
      this.m_vanguardDeliveryRequestVehicleID = TDBID.Create("");
      SetFactValue(this.GetGameInstance(), n"vanguard_auto_delivery_request", 0);
      SetFactValue(this.GetGameInstance(), n"vanguard_auto_delivery_status", status);
    };
  }

  private func OnPlayerAttach(request: ref<PlayerAttachRequest>) {

    if GameInstance.GetSystemRequestsHandler().IsPreGame() {
      return ;
    };

    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(request.owner.GetGame()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if IsDefined(player) {
      this.m_vehicleSystem = GameInstance.GetVehicleSystem(player.GetGame());
      this.m_transactionSystem = GameInstance.GetTransactionSystem(player.GetGame());
      this.m_uninstalledVehicleReconcileRunning = false;
      this.m_uninstalledVehicleReconcileComplete = false;
      this.m_hasUninstalledVehicleReconcileMinute = false;
      this.m_lastUninstalledVehicleReconcileMinute = 0;
      this.AdvanceSoldVehicleLedgerRevision();
      this.PopulateVehicleList();
      this.InitializeVanguardCreditContracts();
      this.ReconcileUninstalledVehicles();
      this.m_deactivateVehiclesDirty = true;
      this.m_financeContractsDirty = true;
      this.m_marmurBankAutoFinanceLeaseObservedThisSession = false;
      this.m_marmurBankAutoFinanceStartupGraceUntil = EngineTime.ToFloat(
        GameInstance.GetEngineTime(this.GetGameInstance())
      ) + 5.00;
      this.m_pendingOrdersResolved = false;

      this.m_coverageFraudExclusionMigrationComplete = false;
      this.DeactivateSoldVehicles();
      this.ResolveLegacyReleaseOrders();
      this.m_pendingOrdersResolved = true;
      this.UpdateFinanceContracts(player);
      this.PurgeExpiredNCGTAppreciationVouchers();
      this.AlignVanguardCoverageTotalLossClaimArrays();
      this.RecoverVanguardCoverageLegacyFailedInsuredTotalLossClaims();
      this.RepairVanguardCoverageTotalLossDespawnRequests();
      this.RefreshVanguardCoverageFraudAccountState();

    };
  }

  private func IsRecordUnlockedForPlayer(id: TweakDBID) -> Bool {
    let unlocked: array<PlayerVehicle>;

    if !IsDefined(this.m_vehicleSystem) || !TDBID.IsValid(id) {
      return false;
    };
    this.m_vehicleSystem.GetPlayerUnlockedVehicles(unlocked);
    for vehicle in unlocked {
      if Equals(vehicle.recordID, id) {
        return true;
      };
    };
    return false;
  }

  // A model that is on the sold list but currently unlocked was re-acquired outside Vanguard (Midnight
  // Acquisition, steal, ...). The live entity's IsPlayerVehicle() stays false for those, so test the unlock.
  public func ClaimSoldVehicleIfUnlocked(id: TweakDBID) -> Void {
    if TDBID.IsValid(id) && ArrayContains(this.m_soldVehicles, id) && this.IsRecordUnlockedForPlayer(id) {
      this.MarkExternalVehicleClaimed(id);
    };
  }

  private func ClaimMountedSoldVehicle() -> Void {
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    let vehicle: ref<VehicleObject>;

    if !IsDefined(player) {
      return;
    };
    vehicle = GetMountedVehicle(player) as VehicleObject;
    if !IsDefined(vehicle) || vehicle.GetVehiclePS().GetIsDestroyed() {
      return;
    };
    this.ClaimSoldVehicleIfUnlocked(vehicle.GetRecordID());
  }

  public func DeactivateSoldVehicles() -> Void {
    let soldCount: Int32 = ArraySize(this.m_soldVehicles);
    let repossessedCount: Int32 = ArraySize(this.m_financeRepossessedVehicleIDs);
    let now: Int32;

    if soldCount <= 0 && repossessedCount <= 0 {
      this.m_deactivateVehiclesDirty = false;
      return;
    };

    now = this.GetCurrentGameMinute();
    if !this.m_deactivateVehiclesDirty && now > 0 && now == this.m_lastDeactivateSoldVehiclesMinute {
      return;
    };

    this.m_lastDeactivateSoldVehiclesMinute = now;
    this.m_deactivateVehiclesDirty = false;

    this.ClaimMountedSoldVehicle();

    for id in this.m_soldVehicles {
      RemoveVehicle(this.GetGameInstance(), this.m_vehicleSystem, id);
    };

    for id in this.m_financeRepossessedVehicleIDs {
      this.RemoveRepossessedVehicleFromWorld(id);
    };
  }

  private func ResolveLegacyReleaseOrders() -> Void {
    let i: Int32 = 0;

    while i < ArraySize(this.m_pendingVehicleIDs) {
      this.Purchase(this.m_pendingVehicleIDs[i]);
      i += 1;
    };

    i = 0;
    while i < ArraySize(this.m_readyVehicleIDs) {
      this.Purchase(this.m_readyVehicleIDs[i]);
      i += 1;
    };

    ArrayClear(this.m_pendingVehicleIDs);
    ArrayClear(this.m_pendingModes);
    ArrayClear(this.m_pendingReadyTimes);
    ArrayClear(this.m_readyVehicleIDs);
    ArrayClear(this.m_readyModes);
    ArrayClear(this.m_readyReleaseTimes);
  }

  private func CreateDealerBundle(currentRecord: ref<Vehicle_Record>, currentId: TweakDBID) -> ref<PurchasableVehicleBundle> {
    let currentCred: Int32;
    let currentPrice: Int32;
    let dealerVariants: array<String>;
    let vehicleVariantIds: array<TweakDBID>;
    let detectedVariants: array<ref<PurchasableVehicleVariant>>;
    let currentVariantRecord: ref<Vehicle_Record>;
    let newBundle: ref<PurchasableVehicleBundle>;
    let newVariant: ref<PurchasableVehicleVariant>;

    if !IsDefined(currentRecord) || !TDBID.IsValid(currentId) {
      return null;
    };

    currentCred = 0;
    currentPrice = TweakDBInterface.GetInt(currentId + t".dealerPrice", 0);

    if Equals(currentPrice, 0) {
      return null;
    };

    newBundle = new PurchasableVehicleBundle();
    newBundle.cred = currentCred;
    newBundle.price = currentPrice;

    dealerVariants = TweakDBInterface.GetStringArray(currentId + t".dealerVariants");
    vehicleVariantIds = this.GetTDBIDs(dealerVariants);
    if Equals(ArraySize(vehicleVariantIds), 0) {
      ArrayPush(vehicleVariantIds, currentId);
    };

    for currentVehicleVariantId in vehicleVariantIds {
      currentVariantRecord = TweakDBInterface.GetVehicleRecord(currentVehicleVariantId) as Vehicle_Record;
      if IsDefined(currentVariantRecord) {
        newVariant = new PurchasableVehicleVariant();
        newVariant.record = currentVariantRecord;
        newVariant.dealerAtlasPath = ResRef.FromString(TweakDBInterface.GetString(currentVehicleVariantId + t".dealerAtlasPath", ""));
        newVariant.dealerPartName = StringToName(TweakDBInterface.GetString(currentVehicleVariantId + t".dealerPartName", ""));
        ArrayPush(detectedVariants, newVariant);
      } else {
      };
    };

    if Equals(ArraySize(detectedVariants), 0) {
      return null;
    };

    newBundle.variants = detectedVariants;
    return newBundle;
  }

  private func GetKnownCompatibilityVehicleIDs() -> array<TweakDBID> {
    let result: array<TweakDBID>;

    ArrayPush(result, TDBID.Create("Vehicle.av_rayfield_excalibur_dav_dummy"));
    ArrayPush(result, TDBID.Create("Vehicle.av_militech_manticore_dav_dummy"));
    ArrayPush(result, TDBID.Create("Vehicle.av_zetatech_atlus_dav_dummy"));
    ArrayPush(result, TDBID.Create("Vehicle.av_zetatech_surveyor_dav_dummy"));
    ArrayPush(result, TDBID.Create("Vehicle.q000_nomad_border_patrol_heli_dav_dummy"));
    ArrayPush(result, TDBID.Create("Vehicle.q000_nomad_border_patrol_heli_mayhem_dav_dummy"));

    ArrayPush(result, TDBID.Create("Vehicle.basilisk_aldecaldos"));
    ArrayPush(result, TDBID.Create("Vehicle.basilisk_militech"));

    ArrayPush(result, TDBID.Create("Vehicle.quadra_unbound_purchasable"));

    return result;
  }

  private func PopulateVehicleList() -> Void {
    let result: array<ref<PurchasableVehicleBundle>>;
    let seenVehicleIDs: array<TweakDBID>;
    let newBundle: ref<PurchasableVehicleBundle>;

    for record in TweakDBInterface.GetRecords(n"Vehicle") {
      let currentRecord: ref<Vehicle_Record> = record as Vehicle_Record;
      if IsDefined(currentRecord) {
        let currentId: TweakDBID = currentRecord.GetID();
        newBundle = this.CreateDealerBundle(currentRecord, currentId);
        if IsDefined(newBundle) {
          ArrayPush(seenVehicleIDs, currentId);
          ArrayPush(result, newBundle);
        };
      };
    };

    let compatibilityVehicleIDs: array<TweakDBID> = this.GetKnownCompatibilityVehicleIDs();
    for compatibilityId in compatibilityVehicleIDs {
      if TDBID.IsValid(compatibilityId) && !ArrayContains(seenVehicleIDs, compatibilityId) {
        let compatibilityRecord: ref<Vehicle_Record> = TweakDBInterface.GetVehicleRecord(compatibilityId) as Vehicle_Record;
        newBundle = this.CreateDealerBundle(compatibilityRecord, compatibilityId);
        if IsDefined(newBundle) {
          ArrayPush(seenVehicleIDs, compatibilityId);
          ArrayPush(result, newBundle);
        };
      };
    };

    this.m_storeVehicles = result;
  }

  public func IsInstalledVehicleRecord(id: TweakDBID) -> Bool {
    if !TDBID.IsValid(id) {
      return false;
    };

    return IsDefined(TweakDBInterface.GetVehicleRecord(id));
  }

  private func CollectUninstalledVehicleCandidates(source: array<TweakDBID>, candidates: array<TweakDBID>) -> array<TweakDBID> {
    for id in source {
      if !this.IsInstalledVehicleRecord(id) && !ArrayContains(candidates, id) {
        ArrayPush(candidates, id);
      };
    };

    return candidates;
  }

  private func CollectUninstalledVehicleCandidate(id: TweakDBID, candidates: array<TweakDBID>) -> array<TweakDBID> {
    if TDBID.IsValid(id) && !this.IsInstalledVehicleRecord(id) && !ArrayContains(candidates, id) {
      ArrayPush(candidates, id);
    };

    return candidates;
  }

  private func RemoveVehicleFromLegacyOrderState(id: TweakDBID) -> Void {
    let i: Int32 = ArraySize(this.m_pendingVehicleIDs) - 1;

    while i >= 0 {
      if Equals(this.m_pendingVehicleIDs[i], id) {
        ArrayErase(this.m_pendingVehicleIDs, i);
        if i < ArraySize(this.m_pendingModes) { ArrayErase(this.m_pendingModes, i); };
        if i < ArraySize(this.m_pendingReadyTimes) { ArrayErase(this.m_pendingReadyTimes, i); };
      };
      i -= 1;
    };

    i = ArraySize(this.m_readyVehicleIDs) - 1;
    while i >= 0 {
      if Equals(this.m_readyVehicleIDs[i], id) {
        ArrayErase(this.m_readyVehicleIDs, i);
        if i < ArraySize(this.m_readyModes) { ArrayErase(this.m_readyModes, i); };
        if i < ArraySize(this.m_readyReleaseTimes) { ArrayErase(this.m_readyReleaseTimes, i); };
      };
      i -= 1;
    };
  }

  private func RemoveVehicleFromFinanceSerialState(id: TweakDBID) -> Void {
    let i: Int32 = ArraySize(this.m_financeContractSerialVehicleIDs) - 1;

    while i >= 0 {
      if Equals(this.m_financeContractSerialVehicleIDs[i], id) {
        ArrayErase(this.m_financeContractSerialVehicleIDs, i);
        if i < ArraySize(this.m_financeContractSerials) { ArrayErase(this.m_financeContractSerials, i); };
      };
      i -= 1;
    };
  }

  private func RemoveVehicleFromFinanceEventState(id: TweakDBID) -> Void {

    return;
  }

  private func RemoveVehicleFromCoverageTotalLossState(id: TweakDBID) -> Void {
    let claimNumber: Int32;
    let i: Int32;
    let j: Int32;

    this.AlignVanguardCoverageTotalLossClaimArrays();
    i = ArraySize(this.m_coverageTotalLossVehicleIDs) - 1;
    while i >= 0 {
      if Equals(this.m_coverageTotalLossVehicleIDs[i], id) || this.VanguardCoverageIDsMatch(this.m_coverageTotalLossVehicleIDs[i], id) {
        claimNumber = i < ArraySize(this.m_coverageTotalLossClaimNumbers) ? this.m_coverageTotalLossClaimNumbers[i] : 0;
        ArrayErase(this.m_coverageTotalLossVehicleIDs, i);
        if i < ArraySize(this.m_coverageTotalLossClaimNumbers) { ArrayErase(this.m_coverageTotalLossClaimNumbers, i); };
        if i < ArraySize(this.m_coverageTotalLossValues) { ArrayErase(this.m_coverageTotalLossValues, i); };
        if i < ArraySize(this.m_coverageTotalLossDeductibles) { ArrayErase(this.m_coverageTotalLossDeductibles, i); };
        if i < ArraySize(this.m_coverageTotalLossSettlements) { ArrayErase(this.m_coverageTotalLossSettlements, i); };
        if i < ArraySize(this.m_coverageTotalLossLoanBalances) { ArrayErase(this.m_coverageTotalLossLoanBalances, i); };
        if i < ArraySize(this.m_coverageTotalLossBankPayments) { ArrayErase(this.m_coverageTotalLossBankPayments, i); };
        if i < ArraySize(this.m_coverageTotalLossPlayerDeposits) { ArrayErase(this.m_coverageTotalLossPlayerDeposits, i); };
        if i < ArraySize(this.m_coverageTotalLossRemainingLoans) { ArrayErase(this.m_coverageTotalLossRemainingLoans, i); };
        if i < ArraySize(this.m_coverageTotalLossIssuedMinutes) { ArrayErase(this.m_coverageTotalLossIssuedMinutes, i); };
        if i < ArraySize(this.m_coverageTotalLossStatuses) { ArrayErase(this.m_coverageTotalLossStatuses, i); };

        if claimNumber > 0 {
          j = ArraySize(this.m_coverageTotalLossDespawnRequestClaimNumbers) - 1;
          while j >= 0 {
            if this.m_coverageTotalLossDespawnRequestClaimNumbers[j] == claimNumber {
              ArrayErase(this.m_coverageTotalLossDespawnRequestClaimNumbers, j);
            };
            j -= 1;
          };
        };
      };
      i -= 1;
    };

    this.RepairVanguardCoverageTotalLossDespawnRequests();
  }

  private func RemoveVehicleFromPhoneHistory(id: TweakDBID) -> Void {
    let originalCount: Int32;
    let originalUnreadStart: Int32;
    let i: Int32;

    this.NormalizeVanguardPhoneHistoryArrays();
    originalCount = ArraySize(this.m_vanguardPhoneMessageKinds);
    originalUnreadStart = Max(0, originalCount - this.m_vanguardPhoneUnreadCount);
    i = originalCount - 1;
    while i >= 0 {
      if Equals(this.m_vanguardPhoneMessageVehicleIDs[i], id) {
        ArrayErase(this.m_vanguardPhoneMessageKinds, i);
        ArrayErase(this.m_vanguardPhoneMessageVehicleIDs, i);
        ArrayErase(this.m_vanguardPhoneMessageAmounts, i);
        ArrayErase(this.m_vanguardPhoneMessageAux1, i);
        ArrayErase(this.m_vanguardPhoneMessageAux2, i);
        ArrayErase(this.m_vanguardPhoneMessageMinutes, i);
        if i < this.m_vanguardPhoneDeliveredCount && this.m_vanguardPhoneDeliveredCount > 0 {
          this.m_vanguardPhoneDeliveredCount -= 1;
        };
        if i >= originalUnreadStart && this.m_vanguardPhoneUnreadCount > 0 {
          this.m_vanguardPhoneUnreadCount -= 1;
        };
      };
      i -= 1;
    };

    this.NormalizeVanguardDeferredPhoneArrays();
    i = ArraySize(this.m_vanguardDeferredPhoneMessageKinds) - 1;
    while i >= 0 {
      if Equals(this.m_vanguardDeferredPhoneMessageVehicleIDs[i], id) {
        ArrayErase(this.m_vanguardDeferredPhoneMessageKinds, i);
        ArrayErase(this.m_vanguardDeferredPhoneMessageVehicleIDs, i);
        ArrayErase(this.m_vanguardDeferredPhoneMessageAmounts, i);
        ArrayErase(this.m_vanguardDeferredPhoneMessageAux1, i);
        ArrayErase(this.m_vanguardDeferredPhoneMessageAux2, i);
        ArrayErase(this.m_vanguardDeferredPhoneMessageMinutes, i);
      };
      i -= 1;
    };

    this.m_vanguardPhoneDeliveredCount = Min(this.m_vanguardPhoneDeliveredCount, ArraySize(this.m_vanguardPhoneMessageKinds));
    this.m_vanguardPhoneUnreadCount = Min(this.m_vanguardPhoneUnreadCount, ArraySize(this.m_vanguardPhoneMessageKinds));

    if Equals(this.m_vanguardLastPhoneMessageVehicleID, id) {
      i = ArraySize(this.m_vanguardPhoneMessageKinds) - 1;
      if i >= 0 {
        this.m_vanguardLastPhoneMessageKind = this.m_vanguardPhoneMessageKinds[i];
        this.m_vanguardLastPhoneMessageVehicleID = this.m_vanguardPhoneMessageVehicleIDs[i];
        this.m_vanguardLastPhoneMessageAmount = this.m_vanguardPhoneMessageAmounts[i];
        this.m_vanguardLastPhoneMessageAux1 = this.m_vanguardPhoneMessageAux1[i];
        this.m_vanguardLastPhoneMessageAux2 = this.m_vanguardPhoneMessageAux2[i];
        this.m_vanguardLastPhoneMessageMinute = this.m_vanguardPhoneMessageMinutes[i];
      } else {
        this.m_vanguardLastPhoneMessageKind = 0;
        this.m_vanguardLastPhoneMessageVehicleID = TDBID.Create("");
        this.m_vanguardLastPhoneMessageAmount = 0;
        this.m_vanguardLastPhoneMessageAux1 = 0;
        this.m_vanguardLastPhoneMessageAux2 = 0;
        this.m_vanguardLastPhoneMessageMinute = 0;
      };
    };
  }

  private func QueueUninstalledVehicleRetirement(id: TweakDBID) -> Void {
    if TDBID.IsValid(id) && !ArrayContains(this.m_uninstalledVehicleRetirementIDs, id) {
      ArrayPush(this.m_uninstalledVehicleRetirementIDs, id);
    };
  }

  public func GetUninstalledVehicleRetirementCount() -> Int32 {
    return ArraySize(this.m_uninstalledVehicleRetirementIDs);
  }

  public func GetUninstalledVehicleRetirementIDAt(index: Int32) -> TweakDBID {
    if index < 0 || index >= ArraySize(this.m_uninstalledVehicleRetirementIDs) {
      return TDBID.Create("");
    };
    return this.m_uninstalledVehicleRetirementIDs[index];
  }

  public func AcknowledgeUninstalledVehicleRetirement(id: TweakDBID) -> Bool {
    let i: Int32 = ArraySize(this.m_uninstalledVehicleRetirementIDs) - 1;
    while i >= 0 {
      if Equals(this.m_uninstalledVehicleRetirementIDs[i], id) {
        ArrayErase(this.m_uninstalledVehicleRetirementIDs, i);
        return true;
      };
      i -= 1;
    };
    return false;
  }

  private func RemoveUninstalledVehicleState(id: TweakDBID) -> Void {
    let i: Int32 = ArraySize(this.m_soldVehicles) - 1;
    let soldLedgerChanged: Bool = false;

    this.QueueUninstalledVehicleRetirement(id);

    if TDBID.IsValid(id) && IsDefined(this.m_vehicleSystem) {
      RemoveVehicle(this.GetGameInstance(), this.m_vehicleSystem, id);
    };

    while i >= 0 {
      if Equals(this.m_soldVehicles[i], id) {
        ArrayErase(this.m_soldVehicles, i);
        soldLedgerChanged = true;
      };
      i -= 1;
    };
    if soldLedgerChanged {
      this.AdvanceSoldVehicleLedgerRevision();
    };

    this.RemoveVehicleFromLegacyOrderState(id);
    this.ClearCustomerFollowup(id);
    this.ClearSaleFollowup(id);

    if this.GetFinanceRemainingBalance(id) > 0 {
      this.RegisterVanguardCreditContract(id, true);
    } else {
      this.RemoveFinanceContractSilent(id);
      this.RemoveVehicleFromFinanceSerialState(id);
      this.RemoveVehicleFromFinanceEventState(id);
    };
    this.RemoveVanguardCoverageVehicleFromPolicy(id);
    this.ClearVanguardUninsuredVehicleDestroyed(id);
    this.ClearVanguardCoverageFraudDestroyedVehicleExclusion(id);
    this.RemoveVehicleFromCoverageTotalLossState(id);
    this.ClearVanguardCoverageRuntimeAliases();
    this.InvalidateNCGTAppreciation(id);
    this.RemoveNCGTPerformancePackageState(id);
    this.RemoveVehicleFromPhoneHistory(id);

    if Equals(this.m_coverageFraudLastVehicleID, id) {
      this.m_coverageFraudLastVehicleID = TDBID.Create("");
    };
    if Equals(this.m_ncgtAppreciationLastCommittedVehicleID, id) {
      this.m_ncgtAppreciationLastCommittedVehicleID = TDBID.Create("");
      this.m_ncgtAppreciationLastCommittedSerial = 0;
      this.m_ncgtAppreciationLastCommittedCheckoutToken = 0;
      this.m_ncgtAppreciationLastCommittedSavings = 0;
      this.m_ncgtAppreciationLastCommittedMinute = 0;
    };
    if Equals(this.m_ncgtAppreciationReservedVehicleID, id) {
      this.ClearNCGTAppreciationReservation();
    };
    if Equals(this.m_ncgtAppreciationNoticePendingVehicleID, id) {
      this.ClearPendingNCGTAppreciationVoucherNotice();
    };
    if Equals(this.m_vanguardDeliveryRequestVehicleID, id) {
      this.ClearVanguardDeliveryRequest(this.m_vanguardDeliveryRequestSequence, 4);
    };

    this.m_deactivateVehiclesDirty = true;
    this.m_financeContractsDirty = true;
    SetFactValue(this.GetGameInstance(), n"vanguard_coverage_redscript_commit_request", 1);
  }

  public func ReconcileUninstalledVehicles() -> Int32 {
    let unlockedVehicles: array<PlayerVehicle>;
    let persistentVehicles: array<PlayerVehicle>;
    let candidates: array<TweakDBID>;
    let now: Int32;
    let removedCount: Int32 = 0;

    if this.m_uninstalledVehicleReconcileRunning
      || this.m_uninstalledVehicleReconcileComplete
      || !IsDefined(this.m_vehicleSystem) {
      return 0;
    };

    now = this.GetCurrentGameMinute();
    if this.m_hasUninstalledVehicleReconcileMinute
      && now > 0
      && now == this.m_lastUninstalledVehicleReconcileMinute {
      return 0;
    };

    this.m_uninstalledVehicleReconcileRunning = true;
    this.m_hasUninstalledVehicleReconcileMinute = true;
    this.m_lastUninstalledVehicleReconcileMinute = now;

    this.m_vehicleSystem.GetPlayerUnlockedVehicles(unlockedVehicles);
    for vehicle in unlockedVehicles {
      candidates = this.CollectUninstalledVehicleCandidate(vehicle.recordID, candidates);
    };

    persistentVehicles = GetPersistentVehicles(this.GetGameInstance());
    for vehicle in persistentVehicles {
      candidates = this.CollectUninstalledVehicleCandidate(vehicle.recordID, candidates);
    };

    candidates = this.CollectUninstalledVehicleCandidates(this.m_soldVehicles, candidates);
    candidates = this.CollectUninstalledVehicleCandidates(this.m_pendingVehicleIDs, candidates);
    candidates = this.CollectUninstalledVehicleCandidates(this.m_followupVehicleIDs, candidates);
    candidates = this.CollectUninstalledVehicleCandidates(this.m_saleFollowupVehicleIDs, candidates);
    candidates = this.CollectUninstalledVehicleCandidates(this.m_readyVehicleIDs, candidates);
    candidates = this.CollectUninstalledVehicleCandidates(this.m_financeVehicleIDs, candidates);
    candidates = this.CollectUninstalledVehicleCandidates(this.m_financeStreetCredVehicleIDs, candidates);
    candidates = this.CollectUninstalledVehicleCandidates(this.m_financePaymentFrequencyVehicleIDs, candidates);
    candidates = this.CollectUninstalledVehicleCandidates(this.m_financeAutoPayVehicleIDs, candidates);
    candidates = this.CollectUninstalledVehicleCandidates(this.m_financePaymentSourceVehicleIDs, candidates);
    candidates = this.CollectUninstalledVehicleCandidates(this.m_financeContractSerialVehicleIDs, candidates);
    candidates = this.CollectUninstalledVehicleCandidates(this.m_coverageVehicleIDs, candidates);
    candidates = this.CollectUninstalledVehicleCandidates(this.m_coverageTotalLossVehicleIDs, candidates);
    candidates = this.CollectUninstalledVehicleCandidates(this.m_uninsuredDestroyedVehicleIDs, candidates);
    candidates = this.CollectUninstalledVehicleCandidates(this.m_coverageFraudDestroyedVehicleIDs, candidates);
    candidates = this.CollectUninstalledVehicleCandidates(this.m_financeDefaultVehicleIDs, candidates);
    candidates = this.CollectUninstalledVehicleCandidates(this.m_financeRepossessedVehicleIDs, candidates);
    candidates = this.CollectUninstalledVehicleCandidates(this.m_financeEventVehicleIDs, candidates);
    candidates = this.CollectUninstalledVehicleCandidates(this.m_ncgtAppreciationVehicleIDs, candidates);
    candidates = this.CollectUninstalledVehicleCandidates(this.m_ncgtPerformanceVehicleIDs, candidates);
    candidates = this.CollectUninstalledVehicleCandidates(this.m_financeNoticeVehicleIDs, candidates);
    for phoneVehicleID in this.m_vanguardPhoneMessageVehicleIDs {
      if NotEquals(phoneVehicleID, t"VanguardAuto.Phone.NoVehicle") {
        candidates = this.CollectUninstalledVehicleCandidate(phoneVehicleID, candidates);
      };
    };
    for phoneVehicleID in this.m_vanguardDeferredPhoneMessageVehicleIDs {
      if NotEquals(phoneVehicleID, t"VanguardAuto.Phone.NoVehicle") {
        candidates = this.CollectUninstalledVehicleCandidate(phoneVehicleID, candidates);
      };
    };
    candidates = this.CollectUninstalledVehicleCandidate(this.m_coverageFraudLastVehicleID, candidates);
    candidates = this.CollectUninstalledVehicleCandidate(this.m_ncgtAppreciationLastCommittedVehicleID, candidates);
    candidates = this.CollectUninstalledVehicleCandidate(this.m_ncgtAppreciationReservedVehicleID, candidates);
    candidates = this.CollectUninstalledVehicleCandidate(this.m_vanguardDeliveryRequestVehicleID, candidates);

    for id in candidates {
      this.RemoveUninstalledVehicleState(id);
      removedCount += 1;
    };

    if removedCount > 0 {
      SyncPersistentVehicles(this.GetGameInstance());
    };

    this.m_uninstalledVehicleReconcileRunning = false;
    this.m_uninstalledVehicleReconcileComplete = true;
    return removedCount;
  }

  public func GetList() -> array<ref<PurchasableVehicleBundle>> {
    let player: ref<PlayerPuppet>;

    this.ReconcileUninstalledVehicles();
    this.UpdatePendingOrders();
    player = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    this.UpdatePromoCampaignAlerts(player);
    return this.m_storeVehicles;
  }

  public func IsPurchasable(id: TweakDBID) -> Bool {
    for vehicle in this.m_storeVehicles {
      for variant in vehicle.variants {
      if Equals(variant.record.GetID(), id) {
        return true;
      };
      }
    };
    return false;
  }

  public func IsUnlocked(id: TweakDBID) -> Bool {
    this.UpdatePendingOrders();
    return this.IsSeparatePurchased(id);
  }

  public func IsPurchased(id: TweakDBID) -> Bool {
    this.UpdatePendingOrders();
    return this.IsSeparatePurchased(id) || this.HasPendingOrder(id);
  }

  public func HasPendingOrder(id: TweakDBID) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(this.m_pendingVehicleIDs) {
      if Equals(this.m_pendingVehicleIDs[i], id) {
        return true;
      };
      i += 1;
    };
    return false;
  }

  public func GetPendingOrderMode(id: TweakDBID) -> Int32 {
    let i: Int32 = 0;
    while i < ArraySize(this.m_pendingVehicleIDs) {
      if Equals(this.m_pendingVehicleIDs[i], id) {
        return this.m_pendingModes[i];
      };
      i += 1;
    };
    return 0;
  }

  public func GetPendingMinutesRemaining(id: TweakDBID) -> Int32 {
    let now: Int32 = this.GetCurrentGameMinute();
    let i: Int32 = 0;
    while i < ArraySize(this.m_pendingVehicleIDs) {
      if Equals(this.m_pendingVehicleIDs[i], id) {
        return Max(0, this.m_pendingReadyTimes[i] - now);
      };
      i += 1;
    };
    return 0;
  }

  public func GetPendingCount() -> Int32 {
    return ArraySize(this.m_pendingVehicleIDs);
  }

  public func GetPendingVehicleKeyAt(index: Int32) -> String {
    if index < 0 || index >= ArraySize(this.m_pendingVehicleIDs) {
      return "";
    };

    return TDBID.ToStringDEBUG(this.m_pendingVehicleIDs[index]);
  }

  public func GetPendingVehicleNameAt(index: Int32) -> String {
    let record: ref<Vehicle_Record>;

    if index < 0 || index >= ArraySize(this.m_pendingVehicleIDs) {
      return "vehicle";
    };

    record = TweakDBInterface.GetVehicleRecord(this.m_pendingVehicleIDs[index]);
    if IsDefined(record) {
      return GetLocalizedTextByKey(record.DisplayName());
    };

    return "vehicle";
  }

  public func GetPendingReadyMinuteAt(index: Int32) -> Int32 {
    if index < 0 || index >= ArraySize(this.m_pendingReadyTimes) {
      return 0;
    };

    return this.m_pendingReadyTimes[index];
  }

  public func GetPendingModeAtIndex(index: Int32) -> Int32 {
    if index < 0 || index >= ArraySize(this.m_pendingModes) {
      return 0;
    };

    return this.m_pendingModes[index];
  }

  public func HasReadyOrder(id: TweakDBID) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(this.m_readyVehicleIDs) {
      if Equals(this.m_readyVehicleIDs[i], id) {
        return true;
      };
      i += 1;
    };
    return false;
  }

  public func GetReadyOrderCount() -> Int32 {
    return ArraySize(this.m_readyVehicleIDs);
  }

  public func GetReadyVehicleKeyAt(index: Int32) -> String {
    if index < 0 || index >= ArraySize(this.m_readyVehicleIDs) {
      return "";
    };

    return TDBID.ToStringDEBUG(this.m_readyVehicleIDs[index]);
  }

  public func GetReadyVehicleNameAt(index: Int32) -> String {
    let record: ref<Vehicle_Record>;

    if index < 0 || index >= ArraySize(this.m_readyVehicleIDs) {
      return "vehicle";
    };

    record = TweakDBInterface.GetVehicleRecord(this.m_readyVehicleIDs[index]);
    if IsDefined(record) {
      return GetLocalizedTextByKey(record.DisplayName());
    };

    return "vehicle";
  }

  public func GetReadyModeAtIndex(index: Int32) -> Int32 {
    if index < 0 || index >= ArraySize(this.m_readyModes) {
      return 0;
    };

    return this.m_readyModes[index];
  }

  public func GetReadyReleaseMinuteAt(index: Int32) -> Int32 {
    if index < 0 || index >= ArraySize(this.m_readyReleaseTimes) {
      return 0;
    };

    return this.m_readyReleaseTimes[index];
  }

  private func QueueReadyOrder(id: TweakDBID, mode: Int32, releaseMinute: Int32) -> Void {
    if this.HasReadyOrder(id) {
      return ;
    };

    ArrayPush(this.m_readyVehicleIDs, id);
    ArrayPush(this.m_readyModes, mode);
    ArrayPush(this.m_readyReleaseTimes, releaseMinute);
  }

  private func GetCustomerCareFollowupDelayMinutes() -> Int32 {
    return 2880;
  }

  public func MarkReadyOrderPlaced(id: TweakDBID) -> Void {
    let newReadyVehicleIDs: array<TweakDBID>;
    let newReadyModes: array<Int32>;
    let newReadyReleaseTimes: array<Int32>;
    let i: Int32 = 0;
    let placedMode: Int32 = 0;
    let wasPlaced: Bool = false;

    while i < ArraySize(this.m_readyVehicleIDs) {
      if Equals(this.m_readyVehicleIDs[i], id) {
        placedMode = this.m_readyModes[i];
        wasPlaced = true;
      } else {
        ArrayPush(newReadyVehicleIDs, this.m_readyVehicleIDs[i]);
        ArrayPush(newReadyModes, this.m_readyModes[i]);
        ArrayPush(newReadyReleaseTimes, this.m_readyReleaseTimes[i]);
      };
      i += 1;
    };

    this.m_readyVehicleIDs = newReadyVehicleIDs;
    this.m_readyModes = newReadyModes;
    this.m_readyReleaseTimes = newReadyReleaseTimes;

    if wasPlaced {
      this.ScheduleCustomerFollowup(id, placedMode, this.GetCustomerCareFollowupDelayMinutes());
    };
  }

  public func HasCustomerFollowup(id: TweakDBID) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(this.m_followupVehicleIDs) {
      if Equals(this.m_followupVehicleIDs[i], id) {
        return true;
      };
      i += 1;
    };
    return false;
  }

  public func ClearCustomerFollowup(id: TweakDBID) -> Void {
    let newFollowupVehicleIDs: array<TweakDBID>;
    let newFollowupModes: array<Int32>;
    let newFollowupTimes: array<Int32>;
    let i: Int32 = 0;

    while i < ArraySize(this.m_followupVehicleIDs) {
      if !Equals(this.m_followupVehicleIDs[i], id) {
        ArrayPush(newFollowupVehicleIDs, this.m_followupVehicleIDs[i]);
        if i < ArraySize(this.m_followupModes) {
          ArrayPush(newFollowupModes, this.m_followupModes[i]);
        } else {
          ArrayPush(newFollowupModes, 1);
        };
        if i < ArraySize(this.m_followupTimes) {
          ArrayPush(newFollowupTimes, this.m_followupTimes[i]);
        } else {
          ArrayPush(newFollowupTimes, this.GetCurrentGameMinute() + this.GetCustomerCareFollowupDelayMinutes());
        };
      };
      i += 1;
    };

    this.m_followupVehicleIDs = newFollowupVehicleIDs;
    this.m_followupModes = newFollowupModes;
    this.m_followupTimes = newFollowupTimes;
  }

  public func GetCustomerFollowupCount() -> Int32 {
    return ArraySize(this.m_followupVehicleIDs);
  }

  public func GetCustomerFollowupVehicleKeyAt(index: Int32) -> String {
    if index < 0 || index >= ArraySize(this.m_followupVehicleIDs) {
      return "";
    };

    return TDBID.ToStringDEBUG(this.m_followupVehicleIDs[index]);
  }

  public func GetCustomerFollowupVehicleNameAt(index: Int32) -> String {
    let record: ref<Vehicle_Record>;

    if index < 0 || index >= ArraySize(this.m_followupVehicleIDs) {
      return "vehicle";
    };

    record = TweakDBInterface.GetVehicleRecord(this.m_followupVehicleIDs[index]);
    if IsDefined(record) {
      return GetLocalizedTextByKey(record.DisplayName());
    };

    return "vehicle";
  }

  public func GetCustomerFollowupDueMinuteAt(index: Int32) -> Int32 {
    if index < 0 || index >= ArraySize(this.m_followupTimes) {
      return 0;
    };

    return this.m_followupTimes[index];
  }

  public func GetCustomerFollowupModeAtIndex(index: Int32) -> Int32 {
    if index < 0 || index >= ArraySize(this.m_followupModes) {
      return 0;
    };

    return this.m_followupModes[index];
  }

  private func AdvanceSoldVehicleLedgerRevision() -> Void {
    this.m_soldVehicleLedgerRevision += 1;
    if this.m_soldVehicleLedgerRevision <= 0 {
      this.m_soldVehicleLedgerRevision = 1;
    };
  }

  public func GetSoldVehicleLedgerRevision() -> Int32 {
    return this.m_soldVehicleLedgerRevision;
  }

  public func GetSoldVehicleCount() -> Int32 {
    return ArraySize(this.m_soldVehicles);
  }

  public func IsVanguardVehicleSold(id: TweakDBID) -> Bool {
    return ArrayContains(this.m_soldVehicles, id);
  }

  public func GetSoldVehicleKeyAt(index: Int32) -> String {
    if index < 0 || index >= ArraySize(this.m_soldVehicles) {
      return "";
    };

    return TDBID.ToStringDEBUG(this.m_soldVehicles[index]);
  }

  public func GetSoldVehicleNameAt(index: Int32) -> String {
    let record: ref<Vehicle_Record>;

    if index < 0 || index >= ArraySize(this.m_soldVehicles) {
      return "vehicle";
    };

    record = TweakDBInterface.GetVehicleRecord(this.m_soldVehicles[index]);
    if IsDefined(record) {
      return GetLocalizedTextByKey(record.DisplayName());
    };

    return "vehicle";
  }

  public func GetSoldVehicleSellPriceAt(index: Int32) -> Int32 {
    let vehicleID: TweakDBID;
    let price: Int32;

    if index < 0 || index >= ArraySize(this.m_soldVehicles) {
      return 0;
    };

    vehicleID = this.m_soldVehicles[index];
    price = this.GetVehicleBasePrice(vehicleID);
    return Cast<Int32>(Cast<Float>(price) * this.m_sellPriceModifier);
  }

  public func ClearSoldVehicleRecord(id: TweakDBID) -> Void {
    let soldVehicles: array<TweakDBID> = this.m_soldVehicles;

    if ArrayContains(soldVehicles, id) {
      ArrayRemove(soldVehicles, id);
      this.m_soldVehicles = soldVehicles;
      this.AdvanceSoldVehicleLedgerRevision();
      this.m_deactivateVehiclesDirty = true;
    };
  }

  public func MarkExternalVehicleClaimed(id: TweakDBID) -> Void {
    let vehicleRecord: ref<Vehicle_Record>;
    let vehicleId: TweakDBID;

    if !TDBID.IsValid(id) {
      return ;
    };

    this.ClearSoldVehicleRecord(id);

    vehicleRecord = TweakDBInterface.GetVehicleRecord(id);
    if IsDefined(vehicleRecord) {
      vehicleId = vehicleRecord.GetID();
      if NotEquals(vehicleId, id) {
        this.ClearSoldVehicleRecord(vehicleId);
      };
    };
  }

  public func HasSaleFollowup(id: TweakDBID) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(this.m_saleFollowupVehicleIDs) {
      if Equals(this.m_saleFollowupVehicleIDs[i], id) {
        return true;
      };
      i += 1;
    };
    return false;
  }

  public func ClearSaleFollowup(id: TweakDBID) -> Void {
    let newSaleFollowupVehicleIDs: array<TweakDBID>;
    let newSaleFollowupTimes: array<Int32>;
    let i: Int32 = 0;

    while i < ArraySize(this.m_saleFollowupVehicleIDs) {
      if !Equals(this.m_saleFollowupVehicleIDs[i], id) {
        ArrayPush(newSaleFollowupVehicleIDs, this.m_saleFollowupVehicleIDs[i]);
        if i < ArraySize(this.m_saleFollowupTimes) {
          ArrayPush(newSaleFollowupTimes, this.m_saleFollowupTimes[i]);
        } else {
          ArrayPush(newSaleFollowupTimes, this.GetCurrentGameMinute() + 60);
        };
      };
      i += 1;
    };

    this.m_saleFollowupVehicleIDs = newSaleFollowupVehicleIDs;
    this.m_saleFollowupTimes = newSaleFollowupTimes;
  }

  public func GetSaleFollowupCount() -> Int32 {
    return ArraySize(this.m_saleFollowupVehicleIDs);
  }

  public func GetSaleFollowupVehicleKeyAt(index: Int32) -> String {
    if index < 0 || index >= ArraySize(this.m_saleFollowupVehicleIDs) {
      return "";
    };

    return TDBID.ToStringDEBUG(this.m_saleFollowupVehicleIDs[index]);
  }

  public func GetSaleFollowupVehicleNameAt(index: Int32) -> String {
    let record: ref<Vehicle_Record>;

    if index < 0 || index >= ArraySize(this.m_saleFollowupVehicleIDs) {
      return "vehicle";
    };

    record = TweakDBInterface.GetVehicleRecord(this.m_saleFollowupVehicleIDs[index]);
    if IsDefined(record) {
      return GetLocalizedTextByKey(record.DisplayName());
    };

    return "vehicle";
  }

  public func GetSaleFollowupDueMinuteAt(index: Int32) -> Int32 {
    if index < 0 || index >= ArraySize(this.m_saleFollowupTimes) {
      return 0;
    };

    return this.m_saleFollowupTimes[index];
  }

  public func ScheduleSaleFollowup(id: TweakDBID, delayMinutes: Int32) -> Void {
    let dueTime: Int32;

    this.UpdateSaleFollowups();

    if this.HasSaleFollowup(id) || this.HasSaleConfirmationPhoneMessage(id) || delayMinutes <= 0 {
      return ;
    };

    dueTime = this.GetCurrentGameMinute() + delayMinutes;
    ArrayPush(this.m_saleFollowupVehicleIDs, id);
    ArrayPush(this.m_saleFollowupTimes, dueTime);
  }

  public func UpdateSaleFollowups() -> Void {
    let now: Int32 = this.GetCurrentGameMinute();
    let newSaleFollowupVehicleIDs: array<TweakDBID>;
    let newSaleFollowupTimes: array<Int32>;
    let i: Int32 = 0;

    while i < ArraySize(this.m_saleFollowupVehicleIDs) {
      if !this.HasSaleConfirmationPhoneMessage(this.m_saleFollowupVehicleIDs[i]) {
        ArrayPush(newSaleFollowupVehicleIDs, this.m_saleFollowupVehicleIDs[i]);
        if i < ArraySize(this.m_saleFollowupTimes) {
          ArrayPush(newSaleFollowupTimes, this.m_saleFollowupTimes[i]);
        } else {
          ArrayPush(newSaleFollowupTimes, now + 60);
        };
      };
      i += 1;
    };

    this.m_saleFollowupVehicleIDs = newSaleFollowupVehicleIDs;
    this.m_saleFollowupTimes = newSaleFollowupTimes;
  }

  public func ScheduleCustomerFollowup(id: TweakDBID, mode: Int32, delayMinutes: Int32) -> Void {
    let dueTime: Int32;

    this.UpdateCustomerFollowups();

    if ArrayContains(this.m_soldVehicles, id) || this.HasCustomerFollowup(id) || delayMinutes <= 0 {
      return ;
    };

    dueTime = this.GetCurrentGameMinute() + delayMinutes;
    ArrayPush(this.m_followupVehicleIDs, id);
    ArrayPush(this.m_followupModes, mode);
    ArrayPush(this.m_followupTimes, dueTime);
  }

  public func UpdateCustomerFollowups() -> Void {
    let now: Int32 = this.GetCurrentGameMinute();
    let newFollowupVehicleIDs: array<TweakDBID>;
    let newFollowupModes: array<Int32>;
    let newFollowupTimes: array<Int32>;
    let i: Int32 = 0;

    while i < ArraySize(this.m_followupVehicleIDs) {
      if !ArrayContains(this.m_soldVehicles, this.m_followupVehicleIDs[i]) {
        ArrayPush(newFollowupVehicleIDs, this.m_followupVehicleIDs[i]);
        if i < ArraySize(this.m_followupModes) {
          ArrayPush(newFollowupModes, this.m_followupModes[i]);
        } else {
          ArrayPush(newFollowupModes, 1);
        };
        if i < ArraySize(this.m_followupTimes) {
          ArrayPush(newFollowupTimes, this.m_followupTimes[i]);
        } else {
          ArrayPush(newFollowupTimes, now + this.GetCustomerCareFollowupDelayMinutes());
        };
      };
      i += 1;
    };

    this.m_followupVehicleIDs = newFollowupVehicleIDs;
    this.m_followupModes = newFollowupModes;
    this.m_followupTimes = newFollowupTimes;
  }

  public func GetOrderDelayMinutes(mode: Int32) -> Int32 {
    return 0;
  }

  public func SchedulePurchase(id: TweakDBID, mode: Int32) -> Void {
    if !this.IsInstalledVehicleRecord(id) || !this.IsPurchasable(id) || this.IsSeparatePurchased(id) {
      return ;
    };

    this.Purchase(id);
    this.ScheduleCustomerFollowup(id, 1, this.GetCustomerCareFollowupDelayMinutes());
  }

  public func UpdatePendingOrders() -> Void {
    if this.m_pendingOrdersResolved {
      return;
    };

    this.ResolveLegacyReleaseOrders();
    this.m_pendingOrdersResolved = true;
  }

  public func Purchase(id: TweakDBID) -> Void {
    let wasPurchased: Bool = this.IsSeparatePurchased(id);

    if !this.IsInstalledVehicleRecord(id) || !this.IsPurchasable(id) {
      return;
    };

    this.m_vehicleSystem.EnablePlayerVehicleID(id, true);
    SyncPersistentVehicles(this.GetGameInstance());
    let soldVehicles: array<TweakDBID> = this.m_soldVehicles;
    if ArrayContains(soldVehicles, id) {
      ArrayRemove(soldVehicles, id);
      this.m_soldVehicles = soldVehicles;
      this.AdvanceSoldVehicleLedgerRevision();
      this.m_deactivateVehiclesDirty = true;
    };

    this.ClearVanguardUninsuredVehicleDestroyed(id);

    if !wasPurchased {
      this.m_dealershipPurchases += 1;
    };
  }

  public func IsVehicleFinanced(id: TweakDBID) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(this.m_financeVehicleIDs) {
      if Equals(this.m_financeVehicleIDs[i], id) {
        return true;
      };
      i += 1;
    };
    return false;
  }

  private func GetCanonicalVehicleRecordID(id: TweakDBID) -> TweakDBID {
    let vehicleRecord: ref<Vehicle_Record>;

    if !TDBID.IsValid(id) {
      return id;
    };

    vehicleRecord = TweakDBInterface.GetVehicleRecord(id);
    if IsDefined(vehicleRecord) && TDBID.IsValid(vehicleRecord.GetID()) {
      return vehicleRecord.GetID();
    };

    return id;
  }

  public func GetFinanceContractIDForTradeInID(id: TweakDBID) -> TweakDBID {
    let canonicalID: TweakDBID = this.GetCanonicalVehicleRecordID(id);
    let contractID: TweakDBID;
    let contractCanonicalID: TweakDBID;
    let i: Int32 = 0;

    if !TDBID.IsValid(id) {
      return id;
    };

    if this.IsVehicleFinanced(id) {
      return id;
    };

    if TDBID.IsValid(canonicalID) && !Equals(canonicalID, id) && this.IsVehicleFinanced(canonicalID) {
      return canonicalID;
    };

    while i < ArraySize(this.m_financeVehicleIDs) {
      contractID = this.m_financeVehicleIDs[i];
      if Equals(contractID, id) || Equals(contractID, canonicalID) {
        return contractID;
      };

      contractCanonicalID = this.GetCanonicalVehicleRecordID(contractID);
      if Equals(contractCanonicalID, id) || Equals(contractCanonicalID, canonicalID) {
        return contractID;
      };

      i += 1;
    };

    return id;
  }

  public func IsTradeInVehicleFinanced(id: TweakDBID) -> Bool {
    let contractID: TweakDBID = this.GetFinanceContractIDForTradeInID(id);
    let contractIndex: Int32;

    if !TDBID.IsValid(contractID) {
      return false;
    };

    contractIndex = this.GetFinanceContractIndex(contractID);
    return contractIndex >= 0 && this.GetFinanceRemainingBalanceByIndex(contractIndex) > 0;
  }

  public func GetTradeInFinanceRemainingBalance(id: TweakDBID) -> Int32 {
    let contractID: TweakDBID = this.GetFinanceContractIDForTradeInID(id);
    let contractIndex: Int32;

    if !TDBID.IsValid(contractID) {
      return 0;
    };

    contractIndex = this.GetFinanceContractIndex(contractID);
    if contractIndex < 0 {
      return 0;
    };

    return this.GetFinanceRemainingBalanceByIndex(contractIndex);
  }

  public func GetFinanceContractIndex(id: TweakDBID) -> Int32 {
    let i: Int32 = 0;

    while i < ArraySize(this.m_financeVehicleIDs) {
      if Equals(this.m_financeVehicleIDs[i], id) {
        return i;
      };
      i += 1;
    };

    return -1;
  }

  private func GetFinanceContractSerialIndex(id: TweakDBID) -> Int32 {
    let i: Int32 = 0;

    while i < ArraySize(this.m_financeContractSerialVehicleIDs) {
      if Equals(this.m_financeContractSerialVehicleIDs[i], id) {
        return i;
      };
      i += 1;
    };

    return -1;
  }

  private func AssignNewFinanceContractSerial(id: TweakDBID) -> Int32 {
    let index: Int32;

    if !TDBID.IsValid(id) {
      return 0;
    };

    this.m_financeContractSerialSequence += 1;
    if this.m_financeContractSerialSequence <= 0 {
      this.m_financeContractSerialSequence = 1;
    };

    index = this.GetFinanceContractSerialIndex(id);
    if index >= 0 && index < ArraySize(this.m_financeContractSerials) {
      this.m_financeContractSerials[index] = this.m_financeContractSerialSequence;
    } else {
      ArrayPush(this.m_financeContractSerialVehicleIDs, id);
      ArrayPush(this.m_financeContractSerials, this.m_financeContractSerialSequence);
    };

    return this.m_financeContractSerialSequence;
  }

  private func EnsureFinanceContractSerial(id: TweakDBID) -> Int32 {
    let index: Int32 = this.GetFinanceContractSerialIndex(id);

    if index >= 0
      && index < ArraySize(this.m_financeContractSerials)
      && this.m_financeContractSerials[index] > 0 {
      return this.m_financeContractSerials[index];
    };

    return this.AssignNewFinanceContractSerial(id);
  }

  public func GetActiveFinanceContractCount() -> Int32 {
    return ArraySize(this.m_financeVehicleIDs);
  }
  public func GetMaxActiveAutoFinanceContracts() -> Int32 {
    return 10;
  }
  public func HasAvailableAutoFinanceSlot() -> Bool {
    return this.GetActiveFinanceContractCount() < this.GetMaxActiveAutoFinanceContracts();
  }

  public func GetAutoFinanceCapacityDisplayText() -> String {
    return s"\(this.GetActiveFinanceContractCount()) / \(this.GetMaxActiveAutoFinanceContracts())";
  }

  public func IsAutoFinanceCapacityReached() -> Bool {
    return !this.HasAvailableAutoFinanceSlot();
  }

  public func GetActiveFinanceVehicleNameAt(contractIndex: Int32) -> String {
    let internalIndex: Int32 = contractIndex - 1;

    if internalIndex < 0 || internalIndex >= ArraySize(this.m_financeVehicleIDs) {
      return VanguardAutoLocalization.Text(1735, "Vanguard Auto Loan");
    };

    if !this.IsInstalledVehicleRecord(this.m_financeVehicleIDs[internalIndex]) {
      return "Removed vehicle - loan #" + IntToString(this.EnsureFinanceContractSerial(this.m_financeVehicleIDs[internalIndex]));
    };
    return this.GetVehicleDisplayName(this.m_financeVehicleIDs[internalIndex]);
  }

  public func GetActiveFinanceContractSerialAt(contractIndex: Int32) -> Int32 {
    let internalIndex: Int32 = contractIndex - 1;

    if internalIndex < 0 || internalIndex >= ArraySize(this.m_financeVehicleIDs) {
      return 0;
    };

    return this.EnsureFinanceContractSerial(this.m_financeVehicleIDs[internalIndex]);
  }

  public func GetActiveFinanceRemainingBalanceAt(contractIndex: Int32) -> Int32 {
    let internalIndex: Int32 = contractIndex - 1;

    if internalIndex < 0 || internalIndex >= ArraySize(this.m_financeVehicleIDs) {
      return 0;
    };

    return this.GetFinanceRemainingBalanceByIndex(internalIndex);
  }

  public func GetActiveFinanceMonthlyPaymentAt(contractIndex: Int32) -> Int32 {
    let internalIndex: Int32 = contractIndex - 1;

    if internalIndex < 0 || internalIndex >= ArraySize(this.m_financeMonthlyPayments) {
      return 0;
    };

    return this.m_financeMonthlyPayments[internalIndex];
  }

  public func GetActiveFinanceTermMonthsAt(contractIndex: Int32) -> Int32 {
    let internalIndex: Int32 = contractIndex - 1;

    if internalIndex < 0 || internalIndex >= ArraySize(this.m_financeTerms) {
      return 0;
    };

    return this.m_financeTerms[internalIndex];
  }

  public func GetActiveFinanceRemainingMonthsAt(contractIndex: Int32) -> Int32 {
    let internalIndex: Int32 = contractIndex - 1;

    if internalIndex < 0 || internalIndex >= ArraySize(this.m_financeRemainingMonths) {
      return 0;
    };

    return this.m_financeRemainingMonths[internalIndex];
  }

  public func GetActiveFinanceInterestBasisPointsAt(contractIndex: Int32) -> Int32 {
    let internalIndex: Int32 = contractIndex - 1;

    if internalIndex < 0 || internalIndex >= ArraySize(this.m_financeInterestPercents) {
      return 0;
    };

    return this.m_financeInterestPercents[internalIndex];
  }

  public func GetActiveFinanceTotalDueAt(contractIndex: Int32) -> Int32 {
    let internalIndex: Int32 = contractIndex - 1;

    if internalIndex < 0 || internalIndex >= ArraySize(this.m_financeTotalDue) {
      return 0;
    };

    return this.m_financeTotalDue[internalIndex];
  }

  public func GetActiveFinanceDownPaymentAt(contractIndex: Int32) -> Int32 {
    let internalIndex: Int32 = contractIndex - 1;

    if internalIndex < 0 || internalIndex >= ArraySize(this.m_financeDownPayments) {
      return 0;
    };

    return this.m_financeDownPayments[internalIndex];
  }

  public func GetActiveFinancePaidAmountAt(contractIndex: Int32) -> Int32 {
    let internalIndex: Int32 = contractIndex - 1;

    if internalIndex < 0 || internalIndex >= ArraySize(this.m_financeVehicleIDs) {
      return 0;
    };

    return this.GetFinancePaidAmountByIndex(internalIndex);
  }

  public func GetActiveFinanceNextDueTextAt(contractIndex: Int32) -> String {
    let internalIndex: Int32 = contractIndex - 1;

    if internalIndex < 0 || internalIndex >= ArraySize(this.m_financeVehicleIDs) {
      return "—";
    };

    return this.GetFinanceNextPaymentDueDayText(this.m_financeVehicleIDs[internalIndex]);
  }

  public func GetActiveFinancePaymentFrequencyAt(contractIndex: Int32) -> Int32 {
    let internalIndex: Int32 = contractIndex - 1;

    if internalIndex < 0 || internalIndex >= ArraySize(this.m_financeVehicleIDs) {
      return 3;
    };

    return this.GetFinancePaymentFrequency(this.m_financeVehicleIDs[internalIndex]);
  }

  public func GetActiveFinanceAutoPayEnabledAt(contractIndex: Int32) -> Bool {
    let internalIndex: Int32 = contractIndex - 1;

    if internalIndex < 0 || internalIndex >= ArraySize(this.m_financeVehicleIDs) {
      return false;
    };

    if this.IsVehicleRepossessed(this.m_financeVehicleIDs[internalIndex]) {
      return false;
    };

    return this.IsFinanceAutoPayEnabled(this.m_financeVehicleIDs[internalIndex]);
  }
  public func SetFinanceContractAutoPayByIndex(contractIndex: Int32, enabled: Bool) -> Bool {
    let internalIndex: Int32 = contractIndex - 1;
    let id: TweakDBID;
    let current: Bool;
    if !this.IsMarmurBankAutoFinanceAvailable() { return false; };

    if internalIndex < 0 || internalIndex >= ArraySize(this.m_financeVehicleIDs) {
      return false;
    };

    id = this.m_financeVehicleIDs[internalIndex];
    if !TDBID.IsValid(id) || !this.IsVehicleFinanced(id) || this.IsVehicleRepossessed(id) {
      return false;
    };

    current = this.IsFinanceAutoPayEnabled(id);

    if enabled
      && (this.IsFinancePaymentDelinquent(id)
        || internalIndex >= ArraySize(this.m_financeNextPaymentMinutes)
        || this.m_financeNextPaymentMinutes[internalIndex] <= this.GetCurrentGameMinute()) {
      return false;
    };

    if (current && enabled) || (!current && !enabled) {
      return true;
    };

    this.SetFinanceAutoPayEnabled(id, enabled);
    if enabled {
      if !this.IsFinanceAutoPayEnabled(id) {
        return false;
      };
    } else {
      if this.IsFinanceAutoPayEnabled(id) {
        return false;
      };
    };

    if enabled {
      this.PushFinanceEvent(id, 7, 1, this.GetFinanceRemainingMonths(id), 0, this.GetFinanceMonthlyPaymentForVehicle(id));
    } else {
      this.PushFinanceEvent(id, 8, 0, this.GetFinanceRemainingMonths(id), 0, this.GetFinanceMonthlyPaymentForVehicle(id));
    };
    return true;
  }

  public func IsActiveFinanceContractRepossessedAt(contractIndex: Int32) -> Bool {
    let internalIndex: Int32 = contractIndex - 1;

    if internalIndex < 0 || internalIndex >= ArraySize(this.m_financeVehicleIDs) {
      return false;
    };

    return this.IsVehicleRepossessed(this.m_financeVehicleIDs[internalIndex]);
  }
  public func MarmurBankRepossessFinancedVehicleAt(contractIndex: Int32) -> Bool {
    let internalIndex: Int32 = contractIndex - 1;
    let id: TweakDBID;
    let balance: Int32;
    let remainingMonths: Int32;
    let termMonths: Int32;
    let monthlyPayment: Int32;
    if !this.IsMarmurBankAutoFinanceAvailable() { return false; };

    if internalIndex < 0 || internalIndex >= ArraySize(this.m_financeVehicleIDs) {
      return false;
    };

    id = this.m_financeVehicleIDs[internalIndex];
    if !TDBID.IsValid(id) || !this.IsVehicleFinanced(id) || this.IsVehicleRepossessed(id) {
      return false;
    };

    if !this.HasMarmurCoverageRepossessionAuthorization(id) { return false; };
    balance = this.GetFinanceRemainingBalanceByIndex(internalIndex);
    if balance <= 0 {
      return false;
    };

    if internalIndex < ArraySize(this.m_financeRemainingMonths) {
      remainingMonths = this.m_financeRemainingMonths[internalIndex];
    };
    if internalIndex < ArraySize(this.m_financeTerms) {
      termMonths = this.m_financeTerms[internalIndex];
    };
    if internalIndex < ArraySize(this.m_financeMonthlyPayments) {
      monthlyPayment = this.m_financeMonthlyPayments[internalIndex];
    };

    this.MarkVehicleRepossessed(id, balance, remainingMonths, termMonths, monthlyPayment);
    return true;
  }

  public func MarmurRepossessFinancedVehicleAt(contractIndex: Int32) -> Bool {
    return this.MarmurBankRepossessFinancedVehicleAt(contractIndex);
  }

  public func RepossessFinancedVehicleAt(contractIndex: Int32) -> Bool {
    return this.MarmurBankRepossessFinancedVehicleAt(contractIndex);
  }
  public func PayFinanceContractScheduledByIndex(contractIndex: Int32, player: ref<GameObject>) -> Bool {
    let i: Int32 = contractIndex - 1;
    let id: TweakDBID;
    let amount: Int32;
    if !this.IsMarmurBankAutoFinanceAvailable() { return false; };

    if i < 0 || i >= ArraySize(this.m_financeVehicleIDs) { return false; };
    id = this.m_financeVehicleIDs[i];
    if this.IsVehicleRepossessed(id) { return false; };
    this.RegisterVanguardCreditContract(id, true);
    this.CaptureVanguardMaturedObligations(id);
    amount = this.GetVanguardCreditFact(this.EnsureFinanceContractSerial(id), "arrears");
    if amount <= 0 { amount = this.GetVanguardCreditCashDue(id); };
    return this.MakeCustomFinancePayment(id, amount, player);
  }
  public func PayFinanceContractFullByIndex(contractIndex: Int32, player: ref<GameObject>) -> Bool {
    let internalIndex: Int32 = contractIndex - 1;
    if !this.IsMarmurBankAutoFinanceAvailable() { return false; };

    if internalIndex < 0 || internalIndex >= ArraySize(this.m_financeVehicleIDs) {
      return false;
    };

    return this.PayOffFinanceContract(this.m_financeVehicleIDs[internalIndex], player);
  }
  public func PayFinanceContractCustomByIndex(contractIndex: Int32, requestedAmount: Int32, player: ref<GameObject>) -> Bool {
    let internalIndex: Int32 = contractIndex - 1;
    if !this.IsMarmurBankAutoFinanceAvailable() { return false; };

    if internalIndex < 0 || internalIndex >= ArraySize(this.m_financeVehicleIDs) {
      return false;
    };

    return this.MakeCustomFinancePayment(this.m_financeVehicleIDs[internalIndex], requestedAmount, player);
  }
  public func MakeCustomFinancePayment(id: TweakDBID, requestedAmount: Int32, player: ref<GameObject>) -> Bool {
    let i: Int32 = this.GetFinanceContractIndex(id);
    let amount: Int32;
    let balance: Int32;
    let after: Int32;
    if !this.IsMarmurBankAutoFinanceAvailable() { return false; };

    if !IsDefined(player) || i < 0 || requestedAmount <= 0 { return false; };
    this.RegisterVanguardCreditContract(id, true);
    this.CaptureVanguardMaturedObligations(id);
    balance = this.GetFinanceRemainingBalanceByIndex(i);
    amount = Min(requestedAmount, balance);
    if amount <= 0 || !this.DebitVanguardCreditWallet(player, amount) { return false; };
    after = balance - amount;
    this.RecordVanguardCreditPayment(id, amount, after, after == 0);
    if after == 0 {
      this.PushFinanceEvent(id, 5, amount, 0, this.m_financeTerms[i], this.m_financeMonthlyPayments[i]);
      this.RemovePaidVanguardCreditContract(id);
    } else {
      this.StoreVanguardCreditPaidAmount(i, this.GetFinancePaidAmountByIndex(i) + amount);
      this.m_financeRemainingMonths[i] = Max(1, (after + this.m_financeMonthlyPayments[i] - 1) / this.m_financeMonthlyPayments[i]);
      if this.GetVanguardCreditFact(this.EnsureFinanceContractSerial(id), "arrears") == 0 { this.ClearFinanceDefaultState(id); };
      this.PushFinanceEvent(id, 6, amount, this.m_financeRemainingMonths[i], this.m_financeTerms[i], this.m_financeMonthlyPayments[i]);
    };
    this.m_financeContractsDirty = true;
    return true;
  }

  public func RequestMarmurBankLoanHandoff(id: TweakDBID) -> Void {
    let gameInstance: GameInstance = this.GetGameInstance();
    let contractIndex: Int32 = this.GetFinanceContractIndex(id);
    let serial: Int32;

    if !this.IsMarmurBankAutoFinanceAvailable() || contractIndex < 0 {
      return;
    };

    serial = this.GetActiveFinanceContractSerialAt(contractIndex + 1);
    SetFactValue(gameInstance, n"marmur_vanguard_selected_contract", contractIndex + 1);
    SetFactValue(gameInstance, n"marmur_vanguard_selected_serial", serial);
    SetFactValue(gameInstance, n"marmur_vanguard_selected_balance", this.GetFinanceRemainingBalanceByIndex(contractIndex));
    SetFactValue(gameInstance, n"marmur_vanguard_selected_monthly", this.m_financeMonthlyPayments[contractIndex]);
    SetFactValue(gameInstance, n"marmur_vanguard_selected_term", this.m_financeTerms[contractIndex]);

    SetFactValue(gameInstance, n"marmur_vanguard_open_loans", 1);
  }

  public func SetMarmurBankAutoFinanceIntegrationAvailable(available: Bool, apiVersion: Int32) -> Bool {
    this.m_marmurBankAutoFinanceIntegrationAvailable = available
      && this.GetMarmurLoanServicingVersion() == 1
      && apiVersion >= 4
      && GetMarmurVanguardAutoFinanceProviderVersion() >= 4
      && IsMarmurVanguardAutoFinanceProviderAvailable(this.GetGameInstance());
    if this.m_marmurBankAutoFinanceIntegrationAvailable {
      this.m_marmurBankAutoFinanceIntegrationAPIVersion = apiVersion;
      this.m_marmurBankAutoFinanceIntegrationHeartbeatAt = EngineTime.ToFloat(
        GameInstance.GetEngineTime(this.GetGameInstance())
      );
      this.m_marmurBankAutoFinanceLeaseObservedThisSession = true;
    } else {
      this.m_marmurBankAutoFinanceIntegrationAPIVersion = 0;
      this.m_marmurBankAutoFinanceIntegrationHeartbeatAt = 0.00;
    };

    return this.m_marmurBankAutoFinanceIntegrationAvailable;
  }

  private func IsMarmurBankAutoFinanceStartupGraceActive() -> Bool {
    if this.m_marmurBankAutoFinanceLeaseObservedThisSession {
      return false;
    };

    return EngineTime.ToFloat(GameInstance.GetEngineTime(this.GetGameInstance()))
      <= this.m_marmurBankAutoFinanceStartupGraceUntil;
  }

  public func IsMarmurBankAutoFinanceAvailable() -> Bool {
    let now: Float;

    if !this.m_marmurBankAutoFinanceIntegrationAvailable
      || this.m_marmurBankAutoFinanceIntegrationAPIVersion < 4
      || GetMarmurVanguardAutoFinanceProviderVersion() < 4
      || !IsMarmurVanguardAutoFinanceProviderAvailable(this.GetGameInstance()) {
      return false;
    };

    now = EngineTime.ToFloat(GameInstance.GetEngineTime(this.GetGameInstance()));
    if now < this.m_marmurBankAutoFinanceIntegrationHeartbeatAt
      || now - this.m_marmurBankAutoFinanceIntegrationHeartbeatAt > 3.00 {
      this.m_marmurBankAutoFinanceIntegrationAvailable = false;
      this.m_marmurBankAutoFinanceIntegrationAPIVersion = 0;
      this.m_marmurBankAutoFinanceIntegrationHeartbeatAt = 0.00;
      return false;
    };

    return true;
  }

  public func IsMarmurBankSavingsPaymentSourceAvailable() -> Bool {
    return this.IsMarmurBankAutoFinanceAvailable()
      && this.m_marmurBankAutoFinanceIntegrationAPIVersion >= 3
      && IsMarmurVanguardSavingsPaymentSourceAvailable(this.GetGameInstance());
  }
  public func PublishMarmurBankAutoLoanApprovalNotice(id: TweakDBID) -> Void {
    let gameInstance: GameInstance = this.GetGameInstance();
    let contractIndex: Int32 = this.GetFinanceContractIndex(id);
    let balance: Int32;
    let scheduledAmount: Int32;
    let termMonths: Int32;
    let frequency: Int32;
    let encodedTermFrequency: Int32;

    if contractIndex < 0 {
      return;
    };

    balance = this.GetFinanceRemainingBalanceByIndex(contractIndex);
    termMonths = this.m_financeTerms[contractIndex];
    frequency = this.GetFinancePaymentFrequency(id);
    if frequency < 1 || frequency > 3 {
      frequency = 3;
    };
    scheduledAmount = this.CalculateFinanceScheduledPaymentAmount(this.m_financeMonthlyPayments[contractIndex], frequency, balance);
    encodedTermFrequency = termMonths * 10 + frequency;

    SetFactValue(gameInstance, n"marmur_vanguard_auto_sms_pending", 1);
    SetFactValue(gameInstance, n"marmur_vanguard_auto_sms_amount", balance);
    SetFactValue(gameInstance, n"marmur_vanguard_auto_sms_payment", scheduledAmount);
    SetFactValue(gameInstance, n"marmur_vanguard_auto_sms_termfreq", encodedTermFrequency);
    SetFactValue(gameInstance, n"marmur_vanguard_auto_sms_contract", contractIndex + 1);
    SetFactValue(gameInstance, n"marmur_vanguard_auto_sms_serial", this.GetActiveFinanceContractSerialAt(contractIndex + 1));
    SetFactValue(gameInstance, n"marmur_vanguard_auto_sms_apr", this.GetActiveFinanceInterestBasisPointsAt(contractIndex + 1));
  }
  public func PublishMarmurBankAutoLoanDenialNotice(id: TweakDBID, finalPrice: Int32, reasonCode: Int32) -> Void {
    let gameInstance: GameInstance = this.GetGameInstance();

    SetFactValue(gameInstance, n"marmur_vanguard_auto_sms_pending", 2);
    SetFactValue(gameInstance, n"marmur_vanguard_auto_sms_amount", finalPrice);
    SetFactValue(gameInstance, n"marmur_vanguard_auto_sms_payment", reasonCode);
    SetFactValue(gameInstance, n"marmur_vanguard_auto_sms_termfreq", this.GetMaxActiveAutoFinanceContracts());
    SetFactValue(gameInstance, n"marmur_vanguard_auto_sms_contract", this.GetFinanceContractIndex(id) + 1);
    SetFactValue(gameInstance, n"marmur_vanguard_auto_sms_serial", 0);
    SetFactValue(gameInstance, n"marmur_vanguard_auto_sms_apr", 0);
  }
  public func QueueAutoFinanceDenialNotice(id: TweakDBID, finalPrice: Int32, reasonCode: Int32) -> Void {

    if reasonCode == 1 && this.IsMarmurFinancialCreditAvailable() && this.GetVanguardCreditEventCount() == 0 {
      this.QueueVanguardCreditApplication();
    };

    if !this.IsInstalledVehicleRecord(id) || !this.IsPurchasable(id) {
      return;
    };

    this.PublishPhoneNotificationRecord(3010, id, finalPrice, reasonCode, this.GetActiveFinanceContractCount());
    this.PublishMarmurBankAutoLoanDenialNotice(id, finalPrice, reasonCode);
  }
  public func GetMarmurBankAutoCreditMaxPrincipal(player: ref<PlayerPuppet>) -> Int32 {
    return this.GetMarmurCreditAvailableLimit(0);
  }
  public func GetMarmurBankAutoCreditInterestBasisPoints(player: ref<PlayerPuppet>) -> Int32 {
    return this.m_marmurCreditAPR;
  }

  public func GetMarmurBankAutoCreditTierLabel(player: ref<PlayerPuppet>) -> String {
    return this.GetFinancialCreditLabel(player);
  }

  public func GetMarmurBankAutoFinancePrincipal(price: Int32, player: ref<PlayerPuppet>) -> Int32 {
    return this.GetMarmurBankAutoFinancePrincipalWithDownPayment(price, this.GetFinanceDownPaymentForPlayer(price, player));
  }

  public func GetMarmurBankAutoFinancePrincipalWithDownPayment(price: Int32, downPayment: Int32) -> Int32 {
    let principal: Int32 = price - this.ClampFinanceDownPayment(price, downPayment);

    if principal < 0 {
      return 0;
    };

    return principal;
  }

  public func CanFinanceVehicleForPlayer(price: Int32, player: ref<PlayerPuppet>) -> Bool {
    return this.CanFinanceVehicleForPlayerWithDownPayment(price, player, this.GetFinanceDownPaymentForPlayer(price, player));
  }
  public func CanFinanceVehicleForPlayerWithDownPayment(price: Int32, player: ref<PlayerPuppet>, downPayment: Int32) -> Bool {
    let down: Int32 = this.ClampFinanceDownPaymentForPlayer(price, downPayment, player);
    let principal: Int32 = this.GetMarmurBankAutoFinancePrincipalWithDownPayment(price, down);
    return IsDefined(player) && price > 0 && this.HasAvailableAutoFinanceSlot()
      && this.GetMarmurCreditDecisionCode(principal, 0) == 0
      && this.PlayerCanPay(player, this.GetFinanceDueTodayWithDownPayment(price, down));
  }

  public func GetFinanceApprovalGapForPlayer(price: Int32, player: ref<PlayerPuppet>, downPayment: Int32) -> Int32 {
    let normalizedDownPayment: Int32 = this.ClampFinanceDownPaymentForPlayer(price, downPayment, player);
    let principal: Int32 = this.GetMarmurBankAutoFinancePrincipalWithDownPayment(price, normalizedDownPayment);
    let creditMax: Int32 = this.GetMarmurBankAutoCreditMaxPrincipal(player);
    let gap: Int32 = principal - creditMax;

    if gap < 0 {
      return 0;
    };

    return gap;
  }

  private func RoundUpFinanceDownPaymentOption(amount: Int32) -> Int32 {
    let normalizedAmount: Int32 = amount;

    if normalizedAmount <= 0 {
      return 0;
    };

    if normalizedAmount < 1000 {
      return 1000;
    };

    return ((normalizedAmount + 499) / 500) * 500;
  }
  public func GetFinanceMinimumDownPaymentForApproval(price: Int32, player: ref<PlayerPuppet>) -> Int32 {
    let creditMax: Int32;
    let creditRequiredDownPayment: Int32;
    let policyMinimumDownPayment: Int32;
    let requiredDownPayment: Int32;
    let minimumDownPayment: Int32;
    let maxDownPayment: Int32 = this.GetFinanceMaxDownPaymentOption(price);

    if !IsDefined(player) || price <= 0 {
      return 0;
    };

    policyMinimumDownPayment = this.GetFinanceRequiredMinimumDownPayment(price, player);
    creditMax = this.GetMarmurBankAutoCreditMaxPrincipal(player);
    if creditMax <= 0 {
      creditRequiredDownPayment = price;
    } else {
      creditRequiredDownPayment = price - creditMax;
      if creditRequiredDownPayment < 0 {
        creditRequiredDownPayment = 0;
      };
    };

    requiredDownPayment = Max(policyMinimumDownPayment, creditRequiredDownPayment);
    if requiredDownPayment <= 0 {
      return 0;
    };

    minimumDownPayment = this.RoundUpFinanceDownPaymentOption(requiredDownPayment);
    if maxDownPayment > 0 && requiredDownPayment <= maxDownPayment && minimumDownPayment > maxDownPayment {
      return maxDownPayment;
    };

    return minimumDownPayment;
  }

  public func GetFinanceAdditionalDownPaymentNeededForApproval(price: Int32, player: ref<PlayerPuppet>, downPayment: Int32) -> Int32 {
    let currentDownPayment: Int32 = this.ClampFinanceDownPaymentForPlayer(price, downPayment, player);
    let minimumDownPayment: Int32 = this.GetFinanceMinimumDownPaymentForApproval(price, player);
    let additionalDownPayment: Int32 = minimumDownPayment - currentDownPayment;

    if additionalDownPayment < 0 {
      return 0;
    };

    return additionalDownPayment;
  }
  public func GetAutoFinanceRiskLevelForPlayer(price: Int32, termMonths: Int32, player: ref<PlayerPuppet>, downPayment: Int32) -> Int32 {
    let down: Int32 = this.ClampFinanceDownPaymentForPlayer(price, downPayment, player);
    let principal: Int32 = this.GetMarmurBankAutoFinancePrincipalWithDownPayment(price, down);
    if !IsDefined(player) || price <= 0 || !this.HasAvailableAutoFinanceSlot()
      || this.GetMarmurCreditDecisionCode(principal, 0) != 0 { return 3; };
    return this.GetFinancialCreditScore(player) < 670 ? 2 : 1;
  }
  public func DoesMediumRiskAutoFinanceApprove(price: Int32, player: ref<PlayerPuppet>, downPayment: Int32) -> Bool {
    return this.CanFinanceVehicleForPlayerWithDownPayment(price, player, downPayment);
  }
  public func GetAutoFinanceRiskLevelForPlayerAfterTradeIn(price: Int32, termMonths: Int32, player: ref<PlayerPuppet>, downPayment: Int32, tradeInVehicleIDs: array<TweakDBID>) -> Int32 {
    let down: Int32 = this.ClampFinanceDownPaymentForPlayer(price, downPayment, player);
    let principal: Int32 = this.GetMarmurBankAutoFinancePrincipalWithDownPayment(price, down);
    if !IsDefined(player) || price <= 0 || !this.HasAvailableAutoFinanceSlotAfterTradeIn(tradeInVehicleIDs)
      || this.GetMarmurCreditDecisionCode(principal, this.GetCreditReleasedByTradeIn(tradeInVehicleIDs)) != 0 { return 3; };
    return this.GetFinancialCreditScore(player) < 670 ? 2 : 1;
  }
  public func DoesMediumRiskAutoFinanceApproveAfterTradeIn(price: Int32, player: ref<PlayerPuppet>, downPayment: Int32, tradeInVehicleIDs: array<TweakDBID>) -> Bool {
    return this.CanFinanceVehicleForPlayerWithDownPaymentAfterTradeIn(price, player, downPayment, tradeInVehicleIDs);
  }
  public func CanFinanceVehicleForPlayerWithDownPaymentAfterTradeIn(price: Int32, player: ref<PlayerPuppet>, downPayment: Int32, tradeInVehicleIDs: array<TweakDBID>) -> Bool {
    let down: Int32 = this.ClampFinanceDownPaymentForPlayer(price, downPayment, player);
    let principal: Int32 = this.GetMarmurBankAutoFinancePrincipalWithDownPayment(price, down);
    return IsDefined(player) && price > 0 && this.HasAvailableAutoFinanceSlotAfterTradeIn(tradeInVehicleIDs)
      && this.GetMarmurCreditDecisionCode(principal, this.GetCreditReleasedByTradeIn(tradeInVehicleIDs)) == 0;
  }

  public func GetAutoFinanceRiskTintForLevel(riskLevel: Int32) -> CName {
    if riskLevel == 1 {
      return n"MainColors.Green";
    };

    if riskLevel == 2 {
      return n"MainColors.Yellow";
    };

    return n"MainColors.Red";
  }

  private func FormatMoneyGroup(value: Int32) -> String {
    if value < 10 {
      return s"00\(value)";
    };

    if value < 100 {
      return s"0\(value)";
    };

    return s"\(value)";
  }

  public func FormatMoney(amount: Int32) -> String {
    let value: Int32 = amount;
    let sign: String = "";
    let millions: Int32;
    let thousands: Int32;
    let remainder: Int32;

    if value < 0 {
      value = 0 - value;
      sign = "-";
    };

    if value < 1000 {
      return s"\(sign)$\(value)";
    };

    if value < 1000000 {
      thousands = value / 1000;
      remainder = value - thousands * 1000;
      return s"\(sign)$\(thousands),\(this.FormatMoneyGroup(remainder))";
    };

    millions = value / 1000000;
    remainder = value - millions * 1000000;
    thousands = remainder / 1000;
    remainder = remainder - thousands * 1000;
    return s"\(sign)$\(millions),\(this.FormatMoneyGroup(thousands)),\(this.FormatMoneyGroup(remainder))";
  }
  public func GetFinanceRequiredMinimumDownPaymentPercent(player: ref<PlayerPuppet>) -> Int32 {
    if !IsDefined(player) || this.GetFinancialCreditScore(player) < 670 { return 10; };
    return 0;
  }

  public func GetFinanceDownPaymentPercent(player: ref<PlayerPuppet>) -> Int32 {
    return this.GetFinanceRequiredMinimumDownPaymentPercent(player);
  }

  public func GetFinanceDownPaymentDisplayText(player: ref<PlayerPuppet>) -> String {
    let percent: Int32 = this.GetFinanceRequiredMinimumDownPaymentPercent(player);

    if percent <= 0 {
      return VanguardAutoLocalization.Text(1736, "No minimum");
    };

    return VanguardAutoLocalization.Text1(1737, s"\(percent)% minimum", s"\(percent)");
  }

  public func GetFinanceDownPayment(price: Int32) -> Int32 {

    let downPayment: Int32;

    if price <= 0 {
      return 0;
    };

    downPayment = this.RoundUpFinanceDownPaymentOption((price + 9) / 10);
    if downPayment > price {
      return price;
    };

    return downPayment;
  }
  public func GetFinanceRequiredMinimumDownPayment(price: Int32, player: ref<PlayerPuppet>) -> Int32 {
    let percent: Int32 = this.GetFinanceRequiredMinimumDownPaymentPercent(player);
    let minimumDownPayment: Int32;
    let maxDownPayment: Int32 = this.GetFinanceMaxDownPaymentOption(price);

    if price <= 0 || percent <= 0 || maxDownPayment <= 0 {
      return 0;
    };

    minimumDownPayment = this.RoundUpFinanceDownPaymentOption((price * percent + 99) / 100);
    if minimumDownPayment > maxDownPayment {
      return maxDownPayment;
    };

    return minimumDownPayment;
  }

  public func GetFinanceDownPaymentForPlayer(price: Int32, player: ref<PlayerPuppet>) -> Int32 {
    return this.GetFinanceRequiredMinimumDownPayment(price, player);
  }

  public func GetFinanceMaxDownPaymentOption(price: Int32) -> Int32 {
    let maxDownPayment: Int32;

    if price <= 1500 {
      return 0;
    };

    maxDownPayment = (price * 80) / 100;
    maxDownPayment = (maxDownPayment / 2500) * 2500;

    if maxDownPayment >= price {
      maxDownPayment = price - 500;
    };

    if maxDownPayment < 1000 {
      return 0;
    };

    return maxDownPayment;
  }

  public func ClampFinanceDownPayment(price: Int32, downPayment: Int32) -> Int32 {
    let maxDownPayment: Int32 = this.GetFinanceMaxDownPaymentOption(price);
    let normalizedDownPayment: Int32 = downPayment;

    if normalizedDownPayment <= 0 || maxDownPayment <= 0 {
      return 0;
    };

    if normalizedDownPayment < 1000 {
      normalizedDownPayment = 1000;
    };

    normalizedDownPayment = (normalizedDownPayment / 500) * 500;

    if normalizedDownPayment > maxDownPayment {
      return maxDownPayment;
    };

    return normalizedDownPayment;
  }

  public func ClampFinanceDownPaymentForPlayer(price: Int32, downPayment: Int32, player: ref<PlayerPuppet>) -> Int32 {
    let normalizedDownPayment: Int32 = this.ClampFinanceDownPayment(price, downPayment);
    let minimumDownPayment: Int32 = this.GetFinanceRequiredMinimumDownPayment(price, player);

    if normalizedDownPayment < minimumDownPayment {
      return minimumDownPayment;
    };

    return normalizedDownPayment;
  }

  public func GetFinanceDealerFeePercent() -> Int32 {
    return 0;
  }

  public func GetDealerFeeAmount() -> Int32 {
    return 500;
  }

  public func GetFinanceDealerFeeAmount(price: Int32) -> Int32 {
    return this.GetDealerFeeAmount();
  }

  public func GetVehiclePurchaseTotal(finalPrice: Int32) -> Int32 {
    return finalPrice + this.GetDealerFeeAmount();
  }

  public func GetFinanceDueToday(price: Int32) -> Int32 {
    return this.GetFinanceDownPayment(price) + this.GetFinanceDealerFeeAmount(price);
  }

  public func GetFinanceDueTodayForPlayer(price: Int32, player: ref<PlayerPuppet>) -> Int32 {
    return this.GetFinanceDownPaymentForPlayer(price, player) + this.GetFinanceDealerFeeAmount(price);
  }

  public func GetFinanceDueTodayWithDownPayment(price: Int32, downPayment: Int32) -> Int32 {
    return this.ClampFinanceDownPayment(price, downPayment) + this.GetFinanceDealerFeeAmount(price);
  }

  public func GetFinanceDealerFeeDisplayText(price: Int32) -> String {
    return this.FormatMoney(this.GetDealerFeeAmount());
  }

  public func GetFinanceNextPaymentDueDayText(id: TweakDBID) -> String {
    let dueMinute: Int32 = this.GetCurrentGameMinute() + 43200;
    let currentMinute: Int32 = this.GetCurrentGameMinute();
    let remainingMinutes: Int32;
    let daysRemaining: Int32;
    let i: Int32 = 0;

    while i < ArraySize(this.m_financeVehicleIDs) {
      if Equals(this.m_financeVehicleIDs[i], id) {
        dueMinute = this.m_financeNextPaymentMinutes[i];
        i = ArraySize(this.m_financeVehicleIDs);
      } else {
        i += 1;
      };
    };

    if this.IsFinancePaymentDelinquent(id) { return "Past due"; };
    remainingMinutes = dueMinute - currentMinute;
    if remainingMinutes <= 0 {
      return VanguardAutoLocalization.Text(1738, "Due now");
    };

    daysRemaining = (remainingMinutes + 1439) / 1440;
    if daysRemaining <= 1 {
      return VanguardAutoLocalization.Text(1739, "1 day");
    };

    return VanguardAutoLocalization.Text1(1338, s"\(daysRemaining) days", s"\(daysRemaining)");
  }
  public func NormalizeFinanceTerm(termMonths: Int32) -> Int32 {
    return 60;
  }
  public func GetFinanceInterestBasisPoints(termMonths: Int32, player: ref<PlayerPuppet>) -> Int32 {

    if this.GetSelectedPromotionOfferCode() == 8 {
      if this.IsPromotionOfferAvailable(8, player) {
        return 299;
      };
    };

    return this.GetMarmurBankAutoCreditInterestBasisPoints(player);
  }

  public func GetFinanceInterestPercent(termMonths: Int32, player: ref<PlayerPuppet>) -> Int32 {
    return (this.GetFinanceInterestBasisPoints(termMonths, player) + 99) / 100;
  }

  public func GetFinanceInterestDisplayText(termMonths: Int32, player: ref<PlayerPuppet>) -> String {
    let basisPoints: Int32 = this.GetFinanceInterestBasisPoints(termMonths, player);
    let whole: Int32 = basisPoints / 100;
    let decimalTens: Int32 = (basisPoints % 100) / 10;
    let decimalOnes: Int32 = basisPoints % 10;

    return s"\(whole).\(decimalTens)\(decimalOnes)%";
  }

  public func GetFinanceTotalDue(price: Int32, termMonths: Int32, player: ref<PlayerPuppet>) -> Int32 {
    return this.GetFinanceTotalDueWithDownPayment(price, termMonths, player, this.GetFinanceDownPaymentForPlayer(price, player));
  }
  public func GetFinanceTotalDueWithDownPayment(price: Int32, termMonths: Int32, player: ref<PlayerPuppet>, downPayment: Int32) -> Int32 {
    let normalizedTerm: Int32 = this.NormalizeFinanceTerm(termMonths);
    let normalizedDownPayment: Int32 = this.ClampFinanceDownPaymentForPlayer(price, downPayment, player);
    let financedAmount: Int32 = price - normalizedDownPayment;
    let interestBasisPoints: Int32 = this.GetFinanceInterestBasisPoints(normalizedTerm, player);
    let interestAmount: Int32;

    if financedAmount < 0 {
      financedAmount = 0;
    };

    interestAmount = Cast<Int32>((Cast<Double>(financedAmount) * Cast<Double>(interestBasisPoints)) / Cast<Double>(10000.0));
    return financedAmount + interestAmount;
  }

  public func GetFinanceMonthlyPayment(price: Int32, termMonths: Int32, player: ref<PlayerPuppet>) -> Int32 {
    return this.GetFinanceMonthlyPaymentWithDownPayment(price, termMonths, player, this.GetFinanceDownPaymentForPlayer(price, player));
  }
  public func GetFinanceMonthlyPaymentWithDownPayment(price: Int32, termMonths: Int32, player: ref<PlayerPuppet>, downPayment: Int32) -> Int32 {
    let normalizedTerm: Int32 = this.NormalizeFinanceTerm(termMonths);
    let totalDue: Int32 = this.GetFinanceTotalDueWithDownPayment(price, normalizedTerm, player, downPayment);

    return Max(1, (totalDue + normalizedTerm - 1) / normalizedTerm);
  }

  private func ClampStreetCred(streetCred: Int32) -> Int32 {
    if streetCred < 0 {
      return 0;
    };

    if streetCred > 50 {
      return 50;
    };

    return streetCred;
  }

  public func GetCurrentStreetCredLevel(player: ref<PlayerPuppet>) -> Int32 {
    return this.GetFinancialCreditScore(player);
  }

  public func GetStreetCredCreditworthinessLabel(player: ref<PlayerPuppet>) -> String {
    return this.GetFinancialCreditLabel(player);
  }

  public func GetStreetCredCreditworthinessTint(player: ref<PlayerPuppet>) -> CName {
    return this.GetFinancialCreditTint(player);
  }

  public func GetStreetCredCreditworthinessSummary(player: ref<PlayerPuppet>) -> String {
    return this.GetFinancialCreditSummary(player);
  }

  private func GetFinanceOriginalStreetCredIndex(id: TweakDBID) -> Int32 {
    let i: Int32 = 0;

    while i < ArraySize(this.m_financeStreetCredVehicleIDs) {
      if Equals(this.m_financeStreetCredVehicleIDs[i], id) {
        return i;
      };
      i += 1;
    };

    return -1;
  }

  private func SetFinanceOriginalStreetCred(id: TweakDBID, streetCred: Int32) -> Void {

  }

  private func RemoveFinanceOriginalStreetCredState(id: TweakDBID) -> Void {
    let newVehicleIDs: array<TweakDBID>;
    let newStreetCreds: array<Int32>;
    let i: Int32 = 0;

    while i < ArraySize(this.m_financeStreetCredVehicleIDs) {
      if NotEquals(this.m_financeStreetCredVehicleIDs[i], id) {
        ArrayPush(newVehicleIDs, this.m_financeStreetCredVehicleIDs[i]);
        ArrayPush(newStreetCreds, this.m_financeOriginalStreetCredLevels[i]);
      };
      i += 1;
    };

    this.m_financeStreetCredVehicleIDs = newVehicleIDs;
    this.m_financeOriginalStreetCredLevels = newStreetCreds;
  }

  public func GetFinanceOriginalStreetCredForVehicle(id: TweakDBID, player: ref<PlayerPuppet>) -> Int32 {
    return this.GetFinancialCreditScore(player);
  }

  private func EnsureFinanceOriginalStreetCredSnapshots(player: ref<PlayerPuppet>) -> Void {

  }

  private func PlayerCanPay(player: ref<PlayerPuppet>, amount: Int32) -> Bool {
    if !IsDefined(player) || amount <= 0 {
      return false;
    };

    return this.m_transactionSystem.GetItemQuantity(player, MarketSystem.Money()) >= amount;
  }

  private func ShouldLogFinanceEvent(kind: Int32) -> Bool {

    if kind == 1 || kind == 3 {
      return true;
    };

    return false;
  }

  private func PushFinanceEvent(id: TweakDBID, kind: Int32, amount: Int32, remainingMonths: Int32, termMonths: Int32, monthlyPayment: Int32) -> Void {
    this.PushFinanceEventWithPaymentSource(id, kind, amount, remainingMonths, termMonths, monthlyPayment, 1);
  }
  private func PushFinanceEventWithPaymentSource(id: TweakDBID, kind: Int32, amount: Int32, remainingMonths: Int32, termMonths: Int32, monthlyPayment: Int32, paymentSource: Int32) -> Void {
    while ArraySize(this.m_financeEventPaymentSources) < ArraySize(this.m_financeEventKinds) {
      ArrayPush(this.m_financeEventPaymentSources, 1);
    };

    while ArraySize(this.m_marmurAutoEventContractSerials) < ArraySize(this.m_financeEventKinds) {
      ArrayPush(this.m_marmurAutoEventContractSerials, 0);
    };
    ArrayPush(this.m_marmurAutoEventContractSerials, this.EnsureFinanceContractSerial(id));
    ArrayPush(this.m_financeEventVehicleIDs, id);
    ArrayPush(this.m_financeEventKinds, kind);
    ArrayPush(this.m_financeEventMinutes, this.GetCurrentGameMinute());
    ArrayPush(this.m_financeEventAmounts, amount);
    ArrayPush(this.m_financeEventRemainingMonths, remainingMonths);
    ArrayPush(this.m_financeEventTerms, termMonths);
    ArrayPush(this.m_financeEventMonthlyPayments, monthlyPayment);
    ArrayPush(this.m_financeEventPaymentSources, this.NormalizeFinancePaymentSource(paymentSource));

  }

  private func HasFinanceNotice(id: TweakDBID, kind: Int32, cycleMinute: Int32) -> Bool {
    let i: Int32 = 0;

    while i < ArraySize(this.m_financeNoticeVehicleIDs) {
      if Equals(this.m_financeNoticeVehicleIDs[i], id) && this.m_financeNoticeKinds[i] == kind && this.m_financeNoticeCycleMinutes[i] == cycleMinute {
        return true;
      };
      i += 1;
    };

    return false;
  }
  private func QueueFinanceNotice(id: TweakDBID, kind: Int32, cycleMinute: Int32, amount: Int32, remainingMonths: Int32, termMonths: Int32, monthlyPayment: Int32) -> Void {
    if !TDBID.IsValid(id) || kind <= 0 || cycleMinute <= 0 {
      return;
    };

    if this.HasFinanceNotice(id, kind, cycleMinute) {
      return;
    };

    ArrayPush(this.m_financeNoticeVehicleIDs, id);
    ArrayPush(this.m_financeNoticeKinds, kind);
    ArrayPush(this.m_financeNoticeCycleMinutes, cycleMinute);
    this.PushFinanceEvent(id, kind, amount, remainingMonths, termMonths, monthlyPayment);
  }

  private func RemoveFinanceNoticeState(id: TweakDBID) -> Void {
    let newVehicleIDs: array<TweakDBID>;
    let newKinds: array<Int32>;
    let newCycleMinutes: array<Int32>;
    let i: Int32 = 0;

    while i < ArraySize(this.m_financeNoticeVehicleIDs) {
      if NotEquals(this.m_financeNoticeVehicleIDs[i], id) {
        ArrayPush(newVehicleIDs, this.m_financeNoticeVehicleIDs[i]);
        ArrayPush(newKinds, this.m_financeNoticeKinds[i]);
        ArrayPush(newCycleMinutes, this.m_financeNoticeCycleMinutes[i]);
      };
      i += 1;
    };

    this.m_financeNoticeVehicleIDs = newVehicleIDs;
    this.m_financeNoticeKinds = newKinds;
    this.m_financeNoticeCycleMinutes = newCycleMinutes;
  }
  private func QueueFinancePaymentReminderEvents(id: TweakDBID, dueMinute: Int32, now: Int32, amount: Int32, remainingMonths: Int32, termMonths: Int32, monthlyPayment: Int32, isRepossessed: Bool, isDelinquent: Bool) -> Void {
    let remainingMinutes: Int32 = dueMinute - now;

    if amount <= 0 || dueMinute <= 0 || isRepossessed || isDelinquent {
      return;
    };

    if remainingMinutes > 1440 && remainingMinutes <= 4320 {
      this.QueueFinanceNotice(id, 10, dueMinute, amount, remainingMonths, termMonths, monthlyPayment);
      return;
    };

    if remainingMinutes > 720 && remainingMinutes <= 1440 {
      this.QueueFinanceNotice(id, 11, dueMinute, amount, remainingMonths, termMonths, monthlyPayment);
      return;
    };

    if remainingMinutes > 0 && remainingMinutes <= 720 {
      this.QueueFinanceNotice(id, 12, dueMinute, amount, remainingMonths, termMonths, monthlyPayment);
    };
  }
  private func QueueFinanceDelinquencyWarningEvents(id: TweakDBID, defaultStartMinute: Int32, now: Int32, amount: Int32, remainingMonths: Int32, termMonths: Int32, monthlyPayment: Int32, isRepossessed: Bool) -> Void {
    let lateMinutes: Int32 = now - defaultStartMinute;

    if amount <= 0 || defaultStartMinute <= 0 || isRepossessed {
      return;
    };

    if lateMinutes >= 8640 && lateMinutes < 10080 {
      this.QueueFinanceNotice(id, 17, defaultStartMinute, amount, remainingMonths, termMonths, monthlyPayment);
      return;
    };

    if lateMinutes >= 5760 && lateMinutes < 8640 {
      this.QueueFinanceNotice(id, 16, defaultStartMinute, amount, remainingMonths, termMonths, monthlyPayment);
      return;
    };

    if lateMinutes >= 2880 && lateMinutes < 5760 {
      this.QueueFinanceNotice(id, 15, defaultStartMinute, amount, remainingMonths, termMonths, monthlyPayment);
    };
  }

  private func GetFinanceDefaultIndex(id: TweakDBID) -> Int32 {
    let i: Int32 = 0;

    while i < ArraySize(this.m_financeDefaultVehicleIDs) {
      if Equals(this.m_financeDefaultVehicleIDs[i], id) {
        return i;
      };
      i += 1;
    };

    return -1;
  }

  private func GetFinanceRepossessionIndex(id: TweakDBID) -> Int32 {
    let i: Int32 = 0;

    while i < ArraySize(this.m_financeRepossessedVehicleIDs) {
      if Equals(this.m_financeRepossessedVehicleIDs[i], id) {
        return i;
      };
      i += 1;
    };

    return -1;
  }

  public func IsVehicleRepossessed(id: TweakDBID) -> Bool {
    return this.GetFinanceRepossessionIndex(id) >= 0;
  }

  public func IsVehicleDefaulted(id: TweakDBID) -> Bool {
    return this.IsVehicleRepossessed(id);
  }

  public func IsFinancePaymentDelinquent(id: TweakDBID) -> Bool {
    return this.GetFinanceDefaultIndex(id) >= 0;
  }

  private func StartFinanceDefaultState(id: TweakDBID, dueMinute: Int32, amount: Int32, remainingMonths: Int32, termMonths: Int32, monthlyPayment: Int32) -> Void {
    this.StartFinanceDefaultStateWithEventKind(id, dueMinute, amount, remainingMonths, termMonths, monthlyPayment, 9);
  }
  private func StartFinanceDefaultStateWithEventKind(id: TweakDBID, dueMinute: Int32, amount: Int32, remainingMonths: Int32, termMonths: Int32, monthlyPayment: Int32, eventKind: Int32) -> Void {
    if this.IsVehicleRepossessed(id) {
      return;
    };

    if this.GetFinanceDefaultIndex(id) >= 0 {
      return;
    };

    ArrayPush(this.m_financeDefaultVehicleIDs, id);
    ArrayPush(this.m_financeDefaultStartMinutes, dueMinute);
    this.QueueFinanceNotice(id, eventKind, dueMinute, amount, remainingMonths, termMonths, monthlyPayment);
  }
  private func ClearFinanceDefaultState(id: TweakDBID) -> Void {
    let newVehicleIDs: array<TweakDBID>;
    let newStartMinutes: array<Int32>;
    let i: Int32 = 0;

    while i < ArraySize(this.m_financeDefaultVehicleIDs) {
      if NotEquals(this.m_financeDefaultVehicleIDs[i], id) {
        ArrayPush(newVehicleIDs, this.m_financeDefaultVehicleIDs[i]);
        ArrayPush(newStartMinutes, this.m_financeDefaultStartMinutes[i]);
      };
      i += 1;
    };

    this.m_financeDefaultVehicleIDs = newVehicleIDs;
    this.m_financeDefaultStartMinutes = newStartMinutes;
  }
  private func ClearFinanceRepossessionState(id: TweakDBID) -> Void {
    let newVehicleIDs: array<TweakDBID>;
    let i: Int32 = 0;

    while i < ArraySize(this.m_financeRepossessedVehicleIDs) {
      if NotEquals(this.m_financeRepossessedVehicleIDs[i], id) {
        ArrayPush(newVehicleIDs, this.m_financeRepossessedVehicleIDs[i]);
      };
      i += 1;
    };

    this.m_financeRepossessedVehicleIDs = newVehicleIDs;
    this.m_deactivateVehiclesDirty = true;
  }
  private func ShouldRepossessFinanceContract(id: TweakDBID, now: Int32) -> Bool {
    let index: Int32 = this.GetFinanceDefaultIndex(id);

    if index < 0 || this.IsVehicleRepossessed(id) {
      return false;
    };

    return now >= this.m_financeDefaultStartMinutes[index] + 10080;
  }
  private func MarkVehicleRepossessed(id: TweakDBID, amount: Int32, remainingMonths: Int32, termMonths: Int32, monthlyPayment: Int32) -> Void {
    if !this.IsMarmurBankAutoFinanceAvailable() { return; };

    if this.IsVehicleRepossessed(id) {
      this.RemoveRepossessedVehicleFromWorld(id);
      return;
    };

    this.RegisterVanguardCreditContract(id, true);
    this.RecordVanguardCreditRepossession(id);
    ArrayPush(this.m_financeRepossessedVehicleIDs, id);
    this.m_deactivateVehiclesDirty = true;
    this.m_financeContractsDirty = true;
    this.InvalidateNCGTAppreciation(id);
    this.RemoveNCGTPerformancePackageState(id);
    this.ClearFinanceDefaultState(id);
    this.RemoveRepossessedVehicleFromWorld(id);
    this.PushFinanceEvent(id, 3, amount, remainingMonths, termMonths, monthlyPayment);
  }

  private func RemoveRepossessedVehicleFromWorld(id: TweakDBID) -> Void {
    if !TDBID.IsValid(id) || !IsDefined(this.m_vehicleSystem) {
      return;
    };

    this.m_vehicleSystem.TogglePlayerActiveVehicle(Cast<GarageVehicleID>(id), gamedataVehicleType.Car, false);
    this.m_vehicleSystem.TogglePlayerActiveVehicle(Cast<GarageVehicleID>(id), gamedataVehicleType.Bike, false);
    ClearVehiclePersistence(this.GetGameInstance(), id);
  }
  private func RemoveFinanceContractSilent(id: TweakDBID) -> Void {
    let newVehicleIDs: array<TweakDBID>;
    let newTerms: array<Int32>;
    let newMonthlyPayments: array<Int32>;
    let newRemainingMonths: array<Int32>;
    let newNextPaymentMinutes: array<Int32>;
    let newTotalDue: array<Int32>;
    let newDownPayments: array<Int32>;
    let newInterestPercents: array<Int32>;
    let newPaidAmounts: array<Int32>;
    let i: Int32 = 0;

    while i < ArraySize(this.m_financeVehicleIDs) {
      if NotEquals(this.m_financeVehicleIDs[i], id) {
        ArrayPush(newVehicleIDs, this.m_financeVehicleIDs[i]);
        ArrayPush(newTerms, this.m_financeTerms[i]);
        ArrayPush(newMonthlyPayments, this.m_financeMonthlyPayments[i]);
        ArrayPush(newRemainingMonths, this.m_financeRemainingMonths[i]);
        ArrayPush(newNextPaymentMinutes, this.m_financeNextPaymentMinutes[i]);
        ArrayPush(newTotalDue, this.m_financeTotalDue[i]);
        ArrayPush(newDownPayments, this.m_financeDownPayments[i]);
        ArrayPush(newInterestPercents, this.m_financeInterestPercents[i]);
        ArrayPush(newPaidAmounts, this.GetFinancePaidAmountByIndex(i));
      };
      i += 1;
    };

    this.m_financeVehicleIDs = newVehicleIDs;
    this.m_financeTerms = newTerms;
    this.m_financeMonthlyPayments = newMonthlyPayments;
    this.m_financeRemainingMonths = newRemainingMonths;
    this.m_financeNextPaymentMinutes = newNextPaymentMinutes;
    this.m_financeTotalDue = newTotalDue;
    this.m_financeDownPayments = newDownPayments;
    this.m_financeInterestPercents = newInterestPercents;
    this.m_financePaidAmounts = newPaidAmounts;
    this.m_financeContractsDirty = true;
    this.RemoveFinanceAutoPayState(id);
    this.RemoveFinancePaymentFrequencyState(id);
    this.RemoveFinanceOriginalStreetCredState(id);
    this.RemoveFinanceNoticeState(id);
    this.ClearFinanceDefaultState(id);
    this.ClearFinanceRepossessionState(id);
  }

  public func ArePromoAlertsEnabled() -> Bool {
    return this.IsVanguardAlertCategoryEnabled(4);
  }

  public func TogglePromoAlerts() -> Bool {
    this.EnsureVanguardAlertPreferences();
    this.m_promoAlertsDisabled = !this.m_promoAlertsDisabled;
    this.m_vanguardAlertsRevision += 1;
    this.DiscardVanguardAlertBacklog();
    return !this.m_promoAlertsDisabled;
  }

  public func AreVanguardAlertsEnabled() -> Bool {
    return this.AreVanguardAlertSectionEnabled(false) || this.AreVanguardAlertSectionEnabled(true);
  }

  public func GetVanguardAlertsRevision() -> Int32 {
    return this.m_vanguardAlertsRevision;
  }

  public func DiscardVanguardAlertBacklog() -> Void {

    ArrayClear(this.m_vanguardDeferredPhoneMessageKinds);
    ArrayClear(this.m_vanguardDeferredPhoneMessageVehicleIDs);
    ArrayClear(this.m_vanguardDeferredPhoneMessageAmounts);
    ArrayClear(this.m_vanguardDeferredPhoneMessageAux1);
    ArrayClear(this.m_vanguardDeferredPhoneMessageAux2);
    ArrayClear(this.m_vanguardDeferredPhoneMessageMinutes);
    ArrayClear(this.m_followupVehicleIDs);
    ArrayClear(this.m_followupModes);
    ArrayClear(this.m_followupTimes);
    ArrayClear(this.m_saleFollowupVehicleIDs);
    ArrayClear(this.m_saleFollowupTimes);
    this.MarkPhoneMessagesDelivered(this.GetNotificationHistoryCount());

  }

  private func PushPromoAlertEvent(kind: Int32) -> Void {
    ArrayPush(this.m_promoAlertEventKinds, kind);
    ArrayPush(this.m_promoAlertEventMinutes, this.GetCurrentGameMinute());

    this.PublishPhoneNotificationRecord(2000 + kind, t"VanguardAuto.Phone.NoVehicle", 0, 0, 0);
  }

  public func UpdatePromoCampaignAlerts(player: ref<PlayerPuppet>) -> Void {
    let now: Int32;
    let code: Int32;

    this.FlushDeferredPhoneNotifications();

    if !IsDefined(player) || !this.ArePromoAlertsEnabled() {
      return;
    };

    now = this.GetCurrentGameMinute();
    if now > 0 && now == this.m_lastPromoCampaignScanMinute {
      return;
    };
    this.m_lastPromoCampaignScanMinute = now;

    if this.IsInDangerZone(player) {
      return;
    };

    code = this.ResolveCurrentCampaignCode(player);

    if code <= 0 || now <= 0 {
      return;
    };

    if !this.IsPromotionOfferAvailable(code, player) || !this.HasPromotionEligibleInventory(code, player) {
      return;
    };

    if this.m_lastPromoCampaignAlertCode == code {
      return;
    };

    if this.m_lastPromoCampaignAlertMinute > 0 && now < this.m_lastPromoCampaignAlertMinute + 10080 {
      return;
    };

    this.m_lastPromoCampaignAlertMinute = now;
    this.m_lastPromoCampaignAlertCode = code;
    this.PushPromoAlertEvent(100 + code);
  }

  public func GetPromoAlertEventCount() -> Int32 {
    return ArraySize(this.m_promoAlertEventKinds);
  }

  public func GetPromoAlertEventKindAt(index: Int32) -> Int32 {
    if index < 0 || index >= ArraySize(this.m_promoAlertEventKinds) {
      return 0;
    };

    return this.m_promoAlertEventKinds[index];
  }

  public func GetPromoAlertEventMinuteAt(index: Int32) -> Int32 {
    if index < 0 || index >= ArraySize(this.m_promoAlertEventMinutes) {
      return 0;
    };

    return this.m_promoAlertEventMinutes[index];
  }

  private func GetPromoAlertSalesMessageByCampaignCode(code: Int32) -> String {
    switch code {
      case 1:
        return VanguardAutoLocalization.Text(1740, "Vanguard Auto Sales: New customer cash is available on eligible inventory. Select the offer before checkout.");
      case 2:
        return VanguardAutoLocalization.Text(1741, "Vanguard Auto Sales: Trade-in bonus is active. Stage an eligible garage vehicle at checkout to boost its trade-in value by 15%.");
      case 3:
        return VanguardAutoLocalization.Text(1742, "Vanguard Auto Sales: Today's dealer cash allowance is active. Eligible showroom pricing can use the current daily offer.");
      case 4:
        return VanguardAutoLocalization.Text(1743, "Vanguard Auto Sales: End-of-sales-week bonus cash is active on eligible inventory.");
      case 5:
        return VanguardAutoLocalization.Text(1744, "Vanguard Auto Sales: A rotating inventory allowance is active. Qualifying price tiers now have limited-time savings.");
      case 6:
        return VanguardAutoLocalization.Text(1745, "Vanguard Auto Sales: Owner loyalty cash is active for returning customers.");
      case 7:
        return VanguardAutoLocalization.Text(1746, "Vanguard Auto Sales: Premium model cash allowance is active on qualified high-value inventory.");
      case 8:
        return VanguardAutoLocalization.Text(1747, "Vanguard Auto Sales: Preferred finance rate is active. Qualified 60-month contracts can use reduced APR at checkout.");
      case 9:
        return VanguardAutoLocalization.Text(1748, "Vanguard Auto Sales: Garage conquest cash is active for new Vanguard customers with an existing garage vehicle.");
      case 10:
        return VanguardAutoLocalization.Text(1749, "Vanguard Auto Sales: Weekend sales event cash is active on eligible inventory.");
      case 11:
        return VanguardAutoLocalization.Text(1750, "Vanguard Auto Sales: Repeat buyer bonus cash is active for customers with multiple prior purchases.");
      case 12:
        return VanguardAutoLocalization.Text(1751, "Vanguard Auto Sales: Model-year closeout cash is active on eligible premium inventory.");
    };

    return VanguardAutoLocalization.Text(1752, "Vanguard Auto Sales: A limited dealership offer is active. Check the showroom for eligible vehicles.");
  }

  public func GetPromoAlertEventMessageAt(index: Int32) -> String {
    let kind: Int32 = this.GetPromoAlertEventKindAt(index);
    let campaignCode: Int32;

    if kind == 1 {
      return VanguardAutoLocalization.Text(1753, "Vanguard Auto: Promo phone notifications are now enabled. Sales alerts are limited to meaningful campaign changes and will not repeat every load.");
    };

    if kind == 2 {
      return VanguardAutoLocalization.Text(1754, "Vanguard Auto: Promo phone notifications are now disabled. Dealership offers will still appear on the website.");
    };

    if kind >= 101 && kind <= 112 {
      campaignCode = kind - 100;
      return this.GetPromoAlertSalesMessageByCampaignCode(campaignCode);
    };

    return VanguardAutoLocalization.Text(1755, "Vanguard Auto: Promo phone notification preference updated.");
  }

  public func GetVehicleDisplayName(id: TweakDBID) -> String {
    let record: ref<Vehicle_Record> = TweakDBInterface.GetVehicleRecord(id);
    if IsDefined(record) {
      return GetLocalizedTextByKey(record.DisplayName());
    };
    return "vehicle";
  }

  public func IsVanguardCoverageVehicleIneligible(id: TweakDBID) -> Bool {
    let record: ref<Vehicle_Record>;
    let recordKey: String;
    let displayName: String;

    if !TDBID.IsValid(id) {
      return false;
    };

    recordKey = UTF8StrLower(TDBID.ToStringDEBUG(id));
    if StrContains(recordKey, "delamain") {
      return true;
    };

    record = TweakDBInterface.GetVehicleRecord(id);
    if IsDefined(record) {
      displayName = UTF8StrLower(GetLocalizedTextByKey(record.DisplayName()));
      if StrContains(displayName, "delamain") {
        return true;
      };
    };

    return false;
  }

  private func IsPhoneNotificationSuppressed() -> Bool {
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    let bb: ref<IBlackboard>;
    let braindanceBB: ref<IBlackboard>;
    let quests: ref<QuestsSystem>;
    let sceneTier: Int32;
    let playerRecord: String;

    if !IsDefined(player) {
      return true;
    };

    bb = player.GetPlayerStateMachineBlackboard();
    if IsDefined(bb) {
      sceneTier = bb.GetInt(GetAllBlackboardDefs().PlayerStateMachine.SceneTier);
      if sceneTier >= 3 {
        return true;
      };
    };

    braindanceBB = GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().Braindance);
    if IsDefined(braindanceBB) && braindanceBB.GetBool(GetAllBlackboardDefs().Braindance.IsActive) {
      return true;
    };

    quests = GameInstance.GetQuestsSystem(this.GetGameInstance());
    if IsDefined(quests) {
      if quests.GetFact(n"q101_01_firestorm_active") > 0 || quests.GetFact(n"q101_firestorm_active") > 0 || quests.GetFact(n"q108_johnny_active") > 0 || quests.GetFact(n"q108_active") > 0 {
        return true;
      };
    };

    playerRecord = UTF8StrLower(TDBID.ToStringDEBUG(player.GetRecordID()));
    if StrContains(playerRecord, "johnny") || StrContains(playerRecord, "silverhand") {
      return true;
    };

    return false;
  }

  private func GetPhoneMessageTextByData(kind: Int32, vehicleID: TweakDBID, amount: Int32, aux1: Int32, aux2: Int32) -> String {
    let vehicleName: String;
    let financeKind: Int32;
    let promoKind: Int32;
    let campaignCode: Int32;
    let rewardPercent: Int32;
    let termLabel: String;

    if kind >= 1001 && kind <= 1018 {
      vehicleName = this.GetVehicleDisplayName(vehicleID);
      financeKind = kind - 1000;

      if financeKind != 1 && financeKind != 3 {
        return "";
      };

      if financeKind == 1 {
        return VanguardAutoLocalization.Text1(1869, s"Vanguard Auto: Financing approved for \(vehicleName). Vehicle delivery is complete. Your selected Auto-Pay request and payment schedule were submitted to Marmur Bank for servicing in Marmur Bank > Loans.", s"\(vehicleName)");
      };
      if financeKind == 2 {
        return VanguardAutoLocalization.Text3(1863, s"Marmur Bank Auto Loans: Scheduled payment of \(this.FormatMoney(amount)) was posted for \(vehicleName). \(aux1) scheduled payments remain.", s"\(this.FormatMoney(amount))", s"\(vehicleName)", s"\(aux1)");
      };
      if financeKind == 3 {
        return VanguardAutoLocalization.Text1(1758, s"Vanguard Auto Finance: Repossession complete for \(vehicleName). Payment was not received within the contractual grace period. Vehicle access and summon privileges are suspended.", s"\(vehicleName)");
      };
      if financeKind == 4 {
        return VanguardAutoLocalization.Text1(1864, s"Marmur Bank Auto Loans: Final scheduled payment received for \(vehicleName). The title is now clear.", s"\(vehicleName)");
      };
      if financeKind == 5 {
        return VanguardAutoLocalization.Text1(1760, s"Vanguard Auto Finance: Payoff received for \(vehicleName). The title is now clear.", s"\(vehicleName)");
      };
      if financeKind == 6 {
        return VanguardAutoLocalization.Text2(1761, s"Vanguard Auto Finance: Extra payment of \(this.FormatMoney(amount)) received for \(vehicleName). Remaining balance has been updated.", s"\(this.FormatMoney(amount))", s"\(vehicleName)");
      };
      if financeKind == 7 {
        return VanguardAutoLocalization.Text1(1865, s"Marmur Bank Auto Loans: Auto-Pay is now enabled for \(vehicleName).", s"\(vehicleName)");
      };
      if financeKind == 8 {
        return VanguardAutoLocalization.Text1(1866, s"Marmur Bank Auto Loans: Auto-Pay has been disabled for \(vehicleName). Open Marmur Bank > Loans to make payments.", s"\(vehicleName)");
      };
      if financeKind == 9 {
        return VanguardAutoLocalization.Text1(1764, s"Vanguard Auto Finance: Payment missed for \(vehicleName). The account is now past due. Submit payment in Marmur Bank > Loans to avoid recovery review.", s"\(vehicleName)");
      };
      if financeKind == 10 {
        return VanguardAutoLocalization.Text2(1765, s"Vanguard Auto Finance: Upcoming payment reminder. \(this.FormatMoney(amount)) is scheduled for \(vehicleName) in roughly 3 days.", s"\(this.FormatMoney(amount))", s"\(vehicleName)");
      };
      if financeKind == 11 {
        return VanguardAutoLocalization.Text2(1766, s"Vanguard Auto Finance: Payment reminder. \(this.FormatMoney(amount)) is due for \(vehicleName) within 24 hours.", s"\(this.FormatMoney(amount))", s"\(vehicleName)");
      };
      if financeKind == 12 {
        return VanguardAutoLocalization.Text2(1767, s"Vanguard Auto Finance: Payment due today. \(this.FormatMoney(amount)) is scheduled for \(vehicleName).", s"\(this.FormatMoney(amount))", s"\(vehicleName)");
      };
      if financeKind == 13 {
        return VanguardAutoLocalization.Text2(1867, s"Marmur Bank Auto Loans: Auto-Pay failed for \(vehicleName). We could not process \(this.FormatMoney(amount)). Submit a scheduled payment in Marmur Bank > Loans to prevent recovery action.", s"\(vehicleName)", s"\(this.FormatMoney(amount))");
      };
      if financeKind == 15 {
        return VanguardAutoLocalization.Text1(1769, s"Vanguard Auto Finance: Late payment notice for \(vehicleName). The account remains past due and may receive additional review if payment is not received.", s"\(vehicleName)");
      };
      if financeKind == 16 {
        return VanguardAutoLocalization.Text1(1770, s"Vanguard Auto Finance: Pre-repossession notice for \(vehicleName). Continued nonpayment may result in vehicle recovery action.", s"\(vehicleName)");
      };
      if financeKind == 17 {
        return VanguardAutoLocalization.Text1(1771, s"Vanguard Auto Finance: Final pre-repossession warning for \(vehicleName). Payment is required before the next account review cycle to avoid repossession.", s"\(vehicleName)");
      };
      if financeKind == 18 {
        return s"Vanguard Auto Finance: Refinance accepted for \(vehicleName). New contract balance: \(this.FormatMoney(amount)) over \(aux1) months at \(this.FormatMoney(aux2))/mo. Terms were based on current credit profile.";
      };
      return VanguardAutoLocalization.Text(1772, "Vanguard Auto: Garage account status updated.");
    };

    if kind >= 2000 && kind <= 2200 {
      promoKind = kind - 2000;
      if promoKind == 1 {
        return VanguardAutoLocalization.Text(1753, "Vanguard Auto: Promo phone notifications are now enabled. Sales alerts are limited to meaningful campaign changes and will not repeat every load.");
      };
      if promoKind == 2 {
        return VanguardAutoLocalization.Text(1754, "Vanguard Auto: Promo phone notifications are now disabled. Dealership offers will still appear on the website.");
      };
      if promoKind >= 101 && promoKind <= 112 {
        campaignCode = promoKind - 100;
        return this.GetPromoAlertSalesMessageByCampaignCode(campaignCode);
      };
      return VanguardAutoLocalization.Text(1755, "Vanguard Auto: Promo phone notification preference updated.");
    };

    vehicleName = this.GetVehicleDisplayName(vehicleID);
    if kind == 3101 {
      return s"Vanguard Auto Claims Notice: \(vehicleName) has been classified as a total loss. Claim CLM-\(aux1) requires settlement review. Open Vanguard Auto > Coverage to review the settlement agreement.";
    };
    if kind == 3102 {
      if amount == 1 {
        return s"Vanguard Auto Claims Notice: Settlement review for \(vehicleName) has been denied. Reason: recent total-loss settlement activity is still inside Vanguard Auto Insurance's \(aux2)-day claim frequency review window. No settlement payment will be issued at this time. Review window remaining: \(aux1) day(s).";
      };
      if amount == 2 {
        return s"Vanguard Auto Claims Notice: Settlement review for \(vehicleName) has been denied. Reason: the vehicle is not eligible for a total-loss settlement under the active policy record. No settlement payment will be issued.";
      };
      if amount == 3 {
        return s"Vanguard Auto Claims Notice: Settlement review for \(vehicleName) has been denied. Reason: an unresolved total-loss settlement is already pending on this policy. Review the active settlement before opening another claim.";
      };
      return s"Vanguard Auto Claims Notice: Settlement review for \(vehicleName) has been denied. Reason: the claim could not be approved under the current policy review rules. No settlement payment will be issued.";
    };
    if kind == 3103 {
      rewardPercent = aux1;
      if rewardPercent <= 0 { rewardPercent = 22; };
      termLabel = "6-month";
      if aux2 >= 12 { termLabel = "12-month"; };
      return s"Vanguard Auto Insurance: Good Driver Appreciation applied. No at-fault accidents have been recorded for 7 days, so your paid-in-full \(termLabel) policy earned a \(rewardPercent)% reward credit. Credit issued: \(this.FormatMoney(amount)).";
    };
    if kind == 3104 {
      rewardPercent = aux1;
      if rewardPercent <= 0 { rewardPercent = 22; };
      termLabel = "6-month";
      if aux2 >= 12 { termLabel = "12-month"; };
      return s"Vanguard Auto Insurance: Good Driver Appreciation applied. No at-fault accidents have been recorded for 7 days. Your active \(termLabel) policy now receives \(rewardPercent)% off qualifying premium calculations while the clean-driver status remains active.";
    };
    if kind == 3110 {
      return s"Vanguard Auto Insurance Fraud Warning: Damage analysis determined that your insured vehicle, \(vehicleName), was deliberately destroyed by the policyholder. The claim has been denied. This is strike 1 of 3. Additional confirmed incidents may result in policy suspension or permanent termination.";
    };
    if kind == 3111 {
      return s"Vanguard Auto Insurance Suspension Notice: A second confirmed policyholder-caused total loss has been recorded for \(vehicleName). The claim has been denied, and coverage on all vehicles is suspended for 7 days. This is strike 2 of 3. A further incident will result in permanent termination.";
    };
    if kind == 3112 {
      return "Vanguard Auto Insurance Account Notice: Your 7-day suspension has ended. Coverage has resumed for the remainder of your policy term.";
    };
    if kind == 3113 {
      return "Vanguard Auto Insurance Account Notice: Your 7-day suspension has ended. Your previous policy expired during the suspension period. Your account is now eligible for a new coverage review.";
    };
    if kind == 3115 {
      return "Vanguard Auto Insurance Account Notice: Your 7-day suspension has ended. Your policy record remains active, but no vehicles are currently covered. Open Vanguard Auto and select Coverage to review your account.";
    };
    if kind == 3114 {
      return "Vanguard Auto Insurance Termination Notice: A third confirmed policyholder-caused total loss has been recorded. The claim has been denied, your policy has been permanently terminated, and this account is no longer eligible for Vanguard coverage. Open Vanguard Auto and select Coverage to review the formal termination notice.";
    };
    if kind == 3201 {
      rewardPercent = aux1 / 100;
      if rewardPercent <= 0 {
        return "";
      };
      return s"Vanguard Auto: Your \(vehicleName) includes a \(rewardPercent)% Owner Appreciation voucher through our NCGT Performance Shops partnership. Visit an NCGT shop within 7 days. Valid once on all eligible parts in a single checkout; labor fees are excluded.";
    };
    if kind == 3001 {
      return VanguardAutoLocalization.Text1(1773, s"Vanguard Auto: Thank you for your purchase. \(vehicleName) has been added to your Garage.", s"\(vehicleName)");
    };
    if kind == 3002 {
      return VanguardAutoLocalization.Text2(1774, s"Vanguard Auto: Payment received in full: \(this.FormatMoney(amount)) for \(vehicleName). Ownership and title records are complete.", s"\(this.FormatMoney(amount))", s"\(vehicleName)");
    };
    if kind == 3003 {
      return VanguardAutoLocalization.Text1(1775, s"Vanguard Auto Customer Care: We hope you are enjoying your \(vehicleName). Your purchase and ownership records remain available in Garage.", s"\(vehicleName)");
    };
    if kind == 3004 {
      return VanguardAutoLocalization.Text1(1776, s"Vanguard Auto: Sale confirmation for \(vehicleName) is complete. Eligible proceeds have been finalized. Bank-held titles require payoff before sale.", s"\(vehicleName)");
    };
    if kind == 3010 {
      if aux1 == 4 {
        return s"Vanguard Auto: Financing is temporarily unavailable for \(vehicleName). Marmur Bank services must be online before an application can be submitted.";
      };
      if aux1 == 3 {
        return VanguardAutoLocalization.Text1(1777, s"Vanguard Auto: Financing was not approved for \(vehicleName). Your active auto-loan limit is full. Pay off an existing Marmur Bank auto loan before applying again.", s"\(vehicleName)");
      };
      if aux1 == 2 {
        return VanguardAutoLocalization.Text1(1778, s"Vanguard Auto: Financing was not approved for \(vehicleName). Required due-today funds were not available. Improve your credit or checking balance and try again.", s"\(vehicleName)");
      };
      return VanguardAutoLocalization.Text1(1779, s"Vanguard Auto: Financing was not approved for \(vehicleName). Improve your credit or choose a lower-priced vehicle and try again.", s"\(vehicleName)");
    };

    return "";
  }

  private func GetPhoneMessageTextAt(index: Int32) -> String {
    if index < 0 || index >= ArraySize(this.m_vanguardPhoneMessageKinds) {
      return "";
    };
    if index >= ArraySize(this.m_vanguardPhoneMessageVehicleIDs) || index >= ArraySize(this.m_vanguardPhoneMessageAmounts) || index >= ArraySize(this.m_vanguardPhoneMessageAux1) || index >= ArraySize(this.m_vanguardPhoneMessageAux2) {
      return "";
    };

    return this.GetPhoneMessageTextByData(
      this.m_vanguardPhoneMessageKinds[index],
      this.m_vanguardPhoneMessageVehicleIDs[index],
      this.m_vanguardPhoneMessageAmounts[index],
      this.m_vanguardPhoneMessageAux1[index],
      this.m_vanguardPhoneMessageAux2[index]
    );
  }

  private func NormalizeVanguardPhoneHistoryArrays() -> Void {
    let count: Int32 = ArraySize(this.m_vanguardPhoneMessageKinds);

    while ArraySize(this.m_vanguardPhoneMessageVehicleIDs) < count { ArrayPush(this.m_vanguardPhoneMessageVehicleIDs, t"VanguardAuto.Phone.NoVehicle"); };
    while ArraySize(this.m_vanguardPhoneMessageAmounts) < count { ArrayPush(this.m_vanguardPhoneMessageAmounts, 0); };
    while ArraySize(this.m_vanguardPhoneMessageAux1) < count { ArrayPush(this.m_vanguardPhoneMessageAux1, 0); };
    while ArraySize(this.m_vanguardPhoneMessageAux2) < count { ArrayPush(this.m_vanguardPhoneMessageAux2, 0); };
    while ArraySize(this.m_vanguardPhoneMessageMinutes) < count { ArrayPush(this.m_vanguardPhoneMessageMinutes, 0); };

    while ArraySize(this.m_vanguardPhoneMessageVehicleIDs) > count { ArrayErase(this.m_vanguardPhoneMessageVehicleIDs, ArraySize(this.m_vanguardPhoneMessageVehicleIDs) - 1); };
    while ArraySize(this.m_vanguardPhoneMessageAmounts) > count { ArrayErase(this.m_vanguardPhoneMessageAmounts, ArraySize(this.m_vanguardPhoneMessageAmounts) - 1); };
    while ArraySize(this.m_vanguardPhoneMessageAux1) > count { ArrayErase(this.m_vanguardPhoneMessageAux1, ArraySize(this.m_vanguardPhoneMessageAux1) - 1); };
    while ArraySize(this.m_vanguardPhoneMessageAux2) > count { ArrayErase(this.m_vanguardPhoneMessageAux2, ArraySize(this.m_vanguardPhoneMessageAux2) - 1); };
    while ArraySize(this.m_vanguardPhoneMessageMinutes) > count { ArrayErase(this.m_vanguardPhoneMessageMinutes, ArraySize(this.m_vanguardPhoneMessageMinutes) - 1); };
  }

  private func NormalizeVanguardDeferredPhoneArrays() -> Void {
    let count: Int32 = ArraySize(this.m_vanguardDeferredPhoneMessageKinds);

    while ArraySize(this.m_vanguardDeferredPhoneMessageVehicleIDs) < count { ArrayPush(this.m_vanguardDeferredPhoneMessageVehicleIDs, t"VanguardAuto.Phone.NoVehicle"); };
    while ArraySize(this.m_vanguardDeferredPhoneMessageAmounts) < count { ArrayPush(this.m_vanguardDeferredPhoneMessageAmounts, 0); };
    while ArraySize(this.m_vanguardDeferredPhoneMessageAux1) < count { ArrayPush(this.m_vanguardDeferredPhoneMessageAux1, 0); };
    while ArraySize(this.m_vanguardDeferredPhoneMessageAux2) < count { ArrayPush(this.m_vanguardDeferredPhoneMessageAux2, 0); };
    while ArraySize(this.m_vanguardDeferredPhoneMessageMinutes) < count { ArrayPush(this.m_vanguardDeferredPhoneMessageMinutes, 0); };

    while ArraySize(this.m_vanguardDeferredPhoneMessageVehicleIDs) > count { ArrayErase(this.m_vanguardDeferredPhoneMessageVehicleIDs, ArraySize(this.m_vanguardDeferredPhoneMessageVehicleIDs) - 1); };
    while ArraySize(this.m_vanguardDeferredPhoneMessageAmounts) > count { ArrayErase(this.m_vanguardDeferredPhoneMessageAmounts, ArraySize(this.m_vanguardDeferredPhoneMessageAmounts) - 1); };
    while ArraySize(this.m_vanguardDeferredPhoneMessageAux1) > count { ArrayErase(this.m_vanguardDeferredPhoneMessageAux1, ArraySize(this.m_vanguardDeferredPhoneMessageAux1) - 1); };
    while ArraySize(this.m_vanguardDeferredPhoneMessageAux2) > count { ArrayErase(this.m_vanguardDeferredPhoneMessageAux2, ArraySize(this.m_vanguardDeferredPhoneMessageAux2) - 1); };
    while ArraySize(this.m_vanguardDeferredPhoneMessageMinutes) > count { ArrayErase(this.m_vanguardDeferredPhoneMessageMinutes, ArraySize(this.m_vanguardDeferredPhoneMessageMinutes) - 1); };
  }

  private func HasExactPhoneRecord(kind: Int32, vehicleID: TweakDBID, amount: Int32, aux1: Int32, aux2: Int32, minute: Int32) -> Bool {
    this.NormalizeVanguardPhoneHistoryArrays();
    let i: Int32 = 0;
    while i < ArraySize(this.m_vanguardPhoneMessageKinds) {
      if this.m_vanguardPhoneMessageKinds[i] == kind &&
         Equals(this.m_vanguardPhoneMessageVehicleIDs[i], vehicleID) &&
         this.m_vanguardPhoneMessageAmounts[i] == amount &&
         this.m_vanguardPhoneMessageAux1[i] == aux1 &&
         this.m_vanguardPhoneMessageAux2[i] == aux2 &&
         this.m_vanguardPhoneMessageMinutes[i] == minute {
        return true;
      };
      i += 1;
    };
    return false;
  }

  private func HasSaleConfirmationPhoneMessage(id: TweakDBID) -> Bool {
    this.NormalizeVanguardPhoneHistoryArrays();
    let i: Int32 = 0;

    while i < ArraySize(this.m_vanguardPhoneMessageKinds) {
      if this.m_vanguardPhoneMessageKinds[i] == 3004 && Equals(this.m_vanguardPhoneMessageVehicleIDs[i], id) {
        return true;
      };
      i += 1;
    };

    return false;
  }

  private func QueueDeferredPhoneNotificationRecord(kind: Int32, vehicleID: TweakDBID, amount: Int32, aux1: Int32, aux2: Int32) -> Void {
    if !this.IsVanguardPhoneAlertKindEnabled(kind) { return; };
    let occurrenceMinute: Int32 = this.GetCurrentGameMinute();
    let i: Int32 = 0;

    if StrLen(this.GetPhoneMessageTextByData(kind, vehicleID, amount, aux1, aux2)) <= 0 {
      return;
    };

    this.NormalizeVanguardDeferredPhoneArrays();
    while i < ArraySize(this.m_vanguardDeferredPhoneMessageKinds) {
      if this.m_vanguardDeferredPhoneMessageKinds[i] == kind &&
         Equals(this.m_vanguardDeferredPhoneMessageVehicleIDs[i], vehicleID) &&
         this.m_vanguardDeferredPhoneMessageAmounts[i] == amount &&
         this.m_vanguardDeferredPhoneMessageAux1[i] == aux1 &&
         this.m_vanguardDeferredPhoneMessageAux2[i] == aux2 &&
         this.m_vanguardDeferredPhoneMessageMinutes[i] == occurrenceMinute {
        return;
      };
      i += 1;
    };

    ArrayPush(this.m_vanguardDeferredPhoneMessageKinds, kind);
    ArrayPush(this.m_vanguardDeferredPhoneMessageVehicleIDs, vehicleID);
    ArrayPush(this.m_vanguardDeferredPhoneMessageAmounts, amount);
    ArrayPush(this.m_vanguardDeferredPhoneMessageAux1, aux1);
    ArrayPush(this.m_vanguardDeferredPhoneMessageAux2, aux2);
    ArrayPush(this.m_vanguardDeferredPhoneMessageMinutes, occurrenceMinute);
  }

  private func AppendPhoneMessageImmediateRecord(kind: Int32, vehicleID: TweakDBID, amount: Int32, aux1: Int32, aux2: Int32) -> Bool {
    return this.AppendPhoneMessageRecordAtMinute(kind, vehicleID, amount, aux1, aux2, this.GetCurrentGameMinute());
  }

  private func AppendPhoneMessageRecordAtMinute(kind: Int32, vehicleID: TweakDBID, amount: Int32, aux1: Int32, aux2: Int32, occurrenceMinute: Int32) -> Bool {

    if !this.IsVanguardPhoneAlertKindEnabled(kind) { return true; };
    let text: String = this.GetPhoneMessageTextByData(kind, vehicleID, amount, aux1, aux2);

    if kind == 3101 && !this.IsVanguardCoverageTotalLossNotificationValid(vehicleID, aux1) {
      return false;
    };

    if StrLen(text) <= 0 {
      return false;
    };
    if this.HasExactPhoneRecord(kind, vehicleID, amount, aux1, aux2, occurrenceMinute) {

      return true;
    };

    this.EnsureVanguardPhoneUnreadSplit();
    ArrayPush(this.m_vanguardPhoneMessageKinds, kind);
    ArrayPush(this.m_vanguardPhoneMessageVehicleIDs, vehicleID);
    ArrayPush(this.m_vanguardPhoneMessageAmounts, amount);
    ArrayPush(this.m_vanguardPhoneMessageAux1, aux1);
    ArrayPush(this.m_vanguardPhoneMessageAux2, aux2);
    ArrayPush(this.m_vanguardPhoneMessageMinutes, occurrenceMinute);
    if this.GetVanguardPhoneAlertCategory(kind) >= 100 {
      this.m_vanguardCoveragePhoneUnreadCount += 1;
    } else {
      this.m_vanguardPhoneUnreadCount += 1;
    };
    this.m_vanguardLastPhoneMessageKind = kind;
    this.m_vanguardLastPhoneMessageVehicleID = vehicleID;
    this.m_vanguardLastPhoneMessageAmount = amount;
    this.m_vanguardLastPhoneMessageAux1 = aux1;
    this.m_vanguardLastPhoneMessageAux2 = aux2;
    this.m_vanguardLastPhoneMessageMinute = occurrenceMinute;

    while ArraySize(this.m_vanguardPhoneMessageKinds) > 60 {
      ArrayErase(this.m_vanguardPhoneMessageKinds, 0);
      ArrayErase(this.m_vanguardPhoneMessageVehicleIDs, 0);
      ArrayErase(this.m_vanguardPhoneMessageAmounts, 0);
      ArrayErase(this.m_vanguardPhoneMessageAux1, 0);
      ArrayErase(this.m_vanguardPhoneMessageAux2, 0);
      ArrayErase(this.m_vanguardPhoneMessageMinutes, 0);
      if this.m_vanguardPhoneDeliveredCount > 0 {
        this.m_vanguardPhoneDeliveredCount -= 1;
      };
    };

    return true;
  }

  private func PublishPhoneNotificationRecord(kind: Int32, vehicleID: TweakDBID, amount: Int32, aux1: Int32, aux2: Int32) -> Bool {

    if !this.IsVanguardPhoneAlertKindEnabled(kind) { return true; };
    let text: String = this.GetPhoneMessageTextByData(kind, vehicleID, amount, aux1, aux2);

    if kind == 3101 && !this.IsVanguardCoverageTotalLossNotificationValid(vehicleID, aux1) {
      return false;
    };

    if StrLen(text) <= 0 {
      return false;
    };
    if this.IsPhoneNotificationSuppressed() {
      this.QueueDeferredPhoneNotificationRecord(kind, vehicleID, amount, aux1, aux2);
      return false;
    };

    return this.AppendPhoneMessageImmediateRecord(kind, vehicleID, amount, aux1, aux2);
  }

  private func RemoveDeferredPhoneNotificationHead() -> Void {
    ArrayErase(this.m_vanguardDeferredPhoneMessageKinds, 0);
    ArrayErase(this.m_vanguardDeferredPhoneMessageVehicleIDs, 0);
    ArrayErase(this.m_vanguardDeferredPhoneMessageAmounts, 0);
    ArrayErase(this.m_vanguardDeferredPhoneMessageAux1, 0);
    ArrayErase(this.m_vanguardDeferredPhoneMessageAux2, 0);
    ArrayErase(this.m_vanguardDeferredPhoneMessageMinutes, 0);
  }

  public func FlushDeferredPhoneNotifications() -> Void {
    if !this.AreVanguardAlertsEnabled() {
      this.DiscardVanguardAlertBacklog();
      return;
    };
    if this.IsPhoneNotificationSuppressed() || ArraySize(this.m_vanguardDeferredPhoneMessageKinds) <= 0 {
      return;
    };

    this.NormalizeVanguardDeferredPhoneArrays();
    while ArraySize(this.m_vanguardDeferredPhoneMessageKinds) > 0 && !this.IsPhoneNotificationSuppressed() {
      let kind: Int32 = this.m_vanguardDeferredPhoneMessageKinds[0];
      let vehicleID: TweakDBID = this.m_vanguardDeferredPhoneMessageVehicleIDs[0];
      let amount: Int32 = this.m_vanguardDeferredPhoneMessageAmounts[0];
      let aux1: Int32 = this.m_vanguardDeferredPhoneMessageAux1[0];
      let aux2: Int32 = this.m_vanguardDeferredPhoneMessageAux2[0];
      let occurrenceMinute: Int32 = this.m_vanguardDeferredPhoneMessageMinutes[0];
      let text: String = this.GetPhoneMessageTextByData(kind, vehicleID, amount, aux1, aux2);

      if StrLen(text) <= 0 {

        this.RemoveDeferredPhoneNotificationHead();
      } else {
        if !this.AppendPhoneMessageRecordAtMinute(kind, vehicleID, amount, aux1, aux2, occurrenceMinute) {

          this.RemoveDeferredPhoneNotificationHead();
        } else {
          this.RemoveDeferredPhoneNotificationHead();
        };
      };
    };
  }

  public func QueuePurchaseConfirmation(vehicleID: TweakDBID, amount: Int32, financed: Bool) -> Void {

    if financed {
      return;
    };

    this.PublishPhoneNotificationRecord(3001, vehicleID, 0, 0, 0);
    this.PublishPhoneNotificationRecord(3002, vehicleID, amount, 0, 0);
    this.QueueNCGTAppreciationVoucherNotice(vehicleID);
  }

  public func QueueFinancedDeliverySpend(vehicleID: TweakDBID, amount: Int32) -> Void {
    let index: Int32 = this.GetFinanceContractIndex(vehicleID);

    if amount <= 0 || index < 0 {
      return;
    };

    this.PushFinanceEvent(vehicleID, 19, amount, this.m_financeRemainingMonths[index], this.m_financeTerms[index], this.m_financeMonthlyPayments[index]);
  }

  private func ConsumeGoodDriverRewardPhoneFact() -> Void {
    let qs: ref<QuestsSystem>;
    let pending: Int32;
    let amount: Int32;
    let percent: Int32;
    let cleanDays: Int32;
    let termMonths: Int32;

    qs = GameInstance.GetQuestsSystem(this.GetGameInstance());
    if !IsDefined(qs) {
      return;
    };

    pending = qs.GetFactStr(s"vanguard_good_driver_sms_pending");
    if pending <= 0 {
      return;
    };

    amount = qs.GetFactStr(s"vanguard_good_driver_sms_amount");
    percent = qs.GetFactStr(s"vanguard_good_driver_sms_percent");
    cleanDays = qs.GetFactStr(s"vanguard_good_driver_sms_clean_days");
    termMonths = qs.GetFactStr(s"vanguard_good_driver_sms_term_months");

    if percent <= 0 { percent = 22; };
    if cleanDays <= 0 { cleanDays = 7; };
    if termMonths <= 0 { termMonths = this.GetVanguardCoverageTermMonths(); };

    if this.m_coverageGoodDriverRewardedTermStartMinute == this.m_coverageTermStartMinute && this.m_coverageGoodDriverRewardedStartMinute == this.m_coverageGoodDriverStartMinute && this.m_coverageGoodDriverRewardedVersion == 2200 {
      SetFactValue(this.GetGameInstance(), n"vanguard_good_driver_sms_pending", 0);
      SetFactValue(this.GetGameInstance(), n"vanguard_good_driver_sms_amount", 0);
      SetFactValue(this.GetGameInstance(), n"vanguard_good_driver_sms_percent", 0);
      SetFactValue(this.GetGameInstance(), n"vanguard_good_driver_sms_clean_days", 0);
      SetFactValue(this.GetGameInstance(), n"vanguard_good_driver_sms_term_months", 0);
      return;
    };

    this.m_coverageGoodDriverRewardedTermStartMinute = this.m_coverageTermStartMinute;
    this.m_coverageGoodDriverRewardedStartMinute = this.m_coverageGoodDriverStartMinute;
    this.m_coverageGoodDriverRewardedVersion = 2200;

    if pending == 1 {
      this.m_coverageGoodDriverRefundIssuedThisTerm = true;
      this.PublishPhoneNotificationRecord(3103, t"VanguardAuto.Phone.NoVehicle", amount, percent, termMonths);
    } else {
      if pending == 2 {
        this.PublishPhoneNotificationRecord(3104, t"VanguardAuto.Phone.NoVehicle", amount, percent, termMonths);
      };
    };

    SetFactValue(this.GetGameInstance(), n"vanguard_good_driver_sms_pending", 0);
    SetFactValue(this.GetGameInstance(), n"vanguard_good_driver_sms_amount", 0);
    SetFactValue(this.GetGameInstance(), n"vanguard_good_driver_sms_percent", 0);
    SetFactValue(this.GetGameInstance(), n"vanguard_good_driver_sms_clean_days", 0);
    SetFactValue(this.GetGameInstance(), n"vanguard_good_driver_sms_term_months", 0);
  }

  public func ProcessPendingPhoneMessages() -> Void {
    let now: Int32 = this.GetCurrentGameMinute();
    let newFollowupVehicleIDs: array<TweakDBID>;
    let newFollowupModes: array<Int32>;
    let newFollowupTimes: array<Int32>;
    let newSaleFollowupVehicleIDs: array<TweakDBID>;
    let newSaleFollowupTimes: array<Int32>;
    let i: Int32 = 0;

    this.RefreshVanguardCoverageFraudAccountState();
    this.FlushDeferredPhoneNotifications();
    this.ConsumeGoodDriverRewardPhoneFact();
    this.RefreshVanguardCoverageGoodDriverAppreciationNotice();
    if !this.AreVanguardAlertsEnabled() {
      this.DiscardVanguardAlertBacklog();
      return;
    };

    while i < ArraySize(this.m_followupVehicleIDs) {
      if i < ArraySize(this.m_followupTimes) && this.m_followupTimes[i] <= now {
        if !ArrayContains(this.m_soldVehicles, this.m_followupVehicleIDs[i]) {
          this.PublishPhoneNotificationRecord(3003, this.m_followupVehicleIDs[i], 0, 0, 0);
        };
      } else {
        if !ArrayContains(this.m_soldVehicles, this.m_followupVehicleIDs[i]) {
          ArrayPush(newFollowupVehicleIDs, this.m_followupVehicleIDs[i]);
          if i < ArraySize(this.m_followupModes) {
            ArrayPush(newFollowupModes, this.m_followupModes[i]);
          } else {
            ArrayPush(newFollowupModes, 1);
          };
          if i < ArraySize(this.m_followupTimes) {
            ArrayPush(newFollowupTimes, this.m_followupTimes[i]);
          } else {
            ArrayPush(newFollowupTimes, now + this.GetCustomerCareFollowupDelayMinutes());
          };
        };
      };
      i += 1;
    };

    this.m_followupVehicleIDs = newFollowupVehicleIDs;
    this.m_followupModes = newFollowupModes;
    this.m_followupTimes = newFollowupTimes;

    i = 0;
    while i < ArraySize(this.m_saleFollowupVehicleIDs) {
      if i < ArraySize(this.m_saleFollowupTimes) && this.m_saleFollowupTimes[i] <= now {
        if !this.HasSaleConfirmationPhoneMessage(this.m_saleFollowupVehicleIDs[i]) {
          this.PublishPhoneNotificationRecord(3004, this.m_saleFollowupVehicleIDs[i], 0, 0, 0);
        };
      } else {
        ArrayPush(newSaleFollowupVehicleIDs, this.m_saleFollowupVehicleIDs[i]);
        if i < ArraySize(this.m_saleFollowupTimes) {
          ArrayPush(newSaleFollowupTimes, this.m_saleFollowupTimes[i]);
        } else {
          ArrayPush(newSaleFollowupTimes, now + 60);
        };
      };
      i += 1;
    };

    this.m_saleFollowupVehicleIDs = newSaleFollowupVehicleIDs;
    this.m_saleFollowupTimes = newSaleFollowupTimes;
  }

  private func VanguardPhoneThreadMinuteSortsBefore(leftMinute: Int32, rightMinute: Int32) -> Bool {
    if leftMinute <= 0 {
      return rightMinute > 0;
    };
    if rightMinute <= 0 {
      return false;
    };
    return leftMinute < rightMinute;
  }

  public func GetPhoneThreadMessages() -> array<String> {
    let messages: array<String>;
    let minutes: array<Int32>;
    let text: String;
    let i: Int32 = 0;
    let j: Int32;
    let tempText: String;
    let tempMinute: Int32;

    this.NormalizeVanguardPhoneHistoryArrays();
    while i < ArraySize(this.m_vanguardPhoneMessageKinds) {
      text = this.GetPhoneMessageTextAt(i);
      if StrLen(text) > 0 && this.GetVanguardPhoneAlertCategory(this.m_vanguardPhoneMessageKinds[i]) < 100 {
        ArrayPush(messages, text);
        ArrayPush(minutes, this.m_vanguardPhoneMessageMinutes[i]);
      };
      i += 1;
    };

    i = 1;
    while i < ArraySize(messages) {
      j = i;
      while j > 0 && this.VanguardPhoneThreadMinuteSortsBefore(minutes[j], minutes[j - 1]) {
        tempText = messages[j - 1];
        messages[j - 1] = messages[j];
        messages[j] = tempText;

        tempMinute = minutes[j - 1];
        minutes[j - 1] = minutes[j];
        minutes[j] = tempMinute;
        j -= 1;
      };
      i += 1;
    };

    return messages;
  }

  public func GetNotificationHistoryCount() -> Int32 {
    this.NormalizeVanguardPhoneHistoryArrays();
    return ArraySize(this.m_vanguardPhoneMessageKinds);
  }

  public func GetNotificationHistoryText(index: Int32) -> String {
    this.NormalizeVanguardPhoneHistoryArrays();
    let count: Int32 = ArraySize(this.m_vanguardPhoneMessageKinds);
    let realIndex: Int32;

    if count <= 0 || index <= 0 || index > count {
      return "";
    };

    realIndex = count - index;
    return this.GetPhoneMessageTextAt(realIndex);
  }

  public func GetPhoneUnreadCount() -> Int32 {
    this.EnsureVanguardPhoneUnreadSplit();
    return this.m_vanguardPhoneUnreadCount;
  }

  public func ResetPhoneUnreadCount() -> Void {
    this.EnsureVanguardPhoneUnreadSplit();
    this.m_vanguardPhoneUnreadCount = 0;
  }

  public func GetPhoneDeliveredCount() -> Int32 {
    this.NormalizeVanguardPhoneHistoryArrays();
    let count: Int32 = ArraySize(this.m_vanguardPhoneMessageKinds);
    if this.m_vanguardPhoneDeliveredCount < 0 {
      this.m_vanguardPhoneDeliveredCount = 0;
    };
    if this.m_vanguardPhoneDeliveredCount > count {
      this.m_vanguardPhoneDeliveredCount = count;
    };
    return this.m_vanguardPhoneDeliveredCount;
  }

  public func MarkPhoneMessagesDelivered(count: Int32) -> Void {
    this.NormalizeVanguardPhoneHistoryArrays();
    let historyCount: Int32 = ArraySize(this.m_vanguardPhoneMessageKinds);
    if count < 0 {
      this.m_vanguardPhoneDeliveredCount = 0;
    } else {
      if count > historyCount {
        this.m_vanguardPhoneDeliveredCount = historyCount;
      } else {
        this.m_vanguardPhoneDeliveredCount = count;
      };
    };
  }

  private func GetLegacyFinancePaidAmountByIndex(index: Int32) -> Int32 {
    let termMonths: Int32;
    let remainingMonths: Int32;
    let monthlyPayment: Int32;
    let paidMonths: Int32;
    let paidAmount: Int32;

    if index < 0 || index >= ArraySize(this.m_financeVehicleIDs) {
      return 0;
    };

    termMonths = this.m_financeTerms[index];
    remainingMonths = this.m_financeRemainingMonths[index];
    monthlyPayment = this.m_financeMonthlyPayments[index];
    paidMonths = termMonths - remainingMonths;

    if paidMonths < 0 {
      paidMonths = 0;
    };

    paidAmount = monthlyPayment * paidMonths;
    if paidAmount < 0 {
      return 0;
    };

    if paidAmount > this.m_financeTotalDue[index] {
      return this.m_financeTotalDue[index];
    };

    return paidAmount;
  }

  private func GetFinancePaidAmountByIndex(index: Int32) -> Int32 {
    let paidAmount: Int32;

    if index < 0 || index >= ArraySize(this.m_financeVehicleIDs) {
      return 0;
    };

    if index < ArraySize(this.m_financePaidAmounts) {
      paidAmount = this.m_financePaidAmounts[index];
      if paidAmount < 0 {
        return 0;
      };

      if paidAmount > this.m_financeTotalDue[index] {
        return this.m_financeTotalDue[index];
      };

      return paidAmount;
    };

    return this.GetLegacyFinancePaidAmountByIndex(index);
  }

  private func GetFinanceRemainingBalanceByIndex(index: Int32) -> Int32 {
    let balance: Int32;

    if index < 0 || index >= ArraySize(this.m_financeVehicleIDs) {
      return 0;
    };

    balance = this.m_financeTotalDue[index] - this.GetFinancePaidAmountByIndex(index);

    if balance < 0 {
      return 0;
    };

    return balance;
  }

  public func GetFinanceRemainingBalance(id: TweakDBID) -> Int32 {
    let i: Int32 = 0;

    while i < ArraySize(this.m_financeVehicleIDs) {
      if Equals(this.m_financeVehicleIDs[i], id) {
        return this.GetFinanceRemainingBalanceByIndex(i);
      };
      i += 1;
    };

    return 0;
  }

  public func GetFinanceRemainingMonths(id: TweakDBID) -> Int32 {
    let i: Int32 = 0;

    while i < ArraySize(this.m_financeVehicleIDs) {
      if Equals(this.m_financeVehicleIDs[i], id) {
        return this.m_financeRemainingMonths[i];
      };
      i += 1;
    };

    return 0;
  }

  public func GetFinanceMonthlyPaymentForVehicle(id: TweakDBID) -> Int32 {
    let i: Int32 = 0;

    while i < ArraySize(this.m_financeVehicleIDs) {
      if Equals(this.m_financeVehicleIDs[i], id) {
        return this.m_financeMonthlyPayments[i];
      };
      i += 1;
    };

    return 0;
  }

  public func GetFinanceTermMonthsForVehicle(id: TweakDBID) -> Int32 {
    let i: Int32 = 0;

    while i < ArraySize(this.m_financeVehicleIDs) {
      if Equals(this.m_financeVehicleIDs[i], id) {
        return this.m_financeTerms[i];
      };
      i += 1;
    };

    return 0;
  }

  public func GetFinanceDownPaymentForVehicle(id: TweakDBID) -> Int32 {
    let i: Int32 = 0;

    while i < ArraySize(this.m_financeVehicleIDs) {
      if Equals(this.m_financeVehicleIDs[i], id) {
        return this.m_financeDownPayments[i];
      };
      i += 1;
    };

    return 0;
  }

  public func GetFinanceTotalDueForVehicle(id: TweakDBID) -> Int32 {
    let i: Int32 = 0;

    while i < ArraySize(this.m_financeVehicleIDs) {
      if Equals(this.m_financeVehicleIDs[i], id) {
        return this.m_financeTotalDue[i];
      };
      i += 1;
    };

    return 0;
  }

  public func GetFinanceInterestDisplayTextForVehicle(id: TweakDBID) -> String {
    let i: Int32 = 0;
    let basisPoints: Int32;
    let whole: Int32;
    let decimal: Int32;

    while i < ArraySize(this.m_financeVehicleIDs) {
      if Equals(this.m_financeVehicleIDs[i], id) {
        basisPoints = this.m_financeInterestPercents[i];
        whole = basisPoints / 100;
        decimal = (basisPoints % 100) / 10;
        return s"\(whole).\(decimal)%";
      };
      i += 1;
    };

    return "—";
  }

  public func GetFinancePaidPercentForVehicle(id: TweakDBID) -> Int32 {
    let i: Int32 = 0;
    let paidAmount: Int32;
    let totalDue: Int32;

    while i < ArraySize(this.m_financeVehicleIDs) {
      if Equals(this.m_financeVehicleIDs[i], id) {
        totalDue = this.m_financeTotalDue[i];
        if totalDue <= 0 {
          return 0;
        };
        paidAmount = this.GetFinancePaidAmountByIndex(i);
        return (paidAmount * 100) / totalDue;
      };
      i += 1;
    };

    return 0;
  }

  public func IsFinanceHalfwayPaid(id: TweakDBID) -> Bool {
    let i: Int32 = 0;

    while i < ArraySize(this.m_financeVehicleIDs) {
      if Equals(this.m_financeVehicleIDs[i], id) {
        return this.GetFinancePaidAmountByIndex(i) * 2 >= this.m_financeTotalDue[i];
      };
      i += 1;
    };

    return false;
  }
  public func GetFinanceRefinanceTermMonths(id: TweakDBID, player: ref<PlayerPuppet>) -> Int32 {
    return this.GetFinancialCreditScore(player) >= 740 ? 24 : 36;
  }
  public func GetFinanceRefinanceInterestBasisPoints(id: TweakDBID, termMonths: Int32, player: ref<PlayerPuppet>) -> Int32 {
    return this.GetMarmurBankAutoCreditInterestBasisPoints(player);
  }

  public func GetFinanceRefinanceInterestDisplayText(id: TweakDBID, player: ref<PlayerPuppet>) -> String {
    let basisPoints: Int32 = this.GetFinanceRefinanceInterestBasisPoints(id, this.GetFinanceRefinanceTermMonths(id, player), player);
    let whole: Int32 = basisPoints / 100;
    let decimal: Int32 = (basisPoints % 100) / 10;

    return s"\(whole).\(decimal)%";
  }
  public func GetFinanceRefinanceTotalDue(id: TweakDBID, player: ref<PlayerPuppet>) -> Int32 {
    let balance: Int32 = this.GetFinanceRemainingBalance(id);
    let termMonths: Int32 = this.GetFinanceRefinanceTermMonths(id, player);
    let interestBasisPoints: Int32 = this.GetFinanceRefinanceInterestBasisPoints(id, termMonths, player);
    let interestAmount: Int32;

    if balance <= 0 {
      return 0;
    };

    interestAmount = Cast<Int32>((Cast<Double>(balance) * Cast<Double>(interestBasisPoints)) / Cast<Double>(10000.0));
    return balance + interestAmount;
  }
  public func GetFinanceRefinanceMonthlyPayment(id: TweakDBID, player: ref<PlayerPuppet>) -> Int32 {
    let termMonths: Int32 = this.GetFinanceRefinanceTermMonths(id, player);
    let totalDue: Int32 = this.GetFinanceRefinanceTotalDue(id, player);

    if totalDue <= 0 || termMonths <= 0 {
      return 0;
    };

    return Max(1, (totalDue + termMonths - 1) / termMonths);
  }

  public func GetFinanceRefinanceRiskText(id: TweakDBID, player: ref<PlayerPuppet>) -> String {
    return "Refinancing uses your current Marmur financial credit profile. Existing terms stay fixed unless you refinance.";
  }
  public func CanRefinanceFinanceContract(id: TweakDBID, player: ref<GameObject>) -> Bool {
    if !IsDefined(player) || !this.IsVehicleFinanced(id) || this.IsVehicleRepossessed(id) || this.IsFinancePaymentDelinquent(id) {
      return false;
    };

    if this.GetFinanceRemainingBalance(id) <= 0 || !this.IsFinanceHalfwayPaid(id) {
      return false;
    };

    if this.m_financeNextPaymentMinutes[this.GetFinanceContractIndex(id)] <= this.GetCurrentGameMinute() { return false; };
    return this.GetMarmurCreditDecisionCode(this.GetFinanceRemainingBalance(id), this.GetFinanceRemainingBalance(id)) == 0;
  }
  public func RefinanceFinanceContract(id: TweakDBID, player: ref<GameObject>) -> Bool {
    let playerPuppet: ref<PlayerPuppet> = player as PlayerPuppet;
    let newVehicleIDs: array<TweakDBID>;
    let newTerms: array<Int32>;
    let newMonthlyPayments: array<Int32>;
    let newRemainingMonths: array<Int32>;
    let newNextPaymentMinutes: array<Int32>;
    let newTotalDue: array<Int32>;
    let newDownPayments: array<Int32>;
    let newInterestPercents: array<Int32>;
    let newPaidAmounts: array<Int32>;
    let i: Int32 = 0;
    let refinanced: Bool = false;
    let termMonths: Int32;
    let newTotal: Int32;
    let newMonthly: Int32;
    let newInterestBasisPoints: Int32;
    let nextPaymentMinute: Int32;
    if !this.IsMarmurBankAutoFinanceAvailable() { return false; };

    if !IsDefined(playerPuppet) || !this.CanRefinanceFinanceContract(id, player) {
      return false;
    };

    termMonths = this.GetFinanceRefinanceTermMonths(id, playerPuppet);
    newTotal = this.GetFinanceRefinanceTotalDue(id, playerPuppet);
    newMonthly = this.GetFinanceRefinanceMonthlyPayment(id, playerPuppet);
    newInterestBasisPoints = this.GetFinanceRefinanceInterestBasisPoints(id, termMonths, playerPuppet);
    nextPaymentMinute = this.GetCurrentGameMinute() + this.GetFinancePaymentFrequencyIntervalMinutes(this.GetFinancePaymentFrequency(id));

    if newTotal <= 0 || newMonthly <= 0 || termMonths <= 0 {
      return false;
    };

    while i < ArraySize(this.m_financeVehicleIDs) {
      if Equals(this.m_financeVehicleIDs[i], id) {
        ArrayPush(newVehicleIDs, id);
        ArrayPush(newTerms, termMonths);
        ArrayPush(newMonthlyPayments, newMonthly);
        ArrayPush(newRemainingMonths, termMonths);
        ArrayPush(newNextPaymentMinutes, nextPaymentMinute);
        ArrayPush(newTotalDue, newTotal);
        ArrayPush(newDownPayments, this.m_financeDownPayments[i]);
        ArrayPush(newInterestPercents, newInterestBasisPoints);
        ArrayPush(newPaidAmounts, 0);
        refinanced = true;
      } else {
        ArrayPush(newVehicleIDs, this.m_financeVehicleIDs[i]);
        ArrayPush(newTerms, this.m_financeTerms[i]);
        ArrayPush(newMonthlyPayments, this.m_financeMonthlyPayments[i]);
        ArrayPush(newRemainingMonths, this.m_financeRemainingMonths[i]);
        ArrayPush(newNextPaymentMinutes, this.m_financeNextPaymentMinutes[i]);
        ArrayPush(newTotalDue, this.m_financeTotalDue[i]);
        ArrayPush(newDownPayments, this.m_financeDownPayments[i]);
        ArrayPush(newInterestPercents, this.m_financeInterestPercents[i]);
        ArrayPush(newPaidAmounts, this.GetFinancePaidAmountByIndex(i));
      };
      i += 1;
    };

    if refinanced {
      this.RegisterVanguardCreditContract(id, true);
      this.RecordVanguardCreditPayment(id, this.GetFinanceRemainingBalance(id), 0, true);
      this.m_financeVehicleIDs = newVehicleIDs;
      this.m_financeTerms = newTerms;
      this.m_financeMonthlyPayments = newMonthlyPayments;
      this.m_financeRemainingMonths = newRemainingMonths;
      this.m_financeNextPaymentMinutes = newNextPaymentMinutes;
      this.m_financeTotalDue = newTotalDue;
      this.m_financeDownPayments = newDownPayments;
      this.m_financeInterestPercents = newInterestPercents;
      this.m_financePaidAmounts = newPaidAmounts;

      this.AssignNewFinanceContractSerial(id);
      this.RegisterVanguardCreditContract(id, false);
      this.QueueVanguardCreditApplication();
      this.m_financeContractsDirty = true;
      this.ClearFinanceDefaultState(id);
      this.PushFinanceEvent(id, 18, newTotal, termMonths, termMonths, newMonthly);
    };

    return refinanced;
  }

  public func GetFinanceExtraPaymentAmount(id: TweakDBID) -> Int32 {
    let monthlyPayment: Int32 = this.GetFinanceMonthlyPaymentForVehicle(id);
    let balance: Int32 = this.GetFinanceRemainingBalance(id);

    if balance <= 0 {
      return 0;
    };

    if monthlyPayment <= 0 || monthlyPayment > balance {
      return balance;
    };

    return monthlyPayment;
  }
  public func CanMakeExtraFinancePayment(id: TweakDBID, player: ref<GameObject>) -> Bool {
    let amount: Int32 = this.GetFinanceExtraPaymentAmount(id);

    if !IsDefined(player) || !this.IsVehicleFinanced(id) || this.IsVehicleRepossessed(id) || amount <= 0 {
      return false;
    };

    return this.m_transactionSystem.GetItemQuantity(player, MarketSystem.Money()) >= amount;
  }

  public func MakeExtraFinancePayment(id: TweakDBID, player: ref<GameObject>) -> Bool {
    return this.MakeCustomFinancePayment(id, this.GetFinanceExtraPaymentAmount(id), player);
  }

  private func NormalizeFinancePaymentFrequency(frequency: Int32) -> Int32 {
    if frequency == 1 {
      return 1;
    };

    if frequency == 2 {
      return 2;
    };

    return 3;
  }

  private func NormalizeFinancePaymentSource(paymentSource: Int32) -> Int32 {
    if paymentSource == 2 {
      return 2;
    };

    return 1;
  }

  public func GetFinancePaymentFrequencyIntervalMinutes(frequency: Int32) -> Int32 {
    let normalized: Int32 = this.NormalizeFinancePaymentFrequency(frequency);

    if normalized == 1 {
      return 10080;
    };

    if normalized == 2 {
      return 20160;
    };

    return 43200;
  }

  public func GetFinancePaymentFrequencyLabel(frequency: Int32) -> String {
    let normalized: Int32 = this.NormalizeFinancePaymentFrequency(frequency);

    if normalized == 1 {
      return VanguardAutoLocalization.Text(1174, "Weekly");
    };

    if normalized == 2 {
      return VanguardAutoLocalization.Text(1175, "Bi-weekly");
    };

    return VanguardAutoLocalization.Text(1176, "Monthly");
  }

  private func GetFinancePaymentFrequencyIndex(id: TweakDBID) -> Int32 {
    let i: Int32 = 0;

    while i < ArraySize(this.m_financePaymentFrequencyVehicleIDs) {
      if Equals(this.m_financePaymentFrequencyVehicleIDs[i], id) {
        return i;
      };
      i += 1;
    };

    return -1;
  }

  public func GetFinancePaymentFrequency(id: TweakDBID) -> Int32 {
    let index: Int32 = this.GetFinancePaymentFrequencyIndex(id);

    if index < 0 {
      return 3;
    };

    return this.NormalizeFinancePaymentFrequency(this.m_financePaymentFrequencies[index]);
  }
  private func ReanchorFinanceNextPayment(id: TweakDBID, frequency: Int32) -> Void {
    let i: Int32 = this.GetFinanceContractIndex(id);
    if i < 0 { return; };
    if this.GetVanguardCreditFact(this.EnsureFinanceContractSerial(id), "registered") == 0 {
      this.m_financeNextPaymentMinutes[i] = this.GetCurrentGameMinute() + this.GetFinancePaymentFrequencyIntervalMinutes(frequency);
    };
  }
  public func SetFinancePaymentFrequency(id: TweakDBID, frequency: Int32) -> Void {
    let normalized: Int32 = this.NormalizeFinancePaymentFrequency(frequency);
    let index: Int32 = this.GetFinancePaymentFrequencyIndex(id);
    let serial: Int32;
    let i: Int32 = this.GetFinanceContractIndex(id);
    if !this.IsMarmurBankAutoFinanceAvailable() { return; };

    if i < 0 || this.IsVehicleRepossessed(id) { return; };
    serial = this.EnsureFinanceContractSerial(id);
    if this.GetVanguardCreditFact(serial, "registered") > 0 {
      if this.IsFinancePaymentDelinquent(id) || this.m_financeNextPaymentMinutes[i] <= this.GetCurrentGameMinute() { return; };
    };
    if index >= 0 { this.m_financePaymentFrequencies[index] = normalized; }
    else { ArrayPush(this.m_financePaymentFrequencyVehicleIDs, id); ArrayPush(this.m_financePaymentFrequencies, normalized); };

    this.ReanchorFinanceNextPayment(id, normalized);
    if this.GetVanguardCreditFact(serial, "registered") > 0 { this.RecordVanguardCreditSchedule(id); };
    this.m_financeContractsDirty = true;
  }

  public func CycleFinancePaymentFrequency(id: TweakDBID) -> Int32 {
    let current: Int32 = this.GetFinancePaymentFrequency(id);
    let nextFrequency: Int32 = 1;

    if current == 1 {
      nextFrequency = 2;
    } else {
      if current == 2 {
        nextFrequency = 3;
      } else {
        nextFrequency = 1;
      };
    };

    this.SetFinancePaymentFrequency(id, nextFrequency);
    return this.GetFinancePaymentFrequency(id);
  }

  private func CalculateFinanceScheduledPaymentAmount(monthlyPayment: Int32, frequency: Int32, balance: Int32) -> Int32 {
    let normalized: Int32 = this.NormalizeFinancePaymentFrequency(frequency);
    let paymentAmount: Int32;

    if monthlyPayment <= 0 || balance <= 0 {
      return 0;
    };

    if normalized == 1 {
      paymentAmount = (monthlyPayment * 12 + 51) / 52;
    } else {
      if normalized == 2 {
        paymentAmount = (monthlyPayment * 12 + 25) / 26;
      } else {
        paymentAmount = monthlyPayment;
      };
    };

    if paymentAmount > balance {
      paymentAmount = balance;
    };

    if paymentAmount <= 0 {
      return 0;
    };

    return Max(1, paymentAmount);
  }

  public func GetFinanceScheduledPaymentAmountByIndex(index: Int32) -> Int32 {
    if index < 0 || index >= ArraySize(this.m_financeVehicleIDs) {
      return 0;
    };

    return this.CalculateFinanceScheduledPaymentAmount(this.m_financeMonthlyPayments[index], this.GetFinancePaymentFrequency(this.m_financeVehicleIDs[index]), this.GetFinanceRemainingBalanceByIndex(index));
  }

  public func GetFinanceScheduledPaymentAmount(id: TweakDBID) -> Int32 {
    let i: Int32 = this.GetFinanceContractIndex(id);
    return i < 0 ? 0 : this.GetActiveFinanceScheduledCashDueAt(i + 1);
  }

  public func GetFinanceScheduledPaymentLabel(id: TweakDBID) -> String {
    return this.GetFinancePaymentFrequencyLabel(this.GetFinancePaymentFrequency(id));
  }

  private func RemoveFinancePaymentFrequencyState(id: TweakDBID) -> Void {
    let newVehicleIDs: array<TweakDBID>;
    let newFrequencies: array<Int32>;
    let i: Int32 = 0;

    while i < ArraySize(this.m_financePaymentFrequencyVehicleIDs) {
      if NotEquals(this.m_financePaymentFrequencyVehicleIDs[i], id) {
        ArrayPush(newVehicleIDs, this.m_financePaymentFrequencyVehicleIDs[i]);
        ArrayPush(newFrequencies, this.m_financePaymentFrequencies[i]);
      };
      i += 1;
    };

    this.m_financePaymentFrequencyVehicleIDs = newVehicleIDs;
    this.m_financePaymentFrequencies = newFrequencies;
  }

  private func GetFinancePaymentSourceIndex(id: TweakDBID) -> Int32 {
    let i: Int32 = 0;

    while i < ArraySize(this.m_financePaymentSourceVehicleIDs) {
      if Equals(this.m_financePaymentSourceVehicleIDs[i], id) {
        return i;
      };
      i += 1;
    };

    return -1;
  }

  public func GetFinancePaymentSource(id: TweakDBID) -> Int32 {
    let index: Int32 = this.GetFinancePaymentSourceIndex(id);

    if index < 0 || index >= ArraySize(this.m_financePaymentSources) {
      return 1;
    };

    return this.NormalizeFinancePaymentSource(this.m_financePaymentSources[index]);
  }
  private func SetFinancePaymentSource(id: TweakDBID, paymentSource: Int32) -> Bool {
    let normalized: Int32 = this.NormalizeFinancePaymentSource(paymentSource);
    let index: Int32 = this.GetFinancePaymentSourceIndex(id);
    if !this.IsMarmurBankAutoFinanceAvailable() { return false; };

    if paymentSource != 1 && paymentSource != 2 {
      return false;
    };

    if !this.IsVehicleFinanced(id) || this.IsVehicleRepossessed(id) {
      return false;
    };

    if normalized == 2 && !this.IsMarmurBankSavingsPaymentSourceAvailable() {
      return false;
    };

    if index >= 0 {
      this.m_financePaymentSources[index] = normalized;
    } else {
      ArrayPush(this.m_financePaymentSourceVehicleIDs, id);
      ArrayPush(this.m_financePaymentSources, normalized);
    };

    return this.GetFinancePaymentSource(id) == normalized;
  }

  public func GetActiveFinancePaymentSourceAt(contractIndex: Int32) -> Int32 {
    let internalIndex: Int32 = contractIndex - 1;

    if internalIndex < 0 || internalIndex >= ArraySize(this.m_financeVehicleIDs) {
      return 1;
    };

    return this.GetFinancePaymentSource(this.m_financeVehicleIDs[internalIndex]);
  }
  public func SetActiveFinancePaymentSourceAt(contractIndex: Int32, paymentSource: Int32) -> Bool {
    let internalIndex: Int32 = contractIndex - 1;
    if !this.IsMarmurBankAutoFinanceAvailable() { return false; };

    if internalIndex < 0
      || internalIndex >= ArraySize(this.m_financeVehicleIDs)
      || (paymentSource != 1 && paymentSource != 2)
      || !this.IsMarmurBankAutoFinanceAvailable() {
      return false;
    };

    return this.SetFinancePaymentSource(this.m_financeVehicleIDs[internalIndex], paymentSource);
  }

  private func RemoveFinancePaymentSourceState(id: TweakDBID) -> Void {
    let newVehicleIDs: array<TweakDBID>;
    let newSources: array<Int32>;
    let i: Int32 = 0;

    while i < ArraySize(this.m_financePaymentSourceVehicleIDs) {
      if NotEquals(this.m_financePaymentSourceVehicleIDs[i], id) {
        ArrayPush(newVehicleIDs, this.m_financePaymentSourceVehicleIDs[i]);
        ArrayPush(newSources, this.m_financePaymentSources[i]);
      };
      i += 1;
    };

    this.m_financePaymentSourceVehicleIDs = newVehicleIDs;
    this.m_financePaymentSources = newSources;
  }
  private func TryDebitFinanceAutoPay(player: ref<PlayerPuppet>, id: TweakDBID, amount: Int32) -> Bool {
    let paymentSource: Int32 = this.GetFinancePaymentSource(id);
    if !this.IsMarmurBankAutoFinanceAvailable() { return false; };

    if amount <= 0 || !IsDefined(player) {
      return false;
    };

    if paymentSource == 2 {
      if !this.IsMarmurBankSavingsPaymentSourceAvailable() {
        return false;
      };

      return DebitMarmurVanguardSavingsPayment(
        this.GetGameInstance(),
        amount,
        this.EnsureFinanceContractSerial(id),
        this.GetCurrentGameMinute()
      );
    };

    return this.DebitVanguardCreditWallet(player, amount);
  }

  private func GetFinanceAutoPayIndex(id: TweakDBID) -> Int32 {
    let i: Int32 = 0;

    while i < ArraySize(this.m_financeAutoPayVehicleIDs) {
      if Equals(this.m_financeAutoPayVehicleIDs[i], id) {
        return i;
      };
      i += 1;
    };

    return -1;
  }

  public func IsFinanceAutoPayEnabled(id: TweakDBID) -> Bool {
    let index: Int32 = this.GetFinanceAutoPayIndex(id);

    if index < 0 {
      return false;
    };

    return this.m_financeAutoPayEnabled[index];
  }
  public func SetFinanceAutoPayEnabled(id: TweakDBID, enabled: Bool) -> Void {
    let index: Int32 = this.GetFinanceAutoPayIndex(id);
    let contractIndex: Int32 = this.GetFinanceContractIndex(id);
    if !this.IsMarmurBankAutoFinanceAvailable() { return; };

    if !this.IsVehicleFinanced(id)
      || this.IsVehicleRepossessed(id)
      || (enabled
        && (this.IsFinancePaymentDelinquent(id)
          || contractIndex < 0
          || contractIndex >= ArraySize(this.m_financeNextPaymentMinutes)
          || this.m_financeNextPaymentMinutes[contractIndex] <= this.GetCurrentGameMinute())) {
      return;
    };

    if index >= 0 {
      this.m_financeAutoPayEnabled[index] = enabled;
    } else {
      ArrayPush(this.m_financeAutoPayVehicleIDs, id);
      ArrayPush(this.m_financeAutoPayEnabled, enabled);
    };
  }
  public func ToggleFinanceAutoPay(id: TweakDBID) -> Bool {
    let current: Bool = this.IsFinanceAutoPayEnabled(id);
    let enabled: Bool = !current;
    if !this.IsMarmurBankAutoFinanceAvailable() { return false; };

    if enabled && this.IsFinancePaymentDelinquent(id) {
      return false;
    };
    this.SetFinanceAutoPayEnabled(id, enabled);
    if enabled {
      if !this.IsFinanceAutoPayEnabled(id) {
        return current;
      };
    } else {
      if this.IsFinanceAutoPayEnabled(id) {
        return current;
      };
    };
    if enabled {
      this.PushFinanceEvent(id, 7, 1, this.GetFinanceRemainingMonths(id), 0, this.GetFinanceMonthlyPaymentForVehicle(id));
    } else {
      this.PushFinanceEvent(id, 8, 0, this.GetFinanceRemainingMonths(id), 0, this.GetFinanceMonthlyPaymentForVehicle(id));
    };
    return enabled;
  }

  private func RemoveFinanceAutoPayState(id: TweakDBID) -> Void {
    let newVehicleIDs: array<TweakDBID>;
    let newEnabled: array<Bool>;
    let i: Int32 = 0;

    while i < ArraySize(this.m_financeAutoPayVehicleIDs) {
      if NotEquals(this.m_financeAutoPayVehicleIDs[i], id) {
        ArrayPush(newVehicleIDs, this.m_financeAutoPayVehicleIDs[i]);
        ArrayPush(newEnabled, this.m_financeAutoPayEnabled[i]);
      };
      i += 1;
    };

    this.m_financeAutoPayVehicleIDs = newVehicleIDs;
    this.m_financeAutoPayEnabled = newEnabled;
    this.RemoveFinancePaymentSourceState(id);
  }

  public func GetFinanceSettlementAmount(id: TweakDBID, salePrice: Int32) -> Int32 {
    return salePrice - this.GetFinanceRemainingBalance(id);
  }

  public func CanSellWithFinanceSettlement(id: TweakDBID, salePrice: Int32, player: ref<GameObject>) -> Bool {

    if !IsDefined(player) || !this.IsVehicleFinanced(id) || this.IsVehicleRepossessed(id) {
      return false;
    };

    return this.GetFinanceRemainingBalance(id) <= 0;
  }
  private func CloseFinanceContractAfterSale(id: TweakDBID, payoffAmount: Int32) -> Bool {
    let i: Int32 = this.GetFinanceContractIndex(id);
    let balance: Int32;
    if !this.IsMarmurBankAutoFinanceAvailable() { return false; };

    if i < 0 { return false; };
    balance = this.GetFinanceRemainingBalanceByIndex(i);
    if balance <= 0 || payoffAmount < balance { return false; };
    this.RegisterVanguardCreditContract(id, true);
    this.CaptureVanguardMaturedObligations(id);
    this.RecordVanguardCreditPayment(id, balance, 0, true);
    this.PushFinanceEvent(id, 5, balance, 0, this.m_financeTerms[i], this.m_financeMonthlyPayments[i]);
    this.RemovePaidVanguardCreditContract(id);
    return true;
  }
  public func CanPayOffFinanceContract(id: TweakDBID, player: ref<GameObject>) -> Bool {
    let balance: Int32 = this.GetFinanceRemainingBalance(id);
    return IsDefined(player) && balance > 0 && this.m_transactionSystem.GetItemQuantity(player, MarketSystem.Money()) >= balance;
  }
  public func PayOffFinanceContract(id: TweakDBID, player: ref<GameObject>) -> Bool {
    if !this.IsMarmurBankAutoFinanceAvailable() { return false; };

    return this.MakeCustomFinancePayment(id, this.GetFinanceRemainingBalance(id), player);
  }

  public func StartFinancing(id: TweakDBID, finalPrice: Int32, termMonths: Int32, player: ref<PlayerPuppet>) -> Bool {
    return this.StartFinancingWithAutoPayOptions(id, finalPrice, termMonths, player, true, 3);
  }

  public func StartFinancingWithAutoPayOptions(id: TweakDBID, finalPrice: Int32, termMonths: Int32, player: ref<PlayerPuppet>, autoPayEnabled: Bool, paymentFrequency: Int32) -> Bool {
    return this.StartFinancingWithCustomDownPaymentAutoPayOptions(id, finalPrice, termMonths, player, autoPayEnabled, paymentFrequency, this.GetFinanceDownPaymentForPlayer(finalPrice, player));
  }

  public func StartFinancingWithCustomDownPaymentAutoPayOptions(id: TweakDBID, finalPrice: Int32, termMonths: Int32, player: ref<PlayerPuppet>, autoPayEnabled: Bool, paymentFrequency: Int32, requestedDownPayment: Int32) -> Bool {
    return this.StartFinancingWithCustomDownPaymentAutoPaySourceOptions(id, finalPrice, termMonths, player, autoPayEnabled, paymentFrequency, 1, requestedDownPayment);
  }
  public func StartFinancingWithCustomDownPaymentAutoPaySourceOptions(id: TweakDBID, finalPrice: Int32, termMonths: Int32, player: ref<PlayerPuppet>, autoPayEnabled: Bool, paymentFrequency: Int32, paymentSource: Int32, requestedDownPayment: Int32) -> Bool {
    let normalizedTerm: Int32 = this.NormalizeFinanceTerm(termMonths);
    let normalizedFrequency: Int32 = this.NormalizeFinancePaymentFrequency(paymentFrequency);
    let normalizedPaymentSource: Int32 = this.NormalizeFinancePaymentSource(paymentSource);
    let downPayment: Int32;
    let dueToday: Int32;
    let totalDue: Int32;
    let monthlyPayment: Int32;
    let interestBasisPoints: Int32;

    if !this.IsInstalledVehicleRecord(id)
      || !this.IsPurchasable(id)
      || !IsDefined(player)
      || finalPrice <= 0
      || this.IsSeparatePurchased(id)
      || this.IsVehicleFinanced(id)
      || normalizedTerm <= 0 {
      return false;
    };

    if !this.IsMarmurFinancialCreditAvailable() {
      this.PublishPhoneNotificationRecord(3010, id, finalPrice, 4, this.GetActiveFinanceContractCount());
      return false;
    };

    if normalizedPaymentSource == 2 && !this.IsMarmurBankSavingsPaymentSourceAvailable() {
      return false;
    };

    if !this.HasAvailableAutoFinanceSlot() {
      this.QueueAutoFinanceDenialNotice(id, finalPrice, 3);
      return false;
    };

    downPayment = this.ClampFinanceDownPaymentForPlayer(finalPrice, requestedDownPayment, player);
    dueToday = this.GetFinanceDueTodayWithDownPayment(finalPrice, downPayment);

    if !this.CanFinanceVehicleForPlayerWithDownPayment(finalPrice, player, downPayment) {
      if !this.PlayerCanPay(player, dueToday) {
        this.QueueAutoFinanceDenialNotice(id, finalPrice, 2);
      } else {
        this.QueueAutoFinanceDenialNotice(id, finalPrice, 1);
      };
      return false;
    };

    if dueToday > 0 && !this.DebitVanguardCreditWallet(player, dueToday) {
      this.QueueAutoFinanceDenialNotice(id, finalPrice, 2);
      return false;
    };

    totalDue = this.GetFinanceTotalDueWithDownPayment(finalPrice, normalizedTerm, player, downPayment);
    monthlyPayment = this.GetFinanceMonthlyPaymentWithDownPayment(finalPrice, normalizedTerm, player, downPayment);
    interestBasisPoints = this.GetFinanceInterestBasisPoints(normalizedTerm, player);

    this.Purchase(id);

    ArrayPush(this.m_financeVehicleIDs, id);
    ArrayPush(this.m_financeTerms, normalizedTerm);
    ArrayPush(this.m_financeMonthlyPayments, monthlyPayment);
    ArrayPush(this.m_financeRemainingMonths, normalizedTerm);
    ArrayPush(this.m_financeNextPaymentMinutes, this.GetCurrentGameMinute() + 43200);
    ArrayPush(this.m_financeTotalDue, totalDue);
    ArrayPush(this.m_financeDownPayments, downPayment);
    ArrayPush(this.m_financeInterestPercents, interestBasisPoints);
    ArrayPush(this.m_financePaidAmounts, 0);
    this.AssignNewFinanceContractSerial(id);
    this.m_financeContractsDirty = true;

    this.ClearFinanceDefaultState(id);
    this.ClearFinanceRepossessionState(id);
    this.SetFinancePaymentFrequency(id, normalizedFrequency);
    if !this.SetFinancePaymentSource(id, normalizedPaymentSource) {
      return false;
    };

    this.SetFinanceAutoPayEnabled(id, autoPayEnabled);
    this.IssueNCGTAppreciationVoucher(id, finalPrice, true);

    this.ScheduleCustomerFollowup(id, 1, this.GetCustomerCareFollowupDelayMinutes());
    this.QueuePurchaseConfirmation(id, dueToday, true);
    this.PushFinanceEvent(id, 1, dueToday, normalizedTerm, normalizedTerm, monthlyPayment);
    this.RegisterVanguardCreditContract(id, false);
    this.QueueVanguardCreditApplication();
    this.PublishMarmurBankAutoLoanApprovalNotice(id);
    this.QueueNCGTAppreciationVoucherNotice(id);
    return true;
  }

  public func UpdateFinanceContracts(player: ref<PlayerPuppet>) -> Void {

    return;
  }
  public func MarmurBankServiceFinanceContracts(player: ref<PlayerPuppet>) -> Bool {
    if !IsDefined(player) || !this.IsMarmurBankAutoFinanceAvailable() {
      return false;
    };

    this.UpdateFinanceContractsInternal(player, true);
    return true;
  }
  private func UpdateFinanceContractsInternal(player: ref<PlayerPuppet>, allowAutoPayServicing: Bool) -> Void {
    let now: Int32 = this.GetCurrentGameMinute();
    let i: Int32 = 0;
    let id: TweakDBID;
    let serial: Int32;
    let beforeCount: Int32;
    if !allowAutoPayServicing || !this.IsMarmurBankAutoFinanceAvailable() { return; };

    if !IsDefined(player) { return; };

    if this.m_marmurLastServiceSession != this.GetOdometerSession()
      || this.m_marmurCreditRegistrationSession != this.GetOdometerSession()
      || this.m_marmurCreditRegistrationSequence != this.m_financeContractSerialSequence {
      this.m_financeContractsDirty = true;
    };

    this.FlushDeferredPhoneNotifications();
    if !this.m_financeContractsDirty && now == this.m_lastFinanceUpdateMinute
      && ArraySize(this.m_financeVehicleIDs) == this.m_lastFinanceUpdateContractCount { return; };
    this.m_lastFinanceUpdateMinute = now;
    this.m_marmurLastServiceSession = this.GetOdometerSession();
    this.m_financeContractsDirty = false;
    this.InitializeVanguardCreditContracts();
    while i < ArraySize(this.m_financeVehicleIDs) {
      id = this.m_financeVehicleIDs[i];
      beforeCount = ArraySize(this.m_financeVehicleIDs);
      serial = this.EnsureFinanceContractSerial(id);
      if !this.IsVehicleRepossessed(id) {

        if this.IsFinanceAutoPayEnabled(id) && !allowAutoPayServicing {
          if this.m_financeNextPaymentMinutes[i] <= now { this.m_financeContractsDirty = true; };
        } else {
          this.ServiceVanguardCreditContract(id, player, allowAutoPayServicing);
        };
        if this.IsVehicleFinanced(id) && this.GetVanguardCreditFact(serial, "arrears") > 0 {

          this.m_financeContractsDirty = true;
          this.QueueFinanceDelinquencyWarningEvents(id, this.GetVanguardCreditFact(serial, "oldest_minute"), now,
            this.GetVanguardCreditFact(serial, "arrears"), this.GetFinanceRemainingMonths(id),
            this.GetFinanceTermMonthsForVehicle(id), this.GetFinanceMonthlyPaymentForVehicle(id), false);
          if allowAutoPayServicing && this.IsMarmurBankAutoFinanceAvailable()
            && now >= this.GetVanguardCreditFact(serial, "oldest_minute") + 10080 {
            this.MarkVehicleRepossessed(id, this.GetFinanceRemainingBalance(id), this.GetFinanceRemainingMonths(id),
              this.GetFinanceTermMonthsForVehicle(id), this.GetFinanceMonthlyPaymentForVehicle(id));
          };
        };
      };
      if ArraySize(this.m_financeVehicleIDs) == beforeCount { i += 1; };
    };
    this.m_lastFinanceUpdateContractCount = ArraySize(this.m_financeVehicleIDs);
  }

  public func GetFinanceEventCount() -> Int32 {
    return ArraySize(this.m_financeEventVehicleIDs);
  }

  public func GetFinanceEventVehicleKeyAt(index: Int32) -> String {
    if index < 0 || index >= ArraySize(this.m_financeEventVehicleIDs) {
      return "";
    };

    return TDBID.ToStringDEBUG(this.m_financeEventVehicleIDs[index]);
  }

  public func GetFinanceEventVehicleNameAt(index: Int32) -> String {
    let record: ref<Vehicle_Record>;

    if index < 0 || index >= ArraySize(this.m_financeEventVehicleIDs) {
      return "vehicle";
    };

    record = TweakDBInterface.GetVehicleRecord(this.m_financeEventVehicleIDs[index]);
    if IsDefined(record) {
      return GetLocalizedTextByKey(record.DisplayName());
    };

    return "vehicle";
  }

  public func GetMarmurAutoLoanEventContractSerialAt(index: Int32) -> Int32 {
    if index < 0 || index >= ArraySize(this.m_marmurAutoEventContractSerials) { return 0; };
    return this.m_marmurAutoEventContractSerials[index];
  }

  public func GetFinanceEventKindAt(index: Int32) -> Int32 {
    if index < 0 || index >= ArraySize(this.m_financeEventKinds) {
      return 0;
    };

    return this.m_financeEventKinds[index];
  }

  public func GetFinanceEventMinuteAt(index: Int32) -> Int32 {
    if index < 0 || index >= ArraySize(this.m_financeEventMinutes) {
      return 0;
    };

    return this.m_financeEventMinutes[index];
  }

  public func GetFinanceEventAmountAt(index: Int32) -> Int32 {
    if index < 0 || index >= ArraySize(this.m_financeEventAmounts) {
      return 0;
    };

    return this.m_financeEventAmounts[index];
  }

  public func GetFinanceEventRemainingMonthsAt(index: Int32) -> Int32 {
    if index < 0 || index >= ArraySize(this.m_financeEventRemainingMonths) {
      return 0;
    };

    return this.m_financeEventRemainingMonths[index];
  }

  public func GetFinanceEventTermAt(index: Int32) -> Int32 {
    if index < 0 || index >= ArraySize(this.m_financeEventTerms) {
      return 0;
    };

    return this.m_financeEventTerms[index];
  }

  public func GetFinanceEventMonthlyPaymentAt(index: Int32) -> Int32 {
    if index < 0 || index >= ArraySize(this.m_financeEventMonthlyPayments) {
      return 0;
    };

    return this.m_financeEventMonthlyPayments[index];
  }

  public func GetFinanceEventPaymentSourceAt(index: Int32) -> Int32 {
    if index < 0 || index >= ArraySize(this.m_financeEventKinds) || index >= ArraySize(this.m_financeEventPaymentSources) {
      return 1;
    };

    return this.NormalizeFinancePaymentSource(this.m_financeEventPaymentSources[index]);
  }

  public func GetFinanceEventMessageAt(index: Int32) -> String {
    let vehicleName: String = this.GetFinanceEventVehicleNameAt(index);
    let kind: Int32 = this.GetFinanceEventKindAt(index);
    let amount: Int32 = this.GetFinanceEventAmountAt(index);
    let remainingMonths: Int32 = this.GetFinanceEventRemainingMonthsAt(index);
    let monthlyPayment: Int32 = this.GetFinanceEventMonthlyPaymentAt(index);

    if kind == 1 {
      return VanguardAutoLocalization.Text2(1868, s"Vanguard Auto: Financing approved for \(vehicleName). Due today processed: \(this.FormatMoney(amount)) including the flat $500 dealer fee. Your selected Auto-Pay request and payment schedule were submitted to Marmur Bank for servicing in Marmur Bank > Loans.", s"\(vehicleName)", s"\(this.FormatMoney(amount))");
    };

    if kind == 2 {
      return VanguardAutoLocalization.Text3(1863, s"Marmur Bank Auto Loans: Scheduled payment of \(this.FormatMoney(amount)) was posted for \(vehicleName). \(remainingMonths) scheduled payments remain.", s"\(this.FormatMoney(amount))", s"\(vehicleName)", s"\(remainingMonths)");
    };

    if kind == 3 {
      return VanguardAutoLocalization.Text1(1758, s"Vanguard Auto Finance: Repossession complete for \(vehicleName). Payment was not received within the contractual grace period. Vehicle access and summon privileges are suspended.", s"\(vehicleName)");
    };

    if kind == 4 {
      return VanguardAutoLocalization.Text1(1864, s"Marmur Bank Auto Loans: Final scheduled payment received for \(vehicleName). The title is now clear.", s"\(vehicleName)");
    };

    if kind == 9 {
      return VanguardAutoLocalization.Text1(1764, s"Vanguard Auto Finance: Payment missed for \(vehicleName). The account is now past due. Submit payment in Marmur Bank > Loans to avoid recovery review.", s"\(vehicleName)");
    };

    if kind == 10 {
      return VanguardAutoLocalization.Text2(1765, s"Vanguard Auto Finance: Upcoming payment reminder. \(this.FormatMoney(amount)) is scheduled for \(vehicleName) in roughly 3 days.", s"\(this.FormatMoney(amount))", s"\(vehicleName)");
    };

    if kind == 11 {
      return VanguardAutoLocalization.Text2(1766, s"Vanguard Auto Finance: Payment reminder. \(this.FormatMoney(amount)) is due for \(vehicleName) within 24 hours.", s"\(this.FormatMoney(amount))", s"\(vehicleName)");
    };

    if kind == 12 {
      return VanguardAutoLocalization.Text2(1767, s"Vanguard Auto Finance: Payment due today. \(this.FormatMoney(amount)) is scheduled for \(vehicleName).", s"\(this.FormatMoney(amount))", s"\(vehicleName)");
    };

    if kind == 13 {
      return VanguardAutoLocalization.Text2(1867, s"Marmur Bank Auto Loans: Auto-Pay failed for \(vehicleName). We could not process \(this.FormatMoney(amount)). Submit a scheduled payment in Marmur Bank > Loans to prevent recovery action.", s"\(vehicleName)", s"\(this.FormatMoney(amount))");
    };

    if kind == 15 {
      return VanguardAutoLocalization.Text1(1769, s"Vanguard Auto Finance: Late payment notice for \(vehicleName). The account remains past due and may receive additional review if payment is not received.", s"\(vehicleName)");
    };

    if kind == 16 {
      return VanguardAutoLocalization.Text1(1770, s"Vanguard Auto Finance: Pre-repossession notice for \(vehicleName). Continued nonpayment may result in vehicle recovery action.", s"\(vehicleName)");
    };

    if kind == 17 {
      return VanguardAutoLocalization.Text1(1771, s"Vanguard Auto Finance: Final pre-repossession warning for \(vehicleName). Payment is required before the next account review cycle to avoid repossession.", s"\(vehicleName)");
    };

    if kind == 18 {
      return s"Vanguard Auto Finance: Refinance accepted for \(vehicleName). New contract balance: \(this.FormatMoney(amount)) over \(remainingMonths) months at \(this.FormatMoney(monthlyPayment))/mo. Terms were based on current credit profile.";
    };

    if kind == 5 {
      return VanguardAutoLocalization.Text1(1760, s"Vanguard Auto Finance: Payoff received for \(vehicleName). The title is now clear.", s"\(vehicleName)");
    };

    if kind == 6 {
      return VanguardAutoLocalization.Text2(1761, s"Vanguard Auto Finance: Extra payment of \(this.FormatMoney(amount)) received for \(vehicleName). Remaining balance has been updated.", s"\(this.FormatMoney(amount))", s"\(vehicleName)");
    };

    if kind == 7 {
      return VanguardAutoLocalization.Text1(1865, s"Marmur Bank Auto Loans: Auto-Pay is now enabled for \(vehicleName).", s"\(vehicleName)");
    };

    if kind == 8 {
      return VanguardAutoLocalization.Text1(1866, s"Marmur Bank Auto Loans: Auto-Pay has been disabled for \(vehicleName). Open Marmur Bank > Loans to make payments.", s"\(vehicleName)");
    };

    return VanguardAutoLocalization.Text(1772, "Vanguard Auto: Garage account status updated.");
  }

  public func IsInDangerZone(player: ref<PlayerPuppet>) -> Bool {
    let bb: ref<IBlackboard> = player.GetPlayerStateMachineBlackboard();
    let zone: Int32 = bb.GetInt(GetAllBlackboardDefs().PlayerStateMachine.Zones);
    let inDanger: Bool = zone > 2;
    return inDanger;
  }

  private func RefreshMarmurOwnedVehicleSnapshot() -> Void {
    this.m_marmurOwnedVehicleSnapshot = this.GetOwnedVehiclesData();
  }

  private func GetMarmurOwnedVehicleSnapshotAt(vehicleIndex: Int32) -> ref<AutofixerItemData> {
    let internalIndex: Int32 = vehicleIndex - 1;

    if internalIndex < 0 || internalIndex >= ArraySize(this.m_marmurOwnedVehicleSnapshot) {
      return null;
    };

    return this.m_marmurOwnedVehicleSnapshot[internalIndex];
  }

  public func GetMarmurBankVanguardCompatibilityVersion() -> Int32 {
    return 1513;
  }

  public func MarmurGetOwnedVehicleCount() -> Int32 {
    this.RefreshMarmurOwnedVehicleSnapshot();
    return ArraySize(this.m_marmurOwnedVehicleSnapshot);
  }

  public func MarmurGetOwnedVehicleNameAt(vehicleIndex: Int32) -> String {
    let data: ref<AutofixerItemData> = this.GetMarmurOwnedVehicleSnapshotAt(vehicleIndex);

    if !IsDefined(data) {
      return VanguardAutoLocalization.Text1(1784, s"Vanguard Vehicle #\(vehicleIndex)", s"\(vehicleIndex)");
    };

    return data.title;
  }

  public func MarmurIsOwnedVehicleFinancedAt(vehicleIndex: Int32) -> Bool {
    let data: ref<AutofixerItemData> = this.GetMarmurOwnedVehicleSnapshotAt(vehicleIndex);

    if !IsDefined(data) {
      return false;
    };

    return data.financed || data.defaulted || data.repossessed || this.IsVehicleFinanced(data.vehicleID) || this.IsVehicleDefaulted(data.vehicleID) || this.IsVehicleRepossessed(data.vehicleID);
  }

  public func MarmurIsOwnedVehicleEligibleAt(vehicleIndex: Int32) -> Bool {
    let data: ref<AutofixerItemData> = this.GetMarmurOwnedVehicleSnapshotAt(vehicleIndex);

    if !IsDefined(data) || data.sold || data.price <= 0 || !TDBID.IsValid(data.vehicleID) {
      return false;
    };

    if ArrayContains(this.m_soldVehicles, data.vehicleID) || data.destroyed || this.IsVanguardUninsuredVehicleDestroyed(data.vehicleID) {
      return false;
    };

    if this.IsVanguardCoverageTotalLossLocked(data.vehicleID) {
      return false;
    };

    return !this.MarmurIsOwnedVehicleFinancedAt(vehicleIndex);
  }

  public func MarmurGetOwnedVehicleLiquidationValueAt(vehicleIndex: Int32) -> Int32 {
    let data: ref<AutofixerItemData> = this.GetMarmurOwnedVehicleSnapshotAt(vehicleIndex);

    if !this.MarmurIsOwnedVehicleEligibleAt(vehicleIndex) || !IsDefined(data) {
      return 0;
    };

    return Max(0, data.price);
  }

  public func MarmurBankLiquidateOwnedVehicleAt(vehicleIndex: Int32) -> Int32 {
    let data: ref<AutofixerItemData> = this.GetMarmurOwnedVehicleSnapshotAt(vehicleIndex);
    let liquidationValue: Int32;
    let removed: Bool = false;

    if !this.MarmurIsOwnedVehicleEligibleAt(vehicleIndex) || !IsDefined(data) {
      return 0;
    };

    liquidationValue = Max(0, data.price);
    if liquidationValue <= 0 {
      return 0;
    };

    removed = RemoveVehicle(this.GetGameInstance(), this.m_vehicleSystem, data.vehicleID);
    if !removed {
    };

    data.sold = true;
    if !ArrayContains(this.m_soldVehicles, data.vehicleID) {
      ArrayPush(this.m_soldVehicles, data.vehicleID);
      this.AdvanceSoldVehicleLedgerRevision();
      this.m_deactivateVehiclesDirty = true;
    };
    this.InvalidateNCGTAppreciation(data.vehicleID);
    this.RemoveNCGTPerformancePackageState(data.vehicleID);

    return liquidationValue;
  }

  public func GetNCGTPerformancePackageAPIVersion() -> Int32 {
    return 2;
  }

  public func SetNCGTPerformancePackageIntegrationAvailable(available: Bool, apiVersion: Int32) -> Bool {
    this.m_ncgtPerformanceIntegrationAvailable = available && apiVersion >= 2;
    if this.m_ncgtPerformanceIntegrationAvailable {
      this.m_ncgtPerformanceIntegrationAPIVersion = apiVersion;
      this.m_ncgtPerformanceIntegrationHeartbeatAt = EngineTime.ToFloat(
        GameInstance.GetEngineTime(this.GetGameInstance())
      );
    } else {
      this.m_ncgtPerformanceIntegrationAPIVersion = 0;
      this.m_ncgtPerformanceIntegrationHeartbeatAt = 0.00;
    };

    return this.m_ncgtPerformanceIntegrationAvailable;
  }

  public func IsNCGTPerformancePackageIntegrationAvailable() -> Bool {
    let now: Float;

    if !this.m_ncgtPerformanceIntegrationAvailable
      || this.m_ncgtPerformanceIntegrationAPIVersion < 2 {
      return false;
    };

    now = EngineTime.ToFloat(GameInstance.GetEngineTime(this.GetGameInstance()));
    if now < this.m_ncgtPerformanceIntegrationHeartbeatAt
      || now - this.m_ncgtPerformanceIntegrationHeartbeatAt > 10.00 {
      this.m_ncgtPerformanceIntegrationAvailable = false;
      this.m_ncgtPerformanceIntegrationAPIVersion = 0;
      this.m_ncgtPerformanceIntegrationHeartbeatAt = 0.00;
      return false;
    };

    return true;
  }

  public func ResolveNCGTPerformanceVehicleClass(id: TweakDBID) -> Int32 {
    let record: ref<Vehicle_Record>;
    let identity: String;

    if !TDBID.IsValid(id) {
      return 0;
    };

    record = TweakDBInterface.GetVehicleRecord(id);
    if !IsDefined(record) || !IsDefined(record.Type()) {
      return 0;
    };

    identity = StrLower(s"\(TDBID.ToStringDEBUG(id)) \(NameToString(record.AppearanceName()))");
    if StrContains(identity, "vehicle.av_")
      || StrContains(identity, "v_av_")
      || StrContains(identity, ".av_")
      || StrContains(identity, "_dav")
      || StrContains(identity, "aerial")
      || StrContains(identity, "flying")
      || StrContains(identity, "hover")
      || StrContains(identity, "helicopter")
      || StrContains(identity, "panzer")
      || StrContains(identity, "tank")
      || StrContains(identity, "excalibur")
      || StrContains(identity, "manticore")
      || StrContains(identity, "atlus")
      || StrContains(identity, "surveyor")
      || StrContains(identity, "mayhem")
      || StrContains(identity, "valgus")
      || StrContains(identity, "basilisk") {
      return 0;
    };

    if Equals(record.Type().Type(), gamedataVehicleType.Bike) {
      return 3;
    };

    if !Equals(record.Type().Type(), gamedataVehicleType.Car) {
      return 0;
    };

    if StrContains(identity, "truck")
      || StrContains(identity, "utility4")
      || StrContains(identity, "standard3")
      || StrContains(identity, "emperor")
      || StrContains(identity, "legatus")
      || StrContains(identity, "mackinaw")
      || StrContains(identity, "ramtrx")
      || StrContains(identity, "supron")
      || StrContains(identity, "columbus")
      || StrContains(identity, "hellhound")
      || StrContains(identity, "kurtz")
      || StrContains(identity, "pickup")
      || StrContains(identity, "heavy")
      || StrContains(identity, "semi_")
      || StrContains(identity, "_van_")
      || StrContains(identity, "minivan") {
      return 2;
    };

    return 1;
  }

  public func IsNCGTPerformancePackageCodeForClass(vehicleClass: Int32, packageCode: Int32) -> Bool {
    return (vehicleClass == 1 && packageCode >= 1 && packageCode <= 3)
      || (vehicleClass == 2 && packageCode >= 4 && packageCode <= 6)
      || (vehicleClass == 3 && packageCode >= 7 && packageCode <= 9);
  }

  public func GetNCGTPerformancePackagePartsSubtotal(vehicleClass: Int32, packageCode: Int32) -> Int32 {
    if !this.IsNCGTPerformancePackageCodeForClass(vehicleClass, packageCode) {
      return 0;
    };

    switch packageCode {
      case 1:
        return 3250;
      case 2:
        return 6800;
      case 3:
        return 12000;
      case 4:
        return 3250;
      case 5:
        return 6800;
      case 6:
        return 10350;
      case 7:
        return 3450;
      case 8:
        return 8600;
      case 9:
        return 12200;
    };

    return 0;
  }

  public func GetNCGTPerformancePackageLabor(vehicleClass: Int32, packageCode: Int32) -> Int32 {
    if !this.IsNCGTPerformancePackageCodeForClass(vehicleClass, packageCode) {
      return 0;
    };

    switch packageCode {
      case 1:
        return 1350;
      case 2:
        return 2250;
      case 3:
        return 3000;
      case 4:
        return 1350;
      case 5:
        return 2250;
      case 6:
        return 3825;
      case 7:
        return 1350;
      case 8:
        return 3450;
      case 9:
        return 3975;
    };

    return 0;
  }

  public func GetNCGTPerformancePackageVoucherBpsForPrice(vehiclePrice: Int32) -> Int32 {
    return this.GetNCGTAppreciationDiscountBpsForPrice(vehiclePrice);
  }

  public func GetNCGTPerformancePackageDiscount(vehicleClass: Int32, packageCode: Int32, vehiclePrice: Int32) -> Int32 {
    let partsSubtotal: Int32 = this.GetNCGTPerformancePackagePartsSubtotal(vehicleClass, packageCode);
    let discountBps: Int32 = this.GetNCGTPerformancePackageVoucherBpsForPrice(vehiclePrice);

    if partsSubtotal <= 0 || discountBps <= 0 {
      return 0;
    };

    return (partsSubtotal * discountBps) / 10000;
  }

  public func GetNCGTPerformancePackageFinalTotal(vehicleClass: Int32, packageCode: Int32, vehiclePrice: Int32) -> Int32 {
    let partsSubtotal: Int32 = this.GetNCGTPerformancePackagePartsSubtotal(vehicleClass, packageCode);
    let labor: Int32 = this.GetNCGTPerformancePackageLabor(vehicleClass, packageCode);
    let discount: Int32 = this.GetNCGTPerformancePackageDiscount(vehicleClass, packageCode, vehiclePrice);

    if partsSubtotal <= 0 || labor <= 0 {
      return 0;
    };

    return Max(0, partsSubtotal + labor - Min(partsSubtotal, discount));
  }

  private func IsNCGTPerformancePackageQuoteValid(id: TweakDBID, vehicleClass: Int32, packageCode: Int32, vehiclePrice: Int32) -> Bool {
    return TDBID.IsValid(id)
      && vehicleClass >= 1
      && vehicleClass <= 3
      && this.ResolveNCGTPerformanceVehicleClass(id) == vehicleClass
      && this.IsNCGTPerformancePackageCodeForClass(vehicleClass, packageCode)
      && vehiclePrice > 0
      && this.GetNCGTPerformancePackagePartsSubtotal(vehicleClass, packageCode) > 0
      && this.GetNCGTPerformancePackageLabor(vehicleClass, packageCode) > 0
      && this.GetNCGTPerformancePackageFinalTotal(vehicleClass, packageCode, vehiclePrice) > 0;
  }

  private func NormalizeNCGTPerformancePackageArrays() -> Void {
    let count: Int32 = ArraySize(this.m_ncgtPerformanceVehicleIDs);
    let legacyIndex: Int32;

    while ArraySize(this.m_ncgtPerformanceVehicleClasses) < ArraySize(this.m_ncgtPerformanceVehicleIDs) {
      legacyIndex = ArraySize(this.m_ncgtPerformanceVehicleClasses);
      if legacyIndex < ArraySize(this.m_ncgtPerformancePackageCodes)
        && this.m_ncgtPerformancePackageCodes[legacyIndex] >= 1
        && this.m_ncgtPerformancePackageCodes[legacyIndex] <= 3 {
        ArrayPush(this.m_ncgtPerformanceVehicleClasses, 1);
      } else {
        ArrayPush(this.m_ncgtPerformanceVehicleClasses, this.ResolveNCGTPerformanceVehicleClass(this.m_ncgtPerformanceVehicleIDs[legacyIndex]));
      };
    };

    if ArraySize(this.m_ncgtPerformanceVehicleClasses) < count {
      count = ArraySize(this.m_ncgtPerformanceVehicleClasses);
    };
    if ArraySize(this.m_ncgtPerformancePackageCodes) < count {
      count = ArraySize(this.m_ncgtPerformancePackageCodes);
    };
    if ArraySize(this.m_ncgtPerformancePartsSubtotals) < count {
      count = ArraySize(this.m_ncgtPerformancePartsSubtotals);
    };
    if ArraySize(this.m_ncgtPerformanceLaborTotals) < count {
      count = ArraySize(this.m_ncgtPerformanceLaborTotals);
    };
    if ArraySize(this.m_ncgtPerformanceVoucherBps) < count {
      count = ArraySize(this.m_ncgtPerformanceVoucherBps);
    };
    if ArraySize(this.m_ncgtPerformanceDiscounts) < count {
      count = ArraySize(this.m_ncgtPerformanceDiscounts);
    };
    if ArraySize(this.m_ncgtPerformanceFinalTotals) < count {
      count = ArraySize(this.m_ncgtPerformanceFinalTotals);
    };
    if ArraySize(this.m_ncgtPerformancePaymentModes) < count {
      count = ArraySize(this.m_ncgtPerformancePaymentModes);
    };
    if ArraySize(this.m_ncgtPerformanceTransactionStates) < count {
      count = ArraySize(this.m_ncgtPerformanceTransactionStates);
    };
    if ArraySize(this.m_ncgtPerformanceSerials) < count {
      count = ArraySize(this.m_ncgtPerformanceSerials);
    };
    if ArraySize(this.m_ncgtPerformanceInstalledRevisions) < count {
      count = ArraySize(this.m_ncgtPerformanceInstalledRevisions);
    };
    if ArraySize(this.m_ncgtPerformanceFailureCodes) < count {
      count = ArraySize(this.m_ncgtPerformanceFailureCodes);
    };
    if ArraySize(this.m_ncgtPerformanceVehiclePrices) < count {
      count = ArraySize(this.m_ncgtPerformanceVehiclePrices);
    };
    if ArraySize(this.m_ncgtPerformanceFinanced) < count {
      count = ArraySize(this.m_ncgtPerformanceFinanced);
    };
    if ArraySize(this.m_ncgtPerformanceRollbackRefunds) < count {
      count = ArraySize(this.m_ncgtPerformanceRollbackRefunds);
    };
    if ArraySize(this.m_ncgtPerformanceRollbackFinanceTotals) < count {
      count = ArraySize(this.m_ncgtPerformanceRollbackFinanceTotals);
    };
    if ArraySize(this.m_ncgtPerformanceRollbackFinanceMonthly) < count {
      count = ArraySize(this.m_ncgtPerformanceRollbackFinanceMonthly);
    };
    if ArraySize(this.m_ncgtPerformanceRollbackFinanceDownPayments) < count {
      count = ArraySize(this.m_ncgtPerformanceRollbackFinanceDownPayments);
    };

    ArrayResize(this.m_ncgtPerformanceVehicleIDs, count);
    ArrayResize(this.m_ncgtPerformanceVehicleClasses, count);
    ArrayResize(this.m_ncgtPerformancePackageCodes, count);
    ArrayResize(this.m_ncgtPerformancePartsSubtotals, count);
    ArrayResize(this.m_ncgtPerformanceLaborTotals, count);
    ArrayResize(this.m_ncgtPerformanceVoucherBps, count);
    ArrayResize(this.m_ncgtPerformanceDiscounts, count);
    ArrayResize(this.m_ncgtPerformanceFinalTotals, count);
    ArrayResize(this.m_ncgtPerformancePaymentModes, count);
    ArrayResize(this.m_ncgtPerformanceTransactionStates, count);
    ArrayResize(this.m_ncgtPerformanceSerials, count);
    ArrayResize(this.m_ncgtPerformanceInstalledRevisions, count);
    ArrayResize(this.m_ncgtPerformanceFailureCodes, count);
    ArrayResize(this.m_ncgtPerformanceVehiclePrices, count);
    ArrayResize(this.m_ncgtPerformanceFinanced, count);
    ArrayResize(this.m_ncgtPerformanceRollbackRefunds, count);
    ArrayResize(this.m_ncgtPerformanceRollbackFinanceTotals, count);
    ArrayResize(this.m_ncgtPerformanceRollbackFinanceMonthly, count);
    ArrayResize(this.m_ncgtPerformanceRollbackFinanceDownPayments, count);
  }

  private func GetNCGTPerformancePackageIndexBySerial(serial: Int32) -> Int32 {
    let i: Int32;

    if serial <= 0 {
      return -1;
    };

    this.NormalizeNCGTPerformancePackageArrays();
    i = ArraySize(this.m_ncgtPerformanceSerials) - 1;
    while i >= 0 {
      if this.m_ncgtPerformanceSerials[i] == serial {
        return i;
      };
      i -= 1;
    };

    return -1;
  }

  private func GetNCGTPerformancePackageIndexByVehicle(id: TweakDBID) -> Int32 {
    let i: Int32;

    if !TDBID.IsValid(id) {
      return -1;
    };

    this.NormalizeNCGTPerformancePackageArrays();
    i = ArraySize(this.m_ncgtPerformanceVehicleIDs) - 1;
    while i >= 0 {
      if this.NCGTAppreciationVehicleIDsMatch(this.m_ncgtPerformanceVehicleIDs[i], id) {
        return i;
      };
      i -= 1;
    };

    return -1;
  }

  private func GetPendingNCGTPerformancePackageIndex() -> Int32 {
    let i: Int32 = 0;

    this.NormalizeNCGTPerformancePackageArrays();
    while i < ArraySize(this.m_ncgtPerformanceTransactionStates) {
      if this.m_ncgtPerformanceTransactionStates[i] == 1 {
        return i;
      };
      i += 1;
    };

    return -1;
  }

  private func RecordPendingNCGTPerformancePackage(
    id: TweakDBID,
    vehicleClass: Int32,
    packageCode: Int32,
    vehiclePrice: Int32,
    paymentMode: Int32,
    financed: Bool,
    rollbackRefund: Int32,
    rollbackFinanceTotal: Int32,
    rollbackFinanceMonthly: Int32,
    rollbackFinanceDownPayment: Int32
  ) -> Bool {
    let partsSubtotal: Int32 = this.GetNCGTPerformancePackagePartsSubtotal(vehicleClass, packageCode);
    let labor: Int32 = this.GetNCGTPerformancePackageLabor(vehicleClass, packageCode);
    let discountBps: Int32 = this.GetNCGTPerformancePackageVoucherBpsForPrice(vehiclePrice);
    let discount: Int32 = this.GetNCGTPerformancePackageDiscount(vehicleClass, packageCode, vehiclePrice);
    let finalTotal: Int32 = this.GetNCGTPerformancePackageFinalTotal(vehicleClass, packageCode, vehiclePrice);

    if !this.IsNCGTPerformancePackageIntegrationAvailable()
      || !TDBID.IsValid(id)
      || !this.IsNCGTPerformancePackageQuoteValid(id, vehicleClass, packageCode, vehiclePrice)
      || (paymentMode != 1 && paymentMode != 2)
      || partsSubtotal <= 0
      || labor <= 0
      || discountBps <= 0
      || finalTotal <= 0 {
      return false;
    };

    this.RemoveNCGTPerformancePackageState(id);
    this.m_ncgtPerformanceSequence += 1;
    if this.m_ncgtPerformanceSequence <= 0 {
      this.m_ncgtPerformanceSequence = 1;
    };

    ArrayPush(this.m_ncgtPerformanceVehicleIDs, id);
    ArrayPush(this.m_ncgtPerformanceVehicleClasses, vehicleClass);
    ArrayPush(this.m_ncgtPerformancePackageCodes, packageCode);
    ArrayPush(this.m_ncgtPerformancePartsSubtotals, partsSubtotal);
    ArrayPush(this.m_ncgtPerformanceLaborTotals, labor);
    ArrayPush(this.m_ncgtPerformanceVoucherBps, discountBps);
    ArrayPush(this.m_ncgtPerformanceDiscounts, discount);
    ArrayPush(this.m_ncgtPerformanceFinalTotals, finalTotal);
    ArrayPush(this.m_ncgtPerformancePaymentModes, paymentMode);
    ArrayPush(this.m_ncgtPerformanceTransactionStates, 1);
    ArrayPush(this.m_ncgtPerformanceSerials, this.m_ncgtPerformanceSequence);
    ArrayPush(this.m_ncgtPerformanceInstalledRevisions, 0);
    ArrayPush(this.m_ncgtPerformanceFailureCodes, 0);
    ArrayPush(this.m_ncgtPerformanceVehiclePrices, vehiclePrice);
    ArrayPush(this.m_ncgtPerformanceFinanced, financed);
    ArrayPush(this.m_ncgtPerformanceRollbackRefunds, Max(0, rollbackRefund));
    ArrayPush(this.m_ncgtPerformanceRollbackFinanceTotals, Max(0, rollbackFinanceTotal));
    ArrayPush(this.m_ncgtPerformanceRollbackFinanceMonthly, Max(0, rollbackFinanceMonthly));
    ArrayPush(this.m_ncgtPerformanceRollbackFinanceDownPayments, Max(0, rollbackFinanceDownPayment));
    return true;
  }

  public func HasPendingNCGTPerformancePackage() -> Bool {
    return this.GetPendingNCGTPerformancePackageIndex() >= 0;
  }

  public func GetPendingNCGTPerformancePackageSerial() -> Int32 {
    let index: Int32 = this.GetPendingNCGTPerformancePackageIndex();
    if index < 0 {
      return 0;
    };
    return this.m_ncgtPerformanceSerials[index];
  }

  public func GetPendingNCGTPerformancePackageVehicleID() -> TweakDBID {
    let index: Int32 = this.GetPendingNCGTPerformancePackageIndex();
    if index < 0 {
      return TDBID.Create("");
    };
    return this.m_ncgtPerformanceVehicleIDs[index];
  }

  public func GetPendingNCGTPerformancePackageVehicleClass() -> Int32 {
    let index: Int32 = this.GetPendingNCGTPerformancePackageIndex();
    if index < 0 {
      return 0;
    };
    return this.m_ncgtPerformanceVehicleClasses[index];
  }

  public func GetPendingNCGTPerformancePackageCode() -> Int32 {
    let index: Int32 = this.GetPendingNCGTPerformancePackageIndex();
    if index < 0 {
      return 0;
    };
    return this.m_ncgtPerformancePackageCodes[index];
  }

  public func GetPendingNCGTPerformancePackagePartsSubtotal() -> Int32 {
    let index: Int32 = this.GetPendingNCGTPerformancePackageIndex();
    if index < 0 {
      return 0;
    };
    return this.m_ncgtPerformancePartsSubtotals[index];
  }

  public func GetPendingNCGTPerformancePackageLabor() -> Int32 {
    let index: Int32 = this.GetPendingNCGTPerformancePackageIndex();
    if index < 0 {
      return 0;
    };
    return this.m_ncgtPerformanceLaborTotals[index];
  }

  public func GetPendingNCGTPerformancePackageDiscount() -> Int32 {
    let index: Int32 = this.GetPendingNCGTPerformancePackageIndex();
    if index < 0 {
      return 0;
    };
    return this.m_ncgtPerformanceDiscounts[index];
  }

  public func GetPendingNCGTPerformancePackageFinalTotal() -> Int32 {
    let index: Int32 = this.GetPendingNCGTPerformancePackageIndex();
    if index < 0 {
      return 0;
    };
    return this.m_ncgtPerformanceFinalTotals[index];
  }

  public func GetPendingNCGTPerformancePackageVoucherBps() -> Int32 {
    let index: Int32 = this.GetPendingNCGTPerformancePackageIndex();
    if index < 0 {
      return 0;
    };
    return this.m_ncgtPerformanceVoucherBps[index];
  }

  public func GetNCGTPerformancePackageCode(id: TweakDBID) -> Int32 {
    let index: Int32 = this.GetNCGTPerformancePackageIndexByVehicle(id);
    if index < 0 || this.m_ncgtPerformanceTransactionStates[index] == 3 {
      return 0;
    };
    return this.m_ncgtPerformancePackageCodes[index];
  }

  public func GetNCGTPerformancePackageReceiptVehicleClass(id: TweakDBID) -> Int32 {
    let index: Int32 = this.GetNCGTPerformancePackageIndexByVehicle(id);
    if index < 0 {
      return 0;
    };
    return this.m_ncgtPerformanceVehicleClasses[index];
  }

  public func GetNCGTPerformancePackageState(id: TweakDBID) -> Int32 {
    let index: Int32 = this.GetNCGTPerformancePackageIndexByVehicle(id);
    if index < 0 {
      return 0;
    };
    return this.m_ncgtPerformanceTransactionStates[index];
  }

  public func GetNCGTPerformancePackageSerial(id: TweakDBID) -> Int32 {
    let index: Int32 = this.GetNCGTPerformancePackageIndexByVehicle(id);
    if index < 0 {
      return 0;
    };
    return this.m_ncgtPerformanceSerials[index];
  }

  public func GetNCGTPerformancePackageReceiptPartsSubtotal(id: TweakDBID) -> Int32 {
    let index: Int32 = this.GetNCGTPerformancePackageIndexByVehicle(id);
    if index < 0 {
      return 0;
    };
    return this.m_ncgtPerformancePartsSubtotals[index];
  }

  public func GetNCGTPerformancePackageReceiptLabor(id: TweakDBID) -> Int32 {
    let index: Int32 = this.GetNCGTPerformancePackageIndexByVehicle(id);
    if index < 0 {
      return 0;
    };
    return this.m_ncgtPerformanceLaborTotals[index];
  }

  public func GetNCGTPerformancePackageReceiptVoucherBps(id: TweakDBID) -> Int32 {
    let index: Int32 = this.GetNCGTPerformancePackageIndexByVehicle(id);
    if index < 0 {
      return 0;
    };
    return this.m_ncgtPerformanceVoucherBps[index];
  }

  public func GetNCGTPerformancePackageReceiptDiscount(id: TweakDBID) -> Int32 {
    let index: Int32 = this.GetNCGTPerformancePackageIndexByVehicle(id);
    if index < 0 {
      return 0;
    };
    return this.m_ncgtPerformanceDiscounts[index];
  }

  public func GetNCGTPerformancePackageReceiptFinalTotal(id: TweakDBID) -> Int32 {
    let index: Int32 = this.GetNCGTPerformancePackageIndexByVehicle(id);
    if index < 0 {
      return 0;
    };
    return this.m_ncgtPerformanceFinalTotals[index];
  }

  public func GetNCGTPerformancePackageReceiptPaymentMode(id: TweakDBID) -> Int32 {
    let index: Int32 = this.GetNCGTPerformancePackageIndexByVehicle(id);
    if index < 0 {
      return 0;
    };
    return this.m_ncgtPerformancePaymentModes[index];
  }

  public func CompleteNCGTPerformancePackage(serial: Int32, installedRevision: Int32) -> Bool {
    let index: Int32 = this.GetNCGTPerformancePackageIndexBySerial(serial);

    if index < 0 || installedRevision < 0 {
      return false;
    };

    if this.m_ncgtPerformanceTransactionStates[index] == 2 {
      return true;
    };

    if this.m_ncgtPerformanceTransactionStates[index] != 1 {
      return false;
    };

    this.m_ncgtPerformanceInstalledRevisions[index] = installedRevision;
    this.m_ncgtPerformanceFailureCodes[index] = 0;
    this.m_ncgtPerformanceTransactionStates[index] = 2;
    return true;
  }

  public func FailNCGTPerformancePackage(serial: Int32, failureCode: Int32) -> Bool {
    let index: Int32 = this.GetNCGTPerformancePackageIndexBySerial(serial);
    let financeIndex: Int32;
    let player: ref<PlayerPuppet>;
    let refund: Int32;
    let delayedPaymentRefund: Int32;
    let restoredTotal: Int32;
    let restoredPaidAmount: Int32;
    let paidAmount: Int32;
    let remainingMonths: Int32;
    let vehicleID: TweakDBID;
    let vehiclePrice: Int32;
    let financed: Bool;
    let paymentMode: Int32;

    if index < 0 {
      return false;
    };

    if this.m_ncgtPerformanceTransactionStates[index] == 3 {
      return true;
    };

    if this.m_ncgtPerformanceTransactionStates[index] != 1 {
      return false;
    };

    vehicleID = this.m_ncgtPerformanceVehicleIDs[index];
    vehiclePrice = this.m_ncgtPerformanceVehiclePrices[index];
    financed = this.m_ncgtPerformanceFinanced[index];
    paymentMode = this.m_ncgtPerformancePaymentModes[index];
    refund = Max(0, this.m_ncgtPerformanceRollbackRefunds[index]);
    player = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;

    if (paymentMode != 1 && paymentMode != 2)
      || (paymentMode == 2 && !financed) {
      return false;
    };

    if financed && paymentMode == 2 {
      financeIndex = this.GetFinanceContractIndex(vehicleID);
      if financeIndex < 0
        || financeIndex >= ArraySize(this.m_financeTerms)
        || financeIndex >= ArraySize(this.m_financeMonthlyPayments)
        || financeIndex >= ArraySize(this.m_financeRemainingMonths)
        || financeIndex >= ArraySize(this.m_financeNextPaymentMinutes)
        || financeIndex >= ArraySize(this.m_financeTotalDue)
        || financeIndex >= ArraySize(this.m_financeDownPayments)
        || financeIndex >= ArraySize(this.m_financeInterestPercents)
        || financeIndex >= ArraySize(this.m_financePaidAmounts) {
        return false;
      };

      restoredTotal = this.m_ncgtPerformanceRollbackFinanceTotals[index];
      paidAmount = this.m_financePaidAmounts[financeIndex];
      if restoredTotal <= 0
        || this.m_ncgtPerformanceRollbackFinanceMonthly[index] <= 0
        || this.m_ncgtPerformanceRollbackFinanceDownPayments[index] < 0
        || this.m_financeTotalDue[financeIndex] < restoredTotal
        || paidAmount < 0
        || paidAmount > this.m_financeTotalDue[financeIndex] {
        return false;
      };

      delayedPaymentRefund = Max(0, paidAmount - restoredTotal);
      refund += delayedPaymentRefund;
      restoredPaidAmount = Min(paidAmount, restoredTotal);
      remainingMonths = Max(1, this.m_financeRemainingMonths[financeIndex]);
    };

    if !this.IsNCGTAppreciationIntegrationAvailable()
      || !TDBID.IsValid(vehicleID)
      || vehiclePrice <= 0
      || this.GetNCGTAppreciationDiscountBpsForPrice(vehiclePrice) <= 0
      || (refund > 0 && !IsDefined(player))
      || (refund > 0 && !IsDefined(this.m_transactionSystem)) {
      return false;
    };

    if financed && paymentMode == 2 {
      if !this.ApplyMarmurFinancedPackageCancellation(serial) { return false; };
    } else {
      if refund > 0 && IsDefined(player) {
        this.m_transactionSystem.GiveItem(player, MarketSystem.Money(), refund);
      };
    };

    this.m_ncgtPerformanceInstalledRevisions[index] = 0;
    this.m_ncgtPerformanceFailureCodes[index] = Max(1, failureCode);
    this.m_ncgtPerformanceTransactionStates[index] = 3;

    if this.IssueNCGTAppreciationVoucher(vehicleID, vehiclePrice, financed) {
      this.QueueNCGTAppreciationVoucherNotice(vehicleID);
    };
    return true;
  }

  public func RemoveNCGTPerformancePackageState(id: TweakDBID) -> Bool {
    let removed: Bool = false;
    let i: Int32;

    if !TDBID.IsValid(id) {
      return false;
    };

    this.NormalizeNCGTPerformancePackageArrays();
    i = ArraySize(this.m_ncgtPerformanceVehicleIDs) - 1;
    while i >= 0 {
      if this.NCGTAppreciationVehicleIDsMatch(this.m_ncgtPerformanceVehicleIDs[i], id) {
        ArrayErase(this.m_ncgtPerformanceVehicleIDs, i);
        ArrayErase(this.m_ncgtPerformanceVehicleClasses, i);
        ArrayErase(this.m_ncgtPerformancePackageCodes, i);
        ArrayErase(this.m_ncgtPerformancePartsSubtotals, i);
        ArrayErase(this.m_ncgtPerformanceLaborTotals, i);
        ArrayErase(this.m_ncgtPerformanceVoucherBps, i);
        ArrayErase(this.m_ncgtPerformanceDiscounts, i);
        ArrayErase(this.m_ncgtPerformanceFinalTotals, i);
        ArrayErase(this.m_ncgtPerformancePaymentModes, i);
        ArrayErase(this.m_ncgtPerformanceTransactionStates, i);
        ArrayErase(this.m_ncgtPerformanceSerials, i);
        ArrayErase(this.m_ncgtPerformanceInstalledRevisions, i);
        ArrayErase(this.m_ncgtPerformanceFailureCodes, i);
        ArrayErase(this.m_ncgtPerformanceVehiclePrices, i);
        ArrayErase(this.m_ncgtPerformanceFinanced, i);
        ArrayErase(this.m_ncgtPerformanceRollbackRefunds, i);
        ArrayErase(this.m_ncgtPerformanceRollbackFinanceTotals, i);
        ArrayErase(this.m_ncgtPerformanceRollbackFinanceMonthly, i);
        ArrayErase(this.m_ncgtPerformanceRollbackFinanceDownPayments, i);
        removed = true;
      };
      i -= 1;
    };

    return removed;
  }

  public func GetNCGTAppreciationAPIVersion() -> Int32 {
    return 1;
  }

  private func GetNCGTAppreciationDiscountBpsForPrice(purchasePrice: Int32) -> Int32 {
    if purchasePrice <= 0 {
      return 0;
    };

    if purchasePrice < 50000 {
      return 500;
    };

    if purchasePrice < 100000 {
      return 1000;
    };

    if purchasePrice < 250000 {
      return 1500;
    };

    if purchasePrice < 750000 {
      return 2000;
    };

    return 2500;
  }

  private func ClearNCGTAppreciationReservation() -> Void {
    this.m_ncgtAppreciationReservedVehicleID = TDBID.Create("");
    this.m_ncgtAppreciationReservedSerial = 0;
    this.m_ncgtAppreciationReservedCheckoutToken = 0;
    this.m_ncgtAppreciationReservedParentRevision = 0;
    this.m_ncgtAppreciationReservedSavings = 0;
  }

  private func ReconcileNCGTAppreciationReservation() -> Void {
    let catalogRevision: Int32;
    let voucherIndex: Int32 = -1;
    let i: Int32;

    if this.m_ncgtAppreciationReservedSerial <= 0
      || !TDBID.IsValid(this.m_ncgtAppreciationReservedVehicleID)
      || this.m_ncgtAppreciationReservedCheckoutToken <= 0
      || this.m_ncgtAppreciationReservedParentRevision < 0
      || this.m_ncgtAppreciationReservedSavings <= 0 {
      this.ClearNCGTAppreciationReservation();
      return;
    };

    catalogRevision = GetFact(this.GetGameInstance(), n"ncgt_catalog_save_revision");
    if catalogRevision == this.m_ncgtAppreciationReservedParentRevision {

      this.ClearNCGTAppreciationReservation();
      return;
    };

    this.NormalizeNCGTAppreciationVoucherArrays();
    i = ArraySize(this.m_ncgtAppreciationVehicleIDs) - 1;
    while i >= 0 {
      if this.m_ncgtAppreciationSerials[i] == this.m_ncgtAppreciationReservedSerial
        && this.NCGTAppreciationVehicleIDsMatch(
          this.m_ncgtAppreciationVehicleIDs[i],
          this.m_ncgtAppreciationReservedVehicleID
        ) {
        voucherIndex = i;
        break;
      };
      i -= 1;
    };

    this.m_ncgtAppreciationLastCommittedVehicleID = this.m_ncgtAppreciationReservedVehicleID;
    this.m_ncgtAppreciationLastCommittedSerial = this.m_ncgtAppreciationReservedSerial;
    this.m_ncgtAppreciationLastCommittedCheckoutToken = this.m_ncgtAppreciationReservedCheckoutToken;
    this.m_ncgtAppreciationLastCommittedSavings = this.m_ncgtAppreciationReservedSavings;
    this.m_ncgtAppreciationLastCommittedMinute = this.GetCurrentGameMinute();
    if voucherIndex >= 0 {
      this.RemoveNCGTAppreciationVoucherAt(voucherIndex);
    };
    this.ClearNCGTAppreciationReservation();
  }

  public func SetNCGTAppreciationIntegrationAvailable(available: Bool, apiVersion: Int32) -> Bool {
    this.m_ncgtAppreciationIntegrationAvailable = available && apiVersion >= 1;
    if this.m_ncgtAppreciationIntegrationAvailable {
      this.m_ncgtAppreciationIntegrationAPIVersion = apiVersion;
      this.m_ncgtAppreciationIntegrationHeartbeatAt = EngineTime.ToFloat(
        GameInstance.GetEngineTime(this.GetGameInstance())
      );
      this.ReconcileNCGTAppreciationReservation();
      this.PurgeExpiredNCGTAppreciationVouchers();
    } else {
      this.m_ncgtAppreciationIntegrationAPIVersion = 0;
      this.m_ncgtAppreciationIntegrationHeartbeatAt = 0.00;
    };

    return this.m_ncgtAppreciationIntegrationAvailable;
  }

  public func IsNCGTAppreciationIntegrationAvailable() -> Bool {
    let now: Float;

    if !this.m_ncgtAppreciationIntegrationAvailable
      || this.m_ncgtAppreciationIntegrationAPIVersion < 1 {
      return false;
    };

    now = EngineTime.ToFloat(GameInstance.GetEngineTime(this.GetGameInstance()));
    if now < this.m_ncgtAppreciationIntegrationHeartbeatAt
      || now - this.m_ncgtAppreciationIntegrationHeartbeatAt > 10.00 {
      this.m_ncgtAppreciationIntegrationAvailable = false;
      this.m_ncgtAppreciationIntegrationAPIVersion = 0;
      this.m_ncgtAppreciationIntegrationHeartbeatAt = 0.00;
      return false;
    };

    return true;
  }

  private func NormalizeNCGTAppreciationVoucherArrays() -> Void {
    let count: Int32 = ArraySize(this.m_ncgtAppreciationVehicleIDs);

    if ArraySize(this.m_ncgtAppreciationPurchasePrices) < count {
      count = ArraySize(this.m_ncgtAppreciationPurchasePrices);
    };
    if ArraySize(this.m_ncgtAppreciationDiscountBps) < count {
      count = ArraySize(this.m_ncgtAppreciationDiscountBps);
    };
    if ArraySize(this.m_ncgtAppreciationSerials) < count {
      count = ArraySize(this.m_ncgtAppreciationSerials);
    };
    if ArraySize(this.m_ncgtAppreciationFinanced) < count {
      count = ArraySize(this.m_ncgtAppreciationFinanced);
    };
    if ArraySize(this.m_ncgtAppreciationIssueMinutes) < count {
      count = ArraySize(this.m_ncgtAppreciationIssueMinutes);
    };

    ArrayResize(this.m_ncgtAppreciationVehicleIDs, count);
    ArrayResize(this.m_ncgtAppreciationPurchasePrices, count);
    ArrayResize(this.m_ncgtAppreciationDiscountBps, count);
    ArrayResize(this.m_ncgtAppreciationSerials, count);
    ArrayResize(this.m_ncgtAppreciationFinanced, count);
    ArrayResize(this.m_ncgtAppreciationIssueMinutes, count);
  }

  private func GetNCGTAppreciationRemainingMinutesAt(index: Int32) -> Int32 {
    let issuedMinute: Int32;
    let elapsedMinutes: Int32;

    if index < 0 || index >= ArraySize(this.m_ncgtAppreciationIssueMinutes) {
      return 0;
    };

    issuedMinute = this.m_ncgtAppreciationIssueMinutes[index];
    elapsedMinutes = this.GetCurrentGameMinute() - issuedMinute;
    if issuedMinute < 0 || elapsedMinutes < 0 || elapsedMinutes >= 10080 {
      return 0;
    };

    return 10080 - elapsedMinutes;
  }

  private func PurgeExpiredNCGTAppreciationVouchers() -> Void {
    let i: Int32;

    this.NormalizeNCGTAppreciationVoucherArrays();
    i = ArraySize(this.m_ncgtAppreciationVehicleIDs) - 1;
    while i >= 0 {
      if this.GetNCGTAppreciationRemainingMinutesAt(i) <= 0
        && (this.m_ncgtAppreciationReservedSerial <= 0
          || this.m_ncgtAppreciationSerials[i] != this.m_ncgtAppreciationReservedSerial
          || !this.NCGTAppreciationVehicleIDsMatch(
            this.m_ncgtAppreciationVehicleIDs[i],
            this.m_ncgtAppreciationReservedVehicleID
          )) {

        this.RemoveNCGTAppreciationVoucherAt(i);
      };
      i -= 1;
    };
  }

  private func RemoveNCGTAppreciationVoucherAt(index: Int32) -> Bool {
    let serial: Int32;

    if index < 0 || index >= ArraySize(this.m_ncgtAppreciationVehicleIDs) {
      return false;
    };

    if index < ArraySize(this.m_ncgtAppreciationSerials) {
      serial = this.m_ncgtAppreciationSerials[index];
    };

    ArrayErase(this.m_ncgtAppreciationVehicleIDs, index);
    if index < ArraySize(this.m_ncgtAppreciationPurchasePrices) {
      ArrayErase(this.m_ncgtAppreciationPurchasePrices, index);
    };
    if index < ArraySize(this.m_ncgtAppreciationDiscountBps) {
      ArrayErase(this.m_ncgtAppreciationDiscountBps, index);
    };
    if index < ArraySize(this.m_ncgtAppreciationSerials) {
      ArrayErase(this.m_ncgtAppreciationSerials, index);
    };
    if index < ArraySize(this.m_ncgtAppreciationFinanced) {
      ArrayErase(this.m_ncgtAppreciationFinanced, index);
    };
    if index < ArraySize(this.m_ncgtAppreciationIssueMinutes) {
      ArrayErase(this.m_ncgtAppreciationIssueMinutes, index);
    };

    if serial > 0 && this.m_ncgtAppreciationReservedSerial == serial {
      this.ClearNCGTAppreciationReservation();
    };
    return true;
  }

  private func NCGTAppreciationVehicleIDsMatch(a: TweakDBID, b: TweakDBID) -> Bool {
    let i: Int32 = 0;

    if this.VanguardCoverageIDsMatch(a, b) {
      return true;
    };

    while i < ArraySize(this.m_coverageRuntimeAliasVehicleIDs) && i < ArraySize(this.m_coverageRuntimeAliasPolicyIDs) {
      if (this.VanguardCoverageIDsMatch(a, this.m_coverageRuntimeAliasVehicleIDs[i])
          && this.VanguardCoverageIDsMatch(b, this.m_coverageRuntimeAliasPolicyIDs[i]))
        || (this.VanguardCoverageIDsMatch(b, this.m_coverageRuntimeAliasVehicleIDs[i])
          && this.VanguardCoverageIDsMatch(a, this.m_coverageRuntimeAliasPolicyIDs[i])) {
        return true;
      };
      i += 1;
    };

    return false;
  }

  private func IsNCGTAppreciationVoucherEntryAvailable(index: Int32) -> Bool {
    let vehicleID: TweakDBID;

    if index < 0
      || index >= ArraySize(this.m_ncgtAppreciationVehicleIDs)
      || index >= ArraySize(this.m_ncgtAppreciationPurchasePrices)
      || index >= ArraySize(this.m_ncgtAppreciationDiscountBps)
      || index >= ArraySize(this.m_ncgtAppreciationSerials)
      || index >= ArraySize(this.m_ncgtAppreciationFinanced)
      || index >= ArraySize(this.m_ncgtAppreciationIssueMinutes) {
      return false;
    };

    vehicleID = this.m_ncgtAppreciationVehicleIDs[index];
    if !TDBID.IsValid(vehicleID)
      || this.m_ncgtAppreciationPurchasePrices[index] <= 0
      || this.m_ncgtAppreciationDiscountBps[index] <= 0
      || this.m_ncgtAppreciationSerials[index] <= 0
      || this.GetNCGTAppreciationRemainingMinutesAt(index) <= 0 {
      return false;
    };

    if this.IsVanguardVehicleSold(vehicleID)
      || this.IsVehicleRepossessed(vehicleID)
      || this.IsVanguardUninsuredVehicleDestroyed(vehicleID)
      || this.IsVanguardCoverageTotalLossLocked(vehicleID)
      || !this.IsSeparatePurchased(vehicleID) {
      return false;
    };

    return true;
  }

  private func GetNCGTAppreciationVoucherIndex(id: TweakDBID) -> Int32 {
    let i: Int32;

    if !TDBID.IsValid(id) {
      return -1;
    };

    this.NormalizeNCGTAppreciationVoucherArrays();
    i = ArraySize(this.m_ncgtAppreciationVehicleIDs) - 1;
    while i >= 0 {
      if this.NCGTAppreciationVehicleIDsMatch(this.m_ncgtAppreciationVehicleIDs[i], id) {
        if this.IsNCGTAppreciationVoucherEntryAvailable(i) {
          return i;
        };

        this.RemoveNCGTAppreciationVoucherAt(i);
      };
      i -= 1;
    };

    return -1;
  }

  public func InvalidateNCGTAppreciation(id: TweakDBID) -> Bool {
    let removed: Bool = false;
    let i: Int32;

    if !TDBID.IsValid(id) {
      return false;
    };

    this.NormalizeNCGTAppreciationVoucherArrays();
    i = ArraySize(this.m_ncgtAppreciationVehicleIDs) - 1;
    while i >= 0 {
      if this.NCGTAppreciationVehicleIDsMatch(this.m_ncgtAppreciationVehicleIDs[i], id) {
        this.RemoveNCGTAppreciationVoucherAt(i);
        removed = true;
      };
      i -= 1;
    };

    return removed;
  }

  private func ClearPendingNCGTAppreciationVoucherNotice() -> Void {
    this.m_ncgtAppreciationNoticePendingVehicleID = TDBID.Create("");
    this.m_ncgtAppreciationNoticePendingSerial = 0;
  }

  private func QueueNCGTAppreciationVoucherNotice(id: TweakDBID) -> Bool {
    let index: Int32;

    if this.m_ncgtAppreciationNoticePendingSerial <= 0
      || !TDBID.IsValid(this.m_ncgtAppreciationNoticePendingVehicleID)
      || !this.NCGTAppreciationVehicleIDsMatch(
        this.m_ncgtAppreciationNoticePendingVehicleID,
        id
      ) {
      this.ClearPendingNCGTAppreciationVoucherNotice();
      return false;
    };

    index = this.GetNCGTAppreciationVoucherIndex(id);
    if index < 0
      || index >= ArraySize(this.m_ncgtAppreciationPurchasePrices)
      || index >= ArraySize(this.m_ncgtAppreciationDiscountBps)
      || index >= ArraySize(this.m_ncgtAppreciationSerials)
      || this.m_ncgtAppreciationSerials[index]
        != this.m_ncgtAppreciationNoticePendingSerial {
      this.ClearPendingNCGTAppreciationVoucherNotice();
      return false;
    };

    this.PublishPhoneNotificationRecord(
      3201,
      id,
      this.m_ncgtAppreciationPurchasePrices[index],
      this.m_ncgtAppreciationDiscountBps[index],
      this.m_ncgtAppreciationSerials[index]
    );
    this.ClearPendingNCGTAppreciationVoucherNotice();
    return true;
  }

  private func IssueNCGTAppreciationVoucher(id: TweakDBID, finalPrice: Int32, financed: Bool) -> Bool {
    let discountBps: Int32 = this.GetNCGTAppreciationDiscountBpsForPrice(finalPrice);

    this.ClearPendingNCGTAppreciationVoucherNotice();
    if !this.IsNCGTAppreciationIntegrationAvailable()
      || !TDBID.IsValid(id)
      || finalPrice <= 0
      || discountBps <= 0 {
      return false;
    };

    this.NormalizeNCGTAppreciationVoucherArrays();
    this.InvalidateNCGTAppreciation(id);
    this.m_ncgtAppreciationSequence += 1;
    if this.m_ncgtAppreciationSequence <= 0 {
      this.m_ncgtAppreciationSequence = 1;
    };

    ArrayPush(this.m_ncgtAppreciationVehicleIDs, id);
    ArrayPush(this.m_ncgtAppreciationPurchasePrices, finalPrice);
    ArrayPush(this.m_ncgtAppreciationDiscountBps, discountBps);
    ArrayPush(this.m_ncgtAppreciationSerials, this.m_ncgtAppreciationSequence);
    ArrayPush(this.m_ncgtAppreciationFinanced, financed);
    ArrayPush(this.m_ncgtAppreciationIssueMinutes, this.GetCurrentGameMinute());
    this.m_ncgtAppreciationNoticePendingVehicleID = id;
    this.m_ncgtAppreciationNoticePendingSerial = this.m_ncgtAppreciationSequence;
    return true;
  }

  public func GetNCGTAppreciationDiscountBps(id: TweakDBID) -> Int32 {
    let index: Int32;

    if !this.IsNCGTAppreciationIntegrationAvailable() {
      return 0;
    };

    index = this.GetNCGTAppreciationVoucherIndex(id);
    if index < 0 {
      return 0;
    };

    return this.m_ncgtAppreciationDiscountBps[index];
  }

  public func GetNCGTAppreciationPurchasePrice(id: TweakDBID) -> Int32 {
    let index: Int32;

    if !this.IsNCGTAppreciationIntegrationAvailable() {
      return 0;
    };

    index = this.GetNCGTAppreciationVoucherIndex(id);
    if index < 0 {
      return 0;
    };

    return this.m_ncgtAppreciationPurchasePrices[index];
  }

  public func GetNCGTAppreciationSerial(id: TweakDBID) -> Int32 {
    let index: Int32;

    if !this.IsNCGTAppreciationIntegrationAvailable() {
      return 0;
    };

    index = this.GetNCGTAppreciationVoucherIndex(id);
    if index < 0 {
      return 0;
    };

    return this.m_ncgtAppreciationSerials[index];
  }

  public func GetNCGTAppreciationRemainingMinutes(id: TweakDBID) -> Int32 {
    let index: Int32;

    if !this.IsNCGTAppreciationIntegrationAvailable() {
      return 0;
    };

    index = this.GetNCGTAppreciationVoucherIndex(id);
    if index < 0 {
      return 0;
    };

    return this.GetNCGTAppreciationRemainingMinutesAt(index);
  }

  public func ReserveNCGTAppreciation(
    id: TweakDBID,
    serial: Int32,
    checkoutToken: Int32,
    parentRevision: Int32,
    savings: Int32
  ) -> Bool {
    let index: Int32;

    if !this.IsNCGTAppreciationIntegrationAvailable()
      || !TDBID.IsValid(id)
      || serial <= 0
      || checkoutToken <= 0
      || parentRevision < 0
      || savings <= 0 {
      return false;
    };

    if GetFact(this.GetGameInstance(), n"ncgt_catalog_save_revision") != parentRevision {
      return false;
    };

    index = this.GetNCGTAppreciationVoucherIndex(id);
    if index < 0 || this.m_ncgtAppreciationSerials[index] != serial {
      return false;
    };

    if this.m_ncgtAppreciationReservedSerial > 0 {
      return this.m_ncgtAppreciationReservedSerial == serial
        && this.m_ncgtAppreciationReservedCheckoutToken == checkoutToken
        && this.m_ncgtAppreciationReservedParentRevision == parentRevision
        && this.m_ncgtAppreciationReservedSavings == savings
        && this.NCGTAppreciationVehicleIDsMatch(this.m_ncgtAppreciationReservedVehicleID, id);
    };

    this.m_ncgtAppreciationReservedVehicleID = this.m_ncgtAppreciationVehicleIDs[index];
    this.m_ncgtAppreciationReservedSerial = serial;
    this.m_ncgtAppreciationReservedCheckoutToken = checkoutToken;
    this.m_ncgtAppreciationReservedParentRevision = parentRevision;
    this.m_ncgtAppreciationReservedSavings = savings;
    return true;
  }

  public func ReleaseNCGTAppreciation(id: TweakDBID, serial: Int32, checkoutToken: Int32) -> Bool {
    if this.m_ncgtAppreciationReservedSerial <= 0 {
      return true;
    };

    if !TDBID.IsValid(id)
      || serial <= 0
      || checkoutToken <= 0
      || this.m_ncgtAppreciationReservedSerial != serial
      || this.m_ncgtAppreciationReservedCheckoutToken != checkoutToken
      || !this.NCGTAppreciationVehicleIDsMatch(this.m_ncgtAppreciationReservedVehicleID, id) {
      return false;
    };

    this.ClearNCGTAppreciationReservation();
    return true;
  }

  public func CommitNCGTAppreciation(id: TweakDBID, serial: Int32, checkoutToken: Int32, savings: Int32) -> Bool {
    let index: Int32;
    let voucherID: TweakDBID;

    if !this.IsNCGTAppreciationIntegrationAvailable()
      || !TDBID.IsValid(id)
      || serial <= 0
      || checkoutToken <= 0
      || savings <= 0 {
      return false;
    };

    if this.m_ncgtAppreciationLastCommittedSerial == serial
      && this.m_ncgtAppreciationLastCommittedCheckoutToken == checkoutToken
      && this.m_ncgtAppreciationLastCommittedSavings == savings
      && this.NCGTAppreciationVehicleIDsMatch(this.m_ncgtAppreciationLastCommittedVehicleID, id) {
      this.ClearNCGTAppreciationReservation();
      return true;
    };

    if this.m_ncgtAppreciationReservedSerial != serial
      || this.m_ncgtAppreciationReservedCheckoutToken != checkoutToken
      || this.m_ncgtAppreciationReservedSavings != savings
      || !this.NCGTAppreciationVehicleIDsMatch(this.m_ncgtAppreciationReservedVehicleID, id) {
      return false;
    };

    index = this.GetNCGTAppreciationVoucherIndex(id);
    if index < 0 || this.m_ncgtAppreciationSerials[index] != serial {
      return false;
    };

    voucherID = this.m_ncgtAppreciationVehicleIDs[index];
    this.m_ncgtAppreciationLastCommittedVehicleID = voucherID;
    this.m_ncgtAppreciationLastCommittedSerial = serial;
    this.m_ncgtAppreciationLastCommittedCheckoutToken = checkoutToken;
    this.m_ncgtAppreciationLastCommittedSavings = savings;
    this.m_ncgtAppreciationLastCommittedMinute = this.GetCurrentGameMinute();
    this.RemoveNCGTAppreciationVoucherAt(index);
    this.ClearNCGTAppreciationReservation();
    return true;
  }

  public func GetVanguardCoverageDeductibleAmount(option: Int32) -> Int32 {
    let normalized: Int32 = option;

    if normalized <= 1 {
      return 250;
    };

    if normalized == 2 {
      return 750;
    };

    return 1500;
  }

  public func GetVanguardCoverageDeductibleLabel(option: Int32) -> String {
    let amount: Int32 = this.GetVanguardCoverageDeductibleAmount(option);
    if amount == 250 {
      return VanguardAutoLocalization.Text(1785, "Low deductible");
    };
    if amount == 750 {
      return VanguardAutoLocalization.Text(1786, "Standard deductible");
    };
    return VanguardAutoLocalization.Text(1787, "High deductible");
  }

  public func NormalizeVanguardCoverageDeductibleOption(option: Int32) -> Int32 {
    if option <= 1 {
      return 1;
    };

    if option == 2 {
      return 2;
    };

    return 3;
  }

  public func NormalizeVanguardCoveragePaymentFrequency(frequency: Int32) -> Int32 {
    if frequency <= 0 {
      return 0;
    };

    if frequency == 1 || frequency == 2 {
      return frequency;
    };

    return 3;
  }

  public func GetVanguardCoveragePaymentFrequencyLabel(frequency: Int32) -> String {
    let normalized: Int32 = this.NormalizeVanguardCoveragePaymentFrequency(frequency);

    if normalized == 0 {
      return VanguardAutoLocalization.Text(1331, "Paid In Full");
    };

    if normalized == 1 {
      return VanguardAutoLocalization.Text(1174, "Weekly");
    };

    if normalized == 2 {
      return VanguardAutoLocalization.Text(1175, "Bi-weekly");
    };

    return VanguardAutoLocalization.Text(1176, "Monthly");
  }

  public func NormalizeVanguardCoverageTermMonths(termMonths: Int32) -> Int32 {
    if termMonths >= 12 {
      return 12;
    };

    return 6;
  }

  public func GetVanguardCoverageTermDays(termMonths: Int32) -> Int32 {
    if this.NormalizeVanguardCoverageTermMonths(termMonths) >= 12 {
      return 365;
    };

    return 182;
  }

  public func GetVanguardCoverageTermMonths() -> Int32 {
    if this.m_coverageTermMonths <= 0 {
      return 6;
    };

    return this.NormalizeVanguardCoverageTermMonths(this.m_coverageTermMonths);
  }

  public func GetVanguardCoveragePolicyNumber() -> String {
    if this.m_coveragePolicySerial <= 0 {
      return VanguardAutoLocalization.Text(1788, "Pending");
    };

    return s"VCP-\(this.m_coveragePolicySerial)";
  }

  private func EnsureVanguardCoveragePolicyNumber() -> String {
    if this.m_coveragePolicySerial <= 0 {
      this.m_coveragePolicySerial = this.GetCurrentGameMinute();
      if this.m_coveragePolicySerial <= 0 {
        this.m_coveragePolicySerial = 1;
      };
    };

    return this.GetVanguardCoveragePolicyNumber();
  }

  public func RecordVanguardCoverageAccidentImpact(id: TweakDBID, atFault: Bool, amount: Int32) -> Void {
    let now: Int32 = this.GetCurrentGameMinute();

    if !atFault {
      return;
    };

    if this.m_coverageLastAccidentMinute > 0 && now - this.m_coverageLastAccidentMinute > 259200 {
      this.m_coverageAtFaultAccidentCount = 0;
    };

    this.m_coverageAtFaultAccidentCount += 1;
    if this.m_coverageAtFaultAccidentCount < 0 {
      this.m_coverageAtFaultAccidentCount = 1;
    };
    if this.m_coverageAtFaultAccidentCount > 6 {
      this.m_coverageAtFaultAccidentCount = 6;
    };
    this.m_coverageLastAccidentMinute = now;
  }

  public func GetVanguardCoverageAtFaultSurchargeBasisPoints() -> Int32 {
    let now: Int32 = this.GetCurrentGameMinute();
    let surcharge: Int32;

    if this.m_coverageLastAccidentMinute <= 0 {
      return 0;
    };

    if now - this.m_coverageLastAccidentMinute > 259200 {
      return 0;
    };

    surcharge = this.m_coverageAtFaultAccidentCount * 500;
    if surcharge > 3000 {
      surcharge = 3000;
    };
    if surcharge < 0 {
      surcharge = 0;
    };

    return surcharge;
  }

  public func GetVanguardCoverageAccidentSurchargeBasisPoints() -> Int32 {
    let now: Int32 = this.GetCurrentGameMinute();

    if this.m_coverageLastAccidentMinute > 0 && now - this.m_coverageLastAccidentMinute >= 259200 {
      this.m_coverageAtFaultSurchargeBasisPoints = 0;
      this.m_coverageAtFaultAccidentCount = 0;
    };

    if this.m_coverageAtFaultSurchargeBasisPoints < 0 {
      this.m_coverageAtFaultSurchargeBasisPoints = 0;
    };

    if this.m_coverageAtFaultSurchargeBasisPoints > 2500 {
      this.m_coverageAtFaultSurchargeBasisPoints = 2500;
    };

    return this.m_coverageAtFaultSurchargeBasisPoints;
  }

  public func GetVanguardCoverageCleanDrivingDays() -> Int32 {
    let now: Int32 = this.GetCurrentGameMinute();
    let startMinute: Int32 = this.m_coverageGoodDriverStartMinute;

    if startMinute <= 0 {
      startMinute = this.m_coverageTermStartMinute;
    };

    if this.m_coverageLastAccidentMinute > startMinute {
      startMinute = this.m_coverageLastAccidentMinute;
    };

    if startMinute <= 0 || now <= startMinute {
      return 0;
    };

    return Max(0, (now - startMinute) / 1440);
  }

  public func GetVanguardCoverageDriverRatingScore() -> Int32 {
    let cleanDays: Int32 = this.GetVanguardCoverageCleanDrivingDays();
    let surchargeBasisPoints: Int32 = this.GetVanguardCoverageAccidentSurchargeBasisPoints();
    let score: Int32 = 72;
    let cleanBonus: Int32;
    let accidentPenalty: Int32;

    cleanBonus = (cleanDays * 25) / 28;
    if cleanBonus > 25 {
      cleanBonus = 25;
    };
    if cleanDays >= 7 {
      cleanBonus += 3;
    };

    accidentPenalty = surchargeBasisPoints / 100;
    accidentPenalty += this.m_coverageAtFaultAccidentCount * 4;

    score += cleanBonus;
    score -= accidentPenalty;

    if score > 100 {
      return 100;
    };
    if score < 35 {
      return 35;
    };
    return score;
  }

  public func GetVanguardCoverageDriverRatingLabel() -> String {
    let score: Int32 = this.GetVanguardCoverageDriverRatingScore();

    if score >= 95 {
      return VanguardAutoLocalization.Text(1789, "Excellent");
    };
    if score >= 88 {
      return VanguardAutoLocalization.Text(1790, "Preferred");
    };
    if score >= 76 {
      return "Good";
    };
    if score >= 60 {
      return VanguardAutoLocalization.Text(1791, "Standard");
    };
    return VanguardAutoLocalization.Text(1792, "High Risk");
  }

  public func GetVanguardCoverageGoodDriverDiscountBasisPoints() -> Int32 {
    let cleanDays: Int32 = this.GetVanguardCoverageCleanDrivingDays();

    if cleanDays >= 7 {
      return 2200;
    };
    return 0;
  }

  public func GetVanguardCoverageDriverRateImpactLabel() -> String {
    let surchargeBasisPoints: Int32 = this.GetVanguardCoverageAccidentSurchargeBasisPoints();
    let discountBasisPoints: Int32 = this.GetVanguardCoverageGoodDriverDiscountBasisPoints();

    if surchargeBasisPoints > 0 {
      return s"+\(surchargeBasisPoints / 100)% surcharge";
    };
    if discountBasisPoints > 0 {
      return s"-\(discountBasisPoints / 100)% discount";
    };
    return VanguardAutoLocalization.Text(1793, "No rate change");
  }

  private func RefreshVanguardCoverageGoodDriverAppreciationNotice() -> Void {
    let rewardVersion: Int32 = 2200;
    let cleanDays: Int32;

    if !this.IsVanguardCoverageOperational() {
      return;
    };

    cleanDays = this.GetVanguardCoverageCleanDrivingDays();
    if cleanDays < 7 || this.GetVanguardCoverageGoodDriverDiscountBasisPoints() < rewardVersion {
      return;
    };

    if this.GetVanguardCoveragePaymentFrequency() == 0 {
      return;
    };

    if this.m_coverageGoodDriverRewardedTermStartMinute == this.m_coverageTermStartMinute && this.m_coverageGoodDriverRewardedStartMinute == this.m_coverageGoodDriverStartMinute && this.m_coverageGoodDriverRewardedVersion == rewardVersion {
      return;
    };

    this.m_coverageGoodDriverRewardedTermStartMinute = this.m_coverageTermStartMinute;
    this.m_coverageGoodDriverRewardedStartMinute = this.m_coverageGoodDriverStartMinute;
    this.m_coverageGoodDriverRewardedVersion = rewardVersion;

    this.PublishPhoneNotificationRecord(3104, t"VanguardAuto.Phone.NoVehicle", 0, 22, this.GetVanguardCoverageTermMonths());
  }

  private func GetVanguardCoverageSurchargeIncreaseBasisPoints(severity: Int32) -> Int32 {
    if severity >= 3 {
      return 750;
    };

    if severity == 2 {
      return 500;
    };

    return 250;
  }

  public func ApplyVanguardCoverageAtFaultSurcharge(amount: Int32, severity: Int32) -> Void {
    let increase: Int32 = this.GetVanguardCoverageSurchargeIncreaseBasisPoints(severity);
    let normalizedFrequency: Int32 = this.GetVanguardCoveragePaymentFrequency();
    let currentPremium: Int32;

    if !this.IsVanguardCoverageOperational() {
      return;
    };

    this.m_coverageAtFaultSurchargeBasisPoints += increase;
    if this.m_coverageAtFaultSurchargeBasisPoints > 2500 {
      this.m_coverageAtFaultSurchargeBasisPoints = 2500;
    };

    this.m_coverageAtFaultAccidentCount += 1;
    this.m_coverageLastAccidentMinute = this.GetCurrentGameMinute();
    this.m_coverageGoodDriverStartMinute = this.m_coverageLastAccidentMinute;

    if normalizedFrequency != 0 {
      currentPremium = this.CalculateVanguardCoverageTermPremiumForMonths(this.m_coverageVehicleIDs, this.GetVanguardCoverageDeductibleOption(), this.GetVanguardCoverageTermMonths());
      this.m_coverageLastTermPremium = currentPremium;
      this.m_coverageLastPaymentAmount = this.GetVanguardCoverageInstallmentAmountForTerm(currentPremium, normalizedFrequency, this.GetVanguardCoverageTermMonths());
    };
  }

  public func GetVanguardCoverageRateBasisPoints(option: Int32) -> Int32 {
    let normalized: Int32 = this.NormalizeVanguardCoverageDeductibleOption(option);

    if normalized == 1 {
      return 1500;
    };

    if normalized == 2 {
      return 1000;
    };

    return 500;
  }

  public func GetVanguardCoverageMinimumTermPremium(option: Int32) -> Int32 {
    let normalized: Int32 = this.NormalizeVanguardCoverageDeductibleOption(option);

    if normalized == 1 {
      return 750;
    };

    if normalized == 2 {
      return 600;
    };

    return 500;
  }

  public func GetVanguardCoverageVehicleValue(id: TweakDBID) -> Int32 {
    let value: Int32 = 0;

    if !TDBID.IsValid(id) {
      return 0;
    };

    if this.IsVanguardCoverageVehicleIneligible(id) {
      return 0;
    };

    value = this.GetVehicleBasePrice(id);
    if value <= 0 {
      return this.m_fallbackPrice;
    };

    return value;
  }

  public func CalculateVanguardCoverageVehicleValueTotal(vehicleIDs: array<TweakDBID>) -> Int32 {
    let total: Int32 = 0;
    let i: Int32 = 0;

    while i < ArraySize(vehicleIDs) {
      if this.IsVanguardCoverageOperationalVehicleID(vehicleIDs[i]) {
        total += this.GetVanguardCoverageVehicleValue(vehicleIDs[i]);
      };
      i += 1;
    };

    return total;
  }

  private func GetVanguardCoverageEligibleVehicleCount(vehicleIDs: array<TweakDBID>) -> Int32 {
    let count: Int32 = 0;
    let i: Int32 = 0;

    while i < ArraySize(vehicleIDs) {
      if this.IsVanguardCoverageOperationalVehicleID(vehicleIDs[i]) {
        count += 1;
      };
      i += 1;
    };

    return count;
  }

  public func CalculateVanguardCoverageTermPremium(vehicleIDs: array<TweakDBID>, deductibleOption: Int32) -> Int32 {
    let count: Int32 = this.GetVanguardCoverageEligibleVehicleCount(vehicleIDs);
    let totalValue: Int32 = this.CalculateVanguardCoverageVehicleValueTotal(vehicleIDs);
    let premium: Int32;
    let discountBasisPoints: Int32;
    let discountAmount: Int32;
    let rateBasisPoints: Int32;
    let surchargeBasisPoints: Int32;
    let surchargeAmount: Int32;
    let goodDriverDiscountBasisPoints: Int32;
    let goodDriverDiscountAmount: Int32;
    let wholeUnits: Int32;
    let remainder: Int32;

    if count <= 0 || totalValue <= 0 {
      return 0;
    };

    rateBasisPoints = this.GetVanguardCoverageRateBasisPoints(deductibleOption);

    wholeUnits = totalValue / 10000;
    remainder = totalValue - wholeUnits * 10000;
    premium = wholeUnits * rateBasisPoints;
    premium += (remainder * rateBasisPoints + 9999) / 10000;

    if premium < this.GetVanguardCoverageMinimumTermPremium(deductibleOption) {
      premium = this.GetVanguardCoverageMinimumTermPremium(deductibleOption);
    };

    discountBasisPoints = (count - 1) * 180;
    if discountBasisPoints > 2500 {
      discountBasisPoints = 2500;
    };

    if discountBasisPoints > 0 {

      wholeUnits = premium / 10000;
      remainder = premium - wholeUnits * 10000;
      discountAmount = wholeUnits * discountBasisPoints;
      discountAmount += (remainder * discountBasisPoints) / 10000;
      premium -= discountAmount;
    };

    goodDriverDiscountBasisPoints = this.GetVanguardCoverageGoodDriverDiscountBasisPoints();
    goodDriverDiscountAmount = 0;
    if goodDriverDiscountBasisPoints > 0 {
      wholeUnits = premium / 10000;
      remainder = premium - wholeUnits * 10000;
      goodDriverDiscountAmount = wholeUnits * goodDriverDiscountBasisPoints;
      goodDriverDiscountAmount += (remainder * goodDriverDiscountBasisPoints) / 10000;
      premium -= goodDriverDiscountAmount;
      if premium < this.GetVanguardCoverageMinimumTermPremium(deductibleOption) {
        premium = this.GetVanguardCoverageMinimumTermPremium(deductibleOption);
      };
    };

    surchargeBasisPoints = this.GetVanguardCoverageAccidentSurchargeBasisPoints();
    surchargeAmount = 0;
    if surchargeBasisPoints > 0 {
      wholeUnits = premium / 10000;
      remainder = premium - wholeUnits * 10000;
      surchargeAmount = wholeUnits * surchargeBasisPoints;
      surchargeAmount += (remainder * surchargeBasisPoints + 9999) / 10000;
      premium += surchargeAmount;
    };

    if premium < 1 {
      return 1;
    };

    return premium;
  }

  public func CalculateVanguardCoverageTermPremiumForMonths(vehicleIDs: array<TweakDBID>, deductibleOption: Int32, termMonths: Int32) -> Int32 {
    let basePremium: Int32 = this.CalculateVanguardCoverageTermPremium(vehicleIDs, deductibleOption);

    if basePremium <= 0 {
      return 0;
    };

    return Max(1, basePremium);
  }

  public func GetVanguardCoveragePayInFullAmount(termPremium: Int32) -> Int32 {
    if termPremium <= 0 {
      return 0;
    };

    return termPremium;
  }

  public func GetVanguardCoverageInstallmentAmount(termPremium: Int32, frequency: Int32) -> Int32 {
    return this.GetVanguardCoverageInstallmentAmountForTerm(termPremium, frequency, 6);
  }

  public func GetVanguardCoverageInstallmentAmountForTerm(termPremium: Int32, frequency: Int32, termMonths: Int32) -> Int32 {
    let normalized: Int32 = this.NormalizeVanguardCoveragePaymentFrequency(frequency);
    let payments: Int32 = 6;

    if termPremium <= 0 {
      return 0;
    };

    if normalized == 0 {
      return this.GetVanguardCoveragePayInFullAmount(termPremium);
    };

    if this.NormalizeVanguardCoverageTermMonths(termMonths) >= 12 {
      payments = 12;
      if normalized == 1 {
        payments = 52;
      } else {
        if normalized == 2 {
          payments = 26;
        };
      };
    } else {
      if normalized == 1 {
        payments = 26;
      } else {
        if normalized == 2 {
          payments = 13;
        } else {
          payments = 6;
        };
      };
    };

    return Max(1, (termPremium + payments - 1) / payments);
  }

  public func GetVanguardCoverageMonthlyBreakoutAmount(termPremium: Int32) -> Int32 {
    if termPremium <= 0 {
      return 0;
    };

    return Max(1, (termPremium + 5) / 6);
  }

  public func IsVanguardCoverageFraudDestroyedVehicleExcluded(id: TweakDBID) -> Bool {
    let i: Int32 = 0;

    if !TDBID.IsValid(id) {
      return false;
    };

    while i < ArraySize(this.m_coverageFraudDestroyedVehicleIDs) {
      if this.VanguardCoverageIDsMatch(this.m_coverageFraudDestroyedVehicleIDs[i], id) {
        return true;
      };
      i += 1;
    };

    return false;
  }

  private func IsVanguardCoverageOperationalVehicleID(id: TweakDBID) -> Bool {
    let canonicalID: TweakDBID;

    if !TDBID.IsValid(id) {
      return false;
    };

    canonicalID = this.GetCanonicalVehicleRecordID(id);
    if this.IsVanguardCoverageVehicleIneligible(id) || this.IsVanguardCoverageVehicleIneligible(canonicalID) {
      return false;
    };

    return !this.IsVanguardCoverageFraudDestroyedVehicleExcluded(id) && !this.IsVanguardUninsuredVehicleDestroyed(id);
  }

  private func AdministrativelyExcludeVanguardFraudDestroyedVehicle(id: TweakDBID) -> Bool {
    let resolvedID: TweakDBID;
    let exclusionID: TweakDBID;
    let remainingVehicleIDs: array<TweakDBID>;
    let alreadyExcluded: Bool;
    let removedFromPolicy: Bool = false;
    let i: Int32 = 0;

    if !TDBID.IsValid(id) {
      return false;
    };

    resolvedID = this.ResolveVanguardCoverageVehicleID(id);
    if TDBID.IsValid(resolvedID) {
      exclusionID = resolvedID;
    } else {
      exclusionID = this.GetCanonicalVehicleRecordID(id);
      if !TDBID.IsValid(exclusionID) {
        exclusionID = id;
      };
    };

    alreadyExcluded = this.IsVanguardCoverageFraudDestroyedVehicleExcluded(exclusionID);
    if !alreadyExcluded {
      ArrayPush(this.m_coverageFraudDestroyedVehicleIDs, exclusionID);
    };

    while i < ArraySize(this.m_coverageVehicleIDs) {
      if this.VanguardCoverageIDsMatch(this.m_coverageVehicleIDs[i], exclusionID) {
        removedFromPolicy = true;
      } else {
        ArrayPush(remainingVehicleIDs, this.m_coverageVehicleIDs[i]);
      };
      i += 1;
    };

    if removedFromPolicy {
      this.m_coverageVehicleIDs = remainingVehicleIDs;
      this.ClearVanguardCoverageRuntimeAliases();
    };

    this.m_coverageLastTermPremium = this.CalculateVanguardCoverageTermPremiumForMonths(this.m_coverageVehicleIDs, this.GetVanguardCoverageDeductibleOption(), this.GetVanguardCoverageTermMonths());
    this.m_coverageLastPaymentAmount = this.GetVanguardCoverageInstallmentAmountForTerm(this.m_coverageLastTermPremium, this.GetVanguardCoveragePaymentFrequency(), this.GetVanguardCoverageTermMonths());

    if !alreadyExcluded || removedFromPolicy {
      SetFactValue(this.GetGameInstance(), n"vanguard_coverage_redscript_commit_request", 1);
    };

    return this.IsVanguardCoverageFraudDestroyedVehicleExcluded(exclusionID);
  }

  private func ClearVanguardCoverageFraudDestroyedVehicleExclusion(id: TweakDBID) -> Void {
    let remaining: array<TweakDBID>;
    let i: Int32 = 0;

    if !TDBID.IsValid(id) {
      return;
    };

    while i < ArraySize(this.m_coverageFraudDestroyedVehicleIDs) {
      if !this.VanguardCoverageIDsMatch(this.m_coverageFraudDestroyedVehicleIDs[i], id) {
        ArrayPush(remaining, this.m_coverageFraudDestroyedVehicleIDs[i]);
      };
      i += 1;
    };

    this.m_coverageFraudDestroyedVehicleIDs = remaining;
  }

  private func EnsureVanguardCoverageFraudDestroyedExclusionMigration() -> Void {
    let selectedVehicleIDs: array<TweakDBID>;
    let i: Int32 = 0;

    if this.m_coverageFraudExclusionMigrationRunning || this.m_coverageFraudExclusionMigrationComplete || this.m_coverageFraudStrikeCount <= 0 {
      return;
    };

    this.m_coverageFraudExclusionMigrationRunning = true;
    selectedVehicleIDs = this.m_coverageVehicleIDs;
    while i < ArraySize(selectedVehicleIDs) {

      if this.IsVanguardUninsuredVehicleDestroyed(selectedVehicleIDs[i]) {
        this.AdministrativelyExcludeVanguardFraudDestroyedVehicle(selectedVehicleIDs[i]);
      };
      i += 1;
    };
    this.m_coverageFraudExclusionMigrationRunning = false;
    this.m_coverageFraudExclusionMigrationComplete = true;
  }

  public func HasVanguardCoveragePolicyRecord() -> Bool {
    return this.m_coveragePolicySerial > 0 || this.m_coverageTermStartMinute > 0 || this.m_coverageTermEndMinute > 0 || ArraySize(this.m_coverageVehicleIDs) > 0 || this.m_coverageFraudPermanentlyTerminated;
  }

  public func IsVanguardCoveragePolicyTermActive() -> Bool {
    return this.HasVanguardCoveragePolicyRecord() && this.m_coverageTermEndMinute > this.GetCurrentGameMinute();
  }

  public func IsVanguardCoveragePermanentlyTerminated() -> Bool {
    return this.m_coverageFraudPermanentlyTerminated;
  }

  public func IsVanguardCoverageSuspended() -> Bool {
    if this.m_coverageFraudPermanentlyTerminated || this.m_coverageFraudSuspensionExpirationMinute <= 0 {
      return false;
    };

    return this.GetCurrentGameMinute() < this.m_coverageFraudSuspensionExpirationMinute;
  }

  public func IsVanguardCoverageOperational() -> Bool {
    return this.HasVanguardCoverageActivePolicy() && this.GetCoverageSelectedVehicleCount() > 0 && !this.IsVanguardCoverageSuspended() && !this.m_coverageFraudPermanentlyTerminated;
  }

  public func CanModifyVanguardCoveragePolicy() -> Bool {
    return !this.m_coverageFraudPermanentlyTerminated && !this.IsVanguardCoverageSuspended();
  }

  public func GetVanguardCoverageFraudStrikeCount() -> Int32 {
    if this.m_coverageFraudStrikeCount < 0 {
      this.m_coverageFraudStrikeCount = 0;
    };
    if this.m_coverageFraudStrikeCount > 3 {
      this.m_coverageFraudStrikeCount = 3;
    };
    return this.m_coverageFraudStrikeCount;
  }

  public func GetVanguardCoverageFraudSuspensionExpirationMinute() -> Int32 {
    return this.m_coverageFraudSuspensionExpirationMinute;
  }

  public func GetVanguardCoverageFraudSuspensionRemainingMinutes() -> Int32 {
    let remaining: Int32;

    if !this.IsVanguardCoverageSuspended() {
      return 0;
    };

    remaining = this.m_coverageFraudSuspensionExpirationMinute - this.GetCurrentGameMinute();
    return Max(0, remaining);
  }

  public func GetVanguardCoverageFraudSuspensionRemainingDays() -> Int32 {
    let remaining: Int32 = this.GetVanguardCoverageFraudSuspensionRemainingMinutes();
    if remaining <= 0 {
      return 0;
    };
    return Max(1, (remaining + 1439) / 1440);
  }

  public func GetVanguardCoverageFraudLastIncidentMinute() -> Int32 {
    return this.m_coverageFraudLastIncidentMinute;
  }

  public func GetVanguardCoverageFraudLastVehicleID() -> TweakDBID {
    return this.m_coverageFraudLastVehicleID;
  }

  public func GetVanguardCoverageFraudLastVehicleName() -> String {
    if !TDBID.IsValid(this.m_coverageFraudLastVehicleID) {
      return "insured vehicle";
    };
    return this.GetVehicleDisplayName(this.m_coverageFraudLastVehicleID);
  }

  public func GetVanguardCoverageFraudLastCause() -> Int32 {
    return this.m_coverageFraudLastCause;
  }

  public func GetVanguardCoverageFraudCauseLabel(cause: Int32) -> String {
    if cause == 1 { return "direct weapon damage"; };
    if cause == 2 { return "explosive damage"; };
    if cause == 3 { return "vehicle self-destruct quickhack"; };
    if cause == 4 { return "third-party attack"; };
    if cause == 5 { return "vehicle collision"; };
    if cause == 6 { return "environmental damage"; };
    return "unknown damage source";
  }

  public func GetVanguardCoverageFraudLastCauseLabel() -> String {
    return this.GetVanguardCoverageFraudCauseLabel(this.m_coverageFraudLastCause);
  }

  public func GetVanguardCoverageTerminatedPolicyNumber() -> String {
    if this.m_coverageFraudTerminatedPolicySerial <= 0 {
      return "Unavailable";
    };
    return s"VCP-\(this.m_coverageFraudTerminatedPolicySerial)";
  }

  private func GetVanguardCoveragePostSuspensionOperationalVehicleCount() -> Int32 {
    if !this.IsVanguardCoverageOperational() {
      return 0;
    };

    return this.GetCoverageSelectedVehicleCount();
  }

  public func RefreshVanguardCoverageFraudAccountState() -> Void {
    let policyTermActive: Bool;
    let operationalVehicleCount: Int32;

    this.EnsureVanguardCoverageFraudDestroyedExclusionMigration();
    if this.m_coverageFraudPermanentlyTerminated || this.m_coverageFraudSuspensionExpirationMinute <= 0 || this.m_coverageFraudSuspensionCompletionNotified {
      return;
    };

    if this.GetCurrentGameMinute() < this.m_coverageFraudSuspensionExpirationMinute {
      return;
    };

    this.m_coverageFraudSuspensionExpirationMinute = 0;
    policyTermActive = this.HasVanguardCoverageActivePolicy();
    operationalVehicleCount = this.GetVanguardCoveragePostSuspensionOperationalVehicleCount();
    this.m_coverageFraudSuspensionCompletionNotified = true;
    if policyTermActive && operationalVehicleCount > 0 {
      this.PublishPhoneNotificationRecord(3112, t"VanguardAuto.Phone.NoVehicle", 0, 0, 0);
    } else {
      if policyTermActive {
        this.PublishPhoneNotificationRecord(3115, t"VanguardAuto.Phone.NoVehicle", 0, 0, 0);
      } else {
        this.PublishPhoneNotificationRecord(3113, t"VanguardAuto.Phone.NoVehicle", 0, 0, 0);
      };
    };
  }

  public func HasVanguardCoverageActivePolicy() -> Bool {
    this.EnsureVanguardCoverageFraudDestroyedExclusionMigration();
    if this.m_coverageFraudPermanentlyTerminated {
      return false;
    };

    if !this.HasVanguardCoveragePolicyRecord() {
      return false;
    };

    if this.m_coverageTermEndMinute <= this.GetCurrentGameMinute() {
      return false;
    };

    return true;
  }

  public func GetVanguardCoverageDaysRemaining() -> Int32 {
    let remainingMinutes: Int32;

    if !this.HasVanguardCoverageActivePolicy() {
      return 0;
    };

    remainingMinutes = this.m_coverageTermEndMinute - this.GetCurrentGameMinute();
    if remainingMinutes <= 0 {
      return 0;
    };

    return (remainingMinutes + 1439) / 1440;
  }

  public func GetVanguardCoverageDeductibleOption() -> Int32 {
    if this.m_coverageDeductibleOption <= 0 {
      return 3;
    };

    return this.NormalizeVanguardCoverageDeductibleOption(this.m_coverageDeductibleOption);
  }

  public func GetVanguardCoveragePaymentFrequency() -> Int32 {
    return this.NormalizeVanguardCoveragePaymentFrequency(this.m_coveragePaymentFrequency);
  }

  public func GetCoverageSelectedVehicleCount() -> Int32 {
    this.EnsureVanguardCoverageFraudDestroyedExclusionMigration();
    return this.GetVanguardCoverageEligibleVehicleCount(this.m_coverageVehicleIDs);
  }

  public func GetCoverageSelectedVehicleKeyAt(index: Int32) -> String {
    let i: Int32 = 0;
    let eligibleIndex: Int32 = 0;

    if index < 0 {
      return "";
    };

    while i < ArraySize(this.m_coverageVehicleIDs) {
      if this.IsVanguardCoverageOperationalVehicleID(this.m_coverageVehicleIDs[i]) {
        if eligibleIndex == index {
          return TDBID.ToStringDEBUG(this.m_coverageVehicleIDs[i]);
        };
        eligibleIndex += 1;
      };
      i += 1;
    };

    return "";
  }

  public func GetVanguardCoverageSelectedVehicleIDAt(index: Int32) -> TweakDBID {
    let i: Int32 = 0;
    let eligibleIndex: Int32 = 0;

    if index < 0 {
      return TDBID.Create("");
    };

    while i < ArraySize(this.m_coverageVehicleIDs) {
      if this.IsVanguardCoverageOperationalVehicleID(this.m_coverageVehicleIDs[i]) {
        if eligibleIndex == index {
          return this.m_coverageVehicleIDs[i];
        };
        eligibleIndex += 1;
      };
      i += 1;
    };

    return TDBID.Create("");
  }

  public func GetVanguardCoverageSelectedVehicleIDs() -> array<TweakDBID> {
    let vehicleIDs: array<TweakDBID>;
    let i: Int32 = 0;

    while i < ArraySize(this.m_coverageVehicleIDs) {
      if this.IsVanguardCoverageOperationalVehicleID(this.m_coverageVehicleIDs[i]) {
        ArrayPush(vehicleIDs, this.m_coverageVehicleIDs[i]);
      };
      i += 1;
    };

    return vehicleIDs;
  }

  public func GetVanguardCoverageSelectedCanonicalVehicleIDs() -> array<TweakDBID> {
    let vehicleIDs: array<TweakDBID>;
    let canonicalID: TweakDBID;
    let i: Int32 = 0;

    while i < ArraySize(this.m_coverageVehicleIDs) {
      if this.IsVanguardCoverageOperationalVehicleID(this.m_coverageVehicleIDs[i]) {
        canonicalID = this.GetCanonicalVehicleRecordID(this.m_coverageVehicleIDs[i]);
        if TDBID.IsValid(canonicalID) {
          ArrayPush(vehicleIDs, canonicalID);
        } else {
          ArrayPush(vehicleIDs, this.m_coverageVehicleIDs[i]);
        };
      };
      i += 1;
    };

    return vehicleIDs;
  }

  private func IsVanguardCoverageVehicleInSelectedLists(id: TweakDBID, canonicalID: TweakDBID, coverageIDs: array<TweakDBID>, coverageCanonicalIDs: array<TweakDBID>) -> Bool {
    let i: Int32 = 0;
    let coverageID: TweakDBID;
    let coverageCanonicalID: TweakDBID;

    if !TDBID.IsValid(id) && !TDBID.IsValid(canonicalID) {
      return false;
    };

    while i < ArraySize(coverageIDs) {
      coverageID = coverageIDs[i];
      if Equals(coverageID, id) || Equals(coverageID, canonicalID) {
        return true;
      };

      if i < ArraySize(coverageCanonicalIDs) {
        coverageCanonicalID = coverageCanonicalIDs[i];
        if Equals(coverageCanonicalID, id) || Equals(coverageCanonicalID, canonicalID) {
          return true;
        };
      };
      i += 1;
    };

    return false;
  }

  public func IsVanguardCoverageVehicleInsured(id: TweakDBID) -> Bool {
    let coverageID: TweakDBID;
    let i: Int32 = 0;

    this.RefreshVanguardCoverageFraudAccountState();

    if !this.IsVanguardCoverageOperational() || !this.IsVanguardCoverageOperationalVehicleID(id) {
      return false;
    };

    while i < ArraySize(this.m_coverageVehicleIDs) {
      coverageID = this.m_coverageVehicleIDs[i];
      if this.VanguardCoverageIDsMatch(coverageID, id) {
        return true;
      };
      i += 1;
    };

    i = 0;
    while i < ArraySize(this.m_coverageRuntimeAliasVehicleIDs) && i < ArraySize(this.m_coverageRuntimeAliasPolicyIDs) {
      if this.VanguardCoverageIDsMatch(this.m_coverageRuntimeAliasVehicleIDs[i], id) && this.IsVanguardCoveragePolicyVehicleSelected(this.m_coverageRuntimeAliasPolicyIDs[i]) {
        return true;
      };
      i += 1;
    };

    return false;
  }

  public func IsVanguardCoverageVehicleSelectedOnPolicyRecord(id: TweakDBID) -> Bool {
    let i: Int32 = 0;

    if !TDBID.IsValid(id) || this.IsVanguardCoverageVehicleIneligible(id) {
      return false;
    };

    while i < ArraySize(this.m_coverageVehicleIDs) {
      if this.VanguardCoverageIDsMatch(this.m_coverageVehicleIDs[i], id) {
        return true;
      };
      i += 1;
    };

    i = 0;
    while i < ArraySize(this.m_coverageRuntimeAliasVehicleIDs) && i < ArraySize(this.m_coverageRuntimeAliasPolicyIDs) {
      if this.VanguardCoverageIDsMatch(this.m_coverageRuntimeAliasVehicleIDs[i], id) {
        return this.IsVanguardCoverageVehicleSelectedOnPolicyRecord(this.m_coverageRuntimeAliasPolicyIDs[i]);
      };
      i += 1;
    };

    return false;
  }

  private func IsVanguardCoveragePolicyVehicleSelected(id: TweakDBID) -> Bool {
    return this.HasVanguardCoverageActivePolicy() && this.IsVanguardCoverageOperationalVehicleID(id) && this.IsVanguardCoverageVehicleSelectedOnPolicyRecord(id);
  }

  public func ClearVanguardCoverageRuntimeAliases() -> Bool {
    ArrayClear(this.m_coverageRuntimeAliasVehicleIDs);
    ArrayClear(this.m_coverageRuntimeAliasPolicyIDs);
    return true;
  }

  public func RegisterVanguardCoverageRuntimeAliasByKey(liveKey: String, policyKey: String) -> Bool {
    let liveID: TweakDBID = TDBID.Create(liveKey);
    let policyID: TweakDBID = TDBID.Create(policyKey);

    if !TDBID.IsValid(liveID) || !TDBID.IsValid(policyID) || !this.IsVanguardCoveragePolicyVehicleSelected(policyID) {
      return false;
    };

    this.ClearVanguardCoverageRuntimeAliases();
    ArrayPush(this.m_coverageRuntimeAliasVehicleIDs, liveID);
    ArrayPush(this.m_coverageRuntimeAliasPolicyIDs, policyID);
    return true;
  }

  public func IsVanguardCoverageVehicleInsuredByKey(key: String) -> Bool {
    return this.IsVanguardCoverageVehicleInsured(TDBID.Create(key));
  }

  public func IsVanguardMountedPlayerVehicleOwned() -> Bool {
    let player: ref<PlayerPuppet>;
    let mounted: ref<VehicleObject>;

    player = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if !IsDefined(player) {
      return false;
    };

    mounted = player.GetMountedVehicle();
    return IsDefined(mounted) && mounted.VanguardAutoIsCustomerVehicle();
  }

  public func GetVanguardMountedPlayerVehicleID() -> TweakDBID {
    let player: ref<PlayerPuppet>;
    let mounted: ref<VehicleObject>;
    let vehicleID: TweakDBID;

    player = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if !IsDefined(player) {
      return TDBID.Create("");
    };

    mounted = player.GetMountedVehicle();
    if !IsDefined(mounted) || !mounted.VanguardAutoIsCustomerVehicle() {
      return TDBID.Create("");
    };

    vehicleID = mounted.GetRecordID();
    if !TDBID.IsValid(vehicleID) {
      return TDBID.Create("");
    };

    return vehicleID;
  }

  public func GetVanguardMountedCoverageVehicleID() -> TweakDBID {
    let vehicleID: TweakDBID = this.GetVanguardMountedPlayerVehicleID();
    let policyID: TweakDBID;

    if !TDBID.IsValid(vehicleID) || !this.IsVanguardCoverageVehicleInsured(vehicleID) {
      return TDBID.Create("");
    };

    policyID = this.ResolveVanguardCoverageVehicleID(vehicleID);
    if TDBID.IsValid(policyID) {
      return policyID;
    };

    return vehicleID;
  }

  public func GetVanguardMountedPlayerVehicleKey() -> String {
    let player: ref<PlayerPuppet>;
    let mounted: ref<VehicleObject>;
    let vehicleID: TweakDBID;

    player = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if !IsDefined(player) {
      return "";
    };

    mounted = player.GetMountedVehicle();
    if !IsDefined(mounted) || !mounted.VanguardAutoIsCustomerVehicle() {
      return "";
    };

    vehicleID = mounted.GetRecordID();
    if !TDBID.IsValid(vehicleID) {
      return "";
    };

    return TDBID.ToStringDEBUG(vehicleID);
  }

  public func GetVanguardMountedCoverageVehicleKey() -> String {
    let player: ref<PlayerPuppet>;
    let mounted: ref<VehicleObject>;
    let vehicleID: TweakDBID;
    let policyID: TweakDBID;

    player = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if !IsDefined(player) {
      return "";
    };

    mounted = player.GetMountedVehicle();
    if !IsDefined(mounted) || !mounted.VanguardAutoIsCustomerVehicle() {
      return "";
    };

    vehicleID = mounted.GetRecordID();
    if !TDBID.IsValid(vehicleID) || !this.IsVanguardCoverageVehicleInsured(vehicleID) {
      return "";
    };

    policyID = this.ResolveVanguardCoverageVehicleID(vehicleID);
    if TDBID.IsValid(policyID) {
      return TDBID.ToStringDEBUG(policyID);
    };

    return TDBID.ToStringDEBUG(vehicleID);
  }

  public func IsVanguardMountedPlayerVehicleInsured() -> Bool {
    let player: ref<PlayerPuppet>;
    let mounted: ref<VehicleObject>;
    let vehicleID: TweakDBID;

    player = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if !IsDefined(player) {
      return false;
    };

    mounted = player.GetMountedVehicle();
    if !IsDefined(mounted) || !mounted.VanguardAutoIsCustomerVehicle() {
      return false;
    };

    vehicleID = mounted.GetRecordID();
    if !TDBID.IsValid(vehicleID) {
      return false;
    };

    return this.IsVanguardCoverageVehicleInsured(vehicleID);
  }

  public func RestoreVanguardCoverageVehicleByKey(key: String, deductibleOption: Int32, paymentFrequency: Int32, termMonths: Int32, daysRemaining: Int32) -> Bool {
    let id: TweakDBID = TDBID.Create(key);
    let canonicalID: TweakDBID;
    let normalizedDeductible: Int32;
    let normalizedFrequency: Int32;
    let normalizedTermMonths: Int32;
    let normalizedDaysRemaining: Int32;
    let now: Int32;
    let existingID: TweakDBID;
    let i: Int32 = 0;
    let alreadyTracked: Bool = false;

    if !this.CanModifyVanguardCoveragePolicy() {
      return false;
    };

    if !TDBID.IsValid(id) {
      return false;
    };

    if !this.IsVanguardCoverageOperationalVehicleID(id) {
      return false;
    };

    canonicalID = this.GetCanonicalVehicleRecordID(id);
    if TDBID.IsValid(canonicalID) && !this.IsVanguardCoverageOperationalVehicleID(canonicalID) {
      return false;
    };
    normalizedDeductible = this.NormalizeVanguardCoverageDeductibleOption(deductibleOption);
    normalizedFrequency = this.NormalizeVanguardCoveragePaymentFrequency(paymentFrequency);
    normalizedTermMonths = this.NormalizeVanguardCoverageTermMonths(termMonths);
    normalizedDaysRemaining = daysRemaining;
    if normalizedDaysRemaining <= 0 {
      normalizedDaysRemaining = this.GetVanguardCoverageTermDays(normalizedTermMonths);
    };

    while i < ArraySize(this.m_coverageVehicleIDs) {
      existingID = this.m_coverageVehicleIDs[i];
      if this.VanguardCoverageIDsMatch(existingID, id) || this.VanguardCoverageIDsMatch(existingID, canonicalID) {
        alreadyTracked = true;
      };
      i += 1;
    };

    if !alreadyTracked {
      if TDBID.IsValid(canonicalID) {
        ArrayPush(this.m_coverageVehicleIDs, canonicalID);
      } else {
        ArrayPush(this.m_coverageVehicleIDs, id);
      };
    };

    this.m_coverageDeductibleOption = normalizedDeductible;
    this.m_coveragePaymentFrequency = normalizedFrequency;
    this.m_coverageTermMonths = normalizedTermMonths;
    this.m_coverageLastTermPremium = this.CalculateVanguardCoverageTermPremiumForMonths(this.m_coverageVehicleIDs, normalizedDeductible, normalizedTermMonths);
    this.m_coverageLastPaymentAmount = this.GetVanguardCoverageInstallmentAmountForTerm(this.m_coverageLastTermPremium, normalizedFrequency, normalizedTermMonths);
    this.EnsureVanguardCoveragePolicyNumber();

    now = this.GetCurrentGameMinute();
    if this.m_coverageTermStartMinute <= 0 || this.m_coverageTermEndMinute <= now {
      this.m_coverageTermStartMinute = now;
      this.m_coverageTermEndMinute = now + normalizedDaysRemaining * 1440;
    };

    if this.m_coverageGoodDriverStartMinute <= 0 {
      this.m_coverageGoodDriverStartMinute = now;
    };

    return true;
  }

  public func IsVanguardCoverageOwnedOrFinancedVehicle(id: TweakDBID) -> Bool {
    let canonicalID: TweakDBID = this.GetCanonicalVehicleRecordID(id);
    let hasDistinctCanonicalID: Bool = NotEquals(canonicalID, id);

    if !TDBID.IsValid(id) {
      return false;
    };

    if this.IsVanguardCoverageVehicleIneligible(id) || (hasDistinctCanonicalID && this.IsVanguardCoverageVehicleIneligible(canonicalID)) {
      return false;
    };

    if ArrayContains(this.m_soldVehicles, id) || (hasDistinctCanonicalID && ArrayContains(this.m_soldVehicles, canonicalID)) {
      return false;
    };

    if this.IsVehicleRepossessed(id) || (hasDistinctCanonicalID && this.IsVehicleRepossessed(canonicalID)) || this.IsVehicleDefaulted(id) || (hasDistinctCanonicalID && this.IsVehicleDefaulted(canonicalID)) {
      return false;
    };

    if this.IsVehicleFinanced(id) || (hasDistinctCanonicalID && this.IsVehicleFinanced(canonicalID)) {
      return true;
    };

    if this.IsSeparatePurchased(id) {
      return true;
    };

    if TDBID.IsValid(canonicalID) && NotEquals(canonicalID, id) && this.IsSeparatePurchased(canonicalID) {
      return true;
    };

    return false;
  }

  public func IsVanguardCoverageVehicleEligibleForClaim(id: TweakDBID) -> Bool {

    return this.IsVanguardCoverageVehicleInsured(id);
  }

  private func VanguardCoverageIDsMatch(a: TweakDBID, b: TweakDBID) -> Bool {
    let aCanonical: TweakDBID;
    let bCanonical: TweakDBID;

    if !TDBID.IsValid(a) || !TDBID.IsValid(b) {
      return false;
    };

    if Equals(a, b) {
      return true;
    };

    aCanonical = this.GetCanonicalVehicleRecordID(a);
    bCanonical = this.GetCanonicalVehicleRecordID(b);
    if Equals(aCanonical, b) || Equals(a, bCanonical) || Equals(aCanonical, bCanonical) {
      return true;
    };

    return false;
  }

  public func DoVanguardCoverageVehicleIDsMatch(a: TweakDBID, b: TweakDBID) -> Bool {
    return this.VanguardCoverageIDsMatch(a, b);
  }

  public func IsVanguardUninsuredVehicleDestroyed(id: TweakDBID) -> Bool {
    let i: Int32 = 0;

    if !VanguardAutoOptions.PermanentLossEnabled() {
      return false;
    };

    if !TDBID.IsValid(id) {
      return false;
    };

    while i < ArraySize(this.m_uninsuredDestroyedVehicleIDs) {
      if this.VanguardCoverageIDsMatch(this.m_uninsuredDestroyedVehicleIDs[i], id) {
        return true;
      };
      i += 1;
    };

    return false;
  }

  public func IsVanguardUninsuredVehicleDestroyedByKey(key: String) -> Bool {
    return this.IsVanguardUninsuredVehicleDestroyed(TDBID.Create(key));
  }

  public func MarkVanguardDestroyedVehicleWithoutSettlement(id: TweakDBID) -> Bool {
    let canonicalID: TweakDBID;

    if !VanguardAutoOptions.PermanentLossEnabled() {
      return false;
    };

    if !TDBID.IsValid(id) || this.IsVanguardCoverageVehicleIneligible(id) {
      return false;
    };

    canonicalID = this.GetCanonicalVehicleRecordID(id);
    if this.IsVanguardCoverageVehicleIneligible(canonicalID) || !this.IsVanguardCoverageOwnedOrFinancedVehicle(id) {
      return false;
    };

    if this.IsVanguardCoverageTotalLossLocked(id) {
      return false;
    };

    if this.IsVanguardUninsuredVehicleDestroyed(id) {
      return true;
    };

    if TDBID.IsValid(canonicalID) {
      ArrayPush(this.m_uninsuredDestroyedVehicleIDs, canonicalID);
    } else {
      ArrayPush(this.m_uninsuredDestroyedVehicleIDs, id);
    };

    this.InvalidateNCGTAppreciation(id);
    this.RemoveNCGTPerformancePackageState(id);
    return true;
  }

  public func MarkVanguardDestroyedVehicleWithoutSettlementByKey(key: String) -> Bool {
    return this.MarkVanguardDestroyedVehicleWithoutSettlement(TDBID.Create(key));
  }

  public func MarkVanguardUninsuredVehicleDestroyed(id: TweakDBID) -> Bool {
    if !VanguardAutoOptions.PermanentLossEnabled() && TDBID.IsValid(id) && !this.IsVanguardCoverageVehicleIneligible(id) && !this.IsVanguardCoverageTotalLossLocked(id) {
      VanguardAutoOptions.ChargeRestoreFee(this.GetGameInstance(), this.GetVanguardCoverageVehicleValue(id));
      return false;
    };

    if this.IsVanguardCoverageVehicleInsured(id) || this.IsVanguardCoverageTotalLossLocked(id) {
      return false;
    };

    if !this.MarkVanguardDestroyedVehicleWithoutSettlement(id) {
      return false;
    };

    this.RemoveVanguardCoverageVehicleFromPolicy(id);
    return true;
  }

  public func MarkVanguardUninsuredVehicleDestroyedByKey(key: String) -> Bool {
    return this.MarkVanguardUninsuredVehicleDestroyed(TDBID.Create(key));
  }

  private func ClearVanguardUninsuredVehicleDestroyed(id: TweakDBID) -> Void {
    let remaining: array<TweakDBID>;
    let destroyedID: TweakDBID;

    if !TDBID.IsValid(id) {
      return;
    };

    for destroyedID in this.m_uninsuredDestroyedVehicleIDs {
      if !this.VanguardCoverageIDsMatch(destroyedID, id) {
        ArrayPush(remaining, destroyedID);
      };
    };

    this.m_uninsuredDestroyedVehicleIDs = remaining;
  }

  private func RecoverVanguardCoverageLegacyFailedInsuredTotalLossClaims() -> Void {
    let destroyedVehicleIDs: array<TweakDBID>;
    let id: TweakDBID;

    destroyedVehicleIDs = this.m_uninsuredDestroyedVehicleIDs;
    for id in destroyedVehicleIDs {
      if this.IsVanguardCoverageVehicleSelectedOnPolicyRecord(id) && !this.IsVanguardCoverageFraudDestroyedVehicleExcluded(id) && !this.HasPendingVanguardCoverageTotalLossClaimForVehicle(id) {
        this.ClearVanguardUninsuredVehicleDestroyed(id);
        if this.CreateVanguardCoverageTotalLossClaimAfterAdjudication(id, true) {
        } else {
          this.MarkVanguardDestroyedVehicleWithoutSettlement(id);
        };
      };
    };
  }

  public func GetVanguardVehicleScrapPayout(id: TweakDBID) -> Int32 {
    let baseValue: Int32;
    let payout: Int32;

    if !TDBID.IsValid(id) {
      return 0;
    };

    baseValue = this.GetVehicleBasePrice(this.GetCanonicalVehicleRecordID(id));
    payout = baseValue / 125;
    payout = (payout / 25) * 25;

    if payout < 150 {
      return 150;
    };

    if payout > 600 {
      return 600;
    };

    return payout;
  }

  private func ResolveVanguardCoverageVehicleID(id: TweakDBID) -> TweakDBID {
    let i: Int32 = 0;

    while i < ArraySize(this.m_coverageVehicleIDs) {
      if this.VanguardCoverageIDsMatch(this.m_coverageVehicleIDs[i], id) {
        return this.m_coverageVehicleIDs[i];
      };
      i += 1;
    };

    i = 0;
    while i < ArraySize(this.m_coverageRuntimeAliasVehicleIDs) && i < ArraySize(this.m_coverageRuntimeAliasPolicyIDs) {
      if this.VanguardCoverageIDsMatch(this.m_coverageRuntimeAliasVehicleIDs[i], id) && this.IsVanguardCoveragePolicyVehicleSelected(this.m_coverageRuntimeAliasPolicyIDs[i]) {
        return this.m_coverageRuntimeAliasPolicyIDs[i];
      };
      i += 1;
    };

    return id;
  }

  private func GetVanguardCoverageTotalLossStatusAt(index: Int32) -> Int32 {
    if index < 0 || index >= ArraySize(this.m_coverageTotalLossVehicleIDs) {
      return 0;
    };

    if index >= ArraySize(this.m_coverageTotalLossStatuses) {
      return 0;
    };

    return this.m_coverageTotalLossStatuses[index];
  }

  private func AlignVanguardCoverageTotalLossClaimArrays() -> Void {
    let count: Int32 = ArraySize(this.m_coverageTotalLossVehicleIDs);
    let completeCount: Int32 = count;
    let i: Int32;

    completeCount = Min(completeCount, ArraySize(this.m_coverageTotalLossClaimNumbers));
    completeCount = Min(completeCount, ArraySize(this.m_coverageTotalLossValues));
    completeCount = Min(completeCount, ArraySize(this.m_coverageTotalLossDeductibles));
    completeCount = Min(completeCount, ArraySize(this.m_coverageTotalLossSettlements));
    completeCount = Min(completeCount, ArraySize(this.m_coverageTotalLossLoanBalances));
    completeCount = Min(completeCount, ArraySize(this.m_coverageTotalLossBankPayments));
    completeCount = Min(completeCount, ArraySize(this.m_coverageTotalLossPlayerDeposits));
    completeCount = Min(completeCount, ArraySize(this.m_coverageTotalLossRemainingLoans));
    completeCount = Min(completeCount, ArraySize(this.m_coverageTotalLossIssuedMinutes));
    completeCount = Min(completeCount, ArraySize(this.m_coverageTotalLossStatuses));

    i = completeCount;
    while i < count && i < ArraySize(this.m_coverageTotalLossStatuses) {
      this.m_coverageTotalLossStatuses[i] = 0;
      i += 1;
    };

    ArrayResize(this.m_coverageTotalLossClaimNumbers, count);
    ArrayResize(this.m_coverageTotalLossValues, count);
    ArrayResize(this.m_coverageTotalLossDeductibles, count);
    ArrayResize(this.m_coverageTotalLossSettlements, count);
    ArrayResize(this.m_coverageTotalLossLoanBalances, count);
    ArrayResize(this.m_coverageTotalLossBankPayments, count);
    ArrayResize(this.m_coverageTotalLossPlayerDeposits, count);
    ArrayResize(this.m_coverageTotalLossRemainingLoans, count);
    ArrayResize(this.m_coverageTotalLossIssuedMinutes, count);
    ArrayResize(this.m_coverageTotalLossStatuses, count);
  }

  private func IsVanguardCoverageTotalLossClaimRecordComplete(index: Int32) -> Bool {
    if index < 0 || index >= ArraySize(this.m_coverageTotalLossVehicleIDs) || index >= ArraySize(this.m_coverageTotalLossClaimNumbers) || index >= ArraySize(this.m_coverageTotalLossValues) || index >= ArraySize(this.m_coverageTotalLossDeductibles) || index >= ArraySize(this.m_coverageTotalLossSettlements) || index >= ArraySize(this.m_coverageTotalLossLoanBalances) || index >= ArraySize(this.m_coverageTotalLossBankPayments) || index >= ArraySize(this.m_coverageTotalLossPlayerDeposits) || index >= ArraySize(this.m_coverageTotalLossRemainingLoans) || index >= ArraySize(this.m_coverageTotalLossIssuedMinutes) || index >= ArraySize(this.m_coverageTotalLossStatuses) {
      return false;
    };

    if !TDBID.IsValid(this.m_coverageTotalLossVehicleIDs[index]) || this.m_coverageTotalLossClaimNumbers[index] <= 0 || this.m_coverageTotalLossValues[index] <= 0 || this.m_coverageTotalLossDeductibles[index] < 0 || this.m_coverageTotalLossSettlements[index] < 0 || this.m_coverageTotalLossLoanBalances[index] < 0 || this.m_coverageTotalLossBankPayments[index] < 0 || this.m_coverageTotalLossPlayerDeposits[index] < 0 || this.m_coverageTotalLossRemainingLoans[index] < 0 || this.m_coverageTotalLossIssuedMinutes[index] < 0 || this.m_coverageTotalLossStatuses[index] < 0 || this.m_coverageTotalLossStatuses[index] > 2 {
      return false;
    };

    if this.m_coverageTotalLossSettlements[index] != Max(0, this.m_coverageTotalLossValues[index] - this.m_coverageTotalLossDeductibles[index]) {
      return false;
    };

    if this.m_coverageTotalLossBankPayments[index] + this.m_coverageTotalLossPlayerDeposits[index] != this.m_coverageTotalLossSettlements[index] || this.m_coverageTotalLossBankPayments[index] + this.m_coverageTotalLossRemainingLoans[index] != this.m_coverageTotalLossLoanBalances[index] {
      return false;
    };

    return StrLen(this.GetVehicleDisplayName(this.m_coverageTotalLossVehicleIDs[index])) > 0;
  }

  public func GetVanguardCoverageTotalLossClaimIndex(id: TweakDBID) -> Int32 {
    let i: Int32 = 0;
    let fallbackIndex: Int32 = -1;

    if !TDBID.IsValid(id) {
      return -1;
    };

    if this.IsVanguardCoverageVehicleIneligible(id) || this.IsVanguardCoverageVehicleIneligible(this.GetCanonicalVehicleRecordID(id)) {
      return -1;
    };

    while i < ArraySize(this.m_coverageTotalLossVehicleIDs) {
      if this.IsVanguardCoverageTotalLossClaimRecordComplete(i) && this.VanguardCoverageIDsMatch(this.m_coverageTotalLossVehicleIDs[i], id) {
        if this.GetVanguardCoverageTotalLossStatusAt(i) == 1 {
          return i;
        };
        if fallbackIndex < 0 {
          fallbackIndex = i;
        };
      };
      i += 1;
    };

    return fallbackIndex;
  }

  public func GetVanguardCoveragePendingTotalLossClaimIndex() -> Int32 {
    let i: Int32 = 0;
    let pendingIndex: Int32 = -1;
    let pendingMinute: Int32 = 0;
    let issuedMinute: Int32;

    while i < ArraySize(this.m_coverageTotalLossVehicleIDs) {
      if this.IsVanguardCoverageTotalLossClaimRecordComplete(i) && this.GetVanguardCoverageTotalLossStatusAt(i) == 1 && !this.IsVanguardCoverageVehicleIneligible(this.m_coverageTotalLossVehicleIDs[i]) {
        issuedMinute = this.m_coverageTotalLossIssuedMinutes[i];
        if pendingIndex < 0 || issuedMinute < pendingMinute {
          pendingIndex = i;
          pendingMinute = issuedMinute;
        };
      };
      i += 1;
    };

    return pendingIndex;
  }

  public func HasPendingVanguardCoverageTotalLossClaim() -> Bool {
    return this.GetVanguardCoveragePendingTotalLossClaimIndex() >= 0;
  }

  public func IsVanguardCoverageTotalLossClaimPendingAt(index: Int32) -> Bool {
    return this.IsVanguardCoverageTotalLossClaimRecordComplete(index) && this.GetVanguardCoverageTotalLossStatusAt(index) == 1 && !this.IsVanguardCoverageVehicleIneligible(this.m_coverageTotalLossVehicleIDs[index]);
  }

  public func GetVanguardCoveragePendingTotalLossClaimCount() -> Int32 {
    let i: Int32 = 0;
    let count: Int32 = 0;

    while i < ArraySize(this.m_coverageTotalLossVehicleIDs) {
      if this.IsVanguardCoverageTotalLossClaimRecordComplete(i) && this.GetVanguardCoverageTotalLossStatusAt(i) == 1 && !this.IsVanguardCoverageVehicleIneligible(this.m_coverageTotalLossVehicleIDs[i]) {
        count += 1;
      };
      i += 1;
    };

    return count;
  }

  public func IsVanguardCoverageTotalLossClaimNumberPending(claimNumber: Int32) -> Bool {
    let i: Int32 = 0;
    let matchCount: Int32 = 0;
    let pending: Bool = false;

    if claimNumber <= 0 {
      return false;
    };

    while i < ArraySize(this.m_coverageTotalLossVehicleIDs) {
      if this.IsVanguardCoverageTotalLossClaimRecordComplete(i) && this.m_coverageTotalLossClaimNumbers[i] == claimNumber {
        matchCount += 1;
        if this.IsVanguardCoverageTotalLossClaimPendingAt(i) {
          pending = true;
        };
      };
      i += 1;
    };

    return matchCount == 1 && pending;
  }

  private func IsVanguardCoverageTotalLossNotificationValid(id: TweakDBID, claimNumber: Int32) -> Bool {
    let i: Int32 = 0;
    let matchCount: Int32 = 0;
    let targetPending: Bool = false;

    if !TDBID.IsValid(id) || claimNumber <= 0 {
      return false;
    };

    while i < ArraySize(this.m_coverageTotalLossVehicleIDs) {
      if this.IsVanguardCoverageTotalLossClaimRecordComplete(i) && this.m_coverageTotalLossClaimNumbers[i] == claimNumber {
        matchCount += 1;
        if this.IsVanguardCoverageTotalLossClaimPendingAt(i) && this.VanguardCoverageIDsMatch(this.m_coverageTotalLossVehicleIDs[i], id) {
          targetPending = true;
        };
      };
      i += 1;
    };

    return matchCount == 1 && targetPending;
  }

  public func GetVanguardCoverageActiveVehicleCount() -> Int32 {
    return this.GetCoverageSelectedVehicleCount();
  }

  public func GetVanguardCoverageActiveVehicleIDAt(index: Int32) -> TweakDBID {
    return this.GetVanguardCoverageSelectedVehicleIDAt(index);
  }

  public func GetVanguardCoveragePolicyStateLabel() -> String {
    if this.IsVanguardCoveragePermanentlyTerminated() {
      return "TERMINATED";
    };
    if this.IsVanguardCoverageSuspended() {
      return "SUSPENDED";
    };
    if this.IsVanguardCoverageOperational() {
      return "OPERATIONAL";
    };
    if this.HasVanguardCoverageActivePolicy() {
      return "ACTIVE / NO COVERED VEHICLES";
    };
    if this.HasVanguardCoveragePolicyRecord() && !this.IsVanguardCoveragePolicyTermActive() {
      return "EXPIRED";
    };
    return "NO POLICY";
  }

  private func IsVanguardCoverageFraudDiagnosticsEnabled() -> Bool {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    return IsDefined(quests) && quests.GetFact(n"vanguard_coverage_fraud_diagnostics") > 0;
  }

  private func GetVanguardCoverageFraudPolicyConsequenceLabel(disposition: Int32, strikeApplied: Int32, claimCreated: Bool) -> String {
    if strikeApplied >= 3 { return "PERMANENT TERMINATION"; };
    if strikeApplied == 2 { return "7-DAY SUSPENSION"; };
    if strikeApplied == 1 { return "FRAUD WARNING"; };
    if disposition == 2 { return "CLAIM DENIED"; };
    if claimCreated { return "LEGITIMATE CLAIM CREATED"; };
    if disposition == 4 { return "ALREADY ADJUDICATED"; };
    return "NO PUNITIVE ACTION";
  }

  private func GetVanguardCoverageQuickhackClassifierLabel(classifier: Int32) -> String {
    if classifier == 2 { return "EXACT VEHICLE SELF-DESTRUCT"; };
    if classifier == 1 { return "GENERIC OR UNKNOWN QUICKHACK"; };
    return "NOT A QUICKHACK";
  }

  private func LogVanguardCoverageDestructionAdjudication(id: TweakDBID, coveredAtIncident: Bool, playerEvidence: Bool, nonPlayerEvidence: Bool, uncertainEvidence: Bool, cause: Int32, quickhackMarker: Bool, attackType: Int32, attackRecord: TweakDBID, sourceKind: Int32, actionRecord: TweakDBID, quickhackClassifier: Int32, instigatorKind: Int32, attackInstigator: String, previousEvidenceTime: Float, evidenceAge: Float, evidenceClearedStale: Bool, fraudExcluded: Bool, premiumRemoved: Bool, creditSuppressed: Bool, disposition: Int32, strikeApplied: Int32, claimCreated: Bool) -> Void {
    let diagnostic: String;

    if !this.IsVanguardCoverageFraudDiagnosticsEnabled() {
      return;
    };

    diagnostic = s"[VanguardAutoFraud] destruction adjudication vehicle=\(TDBID.ToStringDEBUG(id)) covered=\(coveredAtIncident) policy=\(this.GetVanguardCoveragePolicyStateLabel()) attackInstigator=\(attackInstigator) instigatorKind=\(instigatorKind) playerEvidence=\(playerEvidence) nonPlayerEvidence=\(nonPlayerEvidence) uncertainEvidence=\(uncertainEvidence) cause=\(this.GetVanguardCoverageFraudCauseLabel(cause)) quickhackMarker=\(quickhackMarker) quickhackClassifier=\(this.GetVanguardCoverageQuickhackClassifierLabel(quickhackClassifier)) attackType=\(attackType) attackRecord=\(TDBID.ToStringDEBUG(attackRecord)) actionRecord=\(TDBID.ToStringDEBUG(actionRecord)) sourceKind=\(sourceKind) previousEvidenceTime=\(previousEvidenceTime) evidenceAge=\(evidenceAge) evidenceClearedStale=\(evidenceClearedStale) fraudExcluded=\(fraudExcluded) premiumRemoved=\(premiumRemoved) creditRefundSuppressed=\(creditSuppressed) result=\(disposition) claimDenied=\(disposition == 2) claimCreated=\(claimCreated) strikeApplied=\(strikeApplied) consequence=\(this.GetVanguardCoverageFraudPolicyConsequenceLabel(disposition, strikeApplied, claimCreated)) suspensionExpiration=\(this.m_coverageFraudSuspensionExpirationMinute)";
    FTLogWarning(diagnostic);
  }

  private func ApplyVanguardCoverageFraudStrike(id: TweakDBID, cause: Int32) -> Int32 {
    let newStrike: Int32 = Min(3, Max(0, this.m_coverageFraudStrikeCount) + 1);
    let now: Int32 = this.GetCurrentGameMinute();

    this.m_coverageFraudStrikeCount = newStrike;
    this.m_coverageFraudLastIncidentMinute = now;
    this.m_coverageFraudLastVehicleID = this.ResolveVanguardCoverageVehicleID(id);
    if !TDBID.IsValid(this.m_coverageFraudLastVehicleID) {
      this.m_coverageFraudLastVehicleID = id;
    };
    this.m_coverageFraudLastCause = cause;

    if newStrike == 1 {
      this.PublishPhoneNotificationRecord(3110, this.m_coverageFraudLastVehicleID, 1, 0, 0);
    } else {
      if newStrike == 2 {
        this.m_coverageFraudSuspensionExpirationMinute = now + 10080;
        this.m_coverageFraudSuspensionCompletionNotified = false;
        this.PublishPhoneNotificationRecord(3111, this.m_coverageFraudLastVehicleID, 2, 7, 0);
      } else {
        this.m_coverageFraudTerminatedPolicySerial = this.m_coveragePolicySerial;
        this.m_coverageFraudPermanentlyTerminated = true;
        this.m_coverageFraudSuspensionExpirationMinute = 0;
        this.m_coverageFraudSuspensionCompletionNotified = true;
        ArrayClear(this.m_coverageVehicleIDs);
        ArrayClear(this.m_coverageRuntimeAliasVehicleIDs);
        ArrayClear(this.m_coverageRuntimeAliasPolicyIDs);
        this.m_coverageLastTermPremium = 0;
        this.m_coverageLastPaymentAmount = 0;
        this.PublishPhoneNotificationRecord(3114, this.m_coverageFraudLastVehicleID, 3, 0, 0);
      };
    };

    SetFactValue(this.GetGameInstance(), n"vanguard_coverage_redscript_commit_request", 1);
    return newStrike;
  }

  public func DidLastVanguardCoverageDestructionAdjudicationCreateClaim() -> Bool {
    return this.m_coverageLastAdjudicationClaimCreated;
  }

  public func AdjudicateVanguardCoverageDestroyedVehicle(id: TweakDBID, coveredAtIncident: Bool, evidenceFresh: Bool, playerDeliberateEvidence: Bool, nonPlayerEvidence: Bool, uncertainEvidence: Bool, cause: Int32, quickhackMarker: Bool, attackType: Int32, attackRecord: TweakDBID, sourceKind: Int32) -> Int32 {
    return this.AdjudicateVanguardCoverageDestroyedVehicleWithDiagnostics(id, coveredAtIncident, evidenceFresh, playerDeliberateEvidence, nonPlayerEvidence, uncertainEvidence, cause, quickhackMarker, attackType, attackRecord, sourceKind, TDBID.Create(""), 0, 0, "", 0.00, 0.00, false);
  }

  public func AdjudicateVanguardCoverageDestroyedVehicleWithDiagnostics(id: TweakDBID, coveredAtIncidentIn: Bool, evidenceFresh: Bool, playerDeliberateEvidenceIn: Bool, nonPlayerEvidence: Bool, uncertainEvidence: Bool, cause: Int32, quickhackMarker: Bool, attackType: Int32, attackRecord: TweakDBID, sourceKind: Int32, actionRecord: TweakDBID, quickhackClassifier: Int32, instigatorKind: Int32, attackInstigator: String, previousEvidenceTime: Float, evidenceAge: Float, evidenceClearedStale: Bool) -> Int32 {
    let coveredID: TweakDBID;
    let disposition: Int32 = 3;
    let strikeApplied: Int32 = 0;
    let claimCreated: Bool = false;
    let coveredNow: Bool;
    let confirmedDeliberateCause: Bool;
    let fraudExcluded: Bool = false;
    let premiumRemoved: Bool = false;
    let creditSuppressed: Bool = false;
    let coveredAtIncident: Bool = coveredAtIncidentIn && VanguardAutoOptions.TotalLossClaimsActive();
    let playerDeliberateEvidence: Bool = playerDeliberateEvidenceIn && VanguardAutoOptions.FraudStrikesActive();

    this.m_coverageLastAdjudicationClaimCreated = false;
    if !VanguardAutoOptions.PermanentLossEnabled() && TDBID.IsValid(id) && !this.IsVanguardCoverageVehicleIneligible(id) && !this.IsVanguardCoverageTotalLossLocked(id) {
      VanguardAutoOptions.ChargeRestoreFee(this.GetGameInstance(), this.GetVanguardCoverageVehicleValue(id));
      return 3;
    };
    if !TDBID.IsValid(id) || this.IsVanguardCoverageVehicleIneligible(id) || this.IsVanguardCoverageVehicleIneligible(this.GetCanonicalVehicleRecordID(id)) {
      this.LogVanguardCoverageDestructionAdjudication(id, coveredAtIncident, playerDeliberateEvidence, nonPlayerEvidence, uncertainEvidence, cause, quickhackMarker, attackType, attackRecord, sourceKind, actionRecord, quickhackClassifier, instigatorKind, attackInstigator, previousEvidenceTime, evidenceAge, evidenceClearedStale, false, false, false, 3, 0, false);
      return 3;
    };

    coveredID = this.ResolveVanguardCoverageVehicleID(id);
    if !TDBID.IsValid(coveredID) {
      coveredID = id;
    };

    if this.IsVanguardCoverageTotalLossLocked(coveredID) {

      return 4;
    };

    if this.IsVanguardUninsuredVehicleDestroyed(coveredID) {
      if coveredAtIncident && this.m_coverageFraudStrikeCount <= 0 && this.IsVanguardCoverageVehicleSelectedOnPolicyRecord(coveredID) && !this.IsVanguardCoverageFraudDestroyedVehicleExcluded(coveredID) {
        this.ClearVanguardUninsuredVehicleDestroyed(coveredID);
      } else {
        return 4;
      };
    };

    coveredNow = this.IsVanguardCoverageVehicleInsured(coveredID);

    confirmedDeliberateCause = cause == 1 || cause == 2 || (cause == 3 && quickhackMarker && quickhackClassifier == 2);
    if evidenceFresh && coveredAtIncident && coveredNow && playerDeliberateEvidence && !nonPlayerEvidence && !uncertainEvidence && confirmedDeliberateCause && this.IsVanguardCoverageOwnedOrFinancedVehicle(coveredID) {
      if this.MarkVanguardDestroyedVehicleWithoutSettlement(coveredID) {
        fraudExcluded = this.AdministrativelyExcludeVanguardFraudDestroyedVehicle(coveredID);
        if fraudExcluded {
          disposition = 2;
          premiumRemoved = true;
          creditSuppressed = true;
          strikeApplied = this.ApplyVanguardCoverageFraudStrike(coveredID, cause);
        } else {

          disposition = 3;
        };
      } else {

        disposition = 3;
        claimCreated = this.CreateVanguardCoverageTotalLossClaimAfterAdjudication(coveredID);
        this.m_coverageLastAdjudicationClaimCreated = claimCreated;
      };
    } else {
      if !playerDeliberateEvidence && (cause == 5 || (!nonPlayerEvidence && cause == 6)) {
        disposition = 1;
      } else {
        if !playerDeliberateEvidence && nonPlayerEvidence && cause == 4 {
          disposition = 1;
        } else {
          disposition = 3;
        };
      };

      if coveredAtIncident && coveredNow {
        claimCreated = this.CreateVanguardCoverageTotalLossClaimAfterAdjudication(coveredID);
        this.m_coverageLastAdjudicationClaimCreated = claimCreated;
      };
      if !claimCreated {
        if coveredAtIncident && coveredNow {
        };
        this.MarkVanguardDestroyedVehicleWithoutSettlement(coveredID);
      };
    };

    this.LogVanguardCoverageDestructionAdjudication(coveredID, coveredAtIncident, playerDeliberateEvidence, nonPlayerEvidence, uncertainEvidence, cause, quickhackMarker, attackType, attackRecord, sourceKind, actionRecord, quickhackClassifier, instigatorKind, attackInstigator, previousEvidenceTime, evidenceAge, evidenceClearedStale, fraudExcluded, premiumRemoved, creditSuppressed, disposition, strikeApplied, claimCreated);
    return disposition;
  }

  public func HasPendingVanguardCoverageTotalLossClaimForVehicle(id: TweakDBID) -> Bool {
    let index: Int32 = this.GetVanguardCoverageTotalLossClaimIndex(id);
    return index >= 0 && this.GetVanguardCoverageTotalLossStatusAt(index) == 1;
  }

  public func IsVanguardCoverageTotalLossLocked(id: TweakDBID) -> Bool {
    let index: Int32 = this.GetVanguardCoverageTotalLossClaimIndex(id);

    if index < 0 {
      return false;
    };

    return this.GetVanguardCoverageTotalLossStatusAt(index) == 1;
  }

  public func IsVanguardCoverageTotalLossLockedByKey(key: String) -> Bool {
    return this.IsVanguardCoverageTotalLossLocked(TDBID.Create(key));
  }

  private func GenerateVanguardCoverageTotalLossClaimNumber(now: Int32) -> Int32 {
    let claimNumber: Int32 = 780000 + (now % 100000) + ArraySize(this.m_coverageTotalLossVehicleIDs);

    if claimNumber <= 0 {
      claimNumber = 784215 + ArraySize(this.m_coverageTotalLossVehicleIDs);
    };

    while ArrayContains(this.m_coverageTotalLossClaimNumbers, claimNumber) {
      claimNumber += 1;
    };

    return claimNumber;
  }

  public func GetVanguardCoverageTotalLossSettlementCooldownDays() -> Int32 {
    return 0;
  }

  private func GetVanguardCoverageTotalLossSettlementCooldownMinutes() -> Int32 {
    return this.GetVanguardCoverageTotalLossSettlementCooldownDays() * 1440;
  }

  private func GetVanguardCoverageTotalLossSettlementCooldownRemainingMinutesAt(now: Int32) -> Int32 {
    let elapsed: Int32;
    let cooldown: Int32 = this.GetVanguardCoverageTotalLossSettlementCooldownMinutes();

    if this.m_coverageLastTotalLossSettlementMinute <= 0 || cooldown <= 0 {
      return 0;
    };

    elapsed = now - this.m_coverageLastTotalLossSettlementMinute;
    if elapsed < 0 {
      elapsed = 0;
    };
    if elapsed >= cooldown {
      return 0;
    };

    return cooldown - elapsed;
  }

  public func GetVanguardCoverageTotalLossSettlementCooldownRemainingMinutes() -> Int32 {
    return this.GetVanguardCoverageTotalLossSettlementCooldownRemainingMinutesAt(this.GetCurrentGameMinute());
  }

  private func GetVanguardCoverageTotalLossSettlementCooldownRemainingDaysAt(now: Int32) -> Int32 {
    let remaining: Int32 = this.GetVanguardCoverageTotalLossSettlementCooldownRemainingMinutesAt(now);
    let days: Int32;

    if remaining <= 0 {
      return 0;
    };

    days = (remaining + 1439) / 1440;
    if days < 1 {
      return 1;
    };

    return days;
  }

  private func ShouldThrottleVanguardCoverageSettlementDenial(now: Int32) -> Bool {
    if this.m_coverageLastTotalLossDenialMinute <= 0 {
      return false;
    };
    if now < this.m_coverageLastTotalLossDenialMinute {
      return false;
    };
    return now - this.m_coverageLastTotalLossDenialMinute < 60;
  }

  private func PublishVanguardCoverageSettlementDenial(id: TweakDBID, reasonCode: Int32, daysRemaining: Int32) -> Void {
    let now: Int32 = this.GetCurrentGameMinute();

    if this.ShouldThrottleVanguardCoverageSettlementDenial(now) {
      return;
    };

    this.m_coverageLastTotalLossDenialMinute = now;
    this.PublishPhoneNotificationRecord(3102, id, reasonCode, daysRemaining, this.GetVanguardCoverageTotalLossSettlementCooldownDays());
  }

  private func PublishMarmurBankVanguardSettlementActivity(vehicleID: TweakDBID, claimNumber: Int32, settlementAmount: Int32, bankPayment: Int32, playerDeposit: Int32, walletBefore: Int32, walletAfter: Int32, financeContractIndex: Int32) -> Void {
    let gameInstance: GameInstance = this.GetGameInstance();

    SetFactValue(gameInstance, n"marmur_vanguard_settlement_pending", 1);
    SetFactValue(gameInstance, n"marmur_vanguard_settlement_claim", claimNumber);
    SetFactValue(gameInstance, n"marmur_vanguard_settlement_total", settlementAmount);
    SetFactValue(gameInstance, n"marmur_vanguard_settlement_bank_payment", bankPayment);
    SetFactValue(gameInstance, n"marmur_vanguard_settlement_player_deposit", playerDeposit);
    SetFactValue(gameInstance, n"marmur_vanguard_settlement_wallet_before", walletBefore);
    SetFactValue(gameInstance, n"marmur_vanguard_settlement_wallet_after", walletAfter);
    SetFactValue(gameInstance, n"marmur_vanguard_settlement_contract", financeContractIndex + 1);
    SetFactValue(gameInstance, n"marmur_vanguard_settlement_reason", 1);

  }

  public func CreateVanguardCoverageTotalLossClaimByKey(key: String) -> Bool {
    return this.CreateVanguardCoverageTotalLossClaim(TDBID.Create(key));
  }

  public func CreateVanguardCoverageTotalLossClaim(id: TweakDBID) -> Bool {
    let coveredAtIncident: Bool = this.IsVanguardCoverageVehicleInsured(id);
    this.AdjudicateVanguardCoverageDestroyedVehicle(id, coveredAtIncident, false, false, false, true, 7, false, 0, TDBID.Create(""), 0);
    return this.m_coverageLastAdjudicationClaimCreated || this.HasPendingVanguardCoverageTotalLossClaimForVehicle(id);
  }

  private func CreateVanguardCoverageTotalLossClaimAfterAdjudication(id: TweakDBID, opt allowInactivePolicySnapshot: Bool) -> Bool {
    let coveredID: TweakDBID;
    let existingIndex: Int32;
    let vehicleValue: Int32;
    let deductible: Int32;
    let settlementAmount: Int32;
    let financeContractID: TweakDBID;
    let loanBalance: Int32 = 0;
    let bankPayment: Int32 = 0;
    let playerDeposit: Int32 = 0;
    let remainingLoan: Int32 = 0;
    let now: Int32 = this.GetCurrentGameMinute();
    let claimNumber: Int32;
    let claimIndex: Int32;

    this.AlignVanguardCoverageTotalLossClaimArrays();

    if !TDBID.IsValid(id) {
      return false;
    };

    if this.IsVanguardCoverageVehicleIneligible(id) || this.IsVanguardCoverageVehicleIneligible(this.GetCanonicalVehicleRecordID(id)) {
      return false;
    };

    coveredID = this.ResolveVanguardCoverageVehicleID(id);
    if this.IsVanguardCoverageVehicleIneligible(coveredID) {
      return false;
    };

    existingIndex = this.GetVanguardCoverageTotalLossClaimIndex(coveredID);
    if existingIndex >= 0 && this.GetVanguardCoverageTotalLossStatusAt(existingIndex) == 1 {
      return true;
    };

    if !this.IsVanguardCoverageVehicleEligibleForClaim(coveredID) && !(allowInactivePolicySnapshot && this.IsVanguardCoverageVehicleSelectedOnPolicyRecord(coveredID) && !this.IsVanguardCoverageFraudDestroyedVehicleExcluded(coveredID)) {
      if this.IsVanguardCoverageVehicleInsured(coveredID) {
        this.PublishVanguardCoverageSettlementDenial(coveredID, 2, 0);
      };
      return false;
    };

    vehicleValue = this.GetVanguardCoverageVehicleValue(coveredID);
    deductible = this.GetVanguardCoverageDeductibleAmount(this.GetVanguardCoverageDeductibleOption());
    settlementAmount = Max(0, vehicleValue - deductible);

    financeContractID = this.GetFinanceContractIDForTradeInID(coveredID);
    if this.IsVehicleFinanced(financeContractID) {
      loanBalance = this.GetFinanceRemainingBalance(financeContractID);
    };

    bankPayment = Min(settlementAmount, loanBalance);
    playerDeposit = Max(settlementAmount - loanBalance, 0);
    remainingLoan = Max(loanBalance - settlementAmount, 0);
    claimNumber = this.GenerateVanguardCoverageTotalLossClaimNumber(now);

    claimIndex = ArraySize(this.m_coverageTotalLossVehicleIDs);
    ArrayPush(this.m_coverageTotalLossVehicleIDs, coveredID);
    ArrayPush(this.m_coverageTotalLossClaimNumbers, claimNumber);
    ArrayPush(this.m_coverageTotalLossValues, vehicleValue);
    ArrayPush(this.m_coverageTotalLossDeductibles, deductible);
    ArrayPush(this.m_coverageTotalLossSettlements, settlementAmount);
    ArrayPush(this.m_coverageTotalLossLoanBalances, loanBalance);
    ArrayPush(this.m_coverageTotalLossBankPayments, bankPayment);
    ArrayPush(this.m_coverageTotalLossPlayerDeposits, playerDeposit);
    ArrayPush(this.m_coverageTotalLossRemainingLoans, remainingLoan);
    ArrayPush(this.m_coverageTotalLossIssuedMinutes, now);

    ArrayPush(this.m_coverageTotalLossStatuses, 1);

    if !this.IsVanguardCoverageTotalLossClaimRecordComplete(claimIndex) || this.GetVanguardCoverageTotalLossStatusAt(claimIndex) != 1 || this.m_coverageTotalLossClaimNumbers[claimIndex] != claimNumber || !this.VanguardCoverageIDsMatch(this.m_coverageTotalLossVehicleIDs[claimIndex], coveredID) || !this.IsVanguardCoverageTotalLossNotificationValid(coveredID, claimNumber) {
      if claimIndex < ArraySize(this.m_coverageTotalLossStatuses) {
        this.m_coverageTotalLossStatuses[claimIndex] = 0;
      };
      return false;
    };

    this.InvalidateNCGTAppreciation(coveredID);
    this.RemoveNCGTPerformancePackageState(coveredID);
    this.PublishPhoneNotificationRecord(3101, coveredID, settlementAmount, claimNumber, 0);
    return true;
  }

  public func GetPendingVanguardCoverageTotalLossVehicleID() -> TweakDBID {
    let index: Int32 = this.GetVanguardCoveragePendingTotalLossClaimIndex();
    if index < 0 || index >= ArraySize(this.m_coverageTotalLossVehicleIDs) {
      return TDBID.Create("");
    };
    return this.m_coverageTotalLossVehicleIDs[index];
  }

  public func GetPendingVanguardCoverageTotalLossVehicleName() -> String {
    let id: TweakDBID = this.GetPendingVanguardCoverageTotalLossVehicleID();
    if !TDBID.IsValid(id) {
      return "insured vehicle";
    };
    return this.GetVehicleDisplayName(id);
  }

  public func GetPendingVanguardCoverageTotalLossClaimNumber() -> String {
    return this.GetVanguardCoverageTotalLossClaimNumberAt(this.GetVanguardCoveragePendingTotalLossClaimIndex());
  }

  public func GetPendingVanguardCoverageTotalLossSettlementAmount() -> Int32 {
    return this.GetVanguardCoverageTotalLossSettlementAmountAt(this.GetVanguardCoveragePendingTotalLossClaimIndex());
  }

  public func GetVanguardCoverageTotalLossClaimNumberAt(index: Int32) -> String {
    if index < 0 || index >= ArraySize(this.m_coverageTotalLossClaimNumbers) || this.m_coverageTotalLossClaimNumbers[index] <= 0 {
      return "";
    };

    return s"CLM-\(this.m_coverageTotalLossClaimNumbers[index])";
  }

  public func GetVanguardCoverageTotalLossVehicleNameAt(index: Int32) -> String {
    if index < 0 || index >= ArraySize(this.m_coverageTotalLossVehicleIDs) {
      return "insured vehicle";
    };
    return this.GetVehicleDisplayName(this.m_coverageTotalLossVehicleIDs[index]);
  }

  public func GetVanguardCoverageTotalLossVehicleKeyAt(index: Int32) -> String {
    if index < 0 || index >= ArraySize(this.m_coverageTotalLossVehicleIDs) || !TDBID.IsValid(this.m_coverageTotalLossVehicleIDs[index]) {
      return "";
    };

    return TDBID.ToStringDEBUG(this.m_coverageTotalLossVehicleIDs[index]);
  }

  private func FindUniqueVanguardCoverageTotalLossClaimIndexByNumber(claimNumber: Int32) -> Int32 {
    let i: Int32 = 0;
    let matchIndex: Int32 = -1;

    if claimNumber <= 0 {
      return -1;
    };

    while i < ArraySize(this.m_coverageTotalLossVehicleIDs) {
      if this.IsVanguardCoverageTotalLossClaimRecordComplete(i) && this.m_coverageTotalLossClaimNumbers[i] == claimNumber {
        if matchIndex >= 0 {
          return -1;
        };
        matchIndex = i;
      };
      i += 1;
    };

    return matchIndex;
  }

  private func IsVanguardCoverageTotalLossDespawnEligibleAt(index: Int32) -> Bool {
    if !this.IsVanguardCoverageTotalLossClaimRecordComplete(index) || this.GetVanguardCoverageTotalLossStatusAt(index) != 2 {
      return false;
    };

    if !TDBID.IsValid(this.m_coverageTotalLossVehicleIDs[index]) {
      return false;
    };

    return ArrayContains(this.m_soldVehicles, this.m_coverageTotalLossVehicleIDs[index]);
  }

  private func SanitizeVanguardCoverageTotalLossDespawnQueue() -> Void {
    let normalizedClaimNumbers: array<Int32>;
    let index: Int32;

    for claimNumber in this.m_coverageTotalLossDespawnRequestClaimNumbers {
      index = this.FindUniqueVanguardCoverageTotalLossClaimIndexByNumber(claimNumber);
      if index >= 0 && this.IsVanguardCoverageTotalLossDespawnEligibleAt(index) && !ArrayContains(normalizedClaimNumbers, claimNumber) {
        ArrayPush(normalizedClaimNumbers, claimNumber);
      };
    };

    this.m_coverageTotalLossDespawnRequestClaimNumbers = normalizedClaimNumbers;
  }

  private func ResolveVanguardCoverageTotalLossDespawnRequestIndex() -> Int32 {
    let claimNumber: Int32;

    this.SanitizeVanguardCoverageTotalLossDespawnQueue();
    if ArraySize(this.m_coverageTotalLossDespawnRequestClaimNumbers) <= 0 {
      return -1;
    };

    claimNumber = this.m_coverageTotalLossDespawnRequestClaimNumbers[0];
    return this.FindUniqueVanguardCoverageTotalLossClaimIndexByNumber(claimNumber);
  }

  private func PublishVanguardCoverageTotalLossDespawnRequest() -> Void {
    let index: Int32 = this.ResolveVanguardCoverageTotalLossDespawnRequestIndex();
    let factValue: Int32 = 0;

    if index >= 0 {
      factValue = index + 1;
    };

    if GetFact(this.GetGameInstance(), n"vanguard_coverage_total_loss_despawn_request") != factValue {
      SetFactValue(this.GetGameInstance(), n"vanguard_coverage_total_loss_despawn_request", factValue);
    };
  }

  private func RepairVanguardCoverageTotalLossDespawnRequests() -> Void {
    let legacyRequest: Int32;
    let legacyIndex: Int32;
    let legacyClaimNumber: Int32;
    let existingClaimNumbers: array<Int32>;

    if this.m_coverageTotalLossDespawnQueueVersion >= 1 && ArraySize(this.m_coverageTotalLossDespawnRequestClaimNumbers) <= 0 {
      if GetFact(this.GetGameInstance(), n"vanguard_coverage_total_loss_despawn_request") != 0 {
        SetFactValue(this.GetGameInstance(), n"vanguard_coverage_total_loss_despawn_request", 0);
      };
      return;
    };

    this.AlignVanguardCoverageTotalLossClaimArrays();
    this.SanitizeVanguardCoverageTotalLossDespawnQueue();
    if this.m_coverageTotalLossDespawnQueueVersion < 1 {
      legacyRequest = GetFact(this.GetGameInstance(), n"vanguard_coverage_total_loss_despawn_request");
      legacyIndex = legacyRequest - 1;

      if legacyRequest > 0 && this.IsVanguardCoverageTotalLossDespawnEligibleAt(legacyIndex) {
        legacyClaimNumber = this.m_coverageTotalLossClaimNumbers[legacyIndex];
        if this.FindUniqueVanguardCoverageTotalLossClaimIndexByNumber(legacyClaimNumber) == legacyIndex && !ArrayContains(this.m_coverageTotalLossDespawnRequestClaimNumbers, legacyClaimNumber) {

          existingClaimNumbers = this.m_coverageTotalLossDespawnRequestClaimNumbers;
          ArrayClear(this.m_coverageTotalLossDespawnRequestClaimNumbers);
          ArrayPush(this.m_coverageTotalLossDespawnRequestClaimNumbers, legacyClaimNumber);
          for claimNumber in existingClaimNumbers {
            ArrayPush(this.m_coverageTotalLossDespawnRequestClaimNumbers, claimNumber);
          };
        };
      };

      this.m_coverageTotalLossDespawnQueueVersion = 1;
    };

    this.PublishVanguardCoverageTotalLossDespawnRequest();
  }

  private func QueueVanguardCoverageTotalLossDespawnRequest(index: Int32) -> Void {
    let claimNumber: Int32;

    this.RepairVanguardCoverageTotalLossDespawnRequests();
    if !this.IsVanguardCoverageTotalLossDespawnEligibleAt(index) {
      return;
    };

    claimNumber = this.m_coverageTotalLossClaimNumbers[index];
    if this.FindUniqueVanguardCoverageTotalLossClaimIndexByNumber(claimNumber) != index {
      return;
    };

    if !ArrayContains(this.m_coverageTotalLossDespawnRequestClaimNumbers, claimNumber) {
      ArrayPush(this.m_coverageTotalLossDespawnRequestClaimNumbers, claimNumber);
    };

    this.PublishVanguardCoverageTotalLossDespawnRequest();
  }

  public func GetVanguardCoverageTotalLossDespawnRequestIndex() -> Int32 {
    this.RepairVanguardCoverageTotalLossDespawnRequests();
    return this.ResolveVanguardCoverageTotalLossDespawnRequestIndex();
  }

  public func GetVanguardCoverageTotalLossDespawnRequestClaimNumber() -> Int32 {
    this.RepairVanguardCoverageTotalLossDespawnRequests();
    if ArraySize(this.m_coverageTotalLossDespawnRequestClaimNumbers) <= 0 {
      return 0;
    };

    return this.m_coverageTotalLossDespawnRequestClaimNumbers[0];
  }

  public func CompleteVanguardCoverageTotalLossDespawnRequest(claimNumber: Int32) -> Bool {
    this.RepairVanguardCoverageTotalLossDespawnRequests();
    if claimNumber <= 0 || ArraySize(this.m_coverageTotalLossDespawnRequestClaimNumbers) <= 0 || this.m_coverageTotalLossDespawnRequestClaimNumbers[0] != claimNumber {
      return false;
    };

    ArrayErase(this.m_coverageTotalLossDespawnRequestClaimNumbers, 0);
    this.PublishVanguardCoverageTotalLossDespawnRequest();
    return true;
  }

  public func DeferVanguardCoverageTotalLossDespawnRequest(claimNumber: Int32) -> Bool {
    this.RepairVanguardCoverageTotalLossDespawnRequests();
    if claimNumber <= 0 || ArraySize(this.m_coverageTotalLossDespawnRequestClaimNumbers) <= 1 || this.m_coverageTotalLossDespawnRequestClaimNumbers[0] != claimNumber {
      return false;
    };

    ArrayErase(this.m_coverageTotalLossDespawnRequestClaimNumbers, 0);
    ArrayPush(this.m_coverageTotalLossDespawnRequestClaimNumbers, claimNumber);
    this.PublishVanguardCoverageTotalLossDespawnRequest();
    return true;
  }

  public func GetVanguardCoverageTotalLossVehicleValueAt(index: Int32) -> Int32 {
    if index < 0 || index >= ArraySize(this.m_coverageTotalLossValues) {
      return 0;
    };
    return this.m_coverageTotalLossValues[index];
  }

  public func GetVanguardCoverageTotalLossDeductibleAt(index: Int32) -> Int32 {
    if index < 0 || index >= ArraySize(this.m_coverageTotalLossDeductibles) {
      return 0;
    };
    return this.m_coverageTotalLossDeductibles[index];
  }

  public func GetVanguardCoverageTotalLossSettlementAmountAt(index: Int32) -> Int32 {
    if index < 0 || index >= ArraySize(this.m_coverageTotalLossSettlements) {
      return 0;
    };
    return this.m_coverageTotalLossSettlements[index];
  }

  public func GetVanguardCoverageTotalLossLoanBalanceAt(index: Int32) -> Int32 {
    if index < 0 || index >= ArraySize(this.m_coverageTotalLossLoanBalances) {
      return 0;
    };
    return this.m_coverageTotalLossLoanBalances[index];
  }

  public func GetVanguardCoverageTotalLossBankPaymentAt(index: Int32) -> Int32 {
    if index < 0 || index >= ArraySize(this.m_coverageTotalLossBankPayments) {
      return 0;
    };
    return this.m_coverageTotalLossBankPayments[index];
  }

  public func GetVanguardCoverageTotalLossPlayerDepositAt(index: Int32) -> Int32 {
    if index < 0 || index >= ArraySize(this.m_coverageTotalLossPlayerDeposits) {
      return 0;
    };
    return this.m_coverageTotalLossPlayerDeposits[index];
  }

  public func GetVanguardCoverageTotalLossRemainingLoanAt(index: Int32) -> Int32 {
    if index < 0 || index >= ArraySize(this.m_coverageTotalLossRemainingLoans) {
      return 0;
    };
    return this.m_coverageTotalLossRemainingLoans[index];
  }

  private func FormatVanguardCoverageTwoDigits(value: Int32) -> String {
    if value < 10 {
      return s"0\(value)";
    };
    return s"\(value)";
  }

  public func GetVanguardCoverageTotalLossTimeIssuedAt(index: Int32) -> String {
    let issuedMinute: Int32;
    let issuedDay: Int32;
    let currentDay: Int32;
    let dateCode: Int32;
    let year: Int32;
    let month: Int32;
    let day: Int32;
    let hour: Int32;
    let minute: Int32;

    if index < 0 || index >= ArraySize(this.m_coverageTotalLossIssuedMinutes) {
      return "Night City Local Time";
    };

    issuedMinute = this.m_coverageTotalLossIssuedMinutes[index];
    issuedDay = Max(0, issuedMinute / 1440);
    currentDay = Max(0, this.GetCurrentGameMinute() / 1440);
    dateCode = VanguardAutoCalendar.DateCodeForEngineDay(
      GetGameInstance(),
      issuedDay,
      issuedDay == currentDay
    );
    year = dateCode / 10000;
    month = (dateCode / 100) % 100;
    day = dateCode % 100;
    hour = this.GetHourOfDay(issuedMinute);
    minute = issuedMinute % 60;
    return s"\(this.FormatVanguardCoverageTwoDigits(month))/\(this.FormatVanguardCoverageTwoDigits(day))/\(year) \(this.FormatVanguardCoverageTwoDigits(hour)):\(this.FormatVanguardCoverageTwoDigits(minute)) Night City Local Time";
  }

  public func IsVanguardCoverageTotalLossClaimFinancedAt(index: Int32) -> Bool {
    return this.GetVanguardCoverageTotalLossLoanBalanceAt(index) > 0;
  }
  private func ApplyVanguardCoverageInsuranceFinancePayment(id: TweakDBID, paymentAmount: Int32) -> Bool {
    let contractID: TweakDBID = this.GetFinanceContractIDForTradeInID(id);
    let i: Int32 = this.GetFinanceContractIndex(contractID);
    let balance: Int32;
    let amount: Int32;
    let after: Int32;
    if !this.IsMarmurBankAutoFinanceAvailable() { return false; };

    if i < 0 || paymentAmount <= 0 { return false; };
    balance = this.GetFinanceRemainingBalanceByIndex(i);
    if balance <= 0 { return false; };
    if paymentAmount >= balance { return this.CloseFinanceContractAfterSale(contractID, paymentAmount); };
    this.RegisterVanguardCreditContract(contractID, true);
    this.CaptureVanguardMaturedObligations(contractID);
    amount = Min(balance, paymentAmount);
    after = balance - amount;
    this.RecordVanguardCreditPayment(contractID, amount, after, false);
    this.StoreVanguardCreditPaidAmount(i, this.GetFinancePaidAmountByIndex(i) + amount);
    this.m_financeRemainingMonths[i] = Max(1, (after + this.m_financeMonthlyPayments[i] - 1) / this.m_financeMonthlyPayments[i]);
    if this.GetVanguardCreditFact(this.EnsureFinanceContractSerial(contractID), "arrears") == 0 { this.ClearFinanceDefaultState(contractID); };
    this.m_financeContractsDirty = true;
    this.PushFinanceEvent(contractID, 6, amount, this.m_financeRemainingMonths[i], this.m_financeTerms[i], this.m_financeMonthlyPayments[i]);
    return true;
  }

  private func RemoveVanguardCoverageVehicleFromPolicy(id: TweakDBID) -> Void {
    let newVehicleIDs: array<TweakDBID>;
    let i: Int32 = 0;

    while i < ArraySize(this.m_coverageVehicleIDs) {
      if !this.VanguardCoverageIDsMatch(this.m_coverageVehicleIDs[i], id) && !this.IsVanguardCoverageVehicleIneligible(this.m_coverageVehicleIDs[i]) {
        ArrayPush(newVehicleIDs, this.m_coverageVehicleIDs[i]);
      };
      i += 1;
    };

    this.m_coverageVehicleIDs = newVehicleIDs;
    if ArraySize(this.m_coverageVehicleIDs) <= 0 {
      this.m_coverageLastTermPremium = 0;
      this.m_coverageLastPaymentAmount = 0;
      this.m_coverageTermStartMinute = 0;
      this.m_coverageTermEndMinute = 0;
      this.m_coverageTermMonths = 6;
      this.m_coveragePolicySerial = 0;
      this.m_coverageAtFaultSurchargeBasisPoints = 0;
      this.m_coverageAtFaultAccidentCount = 0;
      this.m_coverageGoodDriverStartMinute = 0;
      this.m_coverageGoodDriverRewardedTermStartMinute = 0;
      this.m_coverageGoodDriverRewardedStartMinute = 0;
      this.m_coverageGoodDriverRewardedVersion = 0;
      this.m_coverageGoodDriverRefundIssuedThisTerm = false;
    } else {
      this.m_coverageLastTermPremium = this.CalculateVanguardCoverageTermPremiumForMonths(this.m_coverageVehicleIDs, this.GetVanguardCoverageDeductibleOption(), this.GetVanguardCoverageTermMonths());
      this.m_coverageLastPaymentAmount = this.GetVanguardCoverageInstallmentAmountForTerm(this.m_coverageLastTermPremium, this.GetVanguardCoveragePaymentFrequency(), this.GetVanguardCoverageTermMonths());
    };
  }

  private func RemoveVanguardCoverageVehiclesAfterOwnershipExit(player: ref<PlayerPuppet>, vehicleIDs: array<TweakDBID>) -> Int32 {
    let recipient: ref<PlayerPuppet> = player;
    let remainingVehicleIDs: array<TweakDBID>;
    let coveredID: TweakDBID;
    let exitID: TweakDBID;
    let removeCoveredID: Bool;
    let removedCoverage: Bool = false;
    let proratedRefund: Int32 = 0;
    let deductibleOption: Int32;
    let paymentFrequency: Int32;
    let termMonths: Int32;
    let i: Int32 = 0;
    let j: Int32;

    if ArraySize(vehicleIDs) <= 0 {
      return 0;
    };

    while i < ArraySize(this.m_coverageVehicleIDs) {
      coveredID = this.m_coverageVehicleIDs[i];
      removeCoveredID = false;
      j = 0;

      while j < ArraySize(vehicleIDs) {
        exitID = vehicleIDs[j];
        if TDBID.IsValid(exitID) && this.VanguardCoverageIDsMatch(coveredID, exitID) {
          removeCoveredID = true;
          removedCoverage = true;
        };
        j += 1;
      };

      if !removeCoveredID && TDBID.IsValid(coveredID) && !this.IsVanguardCoverageVehicleIneligible(coveredID) {
        ArrayPush(remainingVehicleIDs, coveredID);
      };
      i += 1;
    };

    if !removedCoverage {
      return 0;
    };

    if !this.HasVanguardCoverageActivePolicy() {
      for exitID in vehicleIDs {
        this.RemoveVanguardCoverageVehicleFromPolicy(exitID);
      };
      if this.GetCoverageSelectedVehicleCount() <= 0 {
        SetFactValue(this.GetGameInstance(), n"vanguard_coverage_redscript_commit_request", 1);
      };
      return 0;
    };

    if !IsDefined(recipient) {
      recipient = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    };
    if !IsDefined(recipient) {
      return 0;
    };

    deductibleOption = this.GetVanguardCoverageDeductibleOption();
    paymentFrequency = this.GetVanguardCoveragePaymentFrequency();
    termMonths = this.GetVanguardCoverageTermMonths();
    proratedRefund = this.GetVanguardCoverageProratedCreditForTerm(remainingVehicleIDs, deductibleOption, termMonths);

    if !this.ConfirmVanguardCoveragePolicyForTerm(recipient, remainingVehicleIDs, deductibleOption, paymentFrequency, termMonths) {
      return 0;
    };

    SetFactValue(this.GetGameInstance(), n"vanguard_coverage_redscript_commit_request", 1);
    return proratedRefund;
  }

  public func AcceptVanguardCoverageTotalLossSettlement(player: ref<PlayerPuppet>) -> Bool {
    return this.AcceptVanguardCoverageTotalLossSettlementAt(player, this.GetVanguardCoveragePendingTotalLossClaimIndex());
  }

  public func AcceptVanguardCoverageTotalLossSettlementAt(player: ref<PlayerPuppet>, index: Int32) -> Bool {
    let recipient: ref<PlayerPuppet> = player;
    let vehicleID: TweakDBID;
    let bankPayment: Int32;
    let playerDeposit: Int32;
    let settlementAmount: Int32;
    let claimNumber: Int32;
    let financeContractIndex: Int32;
    let walletBefore: Int32 = 0;
    let walletAfter: Int32 = 0;
    let removed: Bool;

    if !this.IsVanguardCoverageTotalLossClaimRecordComplete(index) || this.GetVanguardCoverageTotalLossStatusAt(index) != 1 {
      return false;
    };

    if !IsDefined(recipient) {
      recipient = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    };

    vehicleID = this.m_coverageTotalLossVehicleIDs[index];
    bankPayment = this.GetVanguardCoverageTotalLossBankPaymentAt(index);
    playerDeposit = this.GetVanguardCoverageTotalLossPlayerDepositAt(index);
    settlementAmount = this.GetVanguardCoverageTotalLossSettlementAmountAt(index);
    claimNumber = this.m_coverageTotalLossClaimNumbers[index];
    financeContractIndex = this.GetFinanceContractIndex(this.GetFinanceContractIDForTradeInID(vehicleID));

    if IsDefined(recipient) {
      walletBefore = this.m_transactionSystem.GetItemQuantity(recipient, MarketSystem.Money());
    };

    if bankPayment > 0 {
      if !this.IsMarmurBankAutoFinanceAvailable()
        || !this.ApplyVanguardCoverageInsuranceFinancePayment(vehicleID, bankPayment) {

        return false;
      };
    };

    if playerDeposit > 0 && IsDefined(recipient) {
      this.m_transactionSystem.GiveItem(recipient, MarketSystem.Money(), playerDeposit);
    };

    if IsDefined(recipient) {
      walletAfter = this.m_transactionSystem.GetItemQuantity(recipient, MarketSystem.Money());
    };

    this.PublishMarmurBankVanguardSettlementActivity(vehicleID, claimNumber, settlementAmount, bankPayment, playerDeposit, walletBefore, walletAfter, financeContractIndex);

    removed = RemoveVehicle(this.GetGameInstance(), this.m_vehicleSystem, vehicleID);
    if !removed {
    };

    if !ArrayContains(this.m_soldVehicles, vehicleID) {
      ArrayPush(this.m_soldVehicles, vehicleID);
      this.AdvanceSoldVehicleLedgerRevision();
      this.m_deactivateVehiclesDirty = true;
    };

    this.ClearVanguardUninsuredVehicleDestroyed(vehicleID);
    this.RemoveVanguardCoverageVehicleFromPolicy(vehicleID);
    this.m_coverageTotalLossStatuses[index] = 2;
    this.QueueVanguardCoverageTotalLossDespawnRequest(index);
    this.m_coverageLastTotalLossSettlementMinute = this.GetCurrentGameMinute();
    return true;
  }

  public func GetVanguardCoverageCurrentTermPremium() -> Int32 {
    if !this.HasVanguardCoverageActivePolicy() {
      return 0;
    };

    if this.m_coverageLastTermPremium > 0 {
      return this.m_coverageLastTermPremium;
    };

    return this.CalculateVanguardCoverageTermPremiumForMonths(this.m_coverageVehicleIDs, this.GetVanguardCoverageDeductibleOption(), this.GetVanguardCoverageTermMonths());
  }

  public func GetVanguardCoverageCurrentPaymentAmount() -> Int32 {
    if !this.HasVanguardCoverageActivePolicy() {
      return 0;
    };

    return this.GetVanguardCoverageInstallmentAmountForTerm(this.GetVanguardCoverageCurrentTermPremium(), this.GetVanguardCoveragePaymentFrequency(), this.GetVanguardCoverageTermMonths());
  }

  public func GetVanguardCoverageProratedDifference(vehicleIDs: array<TweakDBID>, deductibleOption: Int32) -> Int32 {
    return this.GetVanguardCoverageProratedDifferenceForTerm(vehicleIDs, deductibleOption, this.GetVanguardCoverageTermMonths());
  }

  public func GetVanguardCoverageProratedDifferenceForTerm(vehicleIDs: array<TweakDBID>, deductibleOption: Int32, termMonths: Int32) -> Int32 {
    let pendingPremium: Int32 = this.CalculateVanguardCoverageTermPremiumForMonths(vehicleIDs, deductibleOption, termMonths);

    return this.GetVanguardCoverageProratedDifferenceForPendingPremium(pendingPremium, termMonths);
  }

  public func GetVanguardCoverageProratedDifferenceForPendingPremium(pendingPremium: Int32, termMonths: Int32) -> Int32 {
    let currentPremium: Int32;
    let daysRemaining: Int32;
    let currentTermDays: Int32;
    let pendingTermDays: Int32;
    let currentDaily: Int32;
    let pendingDaily: Int32;
    let dailyDelta: Int32;
    let prorated: Int32;

    if !this.HasVanguardCoverageActivePolicy() {
      return 0;
    };

    currentPremium = this.GetVanguardCoverageCurrentTermPremium();
    daysRemaining = this.GetVanguardCoverageDaysRemaining();
    if daysRemaining <= 0 {
      return 0;
    };

    currentTermDays = this.GetVanguardCoverageTermDays(this.GetVanguardCoverageTermMonths());
    pendingTermDays = this.GetVanguardCoverageTermDays(termMonths);
    if currentTermDays <= 0 {
      currentTermDays = 182;
    };
    if pendingTermDays <= 0 {
      pendingTermDays = currentTermDays;
    };

    currentDaily = (currentPremium + currentTermDays - 1) / currentTermDays;
    pendingDaily = (pendingPremium + pendingTermDays - 1) / pendingTermDays;
    dailyDelta = pendingDaily - currentDaily;
    if dailyDelta <= 0 {
      return 0;
    };

    prorated = dailyDelta * daysRemaining;
    return Max(1, prorated);
  }

  public func GetVanguardCoverageProratedCredit(vehicleIDs: array<TweakDBID>, deductibleOption: Int32) -> Int32 {
    return this.GetVanguardCoverageProratedCreditForTerm(vehicleIDs, deductibleOption, this.GetVanguardCoverageTermMonths());
  }

  public func GetVanguardCoverageProratedCreditForTerm(vehicleIDs: array<TweakDBID>, deductibleOption: Int32, termMonths: Int32) -> Int32 {
    let pendingPremium: Int32 = this.CalculateVanguardCoverageTermPremiumForMonths(vehicleIDs, deductibleOption, termMonths);

    return this.GetVanguardCoverageProratedCreditForPendingPremium(pendingPremium, termMonths);
  }

  public func GetVanguardCoverageProratedCreditForPendingPremium(pendingPremium: Int32, termMonths: Int32) -> Int32 {
    let currentPremium: Int32;
    let daysRemaining: Int32;
    let currentTermDays: Int32;
    let pendingTermDays: Int32;
    let currentDaily: Int32;
    let pendingDaily: Int32;
    let dailyDelta: Int32;
    let prorated: Int32;

    if !this.HasVanguardCoverageActivePolicy() {
      return 0;
    };

    currentPremium = this.GetVanguardCoverageCurrentTermPremium();
    daysRemaining = this.GetVanguardCoverageDaysRemaining();
    if daysRemaining <= 0 {
      return 0;
    };

    currentTermDays = this.GetVanguardCoverageTermDays(this.GetVanguardCoverageTermMonths());
    pendingTermDays = this.GetVanguardCoverageTermDays(termMonths);
    if currentTermDays <= 0 {
      currentTermDays = 182;
    };
    if pendingTermDays <= 0 {
      pendingTermDays = currentTermDays;
    };

    currentDaily = (currentPremium + currentTermDays - 1) / currentTermDays;
    pendingDaily = (pendingPremium + pendingTermDays - 1) / pendingTermDays;
    dailyDelta = currentDaily - pendingDaily;
    if dailyDelta <= 0 {
      return 0;
    };

    prorated = dailyDelta * daysRemaining;
    return Max(1, prorated);
  }

  public func GetVanguardCoverageDueNowForSelection(vehicleIDs: array<TweakDBID>, deductibleOption: Int32, paymentFrequency: Int32) -> Int32 {
    return this.GetVanguardCoverageDueNowForSelectionForTerm(vehicleIDs, deductibleOption, paymentFrequency, 6);
  }

  public func GetVanguardCoverageDueNowForSelectionForTerm(vehicleIDs: array<TweakDBID>, deductibleOption: Int32, paymentFrequency: Int32, termMonths: Int32) -> Int32 {
    let termPremium: Int32 = this.CalculateVanguardCoverageTermPremiumForMonths(vehicleIDs, deductibleOption, termMonths);

    return this.GetVanguardCoverageDueNowForPendingPremium(termPremium, paymentFrequency, termMonths);
  }

  public func GetVanguardCoverageDueNowForPendingPremium(termPremium: Int32, paymentFrequency: Int32, termMonths: Int32) -> Int32 {
    let proratedDifference: Int32 = 0;

    if termPremium <= 0 {
      return 0;
    };

    if this.HasVanguardCoverageActivePolicy() {
      proratedDifference = this.GetVanguardCoverageProratedDifferenceForPendingPremium(termPremium, termMonths);
      if proratedDifference <= 0 {
        return 0;
      };

      if this.NormalizeVanguardCoveragePaymentFrequency(paymentFrequency) == 0 {
        return proratedDifference;
      };

      return this.GetVanguardCoverageInstallmentAmountForTerm(proratedDifference, paymentFrequency, termMonths);
    };

    return this.GetVanguardCoverageInstallmentAmountForTerm(termPremium, paymentFrequency, termMonths);
  }

  public func ConfirmVanguardCoveragePolicy(player: ref<PlayerPuppet>, vehicleIDs: array<TweakDBID>, deductibleOption: Int32, paymentFrequency: Int32) -> Bool {
    return this.ConfirmVanguardCoveragePolicyForTerm(player, vehicleIDs, deductibleOption, paymentFrequency, 6);
  }

  public func ConfirmVanguardCoveragePolicyForTerm(player: ref<PlayerPuppet>, vehicleIDs: array<TweakDBID>, deductibleOption: Int32, paymentFrequency: Int32, termMonths: Int32) -> Bool {
    let eligibleVehicleIDs: array<TweakDBID>;
    let normalizedDeductible: Int32 = this.NormalizeVanguardCoverageDeductibleOption(deductibleOption);
    let normalizedFrequency: Int32 = this.NormalizeVanguardCoveragePaymentFrequency(paymentFrequency);
    let normalizedTermMonths: Int32 = this.NormalizeVanguardCoverageTermMonths(termMonths);
    let hadActivePolicy: Bool = this.HasVanguardCoverageActivePolicy();
    let previousTermMonths: Int32 = this.GetVanguardCoverageTermMonths();
    let previousFrequency: Int32 = this.GetVanguardCoveragePaymentFrequency();
    let dueNow: Int32;
    let proratedCredit: Int32;
    let termPremium: Int32;
    let now: Int32 = this.GetCurrentGameMinute();
    let id: TweakDBID;

    if !this.CanModifyVanguardCoveragePolicy() {
      return false;
    };

    for id in vehicleIDs {
      if this.IsVanguardCoverageOperationalVehicleID(id) && !ArrayContains(eligibleVehicleIDs, id) {
        ArrayPush(eligibleVehicleIDs, id);
      };
    };

    if hadActivePolicy {
      normalizedTermMonths = previousTermMonths;
      if previousFrequency == 0 || normalizedFrequency == 0 {
        normalizedFrequency = previousFrequency;
      };
    };

    termPremium = this.CalculateVanguardCoverageTermPremiumForMonths(eligibleVehicleIDs, normalizedDeductible, normalizedTermMonths);
    dueNow = this.GetVanguardCoverageDueNowForPendingPremium(termPremium, normalizedFrequency, normalizedTermMonths);
    proratedCredit = this.GetVanguardCoverageProratedCreditForPendingPremium(termPremium, normalizedTermMonths);

    if dueNow > 0 {
      if !this.PlayerCanPay(player, dueNow) {
        return false;
      };

      if !this.m_transactionSystem.RemoveItemByTDBID(player, t"Items.money", dueNow) {
        return false;
      };
    };

    if proratedCredit > 0 {
      this.m_transactionSystem.GiveItem(player, MarketSystem.Money(), proratedCredit);
    };

    if ArraySize(eligibleVehicleIDs) <= 0 {
      ArrayClear(this.m_coverageVehicleIDs);
      this.m_coverageLastTermPremium = 0;
      this.m_coverageLastPaymentAmount = 0;
      this.m_coverageTermStartMinute = 0;
      this.m_coverageTermEndMinute = 0;
      this.m_coverageTermMonths = 6;
      this.m_coveragePolicySerial = 0;
      this.m_coverageAtFaultSurchargeBasisPoints = 0;
      this.m_coverageAtFaultAccidentCount = 0;
      this.m_coverageGoodDriverStartMinute = 0;
      this.m_coverageGoodDriverRewardedTermStartMinute = 0;
      this.m_coverageGoodDriverRewardedStartMinute = 0;
      this.m_coverageGoodDriverRewardedVersion = 0;
      this.m_coverageGoodDriverRefundIssuedThisTerm = false;
      return true;
    };

    ArrayClear(this.m_coverageVehicleIDs);
    for id in eligibleVehicleIDs {
      if TDBID.IsValid(id) && !ArrayContains(this.m_coverageVehicleIDs, id) {
        ArrayPush(this.m_coverageVehicleIDs, id);
      };
    };

    this.m_coverageDeductibleOption = normalizedDeductible;
    this.m_coveragePaymentFrequency = normalizedFrequency;
    this.m_coverageTermMonths = normalizedTermMonths;
    this.m_coverageLastTermPremium = termPremium;
    this.m_coverageLastPaymentAmount = this.GetVanguardCoverageInstallmentAmountForTerm(termPremium, normalizedFrequency, normalizedTermMonths);
    this.EnsureVanguardCoveragePolicyNumber();

    if !hadActivePolicy || this.m_coverageGoodDriverStartMinute <= 0 {
      this.m_coverageGoodDriverStartMinute = now;
    };

    if !hadActivePolicy || this.m_coverageTermEndMinute <= now || previousTermMonths != normalizedTermMonths {
      this.m_coverageTermStartMinute = now;
      this.m_coverageTermEndMinute = now + this.GetVanguardCoverageTermDays(normalizedTermMonths) * 1440;
    };

    if !hadActivePolicy || this.m_coverageTermStartMinute == now {
      this.m_coverageGoodDriverRewardedTermStartMinute = 0;
      this.m_coverageGoodDriverRewardedStartMinute = 0;
      this.m_coverageGoodDriverRewardedVersion = 0;
      this.m_coverageGoodDriverRefundIssuedThisTerm = false;
    };

    return true;
  }

  private func GetOwnedVehiclesDataBase() -> array<ref<AutofixerItemData>> {
    this.ReconcileUninstalledVehicles();
    this.UpdatePendingOrders();
    let result: array<ref<AutofixerItemData>>;
    let playerVehicles: array<PlayerVehicle>;
    let persistentVehicles: array<PlayerVehicle>;
    let seenVehicles: array<TweakDBID>;
    let hasActiveCoveragePolicy: Bool = this.IsVanguardCoverageOperational();
    let activeCoverageIDs: array<TweakDBID>;
    let activeCoverageCanonicalIDs: array<TweakDBID>;
    let vehicleRecord: ref<Vehicle_Record>;
    let vehicleId: TweakDBID;
    let item: ref<AutofixerItemData>;
    let price: Int32;
    let sellPrice: Float;
    let isVanillaVehicle: Bool;

    this.DeactivateSoldVehicles();
    this.m_vehicleSystem.GetPlayerUnlockedVehicles(playerVehicles);
    if hasActiveCoveragePolicy {
      activeCoverageIDs = this.GetVanguardCoverageSelectedVehicleIDs();
      activeCoverageCanonicalIDs = this.GetVanguardCoverageSelectedCanonicalVehicleIDs();
    };

    persistentVehicles = GetPersistentVehicles(this.GetGameInstance());
    for persistentVehicle in persistentVehicles {
      ArrayPush(playerVehicles, persistentVehicle);
    };

    for playerVehicle in playerVehicles {
      if TDBID.IsValid(playerVehicle.recordID) {
        vehicleRecord = TweakDBInterface.GetVehicleRecord(playerVehicle.recordID);
        if IsDefined(vehicleRecord) {
          vehicleId = vehicleRecord.GetID();

          if !ArrayContains(seenVehicles, playerVehicle.recordID) && !ArrayContains(this.m_soldVehicles, playerVehicle.recordID) && !ArrayContains(this.m_soldVehicles, vehicleId) {
            ArrayPush(seenVehicles, playerVehicle.recordID);

            price = TweakDBInterface.GetInt(vehicleId + t".autofixer", 0);
            if Equals(price, 0) {
              isVanillaVehicle = false;
              price = this.FindPriceInBundles(vehicleId);
            } else {
              isVanillaVehicle = true;
            };

            sellPrice = Cast<Float>(price) * this.m_sellPriceModifier;
            item = new AutofixerItemData();
            item.title = GetLocalizedTextByKey(vehicleRecord.DisplayName());
            item.price = Cast<Int32>(sellPrice);
            item.atlasResource = vehicleRecord.Icon().AtlasResourcePath();
            item.textureName = vehicleRecord.Icon().AtlasPartName();
            item.vehicleID = playerVehicle.recordID;
            item.sold = false;
            item.vanilla = isVanillaVehicle;
            item.financeIndex = this.GetFinanceContractIndex(playerVehicle.recordID);
            if item.financeIndex < 0 {
              item.financeIndex = this.GetFinanceContractIndex(vehicleId);
            };
            if item.financeIndex >= 0 {
              item.contractIndex = item.financeIndex + 1;
              item.financeBalance = this.GetFinanceRemainingBalanceByIndex(item.financeIndex);
            } else {
              item.contractIndex = 0;
              item.financeBalance = 0;
            };
            item.financed = item.financeIndex >= 0 && item.financeBalance > 0;
            item.ineligible = this.IsVanguardCoverageVehicleIneligible(playerVehicle.recordID) || this.IsVanguardCoverageVehicleIneligible(vehicleId);
            item.insured = !item.ineligible && hasActiveCoveragePolicy && this.IsVanguardCoverageVehicleInSelectedLists(playerVehicle.recordID, vehicleId, activeCoverageIDs, activeCoverageCanonicalIDs);
            item.repossessed = this.GetFinanceRepossessionIndex(playerVehicle.recordID) >= 0 || this.GetFinanceRepossessionIndex(vehicleId) >= 0;
            item.defaulted = item.repossessed;
            item.totaled = this.IsVanguardCoverageTotalLossLocked(playerVehicle.recordID) || this.IsVanguardCoverageTotalLossLocked(vehicleId);

            item.destroyed = !item.totaled && (this.IsVanguardUninsuredVehicleDestroyed(playerVehicle.recordID) || this.IsVanguardUninsuredVehicleDestroyed(vehicleId));
            if item.destroyed {
              item.scrapValue = this.GetVanguardVehicleScrapPayout(playerVehicle.recordID);
              item.insured = false;
            } else {
              item.scrapValue = 0;
            };
            ArrayPush(result, item);
          };
        };
      };
    };

    for vehicleId in this.m_financeRepossessedVehicleIDs {
      if TDBID.IsValid(vehicleId) && !ArrayContains(seenVehicles, vehicleId) {
        vehicleRecord = TweakDBInterface.GetVehicleRecord(vehicleId);
        if IsDefined(vehicleRecord) {
          price = TweakDBInterface.GetInt(vehicleId + t".autofixer", 0);
          if Equals(price, 0) {
            price = this.FindPriceInBundles(vehicleId);
          };
          sellPrice = Cast<Float>(price) * this.m_sellPriceModifier;
          item = new AutofixerItemData();
          item.title = GetLocalizedTextByKey(vehicleRecord.DisplayName());
          item.price = Cast<Int32>(sellPrice);
          item.atlasResource = vehicleRecord.Icon().AtlasResourcePath();
          item.textureName = vehicleRecord.Icon().AtlasPartName();
          item.vehicleID = vehicleId;
          item.sold = false;
          item.vanilla = false;
          item.financeIndex = this.GetFinanceContractIndex(vehicleId);
          if item.financeIndex >= 0 {
            item.contractIndex = item.financeIndex + 1;
            item.financeBalance = this.GetFinanceRemainingBalanceByIndex(item.financeIndex);
          } else {
            item.contractIndex = 0;
            item.financeBalance = 0;
          };
          item.financed = true;
          item.ineligible = this.IsVanguardCoverageVehicleIneligible(vehicleId);
          item.insured = false;
          item.defaulted = true;
          item.repossessed = true;
          item.totaled = this.IsVanguardCoverageTotalLossLocked(vehicleId);
          item.destroyed = false;
          item.scrapValue = 0;
          ArrayPush(result, item);
        };
      };
    };

    return result;
  }

  public func RemoveRepossessedVehicleFromGarage(player: ref<GameObject>, data: ref<AutofixerItemData>) -> Void {
    let contractID: TweakDBID;
    if !IsDefined(player) || !IsDefined(data) { return; };
    contractID = this.GetFinanceContractIDForTradeInID(data.vehicleID);
    if !this.IsVehicleRepossessed(contractID) && !this.IsVehicleRepossessed(data.vehicleID) { return; };

    this.RemoveRepossessedVehicleFromWorld(data.vehicleID);
    this.m_deactivateVehiclesDirty = true;
  }

  private func SellOwnedVehicleBase(player: ref<GameObject>, data: ref<AutofixerItemData>) -> Void {
    let balance: Int32 = 0;
    let netPayout: Int32 = 0;
    let payout: Int32 = 0;
    let removed: Bool = false;
    let financeContractID: TweakDBID;
    let ownershipExitVehicleIDs: array<TweakDBID>;

    if !IsDefined(player) || !IsDefined(data) {
      return ;
    };

    if ArrayContains(this.m_soldVehicles, data.vehicleID) {
      return ;
    };

    if data.totaled || this.IsVanguardCoverageTotalLossLocked(data.vehicleID) {
      return ;
    };

    if data.destroyed || this.IsVanguardUninsuredVehicleDestroyed(data.vehicleID) {
      return ;
    };

    financeContractID = this.GetFinanceContractIDForTradeInID(data.vehicleID);

    if data.financed && this.GetFinanceRemainingBalance(financeContractID) > 0 {
      return ;
    };

    removed = RemoveVehicle(this.GetGameInstance(), this.m_vehicleSystem, data.vehicleID);
    if !removed {
    };

    if data.financed {
      balance = this.GetFinanceRemainingBalance(financeContractID);
      netPayout = data.price - balance;

      if balance > 0 {
        this.CloseFinanceContractAfterSale(financeContractID, balance);
      };

      if netPayout > 0 {
        payout = netPayout;
      } else {
        payout = 0;
      };
    } else {
      payout = data.price;
    };

    if payout > 0 {
      this.m_transactionSystem.GiveItem(player, MarketSystem.Money(), payout);
    };

    ArrayPush(this.m_soldVehicles, data.vehicleID);
    this.AdvanceSoldVehicleLedgerRevision();
    this.m_deactivateVehiclesDirty = true;
    this.InvalidateNCGTAppreciation(data.vehicleID);
    this.RemoveNCGTPerformancePackageState(data.vehicleID);
    ArrayPush(ownershipExitVehicleIDs, data.vehicleID);
    this.RemoveVanguardCoverageVehiclesAfterOwnershipExit(player as PlayerPuppet, ownershipExitVehicleIDs);
    this.ClearCustomerFollowup(data.vehicleID);
    this.ClearSaleFollowup(data.vehicleID);
    if !this.HasSaleConfirmationPhoneMessage(data.vehicleID) {
      this.PublishPhoneNotificationRecord(3004, data.vehicleID, 0, 0, 0);
    };
    this.m_dealershipSales += 1;
    this.m_lastSaleMinute = this.GetCurrentGameMinute();
  }

  public func ScrapDestroyedVehicle(player: ref<GameObject>, data: ref<AutofixerItemData>) -> Bool {
    let payout: Int32;
    let removed: Bool = false;
    let fraudExcluded: Bool;
    let financeContractID: TweakDBID;
    let ownershipExitVehicleIDs: array<TweakDBID>;

    if !IsDefined(player) || !IsDefined(data) || !TDBID.IsValid(data.vehicleID) || data.sold {
      return false;
    };

    if !this.IsVanguardUninsuredVehicleDestroyed(data.vehicleID) || this.IsVanguardCoverageTotalLossLocked(data.vehicleID) || this.IsVanguardCoverageVehicleSelectedOnPolicyRecord(data.vehicleID) {
      return false;
    };

    fraudExcluded = this.IsVanguardCoverageFraudDestroyedVehicleExcluded(data.vehicleID);

    financeContractID = this.GetFinanceContractIDForTradeInID(data.vehicleID);
    if this.GetFinanceRemainingBalance(financeContractID) > 0 || data.defaulted || data.repossessed {
      return false;
    };

    payout = this.GetVanguardVehicleScrapPayout(data.vehicleID);
    removed = RemoveVehicle(this.GetGameInstance(), this.m_vehicleSystem, data.vehicleID);
    if !removed {
    };

    if payout > 0 {
      this.m_transactionSystem.GiveItem(player, MarketSystem.Money(), payout);
    };

    data.sold = true;
    if !ArrayContains(this.m_soldVehicles, data.vehicleID) {
      ArrayPush(this.m_soldVehicles, data.vehicleID);
      this.AdvanceSoldVehicleLedgerRevision();
    };
    this.m_deactivateVehiclesDirty = true;
    this.InvalidateNCGTAppreciation(data.vehicleID);
    this.RemoveNCGTPerformancePackageState(data.vehicleID);
    this.ClearVanguardUninsuredVehicleDestroyed(data.vehicleID);
    if fraudExcluded {

      this.ClearVanguardCoverageFraudDestroyedVehicleExclusion(data.vehicleID);
      SetFactValue(this.GetGameInstance(), n"vanguard_coverage_redscript_commit_request", 1);
    } else {
      ArrayPush(ownershipExitVehicleIDs, data.vehicleID);
      this.RemoveVanguardCoverageVehiclesAfterOwnershipExit(player as PlayerPuppet, ownershipExitVehicleIDs);
    };
    this.ClearCustomerFollowup(data.vehicleID);
    this.ClearSaleFollowup(data.vehicleID);
    return true;
  }

  public func IsTradeInBonusOfferCode(code: Int32) -> Bool {
    return code == 2;
  }

  public func GetTradeInBonusOfferPercent() -> Int32 {
    return 15;
  }

  public func GetTradeInBonusPercentForOffer(code: Int32, player: ref<PlayerPuppet>) -> Int32 {
    if code == 2 && this.HasGarageVehicleForTradeInOffer(player) {
      return this.GetTradeInBonusOfferPercent();
    };

    return 0;
  }

  public func GetTradeInBonusPercentForSelectedOffer(player: ref<PlayerPuppet>) -> Int32 {
    return this.GetTradeInBonusPercentForOffer(this.GetSelectedPromotionOfferCode(), player);
  }

  public func IsTradeInDataEligible(data: ref<AutofixerItemData>) -> Bool {

    if !IsDefined(data) || data.sold || data.repossessed || data.defaulted || data.destroyed || data.totaled || data.price <= 0 || !TDBID.IsValid(data.vehicleID) {
      return false;
    };

    if this.IsVanguardCoverageTotalLossLocked(data.vehicleID) {
      return false;
    };

    return true;
  }

  public func GetTradeInOfferGarageVehicleCount(player: ref<PlayerPuppet>) -> Int32 {
    let vehicles: array<ref<AutofixerItemData>>;
    let count: Int32 = 0;

    if !IsDefined(player) {
      return 0;
    };

    vehicles = this.GetOwnedVehiclesData();
    for data in vehicles {
      if IsDefined(data) && !data.sold && !data.destroyed && !data.totaled && TDBID.IsValid(data.vehicleID) && !this.IsVanguardCoverageTotalLossLocked(data.vehicleID) {
        count += 1;
      };
    };

    return count;
  }

  public func HasGarageVehicleForTradeInOffer(player: ref<PlayerPuppet>) -> Bool {
    return this.GetTradeInOfferGarageVehicleCount(player) > 0;
  }

  public func GetEligibleTradeInVehicleCount(player: ref<PlayerPuppet>) -> Int32 {
    let vehicles: array<ref<AutofixerItemData>>;
    let count: Int32 = 0;

    if !IsDefined(player) {
      return 0;
    };

    vehicles = this.GetOwnedVehiclesData();
    for data in vehicles {
      if this.IsTradeInDataEligible(data) {
        count += 1;
      };
    };

    return count;
  }

  public func GetTradeInBaseValueByVehicleID(id: TweakDBID) -> Int32 {
    let vehicles: array<ref<AutofixerItemData>> = this.GetOwnedVehiclesData();

    if !TDBID.IsValid(id) || ArrayContains(this.m_soldVehicles, id) {
      return 0;
    };

    for data in vehicles {
      if IsDefined(data) && Equals(data.vehicleID, id) {
        if this.IsTradeInDataEligible(data) {
          return data.price;
        };
        return 0;
      };
    };

    return 0;
  }

  public func CalculateSelectedTradeInBaseValue(vehicleIDs: array<TweakDBID>) -> Int32 {
    let applied: array<TweakDBID>;
    let value: Int32 = 0;
    let currentValue: Int32;

    for id in vehicleIDs {
      if TDBID.IsValid(id) && !ArrayContains(applied, id) {
        currentValue = this.GetTradeInBaseValueByVehicleID(id);
        if currentValue > 0 {
          value += currentValue;
        };
        ArrayPush(applied, id);
      };
    };

    return value;
  }

  public func CalculateSelectedTradeInBonusValue(vehicleIDs: array<TweakDBID>, bonusPercent: Int32) -> Int32 {
    let baseValue: Int32;

    if bonusPercent <= 0 {
      return 0;
    };

    baseValue = this.CalculateSelectedTradeInBaseValue(vehicleIDs);
    if baseValue <= 0 {
      return 0;
    };

    return (baseValue * bonusPercent) / 100;
  }

  public func CalculateSelectedTradeInTotalValue(vehicleIDs: array<TweakDBID>, bonusPercent: Int32) -> Int32 {
    return this.CalculateSelectedTradeInBaseValue(vehicleIDs) + this.CalculateSelectedTradeInBonusValue(vehicleIDs, bonusPercent);
  }

  public func GetTradeInBoostedValueByVehicleID(id: TweakDBID, bonusPercent: Int32) -> Int32 {
    let baseValue: Int32 = this.GetTradeInBaseValueByVehicleID(id);
    let bonusValue: Int32 = 0;

    if baseValue <= 0 {
      return 0;
    };

    if bonusPercent > 0 {
      bonusValue = (baseValue * bonusPercent) / 100;
    };

    return baseValue + bonusValue;
  }

  public func HasSelectedFinancedTradeIn(vehicleIDs: array<TweakDBID>) -> Bool {
    let applied: array<TweakDBID>;

    for id in vehicleIDs {
      if TDBID.IsValid(id) && !ArrayContains(applied, id) {
        if this.IsTradeInVehicleFinanced(id) {
          return true;
        };
        ArrayPush(applied, id);
      };
    };

    return false;
  }

  public func GetSelectedFinancedTradeInCount(vehicleIDs: array<TweakDBID>) -> Int32 {
    let applied: array<TweakDBID>;
    let count: Int32 = 0;

    for id in vehicleIDs {
      if TDBID.IsValid(id) && !ArrayContains(applied, id) {
        if this.IsTradeInVehicleFinanced(id) {
          count += 1;
        };
        ArrayPush(applied, id);
      };
    };

    return count;
  }

  public func CalculateSelectedTradeInPayoffAmount(vehicleIDs: array<TweakDBID>) -> Int32 {
    let applied: array<TweakDBID>;
    let totalPayoff: Int32 = 0;
    let balance: Int32;

    for id in vehicleIDs {
      if TDBID.IsValid(id) && !ArrayContains(applied, id) {
        balance = this.GetTradeInFinanceRemainingBalance(id);
        if balance > 0 {
          totalPayoff += balance;
        };
        ArrayPush(applied, id);
      };
    };

    return totalPayoff;
  }

  public func CalculateSelectedTradeInPositiveEquity(vehicleIDs: array<TweakDBID>, bonusPercent: Int32) -> Int32 {
    let applied: array<TweakDBID>;
    let totalEquity: Int32 = 0;
    let appraisedValue: Int32;
    let payoffAmount: Int32;
    let equity: Int32;

    for id in vehicleIDs {
      if TDBID.IsValid(id) && !ArrayContains(applied, id) {
        appraisedValue = this.GetTradeInBoostedValueByVehicleID(id, bonusPercent);
        payoffAmount = this.GetTradeInFinanceRemainingBalance(id);
        equity = appraisedValue - payoffAmount;
        if equity > 0 {
          totalEquity += equity;
        };
        ArrayPush(applied, id);
      };
    };

    return totalEquity;
  }

  public func CalculateSelectedTradeInNegativeEquity(vehicleIDs: array<TweakDBID>, bonusPercent: Int32) -> Int32 {
    let applied: array<TweakDBID>;
    let totalNegativeEquity: Int32 = 0;
    let appraisedValue: Int32;
    let payoffAmount: Int32;
    let negativeEquity: Int32;

    for id in vehicleIDs {
      if TDBID.IsValid(id) && !ArrayContains(applied, id) {
        appraisedValue = this.GetTradeInBoostedValueByVehicleID(id, bonusPercent);
        payoffAmount = this.GetTradeInFinanceRemainingBalance(id);
        negativeEquity = payoffAmount - appraisedValue;
        if negativeEquity > 0 {
          totalNegativeEquity += negativeEquity;
        };
        ArrayPush(applied, id);
      };
    };

    return totalNegativeEquity;
  }

  public func CanUseTradeInsForCashPurchase(vehicleIDs: array<TweakDBID>) -> Bool {
    return !this.HasSelectedFinancedTradeIn(vehicleIDs);
  }

  public func GetEffectiveActiveFinanceContractCountAfterTradeIn(vehicleIDs: array<TweakDBID>) -> Int32 {
    let count: Int32 = this.GetActiveFinanceContractCount();
    let settledCount: Int32 = this.GetSelectedFinancedTradeInCount(vehicleIDs);

    count -= settledCount;
    if count < 0 {
      return 0;
    };

    return count;
  }
  public func HasAvailableAutoFinanceSlotAfterTradeIn(vehicleIDs: array<TweakDBID>) -> Bool {
    return this.GetEffectiveActiveFinanceContractCountAfterTradeIn(vehicleIDs) < this.GetMaxActiveAutoFinanceContracts();
  }

  public func GetFinanceAdjustedPriceAfterTradeIn(finalPrice: Int32, tradeInCredit: Int32) -> Int32 {
    let adjustedPrice: Int32 = finalPrice - tradeInCredit;

    if finalPrice <= 1 {
      return 1;
    };

    if adjustedPrice < 1 {
      return 1;
    };

    return adjustedPrice;
  }

  public func GetFinanceRemainingTradeCreditAfterPrice(finalPrice: Int32, tradeInCredit: Int32) -> Int32 {
    let maxAppliedToPrice: Int32 = finalPrice - 1;
    let appliedToPrice: Int32 = tradeInCredit;

    if tradeInCredit <= 0 || finalPrice <= 1 {
      return 0;
    };

    if appliedToPrice > maxAppliedToPrice {
      appliedToPrice = maxAppliedToPrice;
    };

    if appliedToPrice < 0 {
      appliedToPrice = 0;
    };

    return Max(0, tradeInCredit - appliedToPrice);
  }

  public func GetFinanceAdjustedPriceAfterTradeInAndNegativeEquity(finalPrice: Int32, tradeInCredit: Int32, negativeEquity: Int32) -> Int32 {
    let financedBase: Int32 = finalPrice + negativeEquity;
    let adjustedPrice: Int32 = financedBase - tradeInCredit;

    if financedBase <= 1 {
      return 1;
    };

    if adjustedPrice < 1 {
      return 1;
    };

    return adjustedPrice;
  }

  public func GetFinanceRemainingTradeCreditAfterPriceAndNegativeEquity(finalPrice: Int32, tradeInCredit: Int32, negativeEquity: Int32) -> Int32 {
    let financedBase: Int32 = finalPrice + negativeEquity;
    let maxAppliedToPrice: Int32 = financedBase - 1;
    let appliedToPrice: Int32 = tradeInCredit;

    if tradeInCredit <= 0 || financedBase <= 1 {
      return 0;
    };

    if appliedToPrice > maxAppliedToPrice {
      appliedToPrice = maxAppliedToPrice;
    };

    if appliedToPrice < 0 {
      appliedToPrice = 0;
    };

    return Max(0, tradeInCredit - appliedToPrice);
  }

  public func GetFinanceNetDueTodayAfterTradeInAndNegativeEquity(finalPrice: Int32, requestedDownPayment: Int32, player: ref<PlayerPuppet>, tradeInCredit: Int32, negativeEquity: Int32) -> Int32 {
    let adjustedPrice: Int32 = this.GetFinanceAdjustedPriceAfterTradeInAndNegativeEquity(finalPrice, tradeInCredit, negativeEquity);
    let downPayment: Int32 = this.ClampFinanceDownPaymentForPlayer(adjustedPrice, requestedDownPayment, player);
    let grossDueToday: Int32 = this.GetFinanceDueTodayWithDownPayment(adjustedPrice, downPayment);
    let remainingTradeCredit: Int32 = this.GetFinanceRemainingTradeCreditAfterPriceAndNegativeEquity(finalPrice, tradeInCredit, negativeEquity);
    let netDue: Int32 = grossDueToday - remainingTradeCredit;

    if netDue < 0 {
      return 0;
    };

    return netDue;
  }

  public func GetFinanceTradeInOverageWithNegativeEquity(finalPrice: Int32, requestedDownPayment: Int32, player: ref<PlayerPuppet>, tradeInCredit: Int32, negativeEquity: Int32) -> Int32 {
    let adjustedPrice: Int32 = this.GetFinanceAdjustedPriceAfterTradeInAndNegativeEquity(finalPrice, tradeInCredit, negativeEquity);
    let downPayment: Int32 = this.ClampFinanceDownPaymentForPlayer(adjustedPrice, requestedDownPayment, player);
    let grossDueToday: Int32 = this.GetFinanceDueTodayWithDownPayment(adjustedPrice, downPayment);
    let remainingTradeCredit: Int32 = this.GetFinanceRemainingTradeCreditAfterPriceAndNegativeEquity(finalPrice, tradeInCredit, negativeEquity);
    let overage: Int32 = remainingTradeCredit - grossDueToday;

    if overage < 0 {
      return 0;
    };

    return overage;
  }

  public func GetFinanceNetDueTodayAfterTradeIn(finalPrice: Int32, requestedDownPayment: Int32, player: ref<PlayerPuppet>, tradeInCredit: Int32) -> Int32 {
    let adjustedPrice: Int32 = this.GetFinanceAdjustedPriceAfterTradeIn(finalPrice, tradeInCredit);
    let downPayment: Int32 = this.ClampFinanceDownPaymentForPlayer(adjustedPrice, requestedDownPayment, player);
    let grossDueToday: Int32 = this.GetFinanceDueTodayWithDownPayment(adjustedPrice, downPayment);
    let remainingTradeCredit: Int32 = this.GetFinanceRemainingTradeCreditAfterPrice(finalPrice, tradeInCredit);
    let netDue: Int32 = grossDueToday - remainingTradeCredit;

    if netDue < 0 {
      return 0;
    };

    return netDue;
  }

  public func GetFinanceTradeInOverage(finalPrice: Int32, requestedDownPayment: Int32, player: ref<PlayerPuppet>, tradeInCredit: Int32) -> Int32 {
    let adjustedPrice: Int32 = this.GetFinanceAdjustedPriceAfterTradeIn(finalPrice, tradeInCredit);
    let downPayment: Int32 = this.ClampFinanceDownPaymentForPlayer(adjustedPrice, requestedDownPayment, player);
    let grossDueToday: Int32 = this.GetFinanceDueTodayWithDownPayment(adjustedPrice, downPayment);
    let remainingTradeCredit: Int32 = this.GetFinanceRemainingTradeCreditAfterPrice(finalPrice, tradeInCredit);
    let overage: Int32 = remainingTradeCredit - grossDueToday;

    if overage < 0 {
      return 0;
    };

    return overage;
  }

  private func ApplyTradeInVehiclesWithoutPayout(player: ref<PlayerPuppet>, vehicleIDs: array<TweakDBID>) -> Int32 {
    let applied: array<TweakDBID>;
    let ownershipExitVehicleIDs: array<TweakDBID>;
    let appliedCount: Int32 = 0;
    let vehicles: array<ref<AutofixerItemData>>;
    let removed: Bool = false;

    if !IsDefined(player) { return 0; };
    if this.HasSelectedFinancedTradeIn(vehicleIDs) && !this.IsMarmurBankAutoFinanceAvailable() { return 0; };

    vehicles = this.GetOwnedVehiclesData();
    for id in vehicleIDs {
      if TDBID.IsValid(id) && !ArrayContains(applied, id) {
        for data in vehicles {
          if IsDefined(data) && Equals(data.vehicleID, id) && this.IsTradeInDataEligible(data) {
            if this.IsTradeInVehicleFinanced(data.vehicleID) {
              let financeContractID: TweakDBID = this.GetFinanceContractIDForTradeInID(data.vehicleID);
              let payoffAmount: Int32 = this.GetFinanceRemainingBalance(financeContractID);
              if payoffAmount > 0 {
                if !this.CloseFinanceContractAfterSale(financeContractID, payoffAmount) { return appliedCount; };
              } else {
                this.RemoveFinanceContractSilent(financeContractID);
              };
            };
            removed = RemoveVehicle(this.GetGameInstance(), this.m_vehicleSystem, data.vehicleID);
            if !removed {
            };
            if !ArrayContains(this.m_soldVehicles, data.vehicleID) {
              ArrayPush(this.m_soldVehicles, data.vehicleID);
              this.AdvanceSoldVehicleLedgerRevision();
              this.m_deactivateVehiclesDirty = true;
            };
            this.InvalidateNCGTAppreciation(data.vehicleID);
            this.RemoveNCGTPerformancePackageState(data.vehicleID);
            ArrayPush(ownershipExitVehicleIDs, data.vehicleID);
            appliedCount += 1;
          };
        };
        ArrayPush(applied, id);
      };
    };

    if appliedCount > 0 {
      this.RemoveVanguardCoverageVehiclesAfterOwnershipExit(player, ownershipExitVehicleIDs);
      SyncPersistentVehicles(this.GetGameInstance());
    };

    return appliedCount;
  }

  public func PurchaseVehicleWithTradeIn(id: TweakDBID, finalPrice: Int32, mode: Int32, player: ref<PlayerPuppet>, tradeInVehicleIDs: array<TweakDBID>, tradeInBonusPercent: Int32) -> Bool {
    let purchaseTotal: Int32 = this.GetVehiclePurchaseTotal(finalPrice);
    let tradeInCredit: Int32 = this.CalculateSelectedTradeInTotalValue(tradeInVehicleIDs, tradeInBonusPercent);
    let netDue: Int32 = purchaseTotal - tradeInCredit;
    let overage: Int32 = tradeInCredit - purchaseTotal;
    let purchaseMode: Int32 = mode;

    if !this.IsInstalledVehicleRecord(id)
      || !this.IsPurchasable(id)
      || this.IsSeparatePurchased(id)
      || finalPrice <= 0
      || !IsDefined(player) {
      return false;
    };

    if !this.CanUseTradeInsForCashPurchase(tradeInVehicleIDs) {
      return false;
    };

    if netDue < 0 {
      netDue = 0;
    };

    if overage < 0 {
      overage = 0;
    };

    if netDue > 0 && !this.PlayerCanPay(player, netDue) {
      return false;
    };

    if netDue > 0 {
      if !this.m_transactionSystem.RemoveItemByTDBID(player, t"Items.money", netDue) {
        return false;
      };
    };

    if this.CalculateSelectedTradeInBaseValue(tradeInVehicleIDs) > 0 {
      this.ApplyTradeInVehiclesWithoutPayout(player, tradeInVehicleIDs);
    };

    if overage > 0 {
      this.m_transactionSystem.GiveItem(player, MarketSystem.Money(), overage);
    };

    this.Purchase(id);
    this.IssueNCGTAppreciationVoucher(id, finalPrice, false);
    this.ScheduleCustomerFollowup(id, purchaseMode, this.GetCustomerCareFollowupDelayMinutes());
    return true;
  }

  public func PurchaseVehicleWithTradeInAndPerformancePackage(
    id: TweakDBID,
    finalPrice: Int32,
    mode: Int32,
    player: ref<PlayerPuppet>,
    tradeInVehicleIDs: array<TweakDBID>,
    tradeInBonusPercent: Int32,
    vehicleClass: Int32,
    packageCode: Int32,
    packagePaymentMode: Int32
  ) -> Bool {
    let packageTotal: Int32 = this.GetNCGTPerformancePackageFinalTotal(vehicleClass, packageCode, finalPrice);
    let purchaseTotal: Int32 = this.GetVehiclePurchaseTotal(finalPrice) + packageTotal;
    let tradeInCredit: Int32 = this.CalculateSelectedTradeInTotalValue(tradeInVehicleIDs, tradeInBonusPercent);
    let netDue: Int32 = purchaseTotal - tradeInCredit;
    let overage: Int32 = tradeInCredit - purchaseTotal;
    let purchaseMode: Int32 = mode;

    if !this.IsInstalledVehicleRecord(id)
      || !this.IsPurchasable(id)
      || this.IsSeparatePurchased(id)
      || finalPrice <= 0
      || !IsDefined(player)
      || !this.IsNCGTPerformancePackageQuoteValid(id, vehicleClass, packageCode, finalPrice)
      || packageTotal <= 0
      || packagePaymentMode != 1
      || !this.IsNCGTPerformancePackageIntegrationAvailable() {
      return false;
    };

    if !this.CanUseTradeInsForCashPurchase(tradeInVehicleIDs) {
      return false;
    };

    if netDue < 0 {
      netDue = 0;
    };

    if overage < 0 {
      overage = 0;
    };

    if netDue > 0 && !this.PlayerCanPay(player, netDue) {
      return false;
    };

    if netDue > 0 {
      if !this.m_transactionSystem.RemoveItemByTDBID(player, t"Items.money", netDue) {
        return false;
      };
    };

    if this.CalculateSelectedTradeInBaseValue(tradeInVehicleIDs) > 0 {
      this.ApplyTradeInVehiclesWithoutPayout(player, tradeInVehicleIDs);
    };

    if overage > 0 {
      this.m_transactionSystem.GiveItem(player, MarketSystem.Money(), overage);
    };

    this.Purchase(id);
    if !this.RecordPendingNCGTPerformancePackage(
      id,
      vehicleClass,
      packageCode,
      finalPrice,
      1,
      false,
      packageTotal,
      0,
      0,
      0
    ) {

      this.m_transactionSystem.GiveItem(player, MarketSystem.Money(), packageTotal);
      if this.IssueNCGTAppreciationVoucher(id, finalPrice, false) {
        this.QueueNCGTAppreciationVoucherNotice(id);
      };
    };
    this.ScheduleCustomerFollowup(id, purchaseMode, this.GetCustomerCareFollowupDelayMinutes());
    return true;
  }

  public func StartFinancingWithCustomDownPaymentAutoPayOptionsAndTradeIn(id: TweakDBID, finalPrice: Int32, termMonths: Int32, player: ref<PlayerPuppet>, autoPayEnabled: Bool, paymentFrequency: Int32, requestedDownPayment: Int32, tradeInVehicleIDs: array<TweakDBID>, tradeInBonusPercent: Int32) -> Bool {
    return this.StartFinancingWithCustomDownPaymentAutoPaySourceOptionsAndTradeIn(id, finalPrice, termMonths, player, autoPayEnabled, paymentFrequency, 1, requestedDownPayment, tradeInVehicleIDs, tradeInBonusPercent);
  }
  public func StartFinancingWithCustomDownPaymentAutoPaySourceOptionsAndTradeIn(id: TweakDBID, finalPrice: Int32, termMonths: Int32, player: ref<PlayerPuppet>, autoPayEnabled: Bool, paymentFrequency: Int32, paymentSource: Int32, requestedDownPayment: Int32, tradeInVehicleIDs: array<TweakDBID>, tradeInBonusPercent: Int32) -> Bool {
    let normalizedTerm: Int32 = this.NormalizeFinanceTerm(termMonths);
    let normalizedFrequency: Int32 = this.NormalizeFinancePaymentFrequency(paymentFrequency);
    let normalizedPaymentSource: Int32 = this.NormalizeFinancePaymentSource(paymentSource);
    let tradeInCredit: Int32 = this.CalculateSelectedTradeInPositiveEquity(tradeInVehicleIDs, tradeInBonusPercent);
    let negativeEquity: Int32 = this.CalculateSelectedTradeInNegativeEquity(tradeInVehicleIDs, tradeInBonusPercent);
    let adjustedPrice: Int32 = this.GetFinanceAdjustedPriceAfterTradeInAndNegativeEquity(finalPrice, tradeInCredit, negativeEquity);
    let downPayment: Int32;
    let dueToday: Int32;
    let overage: Int32;
    let totalDue: Int32;
    let monthlyPayment: Int32;
    let interestBasisPoints: Int32;

    if !this.IsInstalledVehicleRecord(id)
      || !this.IsPurchasable(id)
      || !IsDefined(player)
      || finalPrice <= 0
      || this.IsSeparatePurchased(id)
      || this.IsVehicleFinanced(id)
      || normalizedTerm <= 0 {
      return false;
    };

    if !this.HasSelectedFinancedTradeIn(tradeInVehicleIDs) && tradeInCredit >= this.GetVehiclePurchaseTotal(finalPrice) {
      return this.PurchaseVehicleWithTradeIn(id, finalPrice, 1, player, tradeInVehicleIDs, tradeInBonusPercent);
    };

    if !this.IsMarmurFinancialCreditAvailable() {
      this.PublishPhoneNotificationRecord(3010, id, adjustedPrice, 4, this.GetActiveFinanceContractCount());
      return false;
    };

    if normalizedPaymentSource == 2 && !this.IsMarmurBankSavingsPaymentSourceAvailable() {
      return false;
    };

    if !this.HasAvailableAutoFinanceSlotAfterTradeIn(tradeInVehicleIDs) {
      this.QueueAutoFinanceDenialNotice(id, adjustedPrice, 3);
      return false;
    };

    downPayment = this.ClampFinanceDownPaymentForPlayer(adjustedPrice, requestedDownPayment, player);
    dueToday = this.GetFinanceNetDueTodayAfterTradeInAndNegativeEquity(finalPrice, requestedDownPayment, player, tradeInCredit, negativeEquity);
    overage = this.GetFinanceTradeInOverageWithNegativeEquity(finalPrice, requestedDownPayment, player, tradeInCredit, negativeEquity);

    if !this.CanFinanceVehicleForPlayerWithDownPaymentAfterTradeIn(adjustedPrice, player, downPayment, tradeInVehicleIDs) {
      if dueToday > 0 && !this.PlayerCanPay(player, dueToday) {
        this.QueueAutoFinanceDenialNotice(id, adjustedPrice, 2);
      } else {
        this.QueueAutoFinanceDenialNotice(id, adjustedPrice, 1);
      };
      return false;
    };

    if dueToday > 0 {
      if dueToday > 0 && !this.DebitVanguardCreditWallet(player, dueToday) {
        this.QueueAutoFinanceDenialNotice(id, adjustedPrice, 2);
        return false;
      };
    };

    if this.CalculateSelectedTradeInBaseValue(tradeInVehicleIDs) > 0 {
      this.ApplyTradeInVehiclesWithoutPayout(player, tradeInVehicleIDs);
    };

    if overage > 0 {
      this.m_transactionSystem.GiveItem(player, MarketSystem.Money(), overage);
    };

    totalDue = this.GetFinanceTotalDueWithDownPayment(adjustedPrice, normalizedTerm, player, downPayment);
    monthlyPayment = this.GetFinanceMonthlyPaymentWithDownPayment(adjustedPrice, normalizedTerm, player, downPayment);
    interestBasisPoints = this.GetFinanceInterestBasisPoints(normalizedTerm, player);

    this.Purchase(id);

    ArrayPush(this.m_financeVehicleIDs, id);
    ArrayPush(this.m_financeTerms, normalizedTerm);
    ArrayPush(this.m_financeMonthlyPayments, monthlyPayment);
    ArrayPush(this.m_financeRemainingMonths, normalizedTerm);
    ArrayPush(this.m_financeNextPaymentMinutes, this.GetCurrentGameMinute() + 43200);
    ArrayPush(this.m_financeTotalDue, totalDue);
    ArrayPush(this.m_financeDownPayments, downPayment);
    ArrayPush(this.m_financeInterestPercents, interestBasisPoints);
    ArrayPush(this.m_financePaidAmounts, 0);
    this.AssignNewFinanceContractSerial(id);
    this.m_financeContractsDirty = true;

    this.ClearFinanceDefaultState(id);
    this.ClearFinanceRepossessionState(id);
    this.SetFinancePaymentFrequency(id, normalizedFrequency);
    if !this.SetFinancePaymentSource(id, normalizedPaymentSource) {
      return false;
    };

    this.SetFinanceAutoPayEnabled(id, autoPayEnabled);
    this.IssueNCGTAppreciationVoucher(id, finalPrice, true);

    this.ScheduleCustomerFollowup(id, 1, this.GetCustomerCareFollowupDelayMinutes());
    this.QueuePurchaseConfirmation(id, dueToday, true);
    this.PushFinanceEvent(id, 1, dueToday, normalizedTerm, normalizedTerm, monthlyPayment);
    this.RegisterVanguardCreditContract(id, false);
    this.QueueVanguardCreditApplication();
    this.PublishMarmurBankAutoLoanApprovalNotice(id);
    this.QueueNCGTAppreciationVoucherNotice(id);
    return true;
  }

  public func StartFinancingWithCustomDownPaymentAutoPayOptionsTradeInAndPerformancePackage(
    id: TweakDBID,
    finalPrice: Int32,
    termMonths: Int32,
    player: ref<PlayerPuppet>,
    autoPayEnabled: Bool,
    paymentFrequency: Int32,
    requestedDownPayment: Int32,
    tradeInVehicleIDs: array<TweakDBID>,
    tradeInBonusPercent: Int32,
    vehicleClass: Int32,
    packageCode: Int32,
    packagePaymentMode: Int32
  ) -> Bool {
    return this.StartFinancingWithCustomDownPaymentAutoPaySourceOptionsTradeInAndPerformancePackage(
      id,
      finalPrice,
      termMonths,
      player,
      autoPayEnabled,
      paymentFrequency,
      1,
      requestedDownPayment,
      tradeInVehicleIDs,
      tradeInBonusPercent,
      vehicleClass,
      packageCode,
      packagePaymentMode
    );
  }
  public func StartFinancingWithCustomDownPaymentAutoPaySourceOptionsTradeInAndPerformancePackage(
    id: TweakDBID,
    finalPrice: Int32,
    termMonths: Int32,
    player: ref<PlayerPuppet>,
    autoPayEnabled: Bool,
    paymentFrequency: Int32,
    paymentSource: Int32,
    requestedDownPayment: Int32,
    tradeInVehicleIDs: array<TweakDBID>,
    tradeInBonusPercent: Int32,
    vehicleClass: Int32,
    packageCode: Int32,
    packagePaymentMode: Int32
  ) -> Bool {
    let normalizedTerm: Int32 = this.NormalizeFinanceTerm(termMonths);
    let normalizedFrequency: Int32 = this.NormalizeFinancePaymentFrequency(paymentFrequency);
    let normalizedPaymentSource: Int32 = this.NormalizeFinancePaymentSource(paymentSource);
    let packageTotal: Int32 = this.GetNCGTPerformancePackageFinalTotal(vehicleClass, packageCode, finalPrice);
    let financePrice: Int32 = finalPrice;
    let tradeInCredit: Int32 = this.CalculateSelectedTradeInPositiveEquity(tradeInVehicleIDs, tradeInBonusPercent);
    let negativeEquity: Int32 = this.CalculateSelectedTradeInNegativeEquity(tradeInVehicleIDs, tradeInBonusPercent);
    let adjustedPrice: Int32;
    let baselineAdjustedPrice: Int32;
    let downPayment: Int32;
    let baselineDownPayment: Int32;
    let dueToday: Int32;
    let baselineDueToday: Int32;
    let packageDueToday: Int32;
    let overage: Int32;
    let baselineOverage: Int32;
    let totalDue: Int32;
    let baselineTotalDue: Int32;
    let monthlyPayment: Int32;
    let baselineMonthlyPayment: Int32;
    let interestBasisPoints: Int32;
    let financeIndex: Int32;
    let rollbackRefund: Int32;

    if !this.IsInstalledVehicleRecord(id)
      || !this.IsPurchasable(id)
      || this.IsSeparatePurchased(id)
      || this.IsVehicleFinanced(id)
      || normalizedTerm <= 0
      || !IsDefined(player)
      || finalPrice <= 0
      || !this.IsNCGTPerformancePackageQuoteValid(id, vehicleClass, packageCode, finalPrice)
      || packageTotal <= 0
      || (packagePaymentMode != 1 && packagePaymentMode != 2)
      || !this.IsNCGTPerformancePackageIntegrationAvailable() {
      return false;
    };

    if packagePaymentMode == 2 {
      financePrice += packageTotal;
    } else {
      packageDueToday = packageTotal;
    };

    if !this.HasSelectedFinancedTradeIn(tradeInVehicleIDs)
      && tradeInCredit >= this.GetVehiclePurchaseTotal(financePrice) + packageDueToday {
      return this.PurchaseVehicleWithTradeInAndPerformancePackage(
        id,
        finalPrice,
        1,
        player,
        tradeInVehicleIDs,
        tradeInBonusPercent,
        vehicleClass,
        packageCode,
        1
      );
    };

    adjustedPrice = this.GetFinanceAdjustedPriceAfterTradeInAndNegativeEquity(financePrice, tradeInCredit, negativeEquity);
    baselineAdjustedPrice = this.GetFinanceAdjustedPriceAfterTradeInAndNegativeEquity(finalPrice, tradeInCredit, negativeEquity);

    if !this.IsMarmurFinancialCreditAvailable() {
      this.PublishPhoneNotificationRecord(3010, id, adjustedPrice, 4, this.GetActiveFinanceContractCount());
      return false;
    };

    if normalizedPaymentSource == 2 && !this.IsMarmurBankSavingsPaymentSourceAvailable() {
      return false;
    };

    if !this.HasAvailableAutoFinanceSlotAfterTradeIn(tradeInVehicleIDs) {
      this.QueueAutoFinanceDenialNotice(id, adjustedPrice, 3);
      return false;
    };

    downPayment = this.ClampFinanceDownPaymentForPlayer(adjustedPrice, requestedDownPayment, player);
    baselineDownPayment = this.ClampFinanceDownPaymentForPlayer(baselineAdjustedPrice, requestedDownPayment, player);
    dueToday = this.GetFinanceNetDueTodayAfterTradeInAndNegativeEquity(financePrice, requestedDownPayment, player, tradeInCredit, negativeEquity);
    baselineDueToday = this.GetFinanceNetDueTodayAfterTradeInAndNegativeEquity(finalPrice, requestedDownPayment, player, tradeInCredit, negativeEquity);
    dueToday += packageDueToday;
    overage = this.GetFinanceTradeInOverageWithNegativeEquity(financePrice, requestedDownPayment, player, tradeInCredit, negativeEquity);
    baselineOverage = this.GetFinanceTradeInOverageWithNegativeEquity(finalPrice, requestedDownPayment, player, tradeInCredit, negativeEquity);

    if !this.CanFinanceVehicleForPlayerWithDownPaymentAfterTradeIn(adjustedPrice, player, downPayment, tradeInVehicleIDs) {
      if dueToday > 0 && !this.PlayerCanPay(player, dueToday) {
        this.QueueAutoFinanceDenialNotice(id, adjustedPrice, 2);
      } else {
        this.QueueAutoFinanceDenialNotice(id, adjustedPrice, 1);
      };
      return false;
    };

    if dueToday > 0 {
      if !this.PlayerCanPay(player, dueToday)
        || !this.DebitVanguardCreditWallet(player, dueToday) {
        this.QueueAutoFinanceDenialNotice(id, adjustedPrice, 2);
        return false;
      };
    };

    if this.CalculateSelectedTradeInBaseValue(tradeInVehicleIDs) > 0 {
      this.ApplyTradeInVehiclesWithoutPayout(player, tradeInVehicleIDs);
    };

    if overage > 0 {
      this.m_transactionSystem.GiveItem(player, MarketSystem.Money(), overage);
    };

    totalDue = this.GetFinanceTotalDueWithDownPayment(adjustedPrice, normalizedTerm, player, downPayment);
    monthlyPayment = this.GetFinanceMonthlyPaymentWithDownPayment(adjustedPrice, normalizedTerm, player, downPayment);
    baselineTotalDue = this.GetFinanceTotalDueWithDownPayment(baselineAdjustedPrice, normalizedTerm, player, baselineDownPayment);
    baselineMonthlyPayment = this.GetFinanceMonthlyPaymentWithDownPayment(baselineAdjustedPrice, normalizedTerm, player, baselineDownPayment);
    interestBasisPoints = this.GetFinanceInterestBasisPoints(normalizedTerm, player);

    this.Purchase(id);

    ArrayPush(this.m_financeVehicleIDs, id);
    ArrayPush(this.m_financeTerms, normalizedTerm);
    ArrayPush(this.m_financeMonthlyPayments, monthlyPayment);
    ArrayPush(this.m_financeRemainingMonths, normalizedTerm);
    ArrayPush(this.m_financeNextPaymentMinutes, this.GetCurrentGameMinute() + 43200);
    ArrayPush(this.m_financeTotalDue, totalDue);
    ArrayPush(this.m_financeDownPayments, downPayment);
    ArrayPush(this.m_financeInterestPercents, interestBasisPoints);
    ArrayPush(this.m_financePaidAmounts, 0);
    this.AssignNewFinanceContractSerial(id);
    this.m_financeContractsDirty = true;

    this.ClearFinanceDefaultState(id);
    this.ClearFinanceRepossessionState(id);
    this.SetFinancePaymentFrequency(id, normalizedFrequency);
    if !this.SetFinancePaymentSource(id, normalizedPaymentSource) {
      return false;
    };
    this.SetFinanceAutoPayEnabled(id, autoPayEnabled);

    if packagePaymentMode == 1 {
      rollbackRefund = packageTotal;
    } else {
      rollbackRefund = Max(0, dueToday - baselineDueToday) + Max(0, baselineOverage - overage);
    };

    if !this.RecordPendingNCGTPerformancePackage(
      id,
      vehicleClass,
      packageCode,
      finalPrice,
      packagePaymentMode,
      true,
      rollbackRefund,
      baselineTotalDue,
      baselineMonthlyPayment,
      baselineDownPayment
    ) {
      financeIndex = this.GetFinanceContractIndex(id);
      if packagePaymentMode == 2 && financeIndex >= 0 {
        this.m_financeTotalDue[financeIndex] = baselineTotalDue;
        this.m_financeMonthlyPayments[financeIndex] = baselineMonthlyPayment;
        this.m_financeDownPayments[financeIndex] = baselineDownPayment;
        this.m_financeContractsDirty = true;
      };
      if rollbackRefund > 0 {
        this.m_transactionSystem.GiveItem(player, MarketSystem.Money(), rollbackRefund);
      };
      if this.IssueNCGTAppreciationVoucher(id, finalPrice, true) {
        this.QueueNCGTAppreciationVoucherNotice(id);
      };
    };

    this.ScheduleCustomerFollowup(id, 1, this.GetCustomerCareFollowupDelayMinutes());
    this.QueuePurchaseConfirmation(id, dueToday, true);
    this.PushFinanceEvent(id, 1, dueToday, normalizedTerm, normalizedTerm, monthlyPayment);
    this.RegisterVanguardCreditContract(id, false);
    this.QueueVanguardCreditApplication();
    this.PublishMarmurBankAutoLoanApprovalNotice(id);
    return true;
  }

  private func GetCurrentGameMinute() -> Int32 {
    let timeSystem: ref<TimeSystem> = GameInstance.GetTimeSystem(this.GetGameInstance());
    let gameTime: GameTime;

    if !IsDefined(timeSystem) {
      return 0;
    };

    gameTime = timeSystem.GetGameTime();
    return GameTime.Days(gameTime) * 1440 + GameTime.Hours(gameTime) * 60 + GameTime.Minutes(gameTime);
  }

  private func GetTDBIDs(items: array<String>) -> array<TweakDBID> {
    let result: array<TweakDBID>;
    for item in items {
      ArrayPush(result, TDBID.Create(item));
    };
    return result;
  }

  private func IsSeparatePurchased(id: TweakDBID) -> Bool {
    let unlockedVehicles: array<PlayerVehicle>;
    this.m_vehicleSystem.GetPlayerUnlockedVehicles(unlockedVehicles);
    for vehicle in unlockedVehicles {
      if Equals(vehicle.recordID, id) {
        return true;
      };
    };
    return CheckIfVehicleIsPersistent(this.GetGameInstance(), id);
  }

  private func GetVehicleBasePrice(id: TweakDBID) -> Int32 {
    let price: Int32 = TweakDBInterface.GetInt(id + t".autofixer", 0);

    if Equals(price, 0) {
      return this.FindPriceInBundles(id);
    };

    return price;
  }

  private func FindPriceInBundles(id: TweakDBID) -> Int32 {
    let currentBundle: ref<PurchasableVehicleBundle>;
    let currentVariant: ref<PurchasableVehicleVariant>;
    let targetBundle: ref<PurchasableVehicleBundle>;

    let i: Int32 = 0;
    let j: Int32;
    let bundleFound: Bool = false;
    while i < ArraySize(this.m_storeVehicles) && !bundleFound {
      currentBundle = this.m_storeVehicles[i];
      j = 0;
      while j < ArraySize(currentBundle.variants)  && !bundleFound {
        currentVariant = currentBundle.variants[j];
        if Equals(currentVariant.record.GetID(), id) {
          targetBundle = currentBundle;
          bundleFound = true;
        };
        j += 1;
      };
      i += 1;
    };

    if bundleFound {
      return targetBundle.price;
    };

    return this.m_fallbackPrice;
  }

  public func GetDealershipPurchaseCount() -> Int32 {
    return this.m_dealershipPurchases;
  }

  public func GetDealershipSaleCount() -> Int32 {
    return this.m_dealershipSales;
  }

  public func GetVehicleDiscountPercent(id: TweakDBID, player: ref<PlayerPuppet>) -> Int32 {
    let basePrice: Int32 = this.GetVehicleBasePrice(id);
    let discountAmount: Int32 = this.GetVehicleDiscountAmount(id, player);

    if basePrice <= 0 || discountAmount <= 0 {
      return 0;
    };

    return Max(1, (discountAmount * 100 + basePrice - 1) / basePrice);
  }

  public func GetVehicleDiscountAmount(id: TweakDBID, player: ref<PlayerPuppet>) -> Int32 {
    return this.GetVehicleDiscountAmountForCheckout(id, player, false);
  }

  public func GetVehicleDiscountAmountForCheckout(id: TweakDBID, player: ref<PlayerPuppet>, financeCheckout: Bool) -> Int32 {
    let basePrice: Int32 = this.GetVehicleBasePrice(id);
    let code: Int32 = this.ResolveVehiclePromotionCode(id, player, basePrice);
    let amount: Int32;

    if !this.IsPromotionOfferEligibleForCheckout(code, financeCheckout) {
      return 0;
    };

    amount = this.GetPromotionDiscountAmountForCode(code, basePrice, player);

    if amount >= basePrice {
      return Max(0, basePrice - 1);
    };

    return Max(0, amount);
  }

  public func GetVehicleFinalPrice(id: TweakDBID, player: ref<PlayerPuppet>) -> Int32 {
    return this.GetVehicleFinalPriceForCheckout(id, player, false);
  }

  public func GetVehicleFinalPriceForCheckout(id: TweakDBID, player: ref<PlayerPuppet>, financeCheckout: Bool) -> Int32 {
    let finalPrice: Int32 = this.GetVehicleBasePrice(id) - this.GetVehicleDiscountAmountForCheckout(id, player, financeCheckout);
    if finalPrice < 1 {
      return 1;
    };

    return finalPrice;
  }

  public func HasVehicleDiscount(id: TweakDBID, player: ref<PlayerPuppet>) -> Bool {
    return this.GetVehicleDiscountAmount(id, player) > 0;
  }

  public func GetVehiclePromotionCode(id: TweakDBID, player: ref<PlayerPuppet>) -> Int32 {
    return this.ResolveVehiclePromotionCode(id, player, this.GetVehicleBasePrice(id));
  }

  public func GetVehiclePromotionLabel(id: TweakDBID, player: ref<PlayerPuppet>) -> String {
    return this.GetPromotionLabelByCode(this.GetVehiclePromotionCode(id, player));
  }

  public func GetActiveCampaignCode() -> Int32 {
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    return this.ResolveCurrentCampaignCode(player);
  }

  public func GetActiveCampaignMinutesRemaining() -> Int32 {
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    let code: Int32 = this.ResolveCurrentCampaignCode(player);
    return this.GetCampaignMinutesRemaining(code);
  }

  public func GetActiveCampaignHeadline() -> String {
    return this.GetCampaignHeadlineByCode(this.GetActiveCampaignCode());
  }

  public func GetActiveCampaignBody() -> String {
    return this.GetCampaignBodyByCode(this.GetActiveCampaignCode());
  }

  public func GetActiveCampaignSignature() -> String {
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    let code: Int32 = this.ResolveCurrentCampaignCode(player);
    let remaining: Int32 = this.GetCampaignMinutesRemaining(code);
    return s"\(code)|\(remaining / 120)|\(this.m_dealershipPurchases)|\(this.m_dealershipSales)";
  }

  private func ResolveVehiclePromotionCode(id: TweakDBID, player: ref<PlayerPuppet>, basePrice: Int32) -> Int32 {
    let selectedCode: Int32 = this.GetSelectedPromotionOfferCode();

    if selectedCode > 0 {
      if this.IsPromotionVehicleEligibleForCodeAndVehicle(selectedCode, id, basePrice, player) {
        return selectedCode;
      };
      return 0;
    };

    return 0;
  }

  public func GetPromotionDisplayCodeAt(slot: Int32, player: ref<PlayerPuppet>) -> Int32 {
    let now: Int32 = this.GetCurrentGameMinute();

    if slot <= 0 {
      if this.m_dealershipPurchases <= 0 {
        return 1;
      };
      if this.GetPromotionDiscountAmountForCode(11, 125000, player) > 0 {
        return 11;
      };
      return 6;
    };

    if slot == 1 {
      return 2;
    };

    if this.GetPromotionDiscountAmountForCode(12, 125000, player) > 0 {
      return 12;
    };
    if this.GetPromotionDiscountAmountForCode(9, 125000, player) > 0 {
      return 9;
    };
    if this.GetPromotionDiscountAmountForCode(4, 125000, player) > 0 {
      return 4;
    };
    if this.IsFlagshipEventWindow(now) {
      return 7;
    };

    return 5;
  }

  public func GetPromotionOfferCatalogCreditAmount(code: Int32, player: ref<PlayerPuppet>) -> Int32 {

    switch code {
      case 1:
        return 5000;
      case 2:
        return 15;
      case 3:
        return 15000;
      case 4:
        return 7500;
      case 5:
        return 20000;
      case 6:
        return 7500;
      case 7:
        return 30000;
      case 9:
        return 15000;
      case 10:
        return 15000;
      case 11:
        return 25000;
      case 12:
        return 35000;
      case 13:
        return 10000;
      case 14:
        return 5000;
      case 15:
        return 7500;
    };

    return 0;
  }

  private func ShouldPromotionFilterCandidateReplace(filterMode: Int32, bestCode: Int32, candidateCode: Int32, player: ref<PlayerPuppet>) -> Bool {
    let bestAmount: Int32;
    let candidateAmount: Int32;

    if bestCode <= 0 {
      return true;
    };

    switch filterMode {
      case 2:
        bestAmount = this.GetPromotionOfferCatalogCreditAmount(bestCode, player);
        candidateAmount = this.GetPromotionOfferCatalogCreditAmount(candidateCode, player);
        if candidateAmount != bestAmount {
          return candidateAmount < bestAmount;
        };
        return candidateCode < bestCode;
      case 3:
        bestAmount = this.GetPromotionOfferCatalogCreditAmount(bestCode, player);
        candidateAmount = this.GetPromotionOfferCatalogCreditAmount(candidateCode, player);
        if candidateAmount != bestAmount {
          return candidateAmount > bestAmount;
        };
        return candidateCode > bestCode;
      case 4:
        return candidateCode > bestCode;
      case 5:
        return candidateCode < bestCode;
    };

    return candidateCode < bestCode;
  }

  public func GetPromotionFilteredDisplayCodeAt(slot: Int32, filterMode: Int32, player: ref<PlayerPuppet>) -> Int32 {
    let selectedCodes: array<Int32>;
    let pass: Int32 = 0;
    let candidateCode: Int32;
    let bestCode: Int32;

    if slot < 0 || slot > 14 {
      return 0;
    };

    if filterMode <= 1 {
      if slot > 2 {
        return 0;
      };
      return this.GetPromotionDisplayCodeAt(slot, player);
    };

    while pass <= slot {
      bestCode = 0;
      candidateCode = 1;

      while candidateCode <= 15 {

        if !ArrayContains(selectedCodes, candidateCode)
          && !(candidateCode == 8 && !this.IsMarmurBankAutoFinanceAvailable())
          && !((filterMode == 2 || filterMode == 3) && candidateCode == 8) {
          if this.ShouldPromotionFilterCandidateReplace(filterMode, bestCode, candidateCode, player) {
            bestCode = candidateCode;
          };
        };

        candidateCode += 1;
      };

      if bestCode <= 0 {
        return 0;
      };

      ArrayPush(selectedCodes, bestCode);
      pass += 1;
    };

    return bestCode;
  }

  public func EnsureSelectedPromotionOffer(player: ref<PlayerPuppet>) -> Void {
    let selectedCode: Int32 = this.m_selectedPromotionCode;

    if this.IsPromotionFinanceOnly(selectedCode) && !this.IsMarmurBankAutoFinanceAvailable() {
      this.m_selectedPromotionCode = 0;
      return ;
    };

    if selectedCode >= 1 && selectedCode <= 15 {
      return ;
    };

    this.m_selectedPromotionCode = 0;
  }

  public func SelectPromotionOffer(code: Int32) -> Void {
    if code >= 1 && code <= 15
      && !(this.IsPromotionFinanceOnly(code) && !this.IsMarmurBankAutoFinanceAvailable()) {
      this.m_selectedPromotionCode = code;
    } else {
      this.m_selectedPromotionCode = 0;
    };
  }

  public func GetSelectedPromotionOfferCode() -> Int32 {
    if this.m_selectedPromotionCode >= 1 && this.m_selectedPromotionCode <= 15
      && !(this.IsPromotionFinanceOnly(this.m_selectedPromotionCode) && !this.IsMarmurFinancialCreditAvailable()) {
      return this.m_selectedPromotionCode;
    };

    return 0;
  }

  public func GetPromotionOfferHeadline(code: Int32) -> String {
    let headline: String = this.GetCampaignHeadlineByCode(code);
    if NotEquals(headline, "") {
      return headline;
    };

    return VanguardAutoLocalization.Text(1796, "No promotion selected.");
  }

  public func GetPromotionOfferCardTitle(code: Int32) -> String {
    switch code {
      case 1:
        return VanguardAutoLocalization.Text(1797, "New Customer Cash");
      case 2:
        return VanguardAutoLocalization.Text(1798, "Trade-In Value Bonus");
      case 3:
        return VanguardAutoLocalization.Text(1799, "Dealer Cash Allowance");
      case 4:
        return VanguardAutoLocalization.Text(1800, "End-of-Sales-Week Cash");
      case 5:
        return this.GetInventorySpotlightCardTitle();
      case 6:
        return VanguardAutoLocalization.Text(1801, "Owner Loyalty Cash");
      case 7:
        return VanguardAutoLocalization.Text(1802, "Premium Model Cash Allowance");
      case 8:
        return VanguardAutoLocalization.Text(1803, "Preferred Finance Rate");
      case 9:
        return VanguardAutoLocalization.Text(1804, "Garage Conquest Cash");
      case 10:
        return VanguardAutoLocalization.Text(1805, "Weekend Sales Event Cash");
      case 11:
        return VanguardAutoLocalization.Text(1806, "Repeat Buyer Bonus");
      case 12:
        return VanguardAutoLocalization.Text(1807, "Model-Year Closeout Cash");
      case 13:
        return VanguardAutoLocalization.Text(2033, "Cash Buyer Rebate");
      case 14:
        return VanguardAutoLocalization.Text(2034, "Rider Rebate");
      case 15:
        return VanguardAutoLocalization.Text(2035, "Utility Work Credit");
    };

    return VanguardAutoLocalization.Text(1808, "No Promotion Selected");
  }

  public func GetPromotionOfferBody(code: Int32) -> String {
    let body: String = this.GetCampaignBodyByCode(code);
    if NotEquals(body, "") {
      return body;
    };

    return VanguardAutoLocalization.Text(1809, "Select one available offer to apply dealership pricing rules to qualifying inventory.");
  }

  public func GetPromotionOfferPreviewAmount(code: Int32, player: ref<PlayerPuppet>) -> Int32 {
    let previewBasePrice: Int32 = 125000;

    switch code {
      case 5:
        previewBasePrice = this.GetInventorySpotlightPreviewPrice(this.GetCurrentGameMinute());
        break;
      case 7:
        previewBasePrice = 1200000;
        break;
      case 9:
        previewBasePrice = 125000;
        break;
      case 12:
        previewBasePrice = 125000;
        break;
    };

    return this.GetPromotionDiscountAmountForCode(code, previewBasePrice, player);
  }

  public func IsPromotionOfferAvailable(code: Int32, player: ref<PlayerPuppet>) -> Bool {
    if code == 2 {
      return this.HasGarageVehicleForTradeInOffer(player);
    };

    if code == 8 {
      return this.IsMarmurFinancialCreditAvailable()
        && this.GetFinancialCreditScore(player) >= 740
        && this.m_marmurCreditBaseDecision == 0
        && this.IsPreferredFinanceEventWindow(this.GetCurrentGameMinute());
    };

    return this.GetPromotionOfferPreviewAmount(code, player) > 0;
  }

  public func IsPromotionFinanceOnly(code: Int32) -> Bool {
    return code == 8;
  }

  public func IsPromotionCashOnly(code: Int32) -> Bool {
    return code == 13;
  }

  public func IsPromotionOfferEligibleForCheckout(code: Int32, financeCheckout: Bool) -> Bool {
    if this.IsPromotionFinanceOnly(code) {
      return financeCheckout;
    };

    if this.IsPromotionCashOnly(code) {
      return !financeCheckout;
    };

    return true;
  }

  public func HasPromotionEligibleInventory(code: Int32, player: ref<PlayerPuppet>) -> Bool {
    let variantIndex: Int32;

    if !this.IsPromotionOfferAvailable(code, player) {
      return false;
    };

    if code == 2 {
      for bundle in this.m_storeVehicles {
        variantIndex = 0;
        while variantIndex < ArraySize(bundle.variants) {
          if !this.IsPurchased(bundle.variants[variantIndex].record.GetID()) {
            return true;
          };
          variantIndex += 1;
        };
      };
      return false;
    };

    for bundle in this.m_storeVehicles {
      variantIndex = 0;
      while variantIndex < ArraySize(bundle.variants) {
        if !this.IsPurchased(bundle.variants[variantIndex].record.GetID())
          && this.IsPromotionVehicleEligibleForCodeAndVehicle(code, bundle.variants[variantIndex].record.GetID(), bundle.price, player) {
          return true;
        };
        variantIndex += 1;
      };
    };

    return false;
  }

  public func GetPromotionVehicleCreditForCode(code: Int32, basePrice: Int32, player: ref<PlayerPuppet>) -> Int32 {

    if code == 2 || code == 8 || code == 14 || code == 15 {
      return 0;
    };

    return Max(0, this.GetPromotionDiscountAmountForCode(code, basePrice, player));
  }

  public func GetPromotionVehicleCreditForCodeAndVehicle(code: Int32, id: TweakDBID, basePrice: Int32, player: ref<PlayerPuppet>) -> Int32 {
    if code == 2 || code == 8
      || !this.IsPromotionVehicleEligibleForCodeAndVehicle(code, id, basePrice, player) {
      return 0;
    };

    return Max(0, this.GetPromotionDiscountAmountForCode(code, basePrice, player));
  }

  public func IsPromotionVehicleEligibleForCode(code: Int32, basePrice: Int32, player: ref<PlayerPuppet>) -> Bool {

    if code == 14 || code == 15 {
      return false;
    };

    if code == 2 || code == 8 {
      return this.IsPromotionOfferAvailable(code, player);
    };

    return this.GetPromotionDiscountAmountForCode(code, basePrice, player) > 0;
  }

  public func IsPromotionVehicleEligibleForCodeAndVehicle(code: Int32, id: TweakDBID, basePrice: Int32, player: ref<PlayerPuppet>) -> Bool {
    let vehicleClass: Int32;

    if !TDBID.IsValid(id) || !this.IsPromotionOfferAvailable(code, player) {
      return false;
    };

    if code == 14 || code == 15 {
      vehicleClass = this.ResolveNCGTPerformanceVehicleClass(id);
      if code == 14 && vehicleClass != 3 {
        return false;
      };
      if code == 15 && vehicleClass != 2 {
        return false;
      };
    };

    if code == 2 || code == 8 {
      return true;
    };

    return this.GetPromotionDiscountAmountForCode(code, basePrice, player) > 0;
  }

  public func GetPromotionOfferDisplayValue(code: Int32, player: ref<PlayerPuppet>) -> String {
    let amount: Int32;

    if code == 2 {
      return VanguardAutoLocalization.Text1(1810, s"+\(this.GetTradeInBonusOfferPercent())% TRADE-IN", s"\(this.GetTradeInBonusOfferPercent())");
    };

    if code == 8 {
      return "2.99% APR";
    };

    amount = this.GetPromotionOfferPreviewAmount(code, player);
    if amount > 0 {
      return VanguardAutoLocalization.Text1(1811, s"\(this.FormatMoney(amount)) CREDIT", s"\(this.FormatMoney(amount))");
    };

    amount = this.GetPromotionOfferCatalogCreditAmount(code, player);
    if amount > 0 {
      return VanguardAutoLocalization.Text1(1812, s"UP TO \(this.FormatMoney(amount)) CREDIT", s"\(this.FormatMoney(amount))");
    };

    return VanguardAutoLocalization.Text(1813, "QUALIFICATION REQUIRED");
  }

  public func GetPromotionOfferPreviewPercent(code: Int32, player: ref<PlayerPuppet>) -> Int32 {
    let previewBasePrice: Int32 = 125000;
    let amount: Int32;

    if code == 2 {
      return this.GetTradeInBonusOfferPercent();
    };

    if code == 5 {
      previewBasePrice = this.GetInventorySpotlightPreviewPrice(this.GetCurrentGameMinute());
    } else {
      if code == 7 {
        previewBasePrice = 1200000;
      } else {
        if code == 9 {
          previewBasePrice = 125000;
        } else {
          if code == 12 {
            previewBasePrice = 125000;
          };
        };
      };
    };

    amount = this.GetPromotionDiscountAmountForCode(code, previewBasePrice, player);
    if amount <= 0 {
      return 0;
    };

    return Max(1, (amount * 100 + previewBasePrice - 1) / previewBasePrice);
  }

  public func GetPromotionOfferMinutesRemaining(code: Int32) -> Int32 {
    return this.GetCampaignMinutesRemaining(code);
  }

  private func ResolveCurrentCampaignCode(player: ref<PlayerPuppet>) -> Int32 {
    let now: Int32 = this.GetCurrentGameMinute();

    if this.HasGarageVehicleForTradeInOffer(player) {
      return 2;
    };

    if this.GetPromotionDiscountAmountForCode(4, 125000, player) > 0 {
      return 4;
    };

    if this.GetPromotionDiscountAmountForCode(10, 125000, player) > 0 {
      return 10;
    };

    if this.GetPromotionDiscountAmountForCode(12, 125000, player) > 0 {
      return 12;
    };

    if this.GetPromotionDiscountAmountForCode(9, 125000, player) > 0 {
      return 9;
    };

    if this.GetPromotionDiscountAmountForCode(11, 125000, player) > 0 {
      return 11;
    };

    if this.IsFlagshipEventWindow(now) && this.GetPromotionDiscountAmountForCode(7, 1200000, player) > 0 {
      return 7;
    };

    if this.GetPromotionDiscountAmountForCode(5, this.GetInventorySpotlightPreviewPrice(now), player) > 0 {
      return 5;
    };

    if this.GetPromotionDiscountAmountForCode(1, 125000, player) > 0 {
      return 1;
    };

    if this.GetPromotionDiscountAmountForCode(6, 125000, player) > 0 {
      return 6;
    };

    if this.IsPreferredFinanceEventWindow(now) {
      return 8;
    };

    return 3;
  }

  private func GetPromotionDiscountAmountForCode(code: Int32, basePrice: Int32, player: ref<PlayerPuppet>) -> Int32 {
    let now: Int32 = this.GetCurrentGameMinute();
    let spotlightTier: Int32 = this.GetInventorySpotlightTier(now);
    let minutesSinceSale: Int32;

    if basePrice <= 0 {
      return 0;
    };

    switch code {
      case 1:
        if Equals(this.m_dealershipPurchases, 0) {
          return this.ClampPromotionCashCredit(5000, basePrice);
        };
        return 0;
      case 2:
        return 0;
      case 3:
        if this.IsPreferredFinanceEventWindow(now) {
          return 0;
        };
        return this.ClampPromotionCashCredit(this.GetDailyDealerSpecialAmount(now), basePrice);
      case 4:
        if this.IsMonthEndSalesEventWindow(now) {
          return this.ClampPromotionCashCredit(7500, basePrice);
        };
        return 0;
      case 5:
        if spotlightTier == 0 {
          if basePrice <= 250000 {
            return this.ClampPromotionCashCredit(5000, basePrice);
          };
          return 0;
        };
        if spotlightTier == 1 {
          if basePrice > 250000 && basePrice <= 750000 {
            return this.ClampPromotionCashCredit(10000, basePrice);
          };
          return 0;
        };
        if basePrice > 750000 {
          return this.ClampPromotionCashCredit(20000, basePrice);
        };
        return 0;
      case 6:
        if this.m_dealershipPurchases >= 1 {
          return this.ClampPromotionCashCredit(7500, basePrice);
        };
        return 0;
      case 7:
        if !this.IsFlagshipEventWindow(now) {
          return 0;
        };
        if basePrice > 1000000 {
          return this.ClampPromotionCashCredit(30000, basePrice);
        };
        return 0;
      case 8:
        return 0;
      case 9:
        return this.ClampPromotionCashCredit(this.GetConquestCashAmount(player, basePrice), basePrice);
      case 10:
        return this.ClampPromotionCashCredit(this.GetWeekendSalesEventCashAmount(now), basePrice);
      case 11:
        return this.ClampPromotionCashCredit(this.GetRepeatBuyerBonusAmount(), basePrice);
      case 12:
        if this.IsModelYearCloseoutWindow(now) {
          return this.ClampPromotionCashCredit(this.GetModelYearCloseoutAmount(basePrice), basePrice);
        };
        return 0;
      case 13:
        return this.ClampPromotionCashCredit(10000, basePrice);
      case 14:
        return this.ClampPromotionCashCredit(5000, basePrice);
      case 15:
        return this.ClampPromotionCashCredit(7500, basePrice);
    };

    return 0;
  }

  private func ClampPromotionCashCredit(amount: Int32, basePrice: Int32) -> Int32 {
    let cap: Int32;

    if amount <= 0 || basePrice <= 0 {
      return 0;
    };

    cap = (basePrice * 12) / 100;
    if cap < 2500 {
      cap = 2500;
    };

    if amount > cap {
      amount = cap;
    };

    if amount >= basePrice {
      return Max(0, basePrice - 1);
    };

    return amount;
  }

  private func GetPromotionPercentForCode(code: Int32, basePrice: Int32, player: ref<PlayerPuppet>) -> Int32 {
    let amount: Int32 = this.GetPromotionDiscountAmountForCode(code, basePrice, player);

    if basePrice <= 0 || amount <= 0 {
      return 0;
    };

    return Max(1, (amount * 100 + basePrice - 1) / basePrice);
  }

  private func GetPromotionLabelByCode(code: Int32) -> String {
    switch code {
      case 1:
        return VanguardAutoLocalization.Text(1814, "New customer cash");
      case 2:
        return VanguardAutoLocalization.Text(1815, "Trade-in value bonus");
      case 3:
        return VanguardAutoLocalization.Text(1816, "Dealer cash allowance");
      case 4:
        return VanguardAutoLocalization.Text(1817, "End-of-sales-week cash");
      case 5:
        return VanguardAutoLocalization.Text(1818, "Inventory allowance");
      case 6:
        return VanguardAutoLocalization.Text(1819, "Owner loyalty cash");
      case 7:
        return VanguardAutoLocalization.Text(1820, "Premium model cash allowance");
      case 8:
        return VanguardAutoLocalization.Text(1821, "Preferred 2.99% APR");
      case 9:
        return VanguardAutoLocalization.Text(1822, "Garage conquest cash");
      case 10:
        return VanguardAutoLocalization.Text(1823, "Weekend sales event cash");
      case 11:
        return VanguardAutoLocalization.Text(1824, "Repeat buyer bonus");
      case 12:
        return VanguardAutoLocalization.Text(1825, "Model-year closeout cash");
      case 13:
        return VanguardAutoLocalization.Text(2036, "Cash buyer rebate");
      case 14:
        return VanguardAutoLocalization.Text(2037, "Rider rebate");
      case 15:
        return VanguardAutoLocalization.Text(2038, "Utility work credit");
    };

    return "";
  }

  private func GetCampaignHeadlineByCode(code: Int32) -> String {
    switch code {
      case 1:
        return VanguardAutoLocalization.Text(1826, "New customer cash is currently available.");
      case 2:
        return VanguardAutoLocalization.Text(1827, "Trade-in value bonus is currently available.");
      case 3:
        return this.GetDailyDealerSpecialHeadline();
      case 4:
        return VanguardAutoLocalization.Text(1828, "End-of-sales-week cash is currently active.");
      case 5:
        return this.GetInventorySpotlightHeadline();
      case 6:
        return VanguardAutoLocalization.Text(1829, "Owner loyalty cash is currently active.");
      case 7:
        return VanguardAutoLocalization.Text(1830, "Premium model cash allowance is currently available.");
      case 8:
        return VanguardAutoLocalization.Text(1831, "Preferred 2.99% APR financing is currently available.");
      case 9:
        return VanguardAutoLocalization.Text(1832, "Garage conquest cash is currently available.");
      case 10:
        return VanguardAutoLocalization.Text(1833, "Weekend sales event cash is currently active.");
      case 11:
        return VanguardAutoLocalization.Text(1834, "Repeat buyer bonus is currently available.");
      case 12:
        return VanguardAutoLocalization.Text(1835, "Model-year closeout cash is currently available.");
      case 13:
        return VanguardAutoLocalization.Text(2039, "Cash buyer rebate is currently available.");
      case 14:
        return VanguardAutoLocalization.Text(2040, "Rider rebate is currently available on motorcycles.");
      case 15:
        return VanguardAutoLocalization.Text(2041, "Utility work credit is currently available on trucks.");
    };

    return "";
  }

  private func GetCampaignBodyByCode(code: Int32) -> String {
    switch code {
      case 1:
        return VanguardAutoLocalization.Text(1836, "New Vanguard customers receive €$5,000 customer cash on eligible inventory. No background or role requirement.");
      case 2:
        return VanguardAutoLocalization.Text(1837, "Customers with a vehicle in their garage can stage an eligible trade-in during checkout and receive an extra 15% toward the purchase of another vehicle. Any overage pays directly to the wallet.");
      case 3:
        return VanguardAutoLocalization.Text(1838, "Dealer cash rotates between €$10,000 and €$15,000. On alternate cycles, the daily special becomes a 2.99% APR finance offer.");
      case 4:
        return VanguardAutoLocalization.Text(1839, "Eligible vehicles receive €$7,500 in end-of-sales-week bonus cash until the current sales window closes.");
      case 5:
        return this.GetInventorySpotlightBody();
      case 6:
        return VanguardAutoLocalization.Text(1840, "Returning customers receive a €$7,500 owner loyalty credit on eligible inventory.");
      case 7:
        return VanguardAutoLocalization.Text(1841, "Premium vehicles priced above €$1,000,000 receive a €$30,000 model cash allowance.");
      case 8:
        return VanguardAutoLocalization.Text(1842, "Qualified purchases receive 2.99% APR for the 60-month Vanguard finance contract. Finance checkout only.");
      case 9:
        return VanguardAutoLocalization.Text(1843, "New Vanguard customers with an existing garage vehicle can receive conquest cash on eligible inventory. Trade-in is not required.");
      case 10:
        return VanguardAutoLocalization.Text(1844, "Weekend sales event cash updates automatically while the weekend sales window is active.");
      case 11:
        return VanguardAutoLocalization.Text(1845, "Customers with three or more Vanguard purchases receive a repeat buyer bonus that grows with purchase history.");
      case 12:
        return VanguardAutoLocalization.Text(1846, "Eligible vehicles receive model-year closeout cash during periodic closeout windows. Amount varies by price tier.");
      case 13:
        return VanguardAutoLocalization.Text(2042, "Eligible full-payment purchases receive a €$10,000 cash buyer rebate. Financing does not qualify.");
      case 14:
        return VanguardAutoLocalization.Text(2043, "Eligible motorcycles receive a €$5,000 rider rebate.");
      case 15:
        return VanguardAutoLocalization.Text(2044, "Eligible trucks receive a €$7,500 utility work credit.");
    };

    return "";
  }

  private func GetCampaignMinutesRemaining(code: Int32) -> Int32 {
    let now: Int32 = this.GetCurrentGameMinute();
    let dayMinute: Int32 = now - (now / 1440) * 1440;

    switch code {
      case 2:
        return 0;
      case 3:
        return 1440 - dayMinute;
      case 8:
        return 1440 - dayMinute;
      case 9:
        return 0;
      case 10:
        if this.IsWeekendSalesEventWindow(now) {
          return 360 - (dayMinute - (dayMinute / 360) * 360);
        };
        return 0;
      case 11:
        return 0;
      case 12:
        if this.IsModelYearCloseoutWindow(now) {
          return 1440 - dayMinute;
        };
        return 0;
      case 4:
        if this.IsMonthEndSalesEventWindow(now) {
          return 1440 - dayMinute;
        };
        return 0;
      case 5:
        return 2880 - (now - (now / 2880) * 2880);
      case 7:
        if this.IsFlagshipEventWindow(now) {
          return 1440 - dayMinute;
        };
        return 0;
    };

    return 0;
  }

  private func GetDailyDealerSpecialAmount(now: Int32) -> Int32 {
    let phase: Int32 = (now / 1440) % 3;

    if phase == 0 {
      return 10000;
    };
    if phase == 1 {
      return 0;
    };
    return 15000;
  }

  private func IsPreferredFinanceEventWindow(now: Int32) -> Bool {
    return (now / 1440) % 3 == 1;
  }

  private func GetDailyDealerSpecialPercent(now: Int32) -> Int32 {
    let amount: Int32 = this.GetDailyDealerSpecialAmount(now);
    return Max(1, (amount * 100 + 250000) / 250001);
  }

  private func GetDailyDealerSpecialHeadline() -> String {
    let now: Int32 = this.GetCurrentGameMinute();
    let amount: Int32 = this.GetDailyDealerSpecialAmount(now);

    if this.IsPreferredFinanceEventWindow(now) {
      return VanguardAutoLocalization.Text(1847, "Preferred financing: 2.99% APR for 60 months.");
    };

    return VanguardAutoLocalization.Text1(1848, s"Dealer cash allowance: \(this.FormatMoney(amount)) purchase credit on eligible inventory.", s"\(this.FormatMoney(amount))");
  }

  private func GetInventorySpotlightTier(now: Int32) -> Int32 {
    return (now / 2880) % 3;
  }

  private func GetInventorySpotlightPreviewPrice(now: Int32) -> Int32 {
    let tier: Int32 = this.GetInventorySpotlightTier(now);

    if tier == 0 {
      return 150000;
    };
    if tier == 1 {
      return 600000;
    };
    return 1200000;
  }

  private func GetInventorySpotlightHeadline() -> String {
    let tier: Int32 = this.GetInventorySpotlightTier(this.GetCurrentGameMinute());

    if tier == 0 {
      return VanguardAutoLocalization.Text(1849, "Entry inventory overstock allowance is now active.");
    };
    if tier == 1 {
      return VanguardAutoLocalization.Text(1850, "Mid-tier inventory overstock allowance is now active.");
    };
    return VanguardAutoLocalization.Text(1851, "Premium inventory overstock allowance is now active.");
  }

  private func GetInventorySpotlightCardTitle() -> String {
    let tier: Int32 = this.GetInventorySpotlightTier(this.GetCurrentGameMinute());

    if tier == 0 {
      return VanguardAutoLocalization.Text(1852, "Entry Overstock Cash");
    };
    if tier == 1 {
      return VanguardAutoLocalization.Text(1853, "Mid-Tier Overstock Cash");
    };
    return VanguardAutoLocalization.Text(1854, "Premium Overstock Cash");
  }

  private func GetInventorySpotlightBody() -> String {
    let tier: Int32 = this.GetInventorySpotlightTier(this.GetCurrentGameMinute());

    if tier == 0 {
      return VanguardAutoLocalization.Text(1855, "Entry inventory priced up to €$250,000 receives €$5,000 overstock cash during this 48-hour rotation.");
    };
    if tier == 1 {
      return VanguardAutoLocalization.Text(1856, "Mid-tier inventory priced above €$250,000 and up to €$750,000 receives €$10,000 overstock cash during this 48-hour rotation.");
    };
    return VanguardAutoLocalization.Text(1857, "Premium inventory priced above €$750,000 receives €$20,000 overstock cash during this 48-hour rotation.");
  }

  private func IsFlagshipEventWindow(now: Int32) -> Bool {
    return (now / 1440) % 4 == 3;
  }

  private func IsMonthEndSalesEventWindow(now: Int32) -> Bool {
    return this.GetDayOfWeek(now) == 6;
  }

  private func IsWeekendSalesEventWindow(now: Int32) -> Bool {
    let day: Int32 = this.GetDayOfWeek(now);
    return day == 5 || day == 6;
  }

  private func IsModelYearCloseoutWindow(now: Int32) -> Bool {
    return (now / 1440) % 5 == 4;
  }

  private func HasConquestEligibleGarageVehicle(player: ref<PlayerPuppet>) -> Bool {
    let playerVehicles: array<PlayerVehicle>;
    let persistentVehicles: array<PlayerVehicle>;
    let vehicleId: TweakDBID;

    if this.m_dealershipPurchases > 0 {
      return false;
    };

    if !IsDefined(player) {
      return false;
    };

    this.m_vehicleSystem.GetPlayerUnlockedVehicles(playerVehicles);
    persistentVehicles = GetPersistentVehicles(this.GetGameInstance());
    for persistentVehicle in persistentVehicles {
      ArrayPush(playerVehicles, persistentVehicle);
    };

    for playerVehicle in playerVehicles {
      vehicleId = playerVehicle.recordID;
      if TDBID.IsValid(vehicleId) && !ArrayContains(this.m_soldVehicles, vehicleId) {
        return true;
      };
    };

    return false;
  }

  private func GetConquestCashAmount(player: ref<PlayerPuppet>, basePrice: Int32) -> Int32 {
    if !this.HasConquestEligibleGarageVehicle(player) {
      return 0;
    };

    if basePrice > 1000000 {
      return 15000;
    };

    if basePrice > 500000 {
      return 10000;
    };

    return 5000;
  }

  private func GetWeekendSalesEventCashAmount(now: Int32) -> Int32 {
    let dayMinute: Int32;
    let eventBucket: Int32;

    if !this.IsWeekendSalesEventWindow(now) {
      return 0;
    };

    dayMinute = now - (now / 1440) * 1440;
    eventBucket = (dayMinute / 360) % 4;

    if eventBucket == 0 {
      return 7500;
    };
    if eventBucket == 1 {
      return 10000;
    };
    if eventBucket == 2 {
      return 12500;
    };

    return 15000;
  }

  private func GetRepeatBuyerBonusAmount() -> Int32 {
    let amount: Int32;

    if this.m_dealershipPurchases < 3 {
      return 0;
    };

    amount = 10000 + ((this.m_dealershipPurchases - 3) * 2500);
    if amount > 25000 {
      return 25000;
    };

    return amount;
  }

  private func GetModelYearCloseoutAmount(basePrice: Int32) -> Int32 {
    if basePrice <= 250000 {
      return 7500;
    };

    if basePrice <= 750000 {
      return 15000;
    };

    if basePrice <= 1000000 {
      return 20000;
    };

    return 35000;
  }

  private func GetPlayerStreetCred(player: ref<PlayerPuppet>) -> Int32 {
    return this.GetFinancialCreditScore(player);
  }

  private func GetHourOfDay(now: Int32) -> Int32 {
    let dayMinute: Int32 = now - (now / 1440) * 1440;
    return dayMinute / 60;
  }

  private func GetDayOfWeek(now: Int32) -> Int32 {
    return (now / 1440) % 7;
  }

}

@if(!ModuleExists("VehiclePersistence.System"))
func ClearVehiclePersistence(gameInstance: GameInstance, id: TweakDBID) -> Void {}
@if(ModuleExists("VehiclePersistence.System"))
func ClearVehiclePersistence(gameInstance: GameInstance, id: TweakDBID) -> Void {
  PersistentVehicleSystem.GetInstance(gameInstance).RemovePersistentVehicle(id);
}

@if(!ModuleExists("VehiclePersistence.System"))
func RemoveVehicle(gameInstance: GameInstance, vehicleSystem: ref<VehicleSystem>, id: TweakDBID) -> Bool {
  let idStr: String = TDBID.ToStringDEBUG(id);

  vehicleSystem.EnablePlayerVehicle(idStr, false);
  vehicleSystem.TogglePlayerActiveVehicle(Cast<GarageVehicleID>(id), gamedataVehicleType.Car, false);
  vehicleSystem.TogglePlayerActiveVehicle(Cast<GarageVehicleID>(id), gamedataVehicleType.Bike, false);
  return vehicleSystem.EnablePlayerVehicleID(id, false);
}
@if(ModuleExists("VehiclePersistence.System"))
func RemoveVehicle(gameInstance: GameInstance, vehicleSystem: ref<VehicleSystem>, id: TweakDBID) -> Bool {
  let idStr: String = TDBID.ToStringDEBUG(id);
  let result: Bool;

  vehicleSystem.EnablePlayerVehicle(idStr, false);
  result = vehicleSystem.EnablePlayerVehicleID(id, false, true);
  vehicleSystem.TogglePlayerActiveVehicle(Cast<GarageVehicleID>(id), gamedataVehicleType.Car, false);
  vehicleSystem.TogglePlayerActiveVehicle(Cast<GarageVehicleID>(id), gamedataVehicleType.Bike, false);
  result = PersistentVehicleSystem.GetInstance(gameInstance).RemovePersistentVehicle(id) || result;
  return result;
}

@if(!ModuleExists("VehiclePersistence.System"))
func SyncPersistentVehicles(gameInstance: GameInstance) -> Void {}
@if(ModuleExists("VehiclePersistence.System"))
func SyncPersistentVehicles(gameInstance: GameInstance) -> Void {
  PersistentVehicleSystem.GetInstance(gameInstance).SyncAllPersistentVehicles();
}

@if(!ModuleExists("VehiclePersistence.System"))
func GetPersistentVehicles(gameInstance: GameInstance) -> array<PlayerVehicle> {
  let result: array<PlayerVehicle>;
  return result;
}
@if(ModuleExists("VehiclePersistence.System"))
func GetPersistentVehicles(gameInstance: GameInstance) -> array<PlayerVehicle> {
  return PersistentVehicleSystem.GetInstance(gameInstance).GetPersistentVehicles();
}

@if(!ModuleExists("VehiclePersistence.System"))
func CheckIfVehicleIsPersistent(gameInstance: GameInstance, id: TweakDBID) -> Bool { return false; }
@if(ModuleExists("VehiclePersistence.System"))
func CheckIfVehicleIsPersistent(gameInstance: GameInstance, id: TweakDBID) -> Bool {
  return PersistentVehicleSystem.GetInstance(gameInstance).IsVehiclePersistent(id);
}
