#pragma rtGlobals=1		// Use modern global access method.

#pragma rtGlobals=1		// Use modern global access method.
#include ":User procedures:i_photo2:i_utils", version>=2.00



Function BeforeFileOpenHook(refnum, filename, symPath, type, creator, kind)

	Variable	refnum, kind
	String filename, symPath, type, creator
	
	print("BeforeFileOpenHook(" + num2str(refnum) + "," + filename + "," + symPath + "," +type + "," + creator + "," + num2str(kind) +")")
		
	Variable fileWasLoaded = 0
	String prefix,readLine1
	
	if( stringmatch(filename,"0_*.xs") == 1)
		print filename + " recognized as an XSection file.  If this was not intended, open the file through the Data > Load Waves menu"
		fileWasLoaded = 1
		
		//Create symbolic path
		prefix = filename[2,strsearch(filename,".xs",0)-1]
		PathInfo $(symPath)
		NewPath/O/Q $(prefix+"Path"), S_path
		//KillPath $(symPath)
		
		FReadLine refNum, readLine1
		Close refNum
		
		If (InitXSection(prefix+"Path",prefix,str2num(readLine1))==-1)
			Print "The XSection fileloader has failed."
			return 1
		EndIf
		
		SetDataFolder $("root:XS_"+prefix)
		XSection(prefix)
			
		XS_update_browser()
				
		SetDataFolder $("root:XS_"+prefix)
		UpdateXSData(prefix)			
	elseif( stringmatch(filename,"*.xs") == 1)
		print filename + " recognized as an XSection file.  If this was not intended, open the file through the Data > Load Waves menu"
		fileWasLoaded = 1
		
		//Create symbolic path
		prefix = filename[0,strsearch(filename,".xs",0)-1]
		PathInfo $(symPath)
		S_path += (prefix + ":")
		print S_path
		NewPath/O/Q $(prefix+"Path"), S_path
		//KillPath $(symPath)
		
		FReadLine refNum, readLine1
		Close refNum
		
		If (InitXSection(prefix+"Path",prefix,str2num(readLine1))==-1)
			Print "The XSection fileloader has failed."
			return 1
		EndIf
		
		SetDataFolder $("root:XS_"+prefix)
		XSection(prefix)
		
		XS_update_browser()
				
		SetDataFolder $("root:XS_"+prefix)
		UpdateXSData(prefix)			
	endif
	
	print("end of BeforeFileOpenHook")

	return fileWasLoaded // If we could load the file, don't let Igor open it again...
End

