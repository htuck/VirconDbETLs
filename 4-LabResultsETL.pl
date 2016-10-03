#!/usr/local/bin/perl

###################################################################
=pod

This is a complex transformation.  Each XMLResults record from the Socrates table
	represents a 3 dimensional aray which for coding simplicity I've simply extracted into 3 nested arys

XMLResults record
		Reports
			TestN
				TestID_N
				TestResult_N
			/TestN
		/Reports
/XMLResults record

Each line from the Socrates tab-delim txt export file is 1 pt's report which may have mult test results in it.
The line comes in and the patientID and report date are pulled out from the beginning of the linein string.
Split the line on tab -> @labline w/ elements [0] = patientID, [1] = result record date and [2] = the reports line
Foreach $labline run through @labline skipping [0] and [1] which don't have xml tags in them.
Split [2] on tabs (that were in original soc export file) into @resultline
foreach $resultline insert \n between each xml open/ close tag.
	split $resultline on the \n into @tagline

Now we have @tagline containing all the fields of all the tests in this report.
Each ary element contains an open/ close xml tag surrounding a value.

Each test result is made up of an OBR segment with the 'Observation' (test) identifiers
	, and an OBX segment with the 'Observation' results values.
	All the values have some sort of label tag but it doesn't tell if it's an OBR or OBX value.

@tagline is arranged so:
	<test1>
		<OBR>
			<label1>value1</label1>
			<label2>value2</label2>
			<label3>value3</label3>
		</OBR
		<OBX>
			<label4>value4</label4>
			<label5>value5</label5>
			<label6>value6</label6>
		</OBX>
	<test2>
		<OBR>
			<label1>value1</label1>
			<label2>value2</label2>
			<label3>value3</label3>
		</OBR
		<OBX>
			<label4>value4</label4>
			<label5>value5</label5>
			<label6>value6</label6>
		</OBX>

The ary elements flow past in that order
	we watch for the resultN tag and initialize the variables for the next test's data.
	we watch for <OBR> tag and set a flag telling us the values in the next lines coming through will be assign to the OBR value variables.
	The </OBR> tag turns off the OBR flag
	The OBX tag sets a flag to assign the next values to the OBX variables.
	</OBX> turns off that flag
	The tag for the next test comes by; 
		repeat til done.

Some of the result value fields turn out to have large amounts of free text in them.  Go figure.



=cut
###################################################################

open IN, "SocLabResTest.txt"; 
open OUT, ">LabResultsLEHR_Import.sql"; #to be renamed sqlout or sthg.


