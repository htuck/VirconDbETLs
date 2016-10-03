#!/usr/local/bin/perl

#############################################
# Clinical Data which gets imported to LEHR as dictation notes in dates encounters
=pod
I structured the query so the output file will get the same data from the different tables, 
	ConsultationNotes
	ObstetricCare
	AntiNatalVisitDetails
	
	and it will be arranged in the same columns; see the t-sql query.
	
This routine doesn't split the line into an array but has all columns in each line:
PatientID | ConsultationID | ConsDate | Note
The code grabs each column from the line as $1, $2, $3, $4, cleans up the data and writes it OUT.

=cut
#############################################

	#ferrealie in/ out files
	open(IN, "FromSOC/SocClinicalData.txt") or die "No clindat infile\n";
	open(CDOUT, ">ToLEHR/ClinDatLEHR_Import.sql") or die " can't make clindat outfile\n";;
	
	#======= init the counters
	# these will carry over to the VS portion below.
	
	$seqID=1;	# 1 is ok IF these dictation/ encounter notes are the first value going into a virgin or truncated table 
				#else need to get from qry:   SELECT MAX(ID) FROM `sequences`;   then ADD 1 -- this is the sequences table id 
	
	$formIdCtr=1; 	#everybody here gets a new dictation form even if blank so enc and dict forms' count will be the same.

	$encNr = 1;	# start the encounter numbers at 1 in this virgin system
	
	while (<IN>)	{
		$line= $_;
		
		#skip the header line of the socrates infile
		next if ($line=~ m/﻿PatientID\t.+/);

		#catch the Consultation Note line
		if ($line =~ m/^(\d\d+)\t(\d+)\t(\d\d\d\d\-\d\d\-\d\d 00\:00\:00)\.000\t\|(Consultation Note\:.*)\r$/m) {
			$ptID=$1;
			$consNr=$2;
			$encDt=$3;
			$longnote=$4;
			$longnote =~ s/\'//g;  #clean up the text in the consult notes- may need to add more?
			$longnote =~ s/\"/\\"/g;
			$longnote =~ s/\///g;
			$longnote =~ s/\r/  /g;
			# rem lehr gives us room for 2 dict notes ea form so if we want to pull another out s'where...
		}

		#catch the Obstetric Med Hx line
		if ($line =~ m/^(\d\d+)\t(\d+)\t(\d\d\d\d\-\d\d\-\d\d 00\:00\:00)\.000\t\|(Obstetric Med Hx:.*)\r$/m) {
			$ptID=$1;
			$consNr=$2;
			$encDt=$3;
			$longnote=$4;
			$longnote =~ s/\'//g;  #clean up the text in the consult notes- may need to add more?
			$longnote =~ s/\"/\\"/g;
			$longnote =~ s/\///g;
			$longnote =~ s/\r/  /g;
			# rem lehr gives us room for 2 dict notes ea form so if we want to pull another out s'where...
		}

		#catch the OB Addl Comments line
		if ($line =~ m/^(\d\d+)\t(\d+)\t(\d\d\d\d\-\d\d\-\d\d 00\:00\:00)\.000\t\|(OB Addl Comments:.*)\r$/m) {
			$ptID=$1;
			$consNr=$2;
			$encDt=$3;
			$longnote=$4;
			$longnote =~ s/\'//g;  #clean up the text in the consult notes- may need to add more?
			$longnote =~ s/\"/\\"/g;
			$longnote =~ s/\///g;
			$longnote =~ s/\r/  /g;
			# rem lehr gives us room for 2 dict notes ea form so if we want to pull another out s'where...
		}

		#catch the Anti-Natal Visit Notes line
		if ($line =~ m/^(\d\d+)\t(\d+)\t(\d\d\d\d\-\d\d\-\d\d 00\:00\:00)\.000\t\|(Anti-Natal Visit Notes:.*)\r$/m) {
			$ptID=$1;
			$consNr=$2;
			$encDt=$3;
			$longnote=$4;
			$longnote =~ s/\'//g;  #clean up the text in the consult notes- may need to add more?
			$longnote =~ s/\"/\\"/g;
			$longnote =~ s/\///g;
			$longnote =~ s/\r/  /g;
			# rem lehr gives us room for 2 dict notes ea form so if we want to pull another out s'where...
		}
		
		# each encounter requires entries in multiple tables.
		# Printing the form_encounter line
		print CDOUT "INSERT INTO  `form_encounter`(`pid`,`date`, `onset_date`,`sensitivity`,`reason`,`facility`,`facility_id`,`encounter`,`pc_catid`,`provider_id`) VALUES ((select `pid` from `patient_data` where pubpid='$ptID' order by `pid` limit 1),'$encDt','0000-00-00 00:00:00','normal','Socrates Import Clinical Notes', 'Your Clinic Name Here', '3', '$encNr', '9', '1');\n";

		# Printing the forms line for the new encounter form
		print CDOUT "INSERT INTO  `forms`(`date`,`encounter`,`form_name`,`form_id`,`user`,`pid`,`groupname`,`authorized`,`deleted`,`formdir`) VALUES ('$encDt','$encNr','New Patient Encounter','$formIdCtr','admin',(select `pid` from `patient_data` where `pubpid`='$ptID' order by `pid` limit 1),'default','1','0','newpatient');\n";

		# Printing the form_dictation line
		print CDOUT "INSERT INTO `form_dictation`(`pid`,`groupname`,`user`,`authorized`,`activity`,`date`,`dictation`) VALUES ((select `pid` from patient_data where `pubpid`='$ptID' order by `pid` limit 1),'Default','admin','1',1,'$encDt','$longnote');\n";

		# Printing the forms line for the new dictation form
		print CDOUT "INSERT INTO  `forms`(`date`,`encounter`,`form_name`,`form_id`,`user`,`pid`,`groupname`,`authorized`,`deleted`,`formdir`) VALUES ('$encDt','$encNr','Speech Dictation','$formIdCtr','admin',(select `pid` from `patient_data` where `pubpid`='$ptID' order by `pid` limit 1),'default','1','0','dictation');\n";

		# Printing the sequences line for the new encounter
		print CDOUT "INSERT INTO `sequences` (`id`) values ('$seqID');\n";

		# jack up all counters
		$seqID++;
		$encNr++;
		$formIdCtr++;
	}