//**Taken from i_photo**
Function fileloader_loadSEStxt_XS(symPath, filename,prefix)			
	String symPath, filename,prefix
	
	//print("fileloader_loadSEStxt_XS(" + symPath + "," + filename + "," + prefix + ")")
	
	String DF = getDataFolder(1)
	String SES_line, DataName, cmd, NickName, w_Name
	String th, ph, al
	Variable refnum, done, line
	Variable index
	Variable NumberOfRegions, Region
	Variable NumberOfBlocks, Block
	Variable e0, e1, divideBy
	
	SetDataFolder root:
	//NewDataFolder/O/S carpets
	//NewDataFolder/O/S rawData
	
	
	// get the number of Regions
	//Modified for XS
	Open/R/Z /P=$symPath refnum filename
	If (V_flag != 0 )
		return -1
	EndIf
	
	
	do
		FReadline refnum, SES_line
		if (stringmatch(SES_line, "Number of Regions=*") )
			NumberOfRegions=NumberByKey("Number of Regions",SES_line,"=","\r")
			break
		endif
	while(line < 12)
	Close refnum
	
	// Load all matrices:
	KillWaves_withBase("MM")
	LoadWave/G/M/Q/O/A=MM /P=$symPath filename
	
	// scaling, saving and header
	index = 0
	Region = 1
	do	
		// for each region: get the header, the number of Blocks, and the "run mode information"
		String notestr = sFunc_SES_header(symPath, filename,Region)
		String dim3info = sFunc_SES_dim3(symPath, filename, Region)
		
		NumberOfBlocks = str2num(StringFromList(0,dim3info))
		
		Variable FirstXchannel = NumberByKey("CCDFirstYChannel",noteStr,"=","\r")
		Variable LastXchannel = NumberByKey("CCDLastYChannel",noteStr,"=","\r")
		Variable FirstYchannel = NumberByKey("CCDFirstXChannel",noteStr,"=","\r")
		Variable LastYchannel = NumberByKey("CCDLastXChannel",noteStr,"=","\r")
		
		Variable channelZero = NumberByKey("CCDXChannelZero",noteStr,"=","\r")
		Variable deg_channel = NumberByKey("CCDDegreePerChannel",noteStr,"=","\r")
		Variable NumberOfSlices =  NumberByKey("NumberOfSlices",noteStr,"=","\r")
		Variable DwellTime = NumberByKey("DwellTime", noteStr, "=","\r")
		Variable NumberOfSweeps = NumberByKey("NumberOfSweeps", noteStr, "=","\r")
		Variable channel_slice = (LastXchannel-firstXchannel+1)/NumberOfSlices	// channels/slice
		Variable x0 = (FirstXchannel+ (channel_slice-1)/2 - channelZero)* deg_channel
		Variable x1 = (LastXchannel- (channel_slice-1)/2 - channelZero)* deg_channel	// assuming firstChannel < lastChannel
	
		Block = 1	
		do
			if (NumberOfRegions > 1 || NumberOfBlocks > 1)
				sprintf NickName, "%s_%02d_%03d", fileName_to_waveName(fileName,"SES"), Region, Block
			else
				NickName = fileName_to_waveName(fileName,"SES")
			endif
		
			WAVE M = $("root:MM"+num2str(index))
			MatrixTranspose M
			Duplicate/R=[1,dimsize(M,0)-1][]/O M M_int		// skip the energy-column
			if (DwellTime >= 33)		// seems to be a file with ms 'Step Time'
				//divideBy = DwellTime * NumberOfSweeps * channel_slice
				divideBy = DwellTime * NumberOfSweeps
			else
				//divideBy = DwellTime * NumberOfSweeps * channel_slice * 1000
				divideBy = DwellTime * NumberOfSweeps
			endif
			
			///////////////////////////
			//divideBy = 1;
			///////////////////////////
			
			M_int /= divideBy	// kcts/s/channel
								// changed to counts/pixel/s, FB 10-05-04
			
			Variable FirstEnergy = round(M[0][0] * 1e4)/1e4
			Variable LastEnergy = round(M[0][dimsize(M,1)-1] * 1e4)/1e4	// single precision loading results in funny rounding...
			SetScale/I x, x0,x1,"deg", M_int
			SetScale/I y, FirstEnergy,LastEnergy,"eV", M_int
			
			// write the angles for manipulator scans in the note
			if (NumberOfBlocks > 1)
				th = StringByKey("T"+num2str(Block), dim3info,"=",";")
				ph = StringByKey("F"+num2str(Block), dim3info,"=",";")
				// doubtful if this works:
				al = StringByKey("A"+num2str(Block), dim3info,"=",";")
				if (strlen(al) == 0) // if no alpha angle is defined, it is likely not ALS and therefore 0:
					al = "0"
				endif
				notestr = ReplaceStringByKey("InitialThetaManipulator", noteStr, th,"=","\r")
				notestr = ReplaceStringByKey("FinalThetaManipulator", noteStr, th,"=","\r")
				notestr = ReplaceStringByKey("InitialAlphaAnalyzer", noteStr, al,"=","\r")
				notestr = ReplaceStringByKey("FinalAlphaAnalyzer", noteStr, al,"=","\r")
				notestr = ReplaceStringByKey("InitialPhiManipulator", noteStr, ph,"=","\r")
				notestr = ReplaceStringByKey("FinalPhiManipulator", noteStr, ph,"=","\r")
			endif
			
			Note M_int, noteStr
			KillWaves/Z M		// 10/02/04 modified killing waves to avoid string-length problem
						
			// linescans added 02-16-04
			if (dimsize(M_int,0) > 1)