#input infile line by line.  
#	At this level, each line is one complete lab report containing identifiers and multiple results.
while (<IN>) {
	$labline = $_;

	#skip that header line...
	next if ($labline=~m/PatientID/g);
	
	#grab the 1st couple fields in the labline which are the ptId and date
	if ($labline =~m/^(\d+)\t(\d\d\d\d\-\d\d\-\d\d) \d\d\:\d\d\:\d\d\.\d\d\d\t\<ORU/g) {$PatientID=$1;$DateCreated=$2;}

	#caveat at the head of each report.
	$LabOUT = "These imported reports are for reference only- \n\tObtain authoritative original reports from lab or paper archive\n\n";
	
	#stick a tab at the beginning of each ORU segment which marks the beginning of each result
	$labline=~ s/\<ORU/\t\<ORU/g;

	#split each line on the tabs, into an ary containing one lab result report in each ary element
	@resultline = split(/\t/,$labline);

	# run through each result report
	foreach $resultline (@resultline) {

		#skip the ary element if it doesn't have a tag in it
		#	those will be the elements [0] and [1] containing ptID and date
		next if $resultline!~ m/^\</;

		# I like flags, I cannot lie.
		#	 turn one on when resultline has the tag, to activate the print OUT down below.
		if ($resultline =~ m/\<\/OBR\>/g) {$OBRFlag=1;}
		if ($resultline =~ m/\<\/OBX\>/g) {$OBXFlag=1;}

		#init the printout text vars.
		my ($ObsvDaTime, $TesType, $SpecType, $TestName, $ResultVal, $ResultUnits, $AbbyNormal, $RefRange, $ResultStat, $OrdProv) = ('');
		
		#give it a \n delimiter to split on
		$resultline =~ s/\>\</\>\n\</g;

		#do it
		@tagline = split(/\n/,$resultline);


		foreach $tagline (@tagline) {
			# main section where we see the segment tags and capture the data.

			#OBR.4 Test Type  $TesType
			if ($tagline=~ m/\<OBR\.4\>/)	{$OBR4Flg = 1;}
			if ($OBR4Flg == 1 && $tagline=~ m/\<CE\.2\>(.+?)\<\/CE\.2\>/g)	{$TesType="Test Type: $1"; $OBR4Flg=0;}

			#OBR.7 Obsv Date-time  $ObsvDaTime
			if ($tagline=~ m/\<OBR\.7\>/)	{$OBR7Flg = 1;}
			if ($OBR7Flg == 1 && $tagline=~ m/\<TS\.1\>(\d\d\d\d)(\d\d)(\d\d)(\d\d\d\d)\<\/TS\.1\>/g)	{$ObsvDaTime="Test Date-Time: $1-$2-$3-$4"; $OBR7Flg=0;}

			#OBR.15  Spec Type -  mebbe not required!  $SpecType
			if ($tagline=~ m/\<OBR\.15\>/)	{$OBR15Flg = 1;}
			if ($OBR15Flg == 1 && $tagline=~ m/\<CE\.1\>(.+?)\<\/CE\.1\>/g)	{$SpecType="Spec Type: $1"; $OBR15Flg=0;}

			#OBR.16 Ordering Provider  - accum the parts of the name and cat at print OUT.
			if ($tagline=~ m/\<OBR\.16\>/)	{$OBR16Flg = 1;}
			if ($OBR16Flg == 1 && $tagline=~ m/\<XCN\.6\>(.+?)\<\/XCN\.6\>/g)	{$OBR16Title=$1;} # Title
			if ($OBR16Flg == 1 && $tagline=~ m/\<FN\.1\>(.+?)\<\/FN\.1\>/g)	{$OBR16FNam=$1;} # first name
			if ($OBR16Flg == 1 && $tagline=~ m/\<XCN\.3\>(.+?)\<\/XCN\.3\>/g)	{$OBR16SNam=$1;} # surname

			#don't know how many note fields are allowed; hoping no > 3?
			#NTE.1 Notes and Comments 1
			if ($tagline=~ m/\<NTE\.1\>/ && $tagline=~ m/\<NTE\.1\>(.+?)\<\/NTE\.1\>/g)	{$NTE1Note=$1;} # Note 1

			#NTE.2 Notes and Comments 2
			if ($tagline=~ m/\<NTE\.2\>/ && $tagline=~ m/\<NTE\.2\>(.+?)\<\/NTE\.2\>/g)	{$NTE2Note=$1;} # Note 2

			#NTE.3 Notes and Comments 3
			if ($tagline=~ m/\<NTE\.3\>/ && $tagline=~ m/\<NTE\.3\>(.+?)\<\/NTE\.3\>/g) {$NTE3Note=$1;} # Note 3
			
			#OBX3 Test Name  $TestName
			if ($tagline=~ m/\<OBX\.3\>/)	{$OBX3Flg = 1;}
			if ($OBX3Flg == 1 && $tagline=~ m/\<CE\.2\>(.+?)\<\/CE\.2\>/g)	{$TestName="Test: $1"; $OBX3Flg=0;}

			#OBX.5 Result Value  $ResultVal
			if ($tagline=~ m/\<OBX\.5\>(.+?)\<\/OBX\.5\>/g)	{$ResultVal = "Result: $1";}

			#OBX.6 ResultUnits  $ResultUnits
			if ($tagline=~ m/\<OBX\.6\>/)	{$OBX6Flg = 1;}
			if ($OBX6Flg == 1 && $tagline=~ m/\<CE\.2\>(.+?)\<\/CE\.2\>/g)	{$ResultUnits=$1; $OBX6Flg=0;}

			#OBX.7  Reference Range  $RefRange
			if ($tagline=~ m/\<OBX\.7\>(.+?)\<\/OBX\.7\>/g)	{$RefRange = "Ref Range: $1";}

			#OBX.8  Ab/Normal  $AbbyNormal
			if ($tagline=~ m/\<OBX\.8\>(.+?)\<\/OBX\.8\>/g)	{$AbbyNormal = $1;}

			#OBX.11  Result Status (final or not)  $ResultStat
			if ($tagline=~ m/\<OBX\.11\>(.+?)\<\/OBX\.11\>/g)	{$ResultStat = "Result Status: $1";}

			#WOKAY- these reports have 2 sections: the test identifiers (OBR) and the test results (OBX).
			# I'm checking which type of section just passed through to know which line to print out.
			
		}	# foreach tagline
		
		# THIS is what I'm calling the 'print OUT' section-
		#	it actually assembles the variables into lines that are printed out to to the SQL line
		
		#print out the OBR test identifiers as soon as OBR section is done

		$OrdProv= "Ordering Provider $OBR16Title $OBR16FNam $OBR16SNam";

		#assemble all notes lines here for print OUT
		$Notes= "Notes: $NTE1Note $NTE2Note $NTE3Note";

		#if OBR flag is on print the line out and reinit the variables
		if ($OBRFlag == 1) {	
			
			$LabOUT .= "$TesType\t$ObsvDaTime\t$SpecType\t$OrdProv\n$Notes\n";
			
			#blankemout
			my ($TesType, $ObsvDaTime, $SpecType, $OrdProv)=('');
			$OBRFlag=0;
			$Notes='';
			$OrdProv='';
		}


		#print out the OBX test results as soon as OBX section is done
		if ($OBXFlag == 1) {	
			$LabOUT .= "\t$TestName $ResultVal$ResultUnits $RefRange \($AbbyNormal\) $ResultStat\n";
			
			#blankemout
			my ($TestName, $ResultVal, $ResultUnits, $RefRange, $AbbyNormal, $ResultStat)=('');
			$OBXFlag=0;
			$labpnote='';					
		} #print OUT after all the taglines have passed
			

	} #foreach $resultline
	
	#The SQL output line

	#print "$LabOUT\n";  #just for final testing
	
	$assignedTo='admin';	#this will turn into a routine to retrieve a user ID from the fully configured production system's user table
	
	# Thar she blows!
	print OUT "INSERT INTO `pnotes` (`date`,`body`,`pid`,`groupname`,`activity`,`authorized`,`title`,`assigned_to`,`deleted`,`message_status`) 
	VALUES ('$DateCreated','$LabOUT',(select `pid` from `patient_data` where pubpid='$PatientID' order by `pid` limit 1),'Default',1,1,'Lab Results','$assignedTo',0,'New');\n";

}	# 
;

