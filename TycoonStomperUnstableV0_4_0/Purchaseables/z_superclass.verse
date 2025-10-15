using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { /UnrealEngine.com/Temporary/SpatialMath }
using {cc}

purchaseable<public>:=class<abstract>(Detailable, Hostable, SuperInaugurable, Rebirthable, SubHostable, IntegralFX, Gated, StringReturnables):
    var ID <public> : string = ""
    var OnInitalized <public> : event() = event(){}
    var OnInitalizedChild <public> : event() = event(){}
    var MaybeOwner <public> : ?base = false
    var Ptype <public> : PurchaseableType
    var MyIndex:int=-1
    var IsPurchased: PurchasedStatus = PurchasedStatus.NotPurchased
    var InitialStatus: Dependency = Dependency.Unlocked
    var CanLoad: logic = false
    var GlobalOriginProps : [TWC_unique_prop][]origin_prop = map{}
    var DefaultAltClaim<public>:logic=false

    var OnBoughtEvent <public> : event(agent) = event(agent){}
    var SetOwnerEvent <public> : event(base) = event(base){}
    var BegunHosting : event() = event(){}
    var UnlockEvent <public> : event() = event(){}
    var StatusChange <public> : event() = event(){}
    var RebirthedEvent <public> : event() = event(){}

    @editable {ToolTip:=NameTT} var  Name <public>:  string = "My item name here"
    @editable var  Description <public>: string = "My \nmulti line \nitem description here"
    @editable var  Price <public>: int = {0}
    @editable var  ExperiencePointsToAdd  : int = {0}
    @editable {ToolTip:=CurrenySpendTT} var  CurrencyToSpendID  <public>: int = {0}
    @editable var  CurrencyToReceiveID  <public>: int = {0}
    @editable var  GrantAmount <public>: int = {0}
    @editable {ToolTip:=GrantIntervalTT} var  GrantInterval : ?float = option{15.0}
    @editable {ToolTip:=StartAsTT} var  StartAs <public> : Dependency = Dependency.Unlocked
    @editable var  Accolade: accolades_device = accolades_device{}
    @editable var  OnUnlockCinematic : cinematic_sequence_device = cinematic_sequence_device{}
    @editable var  OnPurchaseCinematic : cinematic_sequence_device = cinematic_sequence_device{}
    @editable {ToolTip:=BypassZoneTT} var  BypassZone <public> : logic = {false}
    @editable var  UnlockTheseItems : []purchase_set = array{}
    @editable var PropsV2 : []TWC_unique_prop = array{}
    @editable var AnimationConfig <public> : animation_main = animation_main{}
    @editable var  HudConfig : hud_main = hud_main{OnFailedMessage := option{"You need [MoneyNeeded] more to purchase [Name]"}; OnSuccessMessage := option{"Succsessfully Purchased [Name]"}}
    @editable var BillboardConfig : billboard_main = billboard_main{}
    @editable var  ConditionsToBuy : condition = condition{}
    @editable var  Purchase_Zone <public> : anyzone_or_atm = anyzone_or_atm{}
    @editable var  VFX : vfx_main = vfx_main{}
    @editable var SFX : sfx_main = sfx_main{}

    OnRebirth<override>():void=
        RebirthedEvent.Signal()
        if(InitialStatus = Dependency.Unlocked){Unlock()}
        if(InitialStatus = Dependency.Locked){Lock()}

        if:
            IsPurchased = PurchasedStatus.Purchased
        then:
            set CanLoad = true
            set IsPurchased = PurchasedStatus.NotPurchased
            Purchase_Zone.Enable()
            Purchase_Zone.Show()
            spawn{SubHost()}
        
        if:
            StartAs = Dependency.Unlocked
            Owner := MaybeOwner?
        then:
            InitializeChildren(Owner, MyIndex)
        else:
            GlobalSuperlog("{Name} is locked after rebirth. Not initializing children.")

    Detail<override>(Type:string)<transacts>:void=
        GlobalSuperlog("==[{Type}]==")

    Initialize<override>(Hostess:base, I:int):void=
        GlobalSuperlog("Initializing {Name}...")
        VFX.OnBegin(-1)
        SFX.OnBegin(-1)
        BillboardConfig.OnBegin(-1)
        BillboardConfig.Initialize(Self)
        HudConfig.Initialize(Self)
        SetupPropsV2()
        
        # Initialize TWC props to hide them on game start
        for:
            TWC:PropsV2
        do:
            TWC.Initialize(Self)
        
        set InitialStatus = StartAs
        set MyIndex = I
        set MaybeOwner = option{Hostess}
        spawn{SubHost()}
        set Purchase_Zone.Origin = Purchase_Zone.Zone.GetTransform().Translation
        spawn{Purchase_Zone.AwaitUnlock(Self)}
        
        if:
            X := CreateID[10]
            set ID = X
        else:
            GlobalSuperlog("Couldnt make ID for: {Name};")

        if:
            StartAs = Dependency.Unlocked
        then:
            InitializeChildren(Hostess, I)
            GlobalSuperlog("Initialized children for {Name}")
        else:
            GlobalSuperlog("{Name} is LOCKED on init. Not initializing children.")

    InitializeChildren(Hostess:base, I:int):void=
        set CanLoad = true
        set MaybeOwner = option{Hostess}
        Purchase_Zone.Initialize(Hostess, DefaultAltClaim)
        InitializeFX()
        
        # Only show billboard if NOT already purchased
        if(IsPurchased = PurchasedStatus.NotPurchased):
            BillboardConfig.Instantiate()
        else:
            GlobalSuperlog("{Name} already purchased - hiding billboard")
            BillboardConfig.Hide()
        
        spawn{AwaitAttemptedPurchase(Purchase_Zone, Hostess)}
        OnInitalized.Signal()
        SetOwnerEvent.Signal(Hostess)

    ManageHost()<suspends>:void=
        race:
            block:
                Host()
            block:
                RebirthedEvent.Await()

    Host<override>()<suspends>:void

    SubHost<override>()<suspends>:void=
        for:
            TWC:PropsV2
        do:
            spawn{ManageTWC(TWC)}

    ManageTWC(TWC:TWC_unique_prop)<suspends>:void=
        race:
            sync: 
                ManagePrePurchasePropSet(TWC)
                ManagePostPurchaseSet(TWC)
            RebirthedEvent.Await()

    ManagePostPurchaseSet<public>(TWC:TWC_unique_prop)<suspends>:void=
        race:
            block:
                RebirthedEvent.Await()
            block:
                BegunHosting.Await()
                case(TWC.OnPurchaseFunction)
                {
                PurchaseMovementType.Nothing =>
                    return
                PurchaseMovementType.Show =>
                    TWC.Show(AnimationConfig)
                PurchaseMovementType.Hide =>
                    TWC.Hide(AnimationConfig)
                }

    ManagePrePurchasePropSet<public>(TWC:TWC_unique_prop)<suspends>:void=
        case(TWC.PrePurchaseFunction)
        {
        PropMovementType.Nothing =>
            return
        PropMovementType.Function_As_Button =>
            var SetTimeOut : float = 1.0
            if:
                Owner := MaybeOwner?
            then{
            race:
                loop:
                    Sleep(0.1)
                    if:
                        TimeOut := UsingTimeout[GetSession()]
                        set SetTimeOut = TimeOut
                    then:
                        GlobalSuperlog("Using Timeout for {SetTimeOut}")
                    
                    # Check lock status FIRST
                    if:
                        StartAs = Dependency.Locked
                    then:
                        TWC.Hide(AnimationConfig)
                    else if:
                        IsPurchased = PurchasedStatus.Purchased
                    then:
                        TWC.Hide(AnimationConfig)
                    else if:
                        StartAs = Dependency.Unlocked
                        IsPurchased = PurchasedStatus.NotPurchased
                    then:
                        spawn. TWC.Show(AnimationConfig)

                        if:
                            Player := Owner.Players[0]
                            MeetsConditions[Owner, ConditionsToBuy, Player, CurrencyToSpendID]
                            CanBuy[Owner, Player, Self]
                            TWC.SwitchToGreen[]
                        else if:
                            TWC.SwitchToRed[]

                    race:
                        Owner.MoneyGranted.Await()
                        StatusChange.Await()
                        Owner.NewItemBought.Await()
                        BegunHosting.Await()
                        Owner.AttemptedBaseClaim.Await()
                        block:
                            SetOwnerEvent.Await()
                            Sleep(SetTimeOut)
                    
                RebirthedEvent.Await()
            }
        }

    SetupPropsV2<public>():void=
        for:
            TWC:PropsV2
        do:
            if:
                TWC.OriginProps.Length <= 0
            then:
                set TWC.OriginProps = array{}
                for:
                    PropIn:TWC.props
                do:
                    set TWC.OriginProps += array{origin_prop{prop:=PropIn, origin:=PropIn.GetTransform()}}
            else:
                Print("Already has Origin Props")
        return

    InitalizeVisuals<override>():void=
        if.  Owner := MaybeOwner?
        then:
            VFX.Initialize(Owner)

    InitalizeAudibles<override>():void=
        if.  Owner := MaybeOwner?
        then:
            SFX.Initialize(Owner)

    InitializeFX<override>():void=
        if.  Owner := MaybeOwner?
        then:
            VFX.Initialize(Owner)  
            SFX.Initialize(Owner)
    
    GetStringParams<override>(MaybeP:?player)<transacts>:[string]string=
        var default : [string]string =  map
        {
            "[Name]"=>Name, 
            "[ID]"=>ID, 
            "[Description]"=>Description, 
            "[Price]"=>"{Price}", 
            "[CurrencyToSpendID]"=>"{CurrencyToSpendID}", 
            "[CurrencyToReceiveID]"=>"{CurrencyToReceiveID}", 
            "[GrantAmount]"=>"{GrantAmount}", 
            "[Ptype]"=>"{Ptype.ToStr()}", 
            "[IsPurchased]"=>"{IsPurchased.ToStr()}",
            "[RebirthsNeeded]"=>"{ConditionsToBuy.MinRebirths}",
            "[MinMoneyCondition]"=>{"{ConditionsToBuy.MinCurrencyAmount}"},
            "[MinExperienceDontion]"=>"{ConditionsToBuy.MinPlayerExperience}"
        }
        if:
            MaybeGrantInterval := GrantInterval?
            set default["[GrantInterval]"] = "{MaybeGrantInterval}"
        if:
            Player := MaybeP?
            Owner := MaybeOwner?
            Stats := PlayerStats := GetCoreStats[Player, Owner.Base_Setup.PersistenceCore]
        then:
            if:
                MoneyNeeded := Price - Stats.AssociatedCurrencies[CurrencyToSpendID]
                set default["[MoneyNeeded]"] = "{MoneyNeeded}"
            if:
                RebirthsLeft := ConditionsToBuy.MinRebirths - Stats.Rebirths
                set default["[RebirthsLeft]"] = "{RebirthsLeft}"
        
        return default

    UnlockDependents(Base:base):tuple(int, logic)=
        var anyfailures:logic=false
        var failures:int=0
        for:
            I -> ItemSet:UnlockTheseItems
        do:
            if:
                PurchaseableData := FetchPurchaseableFromPtypeDex[ItemSet.Type, Base, ItemSet.Index]
            then:
                PurchaseableData(0).Unlock()
            else:
                GlobalSuperlog("")
                set anyfailures = true; set failures += 1
                UnlockFailure(ItemSet.Index, ItemSet.Type.ToStr())
        (failures, anyfailures)

    Unlock<override>():void=
        if:
            StartAs = Dependency.Locked
            Owner := MaybeOwner?
        then:
            set StartAs = Dependency.Unlocked
            StatusChange.Signal()
            UnlockEvent.Signal()
            InitializeChildren(Owner, MyIndex)
        else:
            return

        if.  Owner := MaybeOwner?
        then{
        for:
            Player:Owner.Players
        do:
            OnUnlockCinematic.Play(Player)
        return}

    Lock<override>():void=
        if:
            StartAs = Dependency.Unlocked
        then:
            set StartAs = Dependency.Locked
            StatusChange.Signal()
        else:
            return

    TestAndCommitPurchase(Agent:agent)<decides><transacts>:void=
        GlobalSuperlog("== Attempting Purchase == ")
        Player:=player[Agent]
        Owner := MaybeOwner?
        Stats := PlayerStats := GetCoreStats[Player, Owner.Base_Setup.PersistenceCore]
        Owner.Players.Find[Player]
        AssociatedCurrencies := Stats.AssociatedCurrencies
        MoneyAssociatedWith_ToSpendID := AssociatedCurrencies[CurrencyToSpendID]
        MoneyAssociatedWith_ToSpendID >= Price
        MeetsConditions[Owner, ConditionsToBuy, Player, CurrencyToSpendID]
        StartAs = Dependency.Unlocked
        RemoveMoney(Owner, Player, CurrencyToSpendID, Price)
        MoneyAssocatiedWith_ToReceiveID := AssociatedCurrencies[CurrencyToReceiveID]
        return
    
    OnGrantInterval(Agent:agent)<suspends>:void=
        GlobalSuperlog("-Granting Money on Interval")
        if(GA := GrantInterval?;  Owner := MaybeOwner?){if(Owner.MoneyLeague.Update[Owner, CurrencyToReceiveID, GrantAmount, GA]){GlobalSuperlog("Updated MoneyLeague using: {Name}")}}
        loop:
            if:
                GrantInterval? >= 0.0
                Interval := GrantInterval?
                Player : player = player[Agent]
                Owner := MaybeOwner?
                Stats := PlayerStats := GetCoreStats[Player, Owner.Base_Setup.PersistenceCore]
                MoneyToReceive := Stats.AssociatedCurrencies[CurrencyToReceiveID]
                IsPurchased = PurchasedStatus.Purchased
            then:
                Sleep(Interval+0.0)
                GrantMoney(Owner, Player, CurrencyToReceiveID, GrantAmount, BypassZone)   
            else{GlobalSuperlog("No interval set for: {Name}; or interval is less than 0.0; returning..."); return}

    AwaitAttemptedPurchase(PZ:anyzone_or_atm, Hostess:base)<suspends>:void=
        GlobalSuperlog("Awaiting Attempted Purchase for {Name}")
        race:
            block:
                loop:
                    PreventInf();
                    race:
                        block:
                            Agent := Purchase_Zone.PlayerEntersEvent.Await()
                            GlobalSuperlog("Player Enters Event 2")
                        block:
                            Agent := Purchase_Zone.DelayedPlayerEntersEvent.Await()
                            PurchaseSequence(Agent)
            block:
                RebirthedEvent.Await()

    PurchaseSequence(Agent:agent)<suspends>:void=
        if:
            Owner := MaybeOwner?
            Player := player[Agent]
            PlayerStats := Owner.Owner.GetPlayerStats[Player]
            TestAndCommitPurchase[Agent] or DefaultAltClaim? and not PlayerStats.HasClaimedBase?
            IsPurchased = PurchasedStatus.NotPurchased
        then:
            OnPurchaseSuccess(Player)
        else if:
            Player := player[Agent]
        then:
            Result := RetryPurchase(Agent)
            if. Result?
            then. OnPurchaseSuccess(Player)
            else:
                Purchase_Zone.Enable(); 
                HudConfig.OnFailurePlayer(Player)

    RetryPurchase<public>(Agent:agent)<suspends>:logic=
        RetryPeriod : float = 1.0
        X: int = 5
        base_delay : float = RetryPeriod / Pow(2.0,X*1.0 - 1.0)
        race:
            block:
                for(i := 1..X):
                    delay_time : float = base_delay * Pow(2.0, (i*1.0-1.0))
                    Sleep(delay_time)
                    if:
                        TestAndCommitPurchase[Agent]
                        Player := player[Agent]
                        IsPurchased = PurchasedStatus.NotPurchased
                    then:
                        return true
                return false
            block:
                RebirthedEvent.Await()
        return false

    OnPurchaseSuccess(P:player):void=
        if:
            Owner := MaybeOwner?
        then:
            GlobalSuperlog("Success")
            GrantMoney(Owner, P, CurrencyToReceiveID, GrantAmount, BypassZone)
            OnBought(P)
            FirstBought(P)

    OnBought<public>(Agent:agent):void=
        if:
            Player := player[Agent]
            Owner := MaybeOwner?
        then:
            # Always save purchases to persistence (even when loading)
            UpdateAssociatedUnlocks(Player, Ptype, MyIndex, Owner.Base_Setup.PersistenceCore)
            
            UpdateXP(Player, ExperiencePointsToAdd, Owner.Base_Setup.PersistenceCore)
            Accolade.Award(Player)
            GrantXP(Owner, Player, ExperiencePointsToAdd)
            set IsPurchased = PurchasedStatus.Purchased
            
            Purchase_Zone.OnSuccess(Player, true)
            Purchase_Zone.Disable()
            BillboardConfig.Hide()

            OnBoughtEvent.Signal(Player)
            Owner.NewItemBought.Signal(Self)

            # ALWAYS unlock dependents (even when loading from persistence)
            # This ensures dependent items are available after reload
            Result := UnlockDependents(Owner)
            if(Result(1)?){GlobalSuperlog("When Unlocking all dependents, ({Result(0)}) failed to unlock")}
            
            # Only start money generation and hosting if NOT loading
            if(not CanLoad?):
                spawn{OnGrantInterval(Agent)}
                spawn{ManageHost()}
                BegunHosting.Signal()
                VFX.OnEvent(Player)
                SFX.OnEvent(Player)
            else:
                # Loading from persistence - start these too but mark CanLoad as false
                set CanLoad = false
                spawn{OnGrantInterval(Agent)}
                spawn{ManageHost()}
                BegunHosting.Signal()

    # Method called when loading an item from persistence
    LoadFromPersistence<public>(Player:player):void=
        GlobalSuperlog("=== LOADING {Name} FROM PERSISTENCE ===")
        
        # Set CanLoad to true so OnBought knows this is a load operation
        set CanLoad = true
        
        # Call OnBought to set everything up (it WILL unlock dependents)
        OnBought(Player)
        
        GlobalSuperlog("=== FINISHED LOADING {Name} ===")

    FirstBought(Agent:agent):void=
        if:
            Player := player[Agent]
        then:
            OnPurchaseCinematic.Play(Player)
            HudConfig.OnSuccessfullPlayer(Player)
            Print("|==|----[{Name} ]----|==|")
            Print("|==|----[ Successfully Purchased ]----|==|")

    PoorsMansInit<public>():SuperInaugurable=
        Self

