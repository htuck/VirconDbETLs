#!/usr/local/bin/perl

=pod
subscripts of the demogs data array:
0 ﻿fname
1 lname
2 DOB
3 pubpid
4 status
5 title
6 ss
7 sex
8 mname
9 street
10 city
11 email
12 contact_relationship
13 phone_contact
14 phone_home
15 phone_cell
16 mothersname
17 postal_code
18 phone_biz
19 cmsportal_login
20 pharmacy_id  =
21 occupation
22 contrastart
23 family_size
24 homeless
25 interpretter
26 migrantseasonal
27 deceased_reason
28 regdate

=cut

print "just printed the demogs\n";

	# -- open the raw tsql export txt file
	open(IN, "FromSOC/SocDemogs.txt") or die "No demogs infile\n";

	# makes the output filename
	open(DEMOUT, ">ToLEHR/DemogsLEHR.sql") or die "no demogs outfile\n";


#=====================================================
	#======= init some counters
	$pid=1001;	#will be the first new pt's pid.

	#inhale the file line by line
	while (<IN>)	{
		$line= $_;

#print "$line\n";		
		
		#skip the header line of the socrates infile
		next if ($line=~ m/﻿fname\t.+/);
				
		#Get out the oil- data massage commences:

		#replace the null entries w/ empty strings...? uncomment if you have to do that
		#$line =~ s/NULL/ /g;
		$line =~ s/'/ /g;	# O'Reilly -> O Reilly
		$line =~ s/`/ /g;	# O`Reilly -> O Reilly
		
		#splitting the incoming soc data line on the tabs between ea column.
		@DEMLine = split(/\t/,$line);

		#fetching SOC's PatientID = LEHR's External ID aka Public ID aka pubpid
		$ptID=$DEMLine[3];
		
		#prevents printing OUT bogus sql lines that have no patientID if we get a bunch of \n's at the end of the input file.
		last if ($ptID=~ m//);

		# >> use this to clean up DOB [2] and regdate[28]
		# soc's date+time has several too many second values 
		#	so I'm assigning the desired vals to TDaTime for use in the print out line.
		if ($DEMLine[2] =~ m/^(\d\d\d\d\-\d\d\-\d\d\s\d\d\:\d\d\:\d\d)\.\d\d\d/m) {$DoB=$1;}
		if ($DEMLine[28] =~ m/^(\d\d\d\d\-\d\d\-\d\d\s\d\d\:\d\d\:\d\d)\.\d\d\d/m) {$RegDt=$1;}

	
		
		# Printing the patient_data line
		print DEMOUT "INSERT INTO `patient_data` (`pid`,`fname`,`lname`,`DOB`,`pubpid`,`status`,`title`,`ss`,`sex`,`mname`,`street`,`city`,`email`,`contact_relationship`,`phone_contact`,`phone_home`,`phone_cell`,`mothersname`,`postal_code`,`phone_biz`,`cmsportal_login`,`occupation`,`contrastart`,`family_size`,`homeless`,`interpretter`,`migrantseasonal`,`deceased_reason`,`regdate`) Values ($pid,'$DEMLine[0]','$DEMLine[1]','$DoB','$DEMLine[3]','$DEMLine[4]','$DEMLine[5]','$DEMLine[6]','$DEMLine[7]','$DEMLine[8]','$DEMLine[9]','$DEMLine[10]','$DEMLine[11]','$DEMLine[12]','$DEMLine[13]','$DEMLine[14]','$DEMLine[15]','$DEMLine[16]','$DEMLine[17]','$DEMLine[18]','$DEMLine[19]','$DEMLine[21]','$DEMLine[22]','$DEMLine[23]','$DEMLine[24]','$DEMLine[25]','$DEMLine[26]','$DEMLine[27]','$RegDt');\n";
		
		#boost the pid by one...
		$pid++;
 }
CLOSE;
;

