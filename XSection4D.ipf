//by Shoya Sakamoto 04/24/2019


#pragma rtGlobals=1		// Use modern global access method.
#include <WindowBrowser>
//#include ":XS_fileloader_Shoya"
//#include ":PSK_trFIT"


Menu "XSection"
	"Browser/1",XS_update_browser(); XS_browser_panel();
	"About/2",AboutXS();
	"-"
	SubMenu "Legacy"
		"Reload from current data folder", XSection(gprefix); UpdateXSWindow(gprefix)
		"Manual load", XSLoader()
		"Reinit ",ReinitVariables()
	
		SubMenu "Detector fixes"
			"Normalize lens function", XS_FixLensDataSet()
			"Remove Grid", XS_AutoFFT()
		End
	End
	
End


Window AboutXS() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(193,393,493,506)/K=1 /N=AboutXS as "About"
	ModifyPanel/W=AboutXS fixedSize=1
	SetDrawLayer UserBack
	SetDrawEnv xcoord= rel,ycoord= abs,fsize= 20,fstyle= 4,textxjust= 1,textyjust= 1
	DrawText 0.5,15.865,"XSection"
	SetDrawEnv xcoord= rel,ycoord= abs,textxjust= 1,textyjust= 1
	DrawText 0.5,42,"v3.0"
	SetDrawEnv xcoord= rel,ycoord= abs,textxjust= 1,textyjust= 1
	DrawText 0.5,95,"Support: sobota@stanford.edu"
EndMacro

Function XSection(prefix): Graph	
	String prefix

	print("XSection(" + prefix + ")")

	PauseUpdate; Silent 1	
	
	SetDataFolder $("root:XS_"+prefix)
	
	Wave VolDims,LoadedData,DelayAxis,AngleAxis,EnergyAxis,Delays,VolData,Layers,LayerAxis
	NVAR CutX,CutY,CutZ
	NVAR CutX_val,CutY_val
	NVAR CutScan, IntScan
	NVAR combinedScanNo
	NVAR collapsed
	NVAR firstColor, lastColor, colorIndex, subPanelHidden
	SVAR colorTable
	subPanelHidden = 1
	
	Make/O HairY0={0,0,NaN,Inf,-Inf}
	Make/O HairX0={-Inf,Inf,NaN,0,0}
	
	NVAR WhichGraphToPlot,GraphOnNewAxis,DuplicateGraph

	variable sizeX,sizeY,sizeZ
	sizeX = dimsize(VolData,0)
	sizeY=dimsize(VolData,1)
	sizeZ =dimsize(VolData,2)
	
	//ImBL = Image Bottom Left
	Make/O/N=(sizeX,sizeY) ImBL
	//ImL = Image Top
	Make/O/N=(sizeX,sizeZ) ImT
	//ImL = Image Right
	Make/O/N=(sizeZ,sizeY) ImR
	//GrT = Top graph
	Make/O/N=(sizeX) GrT
	//GrR = Right graph
	Make/O/N=(sizeY) GrR
	Make/O/N=(sizeY) GrR_Y
	//GrTR = Top right graph
	Make/O/N=(sizeZ) GrTR
		
	//Set dimensions
	SetScale/P x, DimOffset(LoadedData,0),DimDelta(LoadedData,0),ImBL,ImT,GrT
	SetScale/P y, DimOffset(LoadedData,1),DimDelta(LoadedData,1),ImBL,ImR
	SetScale/P x, DimOffset(LoadedData,1),DimDelta(LoadedData,1),GrR
	
	if (equallySpaced(Delays) == 1)
	
		SetScale/I x, Delays[0], Delays[dimsize(Delays,0)-1], GrTR
		
	endif
	
	//Placeholder for actual data
	//ImBL = sin(x)*sin(y)
	//ImT = sin(x)*y
	//ImR = x*sin(y)
	//GrT = sin(x)

	GrR_Y[] = DimOffset(LoadedData,1) + p*DimDelta(LoadedData,1)
	//GrR = cos(GrR_Y)

	////////////////////////////////////////////
		
	DoWindow/K $("Win"+prefix)	
	
	
	Display /k=1/W=(350,150,1160,650)/N=$("Win"+prefix) HairY0 vs HairX0 as ("XSection of "+prefix)
	//Display /k=0/W=(350,150,1000,650)/N=$("Win"+prefix) HairY0 vs HairX0 as ("XSection of "+prefix)
	
	SetWindow kwTopWin, userdata=prefix
	
	DoWindow/C $("Win"+prefix)
	DoWindow/F $("Win"+prefix)
	
	ModifyGraph noLabel(left)=2
	ModifyGraph noLabel(bottom)=2

	// Display BL image
	AppendImage/B=AxisB1 /L=AxisL1 ImBL
	ModifyGraph axisEnab(AxisB1)={0,0.5}
	ModifyGraph axisEnab(AxisL1)={0,0.5}
	ModifyGraph freePos(AxisB1)=0
	ModifyGraph freePos(AxisL1)=0
	
	// Display T image
	AppendImage/B=AxisB1 /L=AxisL2 ImT vs {AngleAxis,LayerAxis}
	ModifyGraph axisEnab(AxisL2)={0.55,0.8}
	ModifyGraph freePos(AxisL2)=0
	
	// Display R image
	AppendImage/B=AxisB2 /L=AxisL1 ImR vs {LayerAxis, EnergyAxis}
	ModifyGraph axisEnab(AxisB2)={0.55,0.8}
	ModifyGraph freePos(AxisB2)=0
	
	// Display T graph
	AppendToGraph/B=AxisB1 /L=AxisL3 GrT
	ModifyGraph axisEnab(AxisL3)={0.85,1.0}
	ModifyGraph freePos(AxisL3)=0
	
	// Display R graph
	AppendToGraph/B=AxisB3 /L=AxisL1 GrR_Y vs GrR
	ModifyGraph axisEnab(AxisB3)={0.85,1.0}
	ModifyGraph freePos(AxisB3)=0
	
	// Display TR graph
	AppendToGraph/B=AxisB4 /L=AxisL4 GrTR vs Layers
	ModifyGraph axisEnab(AxisB4)={0.6,1.0}
	ModifyGraph axisEnab(AxisL4)={0.6,1.0}
	ModifyGraph mode(GrTR)=4,marker(GrTR)=19,msize(GrTR)=1.5
	
	ModifyGraph freePos(AxisL4)={0,AxisB4}
	ModifyGraph freePos(AxisB4)={0,AxisL4}
	
	SetAxis/A=2 AxisL4
		
	//Change colorscales
	
	ModifyImage ImBL ctab= {*,*,Terrain256,0}, ctabAutoscale=1,lookup= $""
	ModifyImage ImT ctab= {*,*,Terrain256,0}, ctabAutoscale=1,lookup= $""
	ModifyImage ImR ctab= {*,*,Terrain256,0}, ctabAutoscale=1,lookup= $""

	//Add cursors 
	//CutX = round(VolDims[0]/2)
	//CutY = round(VolDims[1]/2)
	
	Cursor/I/S=2/L=0/H=1/C=(65535,0,0)/P C ImBL CutX,CutY
	Cursor/F/S=2/L=0/H=0/C=(0,0,0)/P D GrTR CutZ,0
	
	Label AxisL1 "Energy"
	Label AxisB1 "Angle or k"
	Label AxisB2 "Delay"
	Label AxisL2 "Delay"
	ModifyGraph lblPosMode(AxisL1)=2,lblPosMode(AxisB1)=2,lblMargin(AxisL1)=10
	ModifyGraph lblMargin(AxisB1)=5
	ModifyGraph lblPosMode(AxisB2)=2,lblMargin(AxisB2)=5
	ModifyGraph lblPosMode(AxisL2)=2,lblMargin(AxisL2)=10
		
	SetWindow $("Win"+prefix) hook(hookFcn)=imgHookFcn, hookevents=2
	
	ControlBar 60
	SetWindow kwTopWin,hook(hookFcn)=imgHookFcn
	NewPanel/W=(0.2,0.2,0.8,0)/FG=(FL,FT,GR,)/HOST=# 
	SetDrawLayer UserBack
	DrawText 651,50,"Fit:"
	
	Button UpdateButton,pos={10,10},size={46,38},proc=ButtonProc,title="Update"
	Button UpdateButton,fSize=10
	CheckBox IntShowCheck,pos={404,33},size={65,15},proc=CheckProc,title="IntWin"
	CheckBox IntShowCheck,variable= ShowInt
	
	SetVariable InDegrees,pos={223,11},size={70,15},title=" ",format="= %.2f deg"
	SetVariable InDegrees,frame=0
	SetVariable InDegrees,limits={-inf,inf,0},value= IntX_val,noedit= 1
	SetVariable InmeV,pos={223,33},size={70,15},bodyWidth=70,title=" "
	SetVariable InmeV,format="= %.1f meV",frame=0
	SetVariable InmeV,limits={-inf,inf,0},value= IntY_val,noedit= 1
	PopupMenu ChooseGraph,pos={444,10},size={55,20},proc=ChooseGraphProc
	PopupMenu ChooseGraph,mode=WhichGraphToPlot,value= "TDC;EDC;MDC;ImBL;ImR;ImT"
	PopupMenu ChooseGraph,fSize=8
	Button DisplayGraph,pos={506,9},size={50,20},proc=DisplayGraphProc,title="Display"
	Button DisplayGraph,fSize=10
	Button AppendGraph,pos={564,9},size={50,20},proc=AppendGraphProc,title="Append"
	Button AppendGraph,fSize=10
	CheckBox NewAxisCheck,pos={621,11},size={76,15},title="New Axis"
	CheckBox NewAxisCheck,variable= GraphOnNewAxis, fsize=9
	CheckBox DuplicateGraphCheck,pos={684,11},size={58,15},title="Duplicate"
	CheckBox DuplicateGraphCheck,variable= DuplicateGraph, fsize=9
	Button RainbowButton,pos={749,9},size={50,20},proc=RainbowProc,title="Rainbow"
	Button RainbowButton,fSize=10
	SetVariable XCutDisplay,pos={61,11},size={48,15},bodyWidth=42,proc=CutXChangeProc,title="K:"
	SetVariable XCutDisplay,value= CutX
	SetVariable EnergyCut,pos={61,33},size={48,15},bodyWidth=42,proc=ChangeEnergyCutProc,title="E:"
	SetVariable EnergyCut,value= CutY
	
	
	SetVariable SetIntX,pos={171,11},size={58,15},bodyWidth=35,proc=SetVarProc,title="IntK:"
	SetVariable SetIntX,limits={1,500,1},value= IntX
	SetVariable SetIntY,pos={171,33},size={58,15},bodyWidth=35,proc=SetVarProc_1,title="IntE:"
	SetVariable SetIntY,limits={1,500,1},value= IntY
	
	SetVariable Timecut,pos={456,33},size={65,15},bodyWidth=35,proc=SetZProc,title="Delay:",value=CutZ,limits={0,500,1}
	SetVariable IntDelay,pos={527,33},size={57,15},bodyWidth=35,proc=SetIntDelay,title="IntD"
	SetVariable IntDelay,limits={0,147,1},value= intZ
	
	SetVariable InDeg2,pos={112,11},size={58,15},title=" "
	SetVariable InDeg2,format="= %.2f deg",frame=0
	SetVariable InDeg2,limits={-inf,inf,0},value= CutX_val,noedit= 1
	
	SetVariable IneV,pos={112,33},size={58,15},title=" "
	SetVariable IneV,format="= %.3f eV",frame=0
	SetVariable IneV,limits={-inf,inf,0},value= CutY_val,noedit= 1
	
	Button FitGauss,pos={672,32},size={40,20},proc=FitGaussButton,title="Gauss"
	Button FitGauss,fSize=10
	Button FitGaussExp,pos={715,32},size={55,20},proc=GaussExpButton,title="GaussExp"
	Button FitGaussExp,fSize=10
	Button AutoFitButton,pos={592,32},size={50,20},proc=XS_AutoFitButtonProc,title="FitTDCs"
	Button AutoFitButton,fSize=10
	
	/////4D feature added by Shoya
	SetVariable cutScan,pos={285,11},size={71.00,15.00},bodyWidth=35,proc=SetCutScan,title="ScanNo"
	SetVariable cutScan,limits={0,500,1},value= cutScan
	SetVariable setIntScanWindow,pos={285,33},size={71.00,15.00},bodyWidth=35,proc=SetIntScanWindow,title="IntScan"
	SetVariable setIntScanWindow,limits={0,500,1},value= IntScan
	
	Button DeleteVolData4D,pos={359,32},size={40,20},proc=ButtonProc_DeleteVolData4D,title="del 4D "
	Button DeleteVolData4D,fSize=10
	
	CheckBox ScanAsDelay,pos={361,12},size={73,15},proc=CheckProc_ScanAsDelay,title="ScanAsDelay"
	CheckBox ScanAsDelay,variable= scanAsdelay
	
	if(collapsed == 1)
		setVariable cutScan, disable=2
		setvariable setIntScanWindow, disable=2
		button DeleteVolData4D, disable=2
		checkbox scanAsDelay, disable =2
	endif
	
	//for showing SubPanel
	Button SubPanel,pos={775.00,33.00},size={25.00,20.00},proc=ButtonProc_showSubPanel,title=">>"
	Button SubPanel,fSize=10
	/////

	RenameWindow #,PTop
	SetActiveSubwindow ##
	
	//some addional functions which appear in the sub panel at the right hand side of the window
	NewPanel/HOST=$("Win"+prefix)/EXT=0/K=2/W=(0,0,100,400)/N=$("Sub"+prefix)/NA=0
	SetDrawLayer UserBack
	SetDrawEnv fillfgc= (43690,43690,43690),fillbgc= (43690,43690,43690)
	DrawRect 3,5,96,247
	//Button removeGrid,pos={10.00,11.00},size={80.00,20.00},title="RemoveGrid"
	//Button removeGrid,fSize=10,proc=buttonProc_deadPixelRemover
	Button deadPixel,pos={5.00,257.00},size={90.00,20.00},title="Rmv Dead Pixel",fSize=10,proc=buttonProc_deadPixelRemover
	SetDrawEnv fsize= 9
	DrawText 10,300,"* mark dead pixel(s) \r  with int window"
	
	ListBox listColorTable,pos={5.00,10.00},size={88.00,61.00},fSize=9
	ListBox listColorTable,listWave=root:color_table:colorTable_list,row= 45,mode= 1
	ListBox listColorTable,selRow= colorIndex,proc=ListBoxProc_ColorTable
	Slider sliderFirstColor,pos={6.00,81.00},size={53.00,154.00},fSize=8
	Slider sliderFirstColor,limits={-2,2,0.1},variable= FirstColor,proc=SliderProc_ColorXS
	Slider sliderLastColor,pos={48.00,81.00},size={53.00,154.00},fSize=8
	Slider sliderLastColor,limits={-2,2,0.1},variable= LastColor,proc=SliderProc_ColorXS
	
	SetDrawEnv fsize= 9
	DrawText 5,248,"First Color"
	SetDrawEnv fsize= 9
	DrawText 53,248,"Last Color"
	
	SetWindow $("Sub"+prefix) userData=prefix
	setWindow $("Sub"+prefix) hook(subPanelHookFCN)=subPanelHookFCN
	SetWindow $("Sub"+prefix) hide=subPanelHidden
	
	SetActiveSubwindow ##
	
	ResumeUpdate	
	DoUpdate
	
	print("End of XSection()")