//				Duplicate/O M_int $"root:carpets:rawData:"+NickName
				Duplicate/O M_int $"root:XS_"+prefix+":LoadedData"
			else		
				NewDataFolder/o root:linescans
				NewDataFolder/o root:linescans:rawData
				e0 = utils_y0(M_int)
				e1 = utils_y1(M_int)
				Redimension/N=(dimsize(M_int,1)) M_int
				SetScale/I x e0,e1,"", M_int
//				Duplicate/o M_int $("root:linescans:rawData:"+NickName)
				Duplicate/o M_int $("root:XS_"+prefix+":LoadedData")
			endif
	
		Block += 1
		index += 1
		while (Block <= NumberOfBlocks)
		
	Region += 1
	while (Region <= NumberOfRegions)
	
	//KillWaves_withBase("MM*")		// doesn't work for large data-sets
	KillWaves/Z m_int
	KillStrings/Z s_fileName, s_waveNames, s_Path
			
	SetDataFolder $DF
End


// ** Taken from i_photo **
// kill all waves that match a BaseName
Static Function KillWaves_withBase(baseName)
	String baseName
	
	String str0 = Wavelist(baseName,",","")
	String str1 = str0[0,strlen(str0)-2]
	
	if (strlen(str1) > 0)
		execute "KillWaves/Z "+str1
	endif
End

