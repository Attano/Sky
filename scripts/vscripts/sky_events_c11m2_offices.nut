Msg("Initiating Sky Car's Winch Panic Event\n");

EntFire( "director", "PanicEvent", 0 )

DirectorOptions <-
{
	// This turns off tanks and witches.
	ProhibitBosses = true

	PreferredMobDirection = SPAWN_IN_FRONT_OF_SURVIVORS
	MobSpawnMinTime = 3
	MobSpawnMaxTime = 3
	MobMaxPending = 20
	MobMinSize = 20
	MobMaxSize = 20
	SustainPeakMinTime = 3
	SustainPeakMaxTime = 3
	IntensityRelaxThreshold = 0.90
	RelaxMinInterval = 4
	RelaxMaxInterval = 4
	RelaxMaxFlowTravel = 200
}

Director.ResetMobTimer()