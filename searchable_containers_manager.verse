using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Verse.org/Random }
using { /UnrealEngine.com/Temporary/Diagnostics }

# Manages a collection of searchable containers with individual cooldowns
searchable_containers_manager := class(creative_device):
    # Array of all search buttons
    @editable
    Buttons : []button_device = array{}

    # Array of item granters for rewards
    @editable
    ItemGranters : []item_granter_device = array{}

    # HUD message device for feedback
    @editable
    HUDDevice : hud_message_device = hud_message_device{}

    # Cooldown duration in seconds
    @editable
    CooldownDuration : float = 120.0

    # Track which buttons are on cooldown
    var ButtonCooldowns : []logic = array{}

    # Helper function to create a localizable message for "Nothing found"
    NothingFoundMessage<localizes>():message = "Nothing found"

    # Helper function to create a localizable message for found items
    FoundItemMessage<localizes>(Amount:int):message = "You found an Something!"

    OnBegin<override>()<suspends> : void =
        # Initialize cooldown array to match button count
        set ButtonCooldowns = for (Index := 0..Buttons.Length - 1) do false

        # Subscribe to each button's interaction event
        for (ButtonIndex -> Button : Buttons):
            Button.InteractedWithEvent.Subscribe(HandleButtonInteraction)

    # Handle button interaction
    HandleButtonInteraction(Agent : agent) : void =
        for (ButtonIndex -> Button : Buttons):
            if (IsButtonOnCooldown[ButtonIndex] = false):
                # Put button on cooldown
                if (set ButtonCooldowns[ButtonIndex] = true):
                    # Try to grant random item
                    GrantRandomItem(Agent)
                    # Start cooldown timer
                    spawn{StartButtonCooldown(ButtonIndex)}
                return

    # Check if button is on cooldown
    IsButtonOnCooldown(ButtonIndex : int)<transacts><decides> : void =
        if (CooldownState := ButtonCooldowns[ButtonIndex], CooldownState = true):
            void

    # Grant random item or show "nothing found" message
    GrantRandomItem(Agent : agent) : void =
        # 30% chance of finding nothing
        if (GetRandomFloat(0.0, 1.0) < 0.3):
            HUDDevice.Show(Agent, NothingFoundMessage())
            return

        # Select random item granter
        if (ItemGranters.Length > 0):
            RandomIndex := GetRandomInt(0, ItemGranters.Length - 1)
            if (ItemGranter := ItemGranters[RandomIndex]):
                ItemGranter.GrantItem(Agent)
                HUDDevice.Show(Agent, FoundItemMessage(1))

    # Handle button cooldown timer
    StartButtonCooldown(ButtonIndex : int)<suspends> : void =
        Sleep(CooldownDuration)
        if (set ButtonCooldowns[ButtonIndex] = false):
            Print("Button {ButtonIndex} cooldown complete")