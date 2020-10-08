#!/usr/bin/perl
#
use strict;
use Sys::Hostname;
use File::Basename;
use File::Temp "tempfile";
use LWP::UserAgent;
use HTTP::Request::Common;
use CGI qw(:standard);
use FileHandle;
use Data::Dumper;
use Time::Local;
use POSIX qw(strftime);
use Getopt::Std;
use Fcntl;
use List::Util qw(max min);

use lib '/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/modules';
use lib '/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/modules/pm';
use CommonHTML;
use LoadCache;
use CommonFunctions;
use CommonColor;

my %opts;
##Check for Specific Customer option
getopts('c:s', \%opts) || usage("invalid arguments\n -c \"<customer>,<customer>,<customer>\"");

use vars qw($cache_dir);
use vars qw($rawdata_dir);
use vars qw($cfg_dir);
use vars qw($l2_report_dir);
use vars qw($drilldown_dir);
use vars qw($green $red $amber $grey $orange $cyan $cgreen $lgrey $info $info2 $dgrey $voilet $lgolden $lblue $hpe $golden);

# Declaration of global Variable
my %l2_backup;
my $t1_server="";

my %cache=();
my %cache1=();
my $weekNumber = POSIX::strftime("%V", localtime time);


my $DEBUG=1;
my $date_str = POSIX::strftime("%d-%m-%Y", localtime time);
my %mons = ( january => 0, february => 1,  march => 2, april => 3, may => 4, june => 5, july => 6, august => 7, september => 8, october => 9, november => 10, december => 11);
my @om_server;
my @all_data;
my %backup_data;
my %backup_report;
my %backup_cell_srv_list;
my %d2d_report;
my %backup_log_collection;
my %backup_col;
my %backup_nb;
my %backup_tsm;
my %backup_be;
my %backup_arc;
my %backup_emc;
my %backup_emcavmr;
my %backup_commvault;
my %omnirpt_d2d;
my %d2d_col;

my %backup_omnirpt;
my %backup_nbrpt;
my %backup_tsmrpt;
my %backup_berpt;
my %backup_arcrpt;
my %backup_emcrpt;
my %backup_emcavmrrpt;
my %backup_commvaultrpt;
my %omnirpt_d2d;
my %all_bkp_ci;
my %all_bkp_shortci;
my %backup_srv_aliases;
my %bkpsrv_alias_list;
my %bkpsrv_company;
my %bkpsrv_clu_mapping;
my %vm=();
my %vmsub=();
#my %bkpsrv_list;
my %cellsrv;
my %dpa_reported_cell_srv;


my $start_time = time();


my @list = ('account_reg','om_status');
%cache = load_cache(\@list);
my %account_reg = %{$cache{account_reg}};
my %om_status = %{$cache{om_status}};

my $t1_region;
my $cfg = read_config();
$t1_region = $cfg->{APJ_T1_SERVERS};

my $os_type_list = "win|netware|esx|aix|hp-ux|linux|sol|sun|openvms|nonstop|sco|z\/os|freebsd|vio|unix";
if(defined $cfg->{BKP_OS_TYPE_LIST}){
	$os_type_list = $cfg->{BKP_OS_TYPE_LIST};
}
print "os_type_list : $os_type_list\n";

my $system_type_list = "server|cluster node";
if(defined $cfg->{BKP_SYSTEM_TYPE_LIST}){
	$system_type_list = $cfg->{BKP_SYSTEM_TYPE_LIST};
}
print "system_type_list : $system_type_list\n";

my @om_servers = split (/\,/,$cfg->{TIER1_OM_SERVERS});
my @raw_logs = ('backup_status.gz');

my ($customer,$sub,$display,$reg,$country,$esl,$mon,$esl_sub);
my ( $day, $month, $year ) = (localtime)[ 3, 4, 5 ];
my @months = qw( january february march april may june july august september october november december);
my $last_month = $months[$month-1];
my $this_year = $year + 1900;
my %backup_cellsrv;

if (not defined($opts{"s"})) {
	print "Inside s option not defined \n";
	get_bkpsrv_clu_mapping();
	printf "get_bkpsrv_clu_mapping : %0.2f Mins\n", (time() - $start_time) / 60;
	get_bkpsrv_list_local();
	printf "get_bkpsrv_list_local : %0.2f Mins\n", (time() - $start_time) / 60;

	@list = ('backup_cellsrv_2');
	%cache = load_cache(\@list);
	%backup_cellsrv = %{$cache{backup_cellsrv_2}};

	get_bkpsrvalias_list();
	printf "get_bkpsrvalias_list : %0.2f Mins\n", (time() - $start_time) / 60;

	foreach my $log (@raw_logs) {
		get_raw_logs($log);
	printf "get_raw_logs : %0.2f Mins\n", (time() - $start_time) / 60;
	}

	processbackupdata();
	printf "processbackupdata : %0.2f Mins\n", (time() - $start_time) / 60;
	process_backup_report();
	printf "process_backup_report : %0.2f Mins\n", (time() - $start_time) / 60;
	####process_backup_d2d_report();

	create_l2_backup_cache();
}


