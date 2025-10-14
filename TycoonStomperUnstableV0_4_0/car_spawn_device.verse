using { /Fortnite.com/Devices }
using { /Fortnite.com/Vehicles }
using { /Verse.org/Simulation }
using { /Fortnite.com/Characters }

car_spawn_device := class(creative_device):
    @editable
    Buttons : []button_device = array{}

    @editable
    CarSpawner : vehicle_spawner_pickup_truck_device = vehicle_spawner_pickup_truck_device{}

    var CurrentVehicle : ?fort_vehicle = false
    var CurrentAgent : ?agent = false
    var DespawnTimerActive : logic = false

    OnBegin<override>()<suspends>:void =
        # Disable the spawner initially so the truck isn't in the world
        CarSpawner.Disable()
        # Subscribe to all buttons in the array
        for (Button : Buttons):
            Button.InteractedWithEvent.Subscribe(OnButtonPressed)
        CarSpawner.SpawnedEvent.Subscribe(OnVehicleSpawned)
        CarSpawner.AgentExitsVehicleEvent.Subscribe(OnAgentExits)
        CarSpawner.AgentEntersVehicleEvent.Subscribe(OnAgentEnters)

    OnButtonPressed(Agent : agent):void =
        if (CurrentVehicle = false):
            set CurrentAgent = option{Agent}
            # Enable the spawner and spawn the truck when the button is pressed
            CarSpawner.Enable()
            CarSpawner.RespawnVehicle()

    OnVehicleSpawned(Vehicle:fort_vehicle):void =
        if (Agent := CurrentAgent?):
            # Assign the saved agent as the driver of the newly spawned truck
            CarSpawner.AssignDriver(Agent)
            set CurrentVehicle = option{Vehicle}

    OnAgentExits(Agent:agent):void =
        if (TrackedAgent := CurrentAgent?):
            if (TrackedAgent = Agent and DespawnTimerActive = false):
                set DespawnTimerActive = true
                spawn{DespawnVehicleAfterDelay()}

    OnAgentEnters(Agent:agent):void =
        # Cancel the despawn timer if the player re-enters the vehicle
        set DespawnTimerActive = false

    DespawnVehicleAfterDelay()<suspends>:void =
        Sleep(120.0)
        if (DespawnTimerActive = true):
            if (Vehicle := CurrentVehicle?):
                CarSpawner.DestroyVehicle()
                set CurrentVehicle = false
                set CurrentAgent = false
                # Disable the spawner again so the truck isn't in the world
                CarSpawner.Disable()
            set DespawnTimerActive = false