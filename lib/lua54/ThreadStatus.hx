package lua54;

enum abstract ThreadStatus(Int) {
	var Something = -1;
	var Ok = 0;
	var Yield;
	var ErrRun;
	var ErrSyntax;
	var ErrMem;
	var ErrErr;
}