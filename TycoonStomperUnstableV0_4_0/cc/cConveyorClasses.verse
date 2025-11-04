
using { /Verse.org/Random }
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/SpatialMath }
using {Purchaseables}
using {Runtimeinstantiables}
using {cc}

<#

░█████╗░██╗░░░██╗░██████╗████████╗░█████╗░███╗░░░███╗  ░█████╗░░█████╗░███╗░░██╗██╗░░░██╗███████╗██╗░░░██╗░█████╗░██████╗░
██╔══██╗██║░░░██║██╔════╝╚══██╔══╝██╔══██╗████╗░████║  ██╔══██╗██╔══██╗████╗░██║██║░░░██║██╔════╝╚██╗░██╔╝██╔══██╗██╔══██╗
██║░░╚═╝██║░░░██║╚█████╗░░░░██║░░░██║░░██║██╔████╔██║  ██║░░╚═╝██║░░██║██╔██╗██║╚██╗░██╔╝█████╗░░░╚████╔╝░██║░░██║██████╔╝
██║░░██╗██║░░░██║░╚═══██╗░░░██║░░░██║░░██║██║╚██╔╝██║  ██║░░██╗██║░░██║██║╚████║░╚████╔╝░██╔══╝░░░░╚██╔╝░░██║░░██║██╔══██╗
╚█████╔╝╚██████╔╝██████╔╝░░░██║░░░╚█████╔╝██║░╚═╝░██║  ╚█████╔╝╚█████╔╝██║░╚███║░░╚██╔╝░░███████╗░░░██║░░░╚█████╔╝██║░░██║
░╚════╝░░╚═════╝░╚═════╝░░░░╚═╝░░░░╚════╝░╚═╝░░░░░╚═╝  ░╚════╝░░╚════╝░╚═╝░░╚══╝░░░╚═╝░░░╚══════╝░░░╚═╝░░░░╚════╝░╚═╝░░╚═╝

░█████╗░██╗░░░░░░█████╗░░██████╗░██████╗███████╗░██████╗░░░██╗░░░██╗███████╗██████╗░░██████╗███████╗
██╔══██╗██║░░░░░██╔══██╗██╔════╝██╔════╝██╔════╝██╔════╝░░░██║░░░██║██╔════╝██╔══██╗██╔════╝██╔════╝
██║░░╚═╝██║░░░░░███████║╚█████╗░╚█████╗░█████╗░░╚█████╗░░░░╚██╗░██╔╝█████╗░░██████╔╝╚█████╗░█████╗░░
██║░░██╗██║░░░░░██╔══██║░╚═══██╗░╚═══██╗██╔══╝░░░╚═══██╗░░░░╚████╔╝░██╔══╝░░██╔══██╗░╚═══██╗██╔══╝░░
╚█████╔╝███████╗██║░░██║██████╔╝██████╔╝███████╗██████╔╝██╗░░╚██╔╝░░███████╗██║░░██║██████╔╝███████╗
░╚════╝░╚══════╝╚═╝░░╚═╝╚═════╝░╚═════╝░╚══════╝╚═════╝░╚═╝░░░╚═╝░░░╚══════╝╚═╝░░╚═╝╚═════╝░╚══════╝

█▀▄ █▀▀ █░█ █▀▀ █░░ █▀█ █▀█ █▀▀ █▀▄   █▄▄ █▄█   ▀█▀ █▀ ▄▀█ █▀█
█▄▀ ██▄ ▀▄▀ ██▄ █▄▄ █▄█ █▀▀ ██▄ █▄▀   █▄█ ░█░   ░█░ ▄█ █▀█ █▀▄

▄▀█ █░░ █░░   █▀█ █ █▀▀ █░█ ▀█▀ █▀   █▀█ █▀▀ █▀ █▀▀ █▀█ █░█ █▀▀ █▀▄
█▀█ █▄▄ █▄▄   █▀▄ █ █▄█ █▀█ ░█░ ▄█   █▀▄ ██▄ ▄█ ██▄ █▀▄ ▀▄▀ ██▄ █▄▀

█▀▄ █▀█   █▄░█ █▀█ ▀█▀   █▀ █▀▀ █░░ █░░
█▄▀ █▄█   █░▀█ █▄█ ░█░   ▄█ ██▄ █▄▄ █▄▄