//**From i_photo**
// convert the header for the region, specified by the 'Region_number' to a wave-note string			// FB  05/19/03
Static Function/S sFunc_SES_header(symPath,filename,Region_number)		
	String symPath, filename
	Variable Region_number

	//print("sFunc_SES_header()")

	String SES_line
	String noteStrList=""
	String noteStr
	String slicevalues
	String str0, str1
	
	Variable refnum
	Variable x0,x1, aux0, aux1
	
	// convert the header between [Region N] and [Data N] in a Keyword-Value paired string-list
	Open/R /P=$symPath refnum filename
	do
		FReadline/N=12 refnum, SES_line
		if (stringmatch(SES_line, "[Region "+num2str(Region_number)+"]\r") )
			break
		endif
	while(1)	// scrolls to [Region N]
	
	
	// for the Helm files, we need to cut the 'Region Name' line of the header, the same line for the V-4 files contains the instrument line, which should appear in the note
	FReadline refnum, SES_line		
	if (stringmatch(SES_line, "Region Name=*")==0)
		noteStrList += SES_line
	endif
	
	do
		FReadline/N=128 refnum, SES_line
		if (stringmatch(SES_line, "[Data*") )
			break
		endif
		
		noteStrList += SES_line
	while (1)	// adds the lines up to [Data*
	Close refnum


	// get the dimension 2 values
	String instrument = StringbyKey("Instrument",noteStrList,"=","\r")
	if (stringmatch(instrument,"SES 200-16"))										// BL V-4 files
		sliceValues = StringbyKey("Slice Values (Deg)",noteStrList,"=","\r")
		x0 = str2num(sliceValues[0,22])	// probably not very stable programming...
		x1 = str2num(sliceValues[23,45])
	else
		sliceValues = StringbyKey("Dimension 2 scale",noteStrList,"=","\r")			// HeLM files
		aux0 = strsearch(sliceValues," ",2)
		aux1 = strsearch(sliceValues," ",aux0+2)
		str0 = sliceValues[0,aux0]
		x0 = str2num(str0)
		str1 = sliceValues[aux0+1,aux1]
		x1 = str2num(str1)
	endif
	if (stringmatch(num2str(x0),"Nan") || stringmatch(num2str(x1),"Nan") )		// scale with the slice numbers
		x0 = 0
		x1 = 1
	endif

	
	// get the values from the string-list
	String location = StringbyKey("Location",noteStrList,"=","\r")
	String user = StringbyKey("User",noteStrList,"=","\r")
	String sample = StringbyKey("Sample",noteStrList,"=","\r")
	String comments = StringbyKey("Comments",noteStrList,"=","\r")
	String startDate = StringbyKey("Date",noteStrList,"=","\r")
	String startTime = StringbyKey("Time",noteStrList,"=","\r")
	String detectorChannels = StringbyKey("Detector Channels",noteStrList,"=","\r")
	String regionName = StringbyKey("Region Name",noteStrList,"=","\r")
	String excitationEnergy = StringbyKey("Excitation Energy",noteStrList,"=","\r")
	String aquisitionmode = StringbyKey("Aquisition Mode",noteStrList,"=","\r")
	String lowEnergy = StringbyKey("Low Energy",noteStrList,"=","\r")
	String highEnergy = StringbyKey("High Energy",noteStrList,"=","\r")
	String EnergyStep = StringbyKey("Energy Step",noteStrList,"=","\r")
	String stepTime = StringbyKey("Step Time",noteStrList,"=","\r")
	String firstXchannel = StringbyKey("Detector First X-Channel",noteStrList,"=","\r")
	String lastXchannel = StringbyKey("Detector Last X-Channel",noteStrList,"=","\r")
	String firstYchannel = StringbyKey("Detector First Y-Channel",noteStrList,"=","\r")
	String lastYchannel = StringbyKey("Detector Last Y-Channel",noteStrList,"=","\r")
	String numberofslices = StringbyKey("Number of Slices",noteStrList,"=","\r")
	String Lensmode = StringbyKey("Lens Mode",noteStrList,"=","\r")
	String passEnergy = StringbyKey("Pass Energy",noteStrList,"=","\r")
	String numberofsweeps = StringbyKey("Number of Sweeps",noteStrList,"=","\r")
	String manipulatorZ = StringbyKey("Z",noteStrList,"=","\r")
	String manipulatorX = StringbyKey("X",noteStrList,"=","\r")
	String manipulatorY = StringbyKey("Y",noteStrList,"=","\r")
	String delayfs = StringbyKey("Delay(fs)",noteStrList,"=","\r")
	String delaymm = StringbyKey("DelayStage(mm)",noteStrList,"=","\r")
	
	// manipulator angles: 
	// first search for 'Theta'/'Phi' keywords. If the '[User Interface Information] section is available, overwrite with the 'T'/'F' values.
	// If the [Run Mode Information] section is available, the values will be overwritten again in 'fileloader_loadSEStxt'.
	Variable phi = round(NumberbyKey("Phi",noteStrList,"=","\r") * 1e4) / 1e4
	Variable theta = round(NumberbyKey("Theta",noteStrList,"=","\r") * 1e4) / 1e4
	Variable alpha = round(NumberbyKey("Alpha",noteStrList,"=","\r") * 1e4) / 1e4
	if (stringmatch(notestrList,"*[User Interface Information*"))
		phi = round(NumberbyKey("F",noteStrList,"=","\r") * 1e4) / 1e4
		theta = round(NumberbyKey("T",noteStrList,"=","\r") * 1e4) / 1e4
		alpha = round(NumberbyKey("A",noteStrList,"=","\r") * 1e4) / 1e4
	endif
	if (numtype(alpha) != 0)
		alpha = 0
	endif
	// make the correct note
	noteStr = fileloader_NoteKeyList_XS(1)		// with the scienta keywords
	String NickName = fileName_to_waveName(fileName,"SES")
	noteStr = ReplaceStringByKey("WaveName", noteStr,NickName,"=","\r")
	noteStr = ReplaceStringByKey("RawDataWave", noteStr,"root:carpets:"+NickName,"=","\r")
	noteStr = ReplaceStringByKey("FileName", noteStr,filename,"=","\r")
	noteStr = ReplaceStringByKey("Sample", noteStr,Sample,"=","\r")
	noteStr = ReplaceStringByKey("Comments", noteStr,Comments,"=","\r")
	noteStr = ReplaceStringByKey("StartDate", noteStr,StartDate,"=","\r")
	noteStr = ReplaceStringByKey("StartTime", noteStr,StartTime,"=","\r")
	noteStr = ReplaceStringByKey("Instrument", noteStr,Instrument,"=","\r")
	noteStr = ReplaceStringByKey("MeasurementSoftware", noteStr,"unknown","=","\r")
	noteStr = ReplaceStringByKey("User", noteStr,user,"=","\r")
	
	noteStr = ReplaceStringByKey("ManipulatorType", noteStr,"flip","=","\r")
	noteStr = ReplaceStringByKey("AnalyzerType", noteStr,"2D","=","\r")
	noteStr = ReplaceStringByKey("AnalyzerMode", noteStr,aquisitionmode,"=","\r")
	if (stringmatch(lensmode,"Transmission"))
		noteStr = ReplaceStringByKey("XScanType", noteStr,"ScientaTransmission","=","\r")
	elseif (stringmatch(lensmode,"Angular"))
		noteStr = ReplaceStringByKey("XScanType", noteStr,"ScientaAngular","=","\r")
	else
		noteStr = ReplaceStringByKey("XScanType", noteStr,"unknown","=","\r")
	endif
	
	noteStr = ReplaceStringByKey("FirstEnergy", noteStr,lowEnergy,"=","\r")	// do all Scienta's scan from low to high??
	noteStr = ReplaceStringByKey("LastEnergy", noteStr,highEnergy,"=","\r")
	aux0 = round( abs(str2num(lowEnergy) - str2num(highenergy) ) / str2num(EnergyStep) +1 )
	noteStr = ReplaceStringByKey("NumberOfEnergies", noteStr,num2str(aux0),"=","\r")
	noteStr = ReplaceNumberByKey("InitialThetaManipulator", noteStr,theta,"=","\r")
	noteStr = ReplaceNumberByKey("FinalThetaManipulator", noteStr,theta,"=","\r")
	noteStr = ReplaceStringByKey("OffsetThetaManipulator", noteStr,"0","=","\r")
	noteStr = ReplaceNumberByKey("InitialPhiManipulator", noteStr,Phi,"=","\r")
	noteStr = ReplaceNumberByKey("FinalPhiManipulator", noteStr,Phi,"=","\r")
	noteStr = ReplaceNumberByKey("InitialAlphaManipulator", noteStr,alpha,"=","\r")
	noteStr = ReplaceNumberByKey("FinalAlphaManipulator", noteStr,alpha,"=","\r")
	noteStr = ReplaceStringByKey("OffsetPhiManipulator", noteStr,"0","=","\r")
	noteStr = ReplaceStringByKey("NumberOfManipulatorAngles", noteStr,"1","=","\r")
	// what about the omega? try 0 as a default
	noteStr = ReplaceStringByKey("InitialOmegaManipulator", noteStr,"0","=","\r")
	noteStr = ReplaceStringByKey("FinalOmegaManipulator", noteStr,"0","=","\r")
	noteStr = ReplaceStringByKey("OffsetOmegaManipulator", noteStr,"0","=","\r")
	
	noteStr = ReplaceStringByKey("PhotonEnergy", noteStr, excitationEnergy,"=","\r")
	noteStr = ReplaceStringByKey("PassEnergy", noteStr,passEnergy,"=","\r")
	noteStr = ReplaceStringByKey("DwellTime", noteStr,stepTime,"=","\r")
	noteStr = ReplaceStringByKey("NumberOfSweeps", noteStr,numberofsweeps,"=","\r")
	
	noteStr = ReplaceStringByKey("RegionName", noteStr,regionName,"=","\r")
	// scienta orientation? try 90 as a default
	//noteStr = ReplaceStringByKey("ScientaOrientation", noteStr,"90","=","\r")	// this is too much confusing
	
	noteStr = ReplaceStringByKey("CCDFirstXChannel", noteStr,firstXchannel,"=","\r")
	noteStr = ReplaceStringByKey("CCDLastXChannel", noteStr,lastXchannel,"=","\r")
	noteStr = ReplaceStringByKey("CCDFirstYChannel", noteStr,firstYchannel,"=","\r")
	noteStr = ReplaceStringByKey("CCDLastYChannel", noteStr,lastYchannel,"=","\r")
	noteStr = ReplaceStringByKey("NumberOfSlices", noteStr,numberofslices,"=","\r")
	
	Variable channel_slice = (str2num(lastYchannel)-str2num(firstYchannel)+1)/str2num(NumberOfSlices)
	Variable degChannel = (x1-x0) / channel_slice
	degChannel = round (degChannel * 1e7) / 1e7
	Variable channelZero = str2num(firstYchannel) + x0/(x0-x1) * channel_slice + 1		// check the '+1'!
	channelZero = round(channelZero * 1e4) / 1e4
	//String s1
	//sprintf s1, "%18.16f", degChannel		// num2str is limited to 5 digits!
	//noteStr = ReplaceStringByKey("CCDDegreePerChannel", noteStr,s1,"=","\r")
	noteStr = ReplaceNumberByKey("CCDXChannelZero", noteStr,ChannelZero,"=","\r")
	noteStr = ReplaceNumberByKey("CCDDegreePerChannel", noteStr,degChannel,"=","\r")
	
	notestr = ReplaceStringByKey("MatrixType", noteStr, "carpet","=","\r")
	noteStr = ReplaceStringByKey("AngleMapping", noteStr,"none","=","\r")
	noteStr = ReplaceStringByKey("EnergyScale", noteStr,"kinetic","=","\r")

	noteStr = ReplaceStringByKey("Delay(fs)", noteStr,delayfs,"=","\r")
	noteStr = ReplaceStringByKey("DelayStage(mm)", noteStr,delaymm,"=","\r")
	
	return noteStr
