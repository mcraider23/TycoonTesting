using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using {cc}

# Purchaseable that unlocks a specific ammo generator when bought
ammo_unlock_buyable<public>:=class<concrete><final>(purchaseable):
    
    var Ptype <override> :  PurchaseableType = PurchaseableType.BasicProp

    # Reference to the ammo generator device
    @editable var AmmoGenerator : ammo_generator_device = ammo_generator_device{}
    
    # Which ammo type to unlock (0=Light, 1=Medium, 2=Heavy, 3=Shells, 4=Rockets, 5=Arrows)
    @editable var AmmoTypeIndex : int = 0

    Initialize<override>(Hostess:base, I:int):void=
        (super:)Initialize(Hostess, I)
        Detail("AmmoUnlockBuyable")

    Host<override>()<suspends>:void=
        # Activate the ammo generator when this item is purchased
        Print("Unlocking ammo type index {AmmoTypeIndex}")
        AmmoGenerator.ActivateGenerator(AmmoTypeIndex)
        
        # Keep this async context alive
        loop:
            Sleep(Inf)

    OnRebirth<override>():void=
        (super:)OnRebirth()
        # Deactivate the generator on rebirth
        AmmoGenerator.DeactivateGenerator(AmmoTypeIndex)