SIMPLIFIED FIX - Stays close to original working code
- Fixed: Only first dropper giving currency (StartDex instead of 0)
- Fixed: Props persist after rebirth (track and cleanup spawned props)
- Simpler approach that doesn't interfere with the working race condition
#>



#Create a custom waypointable class that can be used to create items that can Link to `waypoints` such as: custom droppers and upgraders
custom_waypointable<public>:=class<concrete>(SuperClassInaugurable):
    

    @editable prop  <public>       :        creative_prop        =     creative_prop{}
    @editable Type  <public>       :        types                  =   types.corner

    var LocalOwner : ?purchaseable = false
    var Placed:logic=false


    Action(_Waypoint:waypoint, _Conveyor:custom_conveyor, StartDex:int)<suspends>:void=
        if:
            Location := _Waypoint.OffConveyorLocation?
            Rotation := _Waypoint.OffConveyorRotation?
            prop.TeleportTo[vector3{X:=Location.X, Y:=Location.Y, Z:=Location.Z-300.0}, rotation{}]
        then:
            prop.MoveTo(Location, Rotation, 2.0)
        return
    Initialize<override>(Owner:purchaseable):void=
        set LocalOwner = option{Owner}

        
    
    



    GetAssociatedValue<public>():vector2={vector2{X:=0.0, Y:=0.0}}

