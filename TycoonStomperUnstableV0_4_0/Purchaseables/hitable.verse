 using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using {/Fortnite.com/Teams}
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Assets }
using {cc}

# Enhanced hitable with leveling system and hit animations
hitable_buyable<public>:=class<concrete><final>(fxpurchaseable):

    @editable var hitableConfig : unique_hitable_buyable = unique_hitable_buyable{}
    var Ptype <override> :  PurchaseableType = PurchaseableType.Hitable


    Initialize<override>(Hostess:base, I:int):void=    
        (super:)Initialize(Hostess, I)
        hitableConfig.Initialize(Hostess)
        Detail("hitableBuyable")

        if:
            HC := hitableConfig.OverrideHudConfig?
        then:
            HC.Initialize(Self)

 
    OnRebirth<override>():void=
        (super:)OnRebirth()
        hitableConfig.ResetLevel()

    GetStringParams<override>(P:?player)<transacts>:[string]string=
        var default : [string]string = (super:)GetStringParams(P)
        if:
            Owner := MaybeOwner?
            Player := P?
            Rebirths := GetCoreStats[Player, Owner.Base_Setup.PersistenceCore].Rebirths
            RebirthedOnHitGrantAmount := GetRebirthAmount[Owner, Rebirths, hitableConfig.OnHitGrantAmount]
        then:
            set default = MergeStringMaps(default, map{"[OnHitGrantAmount(Param:RebirthValue)]" => "{RebirthedOnHitGrantAmount.GetTrunc(Owner)}"})
        set default = MergeStringMaps(default, map{
                "[CurrencyOnHitID]" => "{hitableConfig.CurrencyOnHitID}",
                "[OnHitExperienceAmount]" => "{hitableConfig.OnHitExperienceAmount}",
                "[OnHitGrantAmount]" => "{hitableConfig.OnHitGrantAmount}",
                "[HitableLevel]" => "{hitableConfig.CurrentLevel}",
                "[HitableXP]" => "{hitableConfig.CurrentXP}",
                "[HitableMaxXP]" => "{hitableConfig.MaxXPForLevel}",
                "[HitableReward]" => "{hitableConfig.CurrentReward}",
                "[ComboTotal]" => "{hitableConfig.ComboAmount}"
            })

        return default


    Host<override>()<suspends>:void=
        hitableConfig.Enable()
        loop:
            Event := hitableConfig.OnHit.Await()
            if:
                Player := player[Event]
                Owner := MaybeOwner?
                BaseReward := hitableConfig.CurrentReward
                Rebirths := GetCoreStats[Player, Owner.Base_Setup.PersistenceCore].Rebirths
                RebirthedReward := GetRebirthAmount[Owner, Rebirths, BaseReward]
            then:
                    Granter := hitableConfig.OptItemGranter
                    
                    GrantMoney(Owner, Player, hitableConfig.CurrencyOnHitID, RebirthedReward, BypassZone)
                    GrantXP(Owner, Player, hitableConfig.OnHitExperienceAmount)
                    Granter.GrantItem(Player)
                    
                    # Add rebirthed amount to combo
                    hitableConfig.AddToCombo(RebirthedReward)
                    hitableConfig.AddXP(1)
                    spawn{hitableConfig.UpdateDisplayAsync()}
                    
                    # Play hit animation
                    spawn{hitableConfig.PlayHitAnimation()}
                    
                    # Spawn props on hit
                    spawn{hitableConfig.SpawnHitProps()}
                    
                    # Show combo message
                    if:
                        OHudConfig := hitableConfig.OverrideHudConfig?
                    then:
                        OHudConfig.OnSuccessfullPlayer(Player)
                        spawn{OnEvent()}
                    else:
                        HudConfig.OnSuccessfullPlayer(Player)
            else:
                if:
                    OHudConfig := hitableConfig.OverrideHudConfig?
                    Owner := MaybeOwner?
                then:
                    OHudConfig.OnFail(Owner)
                else if:
                    Owner := MaybeOwner?
                then:
                    HudConfig.OnFail(Owner)
                

                    
            PreventInf();


