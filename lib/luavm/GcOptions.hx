package luavm;

enum abstract GcOptions(Int) {
	var GcStop = 0;
	var GCRestart = 1;
	var GcCollect = 2;
	var GcCount = 3;
	var GcCountB = 4;
	var GcStep = 5;
	var GcSetPause = 6;
	var GcSetStepMul = 7;
	var GcIsRunning = 9;
}