End

//**From i_photo**
// convert the "run mode information" section of the SES-files in a easy to parse string:
// returns stringlist. first item: number of blocks in region, following items: keyword-value packed angles
Static Function/S sFunc_SES_dim3(symPath, filename, Region_number)
	String symPath, filename
	Variable Region_number
	
	//print("sFunc_SES_dim3()")
	
	String key1 = "="
	String key2 = "="
	String key3 = ";"
	Variable p1, p2, p11, p21, step
	Variable refnum
	
	String SES_line, dim3str=""
	
	Open/R /P=$symPath refnum filename
	do
		FReadline/N=128 refnum, SES_line
		
		// e.g. [Data 1:1] at the end of the header lines of Region 1
		if (stringmatch(SES_line, "[Data "+num2str(region_number)+"*") )
			break
		endif
		
		if (stringmatch(SES_line, "Dimension 3 size=*") )	// this block is above the run mode information
			dim3str += StringByKey("Dimension 3 size",SES_line,"=","\r")+";"
		endif
		
		if (stringmatch(SES_line, "[Run Mode Information "+num2str(Region_number)+"]\r") )
			step=1
			do
				FReadline refnum, SES_line
				if (stringmatch(SES_line,"Step*")==0)
					break
				endif
				p1 = StrSearch(SES_line, key1,0)
				p11 = StrSearch(SES_line, key3,p1)
				p2 = StrSearch(SES_line, key2,p11)
				p21 = StrSearch(SES_line, key3,p2)
				
				dim3str += "T"+num2str(step)+"="+SES_line[p1+1,p11-1]+";"
				dim3str += "F"+num2str(step)+"="+SES_line[p2+1, p21-1]+";"
			
				step += 1
			while (1)
		break
		endif
	while(1)
	
	Close refnum
	return dim3str
