#!/usr/local/bin/perl

###################################################################
=pod 
	this script processes all the Hx data
		and produces the sql files to simply import it all into LEHR
	Hx data being: 
		prescriptions, allergies, immunizations, lifestyle.
	I will provide a large banner heading below to mark each code section.

	one reason to make multiple import files is to keep them under the default size limit for database imports.

Wokay: this is for the meds.

ary subscripts and their LEHR columns: 
	0 substitute
	1 refills
	2 pubpid
	3 user
	4 start_date
	5 drug
	6 form
	7 quantity
	8 size
	9 interval
	10 substitute
	11 note

=cut
###################################################################
	
	#realies infile
	open(IN, "FromSOC/SocRxExport.txt") or die "No Rx infile\n";
	
	#output file name
	open(RXOUT, ">ToLEHR/RxDataLEHR_Import.sql");
	
	#input infile line by line
	while (<IN>)	{
		$line= $_;
		
		#skip the header line of the socrates infile
		next if ($line=~ m/substitute\t.+/);

		#Get out the oil- data massage commences:

		#ditch those \r's
		$line =~ s/\r//g;

		#splitting the incoming soc data line on the tabs between ea column into the RxLine ary
		@RxLine = split(/\t/,$line);

		#fetching the Pt ID = LEHR's External ID aka Public ID aka pubpid
		$ptID=$RxLine[0];
		
		#prevents printing OUT bogus sql lines if we get a bunch of \n's at the end of the input file.
		last if ($ptID=~ m//);
		
		# soc's date+time has several too many second values 
		#	so I'm assigning the desired vals to TDaTime for use in the print out line.
		if ($RxLine[4] =~ m/^(\d\d\d\d\-\d\d\-\d\d\s\d\d\:\d\d\:\d\d)\.\d\d\d/m) {$DaTime=$1;}

	
		#and dangit, the drug name does too
		$RxLine[5] =~ s/NULL/''/g;
		$RxLine[5] =~ s/\'//g;
		$RxLine[5] =~ s/\`//g;
		$RxLine[5] =~ s/\r//g;
		
		#as does the drug form!
		$RxLine[6] =~ s/NULL/''/g;
		$RxLine[6] =~ s/\'//g;
		$RxLine[6] =~ s/\`//g;
		$RxLine[6] =~ s/\r//g;

		#'note' field always has punct
		$RxLine[10] =~ s/NULL/''/g;
		$RxLine[10] =~ s/\'//g;
		$RxLine[10] =~ s/\`//g;
		$RxLine[10] =~ s/\n/  /g;
		$RxLine[10] =~ s/\r/  /g;
		
		
		# All things considered it's preferable to simply add another encounter for the structured VS data.
		# Printing the form_encounter line
		print RXOUT "INSERT INTO `prescriptions` (`patient_id`,`substitute`,`refills`,`user`,`start_date`,`drug`,`form`,`quantity`,`size`,`interval`,`note`) VALUES ((select `pid` from `patient_data` where `pubpid`='$RxLine[2]' order by `pid` limit 1),$RxLine[0],$RxLine[1],'$RxLine[3]','$DaTime','$RxLine[5]','$RxLine[6]',$RxLine[7],'$RxLine[8]','$RxLine[9]','$RxLine[10]');\n"
		
		
	}

###################################################	
=pod next section: Immunizations.
#	Long ago and far away I got into the habit of abbreviating these as IMO.  And I still do it whenever I get the chance.
#the @IMOLine subscripts as LEHR database immunizations table columns:
	0 ﻿pubpid
	1 administered_date
	2 immunization_id
	3 cvx_code
	4 manufacturer
	5 lot_number
	6 administered_by
	7 note
	8 amount_administered_unit
	9 expiration_date
	10 route
	11 administration_site
=cut
###################################################################

	#realies infile
	open(IN, "FromSOC/SocPtIMO.txt") or die "No IMO infile\n";
	
	#output file name
	open(IMOOUT, ">ToLEHR/IMODataLEHR_Import.sql");
	
	#input infile line by line
	while (<IN>)	{
		$line= $_;
		
		#skip the header line of the socrates infile
		next if ($line=~ m/pubpid\t.+/);

		#Get out the oil- data massage commences:

		#some of these may not be nec for IMOs but they can't hurt...?
		$line =~ s/\r//g;
		$line =~ s/\n//g;
	
		#splitting the incoming soc data line on the tabs between ea column.
		@IMOLine = split(/\t/,$line);

		#fetching the Pt ID = LEHR's External ID aka Public ID aka pubpid
		$ptID=$IMOLine[0];

		#prevents printing OUT bogus sql lines if we get a bunch of \n's at the end of the input file.
		last if ($ptID=~ m//);

		# soc's date+time has several too many second values 
		#	so I'm pulling out the desired vals for use in the print out line.
		# this is $DaTime for administration date and some others that can be the same.
		if ($IMOLine[1] =~ m/^(\d\d\d\d\-\d\d\-\d\d\s\d\d\:\d\d\:\d\d)\.\d\d\d/m) {$DaTime=$1;}
		# this is the expiration date which had better be different than $DaTime
		if ($IMOLine[9] =~ m/^(\d\d\d\d\-\d\d\-\d\d\s\d\d\:\d\d\:\d\d)\.\d\d\d/m) {$XpTime=$1;}

		#cleaning the cvx nr
		$IMOLine[3] =~ s/NULL/''/g; #can be null if it wants.
		$IMOLine[3] =~ s/^\z/''/g; #can be null if it wants.
		$IMOLine[3] =~ s/\-//g; # no dashes
		if ($IMOLine[3] =~ m/^(\d\d\d\d\d\d\d\d\d\d\d)\d\d/m) {$IMOLine[3]=$1;}  # can only be int(11) so taking left 11 

		# All things considered it's preferable to simply add another encounter for the structured VS data.
		# Printing the form_encounter line
		print IMOOUT "INSERT INTO `immunizations` (`patient_id`,`administered_date`,`immunization_id`,`cvx_code`,`manufacturer`,`lot_number`,`administered_by`,`education_date`,`vis_date`,`note`,`amount_administered_unit`,`expiration_date`,`route`,`administration_site`) VALUES ((select `pid` from `patient_data` where `pubpid`='$IMOLine[0]' order by `pid` limit 1),'$DaTime',$IMOLine[2],$IMOLine[3],'$IMOLine[4]','$IMOLine[5]','$IMOLine[6]','$XpTime','$XpTime','$IMOLine[7]','$IMOLine[8]','$XpTime','$IMOLine[10]','$IMOLine[11]');\n";
	}
=cut

###################################################	
=pod
This next section is the allergy/ sensitivities.
This section is a little different from the others.
I construct $vars with some data that the soc infile doesn't provide 
	(see the line: 	#assign lehr cols same for all recs)
then write the strings and the data in the ary subscripts out in the order they're listed below.

	Subscript/ $name	LEHR col	value
	0		 			date	 	soc's date recorded
	$type 				type 		"allergy" - for lists_touch table
	1 					title 		"Allergy: " or "Sensitivity:" + name of substance 
	2					begdate 	(soc beginning date)
	$occr				occurrence	4 (aka "Chronic/Recurrent") for all
	$refby				referredby	"Dr McConville" for all
	3 					pubpid	 	soc's PatientID to translate to LEHR pid.
	4					user 		LEHR only allows int here so simply using the soc UserID
	$outcome			outcome 	0 ("unassigned" for all
	5					reaction 	freetext from soc 
	$erxsrc				erx_source		0
	$erxuld				erx_uploaded	0
	$moddate			modifydate	date recorded (ary[0])

=cut
###################################################	

	#realies infile
	open(IN, "FromSOC/SocAlgieSensExport.txt") or die "No AlgieSens infile\n";
	
	#output file name
	open(ALGOUT, ">ToLEHR/AlgieSensLEHR_Import.sql");
	
	#input infile line by line
	while (<IN>)	{
		$line= $_;
		
		#skip the header line of the socrates infile
		next if ($line=~ m/date\t.+/);

		#Get out the oil- data massage commences:

		#some of these may not be nec for non-freetxt fields but they can't hurt...?
		$line =~ s/\r//g;
		$line =~ s/\n//g;
	
		#splitting the incoming soc data line on the tabs between ea column.
		@ALGLine = split(/\t/,$line);

		#fetching the Pt ID = LEHR's External ID aka Public ID aka pubpid
		$ptID=$ALGLine[3];
		
		#prevents printing OUT bogus sql lines if we get a bunch of \n's at the end of the input file.
		last if ($ptID=~ m//);
		
		# soc's date+time has several too many second values 
		#	so I'm pulling out the desired vals for use in the print out line.
		# this is $DaTime for 'recorded date' and some others that can be the same.
		if ($ALGLine[0] =~ m/^(\d\d\d\d\-\d\d\-\d\d\s\d\d\:\d\d\:\d\d)\.\d\d\d/m) {$DaTime=$1;}
		# this is the beginning date which may be different than $DaTime's recording date
		if ($ALGLine[2] =~ m/^(\d\d\d\d\-\d\d\-\d\d\s\d\d\:\d\d\:\d\d)\.\d\d\d/m) {$BegDt=$1;}

		#cleaning up the 'reaction' note
		$ALGLine[5] =~ s/\'//g;
		$ALGLine[5] =~ s/\`//g;
		$ALGLine[5] =~ s/\,/ /g;
		$ALGLine[5] =~ s/\r//g;

	#assign lehr cols same for all recs:
		$type = "allergy";
		$occr = 4;
		$refby = "Dr McConville";
		$outcome = 0;
		$erxsrc = 0;
		$erxuld = 0;
		$moddate = $DaTime;

		# Printing the `lists` allergy line
		print ALGOUT "INSERT INTO `lists` (`date`,`type`,`title`,`begdate`,`occurrence`,`referredby`,`pid`,`user`,`outcome`,`reaction`,`erx_source`,`erx_uploaded`,`modifydate`) VALUES ('$DaTime','$type','$ALGLine[1]','$BegDt',$occr,'$refby', (select `pid` from `patient_data` where `pubpid`='$ALGLine[3]' order by `pid` limit 1),$ALGLine[4],$outcome,'$ALGLine[5]',$erxsrc,$erxuld,'$moddate');\n";
		
	
	}
###################################################	
=pod

This next section is the LEHR Lifestyle type historical data.
See the historical info gap analysis for the full story.

Subscripts:
	0 ﻿pubpid
	1 alcohol
	2 recreational_drugs
	3 tobacco
	4 exercise_patterns	
	
=cut
###################################################	

	#realies infile
	open(IN, "FromSOC/SocLifestyleEquivs.txt") or die "No LifesHx infile\n";
	
	#output file name
	open(LIFEOUT, ">ToLEHR/LifestyleHxLEHR_Import.sql");
	
	#input infile line by line
	while (<IN>)	{
		$line= $_;
		
		#skip the header line of the socrates infile
		next if ($line=~ m/﻿pubpid\t.+/);
		
		#Get out the oil- data massage commences:

		#some of these may not be nec for non-freetxt fields but they can't hurt...?
		$line =~ s/\r//g;
		$line =~ s/\n//g;

		#splitting the incoming soc data line on the tabs between ea column.
		@LIFELine = split(/\t/,$line);

		#fetching the Pt ID = LEHR's External ID aka Public ID aka pubpid
		$ptID=$LIFELine[0];

		#prevents printing OUT bogus sql lines if we get a bunch of \n's at the end of the input file.
		last if ($ptID=~ m//);
		
		#swapping out some aray element values
		#	easier than if/ then stmts!
		$LIFELine[1] =~ s/0/Denies alcohol use/;
		$LIFELine[1] =~ s/1/Endorses alcohol use/;
		$LIFELine[1] =~ s/NULL/Not recorded/;
		
		$LIFELine[2] =~ s/0/Denies recreational drug use/;
		$LIFELine[2] =~ s/1/Endorses recreational drug use/;
		$LIFELine[2] =~ s/NULL/Not recorded/;
		
		$LIFELine[3] =~ s/0/Denies tobacco use/;
		$LIFELine[3] =~ s/1/Endorses tobacco use/;
		$LIFELine[3] =~ s/NULL/Not recorded/;
		
		$LIFELine[4] =~ s/0/Denies significant activity/;
		$LIFELine[4] =~ s/1/Endorses significant activity/;
		$LIFELine[4] =~ s/NULL/Not recorded/;

		# Printing the `lists` allergy line
		print LIFEOUT "INSERT INTO `history_data` (`pid`,`alcohol`,`recreational_drugs`,`tobacco`,`exercise_patterns`) VALUES ((select `pid` from `patient_data` where `pubpid`='$LIFELine[0]' order by `pid` limit 1),'$LIFELine[1]','$LIFELine[2]','$LIFELine[3]','$LIFELine[4]');\n";
		
		
	}

close;
;


