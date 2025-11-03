using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Fortnite.com/Characters }

billboard_facing_device := class(creative_device):
    @editable
    Billboards : []billboard_device = array{}
    @editable
    RotationLerpSpeed : float = 0.2

    # Track hidden state to only log on change
    var HiddenStates : []logic = array{}

    OnBegin<override>()<suspends> : void =
        # Initialize hidden state array
        set HiddenStates = for (Index := 0..Billboards.Length - 1):
            false

        loop:
            UpdateBillboardRotations()
            Sleep(0.0)

    UpdateBillboardRotations() : void =
        if (Players := GetPlayspace().GetPlayers(), Player := Players[0]):
            if (Character := Player.GetFortCharacter[]):
                PlayerPos := Character.GetTransform().Translation
                for (Index := 0..Billboards.Length - 1):
                    if (Billboard := Billboards[Index]):
                        CurrentTransform := Billboard.GetTransform()
                        BillboardPos := CurrentTransform.Translation
                        # Track and report state changes only
                        if (BillboardPos.Z > -10000.0):
                            if (HiddenStates[Index] = true):
                                if (set HiddenStates[Index] = false):
                                    Print("Billboard {Index} became visible")
                            Direction := vector3{
                                X := PlayerPos.X - BillboardPos.X, 
                                Y := PlayerPos.Y - BillboardPos.Y, 
                                Z := 0.0
                            }
                            if (Direction.Length() > 0.0):
                                Forward := vector3{X := 0.0, Y := 1.0, Z := 0.0}
                                TargetRotation := MakeShortestRotationBetween(Forward, Direction)
                                if (NewRotation := Slerp[CurrentTransform.Rotation, TargetRotation, RotationLerpSpeed]):
                                    if (Billboard.TeleportTo[CurrentTransform.Translation, NewRotation]) { }
                        else:
                            if (HiddenStates[Index] = false):
                                if (set HiddenStates[Index] = true):
                                    Print("Billboard {Index} considered hidden, skipping teleport")