using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Verse.org/Simulation }
using { /Fortnite.com/Playspaces }

food_consumption_manager := class(creative_device):
    EnableFoodConsumption():void =
        Players := GetPlayspace().GetPlayers()
        for (Player : Players):
            if (Character := Player.GetFortCharacter[]):
                Character.SetVulnerability(true)