#####################################################
#section: Vitals
=pod
When split into the array @PtLine, the socrates fields are in these array elements:
	$PtLine[N]	

	0 PatientID (from soc, imported to LEHR as the pubpid)
	1 RecordedDate
	2 Active
	3 PhysicalExercise
	4 Weight
	5 Height
	6 BMI
	7 Obdominal
	8 Systolic
	9 Diastolic
	10 Pulse
	11 Temp
	12 User
	13 HeadCircumference

=cut

# -- open the txt input file from soc and start the output sql file to LEHR
	open(IN, "FromSOC/SocVS_Export.txt") or die "No VS infile\n";
	open(VSOUT, ">ToLEHR/VSDataLEHR_Import.sql");

	$formIdCtr=1;	#these should be the first VS forms going into this virgin system so can start at 1 for the form_id table
					#if not the first, use the qry: (SELECT MAX(form_id) FROM `forms` where `form_name`='Vitals';)
					
	while (<IN>)	{
		$line= $_;
		
		#skip the header line of the socrates VS infile
		next if ($line=~ m/﻿PatientID\t.+/);
				
		#Get out the oil- data massage commences:

		#since these VS are all floats, I'm replacing all the null entries everywhere w/ 0's.
		$line =~ s/\NULL/0.00/g;
		# how a /r got into head circ I will never know! But when I split the line there it is in [13].
		# but they could be ANYwhere...! so kill them here.
		$line =~ s/\r//g;
		$line =~ s/\r//g;

		#splitting the incoming soc data line on the tabs between ea column.
		@PtLine = split(/\t/,$line);

		#fetching the soc PatientID = LEHR's External ID aka Public ID aka pubpid
		$ptID=$PtLine[0];

		#prevents printing OUT bogus sql lines if we get a bunch of \n's at the end of the input file.
		last if ($ptID=~ m//);
		
		# This seems ghetto but I have to get JUST the date val for each VS record so I can search for the encounter that happened on that date.
		#	because when I imported the encounters back in the clinicaldata import, I nuked the times so they only have date+ 00:00:00
		#cropping off the trailing 000 in the date-time
		if ($PtLine[1] =~ m/^(\d\d\d\d\-\d\d\-\d\d\s\d\d\:\d\d\:\d\d)\.\d\d\d/m) {$DaTime=$1;} #this is the full date+time I will write to the table
		#prolly del this: if ($PtLine[1] =~ m/^(\d\d\d\d\-\d\d\-\d\d)\s\d\d\:\d\d\:\d\d\.\d\d\d/m) {$JusDate=$1;} #this is just the date to use for searching for encounters.

		#translating some numeric ary elements to text
		# soc phys acty = 1 -> yes activity
		if ($PtLine[2]==1) {$note='Physically active';} else {$note='Not physically active'};

		#hunting the elusive \n which for some reason always shows up in this ary element!
		$PtLine[13] =~ s/\n//g;
		$PtLine[13] =~ s/NULL/0.00/g;
		
		# All things considered it's preferable to simply add another encounter for the structured VS data.
		# Printing the form_encounter line
		print VSOUT "INSERT INTO  `form_encounter`(`pid`,`date`, `onset_date`,`sensitivity`,`reason`,`facility`,`facility_id`,`encounter`,`pc_catid`,`provider_id`) 
		VALUES ((select `pid` from `patient_data` where pubpid='$ptID' order by `pid` limit 1),'$DaTime','0000-00-00 00:00:00','normal','Import separate VS entries', 'Your Clinic Name Here', '3', '$encNr', '9', '1');\n";

		# Printing the lehr VS form import sql data line
		print VSOUT "INSERT INTO `form_vitals`(`date`,`pid`,`user`,`bps`,`bpd`,`weight`,`height`,`temperature`,`pulse`,`BMI`,`waist_circ`,`head_circ`) VALUES ('$DaTime',(select `pid` from `patient_data` where `pubpid`='$PtLine[0]' order by `pid` limit 1),'$PtLine[12]','$PtLine[8]','$PtLine[9]',$PtLine[4],$PtLine[5],$PtLine[11],'$PtLine[10]',$PtLine[6],$PtLine[7],$PtLine[13]);\n";

		#each form also requires some references in other tables
		#`forms`
		
		print VSOUT "INSERT INTO `forms`(`date`,`encounter`,`form_name`,`form_id`,`user`,`pid`,`groupname`,`authorized`,`deleted`,`formdir`) VALUES ('$DaTime','$encNr', 'Vitals', '$formIdCtr', '$PtLine[12]',(select `pid` from `patient_data` where `pubpid`='$PtLine[0]' order by `pid` limit 1), 'default', 1, 0, 'vitals');\n";
		
		#`sequences`
		print VSOUT "INSERT INTO `sequences` (`id`) values ($seqID);\n";
		
		#++ the forms table ID counter
		$formIdCtr++;
		#++ the sequences table id val
		$seqID++;
		#++ form_encounter's `encounter` val
		$encNr++;
		#blank the notes field var4
		$note='';
				
	}
close;

;