End

//**From i_photo**
Static Function/s fileName_to_waveName(fileName, convention)	// FB  05/19/03
	String fileName, convention
	
	//print("fileName_to_waveName(" + fileName + "," + convention + ")")
	
	Variable n = strlen(filename)
	//NVAR first_char = root:internalUse:prefs:gv_Nick_firstChar
	//NVAR last_char = root:internalUse:prefs:gv_Nick_lastChar
	
	String NickName
	
	strswitch(convention)
		case "SES":
		case "FITS":
				Variable p_ext = strsearch(fileName,".txt",0)
				//NickName = CleanUpName(fileName[first_char, last_char],0)+"_"+fileName[p_ext-3,p_ext-1]
				NickName = "DefaultName"
			break					
		case "SES_pxt":	
				NickName = CleanUpName(fileName[n-6,n-1],0)
			break
		case "VG1Z":		
				NickName = CleanUpName("VG"+fileName[4, 9]+fileName[11, 13],0)
			break
		case "pref":
				//NickName = CleanUpName(fileName[first_char, last_char],0)
			break
		default:			
				//NickName = CleanUpName(fileName[first_char, last_char],0)	// when no case matches
	endswitch
	
	return NickName
End


//**Taken from i_photo**
// this is the holy hopefully static KeyWord-list for the wave-notes			// FB  05/19/03
//
// Made some changes in i_filetable.ipf. It contains now a keyword list 
// similar to this one. If you change something here, please change 
// also i_filetable.ipf.								// F.Schmitt 04/22/07
//
Function/S fileloader_NoteKeyList_XS(data_type)
	Variable data_type	// 1=SES, 2=MacESCAII, 3=Croissant
	
	//print("fileloader_NoteKeyList_XS(" + num2str(data_type) + ")")
	
	String keylist=""
	keylist+="WaveName=\r"
	keylist+="RawDataWave=\r"
	keylist+="FileName=\r"
	keylist+="Sample=\r"
	keylist+="Comments=\r"
	keylist+="StartDate=\r"
	keylist+="StartTime=\r"
	keylist+="Instrument=\r"
	keylist+="MeasurementSoftware=\r"
	keylist+="User=\r"
	keylist+="\r"
	
	keylist+="ManipulatorType=\r"
	keylist+="AnalyzerType=\r"
	keylist+="AnalyzerMode=\r"
	keylist+="XScanType=\r"
	keylist+="\r"
	
	keylist+="FirstEnergy=\r"
	keylist+="LastEnergy=\r"
	keylist+="NumberOfEnergies=\r"
	keylist+="InitialAlphaAnalyzer=\r"
	keylist+="FinalAlphaAnalyzer=\r"
	keylist+="InitialThetaManipulator=\r"
	keylist+="FinalThetaManipulator=\r"
	keylist+="OffsetThetaManipulator=\r"
	keylist+="InitialPhiManipulator=\r"
	keylist+="FinalPhiManipulator=\r"
	keylist+="OffsetPhiManipulator=\r"
	keylist+="InitialOmegaManipulator=\r"
	keylist+="FinalOmegaManipulator=\r"
	keylist+="OffsetOmegaManipulator=\r"
	keylist+="NumberOfManipulatorAngles=\r"
	keylist+="AngleSignConventions=\r"
	keylist+="\r"
	
	keylist+="PhotonEnergy=\r"
	keylist+="FermiLevel=\r"
	keylist+="SampleTemperature=\r"
	keylist+="WorkFunction=\r"
	keylist+="PassEnergy=\r"
	keylist+="DwellTime=\r"
	keylist+="NumberOfSweeps=\r"
	keylist+="\r"
	
