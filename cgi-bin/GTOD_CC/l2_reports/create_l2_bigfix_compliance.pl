#!/usr/bin/perl
#
# Pathi Erramilli     29/11/2018      Changing EMC template to OCI

use strict;
use Sys::Hostname;
use File::Basename;
use File::Temp "tempfile";
use CGI qw(:standard);
use FileHandle;
use Data::Dumper;
use Time::Local;
use POSIX qw(strftime);
use Net::Domain qw (hostname hostfqdn hostdomain);


use lib '/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/modules/pm';
use LoadCache;
use CommonFunctions;
use CommonColor;

use vars qw($cache_dir);
use vars qw($rawdata_dir);
use vars qw($cfg_dir);
use vars qw($drilldown_dir);
use vars qw($l2_report_dir);
use vars qw($green $red $amber $grey $yellow $orange $cyan $cgreen $lgrey $info $info2 $dgrey $voilet $lgolden $lblue $hpe);


my %opts = ();
my $use_db = 0;
my @db;

my $down_icon = '<b>&#8600;</b>'; #down
my $up_icon = '<b>&#8599;</b>'; #up
my $stable_icon = '<b>&#8594;</b>'; #stable  &#x2192

####Added to run only on data collection server
my $cfg = read_config();
my $master_server = hostname();
if ($master_server !~ /\./) { $master_server = hostfqdn(); }
chomp $master_server;

if ($cfg->{DATACOLLECTION_MASTER} !~ /$master_server/i) {
	print "Data collection not enabled on this server - $master_server (Data Collection enabled on: $cfg->{DATACOLLECTION_MASTER})\n";
	#exit;
}

# Load required cache files
#my @list = ('account_reg','patch_data_list','srv_patch_mapping','patch_srv_mapping');
my @list = ('account_reg','patch_data_list','l2_system_baseline');
my %cache = load_cache(\@list);
my %cache_sync_time = get_sync_time(\@list);

my %account_reg = %{$cache{account_reg}};
my %patch_data_list = %{$cache{patch_data_list}};
my %l2_baseline = %{$cache{l2_system_baseline}};
#my %bigfix_compliance_devices = %{$cache{bigfix_compliance_devices}};
#my %storage_cis = %{$cache{storage_cis}};

my %l3_bigfix_compliance;
my %l2_bigfix_compliance;

my $tick_icon = '<b>&#x2713;</b>';
my $cross_icon = '<b>&#x2717;</b>';

my ($windows_count, $ux_count, $others_count);

my %all_devices;
my %missing_devices;
my %found_id;

####MAIN####
my $start_time = time();
#print "Start time: $start_time \n";
create_bigfix_bigfix_compliance();

#foreach my $customer (keys %l3_bigfix_compliance) {
#	my %tmp;
#	my $file_name = "$customer"."_l3_bigfix_compliance";
#	%tmp=%{$l3_bigfix_compliance{$customer}};
#	save_hash("$file_name", \%tmp,"$cache_dir/l3_cache/by_customer");
#}

#print "Windows~$windows_count~Unix~$ux_count~Others~$others_count \n";

save_hash("cache.l2_bigfix_compliance", \%l2_bigfix_compliance,"$cache_dir/l2_cache");
save_hash("cache.l3_bigfix_compliance", \%l3_bigfix_compliance,"$cache_dir/l3_cache");

my $end_time = time();
printf "%0.1f Mins\n", ($end_time - $start_time) / 60;


#############

