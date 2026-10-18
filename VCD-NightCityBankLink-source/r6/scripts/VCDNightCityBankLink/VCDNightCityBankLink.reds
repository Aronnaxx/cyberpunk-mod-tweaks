module VCDBankLink
import CarDealer.Content.CarDealerContentController

// Virtual Car Dealer / Vanguard Auto <-> 1st Night City Bank.
// Cash purchases normally need the full price in V's wallet. With this add-on the shortfall is
// drawn from the 1st NC Bank account (withdrawal fee included), then the dealer charges the wallet
// as usual. Without 1st NC Bank installed every function here is a no-op.

@if(ModuleExists("FirstNCBank"))
import FirstNCBank.FNCBankAPI

@if(!ModuleExists("FirstNCBank"))
public func VCDBL_BankAvailable(game: GameInstance) -> Bool { return false; }

@if(ModuleExists("FirstNCBank"))
public func VCDBL_BankAvailable(game: GameInstance) -> Bool {
  return IsDefined(FNCBankAPI.GetSystem(game)) && !FNCBankAPI.IsAccountFrozen(game);
}

@if(!ModuleExists("FirstNCBank"))
public func VCDBL_BankBalance(game: GameInstance) -> Int32 { return 0; }

@if(ModuleExists("FirstNCBank"))
public func VCDBL_BankBalance(game: GameInstance) -> Int32 { return FNCBankAPI.GetBalance(game); }

@if(!ModuleExists("FirstNCBank"))
public func VCDBL_BankWithdraw(game: GameInstance, amount: Int32) -> Bool { return false; }

@if(ModuleExists("FirstNCBank"))
public func VCDBL_BankWithdraw(game: GameInstance, amount: Int32) -> Bool { return FNCBankAPI.Withdraw(game, amount); }

@if(!ModuleExists("FirstNCBank"))
public func VCDBL_FeeBp(game: GameInstance) -> Int32 { return 0; }

@if(ModuleExists("FirstNCBank"))
public func VCDBL_FeeBp(game: GameInstance) -> Int32 { return FNCBankAPI.GetCurrentWithdrawalFeeBp(game); }

public func VCDBL_WalletBalance(game: GameInstance) -> Int32 {
  let player: ref<GameObject> = GameInstance.GetPlayerSystem(game).GetLocalPlayerControlledGameObject();
  if !IsDefined(player) { return 0; };
  return GameInstance.GetTransactionSystem(game).GetItemQuantity(player, MarketSystem.Money());
}

// Smallest bank withdrawal whose net (after the bank's fee) covers `shortfall`; -1 if impossible.
public func VCDBL_GrossFor(game: GameInstance, shortfall: Int32) -> Int32 {
  if shortfall <= 0 { return 0; };
  let feeBp: Int64 = Cast<Int64>(VCDBL_FeeBp(game));
  if feeBp < 0l { feeBp = 0l; };
  if feeBp >= 10000l { return -1; };
  let s: Int64 = Cast<Int64>(shortfall);
  let gross: Int64 = (s * 10000l + (10000l - feeBp) - 1l) / (10000l - feeBp);
  while gross - (gross * feeBp) / 10000l < s { gross += 1l; };
  if gross > 2147483647l { return -1; };
  return Cast<Int32>(gross);
}

public func VCDBL_CanCover(game: GameInstance, price: Int32) -> Bool {
  if !VCDBL_BankAvailable(game) { return false; };
  let gross: Int32 = VCDBL_GrossFor(game, price - VCDBL_WalletBalance(game));
  return gross >= 0 && gross <= VCDBL_BankBalance(game);
}

public func VCDBL_Notify(game: GameInstance, text: String) -> Void {
  let msg: SimpleScreenMessage;
  msg.isShown = true;
  msg.duration = 5.0;
  msg.message = text;
  msg.isInstant = true;
  let bb: ref<IBlackboard> = GameInstance.GetBlackboardSystem(game).Get(GetAllBlackboardDefs().UI_Notifications);
  bb.SetVariant(GetAllBlackboardDefs().UI_Notifications.OnscreenMessage, ToVariant(msg), true);
}

// Tops the wallet up to `price` from the bank. True when the wallet can now cover it.
public func VCDBL_TopUpWallet(game: GameInstance, price: Int32) -> Bool {
  let wallet: Int32 = VCDBL_WalletBalance(game);
  if wallet >= price { return true; };
  if !VCDBL_BankAvailable(game) { return false; };
  let gross: Int32 = VCDBL_GrossFor(game, price - wallet);
  if gross < 0 || gross > VCDBL_BankBalance(game) { return false; };
  if !VCDBL_BankWithdraw(game, gross) { return false; };
  VCDBL_Notify(game, "Vanguard Auto: $" + IntToString(gross) + " drawn from your 1st Night City Bank account to complete the purchase.");
  return VCDBL_WalletBalance(game) >= price;
}

@wrapMethod(CarDealerContentController)
private func HasEnoughMoneyDealer(price: Int32) -> Bool {
  if wrappedMethod(price) { return true; };
  return VCDBL_CanCover(this.playerPuppet.GetGame(), price);
}

@wrapMethod(CarDealerContentController)
private func RemoveMoneyFromPlayerDealer(price: Int32) -> Bool {
  VCDBL_TopUpWallet(this.playerPuppet.GetGame(), price);
  return wrappedMethod(price);
}
