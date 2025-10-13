using { /Verse.org/Simulation }
using {cc}


#Temp states on a game by game basis
playerstats:=class<final><unique>(Rebirthable):

    var HasClaimedBase : ?base = false
    var Player:player


    OnLeave():void=
        if:
            ClaimedBase := HasClaimedBase?
            ClaimedBase.RootPlayer? = Player
        then:
            ClaimedBase.OnRebirth()
            RemoveRebirth(Player, ClaimedBase.Base_Setup.PersistenceCore)
        else:
            GlobalSuperlog("Failed X2")
        set HasClaimedBase = false

    OnRebirth<override>():void=
        if:
            ClaimedBase := HasClaimedBase?
        then:
            set HasClaimedBase = false

    ClaimBase<public>(Base:base)<transacts><decides>:void=
        not HasClaimedBase?
        GlobalSuperlog("Claiming Base -- Passed not HasClaimedBase? Check")
        set HasClaimedBase = option{Base}



#Defines the player profile data class and the map that stores it
player_profile_data := class<final><persistable>:
    Version:int = 0
    CoreSaves  : [int]core_save = map{}


core_save := class <final><persistable>:
    Rebirths:int = 0
    AssociatedCurrencies: [int]int = map{}
    AssociatedUnlocks: []tuple(PurchaseableType, int) = array{}
    Experience : int = 0

 
#Defines the map that stores the player profile data
var PlayerProfileDataMap:weak_map(player, player_profile_data) = map{}




#Creates a new player profile data object
MakePlayerProfileData<constructor>(Src:player_profile_data)<transacts> := player_profile_data:
    CoreSaves:=Src.CoreSaves
    Version := Src.Version+1

MakeCoreSave<constructor>(Src:core_save)<transacts> := core_save:
    AssociatedCurrencies:= Src.AssociatedCurrencies
    AssociatedUnlocks:= Src.AssociatedUnlocks
    Experience := Src.Experience
    Rebirths:=Src.Rebirths

ChangeCoreSave(Src:[int]core_save, id:int, coresave:core_save)<transacts>:[int]core_save=
    var temp: [int]core_save = Src
    if. set temp[id] = coresave; temp

    

RemoveRebirth(P:player, CoreSaveID:int)<transacts>:void=
    
    GlobalSuperlog("Rebirting Player")
    if:
        P.IsActive[]
        Map := PlayerProfileDataMap[P]
    then:
        if:
            EstablishedSave := Map.CoreSaves[CoreSaveID]
            
            NewSave := core_save:
                Rebirths:=EstablishedSave.Rebirths-1
                MakeCoreSave<constructor>(EstablishedSave)

            set PlayerProfileDataMap[P] = player_profile_data:
                CoreSaves:=ChangeCoreSave(Map.CoreSaves, CoreSaveID, NewSave)
                MakePlayerProfileData<constructor>(Map)

            



Rebirth(P:player, CoreSaveID:int)<transacts>:void=
    
    GlobalSuperlog("Rebirting Player")
    if:
        P.IsActive[]
        Map := PlayerProfileDataMap[P]
    then:
        if:
            EstablishedSave := Map.CoreSaves[CoreSaveID]
            
            NewSave := core_save:
                Rebirths:=EstablishedSave.Rebirths+1
                MakeCoreSave<constructor>(EstablishedSave)

            set PlayerProfileDataMap[P] = player_profile_data:
                CoreSaves:=ChangeCoreSave(Map.CoreSaves, CoreSaveID, NewSave)
                MakePlayerProfileData<constructor>(Map)

            

DelidCurrencies(P:player, CoreSaveID:int)<transacts><decides>:void=
    var DelidMap: [int]int = map{}
    for{I := 0..100}
    do{set DelidMap[I] = 0}

    if:
        P.IsActive[]
        Map := PlayerProfileDataMap[P]
    then:
        EstablishedSave := Map.CoreSaves[CoreSaveID]
        NewSave := core_save:
            AssociatedCurrencies := DelidMap
            MakeCoreSave<constructor>(EstablishedSave)


        set PlayerProfileDataMap[P] = player_profile_data:
            CoreSaves:=ChangeCoreSave(Map.CoreSaves, CoreSaveID, NewSave)
            MakePlayerProfileData<constructor>(Map)
        

