using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }

npc_spawn_cycle_device := class(creative_device):
    # Timer for main cycle
    @editable
    MainTimer : timer_device = timer_device{}

    # HUD messages
    @editable
    FirstMessage : hud_message_device = hud_message_device{}
    
    @editable
    SecondMessage : hud_message_device = hud_message_device{}

    # Array of NPC spawners
    @editable
    NPCSpawners : []npc_spawner_device = array{}

    # Timer duration settings
    @editable
    MainTimerDuration : float = 3600.0  # Set your main timer duration here
    
    @editable
    NPCLifetime : float = 600.0  # 10 minutes in seconds

    OnBegin<override>()<suspends>:void=
        # Subscribe to timer success event
        MainTimer.SuccessEvent.Subscribe(OnTimerSuccess)
        # Start the initial timer
        MainTimer.Start()

    OnTimerSuccess(Agent:?agent):void=
        # Show first HUD message
        FirstMessage.Show()
        
        # Enable all NPC spawners
        for (Spawner : NPCSpawners):
            Spawner.Enable()

        # Start 10 minute countdown to disable spawners
        spawn{DisableSpawnersAfterDelay()}

    DisableSpawnersAfterDelay()<suspends>:void=
        # Wait 10 minutes
        Sleep(NPCLifetime)

        # Disable all NPC spawners
        for (Spawner : NPCSpawners):
            Spawner.Disable()

        # Show second HUD message
        SecondMessage.Show()

        # Restart the main timer
        MainTimer.Start()