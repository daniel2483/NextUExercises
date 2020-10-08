#!/usr/bin/perl

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
use Getopt::Std;

use lib '/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/modules';
use lib '/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/modules/pm';
use LoadCache;
use CommonFunctions;
use CommonColor;

use vars qw($cache_dir);
use vars qw($rawdata_dir);
use vars qw($cfg_dir);
use vars qw($drilldown_dir);
use vars qw($l2_report_dir);
use vars qw($green $red $amber $grey $orange $cyan $cgreen $lgrey $info $info2 $dgrey $violet $blue $voilet $lgolden $lblue $hpe);

my $start_time = time();

my $DEBUG = 0;  #Off

my %opts;
getopts('sc:', \%opts) || usage("invalid arguments");

my (@cust_list) = split(/\,/,$opts{"c"});
foreach my $n (@cust_list){
	$n=~s/^\s*//;
	$n=~s/\s*$//;
}
my %cust_list_hash = map { $_ => 1 } @cust_list;

# Declaration of global Variable
my %cache=();
my %l2_auto_details;
my %l2_auto;

my @list = ('account_reg','l2_inc_automation','l2_iaf','ucms_automation');
%cache = load_cache(\@list);

my %account_reg = %{$cache{account_reg}};
my %l2_inc_auto = %{$cache{l2_inc_automation}};
my %l2_iaf = %{$cache{l2_iaf}};
my %ucms = %{$cache{ucms_automation}};

my %l3_robots;
my %l3_rules;
my %l3_tasks;
my %l3_hpsa_jobs;
my %l3_rpa_jobs;

############################################################################
# Start generating metrics
############################################################################