DelidUnlocks(P:player, CoreSaveID:int)<transacts><decides>:void=
    var DelidMap: []tuple(PurchaseableType, int) = array{}
    if:
        P.IsActive[]
        Map := PlayerProfileDataMap[P]

        EstablishedSave := Map.CoreSaves[CoreSaveID]
        NewSave := core_save:
            AssociatedUnlocks := DelidMap
            MakeCoreSave<constructor>(EstablishedSave)


        set PlayerProfileDataMap[P] = player_profile_data:
            CoreSaves:=ChangeCoreSave(Map.CoreSaves, CoreSaveID, NewSave)
            MakePlayerProfileData<constructor>(Map)

#Updates the associated currencies for a player
UpdateAssociatedCurrencies(P:player, CurrencyKey:int, CurrencyValue:int, CoreSaveID:int)<transacts>:void=
    if:
        P.IsActive[]
        Map := PlayerProfileDataMap[P]
        EstablishedSave := Map.CoreSaves[CoreSaveID]
        

        var PastCurrency : [int]int = Map.CoreSaves[CoreSaveID].AssociatedCurrencies
        set PastCurrency[CurrencyKey] = CurrencyValue

        NewSave := core_save:
            AssociatedCurrencies := PastCurrency
            MakeCoreSave<constructor>(EstablishedSave)

        set PlayerProfileDataMap[P] = player_profile_data:
            CoreSaves:=ChangeCoreSave(Map.CoreSaves, CoreSaveID, NewSave)
            MakePlayerProfileData<constructor>(Map)


UpdateAssociatedUnlocks(P:player, KeyType:PurchaseableType, Index:int, CoreSaveID:int)<transacts>:void=
    if:
        P.IsActive[]
        Map := PlayerProfileDataMap[P]

        EstablishedSave := Map.CoreSaves[CoreSaveID]
        NewSave := core_save:
            AssociatedUnlocks := Map.CoreSaves[CoreSaveID].AssociatedUnlocks + array{(KeyType, Index)}
            MakeCoreSave<constructor>(EstablishedSave)

        set PlayerProfileDataMap[P] = player_profile_data:
            CoreSaves:=ChangeCoreSave(Map.CoreSaves, CoreSaveID, NewSave)
            MakePlayerProfileData<constructor>(Map)
            
                


            
UpdateXP(P:player, XP:int, CoreSaveID:int)<transacts>:void=
    if:
        P.IsActive[]
        Map := PlayerProfileDataMap[P]

        EstablishedSave := Map.CoreSaves[CoreSaveID]
        NewSave := core_save:
            Experience := XP
            MakeCoreSave<constructor>(EstablishedSave)

        set PlayerProfileDataMap[P] = player_profile_data:
            CoreSaves:=ChangeCoreSave(Map.CoreSaves, CoreSaveID, NewSave)
            MakePlayerProfileData<constructor>(Map)

# Update hitable progress in persistence
UpdateHitableProgress(P:player, HitableKey:int, Level:int, XP:int, CoreSaveID:int)<transacts><decides>:void=
    if:
        P.IsActive[]
        Map := PlayerProfileDataMap[P]
    then:
        if:
            EstablishedSave := Map.CoreSaves[CoreSaveID]
        then:
            # Encode level and XP into single integer: Level * 10000 + XP
            EncodedValue := (Level * 10000) + XP
            
            var PastCurrency : [int]int = Map.CoreSaves[CoreSaveID].AssociatedCurrencies
            set PastCurrency[HitableKey] = EncodedValue

            NewSave := core_save:
                AssociatedCurrencies := PastCurrency
                MakeCoreSave<constructor>(EstablishedSave)

            set PlayerProfileDataMap[P] = player_profile_data:
                CoreSaves:=ChangeCoreSave(Map.CoreSaves, CoreSaveID, NewSave)
                MakePlayerProfileData<constructor>(Map)

#Gets the associated currencies for a player
GetStats(Agent:agent)<decides><transacts>:player_profile_data=
{
    var PlayerStats : player_profile_data = player_profile_data{}
    if:
        Player := player[Agent]
        PlayerStatsTable := PlayerProfileDataMap[Player]
        set PlayerStats = MakePlayerProfileData(PlayerStatsTable)
    then:
    PlayerStats
}
     
GetCoreStats(Agent:agent, CoreStatsID:int)<decides><transacts>:core_save=
    {
        var PlayerStats : player_profile_data = player_profile_data{}
        if:
            Player := player[Agent]
            PlayerStatsTable := PlayerProfileDataMap[Player]
            set PlayerStats = MakePlayerProfileData(PlayerStatsTable)
        then:
        PlayerStats.CoreSaves[CoreStatsID]
    }