sub create_bigfix_bigfix_compliance
{
	my $tax_cap;
	#print "Step1:Inside create_bigfix_bigfix_compliance subroutine \n";
	foreach my $customer (sort keys %account_reg) {
		my $dmar_id = uc $account_reg{$customer}{dmar_id};
		if ($dmar_id) {
			#print "DMAR ID: $dmar_id,$patch_data_list{CUSTOMER}{$dmar_id} \n";
		}
		
		# Matching DMAR ID in account register and DMAR ID from Bigfix Data
		# If I donot have a match of DMAR ID in Bigfix Patch data, skip the customer
		next if(not defined $patch_data_list{CUSTOMER}{$dmar_id});

		#print "Customer~~$customer~~$account_reg{$customer}{dmar_id} \n";
		#next if ($customer ne 'queensland rail');#'intermountain healthcare'); #'origin energy' #"bank of queensland");
		#print "Skipping $customer \n"if (defined($opts{"c"}) and not defined($cust_list_hash{$customer}))	;
		#next if (defined($opts{"c"}) and not defined($cust_list_hash{$customer}))	;
		#next if($account_reg{$customer}{shavlik_patch}=~/yes/i and $account_reg{$customer}{hpsa_patch}!~/yes/i);
		my %patch_summary=();
		my $file_name = "$account_reg{$customer}{sp_mapping_file}"."_esl_system_ci_by_fqdn";
		my $l3_filename = "$account_reg{$customer}{sp_mapping_file}"."_bigfix";
		#print "Doing $customer with CI Data\n" if ( -r "$cache_dir/by_customer/$file_name");

		print "Loading $cache_dir/by_customer/$file_name\n";
		my $sys = load_cache_byFile("$cache_dir/by_customer/$file_name");

		my %esl_system_ci = %{$sys};
		my ($win_compliant,$win_total_eos,$win_total_srv,$win_os_compliant,$win_os_total_srv,$win_os_old,$win_os_non_compliant);
		my ($AT_MET_ESIS,$AT_NON_OPT_PATCHES,$AT_INSIDE_ESIS,$P30_MET_ESIS,$P30_NON_OPT_PATCHES,$at_ref_win);

		foreach my $center (keys %{$esl_system_ci{$customer}}) {

			#For each FQDN
			foreach my $fqdn (keys %{$esl_system_ci{$customer}{$center}}) {
				
				#print "Step2~~$customer~~$fqdn \n";
				#my $name = $patch_data_list{CUSTOMER}{$dmar_id}{SERVER}{$fqdn}{OS_NM}||$esl_system_ci{$customer}{$center}{$fqdn}{OS_INSTANCE_NAME};
				#next if(!$name);

				my $status = $esl_system_ci{$customer}{$center}{$fqdn}{STATUS};
				my $eol_status = $esl_system_ci{$customer}{$center}{$fqdn}{HW_EOL_STATUS};
				my $system_id = $esl_system_ci{$customer}{$center}{$fqdn}{SYSTEM_ID};
				my $owner_flag = $esl_system_ci{$customer}{$center}{$fqdn}{OWNER_FLAG};
				my $ssn_flag = $esl_system_ci{$customer}{$center}{$fqdn}{SSN};
				my $eso_flag = $esl_system_ci{$customer}{$center}{$fqdn}{ESO4SAP};
				my $service_level = $esl_system_ci{$customer}{$center}{$fqdn}{SERVICE_LEVEL};
				my $os_version = $esl_system_ci{$customer}{'ALL'}{$fqdn}{VERSION};
				my $system_type = $esl_system_ci{$customer}{$center}{$fqdn}{SERVER_TYPE};
				#my $system_type = $patch_data_list{CUSTOMER}{$dmar_id}{SERVER}{$fqdn}{DVC_TYPE_NM};
				
				#my $os_instance_name = $patch_data_list{CUSTOMER}{$dmar_id}{SERVER}{$fqdn}{OS_NM};#||$esl_system_ci{$customer}{$center}{$fqdn}{OS};

				my $system_ci_os_class = $patch_data_list{CUSTOMER}{$dmar_id}{SERVER}{$fqdn}{OS_NM};#||$esl_system_ci{$customer}{$center}{$fqdn}{OS_INSTANCE_NAME};
				$tax_cap = "windows" if ($system_ci_os_class =~ /win/i);
				$tax_cap = "unix" if ($system_ci_os_class =~ /unix|linux|aix|solaris|sco|ubuntu|hp-ux|hpux|rhel/i);

				#if($system_ci_os_class){
				#print "Step2~~$customer~~$fqdn~~$tax_cap~~$system_ci_os_class \n";
				#}

				next if ($system_type !~ /server|cluster node/i);
				my ($patching_etp);
				if (exists($esl_system_ci{$customer}{$center}{$fqdn}{ETP})) {
					$patching_etp = $esl_system_ci{$customer}{$center}{$fqdn}{ETP}->{'patch management'};
				}

				if((! $l2_bigfix_compliance{OS_TYPES}{"$system_ci_os_class"}) and ($system_ci_os_class ne "")){             
					$l2_bigfix_compliance{OS_TYPES}{"$system_ci_os_class"} = $system_ci_os_class; 
				}
				
				if((! $l2_bigfix_compliance{CUSTOMER}{$customer}{OS_TYPES}{"$system_ci_os_class"}) and ($system_ci_os_class ne "")){             
					$l3_bigfix_compliance{CUSTOMER}{$customer}{OS_TYPES}{"$system_ci_os_class"} = $system_ci_os_class; 
					#$l3_bigfix_compliance{CUSTOMER}{$customer}{OS_TYPES}{"$system_ci_os_class"}{SERVERS}{$fqdn} = $patch_data_list{CUSTOMER}{$dmar_id}{SERVER}{$fqdn}{CI_NM}; 
				}                                                                  

				my %teams;
				$teams{ALL} = 1;
				#foreach my $cap (keys %os_class) {
				foreach my $cap ('ALL','windows','unix'){

					foreach my $team (keys %teams) {
						next if($team=~/^\s*$/);
						foreach my $owner ('ALL','OWNER','SSN','ESO4SAP_OWNED','ESO4SAP_USES') {
							next if ($center ne "ALL" and $owner ne "OWNER");
							next if ($owner eq "OWNER" and $owner_flag == 0);
							next if ($owner eq "SSN" and ($owner_flag == 0 or $ssn_flag == 0));
							next if ($owner eq "ESO4SAP_OWNED" and ($owner_flag == 0 or $eso_flag == 0));
							next if ($owner eq "ESO4SAP_USES" and ($owner_flag == 1 or $eso_flag == 0));
							
							#my $cap = $tax_cap;
							#print "$dmar_id~~$fqdn~~$cap~~$team \n";
							if(not defined $l3_bigfix_compliance{CUSTOMER}{$customer}{SERVER}{$fqdn}){
								$l3_bigfix_compliance{CUSTOMER}{$customer}{SERVER}{$fqdn} = \%{$patch_data_list{CUSTOMER}{$dmar_id}{SERVER}{$fqdn}};
							}

							# Save Baseline
							$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'cluster node'}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{COUNT} = $l2_baseline{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'cluster node'}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{COUNT};
							$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{COUNT} = $l2_baseline{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{COUNT};

							$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'cluster node'}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{COUNT} = $l2_baseline{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'cluster node'}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{COUNT};
							$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{COUNT} = $l2_baseline{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{COUNT};
							
							$l2_bigfix_compliance{CUSTOMER}{$customer}{OS_TYPES}{"$system_ci_os_class"}{COUNT}{VALUE}++;
	
							#print "Step3~~$customer~~$fqdn~~$tax_cap~~$os_instance_name \n";
							if (($tax_cap eq "windows") and ($cap =~ /ALL|windows/i))
							{
								#my $cap = $tax_cap;
								#$windows_count ++;
								#Calculate the ETP
								if ($patching_etp ne "" or $service_level =~ /hosting only|not supported/i) {
									$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{WIN_PATCH_ETP}{VALUE}++;
									#$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{WIN_PATCH_ETP}{VALUE}=0 if(not defined($l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{WIN_PATCH_ETP}{VALUE}));
									$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{WIN_PATCH_ETP}{HTML} = "<a href=\"$drilldown_dir/patch_eslSystemCI.pl?customer=$customer&status=$status&system_type=server_and_node&capability=$cap&center=$center&owner_flag=$owner&team=$team&eol_status=$eol_status&etp=patch_mgt&hw_eol_status=all&patch_mgt=patch_mgt\">$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{WIN_PATCH_ETP}{VALUE}</a>";

									$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{WIN_PATCH_ETP}{VALUE}++;
									#$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{WIN_PATCH_ETP}{VALUE}=0 if(not defined($l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{WIN_PATCH_ETP}{VALUE}));
									$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{WIN_PATCH_ETP}{HTML} = "<a href=\"$drilldown_dir/patch_eslSystemCI.pl?customer=$customer&status=$status&system_type=server_and_node&capability=$cap&center=$center&owner_flag=$owner&team=$team&eol_status=ALL&etp=patch_mgt&hw_eol_status=all&patch_mgt=patch_mgt\">$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{WIN_PATCH_ETP}{VALUE}</a>";

									$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{OS_TYPES}{"$system_ci_os_class"}{BIGFIX_ETP}{VALUE}++;
									$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{OS_TYPES}{"$system_ci_os_class"}{BIGFIX_ETP}{VALUE}++;
									next;
								}

								#Calculate Eligible Count ....Anything without ETP should be covered by Bigfix
								$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{WIN_PATCH_ELIGIBLE}{VALUE}++;
								#$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{WIN_PATCH_ELIGIBLE}{VALUE}=0 if(not defined($l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{WIN_PATCH_ELIGIBLE}{VALUE}));
								$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{WIN_PATCH_ELIGIBLE}{HTML} = "<a href=\"$drilldown_dir/patch_eslSystemCI.pl?customer=$customer&status=$status&system_type=server_and_node&capability=$cap&center=$center&owner_flag=$owner&team=$team&eol_status=$eol_status&eligible=patch_mgt&hw_eol_status=all&patch_mgt=patch_mgt\">$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{WIN_PATCH_ELIGIBLE}{VALUE}</a>";

								$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{WIN_PATCH_ELIGIBLE}{VALUE}++;
								#$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{WIN_PATCH_ELIGIBLE}{VALUE}=0 if(not defined($l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{WIN_PATCH_ELIGIBLE}{VALUE}));
								$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{WIN_PATCH_ELIGIBLE}{HTML} = "<a href=\"$drilldown_dir/patch_eslSystemCI.pl?customer=$customer&status=$status&system_type=server_and_node&capability=$cap&center=$center&owner_flag=$owner&team=$team&eol_status=ALL&eligible=patch_mgt&hw_eol_status=all&patch_mgt=patch_mgt\">$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{WIN_PATCH_ELIGIBLE}{VALUE}</a>";
								
								$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{OS_TYPES}{"$system_ci_os_class"}{BIGFIX_ELIGIBLE}{VALUE}++;
								$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{OS_TYPES}{"$system_ci_os_class"}{BIGFIX_ELIGIBLE}{VALUE}++;
								
								#Calculate Bigfix Coverage
								if(($patch_data_list{CUSTOMER}{$dmar_id}{SERVER}{$fqdn}{CI_NM}) or ($fqdn =~ /$patch_data_list{CUSTOMER}{$dmar_id}{SERVER}{$fqdn}{CI_NM}/i))
								{
									$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{OS_TYPES}{"$system_ci_os_class"}{BIGFIX_INSTALLED}{VALUE}++;
									#print "Windows~~Bigfix Covered~~$dmar_id~~$fqdn~~$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{WIN_BIGFIX_INSTALLED}{VALUE} \n";
									$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{WIN_BIGFIX_INSTALLED}{VALUE}++;
									#$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{WIN_PATCH_ELIGIBLE}{VALUE}=0 if(not defined($l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{WIN_PATCH_ELIGIBLE}{VALUE}));
									$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{WIN_BIGFIX_INSTALLED}{HTML} = "<a href=\"$drilldown_dir/l3_bigfix_compliance.pl?cust=$customer&report_type=enrolled&cap=$cap\">$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{WIN_BIGFIX_INSTALLED}{VALUE}</a>";

									$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{OS_TYPES}{"$system_ci_os_class"}{BIGFIX_INSTALLED}{VALUE}++;
									$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{WIN_BIGFIX_INSTALLED}{VALUE}++;
									#$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{WIN_PATCH_ELIGIBLE}{VALUE}=0 if(not defined($l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{WIN_PATCH_ELIGIBLE}{VALUE}));
									$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{WIN_BIGFIX_INSTALLED}{HTML} = "<a href=\"$drilldown_dir/l3_bigfix_compliance.pl?cust=$customer&report_type=enrolled&cap=$cap\">$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{WIN_BIGFIX_INSTALLED}{VALUE}</a>";
									#print "Step4~~$customer~~$fqdn~~$tax_cap~~$center~~$cap~~$team~~$status~~$eol_status~~$owner~~$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{WIN_BIGFIX_INSTALLED}{VALUE} \n";
								}

							#}elsif($tax_cap eq "unix"){
							}elsif (($tax_cap eq "unix") and ($cap =~ /ALL|unix/i)){
								###############Midrange############################
								#my $cap = $tax_cap;
								#$ux_count ++;

								#Calculate the ETP
								if ($patching_etp ne "" or $service_level =~ /hosting only|not supported/i) {
									$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{UX_PATCH_ETP}{VALUE}++;
									$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{UX_PATCH_ETP}{HTML} = "<a href=\"$drilldown_dir/patch_eslSystemCI.pl?customer=$customer&status=$status&system_type=server_and_node&capability=$cap&center=$center&owner_flag=$owner&team=$team&eol_status=$eol_status&etp=patch_mgt&patch_mgt=patch_mgt\">$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{UX_PATCH_ETP}{VALUE}</a>";

									$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{UX_PATCH_ETP}{VALUE}++;
									$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{UX_PATCH_ETP}{HTML} = "<a href=\"$drilldown_dir/patch_eslSystemCI.pl?customer=$customer&status=$status&system_type=server_and_node&capability=$cap&center=$center&owner_flag=$owner&team=$team&eol_status=ALL&etp=patch_mgt&patch_mgt=patch_mgt\">$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{UX_PATCH_ETP}{VALUE}</a>";
									
									$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{OS_TYPES}{"$system_ci_os_class"}{PATCH_ETP}{VALUE}++;
									$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{OS_TYPES}{"$system_ci_os_class"}{PATCH_ETP}{VALUE}++;
									next;
								}

								#Calculate the Eligible count
								$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{UX_PATCH_ELIGIBLE}{VALUE}++;
								$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{UX_PATCH_ELIGIBLE}{HTML} = "<a href=\"$drilldown_dir/patch_eslSystemCI.pl?customer=$customer&status=$status&system_type=server_and_node&capability=$cap&center=$center&owner_flag=$owner&team=$team&eol_status=$eol_status&eligible=patch_mgt&patch_mgt=patch_mgt\">$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{UX_PATCH_ELIGIBLE}{VALUE}</a>";

								$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{UX_PATCH_ELIGIBLE}{VALUE}++;
								$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{UX_PATCH_ELIGIBLE}{HTML} = "<a href=\"$drilldown_dir/patch_eslSystemCI.pl?customer=$customer&status=$status&system_type=server_and_node&capability=$cap&center=$center&owner_flag=$owner&team=$team&eol_status=ALL&eligible=patch_mgt&patch_mgt=patch_mgt\">$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{UX_PATCH_ELIGIBLE}{VALUE}</a>";
								
								$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{OS_TYPES}{"$system_ci_os_class"}{BIGFIX_ELIGIBLE}{VALUE}++;
								$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{OS_TYPES}{"$system_ci_os_class"}{BIGFIX_ELIGIBLE}{VALUE}++;
								
								#Calculate Bigfix Coverage
								if (($patch_data_list{CUSTOMER}{$dmar_id}{SERVER}{$fqdn}{CI_NM}) or ($fqdn =~ /$patch_data_list{CUSTOMER}{$dmar_id}{SERVER}{$fqdn}{CI_NM}/i))
								{
									$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{OS_TYPES}{"$system_ci_os_class"}{BIGFIX_INSTALLED}{VALUE}++;
									#print "UX~~Bigfix Covered~~$dmar_id~~$fqdn \n";
									$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{UX_BIGFIX_INSTALLED}{VALUE}++;
									#$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{WIN_PATCH_ELIGIBLE}{VALUE}=0 if(not defined($l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{WIN_PATCH_ELIGIBLE}{VALUE}));
									$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{UX_BIGFIX_INSTALLED}{HTML} = "<a href=\"$drilldown_dir/l3_bigfix_compliance.pl?cust=$customer&report_type=enrolled&query_type=l2_enrolled&cap=$cap\">$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{UX_BIGFIX_INSTALLED}{VALUE}</a>";
									
									$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{OS_TYPES}{"$system_ci_os_class"}{BIGFIX_INSTALLED}{VALUE}++;
									$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{UX_BIGFIX_INSTALLED}{VALUE}++;
									#$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{WIN_PATCH_ELIGIBLE}{VALUE}=0 if(not defined($l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{WIN_PATCH_ELIGIBLE}{VALUE}));
									$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{UX_BIGFIX_INSTALLED}{HTML} = "<a href=\"$drilldown_dir/l3_bigfix_compliance.pl?cust=$customer&report_type=enrolled&query_type=l2_enrolled&cap=$cap\">$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{UX_BIGFIX_INSTALLED}{VALUE}</a>";
								}
						

									############### Others ############################
							#}elsif(($tax_cap ne "unix")and($tax_cap ne "windows")){
							}elsif(($tax_cap ne "unix")and($tax_cap ne "windows")and($cap !~ /unix|windows/i)){
								# Other Servers
								#if ($cap =~ /other/i){
									#print "Customer~$customer~$fqdn~$system_ci_os_class~$tax_cap~$cap\n";
									#Calculate the ETP
									if ($patching_etp ne "" or $service_level =~ /hosting only|not supported/i) {

										$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{'not applicable'}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{PATCH_ETP_OTHER}{VALUE}++;
										$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{'not applicable'}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{PATCH_ETP_OTHER}{HTML} = "<a href=\"$drilldown_dir/patch_eslSystemCI.pl?customer=$customer&status=$status&system_type=server_and_node&capability=$cap&os_class=other&center=$center&owner_flag=$owner&team=$team&eol_status=$eol_status&etp=patch_mgt&patch_mgt=patch_mgt\">$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{'not applicable'}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{PATCH_ETP_OTHER}{VALUE}</a>";

										$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{'not applicable'}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{PATCH_ETP_OTHER}{VALUE}++;
										$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{'not applicable'}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{PATCH_ETP_OTHER}{HTML} = "<a href=\"$drilldown_dir/patch_eslSystemCI.pl?customer=$customer&status=$status&system_type=server_and_node&capability=$cap&os_class=other&center=$center&owner_flag=$owner&team=$team&eol_status=ALL&etp=patch_mgt&patch_mgt=patch_mgt\">$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{'not applicable'}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{PATCH_ETP_OTHER}{VALUE}</a>";

										next;
									}

									#Calculate the Eligible count
									$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{'not applicable'}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{PATCH_ELIGIBLE_OTHER}{VALUE}++;
									$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{'not applicable'}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{PATCH_ELIGIBLE_OTHER}{HTML} = "<a href=\"$drilldown_dir/patch_eslSystemCI.pl?customer=$customer&status=$status&system_type=server_and_node&capability=$cap&center=$center&owner_flag=$owner&team=$team&eol_status=$eol_status&eligible=patch_mgt&patch_mgt=patch_mgt\">$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{'not applicable'}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{PATCH_ELIGIBLE_OTHER}{VALUE}</a>";

									$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{'not applicable'}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{PATCH_ELIGIBLE_OTHER}{VALUE}++;
									$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{'not applicable'}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{PATCH_ELIGIBLE_OTHER}{HTML} = "<a href=\"$drilldown_dir/patch_eslSystemCI.pl?customer=$customer&status=$status&system_type=server_and_node&capability=$cap&center=$center&owner_flag=$owner&team=$team&eol_status=ALL&eligible=patch_mgt&patch_mgt=patch_mgt\">$l2_bigfix_compliance{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{'not applicable'}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{PATCH_ELIGIBLE_OTHER}{VALUE}</a>";
								#}

							} ## End of Windows-Unix-Else loop
						}## End of Owners loop
					} ## End of Teams loop
				}# End For Caps loop
			} # End For fqdn loop
		} # End For Center loop
		#save_hash("$l3_filename", \%patch_summary, "$cache_dir/by_customer");
		undef %patch_summary;
	}# End customer

}