sub processbackupdata {
	my $bkp_cellsrv;
	my $current_tm = POSIX::time();
	my ($tm,$size,$cell);

	foreach my $customer (sort keys %account_reg) {
		###next if ($account_reg{$customer}{oc_region} !~ /anz|amea|asia|ukiimea/i);
		#next if ($customer ne "origin energy");
		#next if ($customer !~ /ahold/i);
		my %tools_summary=();
		my $file_name = "$account_reg{$customer}{sp_mapping_file}"."_esl_system_ci_by_fqdn";
		my $l3_filename = "$account_reg{$customer}{sp_mapping_file}"."_tools";

		next if (not -r "$cache_dir/by_customer/$file_name");

		my $sys = load_cache_byFile("$cache_dir/by_customer/$file_name");

		my %esl_system_ci = %{$sys};

		my $center = "ALL";
		foreach my $fqdn (keys %{$esl_system_ci{$customer}{$center}}) {
			my @fqdn_short_name = split (/\./,$fqdn);
			$all_bkp_ci{$fqdn} = 1;
			$all_bkp_shortci{@fqdn_short_name[0]} = 1;
		}
	}
	my ($netbkp_count);
	opendir ( DIR, $rawdata_dir ) || return "Error in opening dir $rawdata_dir\n";
	while( (my $filename = readdir(DIR))){
		next if ($filename !~ /backup_status|backup_bsr_status|backup_networker_status/i);
		#next if ($filename !~ /backup_networker_status/i);
		if ($filename =~ /backup_status|backup_bsr_status|backup_networker_status/) {
			print "Loading the Backup_status file : $filename......\n";
			open(BKPDATA,"$rawdata_dir/$filename");
			while (my $ln = <BKPDATA>) {
				chomp $ln;
				next if ($ln =~ /^\s*$/);
				next if ($ln =~ /^CELLSRV\=.*?=\s*$/);
				next if ($ln =~ /DATAPROTECTOR:\#Object/);
				next if ($ln =~ /DATAPROTECTOR:\#Cell Manager:/);
				next if ($ln =~ /DATAPROTECTOR:\#Creation Date:/);
				next if ($ln =~ /DATAPROTECTOR:\# Headers/);
				next if ($ln =~ /DATAPROTECTOR:\# Specification      Object Type/);
				next if ($ln =~ /DATAPROTECTOR:\# No object versions matching the search criteria found/);

				##Cell Server
				($bkp_cellsrv = $ln) =~ s/^CELLSRV\=(.*?)\=.*?$/$1/;
				chomp $bkp_cellsrv;
				
				if(defined($bkpsrv_clu_mapping{$bkp_cellsrv}{PACKAGE})){
					$bkp_cellsrv = $bkpsrv_clu_mapping{$bkp_cellsrv}{PACKAGE};
				}

				#COLLECTION-TIMESTAMP: Fri Aug 21 11:27:37 2015 FILESIZE: 632396
				if ($ln =~ /^.*?COLLECTION-TIMESTAMP:(.*?)TICK:(.*?)FILESIZE:(.*?)$/) {
					#print "Collection Time Entry : $ln......\n";
					if ($ln =~ /D2D/) {
						$backup_col{lc($bkp_cellsrv)}{D2D_TIME} = $1;
						$backup_col{lc($bkp_cellsrv)}{D2D_TICK} = $2;
						$backup_col{lc($bkp_cellsrv)}{D2D_SIZE} = $3;
					} else {
						$backup_col{lc($bkp_cellsrv)}{TIME} = $1;
						$backup_col{lc($bkp_cellsrv)}{TICK} = $2;
						$backup_col{lc($bkp_cellsrv)}{SIZE} = $3;
					}
				}

				$ln =~ s/^CELLSRV\=.*\=//;

				$ln =~ s/^\s+//;
				$ln =~ s/,$//;
				$ln =~ s/^\"//;
				$ln =~ s/\"$//;
				#next if($ln !~ /^ARCSERVE/);
				#next if($ln !~ /gvi0atsmx01p.aholdusa.com/i);
				#next if($ln !~ /gvx0lhftm23p/i);
				#print $ln."\n";
				if ($ln =~ /^NETBACKUP/) {
					#NETBACKUP:mabndc411.boral.com.au,1271534,0,3,0,GREY_PROD_APPS_413,Diff-Inc,magrey16.boral.com.au,magrey412,1440147622,0000000257,1440147879,MAGREY414_Disk,1,                               13,1,mabndc411,1183855,15,100
					$ln =~ s/NETBACKUP://;
					$ln = "$bkp_cellsrv,$ln";
					my @nbdata = split(/\,/,$ln);
					#0 for backup
					next if ($nbdata[2] ne 0);
					# 0 for Success
					next if ($nbdata[4] ne 0);
					my $nb_diff_days = sprintf "%d", ($current_tm - $nbdata[9]) / 86400;
					my $nb_bkp_dt = POSIX::strftime("%d-%m-%Y %H:%M:%S", localtime($nbdata[9]));
					my %z = (cell_server => $nbdata[0], job_name => $nbdata[5],
								   backup_type => $nbdata[6], backup_dt => $nb_bkp_dt,
								   storage => $nbdata[12]);
					my @nb_short_name = split (/\./,$nbdata[7]);
					$netbkp_count++;
					if(!(defined($all_bkp_ci{$nbdata[7]}) or defined($all_bkp_shortci{$nb_short_name[0]}))){
						if(defined($bkpsrv_alias_list{$nbdata[7]})){

							@nb_short_name = split (/\./,$bkpsrv_alias_list{$nbdata[7]}{ALIAS});
						}
					}
					push @{$backup_nb{lc($nb_short_name[0])}{METRICS}}, \%z;
					push @{$backup_nb{lc($nb_short_name[0])}{AGE}}, $nb_diff_days;
					$backup_nb{lc($nb_short_name[0])}{CELL_SERVER} = lc($nbdata[0]);
					$backup_col{CELLSERVER_LIST}{lc($nbdata[0])} = 1;
				} elsif ($ln =~ /^TSM:/) {
						#TSMBACKUP:ausydbu002.corp.pri,09/05/2015 22:30:00,09/05/2015 22:33:33,MONTHLY_INCR_02,AUDMZ003_FS_M,Completed
						next if ($ln !~ /Completed/i);
						$ln =~ s/^TSM://;
						$ln = "$bkp_cellsrv,$ln";
						my @tsmdata = split(/\,/,$ln);
						my $tsm_diff_days;
						my ($tsm_dt,$tsm_tm) = split(/\s/,$tsmdata[1]);
						
						if ($tsm_dt =~ /\//) {
							my @tsm_temp = split (/\//,$tsm_dt);
							if ($tsm_temp[2] < 2000) { $tsm_temp[2] += 2000; }
							$tsm_dt = "$tsm_temp[1]/$tsm_temp[0]/$tsm_temp[2]";
							$tsm_diff_days = getDateDiff($tsm_dt);
						}elsif ($tsm_dt =~ /-/) {
							my @tsm_temp = split (/-/,$tsm_dt);
							if ($tsm_temp[0] < 2000) { $tsm_temp[0] += 2000; }
							$tsm_dt = "$tsm_temp[1]/$tsm_temp[2]/$tsm_temp[0]";
							$tsm_diff_days = getDateDiff($tsm_dt);
						} else {$tsm_diff_days = ""; }
						my $tsm_shortname = $tsmdata[4];
						$tsm_shortname =~ s/^(.*?)_(.*?)$/$1/;
						my %tsm_x = (cell_server => $tsmdata[0], backup_type => $tsmdata[3],
												 backup_dt => $tsmdata[2], job_name => $tsmdata[4]);
						push @{$backup_tsm{lc($tsm_shortname)}{METRICS}}, \%tsm_x;
						push @{$backup_tsm{lc($tsm_shortname)}{AGE}}, $tsm_diff_days;
						$backup_tsm{lc($tsm_shortname)}{CELL_SERVER} = lc($tsmdata[0]);
						$backup_col{CELLSERVER_LIST}{lc($tsmdata[0])} = 1;

				} elsif ($ln =~ /^BACKUPEXEC/i) {
							$ln =~ s/^BACKUPEXEC://;
							$ln = "$bkp_cellsrv~$ln";
							my @bedata = split(/~/,$ln);
							my $be_diff_days;
							my $be_dt;
							my $dt_tick;
							if($bedata[7] eq "dpa"){
								next if ($bedata[1] !~ /success/);

								$be_dt = $bedata[3];
								if ($be_dt =~ /\//) {
									my @be_temp = split (/\//,$be_dt);
									if ($be_temp[2] < 2000) { $be_temp[2] += 2000; }
									$be_dt = "$be_temp[1]/$be_temp[0]/$be_temp[2]";
									####$tsm_diff_days = getDateDiff($tsm_dt);
								}

								#$dt_tick = POSIX::strftime("%d/%m/%Y", localtime($bedata[3]));
							}else{
								next if ($bedata[1] !~ /^[19|2|3]/);
								#'19~Job server: TCC-SBBKBK01~Job started: Monday, September 28, 2015 at 7:00:03 AM~Job type: Backup~Job name: TCC-SBBKBK01-WIN-Daily~TCC-SBBKBK01
								$bedata[3] =~ s/Job started: //;
								$bedata[3] =~ s/,//g;
								my $dt_tick;
								my @be_temp = split(/\s/,$bedata[3]);
								if ($be_temp[1] =~ /[a-zA-Z]/) {
									$dt_tick = POSIX::mktime("0","0","0",$be_temp[2],$mons{lc($be_temp[1])},$be_temp[3]-1900);
								} else {
									$dt_tick = POSIX::mktime("0","0","0",$be_temp[1],$mons{lc($be_temp[2])},$be_temp[3]-1900);
								}
								if ($dt_tick > 0) {
									$be_dt = POSIX::strftime("%d/%m/%Y", localtime($dt_tick));
								}
							}
							if ($be_dt ne "") {
								$be_diff_days = getDateDiff($be_dt);
							} else {
								$be_diff_days = "";
							}

							my %be_metrics = (cell_server => $bedata[0], backup_type => $bedata[4],
														  backup_dt => $bedata[3], job_name => $bedata[5], fqdn => $bedata[6], source => $bedata[7]
														  );
							my $be_shortname;
							if ($bedata[6] =~ /\./) {
									my @x = split (/\./,$bedata[6]);
									$be_shortname = $x[0];
							} else {
								  $be_shortname = $bedata[6];
							}
							if(!(defined($all_bkp_ci{$bedata[6]}) or defined($all_bkp_shortci{$be_shortname}))){
								if(defined($bkpsrv_alias_list{$bedata[6]})){
									my @be_short_name = split (/\./,$bkpsrv_alias_list{$bedata[6]}{ALIAS});
									$be_shortname = @be_short_name[0];
								}
							}

							if ($be_shortname eq "") {
								($be_shortname =$bedata[5]) =~ s/Job name:\s(.*?)\s(.*?)$/$1/;
							}
						  push @{$backup_be{lc($be_shortname)}{METRICS}}, \%be_metrics;
						  push @{$backup_be{lc($be_shortname)}{AGE}}, $be_diff_days;
						  $backup_be{lc($be_shortname)}{CELL_SERVER} = lc($bedata[0]);
						  $backup_col{CELLSERVER_LIST}{lc($bedata[0])} = 1;

				} elsif ($ln =~ /^ARCSERVE/i) {
							$ln =~ s/^ARCSERVE://;
							$ln = "$bkp_cellsrv~$ln";
							my @arcdata = split(/~/,$ln);
							my ($arc_diff_days,$arc_dt,$dt_tick,$arc_shortname);
							#client~name~group~files-saved~ssid~date-time~level~sum-size~savetime
							#bqlphpelbur01.boq.bur~index:bqlpmspltrc01.boq.bur~Test~68~51150107~10/01/15 10:23:55~full~816 MB~1443659035
							if ($arcdata[1] =~ /\./) {
									my @x = split (/\./,$arcdata[1]);
									$arc_shortname = $x[0];
							} else {
								  $arc_shortname = $arcdata[1];
							}

							#if(!(defined($all_bkp_ci{$arcdata[1]})) or defined($all_bkp_ci{$arc_shortname})){
							if(!(defined($all_bkp_ci{$arcdata[1]}) or defined($all_bkp_shortci{$arc_shortname}))){
								if(defined($bkpsrv_alias_list{$arcdata[1]})){
									my @arc_short_name = split (/\./,$bkpsrv_alias_list{$arcdata[1]}{ALIAS});
									$arc_shortname = @arc_short_name[0];
								}
							}

							if ($arcdata[9] > 0) {
								$dt_tick = POSIX::strftime("%d/%m/%Y", localtime($arcdata[9]));
							}

							if ($dt_tick ne "") {
								$arc_diff_days = getDateDiff($dt_tick);
							} else {
								$arc_diff_days = "";
							}

							my %arc_metrics = (cell_server => $arcdata[0], fqdn => $arcdata[1],
																 job_name => $arcdata[2], group => $arcdata[3],
																 files_saved => $arcdata[4], ssid => $arcdata[5],
																 backup_dt => $arcdata[6], backup_type => $arcdata[7],
														   backup_size => $arcdata[8]
														  );

						  push @{$backup_arc{lc($arc_shortname)}{METRICS}}, \%arc_metrics;
						  push @{$backup_arc{lc($arc_shortname)}{AGE}}, $arc_diff_days;
						  $backup_arc{lc($arc_shortname)}{CELL_SERVER} = lc($arcdata[0]);
						  $backup_col{CELLSERVER_LIST}{lc($arcdata[0])} = 1;

				} elsif ($ln =~ /^EMCNETWORKER/i) {
							$ln =~ s/^EMCNETWORKER://;
							$ln = "$bkp_cellsrv~$ln";
							my @emcdata = split(/~/,$ln);
							my ($emc_diff_days,$emc_dt,$dt_tick,$emc_shortname);
							#client~name~group~files-saved~ssid~date-time~level~sum-size~savetime
							#bqlphpelbur01.boq.bur~index:bqlpmspltrc01.boq.bur~Test~68~51150107~10/01/15 10:23:55~full~816 MB~1443659035
							if ($emcdata[1] =~ /\./) {
									my @x = split (/\./,$emcdata[1]);
									$emc_shortname = $x[0];
							} else {
								  $emc_shortname = $emcdata[1];
							}

							#if(!(defined($all_bkp_ci{$emcdata[1]})) or defined($all_bkp_ci{$emc_shortname})){
							if(!(defined($all_bkp_ci{$emcdata[1]}) or defined($all_bkp_shortci{$emc_shortname}))){
								if(defined($bkpsrv_alias_list{$emcdata[1]})){
									my @emc_short_name = split (/\./,$bkpsrv_alias_list{$emcdata[1]}{ALIAS});
									$emc_shortname = @emc_short_name[0];
								}
							}

							if ($emcdata[9] > 0) {
								$dt_tick = POSIX::strftime("%d/%m/%Y", localtime($emcdata[9]));
							}

							if ($dt_tick ne "") {
								$emc_diff_days = getDateDiff($dt_tick);
							} else {
								$emc_diff_days = "";
							}

							my %emc_metrics = (cell_server => $emcdata[0], fqdn => $emcdata[1],
																 job_name => $emcdata[2], group => $emcdata[3],
																 files_saved => $emcdata[4], ssid => $emcdata[5],
																 backup_dt => $emcdata[6], backup_type => $emcdata[7],
														   backup_size => $emcdata[8]
														  );

						  push @{$backup_emc{lc($emc_shortname)}{METRICS}}, \%emc_metrics;
						  push @{$backup_emc{lc($emc_shortname)}{AGE}}, $emc_diff_days;
						  $backup_emc{lc($emc_shortname)}{CELL_SERVER} = lc($emcdata[0]);
						  $backup_col{CELLSERVER_LIST}{lc($emcdata[0])} = 1;

				} elsif ($ln =~ /^EMCAVAMAR/i) {
							$ln =~ s/^EMCAVAMAR://;
							$ln = "$bkp_cellsrv~$ln";
							my @emcavmrdata = split(/~/,$ln);
							my ($emcavmr_diff_days,$emcavmr_dt,$dt_tick,$emcavmr_shortname);
							#client~name~group~files-saved~ssid~date-time~level~sum-size~savetime
							#bqlphpelbur01.boq.bur~index:bqlpmspltrc01.boq.bur~Test~68~51150107~10/01/15 10:23:55~full~816 MB~1443659035
							if ($emcavmrdata[1] =~ /\./) {
									my @x = split (/\./,$emcavmrdata[1]);
									$emcavmr_shortname = $x[0];
							} else {
								  $emcavmr_shortname = $emcavmrdata[1];
							}

							if(!(defined($all_bkp_ci{$emcavmrdata[1]}) or defined($all_bkp_shortci{$emcavmr_shortname}))){
								if(defined($bkpsrv_alias_list{$emcavmrdata[1]})){
									my @emcavmr_short_name = split (/\./,$bkpsrv_alias_list{$emcavmrdata[1]}{ALIAS});
									$emcavmr_shortname = @emcavmr_short_name[0];
								}
							}

							if ($emcavmrdata[9] > 0) {
								$dt_tick = POSIX::strftime("%d/%m/%Y", localtime($emcavmrdata[9]));
							}

							if ($dt_tick ne "") {
								$emcavmr_diff_days = getDateDiff($dt_tick);
							} else {
								$emcavmr_diff_days = "";
							}

							my %emcavmr_metrics = (cell_server => $emcavmrdata[0], fqdn => $emcavmrdata[1],
																 job_name => $emcavmrdata[2], group => $emcavmrdata[3],
																 files_saved => $emcavmrdata[4], ssid => $emcavmrdata[5],
																 backup_dt => $emcavmrdata[6], backup_type => $emcavmrdata[7],
														   backup_size => $emcavmrdata[8]
														  );

						  push @{$backup_emcavmr{lc($emcavmr_shortname)}{METRICS}}, \%emcavmr_metrics;
						  push @{$backup_emcavmr{lc($emcavmr_shortname)}{AGE}}, $emcavmr_diff_days;
						  $backup_emcavmr{lc($emcavmr_shortname)}{CELL_SERVER} = lc($emcavmrdata[0]);
						  $backup_col{CELLSERVER_LIST}{lc($emcavmrdata[0])} = 1;

				} elsif ($ln =~ /^COMMVAULT/i) {
							$ln =~ s/^COMMVAULT://;
							$ln = "$bkp_cellsrv~$ln";
							my @commvaultdata = split(/~/,$ln);
							my ($commvault_diff_days,$commvault_dt,$dt_tick,$commvault_shortname);
							#client~name~group~files-saved~ssid~date-time~level~sum-size~savetime
							#bqlphpelbur01.boq.bur~index:bqlpmspltrc01.boq.bur~Test~68~51150107~10/01/15 10:23:55~full~816 MB~1443659035
							if ($commvaultdata[1] =~ /\./) {
									my @x = split (/\./,$commvaultdata[1]);
									$commvault_shortname = $x[0];
							} else {
								  $commvault_shortname = $commvaultdata[1];
							}

							if(!(defined($all_bkp_ci{$commvaultdata[1]}) or defined($all_bkp_shortci{$commvault_shortname}))){
								if(defined($bkpsrv_alias_list{$commvaultdata[1]})){
									my @commvault_short_name = split (/\./,$bkpsrv_alias_list{$commvaultdata[1]}{ALIAS});
									$commvault_shortname = @commvault_short_name[0];
								}
							}

							if ($commvaultdata[9] > 0) {
								$dt_tick = POSIX::strftime("%d/%m/%Y", localtime($commvaultdata[9]));
							}

							if ($dt_tick ne "") {
								$commvault_diff_days = getDateDiff($dt_tick);
							} else {
								$commvault_diff_days = "";
							}

							my %commvault_metrics = (cell_server => $commvaultdata[0], fqdn => $commvaultdata[1],
																 job_name => $commvaultdata[2], group => $commvaultdata[3],
																 files_saved => $commvaultdata[4], ssid => $commvaultdata[5],
																 backup_dt => $commvaultdata[6], backup_type => $commvaultdata[7],
														   backup_size => $commvaultdata[8]
														  );

						  push @{$backup_commvault{lc($commvault_shortname)}{METRICS}}, \%commvault_metrics;
						  push @{$backup_commvault{lc($commvault_shortname)}{AGE}}, $commvault_diff_days;
						  $backup_commvault{lc($commvault_shortname)}{CELL_SERVER} = lc($commvaultdata[0]);
						  $backup_col{CELLSERVER_LIST}{lc($commvaultdata[0])} = 1;

				} elsif ($ln =~ /^DATAPROTECTOR/i) {
					next if ($ln !~ /winfs|filesystem/i);
					$ln =~ s/^DATAPROTECTOR\://;
					$ln = "$bkp_cellsrv\t$ln";
					my (@bkpdata) = split (/\t/,$ln);
					my $age="";
					my $age_incr="";

					my @short_name = split(/\./,$bkpdata[3]);
					if(!(defined($all_bkp_ci{$bkpdata[3]}) or defined($all_bkp_shortci{$short_name[0]}))){
						if(defined($bkpsrv_alias_list{$bkpdata[3]})){
							my @dp_short_name = split (/\./,$bkpsrv_alias_list{$bkpdata[3]}{ALIAS});
							$short_name[0] = @dp_short_name[0];
						}
					}

                    $short_name[0] = lc($short_name[0]);
					if ($bkpdata[0] =~ /kdhcellmgr/i) {
						 $short_name[0] =~ s/_bk//;
					}

					if ($bkpdata[3] =~ /myintra/i) {
						$short_name[0] =~ s/b$//;
					}

                    # this is a kludge
                    # in some data Object Name is present, in others it is not
                    # last full tick will be either in 7 or 8
                    # last incremental either 9 or 10
                    # so we are testing if the field content is a valid tick

                    my $object_name_present;

                    if ($bkpdata[7] =~ /^1\d\d\d\d\d\d\d\d\d$/) {
                        $object_name_present = 0;
                        $age = getTickDiff("$bkpdata[7]");
                    } elsif ($bkpdata[8] =~ /^1\d\d\d\d\d\d\d\d\d$/) {
                        $object_name_present = 1;
                        $age = getTickDiff("$bkpdata[8]");
                    }

                    if ($bkpdata[9] =~ /^1\d\d\d\d\d\d\d\d\d$/) {
                        $age_incr = getTickDiff("$bkpdata[9]");
                    } elsif ($bkpdata[10] =~ /^1\d\d\d\d\d\d\d\d\d$/) {
                        $age_incr = getTickDiff("$bkpdata[10]");
                    }

                    my $x;
                    #l3 expects $cell_srv,$job_name,$mount_point,$last_full_dt,$desc,$object_type,$age,$fqdn,$last_incr_dt,$age_incr,$rec_count
                    if ($object_name_present == 1) {
                        $x = "$bkpdata[0]~~$bkpdata[1]~~$bkpdata[4]~~$bkpdata[7]~~$bkpdata[5]~~$bkpdata[2]~~$age~~$bkpdata[3]~~$bkpdata[9]~~$age_incr~~$#bkpdata";
                    } else {
                        $x = "$bkpdata[0]~~$bkpdata[1]~~$bkpdata[4]~~$bkpdata[6]~~$bkpdata[5]~~$bkpdata[2]~~$age~~$bkpdata[3]~~$bkpdata[8]~~$age_incr~~$#bkpdata";
                    }

					push @{$backup_data{lc($short_name[0])}{METRICS}}, $x;
					push @{$backup_data{lc($short_name[0])}{AGE}}, $age;
					push @{$backup_data{lc($short_name[0])}{AGE_INCR}}, $age_incr;
					$backup_data{lc($short_name[0])}{CELL_SERVER} = $bkpdata[0];
					$backup_col{CELLSERVER_LIST}{lc($bkpdata[0])} = 1;

				} elsif ($ln =~ /^DPA_DATAPROTECTOR/i) {
					
					next if (!($om_status{$bkp_cellsrv}{STATUS} =~ /up/i) and ($om_status{$bkp_cellsrv}{OM_MACH_TYPE} =~ /controlled/i));

					$ln =~ s/^DPA_DATAPROTECTOR\://;
					$ln = "$bkp_cellsrv\t$ln";
					my (@bkpdata) = split (/\t/,$ln);
					my $age="";
					my $age_incr="";

					my @short_name = split(/\./,$bkpdata[3]);
					if(!(defined($all_bkp_ci{$bkpdata[3]}) or defined($all_bkp_shortci{$short_name[0]}))){
						if(defined($bkpsrv_alias_list{$bkpdata[3]})){
							my @dp_short_name = split (/\./,$bkpsrv_alias_list{$bkpdata[3]}{ALIAS});
							$short_name[0] = @dp_short_name[0];
						}
					}

                    $short_name[0] = lc($short_name[0]);
					if ($bkpdata[0] =~ /kdhcellmgr/i) {
						 $short_name[0] =~ s/_bk//;
					}

					if ($bkpdata[3] =~ /myintra/i) {
						$short_name[0] =~ s/b$//;
					}
					$age = getTickDiff("$bkpdata[8]");
					$age_incr = getTickDiff("$bkpdata[8]");

                    my $x;
                    $x = "$bkpdata[0]~~$bkpdata[1]~~$bkpdata[4]~~$bkpdata[7]~~$bkpdata[5]~~$bkpdata[2]~~$age~~$bkpdata[3]~~$bkpdata[7]~~$age_incr~~$#bkpdata";

					push @{$backup_data{lc($short_name[0])}{METRICS}}, $x;
					push @{$backup_data{lc($short_name[0])}{AGE}}, $age;
					push @{$backup_data{lc($short_name[0])}{AGE_INCR}}, $age_incr;
					$backup_data{lc($short_name[0])}{CELL_SERVER} = $bkpdata[0];
					$backup_col{CELLSERVER_LIST}{lc($bkpdata[0])} = 1;

				} elsif ($ln =~ /^D2D_DATAPROTECTOR/i) {
					$ln =~ s/^D2D_DATAPROTECTOR\://;
					$ln = "$bkp_cellsrv\t$ln";
					my (@data) = split (/\t/,$ln);
					my $d2d_age="";
					my ($y,$z) = split(/\s/,$data[5]);
					my @short_name = split(/\./,$data[2]);
					if ($y =~ /\//) {	$d2d_age = getDateDiff($y); } else {$d2d_age = ""; }
					$short_name[0] = lc($short_name[0]);

					my %x = (object_type => $data[1], client => $data[2],
								 mount_point => $data[3], desc => $data[4],
								 date => $data[5], object_copies => $data[6]);
					push @{$omnirpt_d2d{lc($short_name[0])}{METRICS}}, \%x;
					push @{$omnirpt_d2d{lc($short_name[0])}{AGE}}, $d2d_age;
					$omnirpt_d2d{lc($short_name[0])}{CELL_SERVER} = $data[0];
					$d2d_col{CELLSERVER_LIST}{lc($data[0])} = 1;
				}
			}
		}
	}

	save_hash("cache.backup_omnirpt",\%backup_data);
	save_hash("cache.backup_log_collection",\%backup_col);
	save_hash("cache.backup_nbrpt",\%backup_nb);
	save_hash("cache.backup_tsmrpt",\%backup_tsm);
	save_hash("cache.backup_berpt",\%backup_be);
	save_hash("cache.backup_arcrpt",\%backup_arc);
	save_hash("cache.backup_emcrpt",\%backup_emc);
	save_hash("cache.backup_emcavmrrpt",\%backup_emcavmr);
	save_hash("cache.backup_commvaultrpt",\%backup_commvault);
	save_hash("cache.backup_omnirpt_d2d",\%omnirpt_d2d);
}

sub getDateDiff_NewFmt {
	my ($dt) = @_;
	my ($diff_days,$bkp_time);
	my $y;
	if ($dt ne "") {
		my @x = split(/\//,$dt);
		if ($x[2] > 1900) {
			$bkp_time = POSIX::mktime("0","0","0",$x[1],$x[0]-1,$x[2]-1900);
		} else {
			$bkp_time = POSIX::mktime("0","0","0",$x[0],$x[1]-1,$x[2]+100);
		}
		my $current_time = POSIX::time();
		$diff_days = sprintf "%d", ($current_time - $bkp_time) / 86400;
	} else {
		$diff_days = "unknown";
	}
	return $diff_days;
}

sub getDateDiff {
	my ($dt) = @_;
	my ($diff_days,$bkp_time);
	my $y;
	if ($dt ne "") {
		my @x = split(/\//,$dt);
		if ($x[2] > 1900) {
			$bkp_time = POSIX::mktime("0","0","0",$x[0],$x[1]-1,$x[2]-1900);
		} else {
			$bkp_time = POSIX::mktime("0","0","0",$x[1],$x[0]-1,$x[2]+100);
		}
		my $current_time = POSIX::time();
		$diff_days = sprintf "%d", ($current_time - $bkp_time) / 86400;
	} else {
		$diff_days = "unknown";
	}

	if ($diff_days < 0) { $diff_days = getDateDiff_NewFmt($dt); }

	return $diff_days;
}

sub getTickDiff {
	my ($dt) = @_;
	my ($diff_days);
	my $current_time = POSIX::time();
	if ($dt =~ /^\d/) {
		$diff_days = sprintf "%d", ($current_time - $dt) / 86400;
	} else {
		$diff_days = "unknown";
	}
	if ($diff_days > 16734) { $diff_days = ""; }
	return $diff_days;
}

sub process_backup_report {
	my ($x,$y,$a,$b,$cap_type,$ci_type,$c,$d);

	my $omni_count = scalar keys %backup_data;
	foreach my $customer (sort keys %account_reg) {
		next if(!defined $bkpsrv_company{$customer});
		#next if ($customer !~ /campbell soup company|origin energy|glanbia/i);


		my %tools_summary=();
		my $file_name = "$account_reg{$customer}{sp_mapping_file}"."_esl_system_ci_by_fqdn";
		my $l3_filename = "$account_reg{$customer}{sp_mapping_file}"."_tools";

		next if (not -r "$cache_dir/by_customer/$file_name");

		my $sys = load_cache_byFile("$cache_dir/by_customer/$file_name");

		my %esl_system_ci = %{$sys};

		foreach my $center (keys %{$esl_system_ci{$customer}}) {
			foreach my $fqdn (keys %{$esl_system_ci{$customer}{$center}}) {
				my @short_name=();

				my $system_type = $esl_system_ci{$customer}{$center}{$fqdn}{SERVER_TYPE};
				my $os_type = $esl_system_ci{$customer}{$center}{$fqdn}{OS};
				#next if ($system_type !~ /server|cluster node/i);				
				next if ($system_type !~ /$system_type_list/i);

				my $status = $esl_system_ci{$customer}{$center}{$fqdn}{STATUS};
				my $eol_status = $esl_system_ci{$customer}{$center}{$fqdn}{EOL_STATUS};
				my $backup_etp;
				if (exists($esl_system_ci{$customer}{$center}{$fqdn}{ETP})) {
					$backup_etp = $esl_system_ci{$customer}{$center}{$fqdn}{ETP}->{backup};
				}

				my $owner_flag = $esl_system_ci{$customer}{$center}{$fqdn}{OWNER_FLAG} || 0;
				my $ssn_flag = $esl_system_ci{$customer}{$center}{$fqdn}{SSN} || 0;
				my $eso_flag = $esl_system_ci{$customer}{$center}{$fqdn}{ESO4SAP} || 0;

				my $kpe_name = $esl_system_ci{$customer}{$center}{$fqdn}{KPE_NAME};

				my $service_level = $esl_system_ci{$customer}{$center}{$fqdn}{SERVICE_LEVEL};

				my $tax_cap = $esl_system_ci{$customer}{$center}{$fqdn}{OS_INSTANCE_TAX_CAP};


				#next if ($system_type !~ /server|cluster node/i);				
				#next if ($system_type !~ /$system_type_list/i);
				next if ($status !~ /in production|move to production|ALL/i);

				my %teams;
				my %os_class;

				$os_class{ALL}=1;
				$os_class{backup}=1;
				$os_class{$tax_cap} = 1;

				$teams{ALL}=1;

				foreach my $os_instance (keys %{$esl_system_ci{$customer}{$center}{$fqdn}{ESL_ORG_CARD}}) {
					foreach my $esl_o (@{$esl_system_ci{$customer}{$center}{$fqdn}{ESL_ORG_CARD}{$os_instance}}) {
						#if(defined $teams{$esl_o}){
							$teams{$esl_o->{ORG_NM}} = 1;
						#}
						#$cap_class{'windows'} = 1 if ($esl_o->{INSTANCE_NAME} =~ /^win/i);
						#$cap_class{'unix'} = 1 if ($esl_o->{INSTANCE_NAME} =~ /^unix/i);
					}
				}

				foreach my $cap (keys %os_class) {
					foreach my $team (keys %teams) {
						foreach my $owner ('ALL','OWNER','SSN','ESO4SAP_OWNED','ESO4SAP_USES') {
							next if ($center ne "ALL" and $owner ne "OWNER");
							next if ($owner eq "OWNER" and $owner_flag == 0);
							next if ($owner eq "SSN" and ($owner_flag == 0 or $ssn_flag == 0));
							next if ($owner eq "ESO4SAP_OWNED" and ($owner_flag == 0 or $eso_flag == 0));
							next if ($owner eq "ESO4SAP_USES" and ($owner_flag == 1 or $eso_flag == 0));
							#next if ($os_type !~ /win|netware|esx|aix|hp-ux|linux|sol|sun|openvms|nonstop|sco|z\/os|freebsd|vio|unix/i);
							next if ($os_type !~ /$os_type_list/i);


							@short_name = split(/\./,$fqdn);
							if ($esl_system_ci{$customer}{$center}{$fqdn}{ETP}{backup} ne "") {
									push @{$backup_report{'backup_not_required'}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},$fqdn;
									push @{$backup_report{'backup_not_required'}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},$fqdn;
							}elsif (defined($backup_data{lc($short_name[0])})) {
								my @arr_age_full =  @{$backup_data{lc($short_name[0])}{AGE}};
								my @arr_age_incr = @{$backup_data{lc($short_name[0])}{AGE_INCR}};

								my @arr_age;

								foreach my $i (0 .. $#arr_age_full) {
									if ($arr_age_full[$i] eq "") {
										$arr_age[$i] = $arr_age_incr[$i]
									} elsif ($arr_age_incr[$i] eq "") {
										$arr_age[$i] = $arr_age_full[$i];
									} else {
										$arr_age[$i] = min $arr_age_full[$i], $arr_age_incr[$i];
									}
								}

								my $age = max (@arr_age);

								$backup_cell_srv_list{CELL_SERVER}{$customer}{$backup_data{lc($short_name[0])}{CELL_SERVER}}++;

								$backup_report{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}{$fqdn} = $age;
								$backup_report{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}{$fqdn} = $age;
								$backup_report{all_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}{$fqdn} = $age;
								$backup_report{all_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}{$fqdn} = $age;

								if ($age ne '') {
										if ($age < 2) {
											push @{$backup_report{good_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:dataprotector";
											push @{$backup_report{good_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:dataprotector";
										}
										elsif ($age > 1 and $d < 8) {
											push @{$backup_report{amber_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:dataprotector";
											push @{$backup_report{amber_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:dataprotector";
										}
										elsif ($age > 7 and $d < 32) {
											push @{$backup_report{orange_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:dataprotector";
											push @{$backup_report{orange_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:dataprotector";
										}
										elsif ($age > 31) {
											push @{$backup_report{red_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:dataprotector";
											push @{$backup_report{red_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:dataprotector";
										}
								} else {
									push @{$backup_report{no_date}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:dataprotector";
									push @{$backup_report{no_date}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:dataprotector";
								}


							}elsif (defined($backup_nb{lc($short_name[0])})) {
								$x = max (@{$backup_nb{lc($short_name[0])}{AGE}});
								$y = min (@{$backup_nb{lc($short_name[0])}{AGE}});
								if ($y eq "") {
									$c = $x;
								} else {
									$c = $y;
								}
								#DRILLDOWN
								$backup_report{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}{$fqdn} = $c;
								$backup_report{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}{$fqdn} = $c;
								$backup_report{all_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}{$fqdn} = $c;
								$backup_report{all_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}{$fqdn} = $c;

								$backup_cell_srv_list{NB_CELL_SERVER}{$customer}{$backup_nb{lc($short_name[0])}{CELL_SERVER}}++;
								if ($c < 2) {
									push @{$backup_report{good_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:netbackup";
									push @{$backup_report{good_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:netbackup";
								}
								elsif ($c > 1 and $c < 8) {
									push @{$backup_report{amber_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:netbackup";
									push @{$backup_report{amber_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:netbackup";
								}
								elsif ($c > 7 and $c < 32) {
									push @{$backup_report{orange_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:netbackup";
									push @{$backup_report{orange_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:netbackup";
								}
								elsif ($c > 31) {
									push @{$backup_report{red_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:netbackup";
									push @{$backup_report{red_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:netbackup";
								}
								else {
									push @{$backup_report{no_date}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:netbackup";
									push @{$backup_report{no_date}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:netbackup";
								}

							}elsif (defined($backup_tsm{lc($short_name[0])})) {
								$x = max (@{$backup_tsm{lc($short_name[0])}{AGE}});
								$y = min (@{$backup_tsm{lc($short_name[0])}{AGE}});

								if ($y eq "") {
									$c = $x;
								} else {
									$c = $y;
								}
								#DRILLDOWN
								$backup_report{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}{$fqdn} = $c;
								$backup_report{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}{$fqdn} = $c;
								$backup_report{all_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}{$fqdn} = $c;
								$backup_report{all_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}{$fqdn} = $c;

								$backup_cell_srv_list{TSM_CELL_SERVER}{$customer}{$backup_tsm{lc($short_name[0])}{CELL_SERVER}}++;
								if ($c < 2) {
									push @{$backup_report{good_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:tsm";
									push @{$backup_report{good_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:tsm";
								}
								elsif ($c > 1 and $c < 8) {
									push @{$backup_report{amber_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:tsm";
									push @{$backup_report{amber_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:tsm";
								}
								elsif ($c > 7 and $c < 32) {
									push @{$backup_report{orange_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:tsm";
									push @{$backup_report{orange_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:tsm";
								}
								elsif ($c > 31) {
									push @{$backup_report{red_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:tsm";
									push @{$backup_report{red_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:tsm";
								}
								else {
									push @{$backup_report{no_date}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:tsm";
									push @{$backup_report{no_date}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:tsm";
								}

							} elsif (defined($backup_be{lc($short_name[0])})) {
								$x = max (@{$backup_be{lc($short_name[0])}{AGE}});
								$y = min (@{$backup_be{lc($short_name[0])}{AGE}});

								if ($y eq "") {
									$c = $x;
								} else {
									$c = $y;
								}
								#DRILLDOWN
								$backup_report{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}{$fqdn} = $c;
								$backup_report{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}{$fqdn} = $c;
								$backup_report{all_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}{$fqdn} = $c;
								$backup_report{all_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}{$fqdn} = $c;

								$backup_cell_srv_list{BE_CELL_SERVER}{$customer}{$backup_be{lc($short_name[0])}{CELL_SERVER}}++;
								if ($c < 2) {
									push @{$backup_report{good_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:be";
									push @{$backup_report{good_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:be";
								}
								elsif ($c > 1 and $c < 8) {
									push @{$backup_report{amber_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:be";
									push @{$backup_report{amber_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:be";
								}
								elsif ($c > 7 and $c < 32) {
									push @{$backup_report{orange_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:be";
									push @{$backup_report{orange_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:be";
								}
								elsif ($c > 31) {
									push @{$backup_report{red_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:be";
									push @{$backup_report{red_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:be";
								}
								else {
									push @{$backup_report{no_date}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:be";
									push @{$backup_report{no_date}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:be";
								}
							} elsif (defined($backup_arc{lc($short_name[0])})) {
								$x = max (@{$backup_arc{lc($short_name[0])}{AGE}});
								$y = min (@{$backup_arc{lc($short_name[0])}{AGE}});

								if ($y eq "") {
									$c = $x;
								} else {
									$c = $y;
								}
								#DRILLDOWN
								$backup_report{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}{$fqdn} = $c;
								$backup_report{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}{$fqdn} = $c;
								$backup_report{all_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}{$fqdn} = $c;
								$backup_report{all_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}{$fqdn} = $c;

								$backup_cell_srv_list{ARCSERVE_CELL_SERVER}{$customer}{$backup_arc{lc($short_name[0])}{CELL_SERVER}}++;
								if ($c < 2) {
									push @{$backup_report{good_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:arc";
									push @{$backup_report{good_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:arc";
								}
								elsif ($c > 1 and $c < 8) {
									push @{$backup_report{amber_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:arc";
									push @{$backup_report{amber_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:arc";
								}
								elsif ($c > 7 and $c < 32) {
									push @{$backup_report{orange_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:arc";
									push @{$backup_report{orange_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:arc";
								}
								elsif ($c > 31) {
									push @{$backup_report{red_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:arc";
									push @{$backup_report{red_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:arc";
								}
								else {
									push @{$backup_report{no_date}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:arc";
									push @{$backup_report{no_date}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:arc";
								}
							} elsif (defined($backup_emc{lc($short_name[0])})) {
								$x = max (@{$backup_emc{lc($short_name[0])}{AGE}});
								$y = min (@{$backup_emc{lc($short_name[0])}{AGE}});

								if ($y eq "") {
									$c = $x;
								} else {
									$c = $y;
								}
								#DRILLDOWN
								$backup_report{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}{$fqdn} = $c;
								$backup_report{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}{$fqdn} = $c;
								$backup_report{all_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}{$fqdn} = $c;
								$backup_report{all_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}{$fqdn} = $c;

								$backup_cell_srv_list{EMC_CELL_SERVER}{$customer}{$backup_emc{lc($short_name[0])}{CELL_SERVER}}++;
								if ($c < 2) {
									push @{$backup_report{good_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:emc";
									push @{$backup_report{good_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:emc";
								}
								elsif ($c > 1 and $c < 8) {
									push @{$backup_report{amber_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:emc";
									push @{$backup_report{amber_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:emc";
								}
								elsif ($c > 7 and $c < 32) {
									push @{$backup_report{orange_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:emc";
									push @{$backup_report{orange_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:emc";
								}
								elsif ($c > 31) {
									push @{$backup_report{red_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:emc";
									push @{$backup_report{red_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:emc";
								}
								else {
									push @{$backup_report{no_date}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:emc";
									push @{$backup_report{no_date}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:emc";
								}
							} elsif (defined($backup_emcavmr{lc($short_name[0])})) {
								$x = max (@{$backup_emcavmr{lc($short_name[0])}{AGE}});
								$y = min (@{$backup_emcavmr{lc($short_name[0])}{AGE}});

								if ($y eq "") {
									$c = $x;
								} else {
									$c = $y;
								}
								#DRILLDOWN
								$backup_report{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}{$fqdn} = $c;
								$backup_report{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}{$fqdn} = $c;
								$backup_report{all_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}{$fqdn} = $c;
								$backup_report{all_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}{$fqdn} = $c;

								$backup_cell_srv_list{EMC_AVAMAR_CELL_SERVER}{$customer}{$backup_emcavmr{lc($short_name[0])}{CELL_SERVER}}++;
								if ($c < 2) {
									push @{$backup_report{good_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:emcavmr";
									push @{$backup_report{good_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:emcavmr";
								}
								elsif ($c > 1 and $c < 8) {
									push @{$backup_report{amber_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:emcavmr";
									push @{$backup_report{amber_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:emcavmr";
								}
								elsif ($c > 7 and $c < 32) {
									push @{$backup_report{orange_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:emcavmr";
									push @{$backup_report{orange_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:emcavmr";
								}
								elsif ($c > 31) {
									push @{$backup_report{red_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:emcavmr";
									push @{$backup_report{red_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:emcavmr";
								}
								else {
									push @{$backup_report{no_date}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:emcavmr";
									push @{$backup_report{no_date}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:emcavmr";
								}

							} elsif (defined($backup_commvault{lc($short_name[0])})) {
								$x = max (@{$backup_commvault{lc($short_name[0])}{AGE}});
								$y = min (@{$backup_commvault{lc($short_name[0])}{AGE}});

								if ($y eq "") {
									$c = $x;
								} else {
									$c = $y;
								}
								#DRILLDOWN
								$backup_report{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}{$fqdn} = $c;
								$backup_report{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}{$fqdn} = $c;
								$backup_report{all_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}{$fqdn} = $c;
								$backup_report{all_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}{$fqdn} = $c;

								$backup_cell_srv_list{COMMVAULT_CELL_SERVER}{$customer}{$backup_commvault{lc($short_name[0])}{CELL_SERVER}}++;
								if ($c < 2) {
									push @{$backup_report{good_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:commvault";
									push @{$backup_report{good_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:commvault";
								}
								elsif ($c > 1 and $c < 8) {
									push @{$backup_report{amber_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:commvault";
									push @{$backup_report{amber_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:commvault";
								}
								elsif ($c > 7 and $c < 32) {
									push @{$backup_report{orange_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:commvault";
									push @{$backup_report{orange_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:commvault";
								}
								elsif ($c > 31) {
									push @{$backup_report{red_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:commvault";
									push @{$backup_report{red_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:commvault";
								}
								else {
									push @{$backup_report{no_date}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},"$fqdn:commvault";
									push @{$backup_report{no_date}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},"$fqdn:commvault";
								}

							}  else {
									$backup_report{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}{$fqdn} = "No Backup";
									$backup_report{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}{$fqdn} = "No Backup";
									push @{$backup_report{no_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}},$fqdn;
									push @{$backup_report{no_backup}{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}},$fqdn;
							}
						}
					}
				}
			}
		}
	}
	save_hash("cache.backup_report",\%backup_report);
	save_hash("cache.backup_cell_srv_list",\%backup_cell_srv_list);
}

sub process_backup_d2d_report {
   my ($allci) = @_;
   my ($x,$y,$a,$b,$cap_type,$ci_type,$c,$d);
   my ($customer,$fqdn);

	foreach my $customer (sort keys %account_reg) {
		###next if ($account_reg{$customer}{oc_region} !~ /anz|amea|asia|ukiimea/i);
		#next if ($customer ne "origin energy");
		#next if ($customer !~ /ahold/i);

		my %tools_summary=();
		my $file_name = "$account_reg{$customer}{sp_mapping_file}"."_esl_system_ci_by_fqdn";
		my $l3_filename = "$account_reg{$customer}{sp_mapping_file}"."_tools";

		next if (not -r "$cache_dir/by_customer/$file_name");

		my $sys = load_cache_byFile("$cache_dir/by_customer/$file_name");

		my %esl_system_ci = %{$sys};

		foreach my $center (keys %{$esl_system_ci{$customer}}) {
			foreach my $fqdn (keys %{$esl_system_ci{$customer}{$center}}) {
				my @short_name=();

				if ($esl_system_ci{$customer}{$center}{$fqdn}{OS} =~ /win|netware|esx/i) {
					$cap_type ="wintel";
				} elsif ($esl_system_ci{$customer}{$center}{$fqdn}{OS} =~ /aix|hp-ux|linux|sol|sun|openvms|nonstop|sco|z\/os|freebsd|vio/) {
					$cap_type ="unix";
				} else {
					$cap_type ="not_defined";
				}

				next if ($cap_type !~ /wintel|unix/i);
				my $ci_type = $esl_system_ci{$customer}{$center}{$fqdn}{STATUS};

				@short_name = split(/\./,$fqdn);
				if (defined($omnirpt_d2d{lc($short_name[0])})){
					$x = max (@{$omnirpt_d2d{lc($short_name[0])}{AGE}});
					$y = min (@{$omnirpt_d2d{lc($short_name[0])}{AGE}});

					if ($y eq "") {
						$c = $x;
					} else {
						$c = $y;
					}

					$d2d_report{CELL_SERVER}{$customer}{$omnirpt_d2d{lc($short_name[0])}{CELL_SERVER}}++;

					if ($c ne "") {
						$d2d_report{$customer}{$cap_type}{$ci_type}{$fqdn} = $c;
						$d2d_report{all_backup}{$customer}{$cap_type}{$ci_type}{$fqdn} = $c;

						if ($c < 2) { push @{$d2d_report{good_backup}{$customer}{$cap_type}{$ci_type}},"$fqdn:dataprotector"; }
						elsif ($c > 1 and $c < 8) {push @{$d2d_report{amber_backup}{$customer}{$cap_type}{$ci_type}},"$fqdn:dataprotector"; }
						elsif ($c > 7 and $c < 32) {push @{$d2d_report{orange_backup}{$customer}{$cap_type}{$ci_type}},"$fqdn:dataprotector"; }
						elsif ($c > 31) {push @{$d2d_report{red_backup}{$customer}{$cap_type}{$ci_type}},"$fqdn:dataprotector"; }
					}
				}
			}
		}
	}
}

sub get_backup_cell_server {
	my ($customer,$backup_report,$backup_cell_srv_list,$backup_cellsrv,$backup_col,$center, $cap, $team, $status, $eol_status, $owner)=@_;

	my $cell_servers=0;
	my $cell_servers_omnirpt=0;
	my $dp_rpt=0;
	my $nb=0;
	my $nb_rpt=0;
	my $be=0;
	my $be_rpt=0;
	my $tsm=0;
	my $tsm_rpt=0;
	my $arc=0;
	my $arc_rpt=0;
	my $emc=0;
	my $emc_rpt=0;
	my $emcavmr=0;
	my $emcavmr_rpt=0;
	my $commvault=0;
	my $commvault_rpt=0;
	my @data = ('dataprotector server','netbackup','tsm','arcserve','backupexec','emc networker server','emc avamar server','commvault server');
	my @sys_status = ('in production','move to production');
	foreach my $cell_type (@data) {
		foreach my $sys_status_Type (@sys_status) {
			if ($cell_type =~ /dataprotector/i) {
				eval {$cell_servers= scalar @{$backup_cellsrv->{$customer}{$center}{$cap}{$team}{$sys_status_Type}{$eol_status}{$owner}{$cell_type}}+$cell_servers;};
				my $data_collection=0;
				if ($cell_servers > 0) {
					#Only required for dataprotector
					$cell_servers_omnirpt = scalar keys %{$backup_cell_srv_list->{CELL_SERVER}{$customer}};
					if ($cell_servers_omnirpt > $cell_servers) {
						$cell_servers = $cell_servers_omnirpt;
						foreach my $ln (sort keys %{$backup_report->{CELL_SERVER}{$customer}}) {
							if ($backup_col->{CELLSERVER_LIST}{lc($ln)} eq 1) { $dp_rpt++; }
							elsif ($backup_cell_srv_list->{CELL_SERVER}{$customer}{lc($ln)} > 0) { $dp_rpt++; }
							elsif ($backup_col->{lc($ln)}{TIME}) { $dp_rpt++; }
						}
					}else{
						foreach my $ln (@{$backup_cellsrv->{$customer}{$center}{$cap}{$team}{$sys_status_Type}{$eol_status}{$owner}{$cell_type}}) {
							if ($backup_col->{CELLSERVER_LIST}{lc($ln)} eq 1) { $dp_rpt++; }
							elsif ($backup_cell_srv_list->{CELL_SERVER}{$customer}{lc($ln)} > 0) { $dp_rpt++; }
							elsif ($backup_col->{lc($ln)}{TIME}) { $dp_rpt++; }
						}
					}
				}
			} elsif ($cell_type =~ /netbackup/i) {
				eval {$nb = scalar @{$backup_cellsrv->{$customer}{$center}{$cap}{$team}{$sys_status_Type}{$eol_status}{$owner}{'netbackup server'}}+$nb;};
				if ($nb > 0) {
					foreach my $ln (@{$backup_cellsrv->{$customer}{$center}{$cap}{$team}{$sys_status_Type}{$eol_status}{$owner}{'netbackup server'}}) {
						if ($backup_col->{CELLSERVER_LIST}{lc($ln)}) {$nb_rpt++; }
						elsif ($backup_cell_srv_list->{NB_CELL_SERVER}{$customer}{$ln} > 0) { $nb_rpt++; }
						elsif ($backup_col->{lc($ln)}{TIME}) { $nb_rpt++; }
					}
				}
			} elsif ($cell_type =~ /tsm/i) {
				eval {$tsm = scalar @{$backup_cellsrv->{$customer}{$center}{$cap}{$team}{$sys_status_Type}{$eol_status}{$owner}{'tsm server'}}+$tsm;};
				if ($tsm > 0) {
					foreach my $ln (@{$backup_cellsrv->{$customer}{$center}{$cap}{$team}{$sys_status_Type}{$eol_status}{$owner}{'tsm server'}}) {
						if ($backup_col->{CELLSERVER_LIST}{lc($ln)}) {$tsm_rpt++; }
						elsif ($backup_cell_srv_list->{TSM_CELL_SERVER}{$customer}{$ln} > 0) { $tsm_rpt++; }
						elsif ($backup_col->{lc($ln)}{TIME}) { $tsm_rpt++; }
					}
				}
			} elsif ($cell_type =~ /backupexec/i) {
				eval {$be = scalar @{$backup_cellsrv->{$customer}{$center}{$cap}{$team}{$sys_status_Type}{$eol_status}{$owner}{'backup exec server'}}+$be;};
				if ($be > 0) {
					foreach my $ln (@{$backup_cellsrv->{$customer}{$center}{$cap}{$team}{$sys_status_Type}{$eol_status}{$owner}{'backup exec server'}}) {
						if ($backup_col->{CELLSERVER_LIST}{lc($ln)}) { $be_rpt++; }
						elsif ($backup_cell_srv_list->{BE_CELL_SERVER}{$customer}{$ln} > 0) { $be_rpt++; }
						elsif ($backup_col->{lc($ln)}{TIME}) { $be_rpt++; }
					}
				}
			} elsif ($cell_type =~ /arcserve/i) {
				#eval {$arc = scalar @{$backup_cellsrv->{$customer}{$center}{$cap}{$team}{$sys_status_Type}{$eol_status}{$owner}{arcserve}};};
				eval {$arc = scalar @{$backup_cellsrv->{$customer}{$center}{$cap}{$team}{$sys_status_Type}{$eol_status}{$owner}{'arcserve'}}+$arc;};
				if ($arc > 0) {
					foreach my $ln (@{$backup_cellsrv->{$customer}{$center}{$cap}{$team}{$sys_status_Type}{$eol_status}{$owner}{'arcserve'}}) {
						if ($backup_col->{CELLSERVER_LIST}{lc($ln)}) { $arc_rpt++; }
						elsif ($backup_cell_srv_list->{ARCSERVE_CELL_SERVER}{$customer}{$ln} > 0) { $arc_rpt++; }
						elsif ($backup_col->{lc($ln)}{TIME}) { $arc_rpt++; }
					}
				}
			} elsif ($cell_type =~ /emc networker/i) {
				eval {$emc = scalar @{$backup_cellsrv->{$customer}{$center}{$cap}{$team}{$sys_status_Type}{$eol_status}{$owner}{'emc networker server'}}+$emc;};
				if ($emc > 0) {
					foreach my $ln (@{$backup_cellsrv->{$customer}{$center}{$cap}{$team}{$sys_status_Type}{$eol_status}{$owner}{'emc networker server'}}) {
						if ($backup_col->{CELLSERVER_LIST}{lc($ln)}) { $emc_rpt++; }
						elsif ($backup_cell_srv_list->{EMC_CELL_SERVER}{$customer}{$ln} > 0) { $emc_rpt++; }
						elsif ($backup_col->{lc($ln)}{TIME}) { $emc_rpt++; }
					}
				}
			} elsif ($cell_type =~ /emc avamar/i) {
				eval {$emcavmr = scalar @{$backup_cellsrv->{$customer}{$center}{$cap}{$team}{$sys_status_Type}{$eol_status}{$owner}{'emc avamar server'}}+$emcavmr;};
				if ($emcavmr > 0) {
					foreach my $ln (@{$backup_cellsrv->{$customer}{$center}{$cap}{$team}{$sys_status_Type}{$eol_status}{$owner}{'emc avamar server'}}) {
						if ($backup_col->{CELLSERVER_LIST}{lc($ln)}) { $emcavmr_rpt++; }
						elsif ($backup_cell_srv_list->{EMC_AVAMAR_CELL_SERVER}{$customer}{$ln} > 0) { $emcavmr_rpt++; }
						elsif ($backup_col->{lc($ln)}{TIME}) { $emcavmr_rpt++; }
					}
				}
			} elsif ($cell_type =~ /commvault/i) {
				eval {$commvault = scalar @{$backup_cellsrv->{$customer}{$center}{$cap}{$team}{$sys_status_Type}{$eol_status}{$owner}{'commvault server'}}+$commvault;};
				if ($commvault > 0) {
					foreach my $ln (@{$backup_cellsrv->{$customer}{$center}{$cap}{$team}{$sys_status_Type}{$eol_status}{$owner}{'commvault server'}}) {
						if ($backup_col->{CELLSERVER_LIST}{lc($ln)}) { $commvault_rpt++; }
						elsif ($backup_cell_srv_list->{COMMVAULT_CELL_SERVER}{$customer}{$ln} > 0) { $commvault_rpt++; }
						elsif ($backup_col->{lc($ln)}{TIME}) { $commvault_rpt++; }
					}
				}
			}
		}
	}

	  my %x = ('total_cell_server' => $cell_servers, 'cell_server_working' => $dp_rpt,
	  				 'nb' => $nb, 'nb_rpt' => $nb_rpt,
	  				 'be' =>$be, 'be_rpt' => $be_rpt,
	  				 'tsm' =>$tsm, 'tsm_rpt' => $tsm_rpt,
	  				 'arc' =>$arc, 'arc_rpt' => $arc_rpt,
	  				 'emc' =>$emc, 'emc_rpt' => $emc_rpt,
	  				 'emcavmr' =>$emcavmr, 'emcavmr_rpt' => $emcavmr_rpt,
	  				 'commvault' =>$commvault, 'commvault_rpt' => $commvault_rpt);

		return \%x;

}

sub get_backup_rollup {
	my ($customer, $center, $cap, $team, $status, $eol_status, $owner, $fqdn, $platform,$type, $backup_report) = @_;

	my $no_backup=0;
	my $no_date=0;
	my $good_backup=0;
	my $amber_backup=0;
	my $orange_backup=0;
	my $red_backup=0;
	my $etp=0;
	#####my @cap = ('wintel','unix');
	#####foreach my $capability (@cap) {
	eval {if (scalar @{$backup_report->{good_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}} > 0) { $good_backup += scalar @{$backup_report->{good_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}}; } };

	eval {if (scalar @{$backup_report->{amber_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}} > 0) { $amber_backup += scalar @{$backup_report->{amber_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}}; } };

	eval {if (scalar @{$backup_report->{orange_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}} > 0) { $orange_backup += scalar @{$backup_report->{orange_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}}; } };

	eval {if (scalar @{$backup_report->{red_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}} > 0) { $red_backup += scalar @{$backup_report->{red_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}}; } };

	eval {if (scalar @{$backup_report->{no_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}} > 0) { $no_backup += scalar @{$backup_report->{no_backup}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}}; } };

	eval {if (scalar @{$backup_report->{no_date}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}} > 0) { $no_date += scalar @{$backup_report->{no_date}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}}; } };

	eval {if (scalar @{$backup_report->{'backup_not_required'}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}} > 0) { $etp += scalar @{$backup_report->{'backup_not_required'}{$customer}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}}; } };
	#####}
	my %x = (no_backup => $no_backup,no_date => $no_date, good_backup => $good_backup,
	amber_backup => $amber_backup, orange_backup => $orange_backup, red_backup => $red_backup, etp => $etp);
	return \%x;
}

sub get_raw_logs
{
	my ($file_name) = @_;

	my %reg;
	foreach my $om (@om_servers) {

		if ($om =~ /^\s*(http.*)\:\/\/(.*?)\:(\d+)(.*)$/) {
			my $protocol = $1;
			my $t1_server = $2;
			my $port = $3;
			my $creds = $4;
			my ($user, $pass);

			if ($creds ne "") {
				($user, $pass) = (split(/\|/, $creds))[1,2];
			}
			##Collect only for specific region
			next if ($t1_region !~ /$t1_server/i);

			print "Getting raw log $file_name\n";
			print "Customer is Serviced by T1 server ($t1_server) to be communicated using Protocol ($protocol) on Port ($port).  Using User=$user\n";

			my $ua = LWP::UserAgent->new();
			$ua->credentials("$t1_server:$port", "Authentication required", $user, $pass);

			my $uri = "$protocol://$t1_server:$port/ITO_OP/ui4/$file_name";

			print "Attempting to get $file_name using URI $uri and saving to $rawdata_dir/$file_name\n";

			my $res = $ua->get($uri, ':content_file' => "$rawdata_dir/${t1_server}_${file_name}");

			if (-f "$rawdata_dir/${t1_server}_${file_name}") {
				system("gunzip -f $rawdata_dir/${t1_server}_${file_name}");
			}
		}
	}
}

sub get_bkpsrvalias_list
{
	open ALIAS, '<', "$rawdata_dir/esl.SystemBkpAliases" or die "$0: Cannot open $rawdata_dir/esl.SystemBkpAliases: $!\n";

	while (my $ln = <ALIAS>) {

        chomp $ln;

		my ($fqdn, $system_type, $ip_type, $ip_name) = split /~~~/, $ln;

        $bkpsrv_alias_list{$ip_name}{ALIAS} = $fqdn;
	}
}

sub get_bkpsrv_clu_mapping
{
	open MAPPING, '<', "$rawdata_dir/esl.bkp_clu_mapping" or die "$0: Cannot open $rawdata_dir/esl.bkp_clu_mapping: $!\n";

	while (my $ln = <MAPPING>) {

        chomp $ln;

		my ($clu_pkg, $clu_node_pri, $clu_node_alt) = split /\t/, $ln;

        $bkpsrv_clu_mapping{$clu_pkg}{PRIMARY} = $clu_node_pri;
        $bkpsrv_clu_mapping{$clu_pkg}{ALTERNATE} = $clu_node_alt;
        $bkpsrv_clu_mapping{$clu_node_pri}{PACKAGE} = $clu_pkg;
        $bkpsrv_clu_mapping{$clu_node_alt}{PACKAGE} = $clu_pkg;
	}
}

sub get_bkpsrv_list_local
{
	my %x;

	my @list1 = ('etp');
	my %cache1 = load_cache(\@list1);
	my %etp_bkp = %{$cache1{etp}};

	my $business;
	my %cached_company;
	my ($fqdn,$account,$sub_business,$status,$server_type,$os,$impact,$a_group,$version,$instance_status,$instance_service_level);
	open(my $fh,'<',"$rawdata_dir/esl.bkpsrv_list");
	while (my $ln = <$fh>) {
		chomp $ln;
		next if ($ln =~ /^\s*$/);
		($fqdn,$account,$sub_business,$status,$server_type,$os,$impact,$a_group,$version,$instance_status,$instance_service_level) = split(/~/,$ln);

		# To improve the performance
		if (defined($cached_company{$account}{$sub_business})) {
			$business = $cached_company{$account}{$sub_business};
		} else {
			$business = map_customer_to_sp(\%account_reg,$account,$sub_business,"ESL");
			$cached_company{$account}{$sub_business} = $business;
		}

		$bkpsrv_company{$business}{$fqdn}{SERVER_TYPE} = $server_type;
		$bkpsrv_company{$business}{$fqdn}{INSTANCE_STATUS} = $instance_status;
		$bkpsrv_company{$business}{$fqdn}{INSTANCE_SERVICE_LEVEL} = $instance_service_level;
	}
	my $i;
	foreach my $customer (sort keys %bkpsrv_company) {

		#next if ($customer !~ /origin energy/i);
		#next if ($customer !~ /ahold/i);
		my $file_name = "$account_reg{$customer}{sp_mapping_file}"."_esl_system_ci_by_fqdn";
		next if (not -r "$cache_dir/by_customer/$file_name");
		my $sys = load_cache_byFile("$cache_dir/by_customer/$file_name");
		my %esl_system_ci = %{$sys};
		foreach my $bkpfqdn (keys %{$bkpsrv_company{$customer}}) {
			$server_type = $bkpsrv_company{$customer}{$bkpfqdn}{SERVER_TYPE};
			$instance_status = $bkpsrv_company{$customer}{$bkpfqdn}{INSTANCE_STATUS};
			$instance_service_level = $bkpsrv_company{$customer}{$bkpfqdn}{INSTANCE_SERVICE_LEVEL};
			foreach my $center (keys %{$esl_system_ci{$customer}}) {
				foreach my $cellmgr (keys %{$esl_system_ci{$customer}{$center}}) {
					next if ($cellmgr ne $bkpfqdn);
					my $system_type = $esl_system_ci{$customer}{$center}{$cellmgr}{SERVER_TYPE};
					my $os_type = $esl_system_ci{$customer}{$center}{$bkpfqdn}{OS};

					my $status = $esl_system_ci{$customer}{$center}{$cellmgr}{STATUS};
					my $eol_status = $esl_system_ci{$customer}{$center}{$cellmgr}{EOL_STATUS};
					my $backup_etp;
					if (exists($esl_system_ci{$customer}{$center}{$cellmgr}{ETP})) {
						$backup_etp = $esl_system_ci{$customer}{$center}{$cellmgr}{ETP}->{backup};
					}

					my $owner_flag = $esl_system_ci{$customer}{$center}{$cellmgr}{OWNER_FLAG} || 0;
					my $ssn_flag = $esl_system_ci{$customer}{$center}{$cellmgr}{SSN} || 0;
					my $eso_flag = $esl_system_ci{$customer}{$center}{$cellmgr}{ESO4SAP} || 0;

					my $kpe_name = $esl_system_ci{$customer}{$center}{$cellmgr}{KPE_NAME};

					my $service_level = $esl_system_ci{$customer}{$center}{$cellmgr}{SERVICE_LEVEL};

					my $tax_cap = $esl_system_ci{$customer}{$center}{$cellmgr}{OS_INSTANCE_TAX_CAP};

					my %teams;
					my %os_class;

					$os_class{ALL}=1;
					$os_class{backup}=1;
					$os_class{$tax_cap} = 1;

					$teams{ALL}=1;

					foreach my $os_instance (keys %{$esl_system_ci{$customer}{$center}{$cellmgr}{ESL_ORG_CARD}}) {
						foreach my $esl_o (@{$esl_system_ci{$customer}{$center}{$cellmgr}{ESL_ORG_CARD}{$os_instance}}) {
							if(defined $teams{$esl_o}){
								$teams{$esl_o->{ORG_NM}} = 1;
							}
							#$cap_class{'windows'} = 1 if ($esl_o->{INSTANCE_NAME} =~ /^win/i);
							#$cap_class{'unix'} = 1 if ($esl_o->{INSTANCE_NAME} =~ /^unix/i);
						}
					}

					foreach my $cap (keys %os_class) {
						foreach my $team (keys %teams) {
							foreach my $owner ('ALL','OWNER','SSN','ESO4SAP_OWNED','ESO4SAP_USES') {
								next if ($center ne "ALL" and $owner ne "OWNER");
								next if ($owner eq "OWNER" and $owner_flag == 0);
								next if ($owner eq "SSN" and ($owner_flag == 0 or $ssn_flag == 0));
								next if ($owner eq "ESO4SAP_OWNED" and ($owner_flag == 0 or $eso_flag == 0));
								next if ($owner eq "ESO4SAP_USES" and ($owner_flag == 1 or $eso_flag == 0));

								#next if ($os_type !~ /win|netware|esx|aix|hp-ux|linux|sol|sun|openvms|nonstop|sco|z\/os|freebsd|vio|unix/i);
								next if ($os_type !~ /$os_type_list/i);

								my $backup_etp = "";
								if(exists($etp_bkp{$customer}{$bkpfqdn})) {
									$backup_etp = $etp_bkp{$customer}{$bkpfqdn}->{monitoring};
								}
								next if($backup_etp ne "");
								####next if($instance_status !~  /in production|move to production|delivered|installed in dc|null/i);
								####next if($instance_service_level =~  /not supported/i);

								if(defined($bkpsrv_clu_mapping{$bkpfqdn}{PACKAGE})){
									$bkpfqdn = $bkpsrv_clu_mapping{$bkpfqdn}{PACKAGE};
								}
								if(!defined($bkpsrv_clu_mapping{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}{$server_type}{$bkpfqdn})){
									#push @{$cellsrv{lc($business)}{$server_type}}, $bkpfqdn;
									push @{$cellsrv{lc($customer)}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}{$server_type}}, $bkpfqdn;
									push @{$cellsrv{lc($customer)}{$center}{$cap}{$team}{$status}{ALL}{$owner}{$server_type}}, $bkpfqdn;
									$bkpsrv_clu_mapping{$customer}{$center}{$cap}{$team}{$status}{ALL}{$owner}{$server_type}{$bkpfqdn}{COUNT}++;
								}
								####push @{$cellsrv{lc($customer)}{$center}{$cap}{$team}{$status}{$eol_status}{$owner}{$server_type}}, $bkpfqdn;
								####push @{$cellsrv{lc($customer)}{$center}{$cap}{$team}{$status}{ALL}{$owner}{$server_type}}, $bkpfqdn;

							}#owner
						}#team
					}#Cap

				} #FQDN / CellMgr
			} # CENTER
		}
		$i++;
	}
	#}

	#save_hash("cache.bpksrv_2",\%bkpsrv_list);
	save_hash("cache.backup_cellsrv_2",\%cellsrv);
	#undef %bkpsrv_list;
	undef %cellsrv;
}



sub create_l2_backup_cache {

	foreach my $customer (sort keys %account_reg) {
		next if(!defined $bkpsrv_company{$customer});
		my $all_ci = 0;
		###next if ($account_reg{$customer}{sp_region} ne 'apj');
		###next if ($account_reg{$customer}{oc_region} !~ /anz|amea|asia|ukiimea/i);
		#next if ($customer !~ /campbell soup company|origin energy|glanbia/i);
		#next if ($customer !~ /ahold/i);
		my %tools_summary=();
		my $file_name = "$account_reg{$customer}{sp_mapping_file}"."_esl_system_ci_by_fqdn";
		my $l3_filename = "$account_reg{$customer}{sp_mapping_file}"."_tools";

		next if (not -r "$cache_dir/by_customer/$file_name");

		my $sys = load_cache_byFile("$cache_dir/by_customer/$file_name");

		my %esl_system_ci = %{$sys};

		my $backup_etp;
		my $total_etp;
		my $all_ci;
		my $total_ci_etp;

		my $total_etp_all;
		my $all_ci_all;
		my $total_ci_etp_all;

		my $dc_srv = get_backup_cell_server($customer,\%backup_report,\%backup_cell_srv_list,\%backup_cellsrv,\%backup_col,"ALL", "ALL", "ALL", "in production", "ALL", "ALL");

		my $dc_srv_all = get_backup_cell_server($customer,\%backup_report,\%backup_cell_srv_list,\%backup_cellsrv,\%backup_col,"ALL", "ALL", "ALL", "in production", "ALL", "ALL");

		foreach my $center (keys %{$esl_system_ci{$customer}}) {
			foreach my $fqdn (keys %{$esl_system_ci{$customer}{$center}}) {
				my $system_type = $esl_system_ci{$customer}{$center}{$fqdn}{SERVER_TYPE};
				my $os_type = $esl_system_ci{$customer}{$center}{$fqdn}{OS};
				###next if ($system_type !~/server|cluster node/i);

				my $status = $esl_system_ci{$customer}{$center}{$fqdn}{STATUS};
				my $eol_status = $esl_system_ci{$customer}{$center}{$fqdn}{EOL_STATUS};
				my $backup_etp;
				if (exists($esl_system_ci{$customer}{$center}{$fqdn}{ETP})) {
					$backup_etp = $esl_system_ci{$customer}{$center}{$fqdn}{ETP}->{backup};
				}

				my $owner_flag = $esl_system_ci{$customer}{$center}{$fqdn}{OWNER_FLAG} || 0;
				my $ssn_flag = $esl_system_ci{$customer}{$center}{$fqdn}{SSN} || 0;
				my $eso_flag = $esl_system_ci{$customer}{$center}{$fqdn}{ESO4SAP} || 0;

				my $kpe_name = $esl_system_ci{$customer}{$center}{$fqdn}{KPE_NAME};
				my $service_level = $esl_system_ci{$customer}{$center}{$fqdn}{SERVICE_LEVEL};
				#my $tax_cap = $esl_system_ci{$customer}{$center}{$fqdn}{OS_INSTANCE_TAX_CAP} || 0;
				my $tax_cap = $esl_system_ci{$customer}{$center}{$fqdn}{OS_INSTANCE_TAX_CAP};


				#next if ($system_type !~ /server|cluster node/i);				
				next if ($system_type !~ /$system_type_list/i);
				next if ($status !~ /in production|move to production|ALL/i);

				my %teams;
				my %os_class;

				$os_class{ALL}=1;
				$os_class{backup} = 1;
				$os_class{$tax_cap} = 1;

				$teams{ALL}=1;

				foreach my $os_instance (keys %{$esl_system_ci{$customer}{$center}{$fqdn}{ESL_ORG_CARD}}) {
					foreach my $esl_o (@{$esl_system_ci{$customer}{$center}{$fqdn}{ESL_ORG_CARD}{$os_instance}}) {
						$teams{$esl_o->{ORG_NM}} = 1;
					}
				}

				foreach my $cap (keys %os_class) {
					foreach my $team (keys %teams) {
						foreach my $owner ('ALL','OWNER','SSN','ESO4SAP_OWNED','ESO4SAP_USES') {
							next if ($center ne "ALL" and $owner ne "OWNER");
							next if ($owner eq "OWNER" and $owner_flag == 0);
							next if ($owner eq "SSN" and ($owner_flag == 0 or $ssn_flag == 0));
							next if ($owner eq "ESO4SAP_OWNED" and ($owner_flag == 0 or $eso_flag == 0));
							next if ($owner eq "ESO4SAP_USES" and ($owner_flag == 1 or $eso_flag == 0));

							#next if ($os_type !~ /win|netware|esx|aix|hp-ux|linux|sol|sun|openvms|nonstop|sco|z\/os|freebsd|vio|unix/i);
							next if ($os_type !~ /$os_type_list/i);

							my $backup_status = get_backup_rollup($customer, $center, $cap, $team, $status, $eol_status, $owner, $fqdn, "FILESYSTEM","prd", \%backup_report);
							my $backup_status_eol_all = get_backup_rollup($customer, $center, $cap, $team, $status, "ALL", $owner, $fqdn, "FILESYSTEM","prd", \%backup_report);

							$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{TOTAL_CIS}{VALUE}++;
							$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{TOTAL_CIS}{COLOR} = $voilet;
							$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{TOTAL_CIS}{HTML} = "<a href=\"$drilldown_dir/backkupEligibleCILst.pl?cust=$customer&capability=ALL&status=prd&srv=all_backup_nodes\">$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{TOTAL_CIS}{VALUE}</a>";

							$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{TOTAL_CIS}{VALUE}++;
							$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{TOTAL_CIS}{COLOR} = $voilet;
							$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{TOTAL_CIS}{HTML} = "<a href=\"$drilldown_dir/backkupEligibleCILst.pl?cust=$customer&capability=ALL&status=prd&srv=all_backup_nodes\">$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{TOTAL_CIS}{VALUE}</a>";

							if($system_type eq 'server'){
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{SERVERS}{VALUE}++;
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{SERVERS}{COLOR} = $voilet;
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{SERVERS}{HTML} = "<a href=\"$drilldown_dir/backkupEligibleCILst.pl?customer=$customer&center=$center&capability=$cap&team=$team&status=$status&eol=$eol_status&owner=$owner&srv=all_backup_nodes&srvcat=servers\">$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{SERVERS}{VALUE}</a>";

								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{SERVERS}{VALUE}++;
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{SERVERS}{COLOR} = $voilet;
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{SERVERS}{HTML} = "<a href=\"$drilldown_dir/backkupEligibleCILst.pl?customer=$customer&center=$center&capability=$cap&team=$team&status=$status&eol=ALL&owner=$owner&srv=all_backup_nodes&srvcat=servers\">$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{SERVERS}{VALUE}</a>";

							}elsif($system_type eq 'cluster node'){
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{CLUSTER_NODES}{VALUE}++;
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{CLUSTER_NODES}{COLOR} = $voilet;
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{CLUSTER_NODES}{HTML} = "<a href=\"$drilldown_dir/backkupEligibleCILst.pl?customer=$customer&center=$center&capability=$cap&team=$team&status=$status&eol=$eol_status&owner=$owner&srv=all_backup_nodes&srvcat=clunodes\">$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{CLUSTER_NODES}{VALUE}</a>";

								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{CLUSTER_NODES}{VALUE}++;
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{CLUSTER_NODES}{COLOR} = $voilet;
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{CLUSTER_NODES}{HTML} = "<a href=\"$drilldown_dir/backkupEligibleCILst.pl?customer=$customer&center=$center&capability=$cap&team=$team&status=$status&eol=ALL&owner=$owner&srv=all_backup_nodes&srvcat=clunodes\">$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{CLUSTER_NODES}{VALUE}</a>";

							}

							#Calculate the ETP
							if ($backup_etp ne "") {
								##Column - 2
								##Backup Type: Filesystem
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{ETP}{VALUE}++;
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{ETP}{COLOR} = $dgrey;
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{ETP}{HTML} = "<a href=\"$drilldown_dir/backkupEligibleCILst.pl?customer=$customer&center=$center&capability=$cap&team=$team&status=$status&eol=$eol_status&owner=$owner&srv=backup_exempted_nodes\">$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{ETP}{VALUE}</a>";


								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{ETP}{VALUE}++;
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{ETP}{COLOR} = $dgrey;
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{ETP}{HTML} = "<a href=\"$drilldown_dir/backkupEligibleCILst.pl?customer=$customer&center=$center&capability=$cap&team=$team&status=$status&eol=ALL&owner=$owner&srv=backup_exempted_nodes\">$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{ETP}{VALUE}</a>";

								next;
							}


							$total_etp = $l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{ETP}{VALUE};
							$all_ci = $l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{SERVERS}{VALUE}+$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{CLUSTER_NODES}{VALUE};
							$total_ci_etp = $all_ci - $total_etp;


							$total_etp_all = $l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{ETP}{VALUE};
							$all_ci_all = $l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{SERVERS}{VALUE}+$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{CLUSTER_NODES}{VALUE};
							$total_ci_etp_all = $all_ci_all - $total_etp_all;



							##Column - 3
							##Backup Type: Filesystem
							if ($dc_srv->{total_cell_server} >0) {
								if ($dc_srv->{cell_server_working} eq $dc_srv->{total_cell_server}) {
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{DP}{VALUE} = "$dc_srv->{cell_server_working}<br>Out Of: $dc_srv->{total_cell_server}";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{DP}{COLOR} = "$green";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{DP}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=dataprotector server&cap=filesystem\">$dc_srv->{cell_server_working}<br>Out Of: $dc_srv->{total_cell_server}";
								} else {
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{DP}{VALUE} = "$dc_srv->{cell_server_working}<br>Out Of: $dc_srv->{total_cell_server}";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{DP}{COLOR} = "$red";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{DP}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=dataprotector server&cap=filesystem\">$dc_srv->{cell_server_working}<br>Out Of: $dc_srv->{total_cell_server}";
								}
							} else {
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{DP}{VALUE} = "0";
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{DP}{COLOR} = "$lgrey";
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{DP}{HTML} = "0";
							}



							if ($dc_srv_all->{total_cell_server} >0) {
								if ($dc_srv_all->{cell_server_working} eq $dc_srv_all->{total_cell_server}) {
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{DP}{VALUE} = "$dc_srv_all->{cell_server_working}<br>Out Of: $dc_srv_all->{total_cell_server}";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{DP}{COLOR} = "$green";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{DP}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=dataprotector server&cap=filesystem\">$dc_srv->{cell_server_working}<br>Out Of: $dc_srv->{total_cell_server}";

								}else{
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{DP}{VALUE} = "$dc_srv_all->{cell_server_working}<br>Out Of: $dc_srv_all->{total_cell_server}";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{DP}{COLOR} = "$red";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{DP}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=dataprotector server&cap=filesystem\">$dc_srv->{cell_server_working}<br>Out Of: $dc_srv->{total_cell_server}";


								}
							}else{
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{DP}{VALUE} = "0";
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{DP}{COLOR} = "$lgrey";
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{DP}{HTML} = "0";
							}

							##Column - 4
							##Backup Type: Filesystem
							if ($dc_srv->{nb} >0) {
								if ($dc_srv->{nb} eq $dc_srv->{nb_rpt}) {
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NETBACKUP}{VALUE} = "$dc_srv->{nb_rpt}<br>Out Of: $dc_srv->{nb}";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NETBACKUP}{COLOR} = "$green";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NETBACKUP}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=netbackup server&cap=filesystem\">$dc_srv->{nb_rpt}<br>Out Of: $dc_srv->{nb}";
								} else {
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NETBACKUP}{VALUE} = "$dc_srv->{nb_rpt}<br>Out Of: $dc_srv->{nb}";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NETBACKUP}{COLOR} = "$red";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NETBACKUP}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=netbackup server&cap=filesystem\">$dc_srv->{nb_rpt}<br>Out Of: $dc_srv->{nb}";
								}
							} else {
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NETBACKUP}{VALUE} = "0";
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NETBACKUP}{COLOR} = "$lgrey";
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NETBACKUP}{HTML} = "0";
							}

								if ($dc_srv_all->{nb} >0) {
									if ($dc_srv_all->{nb} eq $dc_srv_all->{nb_rpt}) {
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NETBACKUP}{VALUE} = "$dc_srv_all->{nb_rpt}<br>Out Of: $dc_srv_all->{nb}";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NETBACKUP}{COLOR} = "$green";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NETBACKUP}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=netbackup server&cap=filesystem\">$dc_srv->{nb_rpt}<br>Out Of: $dc_srv->{nb}";

									}else{
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NETBACKUP}{VALUE} = "$dc_srv_all->{nb_rpt}<br>Out Of: $dc_srv_all->{nb}";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NETBACKUP}{COLOR} = "$red";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NETBACKUP}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=netbackup server&cap=filesystem\">$dc_srv->{nb_rpt}<br>Out Of: $dc_srv->{nb}";
									}
								}else{
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NETBACKUP}{VALUE} = "0";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NETBACKUP}{COLOR} = "$lgrey";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NETBACKUP}{HTML} = "0";
								}



								##Column - 5
								##Backup Type: Filesystem
								if ($dc_srv->{be} >0) {
									if ($dc_srv->{be} eq $dc_srv->{be_rpt}) {
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{BACKUPEXEC}{VALUE} = "$dc_srv->{be_rpt}<br>Out Of: $dc_srv->{be}";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{BACKUPEXEC}{COLOR} = "$green";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{BACKUPEXEC}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=backup exec server&cap=filesystem\">$dc_srv->{be_rpt}<br>Out Of: $dc_srv->{be}";

									 } else {
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{BACKUPEXEC}{VALUE} = "$dc_srv->{be_rpt}<br>Out Of: $dc_srv->{be}";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{BACKUPEXEC}{COLOR} = "$red";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{BACKUPEXEC}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=backup exec server&cap=filesystem\">$dc_srv->{be_rpt}<br>Out Of: $dc_srv->{be}";
									 }
								} else {
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{BACKUPEXEC}{VALUE} = "0";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{BACKUPEXEC}{COLOR} = "$lgrey";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{BACKUPEXEC}{HTML} = "0";
								}

								if ($dc_srv_all->{be} >0) {
									if ($dc_srv_all->{be} eq $dc_srv_all->{be_rpt}) {
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{BACKUPEXEC}{VALUE} = "$dc_srv_all->{be_rpt}<br>Out Of: $dc_srv_all->{be}";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{BACKUPEXEC}{COLOR} = "$green";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{BACKUPEXEC}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=backup exec server&cap=filesystem\">$dc_srv->{be_rpt}<br>Out Of: $dc_srv->{be}";

									}else{
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{BACKUPEXEC}{VALUE} = "$dc_srv_all->{be_rpt}<br>Out Of: $dc_srv_all->{be}";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{BACKUPEXEC}{COLOR} = "$red";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{BACKUPEXEC}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=backup exec server&cap=filesystem\">$dc_srv->{be_rpt}<br>Out Of: $dc_srv->{be}";


									}
								}else{
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{BACKUPEXEC}{VALUE} = "0";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{BACKUPEXEC}{COLOR} = "$lgrey";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{BACKUPEXEC}{HTML} = "0";

								}

								##Column - 6
								##Backup Type: Filesystem
								if ($dc_srv->{tsm} >0) {
									if ($dc_srv->{tsm} eq $dc_srv->{tsm_rpt}) {
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{TSM}{VALUE} = "$dc_srv->{tsm_rpt}<br>Out Of: $dc_srv->{tsm}";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{TSM}{COLOR} = "$green";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{TSM}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=tsm server&cap=filesystem\">$dc_srv->{tsm_rpt}<br>Out Of: $dc_srv->{tsm}";

									 } else {
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{TSM}{VALUE} = "$dc_srv->{tsm_rpt}<br>Out Of: $dc_srv->{tsm}";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{TSM}{COLOR} = "$red";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{TSM}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=tsm server&cap=filesystem\">$dc_srv->{tsm_rpt}<br>Out Of: $dc_srv->{tsm}";
									 }
								} else {
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{TSM}{VALUE} = "0";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{TSM}{COLOR} = "$lgrey";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{TSM}{HTML} = "0";
								}

								if ($dc_srv_all->{tsm} >0) {
									if ($dc_srv_all->{tsm} eq $dc_srv_all->{tsm_rpt}) {
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{TSM}{VALUE} = "$dc_srv_all->{tsm_rpt}<br>Out Of: $dc_srv_all->{tsm}";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{TSM}{COLOR} = "$green";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{TSM}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=tsm server&cap=filesystem\">$dc_srv->{tsm_rpt}<br>Out Of: $dc_srv->{tsm}";

									}else{
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{TSM}{VALUE} = "$dc_srv_all->{tsm_rpt}<br>Out Of: $dc_srv_all->{tsm}";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{TSM}{COLOR} = "$red";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{TSM}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=tsm server&cap=filesystem\">$dc_srv->{tsm_rpt}<br>Out Of: $dc_srv->{tsm}";

									}
								}else{
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{TSM}{VALUE} = "0";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{TSM}{COLOR} = "$lgrey";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{TSM}{HTML} = "0";
								}

								##Column - 7
								##Backup Type: Filesystem
								if ($dc_srv->{arc} >0) {
									if ($dc_srv->{arc} eq $dc_srv->{arc_rpt}) {
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{ARCSERVE}{VALUE} = "$dc_srv->{arc_rpt}<br>Out Of: $dc_srv->{arc}";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{ARCSERVE}{COLOR} = "$green";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{ARCSERVE}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=arcserve&cap=filesystem\">$dc_srv->{arc_rpt}<br>Out Of: $dc_srv->{arc}";
									} else {
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{ARCSERVE}{VALUE} = "$dc_srv->{arc_rpt}<br>Out Of: $dc_srv->{arc}";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{ARCSERVE}{COLOR} = "$red";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{ARCSERVE}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=arcserve&cap=filesystem\">$dc_srv->{arc_rpt}<br>Out Of: $dc_srv->{arc}";
									}
								} else {
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{ARCSERVE}{VALUE} = "0";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{ARCSERVE}{COLOR} = "$lgrey";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{ARCSERVE}{HTML} = "0";
								}

								if ($dc_srv_all->{arc} >0) {
									if ($dc_srv_all->{arc} eq $dc_srv_all->{arc_rpt}) {
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{ARCSERVE}{VALUE} = "$dc_srv_all->{arc_rpt}<br>Out Of: $dc_srv_all->{arc}";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{ARCSERVE}{COLOR} = "$green";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{ARCSERVE}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=arcserve&cap=filesystem\">$dc_srv->{arc_rpt}<br>Out Of: $dc_srv->{arc}";

									}else{
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{ARCSERVE}{VALUE} = "$dc_srv_all->{arc_rpt}<br>Out Of: $dc_srv_all->{arc}";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{ARCSERVE}{COLOR} = "$red";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{ARCSERVE}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=arcserve&cap=filesystem\">$dc_srv->{arc_rpt}<br>Out Of: $dc_srv->{arc}";

									}
								}else{
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{ARCSERVE}{VALUE} = "0";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{ARCSERVE}{COLOR} = "$lgrey";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{ARCSERVE}{HTML} = "0";

								}

							  ##Column - 8
								##Backup Type: Filesystem
								if ($dc_srv->{emc} >0) {
									if ($dc_srv->{emc} eq $dc_srv->{emc_rpt}) {
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NETWORKER}{VALUE} = "$dc_srv->{emc_rpt}<br>Out Of: $dc_srv->{emc}";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NETWORKER}{COLOR} = "$green";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NETWORKER}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=emc networker server&cap=filesystem\">$dc_srv->{emc_rpt}<br>Out Of: $dc_srv->{emc}";
									 } else {
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NETWORKER}{VALUE} = "$dc_srv->{emc_rpt}<br>Out Of: $dc_srv->{emc}";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NETWORKER}{COLOR} = "$red";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NETWORKER}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=emc networker server&cap=filesystem\">$dc_srv->{emc_rpt}<br>Out Of: $dc_srv->{emc}";
									 }
							  } else {
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NETWORKER}{VALUE} = "0";
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NETWORKER}{COLOR} = "$lgrey";
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NETWORKER}{HTML} = "0";
							  }

								if ($dc_srv_all->{emc} >0) {
									if ($dc_srv_all->{emc} eq $dc_srv_all->{emc_rpt}) {
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NETWORKER}{VALUE} = "$dc_srv_all->{emc_rpt}<br>Out Of: $dc_srv_all->{emc}";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NETWORKER}{COLOR} = "$green";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NETWORKER}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=emc networker server&cap=filesystem\">$dc_srv->{emc_rpt}<br>Out Of: $dc_srv->{emc}";

									}else{
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NETWORKER}{VALUE} = "$dc_srv_all->{emc_rpt}<br>Out Of: $dc_srv_all->{emc}";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NETWORKER}{COLOR} = "$red";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NETWORKER}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=emc networker server&cap=filesystem\">$dc_srv->{emc_rpt}<br>Out Of: $dc_srv->{emc}";

									}
								}else{
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NETWORKER}{VALUE} = "0";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NETWORKER}{COLOR} = "$lgrey";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NETWORKER}{HTML} = "0";

								}



								if ($dc_srv->{emcavmr} >0) {
									if ($dc_srv->{emcavmr} eq $dc_srv->{emcavmr_rpt}) {
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{AVAMAR}{VALUE} = "$dc_srv->{emcavmr_rpt}<br>Out Of: $dc_srv->{emcavmr}";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{AVAMAR}{COLOR} = "$green";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{AVAMAR}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=emc avamar server&cap=filesystem\">$dc_srv->{emcavmr_rpt}<br>Out Of: $dc_srv->{emcavmr}";
									 } else {
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{AVAMAR}{VALUE} = "$dc_srv->{emcavmr_rpt}<br>Out Of: $dc_srv->{emcavmr}";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{AVAMAR}{COLOR} = "$red";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{AVAMAR}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=emc avamar server&cap=filesystem\">$dc_srv->{emcavmr_rpt}<br>Out Of: $dc_srv->{emcavmr}";
									 }
							  } else {
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{AVAMAR}{VALUE} = "0";
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{AVAMAR}{COLOR} = "$lgrey";
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{AVAMAR}{HTML} = "0";
							  }

								if ($dc_srv_all->{emcavmr} >0) {
									if ($dc_srv_all->{emcavmr} eq $dc_srv_all->{emcavmr_rpt}) {
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{AVAMAR}{VALUE} = "$dc_srv_all->{emcavmr_rpt}<br>Out Of: $dc_srv_all->{emcavmr}";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{AVAMAR}{COLOR} = "$green";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{AVAMAR}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=emc avamar server&cap=filesystem\">$dc_srv->{emcavmr_rpt}<br>Out Of: $dc_srv->{emcavmr}";

									}else{
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{AVAMAR}{VALUE} = "$dc_srv_all->{emcavmr_rpt}<br>Out Of: $dc_srv_all->{emcavmr}";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{AVAMAR}{COLOR} = "$red";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{AVAMAR}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=emc avamar server&cap=filesystem\">$dc_srv->{emcavmr_rpt}<br>Out Of: $dc_srv->{emcavmr}";

									}
								}else{
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{AVAMAR}{VALUE} = "0";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{AVAMAR}{COLOR} = "$lgrey";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{AVAMAR}{HTML} = "0";

								}






								if ($dc_srv->{commvault} >0) {
									if ($dc_srv->{commvault} eq $dc_srv->{commvault_rpt}) {
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{COMMVAULT}{VALUE} = "$dc_srv->{commvault_rpt}<br>Out Of: $dc_srv->{commvault}";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{COMMVAULT}{COLOR} = "$green";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{COMMVAULT}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=commvault server&cap=filesystem\">$dc_srv->{commvault_rpt}<br>Out Of: $dc_srv->{commvault}";
									 } else {
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{COMMVAULT}{VALUE} = "$dc_srv->{commvault_rpt}<br>Out Of: $dc_srv->{commvault}";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{COMMVAULT}{COLOR} = "$red";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{COMMVAULT}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=commvault server&cap=filesystem\">$dc_srv->{commvault_rpt}<br>Out Of: $dc_srv->{commvault}";
									 }
							  } else {
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{COMMVAULT}{VALUE} = "0";
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{COMMVAULT}{COLOR} = "$lgrey";
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{COMMVAULT}{HTML} = "0";
							  }

								if ($dc_srv_all->{commvault} >0) {
									if ($dc_srv_all->{commvault} eq $dc_srv_all->{commvault_rpt}) {
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{COMMVAULT}{VALUE} = "$dc_srv_all->{commvault_rpt}<br>Out Of: $dc_srv_all->{commvault}";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{COMMVAULT}{COLOR} = "$green";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{COMMVAULT}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=commvault server&cap=filesystem\">$dc_srv->{commvault_rpt}<br>Out Of: $dc_srv->{commvault}";

									}else{
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{COMMVAULT}{VALUE} = "$dc_srv_all->{commvault_rpt}<br>Out Of: $dc_srv_all->{commvault}";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{COMMVAULT}{COLOR} = "$red";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{COMMVAULT}{HTML} = "<a href=\"$drilldown_dir/getCellSrv.pl?customer=$customer&type=commvault server&cap=filesystem\">$dc_srv->{commvault_rpt}<br>Out Of: $dc_srv->{commvault}";

									}
								}else{
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{COMMVAULT}{VALUE} = "0";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{COMMVAULT}{COLOR} = "$lgrey";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{COMMVAULT}{HTML} = "0";

								}






							  ##Column - 9
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{KPE}{VALUE} = "KPE";
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{KPE}{COLOR} = $golden;
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{KPE}{HTML} = "<a href=\"$drilldown_dir/backkupEligibleCILst.pl?customer=$customer&center=$center&capability=$cap&team=$team&status=$status&eol=$eol_status&owner=$owner&srv=backup_kpe_nodes\">KPE";

								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{KPE}{VALUE} = "KPE";
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{KPE}{COLOR} = $golden;
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{KPE}{HTML} = "<a href=\"$drilldown_dir/backkupEligibleCILst.pl?customer=$customer&center=$center&capability=$cap&team=$team&status=$status&eol=ALL&owner=$owner&srv=backup_kpe_nodes\">KPE";

								##Column - 10
								##Backup Type: Filesystem
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{ELIGIBLE}{VALUE} = $total_ci_etp;
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{ELIGIBLE}{COLOR} = $info;
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{ELIGIBLE}{HTML} = "<a href=\"$drilldown_dir/backkupEligibleCILst.pl?customer=$customer&center=$center&capability=$cap&team=$team&status=$status&eol=$eol_status&owner=$owner&srv=backup_eligible_nodes\">$total_ci_etp";

								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{ELIGIBLE}{VALUE} = $total_ci_etp_all;
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{ELIGIBLE}{COLOR} = $info;
								$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{ELIGIBLE}{HTML} = "<a href=\"$drilldown_dir/backkupEligibleCILst.pl?customer=$customer&center=$center&capability=$cap&team=$team&status=$status&eol=ALL&owner=$owner&srv=backup_eligible_nodes\">$total_ci_etp_all";

								##Column - 11
								##Backup Type: Filesystem
								 if ($backup_status->{good_backup} ne "") {
											my $backup_perc;
											if($total_ci_etp > 0){
												$backup_perc = sprintf "%0.1f", ($backup_status->{good_backup}) / $total_ci_etp * 100;
											}
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{GOOD}{VALUE} = $backup_perc;
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{GOOD}{COLOR} = $green;
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{GOOD}{NUMBER} = $backup_status->{good_backup};
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{GOOD}{HTML} = "<a href=\"$drilldown_dir/rollUpBackup.pl?customer=$customer&center=$center&capability=$cap&team=$team&status=$status&eol=$eol_status&owner=$owner&type=good_backup\">$backup_status->{good_backup} </a><br>$backup_perc\%";

											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{GOOD}{VALUE} = $backup_perc;
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{GOOD}{COLOR} = $green;
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{GOOD}{NUMBER} = $backup_status_eol_all->{good_backup};
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{GOOD}{HTML} = "<a href=\"$drilldown_dir/rollUpBackup.pl?customer=$customer&center=$center&capability=$cap&team=$team&status=$status&eol=ALL&owner=$owner&type=good_backup\">$backup_status_eol_all->{good_backup} </a><br>$backup_perc\%";

								 } else {
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{GOOD}{VALUE} = "0";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{GOOD}{COLOR} = $green;
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{GOOD}{NUMBER} = "0";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{GOOD}{HTML} = "0<br>0.0\%";

									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{GOOD}{VALUE} = "0";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{GOOD}{COLOR} = $green;
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{GOOD}{NUMBER} = "0";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{GOOD}{HTML} = "0<br>0.0\%";
								 }
								 ##Column - 13
								 ##Backup Type: Filesystem
								 if ($backup_status->{amber_backup} ne "") {
											my $backup_perc;
											if($total_ci_etp > 0){
												$backup_perc = sprintf "%0.1f", ($backup_status->{amber_backup}) / $total_ci_etp * 100;
											}
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{AMBER}{VALUE} = $backup_perc;
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{AMBER}{COLOR} = $amber;
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{AMBER}{NUMBER} = $backup_status->{amber_backup};
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{AMBER}{HTML} = "<a href=\"$drilldown_dir/rollUpBackup.pl?customer=$customer&center=$center&capability=$cap&team=$team&status=$status&eol=$eol_status&owner=$owner&type=amber_backup\">$backup_status->{amber_backup} </a><br>$backup_perc\%";

											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{AMBER}{VALUE} = $backup_perc;
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{AMBER}{COLOR} = $amber;
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{AMBER}{NUMBER} = $backup_status_eol_all->{amber_backup};
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{AMBER}{HTML} = "<a href=\"$drilldown_dir/rollUpBackup.pl?customer=$customer&center=$center&capability=$cap&team=$team&status=$status&eol=ALL&owner=$owner&type=amber_backup\">$backup_status_eol_all->{amber_backup} </a><br>$backup_perc\%";
								 } else {
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{AMBER}{VALUE} = "0";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{AMBER}{COLOR} = $amber;
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{AMBER}{NUMBER} = "0";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{AMBER}{HTML} = "0<br>0.0\%";

										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{AMBER}{VALUE} = "0";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{AMBER}{COLOR} = $amber;
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{AMBER}{NUMBER} = "0";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{AMBER}{HTML} = "0<br>0.0\%";
								 }
								 ##Column - 14
								 ##Backup Type: Filesystem
								 if ($backup_status->{orange_backup} ne "") {
											my $backup_perc;
											if($total_ci_etp > 0){
												$backup_perc = sprintf "%0.1f", ($backup_status->{orange_backup}) / $total_ci_etp * 100;
											}
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{ORANGE}{VALUE} = $backup_perc;
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{ORANGE}{COLOR} = $orange;
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{ORANGE}{NUMBER} = $backup_status->{orange_backup};
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{ORANGE}{HTML} = "<a href=\"$drilldown_dir/rollUpBackup.pl?customer=$customer&center=$center&capability=$cap&team=$team&status=$status&eol=$eol_status&owner=$owner&type=orange_backup\">$backup_status->{orange_backup} </a><br>$backup_perc\%";

											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{ORANGE}{VALUE} = $backup_perc;
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{ORANGE}{COLOR} = $orange;
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{ORANGE}{NUMBER} = $backup_status_eol_all->{orange_backup};
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{ORANGE}{HTML} = "<a href=\"$drilldown_dir/rollUpBackup.pl?customer=$customer&center=$center&capability=$cap&team=$team&status=$status&eol=ALL&owner=$owner&type=orange_backup\">$backup_status_eol_all->{orange_backup} </a><br>$backup_perc\%";
								 } else {
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{ORANGE}{VALUE} = "0";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{ORANGE}{COLOR} = $orange;
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{ORANGE}{NUMBER} = "0";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{ORANGE}{HTML} = "0<br>0.0\%";

										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{ORANGE}{VALUE} = "0";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{ORANGE}{COLOR} = $orange;
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{ORANGE}{NUMBER} = "0";
										$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{ORANGE}{HTML} = "0<br>0.0\%";
								 }

								 ##Column - 15
								 ##Backup Type: Filesystem
								 if ($backup_status->{red_backup} ne "") {
											my $backup_perc;
											if($total_ci_etp > 0){
												$backup_perc = sprintf "%0.1f", ($backup_status->{red_backup}) / $total_ci_etp * 100;
											}
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{RED}{VALUE} = $backup_perc;
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{RED}{COLOR} = $lgolden;
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{RED}{NUMBER} = $backup_status->{red_backup};
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{RED}{HTML} = "<a href=\"$drilldown_dir/rollUpBackup.pl?customer=$customer&center=$center&capability=$cap&team=$team&status=$status&eol=$eol_status&owner=$owner&type=red_backup\">$backup_status->{red_backup} </a><br>$backup_perc\%";

											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{RED}{VALUE} = $backup_perc;
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{RED}{COLOR} = $lgolden;
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{RED}{NUMBER} = $backup_status_eol_all->{red_backup};
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{RED}{HTML} = "<a href=\"$drilldown_dir/rollUpBackup.pl?customer=$customer&center=$center&capability=$cap&team=$team&status=$status&eol=ALL&owner=$owner&type=red_backup\">$backup_status_eol_all->{red_backup} </a><br>$backup_perc\%";
								 } else {
									  $l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{RED}{VALUE} = "0";
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{RED}{COLOR} = $lgolden;
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{RED}{NUMBER} = "0";
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{RED}{HTML} = "0<br>0.0\%";

									  $l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{RED}{VALUE} = "0";
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{RED}{COLOR} = $lgolden;
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{RED}{NUMBER} = "0";
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{RED}{HTML} = "0<br>0.0\%";
								 }

								 ##Column - 16
								 ##Backup Type: Filesystem
								 if ($backup_status->{no_backup} ne "") {
											my $backup_perc;
											if($total_ci_etp > 0){
												$backup_perc = sprintf "%0.1f", ($backup_status->{no_backup}) / $total_ci_etp * 100;
											}
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NO_BACKUP}{VALUE} = $backup_perc;
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NO_BACKUP}{COLOR} = $red;
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NO_BACKUP}{NUMBER} = $backup_status->{no_backup};
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NO_BACKUP}{HTML} = "<a href=\"$drilldown_dir/rollUpBackup.pl?customer=$customer&center=$center&capability=$cap&team=$team&status=$status&eol=$eol_status&owner=$owner&type=no_backup\">$backup_status->{no_backup} </a><br>$backup_perc\%";

											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NO_BACKUP}{VALUE} = $backup_perc;
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NO_BACKUP}{COLOR} = $red;
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NO_BACKUP}{NUMBER} = $backup_status_eol_all->{no_backup};
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NO_BACKUP}{HTML} = "<a href=\"$drilldown_dir/rollUpBackup.pl?customer=$customer&center=$center&capability=$cap&team=$team&status=$status&eol=ALL&owner=$owner&type=no_backup\">$backup_status_eol_all->{no_backup} </a><br>$backup_perc\%";
								 } else {
									  $l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NO_BACKUP}{VALUE} = "0";
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NO_BACKUP}{COLOR} = $red;
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NO_BACKUP}{NUMBER} = "0";
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NO_BACKUP}{HTML} = "0<br>0.0\%";

									  $l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NO_BACKUP}{VALUE} = "0";
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NO_BACKUP}{COLOR} = $red;
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NO_BACKUP}{NUMBER} = "0";
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NO_BACKUP}{HTML} = "0<br>0.0\%";
								 }

								 ##Column - 17
								 ##Backup Type: Filesystem
								 if ($backup_status->{no_date} ne "") {
											my $backup_perc;
											if($total_ci_etp > 0){
												$backup_perc = sprintf "%0.1f", ($backup_status->{no_date}) / $total_ci_etp * 100;
											}
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NO_DATE}{VALUE} = $backup_perc;
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NO_DATE}{COLOR} = $red;
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NO_DATE}{NUMBER} = $backup_status->{no_date};
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NO_DATE}{HTML} = "<a href=\"$drilldown_dir/rollUpBackup.pl?customer=$customer&center=$center&capability=$cap&team=$team&status=$status&eol=$eol_status&owner=$owner&type=no_date\">$backup_status->{no_date} </a><br>$backup_perc\%";

											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NO_DATE}{VALUE} = $backup_perc;
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NO_DATE}{COLOR} = $red;
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NO_DATE}{NUMBER} = $backup_status_eol_all->{no_date};
											$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NO_DATE}{HTML} = "<a href=\"$drilldown_dir/rollUpBackup.pl?customer=$customer&center=$center&capability=$cap&team=$team&status=$status&eol=ALL&owner=$owner&type=no_date\">$backup_status_eol_all->{no_date} </a><br>$backup_perc\%";

								 } else {
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NO_DATE}{VALUE} = "0";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NO_DATE}{COLOR} = $red;
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NO_DATE}{NUMBER} = "0";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{FILESYSTEM}{NO_DATE}{HTML} = "0<br>0.0\%";

									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NO_DATE}{VALUE} = "0";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NO_DATE}{COLOR} = $red;
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NO_DATE}{NUMBER} = "0";
									$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILESYSTEM}{NO_DATE}{HTML} = "0<br>0.0\%";
								 }

						}# owner
					}# teams
				}# Cap
			}#fqdn
		}#center
	}#close customer
	save_hash("cache.l2_backup", \%l2_backup,"$cache_dir/l2_cache");
}

if (defined($opts{"s"})) {
	my $backup = load_cache_byFile("$cache_dir/l2_cache/cache.l2_backup");
	my %l2_backup = %{$backup};
	#--------------------------------------------------------------------------------------------------------------------------------------------------------
	#PERFORMANCE ENHANCEMENTS
	my %menu_filters;
	my %tmp;

	foreach my $customer (keys %{$l2_backup{CUSTOMER}}) {
		foreach my $center (keys %{$l2_backup{CUSTOMER}{$customer}{CENTER}}) {
			my $c_str = $center;
			$c_str =~ s/\:/\_/g;
			foreach my $cap (keys %{$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}}) {
				foreach my $team (keys %{$l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}}) {
					my $t_str = $team;
					$t_str =~ s/\W//g;
					$t_str = substr($t_str,0,25);

					my $file = "l2_backup-$c_str-$t_str";

					$tmp{FILE}{$file}{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team} = $l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team};
					$tmp{FILE}{$file}{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'cluster node'}{CAPABILITY}{$cap}{TEAM}{$team} = $l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'cluster node'}{CAPABILITY}{$cap}{TEAM}{$team};
					$tmp{FILE}{$file}{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$cap}{TEAM}{$team} = $l2_backup{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$cap}{TEAM}{$team};
				}
			}
		}
	}

	foreach my $file (keys %{$tmp{FILE}}) {
		my %t2;
		foreach my $customer (keys %{$tmp{FILE}{$file}{CUSTOMER}}) {
			$t2{CUSTOMER}{$customer}{SOURCE} = $l2_backup{CUSTOMER}{$customer}{SOURCE};
			foreach my $center (keys %{$tmp{FILE}{$file}{CUSTOMER}{$customer}{CENTER}}) {
				foreach my $cap (keys %{$tmp{FILE}{$file}{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}}) {
					foreach my $team (keys %{$tmp{FILE}{$file}{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}}) {
						$t2{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team} = $tmp{FILE}{$file}{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team};
						$menu_filters{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}="$file";
						$menu_filters{CUSTOMER}{ALL}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}="$file";
					}
				}
				foreach my $st (keys %{$tmp{FILE}{$file}{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}}) {
					foreach my $cap (keys %{$tmp{FILE}{$file}{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{$st}{CAPABILITY}}) {
						foreach my $team (keys %{$tmp{FILE}{$file}{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{$st}{CAPABILITY}{$cap}{TEAM}}) {
							$t2{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{$st}{CAPABILITY}{$cap}{TEAM}{$team} = $tmp{FILE}{$file}{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{$st}{CAPABILITY}{$cap}{TEAM}{$team};
						}
					}
				}
			}
		}

		save_hash("$file", \%t2,"$cache_dir/l2_cache/by_filters");
	}
	save_hash("menu_filters-l2_backup", \%menu_filters, "$cache_dir/l2_cache/by_filters");

	my $cache_backup_report = load_cache_byFile("$cache_dir/cache.backup_report");
	my %backup_report = %{$cache_backup_report};

	foreach my $customer (keys %backup_report) {
		my %tmp;
		next if($customer =~ /all_backup|good_backup|amber_backup|orange_backup|red_backup|no_date|no_backup/i);
		my $file_name = "$customer"."_backup_report";
		$file_name =~ s/\W//g;
		%tmp=%{$backup_report{$customer}};
		save_hash("$file_name", \%tmp,"$cache_dir/l3_cache/by_customer");

	}

	foreach my $customer (keys %{$backup_report{"no_backup"}}) {
		my %tmp;
		my $file_name = "no_backup_".$customer."_backup_report";
		$file_name =~ s/\W//g;
		%tmp=%{$backup_report{no_backup}{$customer}};
		save_hash("$file_name", \%tmp,"$cache_dir/l3_cache/by_customer");
	}

	foreach my $customer (keys %{$backup_report{"no_date"}}) {
		my %tmp;
		my $file_name = "no_date_".$customer."_backup_report";
		$file_name =~ s/\W//g;
		%tmp=%{$backup_report{no_date}{$customer}};
		save_hash("$file_name", \%tmp,"$cache_dir/l3_cache/by_customer");
	}

	foreach my $customer (keys %{$backup_report{"red_backup"}}) {
		my %tmp;
		my $file_name = "red_backup_".$customer."_backup_report";
		$file_name =~ s/\W//g;
		%tmp=%{$backup_report{red_backup}{$customer}};
		save_hash("$file_name", \%tmp,"$cache_dir/l3_cache/by_customer");
	}

	foreach my $customer (keys %{$backup_report{"orange_backup"}}) {
		my %tmp;
		my $file_name = "orange_backup_".$customer."_backup_report";
		$file_name =~ s/\W//g;
		%tmp=%{$backup_report{orange_backup}{$customer}};
		save_hash("$file_name", \%tmp,"$cache_dir/l3_cache/by_customer");
	}

	foreach my $customer (keys %{$backup_report{"amber_backup"}}) {
		my %tmp;
		my $file_name = "amber_backup_".$customer."_backup_report";
		$file_name =~ s/\W//g;
		%tmp=%{$backup_report{amber_backup}{$customer}};
		save_hash("$file_name", \%tmp,"$cache_dir/l3_cache/by_customer");
	}

	foreach my $customer (keys %{$backup_report{"good_backup"}}) {
		my %tmp;
		my $file_name = "good_backup_".$customer."_backup_report";
		$file_name =~ s/\W//g;
		%tmp=%{$backup_report{good_backup}{$customer}};
		save_hash("$file_name", \%tmp,"$cache_dir/l3_cache/by_customer");
	}

	foreach my $customer (keys %{$backup_report{"all_backup"}}) {
		my %tmp;
		my $file_name = "all_backup_".$customer."_backup_report";
		$file_name =~ s/\W//g;
		%tmp=%{$backup_report{all_backup}{$customer}};
		save_hash("$file_name", \%tmp,"$cache_dir/l3_cache/by_customer");
	}

}


printf "%0.2f Mins\n", (time() - $start_time) / 60;