//	if ( data_type==1 )		// SES files			// enabled  F.Schmitt 22/04/07
	keylist+="RegionName=\r"
	keylist+="AnalyzerSlit=\r"
	keylist+="ScientaOrientation=\r"
	keylist+="CCDFirstXChannel=\r"
	keylist+="CCDLastXChannel=\r"
	keylist+="CCDFirstYChannel=\r"
	keylist+="CCDLastYChannel=\r"
	keylist+="NumberOfSlices=\r"
	keylist+="CCDXChannelZero=\r"
	keylist+="CCDDegreePerChannel=\r"
	keylist+="\r"
//	endif										// enabled  F.Schmitt 22/04/07
	
//	if ( data_type==2 )		// MacESCAII		// enabled  F.Schmitt 22/04/07
	keylist+="PhotonSource=\r"	
	keylist+="LensSlit=\r"	
	keylist+="LensIris=\r"	
	//keylist+="MacESCAIIThetaInitial\r"	
	//keylist+="MacESCAIIPhiInitial\r"	
	keylist+="\r"		
//	endif										// enabled  F.Schmitt 22/04/07
	
	keylist+="Processing Information:\r"
	keylist+="MatrixType=\r"
	keylist+="DispersionCorrection=\r"
	keylist+="aTMFWave=\r"
	keylist+="aTMFStartEnergy=\r"
	keylist+="aTMFEndEnergy=\r"
	keylist+="fixedTMFMatrix=\r"
	keylist+="x0Crop=\r"
	keylist+="x1Crop=\r"
	keylist+="y0Crop=\r"
	keylist+="y1Crop=\r"
	keylist+="AngleMapping=\r"
	keylist+="EnergyScale=\r"
	keylist+="AverageWave=\r"
	keylist+="FermiNorm=\r"
	keylist+="OtherModifications=\r"

	// Added for TR-ARPES
	keylist+="Delay(fs)=\r"
	keylist+="DelayStage(mm)=\r"
	return keylist
End