End

Function imgHookFcn(s)
	STRUCT WMWinHookStruct &s
	//SVAR gprefix
	string winprefix
	//print(s.eventcode)
	If (s.eventcode == 0)
		winprefix = GetUserData("","","")
		SetDataFolder $("root:XS_"+winprefix)
		//print("imgHookFCN")
		return 0
	EndIf
	
	If (s.eventcode == 7) //Cursormoved
		SVAR gprefix
		NVAR CutX,CutY,CutZ,CutScan,ScanAsDelay
		Wave VolDims, Layers
		If ( stringmatch(s.cursorName ,"C") && stringmatch(s.traceName ,"ImBL") && (s.mouseloc.v >0) )
			CutX= s.PointNumber
			CutY= s.yPointNumber	
			UpdateXSWindow(gprefix)
			doupdate
		EndIf
		
		If ( stringmatch(s.cursorName ,"D") && stringmatch(s.traceName ,"GrTR")  )
		getAxis/Q AxisB4
			//CutZ= round((s.PointNumber)*(V_max-V_min)+V_min)
			Variable hval= hcsr(D)
			Variable ind
			
			For(ind = 0; Layers[ind] < hval; ind+=1)
			EndFor
			
			if(scanAsDelay == 1)
				CutScan = (abs(Layers[ind-1] - hval) < abs(Layers[ind] - hval)) ? ind-1 : ind
			else
				CutZ = (abs(Layers[ind-1] - hval) < abs(Layers[ind] - hval)) ? ind-1 : ind
			endif
			
			 UpdateXSWindow(gprefix)
			doupdate
		EndIf
		
	EndIf
	

	return 0
End

//does not work??
Function subPanelHookFcn(s)
	STRUCT WMWinHookStruct &s
	
	//SVAR gprefix
	//print(s.eventcode)
	If (s.eventcode == 0)
		String winprefix = GetUserData("","","")
		SetDataFolder $("root:XS_"+winprefix)
		print("subPanelHookFCN")
		return 0
	EndIf

	return 0
End

Function InitXSection(sym_path,prefix,numDelays)
	String sym_path, prefix
	Variable numDelays
	
	print("InitXSection(" + sym_path + "," + prefix + "," + num2str(numDelays)+")")
	
	Nvar/Z NoOfScans = root:XS_Globals:NoOfScansToBeCombined
	
	if(!NVAR_exists(NoOfScans))
		Variable/G root:XS_Globals:NoOfScansToBeCombined
		NoOfScans = 1
		
		//input Dialog for setting IntScanWindow
		variable a = 1
		prompt a, "Every x scans will be combined. if x is negative all the scans will be added:"
		Doprompt "Enter parameter", a
		
		if (V_Flag)
				print("initXSection has been canceled")
  		     	return -1                       // User canceled
  		endif
  		
  		NoOfScans = a
		
	endif
	
	String filename
	String datafolder = "root:XS_"+prefix
	
	
	//Initialize autosave
	XS_prefs_initAutosaveTask()
	
	// Set up internal data folder
	DoWindow/K $("Win"+prefix)	
	KillDataFolder/Z $datafolder
	
	if (V_flag == 39)
		Print " There was an error loading your file.  If you're trying to reload an XSection file, make sure none of its variables are in use."
		Return -1
	EndIf
	
	NewDataFolder/O/S $datafolder
	
	NewDataFolder/O Duplicated
	
	Variable/G NoOfScansToBeCombined = NoOfScans 
	
	String/G datapath = sym_path
	Variable/G ScanNo = 0
	Variable/G DelayNo = 0
	Variable/G IntDelay = 0 
	
	Variable/G CutX 
	Variable/G CutY 
	Variable/G CutX_val, CutY_val
	Variable/G CutZ = 0
	
	Variable/G IntX = 10
	Variable/G IntY = 10
	Variable/G IntX_val
	Variable/G IntY_val
	
	Variable/G intZ = 0

	Variable/G CutX_val, CutY_val
	
	Variable/G ShowInt = 1

	variable/G CutScan = 0 
	variable/G IntScan = 0 
	variable/G CombinedScanNo = 0
	
	variable/G collapsed = 0
	variable/G scanAsDelay = 0
	
	String/G gprefix = prefix
	
	Variable/G to_fs = 0
	Variable/G to_um = 0
	
	Variable/G EDC_no = 0
	Variable/G MDC_no = 0
	Variable/G TDC_no = 0
	
	Variable/G WhichGraphToPlot = 1
	Variable/G GraphOnNewAxis = 1
	Variable/G DuplicateGraph = 1
	
	///for sub panel
	variable/G subPanelHidden = 1
	variable/G FirstColor = 0
	variable/G LastColor = 1
	variable/G ColorIndex = 7
	String/G ColorTable = ""
	
	
	Make/O/N=0 Countrate
	Make/O/N=4 VolDims //changed N from 3 to 4
			
	// Open first file to obtain dimensions
	
	sprintf  filename,"%s_%03d_%03d.txt",prefix,0,0
	
	If (fileloader_loadSEStxt_XS(sym_path,filename,prefix)==(-1))
		print "Error- unable to load your first data file.."
		return -1
	EndIf
	
	VolDims[0] = DimSize(LoadedData,0);
	VolDims[1] = DimSize(LoadedData,1);
	VolDims[2] = numDelays;
	volDims[3] = 0// added by Shoya
	CutX = round(VolDims[0]/2)
	CutY = round(VolDims[1]/2)
	IntX = round(0.2*VolDims[0])
	IntY= round(0.1*VolDims[1])
	
	Make/O/N=(VolDims[0],VolDims[1],VolDims[2])  VolData
	
	Make/O/N=(VolDims[0],VolDims[1],VolDims[2], VolDims[3]) VolData4D
	
	Make/N=(numDelays+1) DelayAxis
	Make/N=(VolDims[0]+1) AngleAxis
	Make/N=(VolDims[1]+1) EnergyAxis
	Make/N=(numDelays) Delays = NaN
	Make/N=(numDelays) Layers = p
	Make/N=(numDelays+1) LayerAxis = p -0.5
	
	AngleAxis =  DimOffset(LoadedData,0) + (p-.5)*DimDelta(LoadedData,0)	
	EnergyAxis =  DimOffset(LoadedData,1) + (p-.5)*DimDelta(LoadedData,1)	
	DelayAxis = 1e-10 * p
	
	print("End of initXSection")
	
	Return 0
End




Function LoadXSection()

	print("LoadXSection()")

	String prefix = "test"
	String path = (prefix+"Path") 
	NewPath /M="Choose a data folder" $path 
	
	Variable size = 50
	///////////////////////////////////////////////////////////////////////
	
	If (InitXSection(path,prefix,size)==-1)
		Return -1
	EndIf
	
	XSection(prefix)
	
	// Later this will be turned into a button on the graph
	UpdateXSData(prefix)
End

Function UpdateXSData(prefix)
	String prefix
	
	print("UpdateXSData(" + prefix +")")
	
	SetDataFolder $("root:XS_"+prefix)
	SVAR datapath
	NVAR ScanNo
	NVAR DelayNo,CutZ,IntZ
	Wave VolData,LoadedData,VolDims,DelayAxis,Delays,Countrate,VolData4D
	
	Variable N
	Variable Diff 
	
	Nvar combinedScanNo 
	Nvar NoOfScansToBeCombined
	
	String filename
	
	Do
		sprintf  filename,"%s_%03d_%03d.txt",prefix,ScanNo,DelayNo
		
		If (fileloader_loadSEStxt_XS(datapath,filename,prefix)==(-1))//this is slowing down the process for future reference.
			Break
		EndIf
		
		//Build up delay axis
		If(ScanNo == 0)
			Delays[DelayNo] = str2num(StringByKey("Delay(fs)", note(LoadedData), "=","\r"))			
			
			DelayAxis[DelayNo+1] = Delays[DelayNo]
			
			If(DelayNo==0)
				DelayAxis[0] = DelayAxis[1] - 1
			ElseIf(DelayNo==1)
				Diff = DelayAxis[2] - DelayAxis[1]
				DelayAxis[1] = (DelayAxis[1]+DelayAxis[2])/2
				
				DelayAxis[0] = DelayAxis[1] - Diff
			Else
				DelayAxis[DelayNo] = (DelayAxis[DelayNo] + DelayAxis[DelayNo+1])/2
			EndIf			
			
			If (DelayNo == (VolDims[2]-1))
				Diff = DelayAxis[DelayNo+1] - DelayAxis[DelayNo]
				DelayAxis[DelayNo+1] += Diff
			EndIf
			
			Variable num
			For (num = DelayNo+2; num < (VolDims[2]+1);num+=1)
				DelayAxis[num] = DelayAxis[num-1] + 0.1
			EndFor
			//For (num = DelayNo+1; num < VolDims[2]; num+=1)
			//	Delays[num] = Delays[num-1]+.1
			//EndFor
		EndIf
		
	
		N = ScanNo
		
		Variable numLoaded = DimSize(countrate,0)
		ReDimension/N=(numLoaded+1) countrate
		WaveStats/Q LoadedData
		countrate[numLoaded] = V_npnts*V_avg
		
		//VolData[][][DelayNo] = N/(N+1) * VolData[p][q][DelayNo] + (1/(N+1)) * LoadedData[p][q]
		//VolData[][][DelayNo] = VolData[p][q][DelayNo] + LoadedData[p][q]
		
		
		if(delayNo == 0)
		
			Print "Starting to load scan #" + num2str(ScanNo)
		
			if(mod(scanNo, NoOfScansToBeCombined) == 0) // integrate every NoOfScansToBeCombined scan
				//print("ScanNo = " + Num2str(scanNo) +", CombinedScanNo = " + Num2str(CombinedScanNo) + ", NoOfScansToBeCombined = " + Num2str(NoOfScansToBeCombined))
				combinedScanNo += 1
				redimension/N=(-1,-1,-1,combinedScanNo) VolData4D
			endif
	
		endif

		variable count = mod(scanNo, NoOfScansToBeCombined)
		multithread VolData4D[][][DelayNo][combinedScanNo-1] = (count/(count+1)) * VolData4D[p][q][DelayNo][combinedScanNo-1] + (1/(count+1)) * LoadedData[p][q]//added another dimension of scan number
		
		DelayNo = DelayNo+1
		
		If (DelayNo ==VolDims[2])
			DelayNo = 0
			ScanNo = ScanNo+1
		EndIf 
		
	While(1)
	print(combinedScanNo)
	VolDims[3] = combinedScanNo
	
	
	//UpdateXSWindow(prefix)
	makeVolDataFromVolData4D(prefix,0)
	 
End