if (not defined($opts{"s"})) {
	foreach my $customer (sort keys %account_reg) {

		next if (defined($opts{"c"}) and not defined($cust_list_hash{$customer}));

		####################################################
		# Get Enabled CI Count
		####################################################
		my (%esl_system_ci);

		my $file_name = "$account_reg{$customer}{sp_mapping_file}"."_esl_system_ci_by_fqdn";
		print "Unable to load $cache_dir/by_customer/$file_name \n" if (not -r "$cache_dir/by_customer/$file_name.storable");

		if (-r "$cache_dir/by_customer/$file_name.storable") {
			print "Loading $cache_dir/by_customer/$file_name\n" ;
			my $sys = load_cache_byFile("$cache_dir/by_customer/$file_name",1);
			%esl_system_ci = %{$sys};
		}

		foreach my $center (keys %{$esl_system_ci{$customer}}) {

			#For each FQDN
			foreach my $fqdn (keys %{$esl_system_ci{$customer}{$center}}) {

				my $ci_src = $esl_system_ci{$customer}{$center}{$fqdn}{CI_SOURCE} || 'ESL';;
				my $status = $esl_system_ci{$customer}{$center}{$fqdn}{STATUS};
				my $tax_cap = $esl_system_ci{$customer}{$center}{$fqdn}{OS_INSTANCE_TAX_CAP}; # || "windows";
				my $eva_enabled = $esl_system_ci{$customer}{$center}{$fqdn}{EVA_ENABLED} || 0;
				my $robot_enabled = $esl_system_ci{$customer}{$center}{$fqdn}{ROBOT_ENABLED} || 0;
				my $hpsa_enabled = 0;
				$hpsa_enabled = 1 if ($esl_system_ci{$customer}{$center}{$fqdn}{HPSA_MID} ne "null");

				my %teams;
				my %os_class;

				next if ($status !~ /in production/i);

				if (not defined($l2_auto{CUSTOMER}{$customer}{CI_SRC}{VALUE})) {
					$l2_auto{CUSTOMER}{$customer}{CI_SRC}{VALUE} = $ci_src;
				} else {
					$l2_auto{CUSTOMER}{$customer}{CI_SRC}{VALUE} .= ", $ci_src" if ($l2_auto{CUSTOMER}{$customer}{CI_SRC}{VALUE} !~ /$ci_src/i);
				}

				$os_class{ALL}=1;
				$os_class{$tax_cap} = 1;

				$teams{ALL} = 1;
				foreach my $os_instance (keys %{$esl_system_ci{$customer}{$center}{$fqdn}{ESL_ORG_CARD}}) {
					foreach my $esl_o (@{$esl_system_ci{$customer}{$center}{$fqdn}{ESL_ORG_CARD}{$os_instance}}) {
						next if ($esl_o->{ACTIVITY_NAME} !~ /incident management/i);

						$teams{$esl_o->{ORG_NM}} = 1;
					}
				}

				foreach my $capability (keys %os_class) {
					foreach my $team (keys %teams) {
						foreach my $owner ('ALL','OWNER','SSN','ESO4SAP_OWNED','ESO4SAP_USES','ECS') {
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{CI_TOTAL}{VALUE} ++;

							if ($robot_enabled == 1) {
								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{ROBOT_ENABLED}{VALUE} ++;
							}

							if ($eva_enabled == 1) {
								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{EVA_ENABLED}{VALUE} ++;
							}

							if ($hpsa_enabled == 1) {
								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{HPSA_ENABLED}{VALUE} ++;
							}
						}
					}
				}
			}
		}

		undef %esl_system_ci;

		foreach my $center ( keys %{$l2_auto{CUSTOMER}{$customer}{CENTER}}) {
			foreach my $capability ( keys %{$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}}) {
				foreach my $team ( keys %{$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}}) {
					foreach my $owner ('ALL','OWNER','SSN','ESO4SAP_OWNED','ESO4SAP_USES','ECS') {
						##########################################
						#  Get CI Metrics
						##########################################
						#my $total_ci = $l2_sys_ci{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{ALL}{CAPABILITY}{$capability}{TEAM}{$team}{STATUS}{'in production'}{EOL_STATUS}{ALL}{OWNER}{$owner}{COUNT}{VALUE} || 0;
						my $total_ci = $l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{CI_TOTAL}{VALUE} || 0;
						my $robot_enabled = $l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{ROBOT_ENABLED}{VALUE} || 0;
						my $eva_enabled = $l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{EVA_ENABLED}{VALUE} || 0;
						my $hpsa_enabled = $l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{HPSA_ENABLED}{VALUE} || 0;

						#$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{CI_TOTAL}{VALUE} = $total_ci;
  					#$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{CI_TOTAL}{HTML} = $l2_sys_ci{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{ALL}{CAPABILITY}{$capability}{TEAM}{$team}{STATUS}{'in production'}{EOL_STATUS}{ALL}{OWNER}{$owner}{COUNT}{HTML};


  					if ($total_ci > 0) {
  						my $robot_enabled_pct = sprintf "%0.1f", $robot_enabled / $total_ci * 100;
  						my $eva_enabled_pct = sprintf "%0.1f", $eva_enabled / $total_ci * 100;
  						my $hpsa_enabled_pct = sprintf "%0.1f", $hpsa_enabled / $total_ci * 100;

  						my $color = $green;
  						$color = $red if ($robot_enabled_pct > 0 and $robot_enabled_pct < 75);
  						$color = $info if ($robot_enabled_pct == 0);
  						$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{ROBOT_ENABLED_PCT}{VALUE} = $robot_enabled_pct;
  						if ($robot_enabled > 0) {
  							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{ROBOT_ENABLED_PCT}{HTML} = "<a href=\"$drilldown_dir/eslSystemCI.pl?customer=$customer&status=in production&system_type=all&capability=$capability&center=$center&team=$team&hw_eol_status=ALL&robot=yes_robot\">$robot_enabled_pct%</a>";
  						} else {
  							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{ROBOT_ENABLED_PCT}{HTML} = "0.0%";
  						}
  						$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{ROBOT_ENABLED_PCT}{COLOR} = $color;

  						my $color = $green;
  						$color = $red if ($eva_enabled_pct > 0 and $eva_enabled_pct < 75);
  						$color = $info if ($eva_enabled_pct == 0);
  						$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{EVA_ENABLED_PCT}{VALUE} = $eva_enabled_pct;
  						if ($eva_enabled > 0) {
  							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{EVA_ENABLED_PCT}{HTML} = "<a href=\"$drilldown_dir/eslSystemCI.pl?customer=$customer&status=in production&system_type=all&capability=$capability&center=$center&team=$team&hw_eol_status=ALL&eva=yes_eva\">$eva_enabled_pct%</a>";
  						} else {
  							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{EVA_ENABLED_PCT}{HTML} = "0.0%";
  						}
  						$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{EVA_ENABLED_PCT}{COLOR} = $color;

  						my $color = $green;
  						$color = $red if ($hpsa_enabled_pct > 0 and $hpsa_enabled_pct < 75);
  						$color = $info if ($hpsa_enabled_pct == 0);
  						$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{HPSA_ENABLED_PCT}{VALUE} = $hpsa_enabled_pct;
  						if ($hpsa_enabled > 0) {
  							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{HPSA_ENABLED_PCT}{HTML} = "<a href=\"$drilldown_dir/eslSystemCI.pl?customer=$customer&status=in production&system_type=all&capability=$capability&center=$center&team=$team&hw_eol_status=ALL&hpsa=yes_hpsa\">$hpsa_enabled_pct%</a>";
  						} else {
  							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{HPSA_ENABLED_PCT}{HTML} = "0.0%";
  						}
  						$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{HPSA_ENABLED_PCT}{COLOR} = $color;

  						$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{CI_TOTAL}{HTML} = "<a href=\"$drilldown_dir/eslSystemCI.pl?customer=$customer&status=in production&system_type=all&capability=$capability&center=$center&team=$team&hw_eol_status=ALL\">$total_ci</a>";
  					} else {
  						$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{CI_TOTAL}{HTML} = "0";
  					}
					}
				}
			}
		}
		
		####################################################
		# Get UCMS Custom Use Case Counts
		####################################################
		
		my $rba_usecase_count = 0;
		my $ares_usecase_count = 0;
		my $ima_usecase_count = 0;
		my $eva_usecase_count = 0;
		my $rpa_usecase_count = 0;
		my $ta_usecase_count = 0;
		my $iaf_usecase_count = 0;
		
		$rba_usecase_count = scalar keys %{$ucms{CUSTOMER}{$customer}{PROJECT}{RBA}{ASSET}} if (defined($ucms{CUSTOMER}{$customer}{PROJECT}{RBA}{ASSET}));
		$ares_usecase_count = scalar keys %{$ucms{CUSTOMER}{$customer}{PROJECT}{ARES}{ASSET}} if (defined($ucms{CUSTOMER}{$customer}{PROJECT}{ARES}{ASSET}));
		$eva_usecase_count = scalar keys %{$ucms{CUSTOMER}{$customer}{PROJECT}{EVA}{ASSET}} if (defined($ucms{CUSTOMER}{$customer}{PROJECT}{EVA}{ASSET}));
		$rpa_usecase_count = scalar keys %{$ucms{CUSTOMER}{$customer}{PROJECT}{RPA}{ASSET}} if (defined($ucms{CUSTOMER}{$customer}{PROJECT}{RPA}{ASSET}));
		$ta_usecase_count = scalar keys %{$ucms{CUSTOMER}{$customer}{PROJECT}{TA}{ASSET}} if (defined($ucms{CUSTOMER}{$customer}{PROJECT}{TA}{ASSET}));
		$iaf_usecase_count = scalar keys %{$ucms{CUSTOMER}{$customer}{PROJECT}{IAF}{ASSET}} if (defined($ucms{CUSTOMER}{$customer}{PROJECT}{IAF}{ASSET}));
		
		$ima_usecase_count = $rba_usecase_count + $ares_usecase_count;

		####################################################
		# Get IAF Data
		####################################################
		if (defined ($l2_iaf{CUSTOMER}{$customer}{EXECUTION_COUNT}{VALUE})) {
			foreach my $center (keys %{$l2_auto{CUSTOMER}{$customer}{CENTER}}) {
				foreach my $capability (keys %{$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}}) {
					foreach my $team (keys %{$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}}) {
						foreach my $owner ('ALL','OWNER','SSN','ESO4SAP_OWNED','ESO4SAP_USES','ECS') {
							my $raffia_enabled = $l2_iaf{CUSTOMER}{$customer}{ENROLLED_CI_COUNT}{VALUE} || 0;
							my $total_ci = $l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{CI_TOTAL}{VALUE} || 0;

							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{RAFFIA_ENABLED_COUNT}{VALUE} = $raffia_enabled;

							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{RAFFIA_EXEC_COUNT}{VALUE} = $l2_iaf{CUSTOMER}{$customer}{EXECUTION_COUNT}{VALUE};
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{RAFFIA_EXEC_COUNT}{HTML} = $l2_iaf{CUSTOMER}{$customer}{EXECUTION_COUNT}{HTML};

							#$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{PLAYBOOK_COUNT}{VALUE} = $l2_iaf{CUSTOMER}{$customer}{EXEC_PLAYBOOK_COUNT}{VALUE};
							#$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{PLAYBOOK_COUNT}{HTML} = $l2_iaf{CUSTOMER}{$customer}{EXEC_PLAYBOOK_COUNT}{HTML};

							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{TASK_SRC}{VALUE} = 'Raffia';
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{TASK_SRC}{HTML} = 'Raffia';

							if ($total_ci > 0) {
								my $raffia_enabled_pct = sprintf "%0.1f", $raffia_enabled / $total_ci * 100;

								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{RAFFIA_ENABLED_PCT}{VALUE} = $raffia_enabled_pct;
  							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{RAFFIA_ENABLED_PCT}{HTML} = "$raffia_enabled_pct%";
							}
						}
					}
				}
			}


			####################################################
			# Get Playbook Execution Data
			####################################################

			my (%iaf);

			my $file_name = "$account_reg{$customer}{sp_mapping_file}"."_iaf_details";
			print "Unable to load $cache_dir/by_customer/$file_name \n" if (not -r "$cache_dir/by_customer/$file_name.storable");

			if (-r "$cache_dir/by_customer/$file_name.storable") {
				print "Loading $cache_dir/by_customer/$file_name\n" ;
				my $sys = load_cache_byFile("$cache_dir/by_customer/$file_name",1);
				%iaf = %{$sys};
			}

			foreach my $key (keys %{$iaf{PLAY}}) {
				my $playbook = $iaf{PLAY}{$key}{TASK_NAME};

				foreach my $center (keys %{$l2_auto{CUSTOMER}{$customer}{CENTER}}) {
					foreach my $capability (keys %{$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}}) {
						foreach my $team (keys %{$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}}) {
							foreach my $owner ('ALL','OWNER','SSN','ESO4SAP_OWNED','ESO4SAP_USES','ECS') {

								$l3_tasks{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{SCOPE}{ALL}{TASKS}{$playbook}{TOTAL_EXEC} ++;
								$l3_tasks{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{SCOPE}{ALL}{TASKS}{$playbook}{SOURCE} = 'Raffia';

								#  Set Total IAF Task Count
								my $task_count = scalar keys %{$l3_tasks{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{SCOPE}{ALL}{TASKS}};
								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{IAF_COUNT}{VALUE} = $task_count;
								if ($task_count > 0) {
									$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{IAF_COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_automation.pl?customer=$customer&cap=$capability&team=$team&center=$center&status=in_production&eol=ALL&type=task&scope=ALL\">".$task_count."</a>";
								} else {
									$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{IAF_COUNT}{HTML} = '0';
								}
								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{IAF_COUNT}{COLOR} = $info;
								
								#  Set Custom IAF Use Case Count
								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{IAF_UC_COUNT}{COUNT} = $ima_usecase_count;
								if ($iaf_usecase_count > 0) {
									$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{IAF_UC_COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_ucms_assets.pl?customer=$customer&type=ima\">".$iaf_usecase_count."</a>";
								} else {
									$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{IAF_UC_COUNT}{HTML} = '0';
								}
								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{IAF_UC_COUNT}{COLOR} = $info;
							}
						}
					}
				}
			}
		}


		foreach my $center ( keys %{$l2_inc_auto{CUSTOMER}{$customer}{CENTER}}) {
			foreach my $capability ( keys %{$l2_inc_auto{CUSTOMER}{$customer}{CENTER}{$center}{CI_TYPE}{ALL}{CAPABILITY}}) {
				foreach my $team ( keys %{$l2_inc_auto{CUSTOMER}{$customer}{CENTER}{$center}{CI_TYPE}{ALL}{CAPABILITY}{$capability}{TEAM}}) {
					foreach my $owner ('ALL','OWNER','SSN','ESO4SAP_OWNED','ESO4SAP_USES','ECS') {
						##########################################
						#  Get Incident Metrics - Last 30 days
						##########################################
						if (defined($l2_inc_auto{CUSTOMER}{$customer}{CENTER}{$center}{CI_TYPE}{ALL}{CAPABILITY}{$capability}{TEAM}{$team}{STATUS}{ALL}{EOL_STATUS}{ALL}{INC_TOTAL}{VALUE})) {
							my $inc_total = 0;
							my $inc_success = 0;
							my $inc_diag = 0;
							$inc_total = $l2_inc_auto{CUSTOMER}{$customer}{CENTER}{$center}{CI_TYPE}{ALL}{CAPABILITY}{$capability}{TEAM}{$team}{STATUS}{ALL}{EOL_STATUS}{ALL}{INC_TOTAL}{VALUE} || 0;

							if ($inc_total > 0){

								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{INC_SRC}{VALUE} = $l2_inc_auto{CUSTOMER}{$customer}{CENTER}{$center}{CI_TYPE}{ALL}{CAPABILITY}{$capability}{TEAM}{$team}{STATUS}{ALL}{EOL_STATUS}{ALL}{SRC}{VALUE};
								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{ROBOT_SRC}{VALUE} = $l2_inc_auto{CUSTOMER}{$customer}{CENTER}{$center}{CI_TYPE}{ALL}{CAPABILITY}{$capability}{TEAM}{$team}{STATUS}{ALL}{EOL_STATUS}{ALL}{ROBOT_SRC}{VALUE};

								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{INC_TOTAL}{VALUE} = $inc_total;
								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{INC_TOTAL}{HTML} = $l2_inc_auto{CUSTOMER}{$customer}{CENTER}{$center}{CI_TYPE}{ALL}{CAPABILITY}{$capability}{TEAM}{$team}{STATUS}{ALL}{EOL_STATUS}{ALL}{INC_TOTAL}{HTML};
								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{INC_TOTAL}{COLOR} = $l2_inc_auto{CUSTOMER}{$customer}{CENTER}{$center}{CI_TYPE}{ALL}{CAPABILITY}{$capability}{TEAM}{$team}{STATUS}{ALL}{EOL_STATUS}{ALL}{INC_TOTAL}{COLOR};

								if (defined($l2_inc_auto{CUSTOMER}{$customer}{CENTER}{$center}{CI_TYPE}{ALL}{CAPABILITY}{$capability}{TEAM}{$team}{STATUS}{ALL}{EOL_STATUS}{ALL}{INC_SUCCESS}{VALUE})) {
									$inc_success = $l2_inc_auto{CUSTOMER}{$customer}{CENTER}{$center}{CI_TYPE}{ALL}{CAPABILITY}{$capability}{TEAM}{$team}{STATUS}{ALL}{EOL_STATUS}{ALL}{INC_SUCCESS}{VALUE} || 0;

									$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{FULL_AUTO}{VALUE} = $inc_success;

									my $inc_success_pct = sprintf "%0.1f", $inc_success / $inc_total * 100;
									$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{FULL_AUTO_PCT}{VALUE} = $inc_success_pct;
									if ($inc_success > 0 ) {
										$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{FULL_AUTO_PCT}{HTML} = "<a href=\"$drilldown_dir/l3_bionics_incident.pl?month_str=30days&customer=$customer&cap=$capability&team=$team&center=$center&type=robot_success\">".$inc_success_pct."%</a>";
										my $color = $green;
										$color = $amber if($inc_success_pct < 15 && $inc_total > 0);
										$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{FULL_AUTO_PCT}{COLOR} = $color;
									} else {
										$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{FULL_AUTO_PCT}{HTML} = $inc_success_pct.'%';
										my $color = $info;
										$color = $amber if($inc_total > 0);
										$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{FULL_AUTO_PCT}{COLOR} = $color;
									}
								}

								if (defined($l2_inc_auto{CUSTOMER}{$customer}{CENTER}{$center}{CI_TYPE}{ALL}{CAPABILITY}{$capability}{TEAM}{$team}{STATUS}{ALL}{EOL_STATUS}{ALL}{INC_DIAG}{VALUE})) {
									$inc_diag = $l2_inc_auto{CUSTOMER}{$customer}{CENTER}{$center}{CI_TYPE}{ALL}{CAPABILITY}{$capability}{TEAM}{$team}{STATUS}{ALL}{EOL_STATUS}{ALL}{INC_DIAG}{VALUE} || 0;
									my $robot = $inc_success + $inc_diag;

									$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{ROBOT}{VALUE} = $robot;

									my $robot_pct = sprintf "%0.1f", $robot / $inc_total * 100;
									$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{ROBOT_PCT}{VALUE} = $robot_pct;

									if ($robot > 0 ) {
										$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{ROBOT_PCT}{HTML} = "<a href=\"$drilldown_dir/l3_bionics_incident.pl?month_str=30days&customer=$customer&cap=$capability&team=$team&center=$center&type=robot_touch\">".$robot_pct."%</a>";
										my $color = $green;
										$color = $amber if($robot_pct < 75 && $inc_total > 0);
										$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{OWNER}{$owner}{ALL}{ROBOT_PCT}{COLOR} = $color;
									} else {
										$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{ROBOT_PCT}{HTML} = $robot_pct.'%';
										my $color = $info;
										$color = $amber if($inc_total > 0);
										$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{ROBOT_PCT}{COLOR} = $color;
									}
								}
							}
						}
					}
				}
			}
		}
		

		####################################################
		# Get RBA and ARES Flow Data
		####################################################
		my (%robot_flows);

		my $file_name = "$account_reg{$customer}{sp_mapping_file}"."_rba_flow_list_30days";
		print "Unable to load $cache_dir/by_customer/$file_name \n" if (not -r "$cache_dir/by_customer/$file_name.storable");

		if (-r "$cache_dir/by_customer/$file_name.storable") {
			print "Loading $cache_dir/by_customer/$file_name\n" ;
			my $sys = load_cache_byFile("$cache_dir/by_customer/$file_name",1);
			%robot_flows = %{$sys};
		}


		foreach my $center ( keys %{$robot_flows{$customer}}) {
			foreach my $capability (keys %{$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}}) {
				# Note that the rba_flow_exec cache does not have a capability dimension so set same value for each capability in l2_auto cache
				foreach my $team ( keys %{$robot_flows{$customer}{$center}{ALL}{ALL}}) {
					foreach my $flow ( keys %{$robot_flows{$customer}{$center}{ALL}{ALL}{$team}{ALL}{ALL}{FLOW}}) {
						foreach my $owner ('ALL','OWNER','SSN','ESO4SAP_OWNED','ESO4SAP_USES','ECS') {
							my $robot_exec_count = 0;

							foreach my $flow_status ( keys %{$robot_flows{$customer}{$center}{ALL}{ALL}{$team}{ALL}{ALL}{FLOW}{$flow}{STATUS}}) {
								$robot_exec_count += $robot_flows{$customer}{$center}{ALL}{ALL}{$team}{ALL}{ALL}{FLOW}{$flow}{STATUS}{$flow_status}{FLOW_COUNT};
								my $scope;
								$scope = 'custom' if ($robot_flows{$customer}{$center}{ALL}{ALL}{$team}{ALL}{ALL}{FLOW}{$flow}{STATUS}{$flow_status}{CUSTOM} =~ /TRUE/i);
								$scope = 'generic' if ($robot_flows{$customer}{$center}{ALL}{ALL}{$team}{ALL}{ALL}{FLOW}{$flow}{STATUS}{$flow_status} !~ /TRUE/i);
								$l3_robots{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{SCOPE}{ALL}{ROBOTS}{$flow}{TOTAL_ROBOT_EXEC} = $robot_exec_count;
								$l3_robots{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{SCOPE}{$scope}{ROBOTS}{$flow}{TOTAL_ROBOT_EXEC} = $robot_exec_count;
							}

							#  Set Total Robot Count
							my $robot_count = scalar keys %{$l3_robots{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{SCOPE}{ALL}{ROBOTS}};
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{ROBOT_COUNT}{VALUE} = $robot_count;

							if ($robot_count > 0 ) {
								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{ROBOT_COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_automation.pl?customer=$customer&cap=$capability&team=$team&center=$center&status=in_production&eol=ALL&type=incident&scope=ALL\">".$robot_count."</a>";
							} else {
								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{ROBOT_COUNT}{HTML} = '0';
							}
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{ROBOT_COUNT}{COLOR} = $info;

							#  Set Generic Robot Count
							my $generic_robot_count = scalar keys %{$l3_robots{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{SCOPE}{generic}{ROBOTS}};
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{GENERIC_ROBOT_COUNT}{VALUE} = $generic_robot_count;

							if ($generic_robot_count > 0 ) {
								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{GENERIC_ROBOT_COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_automation.pl?customer=$customer&cap=$capability&team=$team&center=$center&status=in_production&eol=ALL&type=incident&scope=generic\">".$generic_robot_count."</a>";
							} else {
								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{GENERIC_ROBOT_COUNT}{HTML} = '0';
							}
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{GENERIC_ROBOT_COUNT}{COLOR} = $info;

							#  Set Custom Robot Count
							my $custom_robot_count = scalar keys %{$l3_robots{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{SCOPE}{custom}{ROBOTS}};
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{CUSTOM_ROBOT_COUNT}{VALUE} = $custom_robot_count;

							if ($custom_robot_count > 0 ) {
								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{CUSTOM_ROBOT_COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_automation.pl?customer=$customer&cap=$capability&team=$team&center=$center&status=in_production&eol=ALL&type=incident&scope=custom\">".$custom_robot_count."</a>";
							} else {
								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{CUSTOM_ROBOT_COUNT}{HTML} = '0';
							}
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{CUSTOM_ROBOT_COUNT}{COLOR} = $info;
							
							#  Set Custom Robot Use Case Count
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{IMA_UC_COUNT}{COUNT} = $ima_usecase_count;
							if ($ima_usecase_count > 0) {
								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{IMA_UC_COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_ucms_assets.pl?customer=$customer&type=ima\">".$ima_usecase_count."</a>";
							} else {
								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{IMA_UC_COUNT}{HTML} = '0';
							}
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{IMA_UC_COUNT}{COLOR} = $info;
						}
					}
				}
			}
		}

		undef %robot_flows;


		####################################################
		# Get Event Data
		####################################################
		my %ab_actions;

		my $file_name = "$account_reg{$customer}{sp_mapping_file}"."_ab_actions";
		print "Unable to load $cache_dir/by_customer/$file_name \n" if (not -r "$cache_dir/by_customer/$file_name.storable");

		if (-r "$cache_dir/by_customer/$file_name.storable") {
			print "Loading $cache_dir/by_customer/$file_name\n" ;
			my $sys = load_cache_byFile("$cache_dir/by_customer/$file_name",1);
			%ab_actions = %{$sys};
		}

		foreach my $center ( keys %{$ab_actions{$customer}}) {
			foreach my $capability ( keys %{$ab_actions{$customer}{$center}{ALL}}) {
				foreach my $team ( keys %{$ab_actions{$customer}{$center}{ALL}{$capability}}) {
					foreach my $owner ('ALL','OWNER','SSN','ESO4SAP_OWNED','ESO4SAP_USES','ECS') {

						####################################################
						# Get Events Data , correlations and suppressions
						####################################################

						my $event_total = $ab_actions{$customer}{$center}{ALL}{$capability}{$team}{ALL}{ALL}{ACTION}{ALL}{TOTAL_ALERTS} || 0;
						if ($event_total > 0) {
							my $event_correlations = $ab_actions{$customer}{$center}{ALL}{$capability}{$team}{ALL}{ALL}{ACTION}{correlate}{TOTAL_ALERTS} || 0;
							my $event_supressions =$ab_actions{$customer}{$center}{ALL}{$capability}{$team}{ALL}{ALL}{ACTION}{suppress}{TOTAL_ALERTS} || 0;
							my $event_create_inc =$ab_actions{$customer}{$center}{ALL}{$capability}{$team}{ALL}{ALL}{ACTION}{create_incident}{TOTAL_ALERTS} || 0;
							my $event_filtered = $event_correlations + $event_supressions;

							my $event_filtered_pct =  sprintf "%0.1f", $event_filtered / $event_total * 100;
							my $incidents_created_pct =  sprintf "%0.1f", $event_create_inc / $event_total * 100;

							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{TOTAL_EVENTS}{VALUE} = $event_total;
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILTERED_EVENTS}{VALUE} = $event_filtered;
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILTERED_EVENTS_PCT}{VALUE} = $event_filtered_pct;
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{INCIDENTS_CREATED}{VALUE} = $event_create_inc;
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{INCIDENTS_CREATED_PCT}{VALUE} = $incidents_created_pct;

							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{TOTAL_EVENTS}{HTML} = $event_total;
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILTERED_EVENTS}{HTML} = $event_filtered;
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{FILTERED_EVENTS_PCT}{HTML} = $event_filtered_pct.'%';
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{INCIDENTS_CREATED_PCT}{HTML} = $incidents_created_pct.'%';


							####################################################
							# Get Events Rule Data
							####################################################
							foreach my $rule ( keys %{$ab_actions{$customer}{$center}{ALL}{$capability}{$team}{ALL}{ALL}{RULE}}) {
								my $rule_alerts = $ab_actions{$customer}{$center}{ALL}{$capability}{$team}{ALL}{ALL}{RULE}{$rule}{TOTAL_ALERTS};
								my $scope;
								$scope = 'custom' if ($ab_actions{$customer}{$center}{ALL}{$capability}{$team}{ALL}{ALL}{RULE}{$rule}{CUSTOM} =~ /TRUE/i);
								$scope = 'generic' if ($ab_actions{$customer}{$center}{ALL}{$capability}{$team}{ALL}{ALL}{RULE}{$rule}{CUSTOM} !~ /TRUE/i);

								$l3_rules{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{SCOPE}{ALL}{RULES}{$rule}{TOTAL_ALERTS} = $rule_alerts;
								$l3_rules{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{SCOPE}{$scope}{RULES}{$rule}{TOTAL_ALERTS} = $rule_alerts;
							}

							#  Set Total Rule Count
							my $rule_count = scalar keys %{$l3_rules{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{SCOPE}{ALL}{RULES}};
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{RULE_COUNT}{VALUE} = $rule_count;

							if ($rule_count > 0) {
								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{RULE_COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_automation.pl?customer=$customer&cap=$capability&team=$team&center=$center&status=in_production&eol=ALL&type=event&scope=ALL\">".$rule_count."</a>";
							} else {
								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{RULE_COUNT}{HTML} = '0';
							}
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{RULE_COUNT}{COLOR} = $info;

							#  Set Generic Rule Count
							my $gen_rule_count = scalar keys %{$l3_rules{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{SCOPE}{generic}{RULES}};
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{GENERIC_RULE_COUNT}{VALUE} = $gen_rule_count;

							if ($gen_rule_count > 0) {
								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{GENERIC_RULE_COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_automation.pl?customer=$customer&cap=$capability&team=$team&center=$center&status=in_production&eol=ALL&type=event&scope=generic\">".$gen_rule_count."</a>";
							} else {
								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{GENERIC_RULE_COUNT}{HTML} = '0';
							}
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{GENERIC_RULE_COUNT}{COLOR} = $info;

							#  Set Custom Rule Count
							my $cust_rule_count = scalar keys %{$l3_rules{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{SCOPE}{custom}{RULES}};
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{CUSTOM_RULE_COUNT}{VALUE} = $cust_rule_count;

							if ($cust_rule_count > 0) {
								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{CUSTOM_RULE_COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_automation.pl?customer=$customer&cap=$capability&team=$team&center=$center&status=in_production&eol=ALL&type=event&scope=custom\">".$cust_rule_count."</a>";
							} else {
								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{CUSTOM_RULE_COUNT}{HTML} = '0';
							}
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{CUSTOM_RULE_COUNT}{COLOR} = $info;


							#  Set Custom Rule Use Case Count
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{EVA_UC_COUNT}{COUNT} = $eva_usecase_count;
							if ($eva_usecase_count > 0) {
								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{EVA_UC_COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_ucms_assets.pl?customer=$customer&type=eva\">".$eva_usecase_count."</a>";
							} else {
								$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{EVA_UC_COUNT}{HTML} = '0';
							}
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{EVA_UC_COUNT}{COLOR} = $info;

						}
					}
				}
			}
		}

		undef %ab_actions;
		
		####################################################
		# Get HPSA Script Jobs
		####################################################
		my %hpsa_jobs;
		my %tmp_jobs;

		my $file_name = "$account_reg{$customer}{sp_mapping_file}"."_hpsa_script_jobs";
		print "Unable to load $cache_dir/by_customer/$file_name \n" if (not -r "$cache_dir/by_customer/$file_name.storable");

		if (-r "$cache_dir/by_customer/$file_name.storable") {
			print "Loading $cache_dir/by_customer/$file_name\n" ;
			my $sys = load_cache_byFile("$cache_dir/by_customer/$file_name",1);
			%hpsa_jobs = %{$sys};
		}
		
		foreach my $job_id (keys %{$hpsa_jobs{CUSTOMER}{$customer}{JOB_ID}}) {
			my $script = $hpsa_jobs{CUSTOMER}{$customer}{JOB_ID}{$job_id}{SCRIPT};
			my $scope;
			$scope = 'custom' if ($hpsa_jobs{CUSTOMER}{$customer}{JOB_ID}{$job_id}{CUSTOM} =~ /TRUE/i);
			$scope = 'generic' if ($hpsa_jobs{CUSTOMER}{$customer}{JOB_ID}{$job_id}{CUSTOM} !~ /TRUE/i);
								
			$tmp_jobs{$customer}{JOB_COUNT} ++;
			$tmp_jobs{$customer}{SCOPE}{ALL}{SCRIPTS}{$script}{JOB_COUNT} ++;
			$tmp_jobs{$customer}{SCOPE}{$scope}{SCRIPTS}{$script}{JOB_COUNT} ++;
		}
		
		foreach my $center ( keys %{$l2_inc_auto{CUSTOMER}{$customer}{CENTER}}) {
			foreach my $capability ( keys %{$l2_inc_auto{CUSTOMER}{$customer}{CENTER}{$center}{CI_TYPE}{ALL}{CAPABILITY}}) {
				foreach my $team ( keys %{$l2_inc_auto{CUSTOMER}{$customer}{CENTER}{$center}{CI_TYPE}{ALL}{CAPABILITY}{$capability}{TEAM}}) {
					foreach my $owner ('ALL','OWNER','SSN','ESO4SAP_OWNED','ESO4SAP_USES','ECS') {

						foreach my $scope (keys %{$tmp_jobs{$customer}{SCOPE}}) {
							foreach my $script (keys %{$tmp_jobs{$customer}{SCOPE}{$scope}{SCRIPTS}}) {
								my $job_count = $tmp_jobs{$customer}{SCOPE}{$scope}{SCRIPTS}{$script}{JOB_COUNT} || 0;
								$l3_hpsa_jobs{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{SCOPE}{$scope}{SCRIPTS}{$script}{TOTAL_JOBS} = $job_count;
							}
						}
						
						my $total_jobs = $tmp_jobs{$customer}{JOB_COUNT} || 0;
						$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{TOTAL_JOBS}{VALUE} = $total_jobs;
						
						if ($total_jobs > 0) {
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{TOTAL_JOBS}{HTML} = "<a href=\"$drilldown_dir/l3_hpsa_jobs.pl?customer=$customer\">".$total_jobs."</a>";$total_jobs;
						} else {
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{TOTAL_JOBS}{HTML} = 0;
						}
						
						#  Set Total Job Count
						my $job_count = scalar keys%{$tmp_jobs{$customer}{SCOPE}{ALL}{SCRIPTS}};
						$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{JOB_COUNT}{VALUE} = $job_count;
						
						if ($job_count > 0) {
							my $task_src = $l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{TASK_SRC}{VALUE};
							if ($task_src eq '') {
								$task_src = 'HPSA';
							} else {
								$task_src .= ', HPSA' if ($task_src !~ /HPSA/);
							}
							
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{TASK_SRC}{VALUE} = $task_src;
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{TASK_SRC}{HTML} = $task_src;
							
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{JOB_COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_automation.pl?customer=$customer&cap=$capability&team=$team&center=$center&status=in_production&eol=ALL&type=hpsa&scope=ALL\">".$job_count."</a>";
						} else {
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{JOB_COUNT}{HTML} = '0';
						}
						$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{JOB_COUNT}{COLOR} = $info;
						
						#  Set Generic Job Count
						my $generic_job_count = scalar keys%{$tmp_jobs{$customer}{SCOPE}{generic}{SCRIPTS}};
						$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{GENERIC_JOB_COUNT}{VALUE} = $generic_job_count;
						
						if ($generic_job_count > 0) {
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{GENERIC_JOB_COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_automation.pl?customer=$customer&cap=$capability&team=$team&center=$center&status=in_production&eol=ALL&type=hpsa&scope=generic\">".$generic_job_count."</a>";
						} else {
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{GENERIC_JOB_COUNT}{HTML} = '0';
						}
						$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{GENERIC_JOB_COUNT}{COLOR} = $info;
						
						#  Set Custom Job Count
						my $custom_job_count = scalar keys%{$tmp_jobs{$customer}{SCOPE}{custom}{SCRIPTS}};
						$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{CUSTOM_JOB_COUNT}{VALUE} = $custom_job_count;
						
						if ($custom_job_count > 0) {
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{CUSTOM_JOB_COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_automation.pl?customer=$customer&cap=$capability&team=$team&center=$center&status=in_production&eol=ALL&type=hpsa&scope=custom\">".$custom_job_count."</a>";
						} else {
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{CUSTOM_JOB_COUNT}{HTML} = '0';
						}
						$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{CUSTOM_JOB_COUNT}{COLOR} = $info;
						
						#  Set Custom Script Use Case Count
						$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{TA_UC_COUNT}{COUNT} = $ta_usecase_count;
						if ($ta_usecase_count > 0) {
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{TA_UC_COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_ucms_assets.pl?customer=$customer&type=ta\">".$ta_usecase_count."</a>";
						} else {
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{TA_UC_COUNT}{HTML} = '0';
						}
						$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{TA_UC_COUNT}{COLOR} = $info;
					}
				}
			}
		}
		
		undef %hpsa_jobs;
		undef %tmp_jobs;
		
		####################################################
		# Get RPA Jobs
		####################################################
		my %rpa_jobs;
		my %tmp_rpa_jobs;

		my $file_name = "$account_reg{$customer}{sp_mapping_file}"."_rpa_jobs";
		print "Unable to load $cache_dir/by_customer/$file_name \n" if (not -r "$cache_dir/by_customer/$file_name.storable");

		if (-r "$cache_dir/by_customer/$file_name.storable") {
			print "Loading $cache_dir/by_customer/$file_name\n" ;
			my $sys = load_cache_byFile("$cache_dir/by_customer/$file_name",1);
			%rpa_jobs = %{$sys};
		}
		
		foreach my $job_id (keys %{$rpa_jobs{CUSTOMER}{$customer}{JOB_ID}}) {
			my $script = $rpa_jobs{CUSTOMER}{$customer}{JOB_ID}{$job_id}{JOB_NAME};
			my $scope;
			$scope = 'custom' if ($rpa_jobs{CUSTOMER}{$customer}{JOB_ID}{$job_id}{CUSTOM} =~ /TRUE/i);
			$scope = 'generic' if ($rpa_jobs{CUSTOMER}{$customer}{JOB_ID}{$job_id}{CUSTOM} !~ /TRUE/i);
								
			$tmp_rpa_jobs{$customer}{JOB_COUNT} ++;
			$tmp_rpa_jobs{$customer}{SCOPE}{ALL}{SCRIPTS}{$script}{JOB_COUNT} ++;
			$tmp_rpa_jobs{$customer}{SCOPE}{$scope}{SCRIPTS}{$script}{JOB_COUNT} ++;
		}
	
		
		foreach my $center ( keys %{$l2_inc_auto{CUSTOMER}{$customer}{CENTER}}) {
			foreach my $capability ( keys %{$l2_inc_auto{CUSTOMER}{$customer}{CENTER}{$center}{CI_TYPE}{ALL}{CAPABILITY}}) {
				foreach my $team ( keys %{$l2_inc_auto{CUSTOMER}{$customer}{CENTER}{$center}{CI_TYPE}{ALL}{CAPABILITY}{$capability}{TEAM}}) {
					foreach my $owner ('ALL','OWNER','SSN','ESO4SAP_OWNED','ESO4SAP_USES','ECS') {

						foreach my $scope (keys %{$tmp_rpa_jobs{$customer}{SCOPE}}) {
							foreach my $script (keys %{$tmp_rpa_jobs{$customer}{SCOPE}{$scope}{SCRIPTS}}) {
								my $job_count = $tmp_rpa_jobs{$customer}{SCOPE}{$scope}{SCRIPTS}{$script}{JOB_COUNT} || 0;
								$l3_rpa_jobs{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{SCOPE}{$scope}{SCRIPTS}{$script}{TOTAL_JOBS} = $job_count;
							}
						}
						
						my $total_jobs = $tmp_rpa_jobs{$customer}{JOB_COUNT} || 0;
						
						$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{TOTAL_RPA_JOBS}{VALUE} = $total_jobs;
						
						if ($total_jobs > 0) {
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{TOTAL_RPA_JOBS}{HTML} = "<a href=\"$drilldown_dir/l3_rpa_jobs.pl?customer=$customer\">".$total_jobs."</a>";$total_jobs;
						} else {
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{TOTAL_RPA_JOBS}{HTML} = 0;
						}
						
						#  Set Total Job Count
						my $job_count = scalar keys%{$tmp_rpa_jobs{$customer}{SCOPE}{ALL}{SCRIPTS}};
						$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{RPA_JOB_COUNT}{VALUE} = $job_count;

						
						if ($job_count > 0) {
							my $task_src = $l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{RPA_SRC}{VALUE};
							if ($task_src eq '') {
								$task_src = 'WinAutomation';
							} else {
								$task_src .= ', WinAutomation' if ($task_src !~ /WinAutomation/);
							}
							
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{RPA_SRC}{VALUE} = $task_src;
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{RPA_SRC}{HTML} = $task_src;
							
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{RPA_JOB_COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_automation.pl?customer=$customer&cap=$capability&team=$team&center=$center&status=in_production&eol=ALL&type=rpa&scope=ALL\">".$job_count."</a>";
						} else {
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{RPA_JOB_COUNT}{HTML} = '0';
						}
						$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{RPA_JOB_COUNT}{COLOR} = $info;
						
						#  Set Generic Job Count
						my $generic_job_count = scalar keys%{$tmp_rpa_jobs{$customer}{SCOPE}{generic}{SCRIPTS}};
						$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{GENERIC_RPA_JOB_COUNT}{VALUE} = $generic_job_count;
						
						if ($generic_job_count > 0) {
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{GENERIC_RPA_JOB_COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_automation.pl?customer=$customer&cap=$capability&team=$team&center=$center&status=in_production&eol=ALL&type=rpa&scope=generic\">".$generic_job_count."</a>";
						} else {
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{GENERIC_RPA_JOB_COUNT}{HTML} = '0';
						}
						$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{GENERIC_RPA_JOB_COUNT}{COLOR} = $info;
						
						#  Set Custom Job Count
						my $custom_job_count = scalar keys%{$tmp_rpa_jobs{$customer}{SCOPE}{custom}{SCRIPTS}};
						$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{CUSTOM_RPA_JOB_COUNT}{VALUE} = $custom_job_count;
						
						if ($custom_job_count > 0) {
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{CUSTOM_RPA_JOB_COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_automation.pl?customer=$customer&cap=$capability&team=$team&center=$center&status=in_production&eol=ALL&type=rpa&scope=custom\">".$custom_job_count."</a>";
						} else {
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{CUSTOM_RPA_JOB_COUNT}{HTML} = '0';
						}
						$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{CUSTOM_RPA_JOB_COUNT}{COLOR} = $info;
						
						#  Set Custom RPA Use Case Count
						$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{RPA_UC_COUNT}{COUNT} = $rpa_usecase_count;
						if ($rpa_usecase_count > 0) {
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{RPA_UC_COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_ucms_assets.pl?customer=$customer&type=rpa\">".$rpa_usecase_count."</a>";
						} else {
							$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{RPA_UC_COUNT}{HTML} = '0';
						}
						$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{RPA_UC_COUNT}{COLOR} = $info;
					}
				}
			}
		}
		
		undef %rpa_jobs;
		undef %tmp_rpa_jobs;
		
	}
	

	undef %l2_inc_auto;
	save_hash("cache.l2_automation", \%l2_auto,"$cache_dir/l2_cache");
	undef %l2_auto;

	save_hash("cache.l3_auto_inc_robots", \%l3_robots,"$cache_dir/l3_cache");
	undef %l3_robots;

	save_hash("cache.l3_auto_eva_rules", \%l3_rules,"$cache_dir/l3_cache");
	undef %l3_rules;

	save_hash("cache.l3_auto_tasks", \%l3_tasks,"$cache_dir/l3_cache");
	undef %l3_tasks;
	
	save_hash("cache.l3_auto_hpsa_jobs", \%l3_hpsa_jobs,"$cache_dir/l3_cache");
	undef %l3_hpsa_jobs;
	
	save_hash("cache.l3_auto_rpa_jobs", \%l3_rpa_jobs,"$cache_dir/l3_cache");
	undef %l3_rpa_jobs;


} else {
		# Split L2 Incidents cache

	my $auto = load_cache_byFile("$cache_dir/l2_cache/cache.l2_automation",1);
  my %l2_auto = %{$auto};

 	save_hash("cache.l2_automation", \%l2_auto,"$cache_dir/l2_cache");


  #PERFORMANCE ENHANCEMENTS
  my %menu_filters;
  my %tmp;

  #$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$capability}{TEAM}{$team}{EOL_STATUS}{ALL}{OWNER}{$owner}{INC_TOTAL}{VALUE}
  #$l2_auto{CUSTOMER}{$customer}{CI_SRC}{VALUE}

  foreach my $customer (keys %{$l2_auto{CUSTOMER}}) {
  	foreach my $center (keys %{$l2_auto{CUSTOMER}{$customer}{CENTER}}) {

  		my $c_str = $center;
  		$c_str =~ s/\:/\_/g;
  		foreach my $tax_cap (keys %{$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}}) {
  			foreach my $team (keys %{$l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$tax_cap}{TEAM}}) {
  				my $t_str = $team;
  				$t_str =~ s/\W//g;
  				$t_str = substr($t_str,0,25);

  				my $file = "l2_auto-$c_str-$t_str";

  				$tmp{FILE}{$file}{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$tax_cap}{TEAM}{$team} = $l2_auto{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$tax_cap}{TEAM}{$team};

  			}
  		}
  	}
  }

	# Creating the menu filters called menu_filters-l2_auto files
  foreach my $file (keys %{$tmp{FILE}}) {
  	my %t2;
  	foreach my $customer (keys %{$tmp{FILE}{$file}{CUSTOMER}}) {
  		$t2{CUSTOMER}{$customer}{CI_SRC}{VALUE} = $l2_auto{CUSTOMER}{$customer}{CI_SRC}{VALUE};
  		
  		foreach my $center (keys %{$tmp{FILE}{$file}{CUSTOMER}{$customer}{CENTER}}) {
  			foreach my $tax_cap (keys %{$tmp{FILE}{$file}{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}}) {
  				foreach my $team (keys %{$tmp{FILE}{$file}{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$tax_cap}{TEAM}}) {
  					$t2{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$tax_cap}{TEAM}{$team} = $tmp{FILE}{$file}{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$tax_cap}{TEAM}{$team};
  					
  					$menu_filters{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$tax_cap}{TEAM}{$team}="$file";
  					$menu_filters{CUSTOMER}{ALL}{CENTER}{$center}{CAPABILITY}{$tax_cap}{TEAM}{$team}="$file";

  				}
  			}
  		}
  	}

  	save_hash("$file", \%t2,"$cache_dir/l2_cache/by_filters");
  }

  save_hash("menu_filters-l2_auto", \%menu_filters, "$cache_dir/l2_cache/by_filters");

  undef %tmp;
 	undef %l2_auto;
 	undef %menu_filters;
 	undef $auto;
}


my $end_time = time();
printf "Completed Processing after %0.1f Mins\n", ($end_time - $start_time) / 60;

sub usage
{
	my ($err_str) = @_;

	print "create_l2_incidents [-c \"customer1,customer2\"] [-h <30days|MON-YY>]\n";
	print "-c only process specified customer(s)\n";
	exit;

}
