using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }

# Device to manage objective pulse behavior for players
objective_pulse_manager := class(creative_device):
    @editable
    MapIndicator : map_indicator_device = map_indicator_device{}

    @editable
    PlayerSpawners : []player_spawner_device = array{}

    @editable
    Volumes : []volume_device = array{}

    @editable
    ConditionalButton : conditional_button_device = conditional_button_device{}

    OnBegin<override>()<suspends>:void =
        # Subscribe to player spawns
        Print("objective_pulse_manager device has started")
        for (Spawner : PlayerSpawners):
            Spawner.SpawnedEvent.Subscribe(OnPlayerSpawned)

        # Subscribe to volume entry
        for (Volume : Volumes):
            Volume.AgentEntersEvent.Subscribe(OnPlayerEnteredVolume)

        # Subscribe to conditional button
        ConditionalButton.ActivatedEvent.Subscribe(OnButtonActivated)

    # Handle player spawn
    OnPlayerSpawned(Agent:agent):void =
        Print("Player spawned, activating pulse")
        MapIndicator.ActivateObjectivePulse(Agent)

    # Handle player entering volume
    OnPlayerEnteredVolume(Agent:agent):void =
        Print("Player entered volume, deactivating pulse")
        MapIndicator.DeactivateObjectivePulse(Agent)

    # Handle conditional button activation
    OnButtonActivated(Agent:agent):void =
        Print("Conditional button pressed, activating pulse")
        MapIndicator.ActivateObjectivePulse(Agent)