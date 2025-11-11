using { /Verse.org/Random }
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/SpatialMath }
using {Purchaseables}
using {Runtimeinstantiables}
using {cc}

<#

Tycoon Stomper - Conveyor Classes

Developed by TSAR 
ALL RIGHTS RESERVED
DO NOT SELL

#>



#Create a custom waypointable class that can be used to create items that can Link to `waypoints` such as: custom droppers and upgraders
custom_waypointable<public>:=class<concrete>(SuperClassInaugurable):
    

    @editable prop  <public>       :        creative_prop        =     creative_prop{}
    @editable Type  <public>       :        types                  =   types.corner

    var LocalOwner : ?purchaseable = false
    var Placed:logic=false


    Action(_Waypoint:waypoint, _Conveyor:custom_conveyor, StartDex:int)<suspends>:void=
        Print("ACTION: Entry", ?Duration := 10.0)
        if:
            Location := _Waypoint.OffConveyorLocation?
            Rotation := _Waypoint.OffConveyorRotation?
        then:
            Print("ACTION: Got location", ?Duration := 10.0)
            if (prop.TeleportTo[vector3{X:=Location.X, Y:=Location.Y, Z:=Location.Z-300.0}, rotation{}]):
                Print("ACTION: Teleported, calling MoveTo", ?Duration := 10.0)
                spawn{prop.MoveTo(Location, Rotation, 2.0)}
                Print("ACTION: MoveTo returned", ?Duration := 10.0)
            else:
                Print("ACTION: Teleport FAILED", ?Duration := 10.0)
        else:
            Print("ACTION: NO LOCATION", ?Duration := 10.0)
        Print("ACTION: Exiting", ?Duration := 10.0)
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

    # Track spawned props for cleanup on rebirth
    var SpawnedProps : []creative_prop = array{}
    


    GetAssociatedValue<override>():vector2=
        vector2{X:=CubeValue, Y:=CubeValue}

    # Public cleanup method for rebirth
    CleanupAllProps<public>():void=
        Print("DROPPER: Cleaning up {SpawnedProps.Length} props", ?Duration := 10.0)
        for(Prop : SpawnedProps):
            if (Prop.IsValid[]):
                Prop.Dispose()
        set SpawnedProps = array{}

    Action<override>(_Waypoint:waypoint, _Conveyor:custom_conveyor, StartDex:int)<suspends>:void=
        Print("DROPPER: Action started", ?Duration := 10.0)
        (super:)Action(_Waypoint, _Conveyor, StartDex)
        Print("DROPPER: Super returned", ?Duration := 10.0)
        Print("DROPPER: Starting spawn loop", ?Duration := 10.0)
        loop:
            Sleep(PropSpawnRate)
            spawn{SpawnProp(_Conveyor, StartDex)}

    
            
    SpawnProp(_Conveyor:custom_conveyor, StartDex:int)<suspends>:void=
        var CurrentCubeValue : float = 0.0
        Sleep(0.1); set CurrentCubeValue = CubeValue
        MaybeSpawnedProp := SpawnProp(PropSpawn, vector3{X:=0.0,Y:=0.0,Z:=0.0}, rotation{})
        if:
            SpawnedProp := MaybeSpawnedProp(0)?
        then:
            # Track spawned prop for cleanup
            set SpawnedProps += array{SpawnedProp}
            
            SpawnedProp.Hide()
            var ActiveDex: int = StartDex
                loop:
                    if:
                        CNextWaypoint := _Conveyor.ConveyorWaypoints[ActiveDex]
                        CNextWaypointLocation := CNextWaypoint.Location
                        CNextWaypointLocationValue := CNextWaypointLocation.GetTransform().Translation
                        TransformMain := transform{Translation:=SpawnedProp.GetTransform().Translation, Scale:=vector3{X:=0.25, Y:=0.25, Z:=0.25}}
                        NextLocation := transform{Translation:=CNextWaypointLocationValue, Scale:=vector3{X:=0.25, Y:=0.25, Z:=0.25}}
                        SpawnedProp.TeleportTo[TransformMain]
                    then:
                        # FIXED: Use StartDex instead of hardcoded 0
                        if. ActiveDex = StartDex then{
                            if(SpawnedProp.TeleportTo[vector3{X:=CNextWaypointLocationValue.X,Y:=CNextWaypointLocationValue.Y,Z:=CNextWaypointLocationValue.Z+ExitHeight}, rotation{}]){
                                
                                spawn{ShowAfter(SpawnedProp, (55.0/ExitHeight)/10.0)}
                                SpawnedProp.MoveTo(NextLocation, 55.0/ExitHeight)
                            }

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
                        if:
                            Owner := LocalOwner?
                            Base := Owner.MaybeOwner?
                            Player := Base.Players[0]
                            Value := Ceil[CurrentCubeValue]
                        then:
                            GrantMoney(Base,Player, GrantID, Value, Owner.BypassZone)
                        Sleep(0.01); SpawnedProp.Dispose(); return
                    else:
                        SpawnedProp.Dispose(); return

    ShowAfter(Prop:creative_prop, Delay:float)<suspends>:void={Sleep(Delay);  Prop.Show(); return}
       
       
        
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
        Print("WAYPOINT: Linking", ?Duration := 5.0)
        if:
            CheckOwner := Owner?
            Item.Type = Input
            not Item.Placed?
        then:
            
            Item.prop.Show()
            set Item.Placed = true
            set LinkedItem = option{Item}
            NewLink.Signal()
            spawn{ManageLinkedItem()}
            Print("WAYPOINT: Linked", ?Duration := 5.0)
            if:
                not MaybeOrigin?
            then:
                set MaybeOrigin = option{Item.prop.GetTransform()}





    
    Unlink<public>(Item:custom_waypointable):void=
        Print("WAYPOINT: Unlinking", ?Duration := 5.0)
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
            Print("WAYPOINT: Unlinked", ?Duration := 5.0)
            set LinkedItem = false
            NewLink.Signal()
            if(BItem.prop.TeleportTo[Origin]){}
            


    ManageLinkedItem()<suspends>:void=
            Print("WAYPOINT: ManageLinkedItem", ?Duration := 5.0)
            if:
                Item := LinkedItem?
                ItemOwner := Owner?
            then:
                if:
                    Item.Type = types.dropper
                then:
                    Print("WAYPOINT: Dropper detected", ?Duration := 5.0)
                    # Use race block to allow cancellation on rebirth
                    loop:
                        race:
                            block:
                                NewLink.Await()
                                Print("WAYPOINT: NewLink await", ?Duration := 5.0)
                                return
                            block:
                                Item.Action(Self, ItemOwner, StartDex)
                else:
                    Item.Action(Self, ItemOwner, StartDex)