using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using {/Fortnite.com/Teams}
using {cc}

dancefloor_buyable<public>:=class<concrete><final>(purchaseable):

    @editable var dancefloorconfig : unique_dancefloor_buyable = unique_dancefloor_buyable{}
    var Ptype <override> :  PurchaseableType = PurchaseableType.DanceFloor
    
    Initialize<override>(Hostess:base, I:int):void=
        #Calls the parent class's Initialize method
        (super:)Initialize(Hostess, I)

        #Initalizes the dancefloor config
        dancefloorconfig.Initialize(Hostess)
        
        #Lists out all the properties of the item
        Detail("DancefloorBuyable")

 
        
    #Host the dance
    Host<override>()<suspends>:void=
        dancefloorconfig.Enable()
        loop{
            Player := dancefloorconfig.OnEmote.Await()
            race:
                dancefloorconfig.OnEmoteStop.Await()
                GrantOvertime(Player)

        }
    GrantOvertime(Agent:agent)<suspends>:void=
        loop:
            if:
                Player := player[Agent]
                Owner := MaybeOwner?
            then:
                Sleep(dancefloorconfig.EmoteGrantInterval)
                GrantMoney(Owner, Player, dancefloorconfig.CurrencyOnEmoteID, dancefloorconfig.OnEmoteIntervalGrantAmount, BypassZone)
                GrantXP(Owner, Player, dancefloorconfig.OnEmoteIntervalExperienceAmount)
                
                # Award XP accolade while dancing
                dancefloorconfig.DanceXPAccolade.Award(Player)
                
                # Use the dancefloor-specific HUD config
                dancefloorconfig.EmoteHudConfig.OnSuccessfullPlayer(Player)

unique_dancefloor_buyable:=class<concrete>(Toggleable, Inaugurable, StringReturnables):

    #The currency ID that will be granted to the player when emoting
    @editable var CurrencyOnEmoteID  : int = {0}

    #The amount of money that will be granted to the player when emoting
    @editable var OnEmoteIntervalGrantAmount : int = {0}

    #The amount of experience that will be granted to the player when emoting
    @editable var OnEmoteIntervalExperienceAmount : int = {0}

    @editable var EmoteGrantInterval : float = {0.5}
    
    #Mutator zone device that detects emoting
    @editable var EmoteDetector : mutator_zone_device = mutator_zone_device{}

    # Add a separate HUD config for emoting rewards
    @editable var EmoteHudConfig : hud_main = hud_main{
        OnFailedMessage := option{""}
        OnSuccessMessage := option{"+ [GrantAmount] currency from dancing!"}
    }
    
    # Accolades device for XP while dancing
    @editable var DanceXPAccolade : accolades_device = accolades_device{}

    OnEmote : event(agent) = event(agent){}
    OnEmoteStop : event(agent) = event(agent){}


    Disable<override>():void={EmoteDetector.Disable()}
    Enable<override>():void={EmoteDetector.Enable()}

    Initialize<override>(Base:base):void={
        Disable()
        # Initialize the emote HUD config with this class as the string provider
        EmoteHudConfig.Initialize(Self)
        spawn{AwaitEmote(Base)}
        spawn{AwaitEmoteEnd(Base)}
    }

    # Implement GetStringParams to provide values for HUD message placeholders
    GetStringParams<override>(P:?player)<transacts>:[string]string=
        map{
            "[GrantAmount]" => "{OnEmoteIntervalGrantAmount}",
            "[CurrencyID]" => "{CurrencyOnEmoteID}",
            "[Experience]" => "{OnEmoteIntervalExperienceAmount}"
        }

    AwaitEmote(Base:base)<suspends>:void={
        loop:
            Player := EmoteDetector.AgentBeginsEmotingEvent.Await()
            OnEmote.Signal(Player)
    }
    AwaitEmoteEnd(Base:base)<suspends>:void={
        loop:
            Player := EmoteDetector.AgentEndsEmotingEvent.Await()
            OnEmoteStop.Signal(Player)
    }