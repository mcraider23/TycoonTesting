using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }

# Per-button event handler for correct ammo pool
button_handler := class:
    Index : int
    Device : ammo_generator_device

    HandleButtonPress(Agent:agent):void =
        if (Player := player[Agent]):
            Device.OnClaimPressed(Player, Index)

ammo_generator_device := class(creative_device):

    @editable AmmoTypes : []string = array{"Light Bullets", "Medium Bullets", "Heavy Bullets", "Shells", "Rockets", "Arrows"}
    @editable DropIntervals : []float = array{60.0, 60.0, 60.0, 60.0, 120.0, 30.0}
    @editable AmmoPerDrops : []int = array{10, 10, 5, 2, 1, 6}
    @editable MaxAmmoCaps : []int = array{500, 500, 500, 100, 50, 30}
    @editable Billboards : []billboard_device = array{}
    @editable ClaimButtons : []button_device = array{}
    @editable AmmoGranters : []item_granter_device = array{}

    var AmmoStorage : [string]int = map{}

    OnBegin<override>()<suspends>:void =
        Print("Ammo Generator Manager Online")
        for (Index := 0..AmmoTypes.Length-1):
            if (AmmoType := AmmoTypes[Index]):
                if (set AmmoStorage[AmmoType] = 0):
                    spawn{HandleGenerator(Index)}
                    if (Button := ClaimButtons[Index]):
                        Handler := button_handler{Index := Index, Device := Self}
                        Button.InteractedWithEvent.Subscribe(Handler.HandleButtonPress)
                    UpdateBillboard(Index)

    HandleGenerator(Index:int)<suspends>:void =
        if (AmmoType := AmmoTypes[Index], DropInterval := DropIntervals[Index], PerDrop := AmmoPerDrops[Index]):
            loop:
                Sleep(DropInterval)
                if (CurrentAmount := AmmoStorage[AmmoType], MaxCap := MaxAmmoCaps[Index]):
                    NewAmount := Min(CurrentAmount + PerDrop, MaxCap)
                    if (set AmmoStorage[AmmoType] = NewAmount):
                        UpdateBillboard(Index)

    OnClaimPressed(Player:player, Index:int):void =
        if (AmmoType := AmmoTypes[Index], Amount := AmmoStorage[AmmoType], Amount > 0):
            if (set AmmoStorage[AmmoType] = 0):
                UpdateBillboard(Index)
                GrantAmmoToPlayer(Player, AmmoType, Amount, Index)
        else:
            if (AmmoType := AmmoTypes[Index]):
                Print(NoAmmoMessage(AmmoType))

    UpdateBillboard(Index:int):void =
        if (AmmoType := AmmoTypes[Index], Billboard := Billboards[Index], Value := AmmoStorage[AmmoType]):
            Billboard.SetText(AmmoStatusMessage(AmmoType, Value))

    # Grant ALL ammo by calling GrantItem once per unit
    GrantAmmoToPlayer(Player:player, AmmoType:string, Amount:int, Index:int):void =
        if (Granter := AmmoGranters[Index]):
            # Grant each unit of ammo by calling GrantItem in a loop
            for (I := 0..Amount-1):
                Granter.GrantItem(Player)
            Print(GrantAmmoMessage(Amount, AmmoType))
        else:
            Print("No granter assigned for {AmmoType}")

    NoAmmoMessage<localizes>(AmmoType:string):message = "No {AmmoType} ready yet!"
    GrantAmmoMessage<localizes>(Amount:int, AmmoType:string):message = "You received {Amount} {AmmoType}!"
    AmmoStatusMessage<localizes>(AmmoType:string, Value:int):message = "{AmmoType}: {Value}"