Function UpdateXSWindow(prefix)
	String prefix
	
	//print("updateXSWindow("+prefix+")")
	
	PauseUpdate
	
	SetDataFolder $("root:XS_"+prefix)
	
	Wave ImBL,ImT,ImR,VolData,GrT,GrR,GrTR,Delays,VolData4D,VolDims, Layers, LayerAxis, Delays
	NVAR CutX,CutY,CutZ,IntX,IntY,ShowInt,whichgraphtoplot
	NVAR CutScan, IntScan
	NVAR IntX_val,IntY_val
	NVAR cutx_val,cuty_val
	NVAR IntZ,DelayNo
	NVar scanAsDelay

	String popvalStr
	switch(WhichGraphToPlot)	
		case 1:		
			popvalStr = "TDC"
			break				
		case 2:
			popvalStr = "EDC"
			break	
		case 3:
			popvalStr = "MDC"
			break	
		case 4:
			popValStr = "ImBL"				
			break
		case 5:
			popValStr = "ImR"
			break
		case 6:
			popValStr = "ImT"
			break
	endswitch
 	
	PopupMenu ChooseGraph,mode=WhichGraphToPlot,value= "TDC;EDC;MDC;ImBL;ImR;ImT",win=$("Win"+prefix+"#PTOP")
	ControlUpdate/W=$("Win"+prefix+"#PTOP") ChooseGraph
	//RemoveFromGraph/Z fit_GrTR
	
	redimension/N=(dimSize(VolData,2)) Layers
	redimension/N=(dimSize(VolData,2)+1) LayerAxis
	
	
	variable sizeX,sizeY,sizeZ
	sizeX = dimsize(VolData,0)
	sizeY=dimsize(VolData,1)
	sizeZ =dimsize(VolData,2)
	
	//ImL = Image Top
	Redimension/N=(sizeX,sizeZ) ImT
	//ImL = Image Right
	Redimension/N=(sizeZ,sizeY) ImR
	//GrTR = Top right graph
	Redimension/N=(sizeZ) GrTR
		
	
	
	if(scanAsDelay == 0)
		duplicate/O Delays, Layers
		duplicate/O DelayAxis, LayerAxis
	else
		Layers[] = p
		LayerAxis[] = p-0.5
	endif
	
	
	If (IntX < 1)
		IntX = 1
	EndIf
	If (IntY < 1)
		IntY = 1
	EndIf
	
	IntX_val = IntX*DimDelta(ImBL,0)
	IntY_val = IntY*DimDelta(ImBL,1)*1000
	
	Variable XL = floor((IntX-1)/2)
	Variable XR = ceil((IntX-1)/2)
	Variable YL = floor((IntY-1)/2)
	Variable YR = ceil((IntY-1)/2)
	
	
	if (intY > 1)
		Duplicate/O/R=[0,*][CutY-YL,CutY+YR][0,*]  VolData, Temp
		MatrixOp/O/NTHR=0 Temp2 = sumRows(Temp)
		ImT = Temp2[p][1][q]
	Else
		ImT[][] = VolData[p][CutY][q]
	EndIf
	
	If (IntX > 1)
		Duplicate/O/R=[CutX-XL,CutX+XR][0,*][0,*]  VolData, Temp
		MatrixOp/O/NTHR=0 Temp2 = sumCols(Temp)
		ImR = Temp2[0][q][p]
	Else
		ImR[][] = VolData[CutX][q][p]
	EndIf
	
	variable i, count
		imBL = 0; GrT = 0; GrR = 0;count=0;
		
	Variable startP, endP
	if(scanAsDelay == 1)
		startP = max(cutScan - intScan,0)
		endP = min(cutScan+intScan+1,sizeZ)
	else
		startP = max(cutZ - intZ,0)
		endP = min(cutZ+intZ+1,sizeZ)
	endif
		
	for(i=startP; i<endP;i+=1)
		ImBL[][] += VolData[p][q][i]
		GrT[] += ImT[p][i]
		GrR[] += ImR[i][p]
		count+=1
	endfor
	
	imBL = imBL/count
	GrT = GrT/count
	GrR = GrR/count
	
	If ( (IntX== 1) && (IntY == 1) )
		GrTR[] = VolData[CutX][CutY][p]
	ElseIf ( (IntX== 1) && (IntY > 1) )
		GrTR[] = ImT[CutX][p]
	ElseIf( (IntX>1) && (IntY==1))
		GrTR[] = ImR[p][CutY]
	Else
		Duplicate/O/R=[CutX-XL,CutX+XR][0,*]  ImT,Temp
		MatrixOp/O Temp2 = sumcols(Temp)
		GrTR[] = Temp2[0][p]
	EndIf
	
	Cursor/I/S=2/L=0/H=1/C=(65535,0,0)/P/W=$("Win"+prefix) C ImBL CutX,CutY
	CutX_val = DimOffset(ImBL,0) + (CutX)*DimDelta(ImBL,0)
	CutY_val = DimOffset(ImBL,1) + (CutY)*DimDelta(ImBL,1)
	
	Wave EnergyAxis, AngleAxis
	If (ShowInt==1)
	
		Variable XL_val = DimOffset(ImBL,0) + (CutX-XL-.5)*DimDelta(ImBL,0)
		Variable XR_val = DimOffset(ImBL,0) + (CutX+XR+.5)*DimDelta(ImBL,0)
		Variable YL_val = DimOffset(ImBL,1) + (CutY-YL-.5)*DimDelta(ImBL,1)
		Variable YR_val = DimOffset(ImBL,1) + (CutY+YR+.5)*DimDelta(ImBL,1)
		
		Variable lc = 48e3
		DrawAction/W=$("Win"+prefix) Delete
		PauseUpdate
		SetDrawEnv/W=$("Win"+prefix) xcoord= AxisB1,dash= 3, linefgc= (lc,lc,lc);DrawLine/W=$("Win"+prefix) XL_val,0,XL_val,1;
		SetDrawEnv/W=$("Win"+prefix) xcoord= AxisB1,dash= 3, linefgc= (lc,lc,lc);DrawLine/W=$("Win"+prefix) XR_val,0,XR_val,1
		SetDrawEnv/W=$("Win"+prefix) ycoord= AxisL1,dash= 3, linefgc= (lc,lc,lc);DrawLine/W=$("Win"+prefix) 0,YL_Val,1, YL_Val
		SetDrawEnv/W=$("Win"+prefix) ycoord= AxisL1,dash= 3, linefgc= (lc,lc,lc);DrawLine/W=$("Win"+prefix) 0,YR_Val,1, YR_Val
		//ResumeUpdate
	Else
		DrawAction/W=$("Win"+prefix) Delete
		EndIf
		
	ResumeUpdate
End

//added by Shoya
Function UpdateXSWindowForLoop(prefix)
	
	String prefix
	
	print("updateXSWindowForLoop("+prefix+")")
	
	//PauseUpdate
	
	SetDataFolder $("root:XS_"+prefix)

	Wave ImBL,ImT,ImR,VolData,GrT,GrR,GrTR,Delays,VolData4D,VolDims
	NVAR CutX,CutY,CutZ,IntX,IntY,ShowInt,whichgraphtoplot
	NVAR CutScan, IntScan
	NVAR IntX_val,IntY_val
	NVAR cutx_val,cuty_val
	Nvar intZ

	If (IntX < 1)
		IntX = 1
	EndIf
	If (IntY < 1)
		IntY = 1
	EndIf
	
	IntX_val = IntX*DimDelta(ImBL,0)
	IntY_val = IntY*DimDelta(ImBL,1)*1000
	
	Variable XL = floor((IntX-1)/2)
	Variable XR = ceil((IntX-1)/2)
	Variable YL = floor((IntY-1)/2)
	Variable YR = ceil((IntY-1)/2)
	
	
	if (intY > 1)
		Duplicate/O/R=[0,*][CutY-YL,CutY+YR][0,*]  VolData, Temp
		MatrixOp/O/NTHR=0 Temp2 = sumRows(Temp)
		ImT = Temp2[p][1][q]
	Else
		ImT[][] = VolData[p][CutY][q]
	EndIf
	If (IntX > 1)
		Duplicate/O/R=[CutX-XL,CutX+XR][0,*][0,*]  VolData, Temp
		MatrixOp/O/NTHR=0 Temp2 = sumCols(Temp)
		ImR = Temp2[0][q][p]
	Else
		ImR[][] = VolData[CutX][q][p]
	EndIf
	
	//GrT[] = ImT[p][CutZ]
	//GrR[] = ImR[CutZ][p]
	//ImBL[][] = VolData[p][q][CutZ]
	
	//added by Shoya
	variable i
		imBL = 0; GrT = 0; GrR = 0;
		
	for(i=max(cutZ - intZ,0); i<min(cutZ+intZ+1,VolDims[2]);i+=1)
		ImBL[][] += VolData[p][q][i]
		GrT[] += ImT[p][i]
		GrR[] += ImR[i][p]
		//print(i)
	endfor
	
	If ( (IntX== 1) && (IntY == 1) )
		GrTR[] = VolData[CutX][CutY][p]
	ElseIf ( (IntX== 1) && (IntY > 1) )
		GrTR[] = ImT[CutX][p]
	ElseIf( (IntX>1) && (IntY==1))
		GrTR[] = ImR[p][CutY]
	Else
		Duplicate/O/R=[CutX-XL,CutX+XR][0,*]  ImT,Temp
		MatrixOp/O Temp2 = sumcols(Temp)
		GrTR[] = Temp2[0][p]
	EndIf
	
	//Cursor/I/S=2/L=0/H=1/C=(65535,0,0)/P/W=$("Win"+prefix) C ImBL CutX,CutY
	CutX_val = DimOffset(ImBL,0) + (CutX)*DimDelta(ImBL,0)
	CutY_val = DimOffset(ImBL,1) + (CutY)*DimDelta(ImBL,1)
	
	//ResumeUpdate
End



Function SetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	SVAR/Z gprefix
	
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			UpdateXSWindow(gprefix)
			break
	endswitch

	return 0
End

Function CheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba
	SVAR/Z gprefix
	
	Variable/G ShowInt
	
	switch( cba.eventCode )
		case 2: // mouse up
			if(ShowInt==1)
			Else
				DrawAction Delete
				DoUpdate
			EndIf
			UpdateXSWindow(gprefix)
			break
	endswitch

	return 0
End