custom_dropper<public>:=class<concrete>(custom_waypointable):
    @editable ExitHeight    :        float               =   {200.0}
    @editable PropSpawn     :        creative_prop_asset   =   {DefaultCreativePropAsset}
    @editable PropSpawnRate :        float                 =   {1.0}
    @editable Type<override>           :        types      =   types.dropper
    @editable CubeValue : float = 100.0
    @editable GrantID : int = 0

    # Track spawned props for cleanup
    var SpawnedProps : []creative_prop = array{}
    


    GetAssociatedValue<override>():vector2=
        vector2{X:=CubeValue, Y:=CubeValue}

    Action<override>(_Waypoint:waypoint, _Conveyor:custom_conveyor, StartDex:int)<suspends>:void=
        GlobalSuperlog("=== DROPPER ACTION STARTED - Moving dropper prop into position ===")
        (super:)Action(_Waypoint, _Conveyor, StartDex)
        GlobalSuperlog("=== DROPPER IN POSITION - Starting spawn loop ===")
        loop:
            Sleep(PropSpawnRate)
            GlobalSuperlog("Spawning prop from dropper")
            spawn{SpawnProp(_Conveyor, StartDex)}

    # Simple cleanup - dispose all tracked props
    CleanupAllProps<public>():void=
        for(Prop : SpawnedProps):
            Prop.Dispose()
        set SpawnedProps = array{}
    
            
    SpawnProp(_Conveyor:custom_conveyor, StartDex:int)<suspends>:void=
        GlobalSuperlog(">>> SpawnProp called with StartDex={StartDex}")
        var CurrentCubeValue : float = 0.0
        Sleep(0.1); set CurrentCubeValue = CubeValue
        
        GlobalSuperlog("Attempting to spawn prop...")
        MaybeSpawnedProp := SpawnProp(PropSpawn, vector3{X:=0.0,Y:=0.0,Z:=0.0}, rotation{})
        
        if:
            SpawnedProp := MaybeSpawnedProp(0)?
        then:
            GlobalSuperlog("Prop spawned successfully")
            # Add to tracking array
            set SpawnedProps += array{SpawnedProp}
            
            SpawnedProp.Hide()
            GlobalSuperlog("Prop hidden, starting movement loop")
            
            var ActiveDex: int = StartDex
                loop:
                    GlobalSuperlog("Loop iteration: ActiveDex={ActiveDex}")
                    if:
                        CNextWaypoint := _Conveyor.ConveyorWaypoints[ActiveDex]
                        CNextWaypointLocation := CNextWaypoint.Location
                        CNextWaypointLocationValue := CNextWaypointLocation.GetTransform().Translation
                        TransformMain := transform{Translation:=SpawnedProp.GetTransform().Translation, Scale:=vector3{X:=0.25, Y:=0.25, Z:=0.25}}
                        NextLocation := transform{Translation:=CNextWaypointLocationValue, Scale:=vector3{X:=0.25, Y:=0.25, Z:=0.25}}
                        SpawnedProp.TeleportTo[TransformMain]
                    then:
                        GlobalSuperlog("Waypoint found, moving prop")
                        # FIXED: Use StartDex instead of hardcoded 0
                        if. ActiveDex = StartDex then{
                            GlobalSuperlog("First waypoint - teleporting to height and dropping")
                            TargetPos := vector3{X:=CNextWaypointLocationValue.X,Y:=CNextWaypointLocationValue.Y,Z:=CNextWaypointLocationValue.Z+ExitHeight}
                            GlobalSuperlog("Target position: X={TargetPos.X}, Y={TargetPos.Y}, Z={TargetPos.Z}")
                            
                            if(SpawnedProp.TeleportTo[TargetPos, rotation{}]){
                                GlobalSuperlog("Teleport successful! Starting MoveTo and ShowAfter")
                                spawn{ShowAfter(SpawnedProp, (55.0/ExitHeight)/10.0)}
                                SpawnedProp.MoveTo(NextLocation, 55.0/ExitHeight)
                                GlobalSuperlog("MoveTo called")
                            }
                            else:
                                GlobalSuperlog("ERROR: Teleport FAILED!")

                        } 
                        else if:
                            DistanceToNextWaypoint := Distance(SpawnedProp.GetTransform().Translation, _Conveyor.ConveyorWaypoints[ActiveDex].Location.GetTransform().Translation)
                        then:
                            SpawnedProp.MoveTo(NextLocation, DistanceToNextWaypoint/_Conveyor.ConveyorSpeed)
                        if:
                            CNextWaypoint.Input = types.upgrader
                            LinkedItem := CNextWaypoint.LinkedItem?
                        then:
                            set CurrentCubeValue *= GetRandomFloat(LinkedItem.GetAssociatedValue().X,LinkedItem.GetAssociatedValue().Y)
                        set ActiveDex += 1
                    else if:
                        LastWaypoint := _Conveyor.ConveyorWaypoints[ActiveDex-1]
                        LastWaypoint.Input = types.end
                    then:
                        GlobalSuperlog("Prop reached end waypoint")
                        
                        if:
                            Owner := LocalOwner?
                        then:
                            GlobalSuperlog("Owner found: {Owner.Name}")
                            
                            if:
                                Base := Owner.MaybeOwner?
                            then:
                                GlobalSuperlog("Base found: {Base.Base_Setup.Name}")
                                GlobalSuperlog("Base has {Base.Players.Length} players")
                                
                                if:
                                    Player := Base.Players[0]
                                then:
                                    GlobalSuperlog("Player found successfully")
                                    
                                    # Check if player is actually in the base's player list
                                    if:
                                        Base.Players.Find[Player]
                                    then:
                                        GlobalSuperlog("Player IS in base player list - calling GrantMoney")
                                    else:
                                        GlobalSuperlog("ERROR: Player NOT in base player list!")
                                    
                                    if:
                                        Value := Ceil[CurrentCubeValue]
                                    then:
                                        GlobalSuperlog("About to call GrantMoney with GrantID={GrantID}, Value={Value}")
                                        GrantMoney(Base, Player, GrantID, Value, Owner.BypassZone)
                                        GlobalSuperlog("GrantMoney returned")
                                else:
                                    GlobalSuperlog("ERROR: No player at Base.Players[0]")
                            else:
                                GlobalSuperlog("ERROR: Owner.MaybeOwner failed - no Base")
                        else:
                            GlobalSuperlog("ERROR: LocalOwner not set")
                        
                        Sleep(0.01); SpawnedProp.Dispose(); return
                    else:
                        GlobalSuperlog("ERROR: cube reached an invalid waypoint")
                        SpawnedProp.Dispose(); return
        else:
            GlobalSuperlog("ERROR: Failed to spawn prop from PropSpawn asset!")

    ShowAfter(Prop:creative_prop, Delay:float)<suspends>:void=
        GlobalSuperlog("ShowAfter waiting {Delay} seconds...")
        Sleep(Delay)
        Prop.Show()
        GlobalSuperlog("Prop shown!")
        return
       
       
        
custom_upgrader<public>:=class<concrete>(custom_waypointable):
    #editable ApplyAffect
    @editable Type<override>           :        types      =   types.upgrader
    @editable MuliplyValueRange : vector2 = vector2{X:=100.0, Y:=200.0}

    GetAssociatedValue<override>():vector2=
        MuliplyValueRange

    Action<override>(_Waypoint:waypoint, _Conveyor:custom_conveyor, StartDex:int)<suspends>:void=
        (super:)Action(_Waypoint, _Conveyor, StartDex)


