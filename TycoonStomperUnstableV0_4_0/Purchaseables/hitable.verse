using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using {/Fortnite.com/Teams}
using {cc}

# Enhanced hitable with leveling system
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

    # Leveling system properties
    @editable var MaxLevel : int = 10
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