Function SetVarProc_1(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	SVAR/Z gprefix
	
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval

			UpdateXSWindow(gprefix)
			
			break
	endswitch

	return 0
End

Function SetZProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	SVAR/Z gprefix
	NVar scanAsDelay
	
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			
			if(scanAsDelay == 1)
				makeVolDataFromVolData4D(gprefix,0)
			else
				Wave Layers,GrTR
				Cursor/F D GrTR Layers[dval],GrTr[dval]
			endif
			
			break
	endswitch

	return 0
End


////added by Shoya
Function SetIntDelay(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	Svar gprefix
	Nvar scanAsDelay
	
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			
			if(scanAsDelay == 1)
				makeVolDataFromVolData4D(gprefix,0)
			else
				UpdateXSWindow(gprefix)
			endif
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SetCutScan(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	
	SVAR/Z gprefix
	Nvar scanAsDelay

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			
			if(scanAsDelay == 1)
				Wave Layers,GrTR
				Cursor/F D GrTR Layers[dval],GrTr[dval]
			else
				makeVolDataFromVolData4D(gprefix,0)
			endif
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SetIntScanWindow(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	
	SVAR/Z gprefix
	Nvar scanAsDelay

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			
			if(scanAsDelay == 1)
				UpdateXSWindow(gprefix)
			else
				makeVolDataFromVolData4D(gprefix,0)
			endif
			
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

function makeVolDataFromVolData4D(prefix,quiet)
	string prefix
	variable quiet
	
	print("makeVolDataFromVolData4D("+prefix+")")
	
	//PauseUpdate
	
	SetDataFolder $("root:XS_"+prefix)

	wave volData, VolData4D
	NVAR cutScan, intScan, cutZ, intZ, scanAsDelay
	Svar gprefix
	//added by Shoya
	variable i,j
	
	variable startP,endP
	
	if(scanAsDelay == 0)
		
		startP = max(cutScan - intScan,0)
		endP =  min(cutScan + intScan, dimsize(VolData4D,3)-1)
		redimension/N=(-1,-1,dimsize(VolData4D,2)) VolData
		multithread  volData[][][] = 0
		
		for(i = startP; i <= endP; i+=1)
			multithread volData += VolData4D[p][q][r][i]
		endfor
		
		multithread volData /= (endP-startP+1)
		
	elseif(scanAsDelay == 1)
	
		startP = max(cutZ - intZ,0)
		endP =  min(cutZ + intZ, dimsize(VolData4D,2)-1)
		//print("scanAsDelay"+num2str(startP)+num2str(endP))
		redimension/N=(-1,-1,dimsize(VolData4D,3)) VolData
		multithread  volData[][][] = 0
		
		for(i = startP; i <= endP; i+=1)
			multithread volData += VolData4D[p][q][i][r]
		endfor
		
		multithread volData /= (endP-startP+1)
		
	else
		return nan
	endif
	
	//multithread volData = VolData/(endP-startP+1)


	if (quiet == 0)
		updateXSWindow(gprefix)
	else 
		updateXSWindowForLoop(gprefix)
	endif
	
end




Function ButtonProc_DeleteVolData4D(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	SVAR gprefix
	Nvar collapsed
	
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			
			doAlert/T="Delete VolData4D" 1, "Be aware that 4D VolData will be completely deleted and can not be resotored."
			if(V_flag == 2)
				break
			endif
			
			//wave volData
			wave volData4D
			//volData[][][] = 0
			variable i
			
			//for(i = 0; i < dimsize(VolData4D,3); i+=1)
			//	volData[][][] += VolData4D[p][q][r][i]
			//endfor
			//volData = volData/ dimsize(VolData4D,3)
			
			collapsed = 1
			setVariable cutScan, disable=2
			setVariable setIntScanWindow, disable=2
			Button DeleteVolData4D disable=2
			checkbox scanAsDelay disable =2
			
			//XSection(gprefix)
			//updateXSWindow(gprefix)
			
			killwaves VolData4D
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function CheckProc_ScanAsDelay(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	Svar gprefix
	//Nvar ScanAsDelay

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			print(checked)
			//ScanAsDelay = checked

			makeVolDataFromVolData4D(gprefix,0)
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


/////for the subpanel
Function SliderProc_ColorXS(sa) : SliderControl
	STRUCT WMSliderAction &sa
	
	switch( sa.eventCode )
		case -1: // control being killed
			break
		default:
			if( sa.eventCode & 1 ) // value set
				Variable curval = sa.curval
				
				String winprefix = GetUserData("","","")
				SetDataFolder $("root:XS_"+winprefix)
				
				Wave imBL, imR, imT
	
				variable maxImBL, maxImT, maxImR
				maxImBL=wavemax(imBL); maxImT=wavemax(imT);maxImR=wavemax(imR)
	
				Nvar FirstColor, LastColor
				Svar colorTable	
				
				//FirstColor=curval*maxW
				modifyimage imBL ctab={FirstColor*maxImBL,LastColor*maxImBL,$ColorTable,0}
				modifyimage imT ctab={FirstColor*maxImT,LastColor*maxImT,$ColorTable,0}
				modifyimage imR ctab={FirstColor*maxImR,LastColor*maxImR,$ColorTable,0}
				
			endif
			break
	endswitch
	
	return 0
End

Function ListBoxProc_ColorTable(lba) : ListBoxControl
	STRUCT WMListboxAction &lba
	
	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave
	
	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			break
		case 3: // double click
			break
		case 4: // cell selection
			
			String winprefix = GetUserData("","","")
			SetDataFolder $("root:XS_"+winprefix)
			
			wave imBL,imT,imR
			Nvar FirstColor, LastColor, colorIndex
			Svar colorTable
	
			variable maxImBL, maxImT, maxImR
			maxImBL=wavemax(imBL); maxImT=wavemax(imT);maxImR=wavemax(imR)
			
			ColorIndex = row
			ColorTable = listwave[row]
			modifyimage imBL ctab={FirstColor*maxImBL,LastColor*maxImBL,$ColorTable,0}
			modifyimage imT ctab={FirstColor*maxImT,LastColor*maxImT,$ColorTable,0}
			modifyimage imR ctab={FirstColor*maxImR,LastColor*maxImR,$ColorTable,0}
		case 5: // cell selection plus shift key
			break
		case 6: // begin edit
			break
		case 7: // finish edit
			break
		case 13: // checkbox clicked (Igor 6.2 or later)
			break
	endswitch

	return 0
End

Function ButtonProc_DeadPixelRemover(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			
			String winprefix = GetUserData("","","")
			SetDataFolder $("root:XS_"+winprefix)
			XS_DeadpixelRemover(1)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function ButtonProc_showSubPanel(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	Svar gprefix
	Nvar subPanelHidden
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			subPanelHidden = subPanelHidden == 0 ? 1 : 0
			SetWindow $("Sub"+gprefix) hide=subPanelHidden
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


////added by Shoya up to here

Function ButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	SVAR gprefix
	
	switch( ba.eventCode )
		case 2: // mouse up
			UpdateXSData(gprefix)
			break
	endswitch

	return 0
End

Window XSLoader() : Panel
	String/G TempPrefix,TempPathString
	Variable/G TempSize

	print("XSLoader()")

	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(298,362,695,491)
	
	SetDrawLayer UserBack
	SetDrawEnv fname= "MS Sans Serif"
	DrawText 12,31,"Data path:"
	SetVariable prefix,pos={17,75},size={200,16},title="Name of dataset:"
	SetVariable prefix,value= TempPrefix
	Button ChoosePath,pos={320,39},size={70,20},proc=ButtonProcSelectPath,title="Select"
	TitleBox PathString,pos={14,38},size={287,23}
	TitleBox PathString,variable= TempPathString,fixedSize=1
	Button OKButton,pos={331,93},size={50,20},proc=ButtonProcOK,title="OK!"
	SetVariable SetDelayPts,pos={15,101},size={155,16},bodyWidth=60,title="No. of delay points:"
	SetVariable SetDelayPts,limits={1,inf,0},value= TempSize,live= 1
EndMacro

// Select path button
Function ButtonProcSelectPath(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	SetDataFolder root:

	switch( ba.eventCode )
		case 2: // mouse up
				SVAR TempPathString
				NewPath /Q/O/M="Choose a data folder" TempPath
				PathInfo TempPath
				TempPathString =  S_path
				doupdate
			break
	endswitch

	return 0
End

Function ButtonProcOK(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	SetDataFolder root:
	SVAR TempPrefix,TempPathString 
	NVAR TempSize
	

	
	PauseUpdate; Silent 1
	
	switch( ba.eventCode )
		case 2: // mouse up
		
			
			String path, prefix
			path = (TempPrefix+"Path") 
			prefix = TempPrefix
			
			NewPath/O $(path),TempPathString

			If (InitXSection(path,TempPrefix,TempSize)==-1)
				Return -1
			EndIf
			
			SetDataFolder $("root:XS_"+prefix)
			XSection(TempPrefix)
			
				
			KillStrings root:TempPrefix,root:TempPathString
			KillVariables root:TempSize
			DoWindow/K XSLoader
			
			SetDataFolder $("root:XS_"+prefix)
			UpdateXSData(prefix)
			
			break
	endswitch

	return 0
End

Function ButtonProc_Findto(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	Variable/G to_fs
	Variable/G to_um
	Wave Delays
	
	switch( ba.eventCode )
		case 2: // mouse up
				Wave W_coef
				//CurveFit/M=0/W=0/Q gauss, GrTR[min(pcsr(A),pcsr(B)),max(pcsr(A),pcsr(B))]/D /X=Delays
				to_fs = W_coef[2]
				to_um = 2*to_fs*(2.99792e-1)
				
				FuncFit/NTHR=0 GaussianFWHM W_coef  GrTR[pcsr(A),pcsr(B)] /X=Delays /D 
				
				break
	endswitch

	return 0
End


// Adapted from i_photo
Function XS_prefs_initAutosaveTask()
	KillBackground
	SetBackground XS_prefs_autosaveTask()
	CtrlBackground period=3600,dialogsOk=0,noBurst=1
	Variable autosave_interval = 30
	String autosave_fname = "XS_autosave.pxp"
	
	//check if autosave was already initialized
	if ( exists("root:XS_Globals:gv_minutesToNextAutosave") == 0 )
		NewDataFolder/O root:XS_Globals
		Variable/G root:XS_Globals:gv_minutesToNextAutosave = autosave_interval + 1
		if (autosave_interval > 0)
			printf "%s, %s, Initializing Autosave task: save to '%s' every %d minutes.\r", Date(), Time(), autosave_fname, autosave_interval
		else
			printf "%s, %s, Initializing Autosave task: Autosave is disabled.\r", Date(), Time()
		endif
	endif
		

	SetBackground XS_prefs_autosaveTask()
	// initialize background task to exec every minute.
	CtrlBackground period=3600,noBurst=1,dialogsOK=0, start
End


// Adapted from i_photo
Function XS_prefs_autosaveTask()
	Variable autosave_interval = 15
	String autosave_fname = "XS_autosave.pxp"
	
	NVAR minutesToNextAutosave = root:XS_Globals:gv_minutesToNextAutosave
	
	if (autosave_interval <= 0) // autosave disabled
		minutesToNextAutosave = 0
		return 0
	endif
	
	minutesToNextAutosave -= 1
	
	if (minutesToNextAutosave <= 0)
		printf "Autosave: %s ", Time()
		minutesToNextAutosave = autosave_interval
		if (strlen(PathList("home",";","")) == 0)
			//DoAlert 0, "AutoSave does not work for experiments which have never been saved.\rTo turn off this annoying message, either save your experiment or turn off AutSave in preferences."
			printf "WARNING: NOT saved since experiment was never saved by user.\r"
		endif
		PathInfo home
		if (V_flag != 1)
			printf "WARNING: current path does not exist. ('%s'). NOT saving.\r", S_path
			return 0
		endif
		if (stringmatch(S_path, "*WaveMetrics:Igor Pro Folder*"))
			printf "WARNING: current path still seems to be the Igor Pro folder ('%s'). NOT saving.\r", S_path
			return 0
		endif
		printf "saving experiment as '%s' in directory '%s'.\r", autosave_fname, S_path
		SaveExperiment/C/P=home as autosave_fname
	endif
	return 0
End

Function ChooseGraphProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa
	NVAR WhichGraphToPlot
	
	switch( pa.eventCode )
		case 2: // mouse up
			WhichGraphToPlot = pa.popNum
			//String popStr = pa.popStr
			break
	endswitch

	return 0
End

Function DisplayGraphProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	NVAR WhichGraphToPlot
	NVAR DuplicateGraph,GraphOnNewAxis
	NVAR EDC_no,MDC_No,TDC_no, CutZ
	Wave GrTR,Delays,GrR,GrR_Y,GrT
	SVAR gprefix
	Wave Layers
	
	String numStr
	String axisName = "left"
	
	switch( ba.eventCode )
		case 2: // mouse up
			switch(WhichGraphToPlot)	
				case 1:		
					if (DuplicateGraph==1)
						sprintf numStr, "%03.f", TDC_no
						Duplicate GrTR, $(":Duplicated:"+gprefix+"_GrTR_"+numStr)
						Duplicate Layers, $(":Duplicated:"+gprefix+"_Delays_"+numStr)
						if(GraphOnNewAxis==1)
							axisName = "left_"+gprefix+"_"+numStr
						EndIf
						Display/L=$axisName  $(":Duplicated:"+gprefix+"_GrTR_"+numStr) vs $(":Duplicated:"+gprefix+"_Delays_"+numStr)
						ModifyGraph freePos($axisName)=0 , lsize = 2
						TDC_no +=1
					Else
						if(GraphOnNewAxis==1)
							axisName = "left_"+gprefix+"_live"
						EndIf
						Display/L=$axisName GrTR vs Layers
						ModifyGraph freePos($axisName)=0 , lsize = 2
					EndIf
					break						
				case 2:		
					if (DuplicateGraph==1)
						sprintf numStr, "%03.f", EDC_no
						Duplicate GrR,  $(":Duplicated:"+gprefix+"_GrR_"+numStr)
						SetScale/P x, GrR_Y[0], (GrR_Y[1]-GrR_Y[0]), $(":Duplicated:"+gprefix+"_GrR_"+numStr)
				
						if(GraphOnNewAxis==1)
							axisName = "left_"+gprefix+"_"+numStr
						EndIf
						Display/L=$axisName $(":Duplicated:"+gprefix+"_GrR_"+numStr)
						ModifyGraph freePos($axisName)=0 , lsize = 2
						EDC_no +=1
					Else
						if(GraphOnNewAxis==1)
							axisName = "left_"+gprefix+"_live"
						EndIf
						Display/L=$axisName GrR vs GrR_Y
						ModifyGraph freePos($axisName)=0 , lsize = 2
					EndIf
					break	
				case 3:		
					if (DuplicateGraph==1)
						sprintf numStr, "%03.f", MDC_no
						Duplicate GrT, $(":Duplicated:"+gprefix+"_GrT_"+numStr)
						if(GraphOnNewAxis==1)
							axisName = "left_"+gprefix+"_"+numStr
						EndIf
						Display/L=$axisName   $(":Duplicated:"+gprefix+"_GrT_"+numStr)
						ModifyGraph freePos($axisName)=0 , lsize = 2
						MDC_no +=1
					Else
						if(GraphOnNewAxis==1)
							axisName = "left_"+gprefix+"_live"
						EndIf
						Display/L=$axisName GrT
						ModifyGraph freePos($axisName)=0 , lsize = 2
					EndIf
					break	
				case 4:
					if(GraphOnNewAxis==1)
							print "Note: The \"On new vertical axis\" command is ignored when plotting images "
					endif
						
					if( DuplicateGraph==1)
						sprintf numStr, "%03.f", CutZ
						Duplicate/O ImBL, $(":Duplicated:"+gprefix+"_ImBL_Delay"+numStr)
						Display /W=(35.25,41.75,324,380); AppendImage $(":Duplicated:"+gprefix+"_ImBL_Delay"+numStr)
						ModifyImage  $(gprefix+"_ImBL_Delay"+numStr) ctab= {*,*,Terrain256,0}
					Else
						Display /W=(35.25,41.75,324,380); AppendImage ImBL
						ModifyImage ImBL ctab= {*,*,Terrain256,0}
					EndIf
					break
				case 5:
					if(GraphOnNewAxis==1)
							print "Note: The \"On new vertical axis\" command is ignored when plotting images "
					endif
						
					if( DuplicateGraph==1)
						Variable ImR_no = -1
						do
							ImR_no+=1;sprintf numStr, "%03.f", ImR_no
						while(exists(":Duplicated:"+gprefix+"_ImR_"+numStr))
							
						
						Duplicate/O ImR, $(":Duplicated:"+gprefix+"_ImR_"+numStr)
						Display /W=(35.25,41.75,324,380); AppendImage $(":Duplicated:"+gprefix+"_ImR_"+numStr) vs {LayerAxis,EnergyAxis}
						ModifyImage $(gprefix+"_ImR_"+numStr) ctab= {*,*,Terrain256,0}
					Else
						Display /W=(35.25,41.75,324,380); AppendImage ImR vs {LayerAxis,EnergyAxis}
						ModifyImage ImR ctab= {*,*,Terrain256,0}
					EndIf
					break
				case 6:
					if(GraphOnNewAxis==1)
							print "Note: The \"On new vertical axis\" command is ignored when plotting images "
					endif
						
					if( DuplicateGraph==1)
						Variable ImT_no = -1
						do
							ImT_no+=1;sprintf numStr, "%03.f", ImT_no
						while(exists(":Duplicated:"+gprefix+"_ImT_"+numStr))
							
						
						Duplicate/O ImT, $(":Duplicated:"+gprefix+"_ImT_"+numStr)
						Display /W=(35.25,41.75,324,380); AppendImage $(":Duplicated:"+gprefix+"_ImT_"+numStr) vs {AngleAxis,LayerAxis}
						ModifyImage $(gprefix+"_ImT_"+numStr) ctab= {*,*,Terrain256,0}
					Else
						Display /W=(35.25,41.75,324,380); AppendImage ImT vs {AngleAxis,LayerAxis}
						ModifyImage ImT ctab= {*,*,Terrain256,0}
					EndIf
					break
					
			endswitch
			break
	endswitch

	return 0
End

Function AppendGraphProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	NVAR/Z WhichGraphToPlot
	NVAR/Z DuplicateGraph,GraphOnNewAxis
	NVAR/Z EDC_no,MDC_No,TDC_no, CutZ
	Wave GrTR,Delays,GrR,GrR_Y,GrT
	SVAR/Z gprefix
	
	String gN = WinName(1,1)
	String axisName = "left"
	
	String numStr
	switch( ba.eventCode )
		case 2: // mouse up
			switch(WhichGraphToPlot)	
				case 1:		
					if (DuplicateGraph==1)
						sprintf numStr, "%03.f", TDC_no
						Duplicate GrTR, $(":Duplicated:"+gprefix+"_GrTR_"+numStr)
						Duplicate Delays, $(":Duplicated:"+gprefix+"_Delays_"+numStr)
						if(GraphOnNewAxis==1)
							axisName = "left_"+gprefix+"_"+numStr
						EndIf
						AppendToGraph/W=$gN/L=$axisName  $(":Duplicated:"+gprefix+"_GrTR_"+numStr)vs  $(":Duplicated:"+gprefix+"_Delays_"+numStr)
						ModifyGraph/W=$gN freePos($axisName)=0 , lsize = 2
						TDC_no +=1
					Else
						if(GraphOnNewAxis==1)
							axisName = "left_"+gprefix+"_live"
						EndIf
						AppendToGraph/W=$gN/L=$axisName GrTR vs Delays
						ModifyGraph/W=$gN freePos($axisName)=0 , lsize = 2
					EndIf
					break						
				case 2:		
					if (DuplicateGraph==1)
						sprintf numStr, "%03.f", EDC_no
						Duplicate GrR,  $(":Duplicated:"+gprefix+"_GrR_"+numStr)
						SetScale/P x, GrR_Y[0], (GrR_Y[1]-GrR_Y[0]), $(":Duplicated:"+gprefix+"_GrR_"+numStr)
						if(GraphOnNewAxis==1)
							axisName = "left_"+gprefix+"_"+numStr
						EndIf
						AppendToGraph/W=$gN/L=$axisName  $(":Duplicated:"+gprefix+"_GrR_"+numStr)
						ModifyGraph/W=$gN freePos($axisName)=0, lsize = 2
						EDC_no +=1
					Else
						if(GraphOnNewAxis==1)
							axisName = "left_"+gprefix+"_live"
						EndIf
						AppendToGraph/W=$gN/L=$axisName GrR vs GrR_Y
						ModifyGraph/W=$gN freePos($axisName)=0, lsize = 2
					EndIf
					break	
				case 3:		
					if (DuplicateGraph==1)
						sprintf numStr, "%03.f", MDC_no
						Duplicate GrT, $(":Duplicated:"+gprefix+"_GrT_"+numStr)
						if(GraphOnNewAxis==1)
							axisName = "left_"+gprefix+"_"+numStr
						EndIf
						AppendToGraph/W=$gN/L=$axisName   $(":Duplicated:"+gprefix+"_GrT_"+numStr)
						ModifyGraph/W=$gN freePos($axisName)=0, lsize = 2
						MDC_no +=1
					Else
						if(GraphOnNewAxis==1)
							axisName = "left_"+gprefix+"_live"
						EndIf
						AppendToGraph/W=$gN/L=$axisName GrT
						ModifyGraph/W=$gN freePos($axisName)=0, lsize = 2
					EndIf
					break	
				case 4:
					if(GraphOnNewAxis==1)
							print "Note: The \"On new vertical axis\" command is ignored when plotting images "
					endif
					if( DuplicateGraph==1)
						sprintf numStr, "%03.f", CutZ
						Duplicate/O ImBL, $(":Duplicated:"+gprefix+"_ImBL_Delay"+numStr)
						AppendImage/W=$gN $(":Duplicated:"+gprefix+"_ImBL_Delay"+numStr)
						ModifyImage/W=$gN  $(gprefix+"_ImBL_Delay"+numStr) ctab= {*,*,Terrain256,0}
					Else
						AppendImage/W=$gN ImBL
						ModifyImage/W=$gN ImBL ctab= {*,*,Terrain256,0}
					EndIf
					break
				case 5:
					if(GraphOnNewAxis==1)
							print "Note: The \"On new vertical axis\" command is ignored when plotting images "
					endif
						
					if( DuplicateGraph==1)
						Variable ImR_no = -1
						do
							ImR_no+=1;sprintf numStr, "%03.f", ImR_no
						while(exists(":Duplicated:"+gprefix+"_ImR_"+numStr))
							
						
						Duplicate/O ImR, $(":Duplicated:"+gprefix+"_ImR_"+numStr)
						AppendImage/W=$gN $(":Duplicated:"+gprefix+"_ImR_"+numStr) vs {DelayAxis,EnergyAxis}
						ModifyImage/W=$gN $(gprefix+"_ImR_"+numStr) ctab= {*,*,Terrain256,0}
					Else
						 AppendImage/W=$gN ImR vs {DelayAxis,EnergyAxis}
						ModifyImage/W=$gN ImR ctab= {*,*,Terrain256,0}
					EndIf
					break
				case 6:
					if(GraphOnNewAxis==1)
							print "Note: The \"On new vertical axis\" command is ignored when plotting images "
					endif
						
					if( DuplicateGraph==1)
						Variable ImT_no = -1
						do
							ImT_no+=1;sprintf numStr, "%03.f", ImT_no
						while(exists(":Duplicated:"+gprefix+"_ImT_"+numStr))
							
						
						Duplicate/O ImT, $(":Duplicated:"+gprefix+"_ImT_"+numStr)
						AppendImage/W=$gN $(":Duplicated:"+gprefix+"_ImT_"+numStr) vs {AngleAxis,DelayAxis}
						ModifyImage/W=$gN $(gprefix+"_ImT_"+numStr) ctab= {*,*,Terrain256,0}
					Else
						 AppendImage/W=$gN ImT vs {AngleAxis,DelayAxis}
						ModifyImage/W=$gN ImT ctab= {*,*,Terrain256,0}
					EndIf
					break
					
			endswitch
			break
	endswitch

	return 0
End

Function RainbowProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
		//from PSK
			String gN = WinName(1,1)
			
			silent 1;pauseupdate
			Variable tnl_max = ItemsInList(TraceNameList(gN,";",1))
			If (tnl_max > 0)
			Variable nt=0
			Do
			//if(mod(nt,2) !=0)
				ModifyGraph/Z/W=$gN rgb[nt]=(rainbowR(1*nt/tnl_max), rainbowG(1*nt/tnl_max), rainbowB(1*nt/tnl_max) )
			//endif
			nt+=1
			While (nt < tnl_max)
		Endif
			break
	endswitch

	return 0
End



//*** returns Red component of rainbow
Function rainbowR(percent)
	Variable percent
	If (percent < 0.2)
		return (65535*percent*5)
	Elseif (percent < 0.25)
		return 65535
	Elseif (percent < 0.75)
		return (65535*(0.75-percent)*2)
	ElseIf (percent > 0.75)
		return (65535*(percent-0.75)*4)
	Else
		return 0
	Endif
End
//*** returns Green component of rainbow
Function rainbowG(percent)
	Variable percent
	If (percent < 0.1)
		return 0
	ElseIf (percent < 0.4)
		return (65535*(percent-0.1)*3.333)
	ElseIf (percent < 0.5)
		return 65535
	ElseIf (percent < 0.95)
		return (65535*(0.95-percent)*2.222)
	Else
		return 0
	Endif
End
//*** returns Blue component of rainbow
Function rainbowB(percent)
	Variable percent
	If (percent < 0.5)
		return 0
	ElseIf (percent < 0.75)
		return (65535*(percent-0.5)*4)
	Else
		return 65535
	Endif
End

Function ReinitVariables()
	NewDataFolder/O Duplicated
	
	Variable/G ScanNo 
	Variable/G DelayNo
	
	Variable/G CutX
	Variable/G CutY
	Variable/G CutX_val, CutY_val
	Variable/G CutZ
	
	Variable/G IntX
	Variable/G IntY
	Variable/G IntX_val
	Variable/G IntY_val

	Variable/G CutX_val, CutY_val
	
	Variable/G ShowInt 
	
	Variable/G to_fs 
	Variable/G to_um 
	
	Variable/G EDC_no 
	Variable/G MDC_no 
	Variable/G TDC_no
End

Function CutXChangeProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			SVAR gprefix
			UpdateXSWindow(Gprefix)
			break
	endswitch

	return 0
End

Function ChangeEnergyCutProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			SVAR gprefix
			UpdateXSWindow(Gprefix)
			break
	endswitch

	return 0
End


Function FitGaussButton(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			XS_FitGaussFWHM()
			break
	endswitch

	return 0
End

Function GaussExpButton(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			XS_FitGaussTimeShape(1)
			break
	endswitch

	return 0
End

Function XS_FitGaussFWHM()
	Wave GrTR, Delays
	
	Variable minX = 0
	Variable maxX = Inf
	
	if(StringMatch(StringByKey("TNAME",CsrInfo(A)),"GrTR") && StringMatch(StringByKey("TNAME",CsrInfo(B)),"GrTR") )
		minX = min(xcsr(A),xcsr(B))
		maxX =max(xcsr(A),xcsr(B))
	EndIf
	
	CurveFit/Q gauss,GrTR[minX,maxX] /X=Delays[minX,maxX]/D
	
	Wave w_coef, w_sigma
	
	Print "-----------------------------------------------"
	Print "Magnitude\t= " + num2str(w_coef[1]) + "\t +/- " + num2str(w_sigma[1])
	Print "FWHM     \t= "      + num2str(w_coef[3]*1.6651) + " +/- " + num2str(w_sigma[3]*1.6651)
	Print "t0             \t= " + num2str(w_coef[2]) + "\t +/- " + num2str(w_sigma[2])
	Print "Background\t= " + num2str(w_coef[0]) + "\t +/- " + num2str(w_sigma[0])
	Print "-----------------------------------------------"
End

Function XS_FitGaussTimeShape(quiet)
	Variable quiet
	
	Wave GrTR, Delays
	
	Variable minX = 0
	Variable maxX = Inf
	
	if(StringMatch(StringByKey("TNAME",CsrInfo(A)),"GrTR") && StringMatch(StringByKey("TNAME",CsrInfo(B)),"GrTR") )
		minX = min(xcsr(A),xcsr(B))
		maxX =max(xcsr(A),xcsr(B))
	EndIf
	
	
	//Do Gauss fit first
	CurveFit/Q/W=2 gauss,GrTR[minX,maxX] /X=Delays[minX,maxX]
	
	Wave w_coef, w_sigma
	
	Duplicate/O w_coef, w_coef_G
	
	Make/N=5/O W_coef
	W_coef[0] = {w_coef_G[1],w_coef_G[3],w_coef_G[3],w_coef_G[2],w_coef_G[0]}
	FuncFit/Q/W=2 XS_TimeShape W_coef  GrTR[minX,maxX] /X=Delays[minX,maxX]/D
	
	if(quiet !=0)
	Print "-----------------------------------------------"
	Print "Magnitude\t= " + num2str(w_coef[0]) + "\t +/- " + num2str(w_sigma[0])
	Print "FWHM     \t= "      + num2str(w_coef[1]*1.6651) + " +/- " + num2str(w_sigma[1]*1.6651)
	Print "Tau          \t= " + num2str(w_coef[2]) + "\t +/- " + num2str(w_sigma[2])
	Print "t0             \t= " + num2str(w_coef[3]) + "\t +/- " + num2str(w_sigma[3])
	Print "Background\t= " + num2str(w_coef[4]) + "\t +/- " + num2str(w_sigma[4])
	Print "-----------------------------------------------"
	endif
	
End


Function XS_TimeShape(w,t) : FitFunc
	Wave w
	Variable t

	//CurveFitDialog/ These comments were created by the Curve Fitting dialog. Altering them will
	//CurveFitDialog/ make the function less convenient to work with in the Curve Fitting dialog.
	//CurveFitDialog/ Equation:
	//CurveFitDialog/ f(t) = A*sqrt(2/pi) * exp( (sig^2 - 4*tau*(t-t0)) / (4*tau^2) ) * (1+erf( -(sig^2 - 2*tau*(t-t0)) / (2*sig*tau) ))+B
	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ t
	//CurveFitDialog/ Coefficients 5
	//CurveFitDialog/ w[0] = A
	//CurveFitDialog/ w[1] = sig
	//CurveFitDialog/ w[2] = tau
	//CurveFitDialog/ w[3] = t0
	//CurveFitDialog/ w[4] = B

	return w[0]*sqrt(2/pi) * exp( (w[1]^2 - 4*w[2]*(t-w[3])) / (4*w[2]^2) ) * (1+erf( -(w[1]^2 - 2*w[2]*(t-w[3])) / (2*w[1]*w[2]) ))+w[4]
End


Function XS_AutoFFT()
	Wave VolData, VolDims,LoadedData
	SVAR gprefix
	
	if(DataFolderExists("root:XS_"+gprefix+"_G"))
		String alertStr = "Sorry, you already have a data set with the name "
		alertStr += gprefix+"_G. Please rename or delete it if you want to proceed. \n\n"
		alertStr += "Operation aborted."
		DoAlert/T="Error" 0, alertstr
		return -1
	EndIf
						

	DuplicateDataFolder $("root:XS_"+gprefix), $("root:XS_"+gprefix+"_G")
	SetDataFolder $("root:XS_"+gprefix+"_G")
	
	Wave VolData, VolDims,LoadedData, AngleAxis
	SVAR gprefix
	gprefix = gprefix+"_G"
	
	variable xsize, ysize, zsize, tsize
	xsize=dimsize(VolData,0);ysize=dimsize(VolData,1);zsize=dimsize(VolData,2)
	
	// If there's an odd number of angle channels
	variable redim = 0
	if(mod(xsize,2)==1)
		redim = 1
		VolDims[0] +=1;xsize+=1
		ReDimension/N=(xsize,-1,-1) VolData
		ReDimension/N=(xsize,-1) ImT
		ReDimension/N=(xsize,-1) ImBL
		ReDimension/N=(xsize) GrT
		ReDimension/N=(xsize+1) AngleAxis
		AngleAxis[xsize] = 2*AngleAxis[xsize-1] - AngleAxis[xsize-2]
	EndIf
	
   Duplicate/O ImBL, FilterFunc, Collapsed_FFT, wDetIm
      
//	Duplicate/O ImBL, Collapsed
//	Collapsed = 0
	
	Variable StartX, EndX
   Variable StartY, EndY
   StartX = Str2Num(StringByKey("CCDFirstXChannel",note(LoadedData),"=","\r"))
	EndX = Str2Num(StringByKey("CCDLastXChannel",note(LoadedData),"=","\r"))
	StartY = Str2Num(StringByKey("CCDFirstYChannel",note(LoadedData),"=","\r"))
   EndY = Str2Num(StringByKey("CCDLastYChannel",note(LoadedData),"=","\r"))
	SetScale/I x,StartY,EndY,wDetIm
	SetScale/I y,StartX,EndX,wDetIm

	Variable N
//	For(N=0; N<VolDims[2];N+=1)
//		Collapsed += VolData[p][q][N]
//	EndFor
	
	FFT/OUT=4/Dest=FilterFunc wDetIm;
//	Duplicate/O Collapsed_FFT, FilterFunc
//	FFT/OUT=1/Dest=Collapsed_FFT Collapsed;
	FilterFunc = 1
	
// SES 200 settings
//	FilterFunc -= XS_GaussFunc2D(x,y,.012797,.02,-.10665,.03)
//	FilterFunc -= XS_GaussFunc2D(x,y,.10598,0.03,.012111,0.02)
//	FilterFunc -= XS_GaussFunc2D(x,y,.1173,0.03,-.094004,0.03)
//	FilterFunc -= XS_GaussFunc2D(x,y,.092925,0.03,.11965,0.03)
//	FilterFunc -= XS_GaussFunc2D(x,y,.21191,0.04,.025077,0.03)
//	FilterFunc -= XS_GaussFunc2D(x,y,.02552,0.03,-.21399,0.03)
	
//R4000 settings
	Variable ni, nj
	Variable vx, vy
	For(ni = -5; ni<=5; ni+=1)
		For(nj = -5; nj <=5; nj +=1)
			If(ni == 0 && nj==0)
				continue
			EndIf
			//vx = ni * 0.0429105 + nj * 0.08034
			//vy = ni * 0.07898 + nj * -0.0434785
			// New values from May 2018
			vx = ni * 0.0455 + nj * 0.0817
			vy = ni * 0.0821 - nj * 0.0439
			FilterFunc -= XS_GaussFunc2D(x,y, vx ,.015,vy,.015)
		EndFor
	EndFor
	
	Collapsed_FFT = Collapsed_FFT[p][q]*FilterFunc[p][q]
	IFFT/Dest=Collapsed_Filtered Collapsed_FFT
	
	Duplicate/O ImBL, Temp
	
	//added by Shoya, remove high-frequency or low amplitude component
	variable i,j
	//for(i=0;i<dimsize(FilterFunc,0);i+=1)
	//	for(j=0;j<dimsize(FilterFunc,1);j+=1)
	//		variable xFFT = (dimoffset(FilterFunc,0) + dimdelta(FilterFunc,0) * i)/(dimoffset(FilterFunc,0) + dimdelta(FilterFunc,0) * dimsize(FilterFunc,0))
	//		variable yFFT = (dimoffset(FilterFunc,1) + dimdelta(FilterFunc,1) * j)/(dimoffset(FilterFunc,1) + dimdelta(FilterFunc,1) * dimsize(FilterFunc,1))
	//		variable radius = sqrt(xFFT^2 + yFFT^2)
	//		if (radius > 0.5) // cut high-frequency components
	//			FilterFunc[i][j] = 0
	//		endif
			
			//if (magsqr(spec_FFT[i][j]) < 100) // cut low-amplitude comonents
			//	FilterFunc[i][j] = 0
			//endif
			
		//endfor
	//endfor
	
	For(N=0;N<zsize;N+=1)
		Temp = VolData[p][q][N]
		//Temp[178,323] = 0
		
		FFT/OUT=1/Dest=Temp2 Temp;
		//Wave Temp2
		Temp2 *= FilterFunc
		//Temp2 *= 1 - exp(-(p-6)^2/10^2 - (q-141)^2/15^2)- exp(-(p-39)^2/10^2 - (q-258)^2/20^2)- exp(-(p-34)^2/10^2 - (q-362)^2/10^2)- exp(-(p-43)^2/10^2 - (q-153)^2/10^2)- exp(-(p-78)^2/10^2 - (q-269)^2/10^2) - exp(-(p-10)^2/10^2 - (q-34)^2/10^2);
		IFFT/Dest=Temp3 Temp2
		//Wave Temp3
		VolData[][][N] = Temp3[p][q]
	EndFor
	VoLData = (VolData[p][q][r] < 0 ) ? 0 : VolData[p][q][r]

	variable count=0, progress
	wave w = VolData4D
	
	if(waveexists(w))
		if(redim == 1)
			redimension/N=(xsize,-1,-1,-1) w
		endif
		
		for(i=0;i<dimsize(w,3);i+=1)
		//print(i)
		progress = i*100/dimsize(w,3)
		if(abs(progress - 10*count) < 5)
			print("4D grid removal: "+num2str(progress) + "% is done")
			count+=1
		endif
		
		for(j=0;j<dimsize(w,2);j+=1)
	
		Temp[][] = w[p][q][j][i]
		//Temp[178,323] = 0
		
		FFT/OUT=1/Dest=Temp2 Temp;
		//Wave Temp2
		Temp2 *= FilterFunc
		//Temp2 *= 1 - exp(-(p-6)^2/10^2 - (q-141)^2/15^2)- exp(-(p-39)^2/10^2 - (q-258)^2/20^2)- exp(-(p-34)^2/10^2 - (q-362)^2/10^2)- exp(-(p-43)^2/10^2 - (q-153)^2/10^2)- exp(-(p-78)^2/10^2 - (q-269)^2/10^2) - exp(-(p-10)^2/10^2 - (q-34)^2/10^2);
		IFFT/Dest=Temp3 Temp2
		//Wave Temp3
		w[][][j][i] = Temp3[p][q]
		EndFor
		
		Endfor
		
		multithread w = (w[p][q][r][s] < 0 ) ? 0 : w[p][q][r][s]
		print("4D grid removal: "+"complete")
	endif
	
	// If the array was redimensionned for the FFT, reduce it back to its original size
	if( Redim==1)
		VolDims[0] -=1;xsize-=1
		ReDimension/N=(xsize,-1,-1) VolData
		ReDimension/N=(xsize,-1) ImT
		ReDimension/N=(xsize,-1) ImBL
		ReDimension/N=(xsize) GrT
		ReDimension/N=(xsize+1) AngleAxis
		if(waveexists(w))
		ReDimension/N=(xsize,-1,-1,-1) VolData4D
		endif
	EndIf
	
End


Function XS_GaussFunc2D(xval,yval,x0,sx,y0,sy)
	Variable xval,yval,x0,sx,y0,sy
	return exp(-(xval-x0)^2/sx^2 - (yval-y0)^2/sy^2)
End



Function XS_FixLensDataSet()
	SVAR gprefix
	String gprefix_new = gprefix+"_L"
	
	XS_FixLens("LoadedData")
	
	DuplicateDataFolder $("root:XS_"+gprefix), $("root:XS_"+gprefix_new)
	SetDataFolder $("root:XS_"+gprefix_new)
	
	SVAR gprefix
	gprefix = gprefix+"_L"		
	Wave VolData, LensFunction,VolDims
	
	Variable N
	For(N=0;N<VolDims[2];N+=1)
		VolData[][][N] = VolData[p][q][N] / LensFunction[p][q]
	EndFor

End

Function XS_FixLens(waveNameStr)
       String waveNameStr

       Wave WaveToFix = $(WaveNameStr)

       Duplicate/O WaveToFix, LensFunction
       LensFunction = 1

       Variable StartX, EndX
       Variable StartY, EndY

       StartX = Str2Num(StringByKey("CCDFirstXChannel",note(WaveToFix),"=","\r"))
       EndX = Str2Num(StringByKey("CCDLastXChannel",note(WaveToFix),"=","\r"))
       StartY = Str2Num(StringByKey("CCDFirstYChannel",note(WaveToFix),"=","\r"))
       EndY = Str2Num(StringByKey("CCDLastYChannel",note(WaveToFix),"=","\r"))

       SetScale/I x,StartY,EndY,LensFunction
       SetScale/I y,StartX,EndX,LensFunction

       Make/O/N=7 W_Coef
       W_coef = {17.0267,50.0598,491.653,294.405,796.857,240.563,-0.0211022}
       LensFunction = W_coef[0]+W_coef[1]*exp((-1/(2*(1-W_coef[6]^2)))*(((x-W_coef[2])/W_coef[3])^2 + ((y-W_coef[4])/W_coef[5])^2 - (2*W_coef[6]*((y-W_coef[4])*(x-W_coef[2]))/(W_coef[3]*W_coef[5]))))

       WaveToFix = WaveToFix[p][q] / LensFunction[p][q]

       //Duplicate/O WaveToFix, output
End

Function XS_update_browser()
	SetDataFolder root:
	NewDataFolder/O root:XS_Globals
	
	String objName
	Variable index = 0

	Variable NumXSs = 0
	DFREF dfr = GetDataFolderDFR()
	do
		objName = GetIndexedObjNameDFR(dfr, 4, index)
		if (strlen(objName) == 0)
			break
		endif
		
		if( strsearch(objName,"XS_",0,1)==0 )
			NumXSs +=1
		EndIf
		
		index +=1
	while(1)
	
	NumXSs -=1 //Ignore XS_globals
	
	if(WaveExists($("root:XS_Globals:windowParams"))==0)
		Make/O/N=9 root:XS_Globals:windowParams = {0,0,1,1,1,1,1,1,0}
	EndIf
	
	Make/O/T/N=(NumXSs) root:XS_Globals:XS_names
	Make/O/N=(NumXSs) root:XS_Globals:XS_names_sel
	Wave/T NamesWave = root:XS_Globals:XS_names
	
	index=0
	NumXSs = 0
	do
		objName = GetIndexedObjNameDFR(dfr, 4, index)
		if (strlen(objName) == 0)
			break
		endif
		
		if( strsearch(objName,"XS_",0,1)==0 )
			if(cmpstr(objName,"XS_Globals")!=0)
				NamesWave[numXSs] = objName[3,32]
				numXSs+=1
			endif
		EndIf
		
		index +=1
	while(1)
	
End


Function XS_Browser_update_button_proc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			XS_update_browser()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Window XS_browser_panel() : Panel
	DoWindow/K XSBrowser
	
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(5,5,275,356)/k=1/N=XSBrowser as "XSection Browser"
	ModifyPanel fixedSize=1

	SetDrawLayer UserBack
	DrawText 10,26,"Loaded data sets:"
	ListBox XS_list,pos={10,29},size={170,285},listWave=root:XS_Globals:XS_names
	ListBox XS_list,selWave=root:XS_Globals:XS_names_sel,mode= 4,fSize=10
	Button XS_Browser_Update_button,pos={11,318},size={170,23},proc=XS_Browser_update_button_proc,title="Update list",fSize=10
	
	Button XS_browser_display_button,pos={192,28},size={68,23},proc=XS_Browser_display_button_proc,title="Display",fSize=10
	Button XS_browser_hide_button,pos={192,56},size={68,23},proc=XS_Browser_hide_button_proc,title="Hide",fSize=10
	
	Button XS_browser_delete_button,pos={192,106},size={68,23},proc=XS_browser_delete_button,title="Delete",fSize=10
	Button XS_browser_copy_button,pos={192,134},size={68,23},proc=XS_browser_copy_button_proc,title="Copy",fSize=10
	Button XS_browser_rename_button,pos={192,162},size={68,23},proc=XS_Browser_rename_button,title="Rename",fSize=10
	
	Button XS_browser_grid_button,pos={192,212},size={68,23},proc=XS_browser_grid_button_proc,title="Remove grid",fSize=10
	Button XS_browser_scale_button,pos={192,240},size={68,23},proc=XS_Browser_scale_buttonProc,title="Scale axes",fSize=10
	
	//Button XS_browser_lens_button,pos={190,232},size={68,23},proc=XS_button_lens_button_proc,title="Fix lens"

	Button XS_browser_copysettings_button,pos={192,290},size={68,23},proc=XS_browser_copysettings_button,title="Copy config",fSize=10
	Button XS_browser_pastesettings_button,pos={192,318},size={68,23},proc=XS_browser_pastesettings_button,title="Paste config",fSize=10
	
EndMacro

Function XS_Browser_display_button_proc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Variable index = 0
			Wave/T names = root:XS_Globals:XS_names
			Wave names_sel = root:XS_globals:XS_names_sel
			Variable num_names = DimSize(names,0)
			
			For(index = 0; index<num_names;index+=1)
				If(names_sel[index]==1)
					String DirName = "root:XS_" + names[index]
					SetDataFolder $(DirName)
					SVAR gprefix
					XSection(gprefix); //DoUpdate
					UpdateXSWindow(gprefix)
				EndIf
			EndFor			
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function XS_Browser_hide_button_proc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Variable index = 0
			Wave/T names = root:XS_Globals:XS_names
			Wave names_sel = root:XS_globals:XS_names_sel
			Variable num_names = DimSize(names,0)
			
			For(index = 0; index<num_names;index+=1)
				If(names_sel[index]==1)
					DoWindow/K $("Win"+names[index])
				EndIf
			EndFor			
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function XS_browser_delete_button(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			
			Variable index = 0
			Duplicate/O root:XS_Globals:XS_names, root:XS_Globals:XS_names_tmp
			Duplicate/O root:XS_globals:XS_names_sel, root:XS_globals:XS_names_sel_tmp
			Wave/T names = root:XS_Globals:XS_names_tmp
			Wave names_sel = root:XS_globals:XS_names_sel_tmp
			Variable num_names = DimSize(names,0)
			
			For(index = 0; index<num_names;index+=1)
				If(names_sel[index]==1)
					String HelpStr = "Click Continue to Delete, or Cancel if you changed your mind."
					String x=names[index]	
					Prompt x, "Are you sure you want to delete this data set?"
					DoPrompt/Help=HelpStr "Confirm Delete", x
					if (V_Flag==0)
						String DirName = "root:XS_" + names[index]
						SetDataFolder $(DirName)
						DoWindow/K $("Win"+names[index])	
						KillDataFolder DirName			
					endif
				EndIf
				XS_update_browser()
			EndFor			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function XS_browser_grid_button_proc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Variable index = 0
			Duplicate/O root:XS_Globals:XS_names, root:XS_Globals:XS_names_tmp
			Duplicate/O root:XS_globals:XS_names_sel, root:XS_globals:XS_names_sel_tmp
			Wave/T names = root:XS_Globals:XS_names_tmp
			Wave names_sel = root:XS_globals:XS_names_sel_tmp
			Variable num_names = DimSize(names,0)
			
			For(index = 0; index<num_names;index+=1)
				If(names_sel[index]==1)
					String DirName = "root:XS_" + names[index]
					SetDataFolder $(DirName)
					XS_AutoFFT()
				EndIf
			EndFor	
			XS_update_browser()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function XS_button_lens_button_proc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Variable index = 0
			Duplicate/O root:XS_Globals:XS_names, root:XS_Globals:XS_names_tmp
			Duplicate/O root:XS_globals:XS_names_sel, root:XS_globals:XS_names_sel_tmp
			Wave/T names = root:XS_Globals:XS_names_tmp
			Wave names_sel = root:XS_globals:XS_names_sel_tmp
			Variable num_names = DimSize(names,0)
			
			For(index = 0; index<num_names;index+=1)
				If(names_sel[index]==1)
					String DirName = "root:XS_" + names[index]
					SetDataFolder $(DirName)
					XS_FixLensDataSet()
				EndIf
			EndFor	
			XS_update_browser()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function XS_browser_copy_button_proc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Variable index = 0
			Duplicate/O root:XS_Globals:XS_names, root:XS_Globals:XS_names_tmp
			Duplicate/O root:XS_globals:XS_names_sel, root:XS_globals:XS_names_sel_tmp
			Wave/T names = root:XS_Globals:XS_names_tmp
			Wave names_sel = root:XS_globals:XS_names_sel_tmp

			Variable num_names = DimSize(names,0)
			SetDataFolder root:
			For(index = 0; index<num_names;index+=1)
				If(names_sel[index]==1)
					String DirName = "root:XS_" + names[index]
					
						if(DataFolderExists(DirName+"_C"))
							String alertStr = "Sorry, you already have a data set with the name "
							alertStr += names[index]+"_C. Please rename or delete it if you want to proceed. \n\n"
							alertStr += "Operation aborted."
							DoAlert/T="Error" 0, alertstr
							return -1
						EndIf
						
					DuplicateDataFolder $DirName, $(DirName+"_C")
					SVAR prefix = $(DirName+"_C:gprefix")
					String newPrefix = prefix + "_C"
					prefix = newPrefix
				EndIf
			EndFor	
			XS_update_browser()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function XS_Browser_rename_button(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
		
			Duplicate/O root:XS_Globals:XS_names, root:XS_Globals:XS_names_tmp
			Duplicate/O root:XS_globals:XS_names_sel, root:XS_globals:XS_names_sel_tmp
			Wave/T names = root:XS_Globals:XS_names_tmp
			Wave names_sel = root:XS_globals:XS_names_sel_tmp
			
			Variable index = 0

			Variable num_names = DimSize(names,0)
			SetDataFolder root:
			For(index = 0; index<num_names;index+=1)
				If(names_sel[index]==1)
				
					String HelpStr = "Click Continue to Rename, or Cancel if you changed your mind."
					String newName=names[index]+"_new"
					Prompt newName, ("Enter new name for " + names[index])
					DoPrompt/Help=HelpStr "Rename", newName
					if (V_Flag==0)
			
						String DirName = "root:XS_" + names[index]
						
						DuplicateDataFolder $DirName, $("root:XS_"+newName)
						SVAR prefix = $("root:XS_"+newName+":gprefix")

						prefix = newName

						DoWindow/K $("Win"+names[index])	
						KillDataFolder DirName	
					endif
				EndIf
			EndFor	
			XS_update_browser()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End



Function XS_browser_copysettings_button(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Variable index = 0
			Wave/T names = root:XS_Globals:XS_names
			Wave names_sel = root:XS_globals:XS_names_sel
			Variable num_names = DimSize(names,0)
			For(index = 0; index<num_names;index+=1)
				If(names_sel[index]==1)
					Break
				EndIf
			EndFor
			
			String DirName = "root:XS_" + names[index]
			SetDataFolder DirName
			
				if(WaveExists($("root:XS_Globals:windowParams"))==0)
					Make/O/N=9 root:XS_Globals:windowParams = {0,0,1,1,1,1,1,1,0}
				EndIf
				
				
				Wave settings = root:XS_Globals:WindowParams
				NVAR cutx,cuty,intx,inty,whichgraphtoplot,showint,graphonnewaxis,duplicategraph,cutZ
				settings = {cutx,cuty,intx,inty,whichgraphtoplot,showint,graphonnewaxis,duplicategraph,cutZ}
		
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function XS_browser_pastesettings_button(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Variable index = 0
			Wave/T names = root:XS_Globals:XS_names
			Wave names_sel = root:XS_globals:XS_names_sel
			Variable num_names = DimSize(names,0)
			
			Wave settings = root:XS_Globals:WindowParams
			
			For(index = 0; index<num_names;index+=1)
				If(names_sel[index]==1)
					String DirName = "root:XS_" + names[index]
					SetDataFolder DirName
					NVAR cutx,cuty,intx,inty,whichgraphtoplot,showint,graphonnewaxis,duplicategraph,cutZ
					cutx = settings[0]
					cuty = settings[1]
					intx = settings[2]
					inty = settings[3]
					whichgraphtoplot = settings[4]
					showint = settings[5]
					graphonnewaxis = settings[6]
					duplicategraph = settings[7]
					cutz = settings[8]
					SVAR gprefix
					
					if(strlen(WinList("Win"+gprefix, ";", "WIN:1"))>0)
						updateXSWindow(gprefix)
					endif
				EndIf
			EndFor	

			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function Fix_BackAndForth(sToFix)
	String sToFix
	
	Wave VolDims
	Variable NumDelays = VolDims[2]
	
	Wave toFix = $(sToFix)
	Duplicate/O toFix, WhichWay, $(sToFix+"_corr")
	Wave toFix_corr = $(sToFix+"_corr")
	
	Variable N, vScanNo
	For(N=0; N<dimSize(countrate,0); N+=1)
		vScanNo = floor( (N)/NumDelays)
		whichway[N] = (mod(vScanNo,2)==1)
		if (mod(vScanNo,2)==1 )
			
			toFix_corr[N] = toFix[(1+2*vScanNo)*NumDelays-1-N]
		EndIf
	EndFor
End


Function XS_AutoFitTS()
	NVAR CutY, IntY
	SVAR gprefix
	Wave VolDims, GrR_Y
	
	Variable initialY = CutY
	
	Variable yStart = CutY
	Variable yEnd = VolDims[1]
	Variable numSteps = floor((yEnd-yStart)/IntY) + 1
	 
	 Make/O/N=(numSteps) TS_Tau
	 SetScale/P x,GrR_Y[yStart],(IntY*(GrR_Y[1] - GrR_Y[0])), TS_tau
	 TS_Tau = NaN
	 Duplicate/O TS_Tau, TS_Mag,TS_t0,TS_FWHM,TS_Back
	 Duplicate/O TS_Tau, TS_Tau_Err, TS_Mag_Err, TS_FWHM_Err, TS_Back_err,TS_t0_err
	 
	Variable vY
	for(vY = yStart; vY <= yEnd; vY+=IntY)
		CutY = vY; UpdateXSWindow(gprefix)
		XS_FitGaussTimeShape(0); Wave w_coef, w_sigma
		Variable ind = (vY-yStart)/IntY
		TS_Mag[ind] = w_coef[0]
		TS_FWHM[ind] = 1.6651*w_coef[1]
		TS_Tau[ind] = w_coef[2]
		TS_t0[ind] = w_coef[3]
		TS_back[ind] = w_coef[4]
		TS_Mag_err[ind] = w_sigma[0]
		TS_FWHM_err[ind] = 1.6651*w_sigma[1]
		TS_Tau_err[ind] = w_sigma[2]
		TS_t0_err[ind] = w_sigma[3]
		TS_back_err[ind] = w_sigma[4]
	endfor
	TS_Graph()
	CutY = initialY;
	UpdateXSWindow(gprefix)
End

Function TS_Graph() : Graph
	SVAR gprefix
	String winStr = "TDC_Fits_"+gprefix
	
	DoWindow/K $(winStr)
	
	Wave TS_Mag, TS_t0, TS_Tau, TS_FWHM
	Display /N=$(winStr)/W=(35.25,43.25,595.5,417.5)/L=L1/B=B1 TS_Mag
	AppendToGraph/L=L2/B=B2 TS_t0
	AppendToGraph/L=L3/B=B3 TS_Tau
	AppendToGraph/L=L4/B=B4 TS_FWHM

	ModifyGraph rgb(TS_t0)=(0,52224,0),rgb(TS_Tau)=(0,0,0),rgb(TS_FWHM)=(0,0,65280)
	ModifyGraph lblPosMode(L1)=3,lblPosMode(L3)=1,lblPosMode(L4)=1
	ModifyGraph lblPos(L1)=35
	ModifyGraph freePos(L1)={0,B1}
	ModifyGraph freePos(B1)={0,L1}
	ModifyGraph freePos(L2)={0,B2}
	ModifyGraph freePos(B2)=0
	ModifyGraph freePos(L3)={0,B3}
	ModifyGraph freePos(B3)={0,L3}
	ModifyGraph freePos(L4)={0,B4}
	ModifyGraph freePos(B4)={0,L4}
	ModifyGraph axisEnab(L1)={0.55,1}
	ModifyGraph axisEnab(B1)={0.55,1}
	ModifyGraph axisEnab(L2)={0,0.45}
	ModifyGraph axisEnab(B2)={0.55,1}
	ModifyGraph axisEnab(L3)={0.55,1}
	ModifyGraph axisEnab(B3)={0,0.45}
	ModifyGraph axisEnab(L4)={0,0.45}
	ModifyGraph axisEnab(B4)={0,0.45}
	Legend/X=0.00/Y=0.00/C/N=text0/J "\\s(TS_Tau) Tau\r\\s(TS_Mag) Mag\r\\s(TS_FWHM) FWHM\r\\s(TS_t0) t0"
	ModifyGraph mode=4,marker=19,msize=1.5
EndMacro

Function XS_AutoFitButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			 XS_AutoFitTS()
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End


Function XS_Rescale_Delays(shift,scale)
	Variable shift, scale
	
	Wave Delays, DelayAxis
	If(exists("Delays_Original")==0)
		Duplicate/O Delays, Delays_Original
	EndIf

	Delays += Shift
	Delayaxis += Shift
	
	Delays *= scale
	DelayAxis *= scale
End

Function XS_Rescale_Energies(shift)
	Variable shift
	
	Wave GrR_Y, EnergyAxis, ImBL, ImR
	
	If(exists("GrR_Y_Original")==0)
		Duplicate/O GrR_Y, GrR_Y_Original
	EndIf
	Variable original = DimOffset(ImBL,1)
	GrR_Y += Shift
	EnergyAxis += Shift
	SetScale/P y,(original+Shift),DimDelta(ImBL,1), ImBL
	SetScale/P y,(original+Shift),DimDelta(ImR,1), ImR
	Duplicate/O ImBL, LoadedData
End

Function XS_Rescale_Angles(shift)
	Variable shift
	
	Wave AngleAxis, ImBL, ImT, GrT
	If(exists("AngleAxis_Original")==0)
		Duplicate/O AngleAxis, AngleAxis_Original
	EndIf
	Variable original = DimOffset(ImBL,0)
	AngleAxis += Shift
	SetScale/P x,(original+Shift),DimDelta(ImBL,0), ImBL, GrT, ImT
	Duplicate/O ImBL, LoadedData
End

Function XS_Rescale_All(DelayShift,DelayScale,EnergyShift,AngleShift,kConv_E_offset,do_k_conv)
	Variable DelayShift,DelayScale,EnergyShift,AngleShift,kConv_E_offset,do_k_conv
	
	SVAR gprefix
	
	SetDataFolder $("root:XS_"+gprefix)
	Wave originalVoldata = VolData
	string originalDF = "root:XS_"+gprefix
	Nvar collapsed
	
	if(DataFolderExists("root:XS_"+gprefix+"_S"))
		String alertStr = "Sorry, you already have a scaled data set with the name "
		alertStr += gprefix+"_S. Please rename or delete it if you want to proceed. \n\n"
		alertStr += "Operation aborted."
		DoAlert/T="Error" 0, alertstr
		return -1
	EndIf
		
	DuplicateDataFolder $("root:XS_"+gprefix), $("root:XS_"+gprefix+"_S")
	SetDataFolder $("root:XS_"+gprefix+"_S")
	Wave VolData, ImBL,VolDims
	SVAR gprefix
	gprefix = gprefix+"_S"
	
	XS_Rescale_Delays(DelayShift,DelayScale)
	XS_Rescale_Energies(EnergyShift)
	XS_Rescale_Angles(AngleShift)
	
	if(do_k_conv)
	
		// Define boundaries
		Variable Angle_min = DimOffset(ImBL,0)
		Variable Angle_max = DimOffset(ImBL,0) + (DimSize(ImBL,0)-1) * DimDelta(ImBL,0)
		Variable Energy_min = DimOffset(ImBL,1)
		Variable Energy_max = DimOffset(ImBL,1) + (DimSize(ImBL,1)-1) * DimDelta(ImBL,1)
		// The minimum and maximum k are determined at the highest energy
		Variable k_min = 0.5123 * sqrt(Energy_max - kConv_E_offset) * sin(Angle_min*pi/180)
		Variable k_max = 0.5123 * sqrt(Energy_max - kConv_E_offset) * sin(Angle_max*pi/180)
		// Determine the number of k-points to have in the new image
		Variable dk_bottom =  0.5123 * sqrt(Energy_min - kConv_E_offset) * DimDelta(imBL,0) * pi/180
		Variable numK = round(abs ((k_max-k_min) / (dk_bottom)) + 1)
		
		Make/O/N=(numK)  k_wave
		SetScale/I x,k_min, k_max, k_wave
		k_wave = x
		Make/O/N=(DimSize(ImBL,0)) angle_wave
		SetScale/P x,DimOffset(ImBL,0),DimDelta(ImBL,0), angle_wave
		angle_wave = x
		Make/O/N=(DimSize(ImBL,1)) e_wave
		SetScale/P x,DimOffset(ImBL,1) - kConv_E_offset,DimDelta(ImBL,1), e_wave
		e_wave = x
		
		//make the 2D wave for the conversion from k value to point value for old Voldata so we can perform multithread process.
		Make/N=(Dimsize(k_wave,0), Dimsize(e_wave,0)) KtoPointMatrix
		variable i,j
		for(i=0;i<dimsize(k_wave,0);i+=1)
			for(j=0;j<dimsize(e_wave,0);j+=1)
				variable angle = asin(k_wave[i]/0.5123/sqrt(e_wave[j])) * 180/pi
				if(angle <= angle_min || angle >= angle_max)
					KtoPointMatrix[i][j] = nan
				else
					KtoPointMatrix[i][j] = (angle - angle_min)*(Dimsize(angle_wave,0)-1)/(angle_max - angle_min)
				endif
			endfor
		endfor
		
		variable xsize,ysize,zsize,tsize
		ysize = dimsize(VolData,1);zsize = dimsize(VolData,2);tsize = dimsize(VolData,3)
		VolDims[0] = numK;xsize = numk
		
		Make/O/N=(xsize,ysize,zsize) VolData
		Make/O/N=(xsize,ysize) ImBL, LoadedData
		Make/O/N=(xsize,ysize) ImT
		Make/O/N=(xsize) GrT
		SetScale/P x,DimOffset(k_wave,0),DimDelta(k_wave,0), ImBL, LoadedData, ImT, GrT
		SetScale/P y,DimOffset(e_wave,0),DimDelta(e_wave,0), ImBL, LoadedData
		Make/O/N=(xsize+1) AngleAxis
		AngleAxis =  DimOffset(k_wave,0) + (p-.5)*DimDelta(k_wave,0)
		VolData = NaN

		multithread volData[][][] = numType(KtoPointMatrix[p][q]) == 2 ? nan : (ceil(KtoPointMatrix[p][q]) - KtoPointMatrix[p][q])*originalVolData[floor(KtoPointMatrix[p][q])][q][r] + (KtoPointMatrix[p][q]-floor(KtoPointMatrix[p][q]))*originalVolData[ceil(KtoPointMatrix[p][q])][q][r]
		
		///4D angle to k
		if(collapsed == 0)
			//variable t = startMSTimer
			wave originalVolData4D = $(originalDF+":VolData4D")
			
			Make/O/N=(numK,dimsize(originalVolData4D,1),dimsize(originalVolData4D,2),dimsize(originalVolData4D,3)) VolData4D
			VolData4D = nan
			print("4D angle_k_conversion might take a few minutes if your data are big in size")
			multithread volData4D[][][][] = numType(KtoPointMatrix[p][q]) == 2 ? nan : (ceil(KtoPointMatrix[p][q]) - KtoPointMatrix[p][q])*originalVolData4D[floor(KtoPointMatrix[p][q])][q][r][s] + (KtoPointMatrix[p][q]-floor(KtoPointMatrix[p][q]))*originalVolData4D[ceil(KtoPointMatrix[p][q])][q][r][s]
			
			//XS_Angle_to_k_4D(wTmp,originalVolData4D,kConv_E_Offset)
			//print("It took " + num2str(stopMStimer(t)/1000000)) + " s for 4D angle_to_k conversion"
		endif
		
	Endif
End



Function Proc_EnergyShift_Modified(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
			NVAR gEnergyShift = root:XS_Globals:gEnergyShift
			NVAR gkOffset = root:XS_Globals:gkOffset
			gkOffset = gEnergyShift
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function Proc_kconv_checked(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function Proc_ScaleAxes(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			KillWindow PanelAxisScaler
			NVAR gDelayShift = root:XS_Globals:gDelayShift
			NVAR gDelayScale = root:XS_Globals:gDelayScale
			NVAR gEnergyShift = root:XS_Globals:gEnergyShift
			NVAR gAngleShift = root:XS_Globals:gAngleShift
			NVAR gDoKConv = root:XS_Globals:gDoKConv
			NVAR gkOffset = root:XS_Globals:gkOffset
		
			Variable index = 0
			Duplicate/O root:XS_Globals:XS_names, root:XS_Globals:XS_names_tmp
			Duplicate/O root:XS_globals:XS_names_sel, root:XS_globals:XS_names_sel_tmp
			Wave/T names = root:XS_Globals:XS_names_tmp
			Wave names_sel = root:XS_globals:XS_names_sel_tmp
			Variable num_names = DimSize(names,0)
			
			For(index = 0; index<num_names;index+=1)
				If(names_sel[index]==1)
					String DirName = "root:XS_" + names[index]
					SetDataFolder $(DirName)
					SVAR gprefix
					if(XS_Rescale_All(gDelayShift,gDelayScale,gEnergyShift,gAngleShift,gkOffset,gDoKConv)==-1)
						return -1
					endif
					Print "========== Scaling axes =========="
					Print "Data set: " + gprefix
					Print "Delay shift: " + num2str(gDelayShift)
					Print "Delay scale: " + num2str(gDelayScale)
					Print "Energy shift: " + num2str(gEnergyShift)
					Print "Angle shift: " + num2str(gAngleShift)
					if(gDoKConv==1)
						print "Converted to k-space with energy offset: " +num2str(gkOffset)
					Else
						print "Not converted to k-space"
					EndIf
					Print "=============================="
				EndIf
				XS_update_browser()
			EndFor	
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function AxisScaler() 
	DoWindow/K PanelAxisScaler
	NVAR gDelayShift = root:XS_Globals:gDelayShift
	NVAR gDelayScale = root:XS_Globals:gDelayScale
	NVAR gEnergyShift = root:XS_Globals:gEnergyShift
	NVAR gAngleShift = root:XS_Globals:gAngleShift
	NVAR gDoKConv = root:XS_Globals:gDoKConv
	NVAR gkOffset = root:XS_Globals:gkOffset
		
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(24,430,230,667)/N=PanelAxisScaler/k=1 as "Axis Scaler"
	ModifyPanel fixedSize=1
	SetVariable SV_Delayshift,pos={32,23},size={141,16},bodyWidth=85,title="Delay shift:"
	SetVariable SV_Delayshift,limits={-inf,inf,0},value= root:XS_Globals:gDelayShift
	SetVariable SV_Delayscale,pos={26,43},size={147,16},bodyWidth=85,title="Delay scale:"
	SetVariable SV_Delayscale,limits={-inf,inf,0},value= root:XS_Globals:gDelayScale
	SetVariable SV_EnergyShift,pos={26,65},size={147,16},bodyWidth=85,proc=Proc_EnergyShift_Modified,title="Energy shift:"
	SetVariable SV_EnergyShift,limits={-inf,inf,0},value= root:XS_Globals:gEnergyShift
	SetVariable SV_AngleShift,pos={31,86},size={141,16},bodyWidth=85,title="Angle shift:"
	SetVariable SV_AngleShift,limits={-inf,inf,0},value= root:XS_Globals:gAngleShift
	GroupBox group0,pos={6,3},size={194,108},title="Axis shift parameters"
	GroupBox group1,pos={5,119},size={195,79},title="k conversion"
	CheckBox Check_DoKConv,pos={43,142},size={96,14},proc=Proc_kconv_checked,title="Do k-conversion"
	CheckBox Check_DoKConv,variable= root:XS_Globals:gDoKConv
	SetVariable SV_kConv_energyOffset,pos={16,165},size={154,16},bodyWidth=85,title="Energy offset:"
	SetVariable SV_kConv_energyOffset,limits={-inf,inf,0},value= root:XS_Globals:gkOffset
	Button Button_ScaleAxes,pos={30,211},size={71,20},proc=Proc_ScaleAxes,title="Do it!"
	Button Button_Help,pos={110,211},size={71,20},proc=ButtonProc_ScalerHelp,title="Help!"
End


Function XS_Browser_scale_buttonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			SetDataFolder root:XS_Globals
			Variable/G gDelayShift = 0
			Variable/G gDelayScale = 1
			Variable/G gEnergyShift = 0
			Variable/G gAngleShift = 0
			Variable/G gDoKConv = 0
			Variable/G gkOffset = 0
			AxisScaler() 
			
			XS_update_browser()
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function ButtonProc_ScalerHelp(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Print "==============="
			Print "AXIS SCALER HELP"
			Print "==============="
			Print ""
			Print "AFFECTED DATA SETS"
			Print "  The axis operations will be applied to all data sets selected in the XSection Browser. This"
			Print "  means that multiple "
			
			Print "ORDER OF OPERATIONS"
			Print "  The axis operations are performed in the sequence displayed on the panel. For example,"
			Print "  the delay scaling occurs *after* shifting the delay axis. Moreover, the k-conversion occurs"
			Print "  after all axis shifting/scaling is complete."
			
			Print "SIGN OF SHIFT"
			Print "  The value entered for each shift is added to the corresponding axis. For example, if your"
			Print "  spectrum is centered at 3 degrees, you should enter -3 for the angle shift."
			
			Print "ENERGY OFFSET FOR K-CONVERSION"
			Print "  Enter the value on your y-axis that corresponds to zero kinetic energy. For the raw data"
			Print "  from Scienta, this is 0. Be careful: things get trickier if you shift your energy axis. In"
			Print "  general, if you shift the energy axis by xxx eV, then you should also apply an offset of"
			Print "  xxx eV. It's very important to keep track of this if you shift the energy axis multiple times!"
			
			DoAlert/T="Axis Scaler Help" 0, "Some help topics have been written to the command window (Shortcut: Ctrl+J)" 
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function EquallySpaced(w)
	wave w
	variable i
	
	variable delta = w[1]-w[0]
	
	for(i=0;i<dimsize(w,0);i+=1)
	
		if(abs((w[i+1] - w[i])/delta  - 1) >  0.01 )
			return 0
		endif
		
	endfor

	return 1
End

//added to remove dead pixels
function XS_deadPixelRemover(option)
	
	variable option
	
	print("XS_deadPixelRemover")

	Nvar cutX, intX, cutY, intY
	variable startX, endX, startY, endY
	Svar gprefix
	
	wave imBL, volData, volData4D
	
	if(mod(intX,2)==0)
		startX = cutX - (intX/2)
		endX = cutX + (intX/2) + 1
	else
		startX = cutX - (intX+1)/2
		endX = cutX + (intX+1)/2
	endif
	
	if(mod(intY,2)==0)
		startY = cutY - (intY/2)
		endY = cutY + (intY/2) + 1
	else
		startY = cutY - (intY+1)/2
		endY = cutY + (intY+1)/2
	endif
	
	variable i,j,k,l
	
	if(option == 0)
		for(i=startX+1;i<endX;i+=1)
			for(j=startY+1;j<endY;j+=1)
				imBL[i][j] = XS_AvgInterpolate(ImBL, startX, endX, startY, endY, i, j)
			endfor
		endfor
		return nan
	endif
	
	//print("(startX,endX) = (" + num2str(startX) + ", " + num2str(endX) + ")")
	//print("(startY,endY) = (" + num2str(startY) + ", " + num2str(endY) + ")")
	
	duplicate/O imBL, tmp
	for(k=0;k<dimsize(volData,2);k+=1)
		tmp = volData[p][q][k]
		for(i=startX+1;i<endX;i+=1)
			for(j=startY+1;j<endY;j+=1)
				volData[i][j][k] = XS_AvgInterpolate(tmp, startX, endX, startY, endY, i, j)
			endfor
		endfor
	endfor
	
	if(waveexists(VolData4D))
		variable progress, count=0
	
		for(l=0;l<dimsize(volData4D,3);l+=1)
			progress = l *100/dimsize(volData4D,3) 
			if(abs(progress - 20*count) < 5)
				print("4D Dead Pixel Removal: " +num2str(round(progress))+" % done")
				count +=1
			endif
			
			for(k=0;k<dimsize(volData4D,2);k+=1)
				tmp = volData4D[p][q][k][l]
				for(i=startX+1;i<endX;i+=1)
					for(j=startY+1;j<endY;j+=1)
						volData4D[i][j][k][l] = XS_AvgInterpolate(tmp, startX, endX, startY, endY, i, j)
					endfor
				endfor
			endfor
		endfor
		print("4D Dead Pixel Removal: complete")
		makeVolDataFromVoldata4d(gprefix, 0)
	endif
	
	killwaves tmp

end

//take the weighted average of surrounding pixels.Weight is 1/distance.
function XS_AvgInterpolate(imBL,startX, endX, startY, endY, i, j)
	wave imBL
	variable startX, endX, startY, endY, i, j
	variable k, weight, totalweight = 0, result=0
	
	for(k=startY;k<endY+1;k+=1)
		weight = 1/sqrt((i-startX)^2+(j-k)^2)
		result += imBL[startX][k]*weight
		totalWeight += weight
		weight = 1/sqrt((i-endX)^2+(j-k)^2)
		result += imBL[endX][k]*weight
		totalWeight += weight
	endfor
	
	for(k=startX+1;k<endX;k+=1)
		weight = 1/sqrt((i-k)^2+(j-startY)^2)
		result += imBL[k][startY]*weight
		totalWeight += weight
		weight = 1/sqrt((i-k)^2+(j-endY)^2)
		result += imBL[k][endY]*weight
		totalWeight += weight
	endfor

	result /= totalWeight
	
	return result
end