custom_conveyor<public>:=class<concrete>(Inaugurable):

    var NewLink : event(custom_waypointable) = event(custom_waypointable){} 

    @editable ConveyorSpeed <public>           :     float               =       {100.0}
    @editable ConveyorWaypoints <public>       :     []waypoint          =       array{}


    FindLastWaypoint<public>()<decides><transacts>:waypoint=
        EndWaypoints := for:
            I -> Waypoint : ConveyorWaypoints
        do:
            Waypoint.Input = types.end
            Waypoint

        EndWaypoints[0]


    GetDistanceToLastWaypoint<public>(InputDistance:vector3)<transacts><decides>:float=
        LastWaypointLocation := FindLastWaypoint[].Location.GetTransform().Translation
        Distance(InputDistance, LastWaypointLocation)


    
    Initialize<override>(Base:base):void=
        for:
            I -> Waypoint : ConveyorWaypoints
        do:
            Waypoint.Initialize(Base)


    OnBegin<public>():void=
        for:
            I -> Waypoint : ConveyorWaypoints
        do:
            Waypoint.Play(Self, I)

        


        


waypoint<public>:=class<concrete><final>(Inaugurable):

    var NewLink : event() = event(){} 
    @editable OffConveyorLocation : ?vector3 = option{vector3{}}
    @editable OffConveyorRotation : ?rotation = option{rotation{}}
    @editable Location  : creative_prop = creative_prop{}
    @editable Input     : types = types.corner
    var LinkedItem: ?custom_waypointable = false
    var Owner: ?custom_conveyor = false
    var StartDex : int = 0
    var MaybeOrigin : ?transform = option{transform{}}

    Initialize<override>(Base:base):void=
        Location.Hide()

    Play(_Owner:custom_conveyor, _StartDex:int):void=
        set Owner = option{_Owner}; set StartDex = _StartDex
        Location.Hide()
    Link<public>(Item:custom_waypointable):void = 
        GlobalSuperlog("=== LINKING ATTEMPT ===")
        if:
            _Owner := Owner?
            Item.Type = Input
            not Item.Placed?
        then:
            GlobalSuperlog("Link successful - Item type matches and not already placed")
            Item.prop.Show()
            set Item.Placed = true
            set LinkedItem = option{Item}
            NewLink.Signal()
            spawn{ManageLinkedItem()}
            GlobalSuperlog("Linked and spawned ManageLinkedItem")
            if:
                not MaybeOrigin?
            then:
                set MaybeOrigin = option{Item.prop.GetTransform()}
        else:
            GlobalSuperlog("=== LINK FAILED ===")
            if (Item.Type = Input):
                if (Item.Placed?):
                    GlobalSuperlog("Item already placed at another waypoint")
                else:
                    GlobalSuperlog("Item not placed but link still failed")
            else:
                GlobalSuperlog("Type mismatch")





    
    Unlink<public>(Item:custom_waypointable):void=
        set Item.Placed = false
        
        # Cleanup dropper props if this is a dropper
        if:
            Dropper := custom_dropper[Item]
        then:
            Dropper.CleanupAllProps()
        
        if:
            BItem := LinkedItem?
            Origin := MaybeOrigin?
            
            BItem.prop.Hide()
        then:
            GlobalSuperlog("Unlinked")
            NewLink.Signal()
            if(BItem.prop.TeleportTo[Origin]){GlobalSuperlog("Teleported {Origin.Translation}")}
            


    ManageLinkedItem()<suspends>:void=
            GlobalSuperlog("=== ManageLinkedItem STARTED ===")
            if:
                Item := LinkedItem?
                _Owner := Owner?
            then:
                GlobalSuperlog("Item and Owner found")
                if:
                    Item.Type = types.dropper
                then:
                    GlobalSuperlog("Item is a dropper - calling Action directly")
                    # Just call Action directly - it has its own infinite loop
                    Item.Action(Self, _Owner, StartDex)
                else:
                    GlobalSuperlog("Item is not a dropper - calling Action directly")
                    Item.Action(Self, _Owner, StartDex)
            else:
                GlobalSuperlog("=== ManageLinkedItem FAILED - No Item or Owner ===")
                
        
