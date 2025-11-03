using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using {Purchaseables}
using {/Fortnite.com/Teams}
using { /Fortnite.com/Characters }
using { /Verse.org/Random }
using { /UnrealEngine.com/Temporary/SpatialMath }
using {Runtimeinstantiables}
using {HudSystem}
using {cc}
using {Stomper}

base<public>:=class<concrete><unique>(SuperInaugurable, Rebirthable, Runtime, StringReturnables, creative_device):

    var UniqueID:string = ""
    var selfindex:int = -1
    var Status : ClaimStatus = ClaimStatus.Unclaimed
    var Players: []player = array{}
    var RootPlayer : ?player = false
    var Owner:tycoon_stomper = tycoon_stomper{}
    var Rebirthed: event(player) = event(player){}
    var MoneyLeague : money_league = money_league{}
    var MoneyGranted : event(tuple(player, int, int)) = event(tuple(player, int, int)){}
    var NewItemBought : event(purchaseable) = event(purchaseable){}
    var CFR : ClaimFauilreReason = ClaimFauilreReason.TooManyPlayers

    @editable var LeaveButton : button_device = button_device{}
    @editable var Base_Setup : base_setup = base_setup{}
    @editable var BasicProps: []basic_prop_buyable = array{}
    @editable var Collectables: []unique_collectable = array{}
    @editable var Conveyors: []purchaseable_conveyor = array{}
    @editable var Currencies : []currency_config = array{}
    @editable var DanceFloors: []dancefloor_buyable = array{}
    @editable var Droppers: []purchaseable_dropper = array{}
    @editable var Gifts: []unique_giftable = array{}
    @editable var Hitables: []hitable_buyable = array{}
    @editable var MoneyWheel: []unique_moneywheel = array{}
    @editable var NPCSpawners: []npc_buyable = array{}
    @editable var Pets: []pet = array{}
    @editable var Shootables: []shootable_buyable = array{}
    @editable var Upgraders: []purchaseable_upgrader = array{}
    @editable var UIConfig : []currency_ui_config = array{}

    var PlayerToPetMap : [player]tuple(pet, logic) = map{}
    var AttemptedBaseClaim : event() = event(){}
    petmaxreached : event(player) = event(player){}

    GetPurchaseArray():[][]purchaseable=
        array
        {
            BasicProps, 
            NPCSpawners, 
            Droppers, 
            Conveyors, 
            Upgraders, 
            Hitables, 
            Shootables, 
            DanceFloors, 
            Pets
        }

    SizeLimit : int = 1

    InitializeAgent(A:agent)<transacts>:void=
        if:
            Player := player[A]
            not PlayerProfileDataMap[Player]
            set PlayerProfileDataMap[Player] = player_profile_data{}
        then:
            Owner.Config.Superlog("Inited player profile data")
            for:
                X := 0..100
                PlayerData := GetStats[Player]
            do:
                Source := player_profile_data:
                    CoreSaves:=ChangeCoreSave(PlayerData.CoreSaves, X, core_save{})
                    MakePlayerProfileData<constructor>(PlayerData)
                if. set PlayerProfileDataMap[Player] = Source
                if. DelidCurrencies[Player, Base_Setup.PersistenceCore]

        if:
            Player := player[A]
            not Base_Setup.PersistCurrencies?
            DelidCurrencies[Player, Base_Setup.PersistenceCore]

        if:
            Player := player[A]
        then:
            if(set PlayerToPetMap[Player] = (pet{}, false)){}

    OnBegin<override>(IX:int):void=
        Base_Setup.OnBegin(Self, -1)
        Initialize(Self, IX)

    OnBought(Agent:agent)<suspends>:void=
        InitializeAgent(Agent)
        Print("Attempting to claim base")
        Base_Setup.BillBoardConfig.Instantiate()
        if:
            AttemptClaimBase[Agent]
            Status = ClaimStatus.Unclaimed
            Player := player[Agent]
            TempStats := Owner.GetPlayerStats[Player]
            TempStats.ClaimBase[Self]
            PlayerStats := GetCoreStats[Player, Base_Setup.PersistenceCore]
            AssociatedUnlocks := PlayerStats.AssociatedUnlocks
        then:
            if:
                not RootPlayer?
            then:
                set RootPlayer = option{Player}
            set Owner.UnclaimedBases = Owner.UnclaimedBases.RemoveAllElements(Self)
            Base_Setup.PurchaseableConfigs.Purchase_Zone.OnSuccess(Player, false)
            
            # Load unlocks FIRST before showing anything
            if:
                Base_Setup.PersistUnlocks?
            then:
                for:
                    AUnlock : AssociatedUnlocks
                do:
                    GlobalSuperlog("Loading unlock: Type={AUnlock(0).ToStr()}, Index={AUnlock(1)}")
                    Load(Self, AUnlock(0), AUnlock(1))
            else if:
                DelidUnlocks[Player, Base_Setup.PersistenceCore]
            
            # NOW show everything else AFTER loading
            for(I ->IGifts: Gifts){IGifts.InitGiftable(Player)}
            Base_Setup.VFX.OnEvent(Player)
            Owner.Config.Superlog("Player has {PlayerStats.Rebirths} Rebirths")
            
            for(Collectable:Collectables){Collectable.Show(Self)}
            Base_Setup.HudConfig.Initialize(Self)
            Base_Setup.HudConfig.OnSuccessfullPlayer(Player)
            UI := currency_ui{Player:=Player,  Configs:=UIConfig, owner:=Self}
            UI.Create()
            spawn{AwaitUIDestroy(UI)}
            
            if:
                Players.Length < SizeLimit
            then:
                GlobalSuperlog("Still in the size limit")
            else:
                Base_Setup.PurchaseableConfigs.Purchase_Zone.Hide(true)
                Base_Setup.BillBoardConfig.Hide()

            AttemptedBaseClaim.Signal()
        else if:
            Player := player[Agent]
        then:
            if:
                not AttemptClaimBase[Player]
            then:
                set CFR = ClaimFauilreReason.TooManyPlayers
            else if:
                TempStats := Owner.GetPlayerStats[Player]
                not TempStats.ClaimBase[Self]
            then:
                set CFR = ClaimFauilreReason.AlreadyOwnsBase

            Base_Setup.HudConfig.OnFailurePlayer(Player)
            Print("Base is already claimed or size limit was reached (Status: [== {CFR.ToStr()} ==]")

    AwaitBaseClaim(IX:int)<suspends>:void=
        Print("== {Base_Setup.Name} Successfully Initialized ==")
        loop:
            PreventInf();
            Agent := Base_Setup.PurchaseableConfigs.OnBoughtEvent.Await()
            GlobalSuperlog("ON BOUGHT EVENT")
            OnBought(Agent)

    AwaitUIDestroy(UI:currency_ui)<suspends>:void=
        loop:
            Rebirthed.Await()
            UI.Destroy();

    AttemptClaimBase(A:agent)<transacts><decides>:void=
        Owner.Config.Superlog("=Attempting to claim base=")
        if:
            Players.Length < SizeLimit
            Player := player[A]
        then:
            AddToTeam(Player)
            Print("== Base Successfully Claimed ==")
        else:
            set Status = ClaimStatus.Claimed
            Owner.Config.Superlog("Setting status to claimed")

    AwaitRebirth()<suspends>:void=
    {
        Base_Setup.RebirthConfig.HudConfig.Initialize(Self)
        loop:
            Interactor := Base_Setup.RebirthConfig.RebirthButton.ActivatedEvent.Await()
            if:
                Player := player[Interactor]
                PlayerStats := GetCoreStats[Player, Base_Setup.PersistenceCore]
                Rebirths := PlayerStats.Rebirths
                RebirthCurrencyValue := PlayerStats.AssociatedCurrencies[Base_Setup.RebirthConfig.RebirthCostCurrencyID]
                RebirthCostAmount := GetRebirthCostAmount[Self, Rebirths]
                RebirthCurrencyValue >= RebirthCostAmount
            then:
                Rebirthed.Signal(Player)
                OnRebirth()
            else if:
                Player := player[Interactor]
            then:
                Base_Setup.RebirthConfig.HudConfig.OnFailurePlayer(Player)
    }

    OnRebirth<override>():void=
        Owner.Config.Superlog("Attempting Rebirth")
        (GetPurchaseArray()).RebirthList(Self)
        Base_Setup.PurchaseableConfigs.OnRebirth()
        set Status = ClaimStatus.Unclaimed
        Base_Setup.PurchaseableConfigs.Purchase_Zone.Show()
        set MoneyLeague = money_league{}

        for:
            Player:Players
            DelidCurrencies[Player, Base_Setup.PersistenceCore]
            DelidUnlocks[Player, Base_Setup.PersistenceCore]
            TempStats := Owner.GetPlayerStats[Player]
        do:
            TempStats.OnRebirth()
            Rebirth(Player, Base_Setup.PersistenceCore)
            Base_Setup.RebirthConfig.HudConfig.OnSuccessfullPlayer(Player)
            Base_Setup.RebirthConfig.RebirthAccolade.Award(Player)
            set Players = Players.RemoveAllElements(Player)
            
        set Players = array{}
        set RootPlayer = false
        set Owner.UnclaimedBases += array{Self}
        if:
            tempid := CreateID[15]
            set UniqueID = tempid
        then:
            Owner.Config.Superlog("Base ID is {UniqueID}")
        return

    AwaitOnLeave()<suspends>:void=
        loop:
            Agent := LeaveButton.InteractedWithEvent.Await()
            if:
                Player := player[Agent]
                StatsMap := Owner.PlayerStatsMap[Player]?
                Players.Find[Player]
            then:
                StatsMap.OnLeave()

    Initialize<override>(Base:base, IX:int):void=
        set Status = ClaimStatus.Unclaimed
        set selfindex = IX
        spawn{AwaitOnLeave()}
        spawn{AwaitRebirth()}
        spawn{AwaitBaseClaim(IX)}

        if(ID := CreateID[15]){set UniqueID = ID}
        Owner.Config.Superlog("Base ID is {UniqueID}")
        
        Base_Setup.VFX.Initialize(Self)
        Base_Setup.SFX.Initialize(Self)
        Base_Setup.Initialize(Self)

        for(I -> ICurrency: Currencies){ICurrency.Initialize(Self)}
        for(I ->ICollectable: Collectables){ICollectable.Initialize(Self)}
        for(I ->IGifts: Gifts){IGifts.Initialize(Self)}
        for(I ->IMoneywheel: MoneyWheel){IMoneywheel.Initialize(Self)}
        (GetPurchaseArray()).InitList(Self)

    AddToTeam(Player:player)<transacts>:void=
        if:
            not Player.IsOnTeam[]
            Players.Length < SizeLimit
        then:
            set Players += array{Player}
            TC := Owner.GetPlayspace().GetTeamCollection()
            Teams := TC.GetTeams()
            if(TC.AddToTeam[Player, Teams[Base_Setup.TeamToAddTo]]){}
        else:
            Owner.Config.Superlog("Player is already on the team or size limit was reached")

    (Player:player).IsOnTeam()<transacts><decides>:int={I := Players.Find[Player]; I}

    FindFirstPlayerOnTeam():?player={
        if: 
            Player := Players[0]
        then:
            option{Player}
        else:
            false
        }

    GetStringParams<override>(P:?player)<transacts>:[string]string=
        return map
        {
            "[Name]"=>Base_Setup.Name, 
            "[ID]"=>UniqueID, 
            "[Players.Length]"=>"{Players.Length}", 
            "SizeLimit"=>"{SizeLimit}", 
            "[Status]"=>"{Status.ToStr()}",
            "[FailureReason]"=>"{CFR.ToStr()}"
        }