basic_prop_buyable<public>:=class<concrete><final>(purchaseable):
    var Ptype <override> :  PurchaseableType = PurchaseableType.BasicProp

    Initialize<override>(Hostess:base, I:int):void=
        (super:)Initialize(Hostess, I)
        Detail("BasicPropBuyable")

    Host<override>()<suspends>:void=
        loop:
            Sleep(Inf);

fxpurchaseable<public>:=class<abstract>(purchaseable, ExpandedFX):
    @editable var FXMain  <public> :  fx_main = fx_main{}
    TrigEvent : event() = event(){}
    var FirstPlayerOnTeam: ?player = false

    InitalizeVisuals<override>():void=
        if:
            Owner := MaybeOwner?
        then:
            VFX.Initialize(Owner)
            FXMain.EventBasedVFX.Initialize(Owner)

    InitalizeAudibles<override>():void=
        if:
            Owner := MaybeOwner?
        then:
            SFX.Initialize(Owner)
            FXMain.EventBasedSFX.Initialize(Owner)

    InitializeFX<override>():void=
        if:
            Owner := MaybeOwner?
        then:
            VFX.Initialize(Owner)  
            FXMain.EventBasedVFX.Initialize(Owner)
            FXMain.EventBasedSFX.Initialize(Owner)
            set FirstPlayerOnTeam = Owner.FindFirstPlayerOnTeam()

    PlayFX<override>():void=
        if:
            Player := FirstPlayerOnTeam?
        then:
            VFX.OnEvent(Player)
            SFX.OnEvent(Player)
            FXMain.EventBasedVFX.OnEvent(Player)
            FXMain.EventBasedSFX.OnEvent(Player)

    StopFX<override>():void=
        VFX.EndEvent()
        SFX.EndEvent()
        FXMain.EventBasedVFX.EndEvent()
        FXMain.EventBasedSFX.EndEvent()

    PlayVisuals<override>():void=
        if:
            Player := FirstPlayerOnTeam?
        then:
            VFX.OnEvent(Player)
            FXMain.EventBasedVFX.OnEvent(Player)

    StopVisuals<override>():void=
        VFX.EndEvent()
        FXMain.EventBasedVFX.EndEvent()

    PlayAudibles<override>():void=
        if:
            Player := FirstPlayerOnTeam?
        then:
            SFX.OnEvent(Player)
            FXMain.EventBasedSFX.OnEvent(Player)

    StopAudibles<override>():void=
        SFX.EndEvent()
        FXMain.EventBasedSFX.EndEvent()

    OnEvent()<suspends>:void=
        TrigEvent.Signal()
        if:
            FXMain.RestartWhenActivated?
        then:
            race:
                block: 
                    Sleep(0.1)
                    AsyncPlayFX(FXMain.FXLength)
                block: 
                    TrigEvent.Await()
                    StopFX()
        else:
            race:
                block: 
                    AsyncPlayFX(FXMain.FXLength)
                block: 
                    TrigEvent.Await()
        
    AsyncPlayFX(Time:float)<suspends>:void={PlayFX(); Sleep(Time); StopFX(); return}