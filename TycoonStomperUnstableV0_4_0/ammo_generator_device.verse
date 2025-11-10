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
    var ActiveGenerators : []logic = array{}

    OnBegin<override>()<suspends>:void =
        Print("=== AMMO GENERATOR MANAGER ONLINE ===")
        Print("AmmoTypes.Length: {AmmoTypes.Length}")
        
        # Initialize all generators as INACTIVE
        set ActiveGenerators = for (Index := 0..AmmoTypes.Length-1) do false
        Print("Initialized {ActiveGenerators.Length} generator slots as inactive")
        
        for (Index := 0..AmmoTypes.Length-1):
            if (AmmoType := AmmoTypes[Index]):
                Print("Setting up ammo type {Index}: {AmmoType}")
                if (set AmmoStorage[AmmoType] = 0):
                    Print("  Storage initialized to 0")
                    if (Button := ClaimButtons[Index]):
                        Handler := button_handler{Index := Index, Device := Self}
                        Button.InteractedWithEvent.Subscribe(Handler.HandleButtonPress)
                        Print("  Button subscribed")
                    else:
                        Print("  WARNING: No button at index {Index}")
                    UpdateBillboard(Index)
                else:
                    Print("  ERROR: Failed to initialize storage")
            else:
                Print("ERROR: No AmmoType at index {Index}")

    # Public method to activate a specific ammo generator
    ActivateGenerator<public>(Index : int):void =
        Print("=== ACTIVATE GENERATOR CALLED ===")
        Print("Index: {Index}")
        Print("AmmoTypes.Length: {AmmoTypes.Length}")
        Print("ActiveGenerators.Length: {ActiveGenerators.Length}")
        
        if (Index >= 0 and Index < AmmoTypes.Length):
            Print("Index is VALID")
            
            # Check current state safely
            if (CurrentState := ActiveGenerators[Index]):
                Print("Current state retrieved successfully")
            
            if (set ActiveGenerators[Index] = true):
                Print("SUCCESS: Set ActiveGenerators[{Index}] = true")
                Print("Spawning HandleGenerator for index {Index}...")
                spawn{HandleGenerator(Index)}
                Print("HandleGenerator spawned!")
            else:
                Print("ERROR: Failed to set ActiveGenerators[{Index}] = true")
        else:
            Print("ERROR: Index {Index} is OUT OF RANGE (valid: 0 to {AmmoTypes.Length - 1})")

    # Public method to deactivate a generator
    DeactivateGenerator<public>(Index : int):void =
        Print("=== DEACTIVATE GENERATOR CALLED ===")
        Print("Deactivating ammo generator {Index}")
        if (Index >= 0 and Index < AmmoTypes.Length):
            if (set ActiveGenerators[Index] = false):
                Print("Deactivated generator {Index}")
                if (AmmoType := AmmoTypes[Index]):
                    if (set AmmoStorage[AmmoType] = 0):
                        UpdateBillboard(Index)
                        Print("Reset storage for {AmmoType}")

    # Public method to deactivate all generators
    DeactivateAllGenerators<public>():void =
        Print("Deactivating all ammo generators")
        for (Index := 0..AmmoTypes.Length-1):
            DeactivateGenerator(Index)

    HandleGenerator(Index:int)<suspends>:void =
        Print("=== HANDLE GENERATOR STARTED ===")
        Print("Index: {Index}")
        
        if (AmmoType := AmmoTypes[Index], DropInterval := DropIntervals[Index], PerDrop := AmmoPerDrops[Index]):
            Print("Generator {Index} configuration:")
            Print("  AmmoType: {AmmoType}")
            Print("  DropInterval: {DropInterval} seconds")
            Print("  PerDrop: {PerDrop}")
            Print("  Starting generation loop...")
            
            loop:
                # Check if this generator is still active
                Print("Generator {Index} checking if still active...")
                
                # Safely check active state
                if (IsActive := ActiveGenerators[Index]):
                    # IsActive is now a logic value
                    if (IsActive = false):
                        Print("  Generator {Index} is INACTIVE - stopping loop")
                        break
                    else:
                        Print("  Generator {Index} is ACTIVE - continuing")
                else:
                    Print("  ERROR: Could not read ActiveGenerators[{Index}]")
                    break
                
                Print("Generator {Index} sleeping for {DropInterval} seconds")
                Sleep(DropInterval)
                Print("Generator {Index} woke up after {DropInterval} seconds!")
                
                if (CurrentAmount := AmmoStorage[AmmoType], MaxCap := MaxAmmoCaps[Index]):
                    NewAmount := Min(CurrentAmount + PerDrop, MaxCap)
                    Print("  Current: {CurrentAmount}, Adding: {PerDrop}, New: {NewAmount}, Cap: {MaxCap}")
                    
                    if (set AmmoStorage[AmmoType] = NewAmount):
                        Print("  SUCCESS: Updated storage for {AmmoType} to {NewAmount}")
                        UpdateBillboard(Index)
                        Print("  Billboard updated")
                    else:
                        Print("  ERROR: Failed to update storage")
                else:
                    Print("  ERROR: Failed to get CurrentAmount or MaxCap")
        else:
            Print("ERROR: Failed to get AmmoType, DropInterval, or PerDrop for index {Index}")

    OnClaimPressed(Player:player, Index:int):void =
        Print("Claim button pressed for index {Index}")
        if (AmmoType := AmmoTypes[Index], Amount := AmmoStorage[AmmoType], Amount > 0):
            Print("Claiming {Amount} {AmmoType}")
            if (set AmmoStorage[AmmoType] = 0):
                UpdateBillboard(Index)
                GrantAmmoToPlayer(Player, AmmoType, Amount, Index)
        else:
            if (AmmoType := AmmoTypes[Index]):
                Print(NoAmmoMessage(AmmoType))

    UpdateBillboard(Index:int):void =
        if (AmmoType := AmmoTypes[Index], Billboard := Billboards[Index], Value := AmmoStorage[AmmoType]):
            Billboard.SetText(AmmoStatusMessage(AmmoType, Value))
            Print("Billboard {Index} updated: {AmmoType} = {Value}")
        else:
            Print("ERROR: Failed to update billboard {Index}")

    GrantAmmoToPlayer(Player:player, AmmoType:string, Amount:int, Index:int):void =
        if (Granter := AmmoGranters[Index]):
            for (I := 0..Amount-1):
                Granter.GrantItem(Player)
            Print(GrantAmmoMessage(Amount, AmmoType))
        else:
            Print("No granter assigned for {AmmoType}")

    NoAmmoMessage<localizes>(AmmoType:string):message = "No {AmmoType} ready yet!"
    GrantAmmoMessage<localizes>(Amount:int, AmmoType:string):message = "You received {Amount} {AmmoType}!"
    AmmoStatusMessage<localizes>(AmmoType:string, Value:int):message = "{AmmoType}: {Value}"