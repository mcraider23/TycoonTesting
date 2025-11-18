using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Colors }
using { /Fortnite.com/UI }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Game }

ToMessage<localizes>(Text : string):message = "{Text}"

GetStatColor(Value : float, MaxValue : float) : color =
    Percentage := (Value / MaxValue) * 100.0
    if (Percentage >= 75.0):
        NamedColors.LimeGreen
    else if (Percentage >= 25.0):
        NamedColors.Yellow
    else:
        NamedColors.Red

hunger_energy_device := class(creative_device):
    @editable var InitialHunger : float = 100.0
    @editable var InitialEnergy : float = 100.0
    @editable var HungerDrainRate : float = 1.0
    @editable var EnergyDrainRate : float = 1.0
    @editable var DrainInterval : float = 1.0
    @editable var EnergyRechargeRate : float = 5.0
    @editable var HungerRestorePerFood : float = 25.0
    @editable var RestZones : []mutator_zone_device = array{}
    @editable var HungerRestoreZones : []mutator_zone_device = array{}
    @editable var DamageInterval : float = 1.0
    @editable var LowStatDamage : float = 1.0
    @editable var BothStatsDamage : float = 5.0

    var PlayerCanvases : [player]canvas = map{}
    var PlayerHunger : [player]float = map{}
    var PlayerEnergy : [player]float = map{}
    var PlayersInRestZone : [player]logic = map{}
    var PlayersInHungerZone : [player]logic = map{}
    var ActivePlayers : [player]logic = map{}

    AddStatsWidget(Player : player):void =
        if (PlayerUI := GetPlayerUI[Player]):
            HungerText := text_block{
                DefaultText := ToMessage("Hunger: 100%")
                DefaultTextColor := NamedColors.LimeGreen
            }
            EnergyText := text_block{
                DefaultText := ToMessage("Energy: 100%")
                DefaultTextColor := NamedColors.LimeGreen
            }
            StatsBox := stack_box{
                Orientation := orientation.Vertical
                Slots := array{
                    stack_box_slot{Widget := HungerText}
                    stack_box_slot{Widget := EnergyText}
                }
            }
            Canvas := canvas{
                Slots := array{
                    canvas_slot{
                        Widget := StatsBox
                        Anchors := anchors{
                            Minimum := vector2{X := 0.5, Y := 1.0},
                            Maximum := vector2{X := 0.5, Y := 1.0}
                        }
                        Alignment := vector2{X := 0.5, Y := 1.0}
                        Offsets := margin{Top := -120.0}
                        ZOrder := 100
                    }
                }
            }
            PlayerUI.AddWidget(Canvas, player_ui_slot{
                ZOrder := 100
                InputMode := ui_input_mode.None
            })
            if (set PlayerCanvases[Player] = Canvas) {}

    UpdatePlayerStats(Player : player):void =
        # CRITICAL FIX: Check if player is still active before updating
        if (ActivePlayers[Player] = false):
            return
            
        if (Canvas := PlayerCanvases[Player]):
            if (Canvas.Slots.Length > 0):
                if (CanvasSlot := Canvas.Slots[0]):
                    if (StatsBox := stack_box[CanvasSlot.Widget]):
                        if (Hunger := PlayerHunger[Player]):
                            if (Energy := PlayerEnergy[Player]):
                                if (StatsBox.Slots.Length = 2):
                                    if (HungerSlot := StatsBox.Slots[0]):
                                        if (HungerText := text_block[HungerSlot.Widget]):
                                            if (HungerInt := Round[Hunger]):
                                                HungerText.SetText(ToMessage("Hunger: {HungerInt}%"))
                                                HungerText.SetTextColor(GetStatColor(Hunger, InitialHunger))
                                    if (EnergySlot := StatsBox.Slots[1]):
                                        if (EnergyText := text_block[EnergySlot.Widget]):
                                            if (EnergyInt := Round[Energy]):
                                                EnergyText.SetText(ToMessage("Energy: {EnergyInt}%"))
                                                EnergyText.SetTextColor(GetStatColor(Energy, InitialEnergy))

    SubscribeToElimination(Player : player):void =
        if (Character := Player.GetFortCharacter[]):
            Character.EliminatedEvent().Subscribe(OnEliminated)

    OnEliminated(Result : elimination_result):void =
        if (Character := Result.EliminatedCharacter, Agent := Character.GetAgent[], Player := player[Agent]):
            if (set PlayerHunger[Player] = InitialHunger) {}
            if (set PlayerEnergy[Player] = InitialEnergy) {}
            UpdatePlayerStats(Player)

    # PUBLIC: Activate hunger for a player (call this when they claim base)
    ActivateHungerForPlayer<public>(Player : player):void =
        Print("Activating hunger system for player")
        if (set ActivePlayers[Player] = true) {}
        if (set PlayerHunger[Player] = InitialHunger) {}
        if (set PlayerEnergy[Player] = InitialEnergy) {}
        if (set PlayersInRestZone[Player] = false) {}
        if (set PlayersInHungerZone[Player] = false) {}
        AddStatsWidget(Player)
        UpdatePlayerStats(Player)
        SubscribeToElimination(Player)

    # PUBLIC: Deactivate hunger (call this on rebirth)
    DeactivateHungerForPlayer<public>(Player : player)<suspends>:void =
        Print("Deactivating hunger system for player")
        
        # CRITICAL: Set inactive FIRST before removing UI
        if (set ActivePlayers[Player] = false) {}
        
        # Small delay to ensure all loops see the inactive state
        # This prevents race conditions where loops try to update UI as we remove it
        Sleep(0.1)
        
        # Now safe to remove the UI widget
        if (Canvas := PlayerCanvases[Player]):
            if (PlayerUI := GetPlayerUI[Player]):
                PlayerUI.RemoveWidget(Canvas)
                Print("Removed hunger UI for player")
        
        # Clear the canvas reference
        if (set PlayerCanvases[Player] = canvas{}) {}

    OnBegin<override>()<suspends>:void =
        # Set up zones
        for (Zone : RestZones):
            Zone.AgentEntersEvent.Subscribe(OnEnterRestZone)
            Zone.AgentExitsEvent.Subscribe(OnExitRestZone)
        for (Zone : HungerRestoreZones):
            Zone.AgentEntersEvent.Subscribe(OnEnterHungerZone)
            Zone.AgentExitsEvent.Subscribe(OnExitHungerZone)
        
        # Start the loops
        spawn{DamageLoop()}
        spawn{RestorationLoop()}
        spawn{DrainLoop()}

    DrainLoop()<suspends>:void =
        loop:
            Sleep(DrainInterval)
            for (Player -> IsActive : ActivePlayers):
                if (IsActive = true):
                    if (Hunger := PlayerHunger[Player]):
                        if (Energy := PlayerEnergy[Player]):
                            NewHunger := Max(0.0, Hunger - HungerDrainRate)
                            NewEnergy := Max(0.0, Energy - EnergyDrainRate)
                            if (set PlayerHunger[Player] = NewHunger) {}
                            if (set PlayerEnergy[Player] = NewEnergy) {}
                            
                            # CRITICAL FIX: Check active status before updating UI
                            if (ActivePlayers[Player] = true):
                                UpdatePlayerStats(Player)

    RestorationLoop()<suspends>:void =
        loop:
            Sleep(DrainInterval)
            for (Player -> IsActive : ActivePlayers):
                if (IsActive = true):
                    if (PlayersInRestZone[Player] = true):
                        if (Energy := PlayerEnergy[Player]):
                            NewEnergy := Min(InitialEnergy, Energy + EnergyRechargeRate)
                            if (set PlayerEnergy[Player] = NewEnergy) {}
                            
                            # CRITICAL FIX: Check active status before updating UI
                            if (ActivePlayers[Player] = true):
                                UpdatePlayerStats(Player)
                    if (PlayersInHungerZone[Player] = true):
                        if (Hunger := PlayerHunger[Player]):
                            NewHunger := Min(InitialHunger, Hunger + HungerRestorePerFood)
                            if (set PlayerHunger[Player] = NewHunger) {}
                            
                            # CRITICAL FIX: Check active status before updating UI
                            if (ActivePlayers[Player] = true):
                                UpdatePlayerStats(Player)

    DamageLoop()<suspends>:void =
        loop:
            Sleep(DamageInterval)
            for (Player -> IsActive : ActivePlayers):
                if (IsActive = true):
                    if (Hunger := PlayerHunger[Player]):
                        if (Energy := PlayerEnergy[Player]):
                            if (Character := Player.GetFortCharacter[]):
                                if (Hunger = 0.0 and Energy = 0.0):
                                    Character.Damage(BothStatsDamage)
                                else if (Hunger = 0.0 or Energy = 0.0):
                                    Character.Damage(LowStatDamage)

    OnEnterRestZone(Agent : agent):void =
        if (Player := player[Agent]):
            if (set PlayersInRestZone[Player] = true) {}

    OnExitRestZone(Agent : agent):void =
        if (Player := player[Agent]):
            if (set PlayersInRestZone[Player] = false) {}

    OnEnterHungerZone(Agent : agent):void =
        if (Player := player[Agent]):
            if (set PlayersInHungerZone[Player] = true) {}

    OnExitHungerZone(Agent : agent):void =
        if (Player := player[Agent]):
            if (set PlayersInHungerZone[Player] = false) {}