unique_hitable_buyable:=class<concrete>(Toggleable, Inaugurable):

    @editable var CurrencyOnHitID  : int = {0}
    @editable var OnHitGrantAmount : int = {25}
    @editable var OnHitExperienceAmount : int = {0}
    @editable var OptItemGranter : item_granter_device = {item_granter_device{}}
    @editable var hitdetectors : []trigger_device = array{}
    @editable var OverrideHudConfig : ?hud_main = option{hud_main{OnFailedMessage := option{""}; OnSuccessMessage := option{"+[ComboTotal] (Lvl [HitableLevel])"}}}

    # Animation settings for hit feedback
    @editable var HitAnimationEnabled : logic = true
    @editable var HitAnimationDistance : float = 50.0
    @editable var HitAnimationSpeed : float = 20.0
    
    # Props that will animate when hit
    @editable var AnimatedProps : []creative_prop = array{}

    # Prop spawning settings
    @editable var SpawnPropsOnHit : logic = true
    @editable var PropToSpawn : creative_prop_asset = DefaultCreativePropAsset
    @editable var PropCount : int = 8
    @editable var PropScale : float = 0.3
    @editable var PropSpeed : float = 500.0
    @editable var PropLifetime : float = 2.0
    @editable var PropSpawnHeight : float = 100.0

    # Leveling system properties
    @editable var MaxLevel : int = 10000
    @editable var BaseXPPerLevel : int = 10
    @editable var XPScalingFactor : float = 1.5
    @editable var RewardPerLevel : int = 5
    @editable var LevelDisplay : billboard_device = billboard_device{}
    @editable var ComboResetTime : float = 2.0

    var CurrentLevel : int = 1
    var CurrentXP : int = 0
    var MaxXPForLevel : int = 10
    var CurrentReward : int = 25
    var Owner : ?base = false
    var ComboAmount : int = 0
    var ComboActive : logic = false
    var OriginalTransforms : []transform = array{}
    var AnimationInitialized : logic = false

    OnHit : event(agent) = event(agent){}
    ComboReset : event() = event(){}

    # Calculate values for current level
    CalculateLevelValues():void=
        if(CurrentLevel >= MaxLevel):
            set MaxXPForLevel = 999999
        else:
            BaseXP := BaseXPPerLevel * 1.0
            LevelMult := (CurrentLevel - 1) * 1.0
            if:
                LevelFactor := Pow(XPScalingFactor, LevelMult)
                Calculated := BaseXP * LevelFactor
                FlooredValue := Floor[Calculated]
            then:
                set MaxXPForLevel = FlooredValue
            else:
                set MaxXPForLevel = BaseXPPerLevel
        
        LevelBonus := (CurrentLevel - 1) * RewardPerLevel
        set CurrentReward = OnHitGrantAmount + LevelBonus

    # Add XP and check for level up
    AddXP<public>(Amount:int):void=
        if(CurrentLevel >= MaxLevel){return}
        
        set CurrentXP += Amount
        
        if(CurrentXP >= MaxXPForLevel):
            set CurrentLevel += 1
            set CurrentXP = 0
            CalculateLevelValues()

    # Reset level (for rebirth)
    ResetLevel<public>():void=
        set CurrentLevel = 1
        set CurrentXP = 0
        set ComboAmount = 0
        set ComboActive = false
        CalculateLevelValues()
        spawn{UpdateDisplayAsync()}

    # Add to combo
    AddToCombo<public>(Amount:int):void=
        set ComboAmount += Amount
        set ComboActive = true

    # Reset combo
    ResetCombo<public>():void=
        set ComboAmount = 0
        set ComboActive = false
        ComboReset.Signal()

    # Update the billboard display
    UpdateDisplayAsync<public>()<suspends>:void=
        Sleep(0.0)
        if(CurrentLevel >= MaxLevel):
            LevelDisplay.SetText(S2M("MAX LEVEL"))
        else:
            ProgressBar := CreateProgressBar(CurrentXP, MaxXPForLevel)
            DisplayText := "Level {CurrentLevel}\n{ProgressBar}"
            LevelDisplay.SetText(S2M(DisplayText))

    # Create a simple text-based progress bar
    CreateProgressBar(Current:int, MaxXP:int):string=
        if(MaxXP <= 0):
            return "██████████"
        
        BarLength := 10
        Percentage := (Current * 1.0) / (MaxXP * 1.0)
        FilledFloat := Percentage * BarLength * 1.0
        
        if:
            FilledBlocks := Floor[FilledFloat]
        then:
            # Clamp between 0 and BarLength
            FilledInt := if(FilledBlocks < 0){0}else if(FilledBlocks > BarLength){BarLength}else{FilledBlocks}
            
            var BarText : string = ""
            var i : int = 0
            loop:
                if(i >= BarLength){break}
                if(i < FilledInt):
                    set BarText = "{BarText}█"
                else:
                    set BarText = "{BarText}_"
                set i += 1
            
            return BarText
        
        return "__________"

    # Spawn props in all directions on hit
    SpawnHitProps<public>()<suspends>:void=
        if (SpawnPropsOnHit = false):
            return
        
        if (AnimatedProps.Length = 0):
            return
        
        # Get center position from first animated prop
        if (CenterProp := AnimatedProps[0]):
            CenterPos := CenterProp.GetTransform().Translation
            SpawnPos := vector3{
                X := CenterPos.X,
                Y := CenterPos.Y,
                Z := CenterPos.Z + PropSpawnHeight
            }
            
            # Spawn props in predefined directions (avoids trig functions)
            for (I := 0..PropCount - 1):
                spawn{SpawnSinglePropDirectional(SpawnPos, I)}

    # Spawn and animate a single prop using predefined directions
    SpawnSinglePropDirectional(StartPos:vector3, DirIndex:int)<suspends>:void=
        # Use predefined direction vectors to avoid trig - creates 8 directions
        var DirectionX : float = 0.0
        var DirectionY : float = 0.0
        
        # Calculate direction based on index (0-7 for 8 directions)
        if:
            DivResult := Floor[DirIndex * 1.0 / 8.0]
        then:
            Mod8 := DirIndex - (DivResult * 8)
            
            if (Mod8 = 0):  # Right
                set DirectionX = PropSpeed
                set DirectionY = 0.0
            else if (Mod8 = 1):  # Up-Right
                set DirectionX = PropSpeed * 0.707
                set DirectionY = PropSpeed * 0.707
            else if (Mod8 = 2):  # Up
                set DirectionX = 0.0
                set DirectionY = PropSpeed
            else if (Mod8 = 3):  # Up-Left
                set DirectionX = PropSpeed * -0.707
                set DirectionY = PropSpeed * 0.707
            else if (Mod8 = 4):  # Left
                set DirectionX = PropSpeed * -1.0
                set DirectionY = 0.0
            else if (Mod8 = 5):  # Down-Left
                set DirectionX = PropSpeed * -0.707
                set DirectionY = PropSpeed * -0.707
            else if (Mod8 = 6):  # Down
                set DirectionX = 0.0
                set DirectionY = PropSpeed * -1.0
            else:  # Down-Right (7)
                set DirectionX = PropSpeed * 0.707
                set DirectionY = PropSpeed * -0.707
            
            # Spawn the prop
            MaybeSpawnResult := SpawnProp(PropToSpawn, StartPos, rotation{})
            
            if:
                SpawnResult := MaybeSpawnResult(0)?
                SpawnedProp := SpawnResult
            then:
                # Scale the prop down
                CurrentTransform := SpawnedProp.GetTransform()
                ScaledTransform := transform{
                    Translation := CurrentTransform.Translation,
                    Rotation := CurrentTransform.Rotation,
                    Scale := vector3{X := PropScale, Y := PropScale, Z := PropScale}
                }
                if(SpawnedProp.TeleportTo[ScaledTransform]){}
                
                # Calculate end position
                EndPos := vector3{
                    X := StartPos.X + DirectionX,
                    Y := StartPos.Y + DirectionY,
                    Z := StartPos.Z - 200.0  # Fall down
                }
                
                # Move the prop outward
                SpawnedProp.MoveTo(EndPos, CurrentTransform.Rotation, PropLifetime)
                
                # Destroy after lifetime
                Sleep(PropLifetime)
                SpawnedProp.Dispose()

    # Initialize animation system - capture original positions WHEN VISIBLE
    InitializeAnimation():void=
        if (AnimatedProps.Length > 0):
            if (AnimationInitialized = false):
                Print("Capturing original transforms for {AnimatedProps.Length} props")
                set OriginalTransforms = for (Prop : AnimatedProps):
                    CurrentTransform := Prop.GetTransform()
                    Print("Prop at: X={CurrentTransform.Translation.X}, Y={CurrentTransform.Translation.Y}, Z={CurrentTransform.Translation.Z}")
                    CurrentTransform
                set AnimationInitialized = true
                Print("Animation initialized successfully")

    # Play hit animation - captures position on FIRST hit if needed
    PlayHitAnimation<public>()<suspends>:void=
        # Safety check
        if (HitAnimationEnabled = false):
            return
            
        if (AnimatedProps.Length = 0):
            Print("No animated props assigned!")
            return
        
        # IMPORTANT: Capture positions on first hit (when props are visible)
        if (AnimationInitialized = false):
            Print("First hit! Capturing visible positions now...")
            InitializeAnimation()
        
        # Check if counts match
        if (OriginalTransforms.Length = AnimatedProps.Length):
            # Counts match, continue
            void
        else:
            Print("ERROR: Transform count mismatch!")
            return
        
        Print("Starting hit animation...")
        
        # Calculate timing
        UpTime := 1.0 / HitAnimationSpeed
        DownTime := 1.5 / HitAnimationSpeed
        
        # Move props UP
        for (Index -> Prop : AnimatedProps):
            if (Prop.IsValid[]):
                if (OriginalTrans := OriginalTransforms[Index]):
                    UpPos := vector3{
                        X := OriginalTrans.Translation.X,
                        Y := OriginalTrans.Translation.Y,
                        Z := OriginalTrans.Translation.Z + HitAnimationDistance
                    }
                    Print("Moving prop UP to Z={UpPos.Z}")
                    Prop.MoveTo(UpPos, OriginalTrans.Rotation, UpTime)
        
        # Wait for up animation
        Sleep(UpTime)
        
        # Move props DOWN (back to original)
        for (Index -> Prop : AnimatedProps):
            if (Prop.IsValid[]):
                if (OriginalTrans := OriginalTransforms[Index]):
                    Print("Moving prop DOWN to Z={OriginalTrans.Translation.Z}")
                    Prop.MoveTo(OriginalTrans.Translation, OriginalTrans.Rotation, DownTime)
        
        Print("Animation complete!")

    Disable<override>():void=
        for:
            hitdetector : hitdetectors
        do:
            hitdetector.Disable()
    
    Enable<override>():void=
        for:
            hitdetector : hitdetectors
        do:
            hitdetector.Enable()

    Initialize<override>(Base:base):void=
        set Owner = option{Base}
        CalculateLevelValues()
        Disable()
        
        # DON'T initialize animation here - wait for first hit when props are visible!
        
        spawn{UpdateDisplayAsync()}
        spawn{MultiThreadHitDetector(Base)}
        spawn{ManageComboTimer()}

    MultiThreadHitDetector(Base:base)<suspends>:void=
        for:
            hitdetector : hitdetectors
        do:
            spawn{ThreadedSys(hitdetector, Base)}

    ThreadedSys(hitdetector:trigger_device, Base:base)<suspends>:void=
        loop:
            race:
                AwaitHit(Base, hitdetector)
                OnHit.Await()
    
    AwaitHit(Base:base, HD:trigger_device)<suspends>:void=
        MAgent := HD.TriggeredEvent.Await()
        if:
            Agent := MAgent?
        then:
            OnHit.Signal(Agent)

    # Manage combo timer - resets combo after inactivity
    ManageComboTimer<public>()<suspends>:void=
        loop:
            race:
                block:
                    OnHit.Await()
                    Sleep(ComboResetTime)
                    if(ComboActive?):
                        ResetCombo()
                block:
                    ComboReset.Await()