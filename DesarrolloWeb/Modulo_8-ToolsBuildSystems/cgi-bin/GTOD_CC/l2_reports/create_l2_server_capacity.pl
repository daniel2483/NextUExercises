#!/usr/bin/perl
##
use strict;
use Sys::Hostname;
use File::Basename;
use File::Temp "tempfile";
use CGI qw(:standard);
use FileHandle;
use Data::Dumper;
use Time::Local;
use POSIX qw(strftime);
use Getopt::Std;

use lib '/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/modules/pm';
use LoadCache;
use CommonFunctions;
use CommonColor;

use vars qw($cache_dir);
use vars qw($rawdata_dir);
use vars qw($cfg_dir);
use vars qw($l2_report_dir);
use vars qw($drilldown_dir);

use vars qw($green $red $amber);

#my $debug_cust = 'bp';

my $start_time = time();

my %opts;
getopts('sc:p', \%opts) || usage("invalid arguments");

my @list = ( 'l2_system_baseline', 'server_capacity', 'account_reg','system_monitoring_names');
push @list, 'l2_server_capacity' if (defined($opts{c}));
push @list, 'l2_server_memcpu' if (defined($opts{c}));
my %cache = load_cache(\@list);

my %account_reg = %{$cache{account_reg}};
my %server_capacity = %{$cache{server_capacity}};


my %l2_baseline = %{$cache{l2_system_baseline}};
#my %l2_incidents = %{$cache{l2_incidents}};
my %system_monitoring_names = %{$cache{system_monitoring_names}};

# Reading the Cache files for memcpu and capacity (filesystem)
my %l2_server_capacity;
my %l2_server_memcpu;
%l2_server_capacity =  %{$cache{l2_server_capacity}} if (defined($opts{c}));
%l2_server_memcpu =  %{$cache{l2_server_memcpu}} if (defined($opts{c}));

my %system_monitoring_names;
my %incid_by_node = undef;
my %counted_fqdn;
my %counted_fqdn_fs;
my %counted_fqdn_perf;
my %counted_fqdn_all;
my %counted_fqdn_mon;
my %counted_fqdn_cust;

my %incid_totals;

# If is not storing
if (!defined($opts{s})) {

	# Declaration of global Variable, Processing by customer list separated by comma
	my (@cust_list) = split(/\,/,$opts{"c"});
	foreach my $n (@cust_list){
		$n=~s/^\s*//;
		$n=~s/\s*$//;
		undef ($l2_server_capacity{CUSTOMER}{$n});
	}
	my %cust_list_hash = map { $_ => 1 } @cust_list;

	my $count=1;

	my $esl_system_ci = undef;
	my $incid_details_ref;
	my $class;

	foreach my $customer (sort keys %account_reg) {
		undef($incid_details_ref);
		undef(%incid_by_node);
		my $mapping = $account_reg{$customer}{sp_mapping_file};
		my $file_name = "$account_reg{$customer}{sp_mapping_file}"."_esl_system_ci_by_fqdn";
		my $sys;
		my %esl_system_ci;

		my $incid_details_file = $account_reg{$customer}{sp_mapping_file} . "_ebi_incident_details_30days";

		# Output files by customer
		my $capacity_file = "$account_reg{$customer}{sp_mapping_file}"."_server_capacity_30_DAYS";
		my $memcpu_file = "$account_reg{$customer}{sp_mapping_file}"."_server_memcpu_30_DAYS";

		#Process Capacity Data for this Customer
		if (-r "$cache_dir/by_customer/$capacity_file"){
			if(not -r "$cache_dir/by_customer/$file_name"){
				print "No ESL CI Data for $customer, checking for server_capacity data...\n";
				nonesl_account_fs($customer);
			}else{
				print "Found CI Data for $customer - $cache_dir/by_customer/$file_name , checking for server_capacity data...\n";
				$sys =  load_cache_byFile("$cache_dir/by_customer/$file_name");
				%esl_system_ci = %{$sys};
				fs($customer, \%esl_system_ci);
			}
			create_chartdata_fs($customer);
		}

		#Process Memory CPU Data for this Customer
		if (-r "$cache_dir/by_customer/$memcpu_file"){
			if(not -r "$cache_dir/by_customer/$file_name"){
				print "No ESL CI Data for $customer, checking for server_memcpu data...\n";
				nonesl_account_memcpu($customer);
			}else{
				print "Found CI Data for $customer, checking for server_memcpu data...\n";
				$sys =  load_cache_byFile("$cache_dir/by_customer/$file_name");
				%esl_system_ci = %{$sys};
				memcpu($customer, \%esl_system_ci);
			}
			create_chartdata_memcpu($customer);
		}

		#Process Performance Incidents Data for this Customer is there was Capacity or Memory/CPU data
		if(-r "$cache_dir/by_customer/$memcpu_file" or -r "$cache_dir/by_customer/$capacity_file"){
			print STDERR "Processing: $customer - $count iterations\n";
			$incid_details_ref =  load_cache_byFile("$cache_dir/by_customer/$incid_details_file");
			undef(%incid_by_node);
			get_incid_by_node(\%incid_by_node, \%esl_system_ci, $incid_details_ref, $customer);
			get_incident_counts(\%incid_by_node, \%esl_system_ci, $incid_details_ref, $customer,$mapping,$count);
		}else{
			#print "No Capacity or Memory/CPU data for $customer...\n";
			next;
		}

	}


	$l2_server_capacity{NODATA}=1 if(! %l2_server_capacity);
	$l2_server_memcpu{NODATA}=1 if(!%l2_server_memcpu);
	save_hash("cache.l2_server_capacity", \%l2_server_capacity,"$cache_dir/l2_cache");
	save_hash("cache.l2_server_memcpu", \%l2_server_memcpu,"$cache_dir/l2_cache");

} else {

	#---------------------------------------------------------------------------------------------------------
	#PERFORMANCE ENHANCEMENTS
	#
	##############
	#
	#
	# server_capacity
	#
	##############
	my %menu_filters;
	my %tmp;

	my $ref = load_cache_byFile("$cache_dir/l2_cache/cache.l2_server_capacity",1);
	my %l2_server_capacity = %{$ref};

	foreach my $customer (keys %{$l2_server_capacity{CUSTOMER}}) {
		foreach my $center (keys %{$l2_server_capacity{CUSTOMER}{$customer}{CENTER}}) {
			my $c_str = $center;
			$c_str =~ s/\:/\_/g;
			foreach my $cap (keys %{$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}}) {
				foreach my $team (keys %{$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}}) {
					my $t_str = $team;
					$t_str =~ s/\W//g;
					$t_str = substr($t_str,0,25);

					my $file = "l2_server_capacity-$c_str-$t_str";

					$tmp{FILE}{$file}{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team} = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team};

					$tmp{FILE}{$file}{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'cluster node'}{CAPABILITY}{$cap}{TEAM}{$team} = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'cluster node'}{CAPABILITY}{$cap}{TEAM}{$team};
					$tmp{FILE}{$file}{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$cap}{TEAM}{$team} = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$cap}{TEAM}{$team};

				}
			}
		}
	}

	foreach my $file (keys %{$tmp{FILE}}) {
		my %t2;
		foreach my $customer (keys %{$tmp{FILE}{$file}{CUSTOMER}}) {
			$t2{CUSTOMER}{$customer}{PDXC_INSTANCE_LIST}= $l2_server_capacity{CUSTOMER}{$customer}{PDXC_INSTANCE_LIST};
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

	save_hash("menu_filters-l2_server_capacity", \%menu_filters, "$cache_dir/l2_cache/by_filters");

	##############
	#
	#
	# server_memcpu
	#
	##############
	my %menu_filters;
	my %tmp;

	my $ref = load_cache_byFile("$cache_dir/l2_cache/cache.l2_server_memcpu",1);
	my %l2_server_memcpu = %{$ref};

	foreach my $customer (keys %{$l2_server_memcpu{CUSTOMER}}) {
		foreach my $center (keys %{$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}}) {
			my $c_str = $center;
			$c_str =~ s/\:/\_/g;
			foreach my $cap (keys %{$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}}) {
				foreach my $team (keys %{$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}}) {
					my $t_str = $team;
					$t_str =~ s/\W//g;
					$t_str = substr($t_str,0,25);

					my $file = "l2_server_memcpu-$c_str-$t_str";

					$tmp{FILE}{$file}{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team} = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team};

					$tmp{FILE}{$file}{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'cluster node'}{CAPABILITY}{$cap}{TEAM}{$team} = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'cluster node'}{CAPABILITY}{$cap}{TEAM}{$team};
					$tmp{FILE}{$file}{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$cap}{TEAM}{$team} = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$cap}{TEAM}{$team};

				}
			}
		}
	}

	foreach my $file (keys %{$tmp{FILE}}) {
		my %t2;
		foreach my $customer (keys %{$tmp{FILE}{$file}{CUSTOMER}}) {
			$t2{CUSTOMER}{$customer}{PDXC_INSTANCE_LIST}= $l2_server_memcpu{CUSTOMER}{$customer}{PDXC_INSTANCE_LIST};
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

	save_hash("menu_filters-l2_server_memcpu", \%menu_filters, "$cache_dir/l2_cache/by_filters");

}

my $end_time = time();
printf "Completed Processing after %0.1f Mins\n", ($end_time - $start_time) / 60;

# ---------------------------------------------------------------------------------------------------------------

sub get_incident_counts{
	my ($incid_by_node, $esl_system_ci, $incid_details, $customer,$mapping,$count) = @_;
		my $c = 0;
		foreach my $center (keys %{$esl_system_ci->{$customer}}) {
			foreach my $owner ('ALL','OWNER','SSN','ESO4SAP_OWNED','ESO4SAP_USES') {

				next if ($center ne "ALL" and $owner ne "OWNER");

				foreach my $fqdn (sort keys %{$esl_system_ci->{$customer}{$center}}) {
					next if( $fqdn =~/^\s*$/);
					my $system_type = $esl_system_ci->{$customer}{$center}{$fqdn}{SERVER_TYPE};
					my $status = $esl_system_ci->{$customer}{$center}{$fqdn}{STATUS};
					my $impact = $esl_system_ci->{$customer}{$center}{$fqdn}{ESL_IMPACT};
					my $eol_status = $esl_system_ci->{$customer}{$center}{$fqdn}{EOL_STATUS};
					my $owner_flag = $esl_system_ci->{$customer}{$center}{$fqdn}{OWNER_FLAG};
					my $ssn_flag = $esl_system_ci->{$customer}{$center}{$fqdn}{SSN};
					my $eso_flag = $esl_system_ci->{$customer}{$center}{$fqdn}{ESO4SAP};

					my $kpe_name = $esl_system_ci->{$customer}{$center}{$fqdn}{KPE_NAME};
					my $service_level = $esl_system_ci->{$customer}{$center}{$fqdn}{SERVICE_LEVEL};

	#				print "$fqdn SYS TYPE: $system_type - OWNER: $owner - OWNER_FLAG: $owner_flag - SSN_FLAG: $ssn_flag SVC LEVEL: $service_level\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);

					next if ($system_type !~ /server|cluster node/i);
					next if ($owner eq "OWNER" and $owner_flag == 0);
					next if ($owner eq "SSN" and ($owner_flag == 0 or $ssn_flag == 0));
					next if ($owner eq "ESO4SAP_OWNED" and ($owner_flag == 0 or $eso_flag == 0));
					next if ($owner eq "ESO4SAP_USES" and ($owner_flag == 1 or $eso_flag == 0));


					my $tax_cap = $esl_system_ci->{$customer}{$center}{$fqdn}{OS_INSTANCE_TAX_CAP};

					my %teams;
					my %capability;

					$capability{ALL}=1;
					$capability{$tax_cap} = 1;
					$teams{ALL} = 1;
					foreach my $os_instance (keys %{$esl_system_ci->{$customer}{$center}{$fqdn}{ESL_ORG_CARD}}) {
						foreach my $esl_o (@{$esl_system_ci->{$customer}{$center}{$fqdn}{ESL_ORG_CARD}{$os_instance}}) {
							$teams{$esl_o->{ORG_NM}} = 1;
						}
					}
	#				$os_class{'other'} = 1 if (not defined($os_class{'windows'}) and not defined($os_class{'unix'}));

					my %kpe_list;
					foreach my $cap (keys %capability) {
						foreach my $team (keys %teams) {

							# From here on - this fqdn is to be included in report...
							my $fs_crit_server = 0;
							if (defined($incid_by_node->{$fqdn})) {
								if (!defined($counted_fqdn_fs{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn})) {
									$counted_fqdn_fs{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1;
									$fs_crit_server = ($incid_by_node->{$fqdn}{FS} > 0);
	#								$tmp_server_fs_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node->{$fqdn}{FS} > 0);
	#								$tmp_server_fs_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node->{$fqdn}{FS} > 0);
								}
							}

							my $perf_crit_server = 0;
							if (defined($incid_by_node->{$fqdn})) {
	#							print "found $fqdn in PERF list\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);
								if (!defined($counted_fqdn_perf{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn})) {
									$counted_fqdn_perf{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1;
									$perf_crit_server = ($incid_by_node->{$fqdn}{PERF} > 0);
	#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node->{$fqdn}{PERF} > 0);
	#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node->{$fqdn}{PERF} > 0);
								}
							}

							my $all_crit_server = 0;
							if (defined($incid_by_node->{$fqdn})) {
	#							print "found $fqdn in PERF list\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);
								if (!defined($counted_fqdn_all{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn})) {
									$counted_fqdn_all{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1;
									$all_crit_server = ($incid_by_node->{$fqdn}{ALL} > 0);
	#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node->{$fqdn}{PERF} > 0);
	#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node->{$fqdn}{PERF} > 0);
								}
							}

							my $mon_crit_server = 0;
							if (defined($incid_by_node->{$fqdn})) {
	#							print "found $fqdn in PERF list\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);
								if (!defined($counted_fqdn_mon{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn})) {
									$counted_fqdn_mon{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1;
									$mon_crit_server = ($incid_by_node->{$fqdn}{MONITORING} > 0);
	#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node->{$fqdn}{PERF} > 0);
	#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node->{$fqdn}{PERF} > 0);
								}
							}

							my $cust_crit_server = 0;
							if (defined($incid_by_node->{$fqdn})) {
	#							print "found $fqdn in PERF list\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);
								if (!defined($counted_fqdn_cust{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn})) {
									$counted_fqdn_cust{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1;
									$cust_crit_server = ($incid_by_node->{$fqdn}{CUSTOMER} > 0);
	#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node->{$fqdn}{PERF} > 0);
	#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node->{$fqdn}{PERF} > 0);
								}
							}

							my $filesystems_with_3months_fill = 0;
							my $filesystems_with_lt20pctfree_kpe = 0;
							my @sys_3m;

							foreach my $fs (keys %{$server_capacity{$customer}{$fqdn}}) {
								if (!defined($counted_fqdn{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn}{$fs}))	{
									$counted_fqdn{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn}{$fs} = 1;
									$filesystems_with_3months_fill++;
									$filesystems_with_lt20pctfree_kpe++ if ($kpe_name ne "");

								}
							}

							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{$eol_status}{CAPACITY_PERC}{VALUE}=0;
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{$eol_status}{CAPACITY_PERC}{VALUE}=$incid_totals{CAPACITY}/$incid_totals{MONITORING}*100 if($incid_totals{MONITORING}>0);
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{$eol_status}{CAPACITY_PERC}{HTML}=$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{$eol_status}{CAPACITY_PERC}{VALUE};
#							= $l2_incidents{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{$eol_status}{CAPACITY_30DAYS};
#
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{ALL}{CAPACITY_PERC}{VALUE}=0;
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{ALL}{CAPACITY_PERC}{VALUE}=$incid_totals{CAPACITY}/$incid_totals{MONITORING}*100 if($incid_totals{MONITORING}>0);
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{ALL}{CAPACITY_PERC}{HTML}=$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{ALL}{CAPACITY_PERC}{VALUE};
#								= $l2_incidents{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{ALL}{CAPACITY_30DAYS};



							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'3M_TO_FILL'}{VALUE} += $filesystems_with_3months_fill;
							my $value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'3M_TO_FILL'}{VALUE};
							if ($value > 0) {
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'3M_TO_FILL'}{HTML}
								= "<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=$center&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=$eol_status&mapping=$mapping\">" . $value . "</a>";
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'3M_TO_FILL'}{COLOR} = $red;
							} else {
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'3M_TO_FILL'}{HTML} = 0;
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'3M_TO_FILL'}{COLOR} = $green;
							}


							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'3M_TO_FILL'}{VALUE} += $filesystems_with_3months_fill;
							$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'3M_TO_FILL'}{VALUE};
							if ($value > 0) {
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'3M_TO_FILL'}{HTML}
								= "<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=$center&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=ALL&mapping=$mapping\">" . $value . "</a>";
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'3M_TO_FILL'}{COLOR} = $red;
							} else {
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'3M_TO_FILL'}{HTML} = 0;
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'3M_TO_FILL'}{COLOR} = $green;
							}


							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'3M_TO_FILL_KPE'}{VALUE} += $filesystems_with_lt20pctfree_kpe;
							$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'3M_TO_FILL_KPE'}{VALUE};
							if ($value > 0) {
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'3M_TO_FILL_KPE'}{HTML}
								= "<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=$center&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=$eol_status&show_kpe=1&mapping=$mapping\">" . $value . "</a>";
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'3M_TO_FILL_KPE'}{COLOR} = $red;
							} else {
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'3M_TO_FILL_KPE'}{HTML} = 0;
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'3M_TO_FILL_KPE'}{GREEN} = $green;
							}

							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'3M_TO_FILL_KPE'}{VALUE} += $filesystems_with_lt20pctfree_kpe;
							$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'3M_TO_FILL_KPE'}{VALUE};
							if ($value > 0) {
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'3M_TO_FILL_KPE'}{HTML}
								= "<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=$center&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=ALL&show_kpe=1&mapping=$mapping\">" . $value . "</a>";
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'3M_TO_FILL_KPE'}{COLOR} = $red;
							} else {
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'3M_TO_FILL_KPE'}{HTML} = 0;
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'3M_TO_FILL_KPE'}{COLOR} = $green;
							}

							###Crtitical Perf Alerts
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{VALUE} += $perf_crit_server;
							$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{VALUE};
							if ($value > 0) {
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{HTML}
								= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=$center&cap=$cap&team=$team&ci_status=$status&eol=$eol_status&type=PERF&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{COLOR} = $red;
							} else {
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{HTML} = 0;
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{COLOR} = $green;
							}

							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{VALUE} += $perf_crit_server;
							$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{VALUE};
							if ($value > 0) {
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{HTML}
								= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=$center&cap=$cap&team=$team&ci_status=$status&eol=ALL&type=PERF&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{COLOR} = $red;
							} else {
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{HTML} = 0;
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{COLOR} = $green;
							}

							###Crtitical FS Alerts
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{VALUE} += $fs_crit_server;
							$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{VALUE};
							if ($value > 0) {
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{HTML}
								= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=$center&cap=$cap&team=$team&ci_status=$status&eol=$eol_status&type=FS&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{COLOR} = $red;
							} else {
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{HTML} = 0;
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{COLOR} = $green;
							}

							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{VALUE} += $fs_crit_server;
							# print STDERR "$fqdn $count\n" if ($incid_by_node->{$fqdn}{FS});
							$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{VALUE};
							if ($value > 0) {
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{HTML}
								= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=$center&cap=$cap&team=$team&ci_status=$status&eol=ALL&type=FS&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{COLOR} = $red;
							} else {
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{HTML} = 0;
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{COLOR} = $green;
							}

							###ALL Crtitical Alerts
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{VALUE} += $all_crit_server;
							$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{VALUE};
							if ($value > 0) {
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{HTML}
								= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=$center&cap=$cap&team=$team&ci_status=$status&eol=$eol_status&type=ALL&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{COLOR} = $red;
							} else {
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{HTML} = 0;
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{COLOR} = $green;
							}

							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{VALUE} += $all_crit_server;
							# print STDERR "$fqdn $count\n" if ($incid_by_node->{$fqdn}{FS});
							$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{VALUE};
							if ($value > 0) {
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{HTML}
								= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=$center&cap=$cap&team=$team&ci_status=$status&eol=ALL&type=ALL&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{COLOR} = $red;
							} else {
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{HTML} = 0;
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{COLOR} = $green;
							}

							###Crtitical Monitoring Alerts
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{VALUE} += $mon_crit_server;
							$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{VALUE};
							if ($value > 0) {
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{HTML}
								= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=$center&cap=$cap&team=$team&ci_status=$status&eol=$eol_status&type=MONITORING&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{COLOR} = $red;
							} else {
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{HTML} = 0;
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{COLOR} = $green;
							}

							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{VALUE} += $mon_crit_server;
							# print STDERR "$fqdn $count\n" if ($incid_by_node->{$fqdn}{FS});
							$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{VALUE};
							if ($value > 0) {
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{HTML}
								= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=$center&cap=$cap&team=$team&ci_status=$status&eol=ALL&type=MONITORING&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{COLOR} = $red;
							} else {
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{HTML} = 0;
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{COLOR} = $green;
							}

							###Crtitical Customer Alerts
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{VALUE} += $cust_crit_server;
							$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{VALUE};
							if ($value > 0) {
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{HTML}
								= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=$center&cap=$cap&team=$team&ci_status=$status&eol=$eol_status&type=CUSTOMER&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{COLOR} = $red;
							} else {
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{HTML} = 0;
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{COLOR} = $green;
							}

							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{VALUE} += $cust_crit_server;
							# print STDERR "$fqdn $count\n" if ($incid_by_node->{$fqdn}{FS});
							$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{VALUE};
							if ($value > 0) {
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{HTML}
								= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=$center&cap=$cap&team=$team&ci_status=$status&eol=ALL&type=CUSTOMER&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{COLOR} = $red;
							} else {
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{HTML} = 0;
								$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{COLOR} = $green;
							}

							$count++;
						}
					}
				}
			}

		}
}

sub memcpu {

	my ($customer,$esl_system_ci) = @_;

	my %counted_fqdn;
	my %counted_fqdn_fs;
	my %counted_fqdn_perf;

	my $not_in_cmdb;
	my $count=1;
	##PDXC Changes
	my %pdxc_customers;
	my $pdxc_list;
	if (defined($opts{'p'})) {
    $pdxc_list = get_pdxc_instance('server_memcpu');
		foreach my $pdxc_instance (@{$pdxc_list}) {
			print "PDXC Instance found -- $pdxc_instance\n";
  		my $pdxc_cfg = get_pdxc_cache_files($pdxc_instance,'server_memcpu');
  		my $ssz_dir = $pdxc_cfg->{$pdxc_instance}{'ssz_instance_dir'} . '/core_receiver';
		  my $instance_url = $pdxc_cfg->{$pdxc_instance}{'instance_url'};
  		my $mapping = update_pdxc_cache("$ssz_dir/l2_cache",'cache.l2_server_memcpu',$pdxc_instance,$instance_url);
  		my $pdxc_inc = load_cache_byFile("$ssz_dir/l2_cache/cache.l2_server_memcpu");
  		 foreach my $customer (keys %{$pdxc_inc->{CUSTOMER}}) {
  		 	$l2_server_capacity{CUSTOMER}{$customer} = \%{$pdxc_inc->{CUSTOMER}{$customer}};
  		 }
  		foreach my $customer_pdxc (keys %{$mapping}) {
  			$pdxc_customers{$customer_pdxc}{INSTANCE} = $mapping->{$customer_pdxc}{INSTANCE};
  			$pdxc_customers{$customer_pdxc}{INSTANCE_URL} = $mapping->{$customer_pdxc}{INSTANCE_URL};
  			#print "MAPPED: $mapping->{$customer_pdxc}{INSTANCE} and $mapping->{$customer_pdxc}{INSTANCE_URL}\n";
  		}
		}
	}

	my $file_name = "$account_reg{$customer}{sp_mapping_file}"."_server_memcpu_30_DAYS";
	my $sys =  load_cache_byFile("$cache_dir/by_customer/$file_name");
	my %server_memcpu = %{$sys};

	my $server_count;
	my($totalmemmonsys_value,$totalcpumonsys_value);
  ($server_count) = scalar (keys %{$server_memcpu{DATA}});
	foreach my $f (keys %{$server_memcpu{FQDNS}}){
		$not_in_cmdb++ if(not defined($esl_system_ci->{$customer}{ALL}{$f}));
		$totalmemmonsys_value++ if(scalar(keys %{$server_memcpu{DATA}{$f}{memory}})>0);
		$totalcpumonsys_value++ if(scalar(keys %{$server_memcpu{DATA}{$f}{cpu}})>0);
	}
	my $current_tick = time();
	my ($latest_record)= sprintf "%d",($current_tick - $server_memcpu{LATEST_RECORD}) / (24 * 60 * 60);

	my $c = 0;

	foreach my $center (keys %{$esl_system_ci->{$customer}}) {
		foreach my $owner ('ALL','OWNER','SSN','ESO4SAP_OWNED','ESO4SAP_USES') {
			next if ($center ne "ALL" and $owner ne "OWNER");
			foreach my $fqdn (sort keys %{$esl_system_ci->{$customer}{$center}}) {
				next if( $fqdn =~/^\s*$/);
				my $system_type = $esl_system_ci->{$customer}{$center}{$fqdn}{SERVER_TYPE};
				my $status = $esl_system_ci->{$customer}{$center}{$fqdn}{STATUS};
				my $impact = $esl_system_ci->{$customer}{$center}{$fqdn}{ESL_IMPACT};
				my $eol_status = $esl_system_ci->{$customer}{$center}{$fqdn}{EOL_STATUS};
				my $owner_flag = $esl_system_ci->{$customer}{$center}{$fqdn}{OWNER_FLAG};
				my $ssn_flag = $esl_system_ci->{$customer}{$center}{$fqdn}{SSN};
				my $eso_flag = $esl_system_ci->{$customer}{$center}{$fqdn}{ESO4SAP};
				my $systems_with_lt5pctfree = 0;
				my $systems_with_lt5pctfree_kpe = 0;
				my $systems_with_lt10pctfree = 0;
				my $systems_with_lt10pctfree_kpe = 0;
				my $systems_with_lt20pctfree = 0;
				my $systems_with_lt20pctfree_kpe = 0;
				my $total=0;
				my $usedpct = 0;
				my $swaptotal=0;
				my $swapusedpct = 0;

				my $systems_with_cpult5pctfree = 0;
				my $systems_with_cpult5pctfree_kpe = 0;
				my $systems_with_cpult10pctfree = 0;
				my $systems_with_cpult10pctfree_kpe = 0;
				my $systems_with_cpult20pctfree = 0;
				my $systems_with_cpult20pctfree_kpe = 0;
				my $totalpct=0;
				my $syspct = 0;
				my $userpct=0;
				my $iowaitpct = 0;
				my $cpucores=0;
        my $service_level = "";

				my $kpe_name = $esl_system_ci->{$customer}{$center}{$fqdn}{KPE_NAME};
				my $service_level = $esl_system_ci->{$customer}{$center}{$fqdn}{SERVICE_LEVEL};

				#				print "$fqdn SYS TYPE: $system_type - OWNER: $owner - OWNER_FLAG: $owner_flag - SSN_FLAG: $ssn_flag SVC LEVEL: $service_level\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);

				next if ($system_type !~ /server|cluster node/i);
				next if ($owner eq "OWNER" and $owner_flag == 0);
				next if ($owner eq "SSN" and ($owner_flag == 0 or $ssn_flag == 0));
				next if ($owner eq "ESO4SAP_OWNED" and ($owner_flag == 0 or $eso_flag == 0));
				next if ($owner eq "ESO4SAP_USES" and ($owner_flag == 1 or $eso_flag == 0));


				my $tax_cap = $esl_system_ci->{$customer}{$center}{$fqdn}{OS_INSTANCE_TAX_CAP};

				my %teams;
				my $mapping;

				my %capability;

				$capability{ALL}=1;
				$capability{$tax_cap} = 1;
				$teams{ALL} = 1;
				foreach my $os_instance (keys %{$esl_system_ci->{$customer}{$center}{$fqdn}{ESL_ORG_CARD}}) {
					foreach my $esl_o (@{$esl_system_ci->{$customer}{$center}{$fqdn}{ESL_ORG_CARD}{$os_instance}}) {
						$teams{$esl_o->{ORG_NM}} = 1;
					}
				}
				#				$os_class{'other'} = 1 if (not defined($os_class{'windows'}) and not defined($os_class{'unix'}));

				my %kpe_list;
				foreach my $cap (keys %capability) {
					foreach my $team (keys %teams) {
						# Save Baseline
						#$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'cluster node'}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{COUNT} = $server_count;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{COUNT} = $server_count;

					#	$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'cluster node'}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{COUNT} = $server_count;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{COUNT} = $server_count;

						#Calculate the ETP
						if ($service_level =~ /hosting only|not supported/i ) {

							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{SERVER_CAPACITY_ETP}{VALUE}++;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{SERVER_CAPACITY_ETP}{HTML} = "<a href=\"$drilldown_dir/eslSystemCI.pl?customer=$customer&status=$status&system_type=server_and_node&capability=$cap&center=$center&owner_flag=$owner&team=$team&eol_status=$eol_status&etp=all\">$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{PERC_INC_ETP}{VALUE}</a>";

							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{SERVER_CAPACITY_ETP}{VALUE}++;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{SERVER_CAPACITY_ETP}{HTML} = "<a href=\"$drilldown_dir/eslSystemCI.pl?customer=$customer&status=$status&system_type=server_and_node&capability=$cap&center=$center&owner_flag=$owner&team=$team&eol_status=ALL&etp=all\">$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{SERVER_CAPACITY_ETP}{VALUE}</a>";

							next;
						}

#						print "processing $fqdn\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);

						#Eligible CI
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{SERVER_CAPACITY_ELIGIBLE}{VALUE}++;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{SERVER_CAPACITY_ELIGIBLE}{HTML} = "<a href=\"$drilldown_dir/eslSystemCI.pl?customer=$customer&status=$status&system_type=server_and_node&capability=$cap&center=$center&owner_flag=$owner&team=$team&eol_status=$eol_status&eligible=all\">$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{PERC_INC_ELIGIBLE}{VALUE}</a>";

						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{SERVER_CAPACITY_ELIGIBLE}{VALUE}++;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{SERVER_CAPACITY_ELIGIBLE}{HTML} = "<a href=\"$drilldown_dir/eslSystemCI.pl?customer=$customer&status=$status&system_type=server_and_node&capability=$cap&center=$center&owner_flag=$owner&team=$team&eol_status=ALL&eligible=all\">$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{SERVER_CAPACITY_ELIGIBLE}{VALUE}</a>";

						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CVA}{VALUE}++ if(not defined($server_memcpu{FQDNS}{$fqdn}));
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CVA}{COLOR}="green";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CVA}{COLOR}="red" if($l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CVA}{VALUE}>0);
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CVA}{HTML}="<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=mem\">$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CVA}{VALUE}</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CVA}{HTML}="0" if ($l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CVA}{VALUE}==0);

						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CVA}{VALUE}++ if(not defined($server_memcpu{FQDNS}{$fqdn}));
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CVA}{COLOR}="green";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CVA}{COLOR}="red" if ($l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CVA}{VALUE}>0);
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CVA}{HTML}="<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=mem\">$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CVA}{VALUE}</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CVA}{HTML}="0" if ($l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CVA}{VALUE}==0);

						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CMDB}{VALUE}=$not_in_cmdb||0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CMDB}{COLOR}="green";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CMDB}{COLOR}="amber" if ($not_in_cmdb>0);
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CMDB}{HTML}="<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=mem\">$not_in_cmdb</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CMDB}{HTML}="0" if ($not_in_cmdb==0);

						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CMDB}{VALUE}=$not_in_cmdb||0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CMDB}{COLOR}="green";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CMDB}{COLOR}="amber" if($not_in_cmdb>0);
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CMDB}{HTML}="<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=mem\">$not_in_cmdb</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CMDB}{HTML}="0" if($not_in_cmdb==0);

						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{LATEST_RECORD}{VALUE}=$latest_record;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{LATEST_RECORD}{COLOR}="green";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{LATEST_RECORD}{COLOR}="red" if($latest_record>1);
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{LATEST_RECORD}{HTML}="<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=mem\">$latest_record</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{LATEST_RECORD}{HTML}="0" if($latest_record==0);

						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{LATEST_RECORD}{VALUE}=$latest_record;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{LATEST_RECORD}{COLOR}="green";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{LATEST_RECORD}{COLOR}="red" if($latest_record>1);
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{LATEST_RECORD}{HTML}="<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=mem\">$latest_record</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{LATEST_RECORD}{HTML}="0" if($latest_record==0);
						# From here on - this fqdn is to be included in report...
						my $fs_crit_server = 0;
						if (defined($incid_by_node{$fqdn})) {
							if (!defined($counted_fqdn_fs{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn})) {
								$counted_fqdn_fs{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1;
								$fs_crit_server = ($incid_by_node{$fqdn}{FS} > 0);
								#								$tmp_server_fs_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{FS} > 0);
								#								$tmp_server_fs_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{FS} > 0);
							}
						}

						my $perf_crit_server = 0;
						if (defined($incid_by_node{$fqdn})) {
							#							print "found $fqdn in PERF list\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);
							if (!defined($counted_fqdn_perf{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn})) {
								$counted_fqdn_perf{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1;
								$perf_crit_server = ($incid_by_node{$fqdn}{PERF} > 0);
								#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
								#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
							}
						}


						my $all_crit_server = 0;
						if (defined($incid_by_node{$fqdn})) {
							#							print "found $fqdn in PERF list\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);
							if (!defined($counted_fqdn_all{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn})) {
								$counted_fqdn_all{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1;
								$all_crit_server = ($incid_by_node{$fqdn}{ALL} > 0);
								#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
								#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
							}
						}

						my $mon_crit_server = 0;
						if (defined($incid_by_node{$fqdn})) {
							#							print "found $fqdn in PERF list\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);
							if (!defined($counted_fqdn_mon{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn})) {
								$counted_fqdn_mon{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1;
								$mon_crit_server = ($incid_by_node{$fqdn}{MONITORING} > 0);
								#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
								#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
							}
						}

						my $cust_crit_server = 0;
						if (defined($incid_by_node{$fqdn})) {
							#							print "found $fqdn in PERF list\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);
							if (!defined($counted_fqdn_cust{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn})) {
								$counted_fqdn_cust{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1;
								$cust_crit_server = ($incid_by_node{$fqdn}{CUSTOMER} > 0);
								#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
								#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
							}
						}

						my @sys_3m;

						foreach my $sample (sort {$b <=> $a || $b cmp $a  }  keys %{$server_memcpu{DATA}{$fqdn}{memory}}) {
							if (!defined($counted_fqdn{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn}{memory}))	{
								$counted_fqdn{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn}{memory} = 1;
								$total =  $server_memcpu{DATA}{$fqdn}{memory}{$sample}{'system.memory.total'}*0.000001;
								$swaptotal =  $server_memcpu{DATA}{$fqdn}{memory}{$sample}{'system.memory.swap.total'}*0.000001;
								$usedpct =  $server_memcpu{DATA}{$fqdn}{memory}{$sample}{'system.memory.used.pct'}*100;
								$swapusedpct =   $server_memcpu{DATA}{$fqdn}{memory}{$sample}{'system.memory.swap.used.pct'}*100;

								#my $pctfree = sprintf "%.2f", 100-$usedpct;
								if($usedpct >=95){
									$systems_with_lt5pctfree++;
									$systems_with_lt5pctfree_kpe++ if ($kpe_name ne "");
									#print "lt5Checking thresholds for $fqdn\n";
								}elsif($usedpct >=90) {
									$systems_with_lt10pctfree++;
									$systems_with_lt10pctfree_kpe++ if ($kpe_name ne "");
									#print "lt10Checking thresholds for $fqdn\n";
								}elsif($usedpct >=80){
									$systems_with_lt20pctfree++;
									$systems_with_lt20pctfree_kpe++ if ($kpe_name ne "");
									#print "lt20Checking thresholds for $fqdn\n";
								}
							}
						}

						foreach my $sample (sort {$b <=> $a || $b cmp $a  }  keys %{$server_memcpu{DATA}{$fqdn}{cpu}}) {
							if (!defined($counted_fqdn{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn}{cpu}))	{
								$counted_fqdn{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn}{cpu} = 1;
								my $corecount =1;
								$corecount = $server_memcpu{CORECOUNT}{$fqdn}{cpu} if ($server_memcpu{CORECOUNT}{$fqdn}{cpu}>0);
								$totalpct =  $server_memcpu{DATA}{$fqdn}{cpu}{$sample}{'system.cpu.total.pct'}*100/$corecount if($corecount>0);
								$syspct =  $server_memcpu{DATA}{$fqdn}{cpu}{$sample}{'system.cpu.system.pct'}*100/$corecount if($corecount>0);
								$userpct =  $server_memcpu{DATA}{$fqdn}{cpu}{$sample}{'system.cpu.user.pct'}*100/$corecount if($corecount>0);
								$iowaitpct =   $server_memcpu{DATA}{$fqdn}{cpu}{$sample}{'system.cpu.iowait.pct'}*100/$corecount if($corecount>0);
								$cpucores =   sprintf "%d", $server_memcpu{DATA}{$fqdn}{cpu}{$sample}{'system.cpu.cores'};


								my $pctfree = sprintf "%.2f", 100-$totalpct;

								if($pctfree <=5){
									$systems_with_cpult5pctfree++;
									$systems_with_cpult5pctfree_kpe++ if ($kpe_name ne "");
								}elsif($pctfree <=10) {
									$systems_with_cpult10pctfree++;
									$systems_with_cpult10pctfree_kpe++ if ($kpe_name ne "");
								}elsif($pctfree <=20){
									$systems_with_cpult20pctfree++;
									$systems_with_cpult20pctfree_kpe++ if ($kpe_name ne "");
								}
							}
						}

						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALMEMMONSYS'}{VALUE}=$totalmemmonsys_value;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALMEMMONSYS'}{HTML}="<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=mem\">$totalmemmonsys_value</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALMEMMONSYS'}{VALUE}=$totalmemmonsys_value;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALMEMMONSYS'}{HTML}="<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=mem\">$totalmemmonsys_value</a>";

						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALCPUMONSYS'}{VALUE}=$totalcpumonsys_value;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALCPUMONSYS'}{HTML}="<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=cpu\">$totalcpumonsys_value</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALCPUMONSYS'}{VALUE}=$totalcpumonsys_value;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALCPUMONSYS'}{HTML}="<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=cpu\">$totalcpumonsys_value</a>";

						# Get this from L2 Incident Tile
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{$eol_status}{CAPACITY_PERC}{VALUE}=0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{$eol_status}{CAPACITY_PERC}{VALUE}=$incid_totals{CAPACITY}/$incid_totals{MONITORING}*100 if($incid_totals{MONITORING}>0);
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{$eol_status}{CAPACITY_PERC}{HTML}=$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{$eol_status}{CAPACITY_PERC}{VALUE};

						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{ALL}{CAPACITY_PERC}{VALUE}=0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{ALL}{CAPACITY_PERC}{VALUE}=$incid_totals{CAPACITY}/$incid_totals{MONITORING}*100 if($incid_totals{MONITORING}>0);
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{ALL}{CAPACITY_PERC}{HTML}=$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{ALL}{CAPACITY_PERC}{VALUE};

						#
						#
						# MEMORY
						###Less Than 20 Percent Free
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT20PCTFREE'}{VALUE} += $systems_with_lt20pctfree;
						my $value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT20PCTFREE'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT20PCTFREE'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct20&eol_status=$eol_status&mapping=mem\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT20PCTFREE'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT20PCTFREE'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT20PCTFREE'}{COLOR} = $green;
						}


						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT20PCTFREE'}{VALUE} += $systems_with_lt20pctfree;
						$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT20PCTFREE'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT20PCTFREE'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct20&eol_status=ALL&mapping=mem\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT20PCTFREE'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT20PCTFREE'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT20PCTFREE'}{COLOR} = $green;
						}

						###Less Than 10 Percent Free
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT10PCTFREE'}{VALUE} += $systems_with_lt10pctfree;
						$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT10PCTFREE'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT10PCTFREE'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct10&eol_status=$eol_status&show_kpe=1&mapping=mem\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT10PCTFREE'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT10PCTFREE'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT10PCTFREE'}{GREEN} = $green;
						}

						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT10PCTFREE'}{VALUE} += $systems_with_lt10pctfree;
						$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT10PCTFREE'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT10PCTFREE'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct10&eol_status=ALL&show_kpe=1&mapping=mem\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT10PCTFREE'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT10PCTFREE'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT10PCTFREE'}{COLOR} = $green;
						}

						###Less Than 5 Percent Free
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT5PCTFREE'}{VALUE} += $systems_with_lt5pctfree;
						$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT5PCTFREE'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT5PCTFREE'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct5&eol_status=$eol_status&show_kpe=1&mapping=mem\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT5PCTFREE'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT5PCTFREE'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT5PCTFREE'}{GREEN} = $green;
						}

						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT5PCTFREE'}{VALUE} += $systems_with_lt5pctfree_kpe;
						$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT5PCTFREE'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT5PCTFREE'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct5&eol_status=ALL&show_kpe=1&mapping=mem\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT5PCTFREE'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT5PCTFREE'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT5PCTFREE'}{COLOR} = $green;
						}

						#################
						#
						#
						# CPU
						###Less Than 20 Percent Free
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT20PCTFREE'}{VALUE} += $systems_with_cpult20pctfree;
						my $value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT20PCTFREE'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT20PCTFREE'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct20&eol_status=$eol_status&mapping=cpu\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT20PCTFREE'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT20PCTFREE'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT20PCTFREE'}{COLOR} = $green;
						}


						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT20PCTFREE'}{VALUE} += $systems_with_cpult20pctfree;
						$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT20PCTFREE'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT20PCTFREE'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct20&eol_status=ALL&mapping=cpu\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT20PCTFREE'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT20PCTFREE'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT20PCTFREE'}{COLOR} = $green;
						}

						###Less Than 10 Percent Free
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT10PCTFREE'}{VALUE} += $systems_with_cpult10pctfree;
						$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT10PCTFREE'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT10PCTFREE'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct10&eol_status=$eol_status&show_kpe=1&mapping=cpu\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT10PCTFREE'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT10PCTFREE'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT10PCTFREE'}{GREEN} = $green;
						}

						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT10PCTFREE'}{VALUE} += $systems_with_cpult10pctfree;
						$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT10PCTFREE'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT10PCTFREE'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct10&eol_status=ALL&show_kpe=1&mapping=cpu\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT10PCTFREE'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT10PCTFREE'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT10PCTFREE'}{COLOR} = $green;
						}

						###Less Than 5 Percent Free
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT5PCTFREE'}{VALUE} += $systems_with_cpult5pctfree;
						$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT5PCTFREE'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT5PCTFREE'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct5&eol_status=$eol_status&show_kpe=1&mapping=cpu\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT5PCTFREE'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT5PCTFREE'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT5PCTFREE'}{GREEN} = $green;
						}

						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT5PCTFREE'}{VALUE} += $systems_with_cpult5pctfree;
						$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT5PCTFREE'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT5PCTFREE'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct5&eol_status=ALL&show_kpe=1&mapping=cpu\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT5PCTFREE'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT5PCTFREE'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT5PCTFREE'}{COLOR} = $green;
						}

						###Total Space
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALMEMORY'}{VALUE} += sprintf "%.2f",$total;
						$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALMEMORY'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALMEMORY'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=$eol_status&show_kpe=1&mapping=mem\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALMEMORY'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALMEMORY'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALMEMORY'}{GREEN} = $green;
						}

						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALMEMORY'}{VALUE} += sprintf "%.2f",$total;
						$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALMEMORY'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALMEMORY'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=ALL&show_kpe=1&mapping=mem\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALMEMORY'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALMEMORY'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALMEMORY'}{COLOR} = $green;
						}

						###Free Space
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'SWAPTOTAL'}{VALUE} += sprintf "%.2f",$swaptotal;
						$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'SWAPTOTAL'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'SWAPTOTAL'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=$eol_status&show_kpe=1&mapping=mem\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'SWAPTOTAL'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'SWAPTOTAL'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'SWAPTOTAL'}{GREEN} = $green;
						}

						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'SWAPTOTAL'}{VALUE} += sprintf "%.2f",$swaptotal;
						$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'SWAPTOTAL'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'SWAPTOTAL'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=ALL&show_kpe=1&mapping=mem\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'SWAPTOTAL'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'SWAPTOTAL'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'SWAPTOTAL'}{COLOR} = $green;
						}

						###USED Space
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'USEDPERCENT'}{VALUE} += sprintf "%.2f",$usedpct;
						$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'USEDPERCENT'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'USEDPERCENT'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=$eol_status&show_kpe=1&mapping=mem\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'USEDPERCENT'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'USEDPERCENT'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'USEDPERCENT'}{GREEN} = $green;
						}

						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'USEDPERCENT'}{VALUE} += sprintf "%.2f",$usedpct;
						$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'USEDPERCENT'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'USEDPERCENT'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=ALL&show_kpe=1&mapping=mem\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'USEDPERCENT'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'USEDPERCENT'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'USEDPERCENT'}{COLOR} = $green;
						}

						###USED Space
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'SWAPUSEDPCT'}{VALUE} += sprintf "%.2f",$swapusedpct;
						$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'SWAPUSEDPCT'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'SWAPUSEDPCT'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=$eol_status&show_kpe=1&mapping=mem\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'SWAPUSEDPCT'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'SWAPUSEDPCT'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'SWAPUSEDPCT'}{GREEN} = $green;
						}

						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'SWAPUSEDPCT'}{VALUE} += sprintf "%.2f",$swapusedpct;
						$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'SWAPUSEDPCT'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'SWAPUSEDPCT'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=ALL&show_kpe=1&mapping=mem\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'SWAPUSEDPCT'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'SWAPUSEDPCT'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'SWAPUSEDPCT'}{COLOR} = $green;
						}


						###Crtitical Perf Alerts
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{VALUE} += $perf_crit_server;
						$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{HTML}
							= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=$eol_status&type=PERF&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{COLOR} = $green;
						}

						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{VALUE} += $perf_crit_server;
						$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{HTML}
							= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=ALL&type=PERF&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{COLOR} = $green;
						}

						##Critical FS Alerts
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{VALUE} += $fs_crit_server;
						$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{HTML}
							= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=$eol_status&type=FS&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{COLOR} = $green;
						}

						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{VALUE} += $fs_crit_server;
						# print STDERR "$fqdn $count\n" if ($incid_by_node{$fqdn}{FS});
						$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{HTML}
							= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=ALL&type=FS&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{COLOR} = $green;
						}

						###ALL Crtitical Alerts
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{VALUE} += $all_crit_server;
						$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{HTML}
							= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=$eol_status&type=ALL&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{COLOR} = $green;
						}

						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{VALUE} += $all_crit_server;
						# print STDERR "$fqdn $count\n" if ($incid_by_node{$fqdn}{FS});
						$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{HTML}
							= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=ALL&type=ALL&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{COLOR} = $green;
						}

						###Crtitical Monitoring Alerts
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{VALUE} += $mon_crit_server;
						$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{HTML}
							= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=$eol_status&type=MONITORING&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{COLOR} = $green;
						}

						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{VALUE} += $mon_crit_server;
						# print STDERR "$fqdn $count\n" if ($incid_by_node{$fqdn}{FS});
						$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{HTML}
							= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=ALL&type=MONITORING&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{COLOR} = $green;
						}

						###Crtitical Customer Alerts
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{VALUE} += $cust_crit_server;
						$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{HTML}
							= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=$eol_status&type=CUSTOMER&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{COLOR} = $green;
						}

						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{VALUE} += $cust_crit_server;
						# print STDERR "$fqdn $count\n" if ($incid_by_node{$fqdn}{FS});
						$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{VALUE};
						if ($value > 0) {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{HTML}
							= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=ALL&type=CUSTOMER&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{COLOR} = $red;
						} else {
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{HTML} = 0;
							$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{COLOR} = $green;
						}

						$count++;
					}
				}
			}
		}
	}


	if (defined($opts{'p'})) {
	   ##PDXC_Updates
	   foreach my $customer (keys %pdxc_customers) {
	   		my $pdxc_instance = $pdxc_customers{$customer}{INSTANCE};
	   		$l2_server_memcpu{CUSTOMER}{$customer}{PDXC_INSTANCE_LIST}{$pdxc_instance} = $pdxc_customers{$customer}{INSTANCE_URL};
	   		print "PDXCINSTANCELIST: $l2_server_memcpu{CUSTOMER}{$customer}{PDXC_INSTANCE_LIST}{$pdxc_instance}\n";

	   		update_pdxc_ssz(\%l2_server_memcpu,$pdxc_instance,"l2_server_memcpu.pl?aggregation=L2.5");
	   }
 	}
}

sub nonesl_account_memcpu {

	my $customer = shift;

	my %counted_fqdn;
	my %counted_fqdn_fs;
	my %counted_fqdn_perf;

	my $count=1;

	my $file_name = "$account_reg{$customer}{sp_mapping_file}"."_server_memcpu_30_DAYS";
	my $sys =  load_cache_byFile("$cache_dir/by_customer/$file_name");
	my %server_memcpu = %{$sys};
	my $server_count;
  ($server_count) = scalar (keys %{$server_memcpu{DATA}});
  my $current_tick = time();
  my ($latest_record)= sprintf "%d",($current_tick - $server_memcpu{LATEST_RECORD}) / (24 * 60 * 60);
	my $not_in_cmdb=$server_count;



	my $c = 0;
	##PDXC Changes
	my %pdxc_customers;
	my $pdxc_list;
	if (defined($opts{'p'})) {
    $pdxc_list = get_pdxc_instance('server_memcpu');
		foreach my $pdxc_instance (@{$pdxc_list}) {
			print "PDXC Instance found -- $pdxc_instance\n";
  		my $pdxc_cfg = get_pdxc_cache_files($pdxc_instance,'server_memcpu');
  		my $ssz_dir = $pdxc_cfg->{$pdxc_instance}{'ssz_instance_dir'} . '/core_receiver';
		  my $instance_url = $pdxc_cfg->{$pdxc_instance}{'instance_url'};
  		my $mapping = update_pdxc_cache("$ssz_dir/l2_cache",'cache.l2_server_memcpu',$pdxc_instance,$instance_url);
  		my $pdxc_inc = load_cache_byFile("$ssz_dir/l2_cache/cache.l2_server_memcpu");
  		 foreach my $customer (keys %{$pdxc_inc->{CUSTOMER}}) {
  		 	$l2_server_capacity{CUSTOMER}{$customer} = \%{$pdxc_inc->{CUSTOMER}{$customer}};
  		 }
  		foreach my $customer_pdxc (keys %{$mapping}) {
  			$pdxc_customers{$customer_pdxc}{INSTANCE} = $mapping->{$customer_pdxc}{INSTANCE};
  			$pdxc_customers{$customer_pdxc}{INSTANCE_URL} = $mapping->{$customer_pdxc}{INSTANCE_URL};
  			#print "MAPPED: $mapping->{$customer_pdxc}{INSTANCE} and $mapping->{$customer_pdxc}{INSTANCE_URL}\n";
  		}
		}
	}

	foreach my $owner ('ALL','OWNER','SSN','ESO4SAP_OWNED','ESO4SAP_USES') {
		my($totalmemmonsys_value,$totalcpumonsys_value);
		foreach my $fqdn (sort keys %{$server_memcpu{DATA}}) {
			 next if( $fqdn =~/^\s*$/);
			($totalmemmonsys_value) ++ if(scalar(keys %{$server_memcpu{DATA}{$fqdn}{memory}})>0);
			($totalcpumonsys_value) ++ if(scalar(keys %{$server_memcpu{DATA}{$fqdn}{cpu}})>0);
			my $system_type = "server";
			my $status = "in production";
			my $impact = "";
			my $eol_status = "";
			my $owner_flag = "1";
			my $ssn_flag = "1";
			my $eso_flag = "1";

			my $kpe_name = "";
			my $service_level = "";

			#				print "$fqdn SYS TYPE: $system_type - OWNER: $owner - OWNER_FLAG: $owner_flag - SSN_FLAG: $ssn_flag SVC LEVEL: $service_level\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);

			next if ($system_type !~ /server|cluster node/i);
			next if ($owner eq "OWNER" and $owner_flag == 0);
			next if ($owner eq "SSN" and ($owner_flag == 0 or $ssn_flag == 0));
			next if ($owner eq "ESO4SAP_OWNED" and ($owner_flag == 0 or $eso_flag == 0));
			next if ($owner eq "ESO4SAP_USES" and ($owner_flag == 1 or $eso_flag == 0));

			my $systems_with_lt5pctfree = 0;
			my $systems_with_lt5pctfree_kpe = 0;
			my $systems_with_lt10pctfree = 0;
			my $systems_with_lt10pctfree_kpe = 0;
			my $systems_with_lt20pctfree = 0;
			my $systems_with_lt20pctfree_kpe = 0;
			my $total=0;
			my $usedpct = 0;
			my $swaptotal=0;
			my $swapusedpct = 0;

			my $systems_with_cpult5pctfree = 0;
			my $systems_with_cpult5pctfree_kpe = 0;
			my $systems_with_cpult10pctfree = 0;
			my $systems_with_cpult10pctfree_kpe = 0;
			my $systems_with_cpult20pctfree = 0;
			my $systems_with_cpult20pctfree_kpe = 0;
			my $totalpct=0;
			my $syspct = 0;
			my $userpct=0;
			my $iowaitpct = 0;
			my $cpucores=0;

			#print "FQDN: $fqdn\n";
			my $tax_cap = "windows";
			my $mapping;
			my %teams;
			my %capability;

			$capability{ALL}=1;
			$capability{$tax_cap} = 1;
			$teams{ALL} = 1;

			#				$os_class{'other'} = 1 if (not defined($os_class{'windows'}) and not defined($os_class{'unix'}));
			#
			my %kpe_list;
			foreach my $cap (keys %capability) {
				foreach my $team (keys %teams) {
					# Save Baseline

					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{COUNT} = $server_count;
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{COUNT} = $server_count;

					#Calculate the ETP
					if ($service_level =~ /hosting only|not supported/i ) {

						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{SERVER_CAPACITY_ETP}{VALUE}++;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{SERVER_CAPACITY_ETP}{HTML} = "<a href=\"$drilldown_dir/eslSystemCI.pl?customer=$customer&status=$status&system_type=server_and_node&capability=$cap&center=ALL&owner_flag=$owner&team=$team&eol_status=$eol_status&etp=all\">$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{PERC_INC_ETP}{VALUE}</a>";

						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{SERVER_CAPACITY_ETP}{VALUE}++;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{SERVER_CAPACITY_ETP}{HTML} = "<a href=\"$drilldown_dir/eslSystemCI.pl?customer=$customer&status=$status&system_type=server_and_node&capability=$cap&center=ALL&owner_flag=$owner&team=$team&eol_status=ALL&etp=all\">$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{SERVER_CAPACITY_ETP}{VALUE}</a>";

						next;
					}

					#						print "processing $fqdn\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);

					#Eligible CI
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{SERVER_CAPACITY_ELIGIBLE}{VALUE}++;
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{SERVER_CAPACITY_ELIGIBLE}{HTML} = '<a href="/cgi-bin/GTOD_CC/l3_drilldowns/l3_cva_availability.pl?customer='.$customer.'&type=baseline">'.$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{SERVER_CAPACITY_ELIGIBLE}{VALUE}.'</a>';

					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{SERVER_CAPACITY_ELIGIBLE}{VALUE}++;
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{SERVER_CAPACITY_ELIGIBLE}{HTML} = '<a href="/cgi-bin/GTOD_CC/l3_drilldowns/l3_cva_availability.pl?customer='.$customer.'&type=baseline">'.$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{SERVER_CAPACITY_ELIGIBLE}{VALUE}.'</a>';

					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CMDB}{VALUE}=$not_in_cmdb ||0;
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CMDB}{COLOR}="green" ;
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CMDB}{COLOR}="amber" if($not_in_cmdb>0);
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CMDB}{HTML}="<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=mem\">$not_in_cmdb</a>";
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CMDB}{HTML}="0"  if($not_in_cmdb==0);

					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CMDB}{VALUE}=$not_in_cmdb ||0;
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CMDB}{COLOR}="green";
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CMDB}{COLOR}="amber" if($not_in_cmdb>0);
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CMDB}{HTML}="<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=mem\">$not_in_cmdb</a>";
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CMDB}{HTML}="0"  if($not_in_cmdb==0);

					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{LATEST_RECORD}{VALUE}=$latest_record;
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{LATEST_RECORD}{COLOR}="green";
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{LATEST_RECORD}{COLOR}="red" if ($latest_record>1);
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{LATEST_RECORD}{HTML}="<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=mem\">$latest_record</a>";
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{LATEST_RECORD}{HTML}="0"  if ($latest_record==0);

					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{LATEST_RECORD}{VALUE}=$latest_record;
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{LATEST_RECORD}{COLOR}="green";
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{LATEST_RECORD}{COLOR}="red" if ($latest_record>1);
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{LATEST_RECORD}{HTML}="<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=mem\">$latest_record</a>";
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{LATEST_RECORD}{HTML}="0" if ($latest_record==0);

					# From here on - this fqdn is to be included in report...
					my $fs_crit_server = 0;
					if (defined($incid_by_node{$fqdn})) {
						if (!defined($counted_fqdn_fs{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn})) {
							$counted_fqdn_fs{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1;
							$fs_crit_server = ($incid_by_node{$fqdn}{FS} > 0);
							#								$tmp_server_fs_count{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{FS} > 0);
							#								$tmp_server_fs_count{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{FS} > 0);
						}
					}

					my $perf_crit_server = 0;
					if (defined($incid_by_node{$fqdn})) {
						#							print "found $fqdn in PERF list\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);
						if (!defined($counted_fqdn_perf{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn})) {
							$counted_fqdn_perf{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1;
							$perf_crit_server = ($incid_by_node{$fqdn}{PERF} > 0);
							#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
							#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
						}
					}


					my $all_crit_server = 0;
					if (defined($incid_by_node{$fqdn})) {
#							print "found $fqdn in PERF list\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);
						if (!defined($counted_fqdn_all{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn})) {
							$counted_fqdn_all{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1;
							$all_crit_server = ($incid_by_node{$fqdn}{ALL} > 0);
#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
						}
					}

					my $mon_crit_server = 0;
					if (defined($incid_by_node{$fqdn})) {
#							print "found $fqdn in PERF list\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);
						if (!defined($counted_fqdn_mon{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn})) {
							$counted_fqdn_mon{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1;
							$mon_crit_server = ($incid_by_node{$fqdn}{MONITORING} > 0);
#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
						}
					}

					my $cust_crit_server = 0;
					if (defined($incid_by_node{$fqdn})) {
#							print "found $fqdn in PERF list\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);
						if (!defined($counted_fqdn_cust{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn})) {
							$counted_fqdn_cust{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1;
							$cust_crit_server = ($incid_by_node{$fqdn}{CUSTOMER} > 0);
#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
						}
					}

					my @sys_3m;

					foreach my $sample (sort {$b <=> $a || $b cmp $a  }  keys %{$server_memcpu{DATA}{$fqdn}{memory}}) {
							if (!defined($counted_fqdn{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn}{memory}))	{
								$counted_fqdn{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn}{memory} = 1;
								$total =  $server_memcpu{DATA}{$fqdn}{memory}{$sample}{'system.memory.total'}*0.000001;
								$swaptotal =  $server_memcpu{DATA}{$fqdn}{memory}{$sample}{'system.memory.swap.total'}*0.000001;
								$usedpct =  $server_memcpu{DATA}{$fqdn}{memory}{$sample}{'system.memory.used.pct'}*100;
								$swapusedpct =   $server_memcpu{DATA}{$fqdn}{memory}{$sample}{'system.memory.swap.used.pct'}*100;

								#my $pctfree = sprintf "%.2f", 100-$usedpct;
								if($usedpct >=95){
									$systems_with_lt5pctfree++;
									$systems_with_lt5pctfree_kpe++ if ($kpe_name ne "");
								}elsif($usedpct >=90) {
									$systems_with_lt10pctfree++;
									$systems_with_lt10pctfree_kpe++ if ($kpe_name ne "");
								}elsif($usedpct >=80){
									$systems_with_lt20pctfree++;
									$systems_with_lt20pctfree_kpe++ if ($kpe_name ne "");
								}
							}
					}

					foreach my $sample (sort {$b <=> $a || $b cmp $a  }  keys %{$server_memcpu{DATA}{$fqdn}{cpu}}) {
						if (!defined($counted_fqdn{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn}{cpu}))	{
							$counted_fqdn{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn}{cpu} = 1;
							my $corecount =1;
							$corecount = $server_memcpu{CORECOUNT}{$fqdn}{cpu} if ($server_memcpu{CORECOUNT}{$fqdn}{cpu}>0);
							$totalpct =  $server_memcpu{DATA}{$fqdn}{cpu}{$sample}{'system.cpu.total.pct'}*100/$corecount if($corecount>0);
							$syspct =  $server_memcpu{DATA}{$fqdn}{cpu}{$sample}{'system.cpu.system.pct'}*100/$corecount if($corecount>0);
							$userpct =  $server_memcpu{DATA}{$fqdn}{cpu}{$sample}{'system.cpu.user.pct'}*100/$corecount if($corecount>0);
							$iowaitpct =   $server_memcpu{DATA}{$fqdn}{cpu}{$sample}{'system.cpu.iowait.pct'}*100/$corecount if($corecount>0);
							$cpucores =   sprintf "%d", $server_memcpu{DATA}{$fqdn}{cpu}{$sample}{'system.cpu.cores'};


							my $pctfree = sprintf "%.2f", 100-$totalpct;
							if($pctfree <=5 or $fqdn =~/lpv\-dxcst06/){
								print "FQDN:$fqdn Cores:$corecount User:$userpct Sys:$syspct Total:$totalpct PCTFREE:$pctfree Sample:$sample\n";
							}
							if($pctfree <=5){
								$systems_with_cpult5pctfree++;
								$systems_with_cpult5pctfree_kpe++ if ($kpe_name ne "");
							}elsif($pctfree <=10) {
								$systems_with_cpult10pctfree++;
								$systems_with_cpult10pctfree_kpe++ if ($kpe_name ne "");
							}elsif($pctfree <=20){
								$systems_with_cpult20pctfree++;
								$systems_with_cpult20pctfree_kpe++ if ($kpe_name ne "");
							}
						}
					}

					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALMEMMONSYS'}{VALUE}=$totalmemmonsys_value;
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALMEMMONSYS'}{HTML}="<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=mem\">$totalmemmonsys_value</a>";
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALMEMMONSYS'}{VALUE}=$totalmemmonsys_value;
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALMEMMONSYS'}{HTML}="<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=mem\">$totalmemmonsys_value</a>";

					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALCPUMONSYS'}{VALUE}=$totalcpumonsys_value;
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALCPUMONSYS'}{HTML}="<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=cpu\">$totalcpumonsys_value</a>";
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALCPUMONSYS'}{VALUE}=$totalcpumonsys_value;
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALCPUMONSYS'}{HTML}="<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=cpu\">$totalcpumonsys_value</a>";

					# Get this from L2 Incident Tile
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{$eol_status}{CAPACITY_PERC}{VALUE}=0;
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{$eol_status}{CAPACITY_PERC}{VALUE}=$incid_totals{CAPACITY}/$incid_totals{MONITORING}*100 if($incid_totals{MONITORING}>0);
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{$eol_status}{CAPACITY_PERC}{HTML}=$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{$eol_status}{CAPACITY_PERC}{VALUE};

					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{ALL}{CAPACITY_PERC}{VALUE}=0;
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{ALL}{CAPACITY_PERC}{VALUE}=$incid_totals{CAPACITY}/$incid_totals{MONITORING}*100 if($incid_totals{MONITORING}>0);
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{ALL}{CAPACITY_PERC}{HTML}=$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{ALL}{CAPACITY_PERC}{VALUE};

					#
					#
					# MEMORY
					###Less Than 20 Percent Free
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT20PCTFREE'}{VALUE} += $systems_with_lt20pctfree;
					my $value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT20PCTFREE'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT20PCTFREE'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct20&eol_status=$eol_status&mapping=mem\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT20PCTFREE'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT20PCTFREE'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT20PCTFREE'}{COLOR} = $green;
					}


					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT20PCTFREE'}{VALUE} += $systems_with_lt20pctfree;
					$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT20PCTFREE'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT20PCTFREE'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct20&eol_status=ALL&mapping=mem\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT20PCTFREE'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT20PCTFREE'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT20PCTFREE'}{COLOR} = $green;
					}

					###Less Than 10 Percent Free
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT10PCTFREE'}{VALUE} += $systems_with_lt10pctfree;
					$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT10PCTFREE'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT10PCTFREE'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct10&eol_status=$eol_status&show_kpe=1&mapping=mem\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT10PCTFREE'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT10PCTFREE'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT10PCTFREE'}{GREEN} = $green;
					}

					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT10PCTFREE'}{VALUE} += $systems_with_lt10pctfree;
					$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT10PCTFREE'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT10PCTFREE'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct10&eol_status=ALL&show_kpe=1&mapping=mem\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT10PCTFREE'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT10PCTFREE'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT10PCTFREE'}{COLOR} = $green;
					}

					###Less Than 5 Percent Free
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT5PCTFREE'}{VALUE} += $systems_with_lt5pctfree;
					$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT5PCTFREE'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT5PCTFREE'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct5&eol_status=$eol_status&show_kpe=1&mapping=mem\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT5PCTFREE'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT5PCTFREE'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT5PCTFREE'}{GREEN} = $green;
					}

					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT5PCTFREE'}{VALUE} += $systems_with_lt5pctfree_kpe;
					$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT5PCTFREE'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT5PCTFREE'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct5&eol_status=ALL&show_kpe=1&mapping=mem\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT5PCTFREE'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT5PCTFREE'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT5PCTFREE'}{COLOR} = $green;
					}

					#################
					#
					#
					# CPU
					###Less Than 20 Percent Free
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT20PCTFREE'}{VALUE} += $systems_with_cpult20pctfree;
					my $value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT20PCTFREE'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT20PCTFREE'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct20&eol_status=$eol_status&mapping=cpu\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT20PCTFREE'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT20PCTFREE'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT20PCTFREE'}{COLOR} = $green;
					}


					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT20PCTFREE'}{VALUE} += $systems_with_cpult20pctfree;
					$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT20PCTFREE'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT20PCTFREE'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct20&eol_status=ALL&mapping=cpu\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT20PCTFREE'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT20PCTFREE'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT20PCTFREE'}{COLOR} = $green;
					}

					###Less Than 10 Percent Free
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT10PCTFREE'}{VALUE} += $systems_with_cpult10pctfree;
					$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT10PCTFREE'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT10PCTFREE'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct10&eol_status=$eol_status&show_kpe=1&mapping=cpu\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT10PCTFREE'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT10PCTFREE'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT10PCTFREE'}{GREEN} = $green;
					}

					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT10PCTFREE'}{VALUE} += $systems_with_cpult10pctfree;
					$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT10PCTFREE'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT10PCTFREE'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct10&eol_status=ALL&show_kpe=1&mapping=cpu\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT10PCTFREE'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT10PCTFREE'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT10PCTFREE'}{COLOR} = $green;
					}

					###Less Than 5 Percent Free
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT5PCTFREE'}{VALUE} += $systems_with_cpult5pctfree;
					$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT5PCTFREE'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT5PCTFREE'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct5&eol_status=$eol_status&show_kpe=1&mapping=cpu\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT5PCTFREE'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT5PCTFREE'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CPULT5PCTFREE'}{GREEN} = $green;
					}

					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT5PCTFREE'}{VALUE} += $systems_with_cpult5pctfree;
					$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT5PCTFREE'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT5PCTFREE'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct5&eol_status=ALL&show_kpe=1&mapping=cpu\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT5PCTFREE'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT5PCTFREE'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CPULT5PCTFREE'}{COLOR} = $green;
					}

					###Total Space
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALMEMORY'}{VALUE} += sprintf "%.2f",$total;
					$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALMEMORY'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALMEMORY'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=$eol_status&show_kpe=1&mapping=mem\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALMEMORY'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALMEMORY'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALMEMORY'}{GREEN} = $green;
					}

					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALMEMORY'}{VALUE} += sprintf "%.2f",$total;
					$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALMEMORY'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALMEMORY'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=ALL&show_kpe=1&mapping=mem\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALMEMORY'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALMEMORY'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALMEMORY'}{COLOR} = $green;
					}

					###Free Space
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'SWAPTOTAL'}{VALUE} += sprintf "%.2f",$swaptotal;
					$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'SWAPTOTAL'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'SWAPTOTAL'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=$eol_status&show_kpe=1&mapping=mem\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'SWAPTOTAL'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'SWAPTOTAL'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'SWAPTOTAL'}{GREEN} = $green;
					}

					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'SWAPTOTAL'}{VALUE} += sprintf "%.2f",$swaptotal;
					$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'SWAPTOTAL'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'SWAPTOTAL'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=ALL&show_kpe=1&mapping=mem\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'SWAPTOTAL'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'SWAPTOTAL'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'SWAPTOTAL'}{COLOR} = $green;
					}

					###USED Space
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'USEDPERCENT'}{VALUE} += sprintf "%.2f",$usedpct;
					$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'USEDPERCENT'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'USEDPERCENT'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=$eol_status&show_kpe=1&mapping=mem\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'USEDPERCENT'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'USEDPERCENT'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'USEDPERCENT'}{GREEN} = $green;
					}

					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'USEDPERCENT'}{VALUE} += sprintf "%.2f",$usedpct;
					$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'USEDPERCENT'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'USEDPERCENT'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=ALL&show_kpe=1&mapping=mem\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'USEDPERCENT'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'USEDPERCENT'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'USEDPERCENT'}{COLOR} = $green;
					}

					###USED Space
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'SWAPUSEDPCT'}{VALUE} += sprintf "%.2f",$swapusedpct;
					$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'SWAPUSEDPCT'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'SWAPUSEDPCT'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=$eol_status&show_kpe=1&mapping=mem\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'SWAPUSEDPCT'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'SWAPUSEDPCT'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'SWAPUSEDPCT'}{GREEN} = $green;
					}

					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'SWAPUSEDPCT'}{VALUE} += sprintf "%.2f",$swapusedpct;
					$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'SWAPUSEDPCT'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'SWAPUSEDPCT'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_memcpu.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=ALL&show_kpe=1&mapping=mem\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'SWAPUSEDPCT'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'SWAPUSEDPCT'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'SWAPUSEDPCT'}{COLOR} = $green;
					}


					###Crtitical Perf Alerts
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{VALUE} += $perf_crit_server;
					$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{HTML}
						= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=$eol_status&type=PERF&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{COLOR} = $green;
					}

					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{VALUE} += $perf_crit_server;
					$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{HTML}
						= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=ALL&type=PERF&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{COLOR} = $green;
					}

					##Critical FS Alerts
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{VALUE} += $fs_crit_server;
					$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{HTML}
						= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=$eol_status&type=FS&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{COLOR} = $green;
					}

					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{VALUE} += $fs_crit_server;
					# print STDERR "$fqdn $count\n" if ($incid_by_node{$fqdn}{FS});
					$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{HTML}
						= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=ALL&type=FS&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{COLOR} = $green;
					}

					###ALL Crtitical Alerts
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{VALUE} += $all_crit_server;
					$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{HTML}
						= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=$eol_status&type=ALL&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{COLOR} = $green;
					}

					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{VALUE} += $all_crit_server;
					# print STDERR "$fqdn $count\n" if ($incid_by_node{$fqdn}{FS});
					$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{HTML}
						= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=ALL&type=ALL&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{COLOR} = $green;
					}

					###Crtitical Monitoring Alerts
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{VALUE} += $mon_crit_server;
					$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{HTML}
						= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=$eol_status&type=MONITORING&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{COLOR} = $green;
					}

					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{VALUE} += $mon_crit_server;
					# print STDERR "$fqdn $count\n" if ($incid_by_node{$fqdn}{FS});
					$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{HTML}
						= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=ALL&type=MONITORING&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{COLOR} = $green;
					}

					###Crtitical Customer Alerts
					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{VALUE} += $cust_crit_server;
					$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{HTML}
						= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=$eol_status&type=CUSTOMER&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{COLOR} = $green;
					}

					$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{VALUE} += $cust_crit_server;
					# print STDERR "$fqdn $count\n" if ($incid_by_node{$fqdn}{FS});
					$value = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{VALUE};
					if ($value > 0) {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{HTML}
						= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=ALL&type=CUSTOMER&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{COLOR} = $red;
					} else {
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{HTML} = 0;
						$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{COLOR} = $green;
					}

					$count++;
				}
			}
		}
	}

	if (defined($opts{'p'})) {
	   ##PDXC_Updates
	   foreach my $customer (keys %pdxc_customers) {
	   		my $pdxc_instance = $pdxc_customers{$customer}{INSTANCE};
	   		$l2_server_memcpu{CUSTOMER}{$customer}{PDXC_INSTANCE_LIST}{$pdxc_instance} = $pdxc_customers{$customer}{INSTANCE_URL};
	   		print "PDXCINSTANCELIST: $l2_server_memcpu{CUSTOMER}{$customer}{PDXC_INSTANCE_LIST}{$pdxc_instance}\n";

	   		update_pdxc_ssz(\%l2_server_memcpu,$pdxc_instance,"l2_server_memcpu.pl?aggregation=L2.5");
	   }
 	}
	}

sub nonesl_account_fs {

	my ($customer) = shift;
	my %counted_fqdn;
	my %counted_fqdn_fs;
	my %counted_fqdn_perf;
	my $count=1;

	my $file_name = "$account_reg{$customer}{sp_mapping_file}"."_server_capacity_30_DAYS";
	my $sys =  load_cache_byFile("$cache_dir/by_customer/$file_name");
	my %server_capacity = %{$sys};

	my $server_count;
  ($server_count) = scalar (keys %{$server_capacity{DATA}});
  my $current_tick = time();
  my ($latest_record)= sprintf "%d",($current_tick - $server_capacity{LATEST_RECORD}) / (24 * 60 * 60);
	my $not_in_cmdb=$server_count;

	my $c = 0;
	##PDXC Changes
	my %pdxc_customers;
	my $pdxc_list;
	if (defined($opts{'p'})) {
    $pdxc_list = get_pdxc_instance('server_capacity');
		foreach my $pdxc_instance (@{$pdxc_list}) {
			print "PDXC Instance found -- $pdxc_instance\n";
  		my $pdxc_cfg = get_pdxc_cache_files($pdxc_instance,'server_capacity');
  		my $ssz_dir = $pdxc_cfg->{$pdxc_instance}{'ssz_instance_dir'} . '/core_receiver';
		  my $instance_url = $pdxc_cfg->{$pdxc_instance}{'instance_url'};
  		my $mapping = update_pdxc_cache("$ssz_dir/l2_cache",'cache.l2_server_capacity',$pdxc_instance,$instance_url);
  		my $pdxc_inc = load_cache_byFile("$ssz_dir/l2_cache/cache.l2_server_capacity");
  		 foreach my $customer (keys %{$pdxc_inc->{CUSTOMER}}) {
  		 	$l2_server_capacity{CUSTOMER}{$customer} = \%{$pdxc_inc->{CUSTOMER}{$customer}};
  		 }
  		foreach my $customer_pdxc (keys %{$mapping}) {
  			$pdxc_customers{$customer_pdxc}{INSTANCE} = $mapping->{$customer_pdxc}{INSTANCE};
  			$pdxc_customers{$customer_pdxc}{INSTANCE_URL} = $mapping->{$customer_pdxc}{INSTANCE_URL};
  			#print "MAPPED: $mapping->{$customer_pdxc}{INSTANCE} and $mapping->{$customer_pdxc}{INSTANCE_URL}\n";
  		}
		}
	}
	foreach my $owner ('ALL','OWNER','SSN','ESO4SAP_OWNED','ESO4SAP_USES') {
		my %totalfs;

		foreach my $fqdn (sort keys %{$server_capacity{DATA}}) {
			next if( $fqdn =~/^\s*$/);
			my $system_type = "server";
			my $status = "in production";
			my $impact = "";
			my $eol_status = "";
			my $owner_flag = "1";
			my $ssn_flag = "1";
			my $eso_flag = "1";
			my $filesystems_with_lt5pctfree = 0;
			my $filesystems_with_lt5pctfree_kpe = 0;
			my $filesystems_with_lt10pctfree = 0;
			my $filesystems_with_lt10pctfree_kpe = 0;
			my $filesystems_with_lt20pctfree = 0;
			my $filesystems_with_lt20pctfree_kpe = 0;
			my $totalmb=0;
			my $usedmb = 0;
			my $freemb =0;
			my $kpe_name = "";
			my $service_level = "";

			#				print "$fqdn SYS TYPE: $system_type - OWNER: $owner - OWNER_FLAG: $owner_flag - SSN_FLAG: $ssn_flag SVC LEVEL: $service_level\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);

			next if ($system_type !~ /server|cluster node/i);
			next if ($owner eq "OWNER" and $owner_flag == 0);
			next if ($owner eq "SSN" and ($owner_flag == 0 or $ssn_flag == 0));
			next if ($owner eq "ESO4SAP_OWNED" and ($owner_flag == 0 or $eso_flag == 0));
			next if ($owner eq "ESO4SAP_USES" and ($owner_flag == 1 or $eso_flag == 0));

			#print "FQDN: $fqdn\n";
			my $tax_cap = "windows";
			my $mapping;
			my %teams;
			my %capability;

			$capability{ALL}=1;
			$capability{$tax_cap} = 1;
			$teams{ALL} = 1;



			#				$os_class{'other'} = 1 if (not defined($os_class{'windows'}) and not defined($os_class{'unix'}));

			my %kpe_list;
			foreach my $cap (keys %capability) {
				foreach my $team (keys %teams) {
					# Save Baseline

					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{COUNT} = $server_count;
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{COUNT} = $server_count;

					#Calculate the ETP
					if ($service_level =~ /hosting only|not supported/i ) {

						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{SERVER_CAPACITY_ETP}{VALUE}++;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{SERVER_CAPACITY_ETP}{HTML} = "<a href=\"$drilldown_dir/eslSystemCI.pl?customer=$customer&status=$status&system_type=server_and_node&capability=$cap&center=ALL&owner_flag=$owner&team=$team&eol_status=$eol_status&etp=all\">$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{PERC_INC_ETP}{VALUE}</a>";

						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{SERVER_CAPACITY_ETP}{VALUE}++;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{SERVER_CAPACITY_ETP}{HTML} = "<a href=\"$drilldown_dir/eslSystemCI.pl?customer=$customer&status=$status&system_type=server_and_node&capability=$cap&center=ALL&owner_flag=$owner&team=$team&eol_status=ALL&etp=all\">$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{SERVER_CAPACITY_ETP}{VALUE}</a>";

						next;
					}

					#						print "processing $fqdn\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);

					#Eligible CI
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{SERVER_CAPACITY_ELIGIBLE}{VALUE}++;
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{SERVER_CAPACITY_ELIGIBLE}{HTML} = '<a href="/cgi-bin/GTOD_CC/l3_drilldowns/l3_cva_availability.pl?customer='.$customer.'&type=baseline">'.$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{SERVER_CAPACITY_ELIGIBLE}{VALUE}.'</a>';

					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{SERVER_CAPACITY_ELIGIBLE}{VALUE}++;
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{SERVER_CAPACITY_ELIGIBLE}{HTML} = '<a href="/cgi-bin/GTOD_CC/l3_drilldowns/l3_cva_availability.pl?customer='.$customer.'&type=baseline">'.$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{SERVER_CAPACITY_ELIGIBLE}{VALUE}.'</a>';

					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CMDB}{VALUE}=$not_in_cmdb||0;
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CMDB}{COLOR}="green";
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CMDB}{COLOR}="amber" if ($not_in_cmdb>0);
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CMDB}{HTML}="<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=$mapping\">$not_in_cmdb</a>";
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CMDB}{HTML}="0" if ($not_in_cmdb==0);

					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CMDB}{VALUE}=$not_in_cmdb||0;
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CMDB}{COLOR}="green";
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CMDB}{COLOR}="amber" if ($not_in_cmdb>0);
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CMDB}{HTML}="<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=$mapping\">$not_in_cmdb</a>";
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CMDB}{HTML}="0"  if ($not_in_cmdb==0);

					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{LATEST_RECORD}{VALUE}=$latest_record;
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{LATEST_RECORD}{COLOR}="green" ;
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{LATEST_RECORD}{COLOR}="red" if ($latest_record>1);
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{LATEST_RECORD}{HTML}="<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=$mapping\">$latest_record</a>";
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{LATEST_RECORD}{HTML}="0" if ($latest_record==0);

					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{LATEST_RECORD}{VALUE}=$latest_record;
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{LATEST_RECORD}{COLOR}="green";
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{LATEST_RECORD}{COLOR}="red" if ($latest_record>1);
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{LATEST_RECORD}{HTML}="<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=$mapping\">$latest_record</a>";
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{LATEST_RECORD}{HTML}="0" if ($latest_record==0);

					print "NON ESL CUSTOMER $customer TEAM $team, CAP $cap FQDN $fqdn\n";
					# From here on - this fqdn is to be included in report...
					my $fs_crit_server = 0;
					if (defined($incid_by_node{$fqdn})) {
						if (!defined($counted_fqdn_fs{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn})) {
							$counted_fqdn_fs{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1;
							$fs_crit_server = ($incid_by_node{$fqdn}{FS} > 0);
							#								$tmp_server_fs_count{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{FS} > 0);
							#								$tmp_server_fs_count{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{FS} > 0);
						}
					}

					my $perf_crit_server = 0;
					if (defined($incid_by_node{$fqdn})) {
						#							print "found $fqdn in PERF list\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);
						if (!defined($counted_fqdn_perf{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn})) {
							$counted_fqdn_perf{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1;
							$perf_crit_server = ($incid_by_node{$fqdn}{PERF} > 0);
							#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
							#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
						}
					}


					my $all_crit_server = 0;
					if (defined($incid_by_node{$fqdn})) {
#							print "found $fqdn in PERF list\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);
						if (!defined($counted_fqdn_all{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn})) {
							$counted_fqdn_all{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1;
							$all_crit_server = ($incid_by_node{$fqdn}{ALL} > 0);
#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
						}
					}

					my $mon_crit_server = 0;
					if (defined($incid_by_node{$fqdn})) {
#							print "found $fqdn in PERF list\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);
						if (!defined($counted_fqdn_mon{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn})) {
							$counted_fqdn_mon{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1;
							$mon_crit_server = ($incid_by_node{$fqdn}{MONITORING} > 0);
#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
						}
					}

					my $cust_crit_server = 0;
					if (defined($incid_by_node{$fqdn})) {
#							print "found $fqdn in PERF list\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);
						if (!defined($counted_fqdn_cust{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn})) {
							$counted_fqdn_cust{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1;
							$cust_crit_server = ($incid_by_node{$fqdn}{CUSTOMER} > 0);
#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
						}
					}


					my @sys_3m;
					foreach my $sample (sort {$b <=> $a || $b cmp $a }  keys %{$server_capacity{DATA}{$fqdn}{filesystem}}) {
						foreach my $fs (keys %{$server_capacity{DATA}{$fqdn}{filesystem}{$sample}}) {
							next if ($server_capacity{RESOURCE_TYPE}{$fqdn}{filesystem}{$fs}{resource_type} eq "cdrom");
							if (!defined($counted_fqdn{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn}{$fs}))	{
								$counted_fqdn{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn}{$fs} = 1;
								$totalfs{$fqdn."__".$fs}=1;
								$totalmb +=  $server_capacity{DATA}{$fqdn}{filesystem}{$sample}{$fs}{'system.filesystem.total'}*0.000001;
								$usedmb +=  $server_capacity{DATA}{$fqdn}{filesystem}{$sample}{$fs}{'system.filesystem.used.bytes'}*0.000001;
								$freemb +=  $server_capacity{DATA}{$fqdn}{filesystem}{$sample}{$fs}{'system.filesystem.free'}*0.000001;

								my $pctfree = sprintf "%.2f", $server_capacity{DATA}{$fqdn}{filesystem}{$sample}{$fs}{'system.filesystem.used.bytes'}/$server_capacity{DATA}{$fqdn}{filesystem}{$sample}{$fs}{'system.filesystem.total'}*100 if ($server_capacity{DATA}{$fqdn}{filesystem}{$sample}{$fs}{'system.filesystem.total'}>0);
								if($pctfree >=95){
									$filesystems_with_lt5pctfree++;
									$filesystems_with_lt5pctfree_kpe++ if ($kpe_name ne "");
								}elsif($pctfree >=90) {
									$filesystems_with_lt10pctfree++;
									$filesystems_with_lt10pctfree_kpe++ if ($kpe_name ne "");
								}elsif($pctfree >=80){
									$filesystems_with_lt20pctfree++;
									$filesystems_with_lt20pctfree_kpe++ if ($kpe_name ne "");
								}

							}
						}
					}
					my ($totalfs_value) =scalar(keys %totalfs);
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALFS'}{VALUE}=$totalfs_value;
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALFS'}{HTML}="<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=$mapping\">$totalfs_value</a>";
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALFS'}{VALUE}=$totalfs_value;
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALFS'}{HTML}="<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=$mapping\">$totalfs_value</a>";

					###############################################################################
					### COPY INCIDENT COUNTS FOR L1 ROLLUP

#					# Get this from L2 Incident Tile
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{$eol_status}{CAPACITY_PERC}{VALUE}=0;
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{$eol_status}{CAPACITY_PERC}{VALUE}=$incid_totals{CAPACITY}/$incid_totals{MONITORING}*100 if($incid_totals{MONITORING}>0);
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{$eol_status}{CAPACITY_PERC}{HTML}=#$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{$eol_status}{CAPACITY_PERC}{VALUE};
#					= $l2_incidents{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{$eol_status}{CAPACITY_30DAYS};
#
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{ALL}{CAPACITY_PERC}{VALUE}=0;
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{ALL}{CAPACITY_PERC}{VALUE}=$incid_totals{CAPACITY}/$incid_totals{MONITORING}*100 if($incid_totals{MONITORING}>0);
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{ALL}{CAPACITY_PERC}{HTML}=$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{ALL}{CAPACITY_PERC}{VALUE};
#					= $l2_incidents{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{ALL}{CAPACITY_30DAYS};

					#
					#
					#
					###Less Than 20 Percent Free
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT20PCTFREE'}{VALUE} += $filesystems_with_lt20pctfree;
					my $value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT20PCTFREE'}{VALUE};
					if ($value > 0) {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT20PCTFREE'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct20&eol_status=$eol_status&mapping=$mapping\">" . $value . "</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT20PCTFREE'}{COLOR} = $red;
					} else {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT20PCTFREE'}{HTML} = 0;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT20PCTFREE'}{COLOR} = $green;
					}


					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT20PCTFREE'}{VALUE} += $filesystems_with_lt20pctfree;
					$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT20PCTFREE'}{VALUE};
					if ($value > 0) {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT20PCTFREE'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct20&eol_status=ALL&mapping=$mapping\">" . $value . "</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT20PCTFREE'}{COLOR} = $red;
					} else {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT20PCTFREE'}{HTML} = 0;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT20PCTFREE'}{COLOR} = $green;
					}

					###Less Than 10 Percent Free
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT10PCTFREE'}{VALUE} += $filesystems_with_lt10pctfree;
					$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT10PCTFREE'}{VALUE};
					if ($value > 0) {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT10PCTFREE'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct10&eol_status=$eol_status&show_kpe=1&mapping=$mapping\">" . $value . "</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT10PCTFREE'}{COLOR} = $red;
					} else {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT10PCTFREE'}{HTML} = 0;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT10PCTFREE'}{GREEN} = $green;
					}

					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT10PCTFREE'}{VALUE} += $filesystems_with_lt10pctfree;
					$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT10PCTFREE'}{VALUE};
					if ($value > 0) {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT10PCTFREE'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct10&eol_status=ALL&show_kpe=1&mapping=$mapping\">" . $value . "</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT10PCTFREE'}{COLOR} = $red;
					} else {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT10PCTFREE'}{HTML} = 0;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT10PCTFREE'}{COLOR} = $green;
					}

					###Less Than 5 Percent Free
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT5PCTFREE'}{VALUE} += $filesystems_with_lt5pctfree;
					$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT5PCTFREE'}{VALUE};
					if ($value > 0) {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT5PCTFREE'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct5&eol_status=$eol_status&show_kpe=1&mapping=$mapping\">" . $value . "</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT5PCTFREE'}{COLOR} = $red;
					} else {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT5PCTFREE'}{HTML} = 0;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT5PCTFREE'}{GREEN} = $green;
					}

					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT5PCTFREE'}{VALUE} += $filesystems_with_lt5pctfree;
					$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT5PCTFREE'}{VALUE};
					if ($value > 0) {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT5PCTFREE'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct5&eol_status=ALL&show_kpe=1&mapping=$mapping\">" . $value . "</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT5PCTFREE'}{COLOR} = $red;
					} else {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT5PCTFREE'}{HTML} = 0;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT5PCTFREE'}{COLOR} = $green;
					}

					###Total Space
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALMB'}{VALUE} += sprintf "%.2f",$totalmb;
					$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALMB'}{VALUE};
					if ($value > 0) {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALMB'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=$eol_status&show_kpe=1&mapping=$mapping\">" . $value . "</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALMB'}{COLOR} = $red;
					} else {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALMB'}{HTML} = 0;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALMB'}{GREEN} = $green;
					}

					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALMB'}{VALUE} += sprintf "%.2f",$totalmb;
					$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALMB'}{VALUE};
					if ($value > 0) {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALMB'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=ALL&show_kpe=1&mapping=$mapping\">" . $value . "</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALMB'}{COLOR} = $red;
					} else {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALMB'}{HTML} = 0;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALMB'}{COLOR} = $green;
					}

					###Free Space
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'USEDMB'}{VALUE} += sprintf "%.2f",$usedmb;
					$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'USEDMB'}{VALUE};
					if ($value > 0) {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'USEDMB'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=$eol_status&show_kpe=1&mapping=$mapping\">" . $value . "</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'USEDMB'}{COLOR} = $red;
					} else {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'USEDMB'}{HTML} = 0;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'USEDMB'}{GREEN} = $green;
					}

					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'USEDMB'}{VALUE} += sprintf "%.2f",$usedmb;
					$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'USEDMB'}{VALUE};
					if ($value > 0) {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'USEDMB'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=ALL&show_kpe=1&mapping=$mapping\">" . $value . "</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'USEDMB'}{COLOR} = $red;
					} else {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'USEDMB'}{HTML} = 0;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'USEDMB'}{COLOR} = $green;
					}

					###USED Space
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FREEMB'}{VALUE} += sprintf "%.2f",$freemb;
					$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FREEMB'}{VALUE};
					if ($value > 0) {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FREEMB'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=$eol_status&show_kpe=1&mapping=$mapping\">" . $value . "</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FREEMB'}{COLOR} = $red;
					} else {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FREEMB'}{HTML} = 0;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FREEMB'}{GREEN} = $green;
					}

					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FREEMB'}{VALUE} += sprintf "%.2f",$freemb;
					$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FREEMB'}{VALUE};
					if ($value > 0) {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FREEMB'}{HTML}
						= "<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=ALL&show_kpe=1&mapping=$mapping\">" . $value . "</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FREEMB'}{COLOR} = $red;
					} else {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FREEMB'}{HTML} = 0;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FREEMB'}{COLOR} = $green;
					}

					###Crtitical Perf Alerts
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{VALUE} += $perf_crit_server;
					$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{VALUE};
					if ($value > 0) {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{HTML}
						= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=$eol_status&type=PERF&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{COLOR} = $red;
					} else {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{HTML} = 0;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{COLOR} = $green;
					}

					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{VALUE} += $perf_crit_server;
					$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{VALUE};
					if ($value > 0) {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{HTML}
						= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=ALL&type=PERF&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{COLOR} = $red;
					} else {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{HTML} = 0;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{COLOR} = $green;
					}

					##Critical FS Alerts
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{VALUE} += $fs_crit_server;
					$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{VALUE};
					if ($value > 0) {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{HTML}
						= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=$eol_status&type=FS&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{COLOR} = $red;
					} else {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{HTML} = 0;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{COLOR} = $green;
					}

					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{VALUE} += $fs_crit_server;
					# print STDERR "$fqdn $count\n" if ($incid_by_node{$fqdn}{FS});
					$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{VALUE};
					if ($value > 0) {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{HTML}
						= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=ALL&type=FS&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{COLOR} = $red;
					} else {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{HTML} = 0;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{COLOR} = $green;
					}

					###ALL Crtitical Alerts
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{VALUE} += $all_crit_server;
					$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{VALUE};
					if ($value > 0) {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{HTML}
						= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=$eol_status&type=ALL&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{COLOR} = $red;
					} else {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{HTML} = 0;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{COLOR} = $green;
					}

					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{VALUE} += $all_crit_server;
					# print STDERR "$fqdn $count\n" if ($incid_by_node{$fqdn}{FS});
					$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{VALUE};
					if ($value > 0) {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{HTML}
						= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=ALL&type=ALL&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{COLOR} = $red;
					} else {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{HTML} = 0;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{COLOR} = $green;
					}

					###Crtitical Monitoring Alerts
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{VALUE} += $mon_crit_server;
					$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{VALUE};
					if ($value > 0) {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{HTML}
						= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=$eol_status&type=MONITORING&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{COLOR} = $red;
					} else {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{HTML} = 0;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{COLOR} = $green;
					}

					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{VALUE} += $mon_crit_server;
					# print STDERR "$fqdn $count\n" if ($incid_by_node{$fqdn}{FS});
					$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{VALUE};
					if ($value > 0) {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{HTML}
						= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=ALL&type=MONITORING&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{COLOR} = $red;
					} else {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{HTML} = 0;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{COLOR} = $green;
					}

					###Crtitical Customer Alerts
					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{VALUE} += $cust_crit_server;
					$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{VALUE};
					if ($value > 0) {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{HTML}
						= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=$eol_status&type=CUSTOMER&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{COLOR} = $red;
					} else {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{HTML} = 0;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{COLOR} = $green;
					}

					$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{VALUE} += $cust_crit_server;
					# print STDERR "$fqdn $count\n" if ($incid_by_node{$fqdn}{FS});
					$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{VALUE};
					if ($value > 0) {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{HTML}
						= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=ALL&type=CUSTOMER&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{COLOR} = $red;
					} else {
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{HTML} = 0;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{COLOR} = $green;
					}

					$count++;
				}
			}
		}
	}

	if (defined($opts{'p'})) {
	   ##PDXC_Updates
	   foreach my $customer (keys %pdxc_customers) {
	   		my $pdxc_instance = $pdxc_customers{$customer}{INSTANCE};
	   		$l2_server_capacity{CUSTOMER}{$customer}{PDXC_INSTANCE_LIST}{$pdxc_instance} = $pdxc_customers{$customer}{INSTANCE_URL};
	   		print "PDXCINSTANCELIST: $l2_server_capacity{CUSTOMER}{$customer}{PDXC_INSTANCE_LIST}{$pdxc_instance}\n";

	   		update_pdxc_ssz(\%l2_server_capacity,$pdxc_instance,"l2_server_capacity.pl?aggregation=L2.5");
	   }
 	}
}

sub fs {

	my ($customer,$esl_system_ci) = @_;

	my %counted_fqdn;
	my %counted_fqdn_fs;
	my %counted_fqdn_perf;
	my $not_in_cmdb;

	my $count=1;
	##PDXC Changes
	my %pdxc_customers;
	my $pdxc_list;
	if (defined($opts{'p'})) {
    $pdxc_list = get_pdxc_instance('server_capacity');
		foreach my $pdxc_instance (@{$pdxc_list}) {
			print "PDXC Instance found -- $pdxc_instance\n";
  		my $pdxc_cfg = get_pdxc_cache_files($pdxc_instance,'server_capacity');
  		my $ssz_dir = $pdxc_cfg->{$pdxc_instance}{'ssz_instance_dir'} . '/core_receiver';
		  my $instance_url = $pdxc_cfg->{$pdxc_instance}{'instance_url'};
  		my $mapping = update_pdxc_cache("$ssz_dir/l2_cache",'cache.l2_server_capacity',$pdxc_instance,$instance_url);
  		my $pdxc_inc = load_cache_byFile("$ssz_dir/l2_cache/cache.l2_server_capacity");
  		 foreach my $customer (keys %{$pdxc_inc->{CUSTOMER}}) {
  		 	$l2_server_capacity{CUSTOMER}{$customer} = \%{$pdxc_inc->{CUSTOMER}{$customer}};
  		 }
  		foreach my $customer_pdxc (keys %{$mapping}) {
  			$pdxc_customers{$customer_pdxc}{INSTANCE} = $mapping->{$customer_pdxc}{INSTANCE};
  			$pdxc_customers{$customer_pdxc}{INSTANCE_URL} = $mapping->{$customer_pdxc}{INSTANCE_URL};
  			#print "MAPPED: $mapping->{$customer_pdxc}{INSTANCE} and $mapping->{$customer_pdxc}{INSTANCE_URL}\n";
  		}
		}
	}

	my $file_name = "$account_reg{$customer}{sp_mapping_file}"."_server_capacity_30_DAYS";
	my $sys =  load_cache_byFile("$cache_dir/by_customer/$file_name");
	#print "IN FS SUB loading $cache_dir/by_customer/$file_name\n";

	my %server_capacity = %{$sys};
	my $server_count;
  ($server_count) = scalar (keys %{$server_capacity{FQDNS}});
	#print "SERVERCOUNT:$server_count\n";
	foreach my $f (keys %{$server_capacity{FQDNS}}){
		$not_in_cmdb++ if(not defined($esl_system_ci->{$customer}{ALL}{$f}));
	}

	my $current_tick = time();
	my ($latest_record)= sprintf "%d",($current_tick - $server_capacity{LATEST_RECORD}) / (24 * 60 * 60);

	my $c = 0;
	foreach my $center (keys %{$esl_system_ci->{$customer}}) {
		foreach my $owner ('ALL','OWNER','SSN','ESO4SAP_OWNED','ESO4SAP_USES') {
			my %totalfs;
			next if ($center ne "ALL" and $owner ne "OWNER");
			foreach my $fqdn (sort keys %{$esl_system_ci->{$customer}{$center}}) {
				next if( $fqdn =~/^\s*$/);
				#print "Found: $fqdn \n";# if (defined($server_capacity{DATA}{$fqdn}));
				#print Dumper $esl_system_ci->{$customer}{$center}{$fqdn} if (defined($server_capacity{DATA}{$fqdn}));
				my $system_type = $esl_system_ci->{$customer}{$center}{$fqdn}{SERVER_TYPE};
				my $status = $esl_system_ci->{$customer}{$center}{$fqdn}{STATUS};
				my $impact = $esl_system_ci->{$customer}{$center}{$fqdn}{ESL_IMPACT};
				my $eol_status = $esl_system_ci->{$customer}{$center}{$fqdn}{EOL_STATUS};
				my $owner_flag = $esl_system_ci->{$customer}{$center}{$fqdn}{OWNER_FLAG};
				my $ssn_flag = $esl_system_ci->{$customer}{$center}{$fqdn}{SSN};
				my $eso_flag = $esl_system_ci->{$customer}{$center}{$fqdn}{ESO4SAP};
				my $filesystems_with_lt5pctfree = 0;
        my $filesystems_with_lt5pctfree_kpe = 0;
        my $filesystems_with_lt10pctfree = 0;
        my $filesystems_with_lt10pctfree_kpe = 0;
        my $filesystems_with_lt20pctfree = 0;
        my $filesystems_with_lt20pctfree_kpe = 0;
        my $totalmb=0;
        my $usedmb = 0;
        my $freemb =0;
        my $kpe_name = "";
         my $service_level = "";

				my $kpe_name = $esl_system_ci->{$customer}{$center}{$fqdn}{KPE_NAME};
				my $service_level = $esl_system_ci->{$customer}{$center}{$fqdn}{SERVICE_LEVEL};

				#				print "$fqdn SYS TYPE: $system_type - OWNER: $owner - OWNER_FLAG: $owner_flag - SSN_FLAG: $ssn_flag SVC LEVEL: $service_level\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);

				next if ($system_type !~ /server|cluster node/i);
				next if ($owner eq "OWNER" and $owner_flag == 0);
				next if ($owner eq "SSN" and ($owner_flag == 0 or $ssn_flag == 0));
				next if ($owner eq "ESO4SAP_OWNED" and ($owner_flag == 0 or $eso_flag == 0));
				next if ($owner eq "ESO4SAP_USES" and ($owner_flag == 1 or $eso_flag == 0));


				my $tax_cap = $esl_system_ci->{$customer}{$center}{$fqdn}{OS_INSTANCE_TAX_CAP};

				my %teams;
				 my $mapping;

				my %capability;

				$capability{ALL}=1;
				$capability{$tax_cap} = 1;
				$teams{ALL} = 1;
				foreach my $os_instance (keys %{$esl_system_ci->{$customer}{$center}{$fqdn}{ESL_ORG_CARD}}) {
					foreach my $esl_o (@{$esl_system_ci->{$customer}{$center}{$fqdn}{ESL_ORG_CARD}{$os_instance}}) {
						$teams{$esl_o->{ORG_NM}} = 1;
					}
				}
				#				$os_class{'other'} = 1 if (not defined($os_class{'windows'}) and not defined($os_class{'unix'}));

				my %kpe_list;
				foreach my $cap (keys %capability) {
					foreach my $team (keys %teams) {
						# Save Baseline
						#$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'cluster node'}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{COUNT} = $server_count;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{COUNT} = $server_count;

						#$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'cluster node'}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{COUNT} = $server_count;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{COUNT} = $server_count;

						#Calculate the ETP
						if ($service_level =~ /hosting only|not supported/i ) {

							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{SERVER_CAPACITY_ETP}{VALUE}++;
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{SERVER_CAPACITY_ETP}{HTML} = "<a href=\"$drilldown_dir/eslSystemCI.pl?customer=$customer&status=$status&system_type=server_and_node&capability=$cap&center=$center&owner_flag=$owner&team=$team&eol_status=$eol_status&etp=all\">$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{PERC_INC_ETP}{VALUE}</a>";

							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{SERVER_CAPACITY_ETP}{VALUE}++;
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{SERVER_CAPACITY_ETP}{HTML} = "<a href=\"$drilldown_dir/eslSystemCI.pl?customer=$customer&status=$status&system_type=server_and_node&capability=$cap&center=$center&owner_flag=$owner&team=$team&eol_status=ALL&etp=all\">$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{SERVER_CAPACITY_ETP}{VALUE}</a>";

							next;
						}

#						print "processing $fqdn\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);

						#Eligible CI
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{SERVER_CAPACITY_ELIGIBLE}{VALUE}++;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{SERVER_CAPACITY_ELIGIBLE}{HTML} = "<a href=\"$drilldown_dir/eslSystemCI.pl?customer=$customer&status=$status&system_type=server_and_node&capability=$cap&center=$center&owner_flag=$owner&team=$team&eol_status=$eol_status&eligible=all\">$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{PERC_INC_ELIGIBLE}{VALUE}</a>";

						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{SERVER_CAPACITY_ELIGIBLE}{VALUE}++;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{SERVER_CAPACITY_ELIGIBLE}{HTML} = "<a href=\"$drilldown_dir/eslSystemCI.pl?customer=$customer&status=$status&system_type=server_and_node&capability=$cap&center=$center&owner_flag=$owner&team=$team&eol_status=ALL&eligible=all\">$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{SERVER_CAPACITY_ELIGIBLE}{VALUE}</a>";

						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CVA}{VALUE}++ if(not defined($server_capacity{FQDNS}{$fqdn}));
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CVA}{COLOR}="green";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CVA}{COLOR}="red" if($l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CVA}{VALUE}>0);
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CVA}{HTML}="<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=$mapping\">$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CVA}{VALUE}</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CVA}{HTML}="0" if($l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CVA}{VALUE}==0);

						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CVA}{VALUE}++ if(not defined($server_capacity{FQDNS}{$fqdn}));
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CVA}{COLOR}="green";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CVA}{COLOR}="red" if($l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CVA}{VALUE}>0);
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CVA}{HTML}="<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=$mapping\">$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CVA}{VALUE}</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CVA}{HTML}="0" if($l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CVA}{VALUE}==0);

						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CMDB}{VALUE}=$not_in_cmdb||0;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CMDB}{COLOR}="green";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CMDB}{COLOR}="amber" if ($not_in_cmdb>0);
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CMDB}{HTML}="<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=$mapping\">$not_in_cmdb</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NOT_IN_CMDB}{HTML}="0" if ($not_in_cmdb==0);

						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CMDB}{VALUE}=$not_in_cmdb||0;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CMDB}{COLOR}="green";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CMDB}{COLOR}="amber" if ($not_in_cmdb>0);
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CMDB}{HTML}="<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=$mapping\">$not_in_cmdb</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NOT_IN_CMDB}{HTML}="0" if ($not_in_cmdb==0);

						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{LATEST_RECORD}{VALUE}=$latest_record;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{LATEST_RECORD}{COLOR}="green";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{LATEST_RECORD}{COLOR}="red" if ($latest_record>1);
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{LATEST_RECORD}{HTML}="<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=$mapping\">$latest_record</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{LATEST_RECORD}{HTML}="0" if ($latest_record==0);

						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{LATEST_RECORD}{VALUE}=$latest_record;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{LATEST_RECORD}{COLOR}="green";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{LATEST_RECORD}{COLOR}="red" if ($latest_record>1);
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{LATEST_RECORD}{HTML}="<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=$mapping\">$latest_record</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{LATEST_RECORD}{HTML}="0" if ($latest_record==0);

						# From here on - this fqdn is to be included in report...
						my $fs_crit_server = 0;
						if (defined($incid_by_node{$fqdn})) {
							if (!defined($counted_fqdn_fs{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn})) {
								$counted_fqdn_fs{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1;
								$fs_crit_server = ($incid_by_node{$fqdn}{FS} > 0);
								#								$tmp_server_fs_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{FS} > 0);
								#								$tmp_server_fs_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{FS} > 0);
							}
						}

						my $perf_crit_server = 0;
						if (defined($incid_by_node{$fqdn})) {
							#							print "found $fqdn in PERF list\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);
							if (!defined($counted_fqdn_perf{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn})) {
								$counted_fqdn_perf{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1;
								$perf_crit_server = ($incid_by_node{$fqdn}{PERF} > 0);
								#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
								#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
							}
						}


						my $all_crit_server = 0;
						if (defined($incid_by_node{$fqdn})) {
							#							print "found $fqdn in PERF list\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);
							if (!defined($counted_fqdn_all{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn})) {
								$counted_fqdn_all{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1;
								$all_crit_server = ($incid_by_node{$fqdn}{ALL} > 0);
								#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
								#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
							}
						}

						my $mon_crit_server = 0;
						if (defined($incid_by_node{$fqdn})) {
							#							print "found $fqdn in PERF list\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);
							if (!defined($counted_fqdn_mon{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn})) {
								$counted_fqdn_mon{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1;
								$mon_crit_server = ($incid_by_node{$fqdn}{MONITORING} > 0);
								#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
								#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
							}
						}

						my $cust_crit_server = 0;
						if (defined($incid_by_node{$fqdn})) {
							#							print "found $fqdn in PERF list\n" if ($fqdn =~ /bocuspt02|reuxeuus136/i);
							if (!defined($counted_fqdn_cust{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn})) {
								$counted_fqdn_cust{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1;
								$cust_crit_server = ($incid_by_node{$fqdn}{CUSTOMER} > 0);
								#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
								#								$tmp_server_perf_count{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{$fqdn} = 1 if ($incid_by_node{$fqdn}{PERF} > 0);
							}
						}


						my @sys_3m;
						foreach my $sample (sort {$b <=> $a || $b cmp $a }  keys %{$server_capacity{DATA}{$fqdn}{filesystem}}) {
							foreach my $fs (keys %{$server_capacity{DATA}{$fqdn}{filesystem}{$sample}}) {
								next if ($server_capacity{RESOURCE_TYPE}{$fqdn}{filesystem}{$fs}{resource_type} eq "cdrom");
								if (!defined($counted_fqdn{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn}{$fs}))	{
									$counted_fqdn{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{$fqdn}{$fs} = 1;
									$totalfs{$fqdn."__".$fs}=1;
									$totalmb +=  $server_capacity{DATA}{$fqdn}{filesystem}{$sample}{$fs}{'system.filesystem.total'}*0.000001;
									$usedmb +=  $server_capacity{DATA}{$fqdn}{filesystem}{$sample}{$fs}{'system.filesystem.used.bytes'}*0.000001;
									$freemb +=  $server_capacity{DATA}{$fqdn}{filesystem}{$sample}{$fs}{'system.filesystem.free'}*0.000001;

									my $pctfree = sprintf "%.2f", $server_capacity{DATA}{$fqdn}{filesystem}{$sample}{$fs}{'system.filesystem.used.bytes'}/$server_capacity{DATA}{$fqdn}{filesystem}{$sample}{$fs}{'system.filesystem.total'}*100 if ($server_capacity{DATA}{$fqdn}{filesystem}{$sample}{$fs}{'system.filesystem.total'}>0);
									if($pctfree >=95){
										$filesystems_with_lt5pctfree++;
										$filesystems_with_lt5pctfree_kpe++ if ($kpe_name ne "");
									}elsif($pctfree >=90) {
										$filesystems_with_lt10pctfree++;
										$filesystems_with_lt10pctfree_kpe++ if ($kpe_name ne "");
									}elsif($pctfree >=80){
										$filesystems_with_lt20pctfree++;
										$filesystems_with_lt20pctfree_kpe++ if ($kpe_name ne "");
									}

								}
							}
						}
						#print Dumper \%totalfs;
						my ($totalfs_value) =scalar(keys %totalfs);
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALFS'}{VALUE}=$totalfs_value;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALFS'}{HTML}="<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=$mapping\">$totalfs_value</a>";
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALFS'}{VALUE}=$totalfs_value;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALFS'}{HTML}="<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=ALL&eol_status=$eol_status&show_kpe=1&mapping=$mapping\">$totalfs_value</a>";

						###############################################################################

						#					# Get this from L2 Incident Tile
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{$eol_status}{CAPACITY_PERC}{VALUE}=0;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{$eol_status}{CAPACITY_PERC}{VALUE}=$incid_totals{CAPACITY}/$incid_totals{MONITORING}*100 if($incid_totals{MONITORING}>0);
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{$eol_status}{CAPACITY_PERC}{HTML}=#$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{$eol_status}{CAPACITY_PERC}{VALUE};
						#					= $l2_incidents{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{$eol_status}{CAPACITY_30DAYS};
						#
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{ALL}{CAPACITY_PERC}{VALUE}=0;
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{ALL}{CAPACITY_PERC}{VALUE}=$incid_totals{CAPACITY}/$incid_totals{MONITORING}*100 if($incid_totals{MONITORING}>0);
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{ALL}{CAPACITY_PERC}{HTML}=$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{ALL}{CAPACITY_PERC}{VALUE};
						#					= $l2_incidents{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{EOL_STATUS}{ALL}{CAPACITY_30DAYS};

						#
						#
						#
						###Less Than 20 Percent Free
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT20PCTFREE'}{VALUE} += $filesystems_with_lt20pctfree;
						my $value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT20PCTFREE'}{VALUE};
						if ($value > 0) {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT20PCTFREE'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct20&eol_status=$eol_status&mapping=$mapping\">" . $value . "</a>";
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT20PCTFREE'}{COLOR} = $red;
						} else {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT20PCTFREE'}{HTML} = 0;
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT20PCTFREE'}{COLOR} = $green;
						}


						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT20PCTFREE'}{VALUE} += $filesystems_with_lt20pctfree;
						$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT20PCTFREE'}{VALUE};
						if ($value > 0) {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT20PCTFREE'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct20&eol_status=ALL&mapping=$mapping\">" . $value . "</a>";
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT20PCTFREE'}{COLOR} = $red;
						} else {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT20PCTFREE'}{HTML} = 0;
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT20PCTFREE'}{COLOR} = $green;
						}

						###Less Than 10 Percent Free
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT10PCTFREE'}{VALUE} += $filesystems_with_lt10pctfree;
						$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT10PCTFREE'}{VALUE};
						if ($value > 0) {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT10PCTFREE'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct10&eol_status=$eol_status&show_kpe=1&mapping=$mapping\">" . $value . "</a>";
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT10PCTFREE'}{COLOR} = $red;
						} else {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT10PCTFREE'}{HTML} = 0;
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT10PCTFREE'}{GREEN} = $green;
						}

						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT10PCTFREE'}{VALUE} += $filesystems_with_lt10pctfree;
						$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT10PCTFREE'}{VALUE};
						if ($value > 0) {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT10PCTFREE'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct10&eol_status=ALL&show_kpe=1&mapping=$mapping\">" . $value . "</a>";
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT10PCTFREE'}{COLOR} = $red;
						} else {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT10PCTFREE'}{HTML} = 0;
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT10PCTFREE'}{COLOR} = $green;
						}

						###Less Than 5 Percent Free
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT5PCTFREE'}{VALUE} += $filesystems_with_lt5pctfree;
						$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT5PCTFREE'}{VALUE};
						if ($value > 0) {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT5PCTFREE'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct5&eol_status=$eol_status&show_kpe=1&mapping=$mapping\">" . $value . "</a>";
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT5PCTFREE'}{COLOR} = $red;
						} else {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT5PCTFREE'}{HTML} = 0;
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'LT5PCTFREE'}{GREEN} = $green;
						}

						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT5PCTFREE'}{VALUE} += $filesystems_with_lt5pctfree;
						$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT5PCTFREE'}{VALUE};
						if ($value > 0) {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT5PCTFREE'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=pct5&eol_status=ALL&show_kpe=1&mapping=$mapping\">" . $value . "</a>";
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT5PCTFREE'}{COLOR} = $red;
						} else {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT5PCTFREE'}{HTML} = 0;
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'LT5PCTFREE'}{COLOR} = $green;
						}

						###Total Space
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALMB'}{VALUE} += sprintf "%.2f",$totalmb;
						$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALMB'}{VALUE};
						if ($value > 0) {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALMB'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=$eol_status&show_kpe=1&mapping=$mapping\">" . $value . "</a>";
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALMB'}{COLOR} = $red;
						} else {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALMB'}{HTML} = 0;
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'TOTALMB'}{GREEN} = $green;
						}

						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALMB'}{VALUE} += sprintf "%.2f",$totalmb;
						$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALMB'}{VALUE};
						if ($value > 0) {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALMB'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=ALL&show_kpe=1&mapping=$mapping\">" . $value . "</a>";
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALMB'}{COLOR} = $red;
						} else {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALMB'}{HTML} = 0;
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'TOTALMB'}{COLOR} = $green;
						}

						###Free Space
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'USEDMB'}{VALUE} += sprintf "%.2f",$usedmb;
						$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'USEDMB'}{VALUE};
						if ($value > 0) {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'USEDMB'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=$eol_status&show_kpe=1&mapping=$mapping\">" . $value . "</a>";
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'USEDMB'}{COLOR} = $red;
						} else {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'USEDMB'}{HTML} = 0;
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'USEDMB'}{GREEN} = $green;
						}

						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'USEDMB'}{VALUE} += sprintf "%.2f",$usedmb;
						$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'USEDMB'}{VALUE};
						if ($value > 0) {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'USEDMB'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=ALL&show_kpe=1&mapping=$mapping\">" . $value . "</a>";
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'USEDMB'}{COLOR} = $red;
						} else {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'USEDMB'}{HTML} = 0;
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'USEDMB'}{COLOR} = $green;
						}

						###USED Space
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FREEMB'}{VALUE} += sprintf "%.2f",$freemb;
						$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FREEMB'}{VALUE};
						if ($value > 0) {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FREEMB'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=$eol_status&show_kpe=1&mapping=$mapping\">" . $value . "</a>";
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FREEMB'}{COLOR} = $red;
						} else {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FREEMB'}{HTML} = 0;
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FREEMB'}{GREEN} = $green;
						}

						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FREEMB'}{VALUE} += sprintf "%.2f",$freemb;
						$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FREEMB'}{VALUE};
						if ($value > 0) {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FREEMB'}{HTML}
							= "<a href=\"$drilldown_dir/l3_server_capacity.pl?cust=$customer&center=ALL&owner_flag=$owner&os=$cap&team=$team&status=$status&eol_status=ALL&show_kpe=1&mapping=$mapping\">" . $value . "</a>";
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FREEMB'}{COLOR} = $red;
						} else {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FREEMB'}{HTML} = 0;
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FREEMB'}{COLOR} = $green;
						}

						###Crtitical Perf Alerts
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{VALUE} += $perf_crit_server;
						$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{VALUE};
						if ($value > 0) {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{HTML}
							= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=$eol_status&type=PERF&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{COLOR} = $red;
						} else {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{HTML} = 0;
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'PERF'}{COLOR} = $green;
						}

						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{VALUE} += $perf_crit_server;
						$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{VALUE};
						if ($value > 0) {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{HTML}
							= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=ALL&type=PERF&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{COLOR} = $red;
						} else {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{HTML} = 0;
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'PERF'}{COLOR} = $green;
						}

						##Critical FS Alerts
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{VALUE} += $fs_crit_server;
						$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{VALUE};
						if ($value > 0) {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{HTML}
							= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=$eol_status&type=FS&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{COLOR} = $red;
						} else {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{HTML} = 0;
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'FS'}{COLOR} = $green;
						}

						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{VALUE} += $fs_crit_server;
						# print STDERR "$fqdn $count\n" if ($incid_by_node{$fqdn}{FS});
						$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{VALUE};
						if ($value > 0) {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{HTML}
							= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=ALL&type=FS&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{COLOR} = $red;
						} else {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{HTML} = 0;
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'FS'}{COLOR} = $green;
						}

						###ALL Crtitical Alerts
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{VALUE} += $all_crit_server;
						$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{VALUE};
						if ($value > 0) {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{HTML}
							= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=$eol_status&type=ALL&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{COLOR} = $red;
						} else {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{HTML} = 0;
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'ALL'}{COLOR} = $green;
						}

						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{VALUE} += $all_crit_server;
						# print STDERR "$fqdn $count\n" if ($incid_by_node{$fqdn}{FS});
						$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{VALUE};
						if ($value > 0) {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{HTML}
							= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=ALL&type=ALL&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{COLOR} = $red;
						} else {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{HTML} = 0;
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'ALL'}{COLOR} = $green;
						}

						###Crtitical Monitoring Alerts
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{VALUE} += $mon_crit_server;
						$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{VALUE};
						if ($value > 0) {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{HTML}
							= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=$eol_status&type=MONITORING&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{COLOR} = $red;
						} else {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{HTML} = 0;
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'MONITORING'}{COLOR} = $green;
						}

						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{VALUE} += $mon_crit_server;
						# print STDERR "$fqdn $count\n" if ($incid_by_node{$fqdn}{FS});
						$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{VALUE};
						if ($value > 0) {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{HTML}
							= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=ALL&type=MONITORING&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{COLOR} = $red;
						} else {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{HTML} = 0;
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'MONITORING'}{COLOR} = $green;
						}

						###Crtitical Customer Alerts
						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{VALUE} += $cust_crit_server;
						$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{VALUE};
						if ($value > 0) {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{HTML}
							= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=$eol_status&type=CUSTOMER&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{COLOR} = $red;
						} else {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{HTML} = 0;
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{'CUSTOMER'}{COLOR} = $green;
						}

						$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{VALUE} += $cust_crit_server;
						# print STDERR "$fqdn $count\n" if ($incid_by_node{$fqdn}{FS});
						$value = $l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{VALUE};
						if ($value > 0) {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{HTML}
							= "<a href=\"$drilldown_dir/l3_bionics_incident.pl?customer=$customer&center=ALL&cap=$cap&team=$team&ci_status=$status&eol=ALL&type=CUSTOMER&ci_type=system&server_type=servercluster&month_str=30days&view=summary\">" . $value . "</a>";
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{COLOR} = $red;
						} else {
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{HTML} = 0;
							$l2_server_capacity{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{'CUSTOMER'}{COLOR} = $green;
						}

						$count++;
					}
				}
			}
		}
	}


	if (defined($opts{'p'})) {
	   ##PDXC_Updates
	   foreach my $customer (keys %pdxc_customers) {
	   		my $pdxc_instance = $pdxc_customers{$customer}{INSTANCE};
	   		$l2_server_capacity{CUSTOMER}{$customer}{PDXC_INSTANCE_LIST}{$pdxc_instance} = $pdxc_customers{$customer}{INSTANCE_URL};
	   		print "PDXCINSTANCELIST: $l2_server_capacity{CUSTOMER}{$customer}{PDXC_INSTANCE_LIST}{$pdxc_instance}\n";

	   		update_pdxc_ssz(\%l2_server_capacity,$pdxc_instance,"l2_server_capacity.pl?aggregation=L2.5");
	   }
 	}
}

sub create_chartdata_fs{

	my %chartdata;
	my $customer = shift;
	my %average_data;
	my $file_name = "$account_reg{$customer}{sp_mapping_file}_server_capacity_all";
	#print "Opening $cache_dir/by_customer/$file_name<br>";

	my $sys =  load_cache_byFile("$cache_dir/by_customer/$file_name");
	my %server_capacity = %{$sys};

	foreach my $fqdn (sort keys %{$server_capacity{DATA}}) {
		next if( $fqdn =~/^\s*$/);
		foreach my $sample (sort {$b <=> $a || $b cmp $a  }  keys %{$server_capacity{DATA}{$fqdn}{filesystem}}) {
			foreach my $fs (sort keys %{$server_capacity{DATA}{$fqdn}{filesystem}{$sample}}) {
				next if ($server_capacity{RESOURCE_TYPE}{$fqdn}{filesystem}{$fs}{resource_type} eq "cdrom");
				my ($pctfree,$totalmb,$usedmb,$freemb,$colour);
				$pctfree= sprintf "%.2f", $server_capacity{DATA}{$fqdn}{filesystem}{$sample}{$fs}{'system.filesystem.used.pct'}*100;
				$totalmb= sprintf "%.2f", $server_capacity{DATA}{$fqdn}{filesystem}{$sample}{$fs}{'system.filesystem.total'}*0.000001;
				$usedmb= sprintf "%.2f", $server_capacity{DATA}{$fqdn}{filesystem}{$sample}{$fs}{'system.filesystem.used.bytes'}*0.000001;
				$freemb= sprintf "%.2f", $server_capacity{DATA}{$fqdn}{filesystem}{$sample}{$fs}{'system.filesystem.free'}*0.000001;
				my ($day)=$sample=~m/(\d\d\d\d\-\d\d\-\d\d)\s/;
				my ($hours)=$sample=~m/(\d\d\d\d\-\d\d\-\d\d\s\d\d)/;
				#my ($hourcount)=scalar(keys %{$average_data{$fqdn}{HOURS}});
				#print "FQDN:$fqdn Hours:$hours Count:$hourcount <br>" if ($fqdn=~/pxcmonpln17/ and $hours=~/2019-04-14/);
				my ($months)=$day;

				if(scalar(keys %{$average_data{$fqdn}{DAYS}})<8){
					$average_data{$fqdn}{DAYS}{$day}{$fs}{TOTAL}+=$pctfree;
					$average_data{$fqdn}{DAYS}{$day}{$fs}{COUNT}++;
					#print "Day $day - FS - $fs -Total: $average_data{$fqdn}{DAYS}{$day}{$fs}{TOTAL}\n";
				}

				if(scalar(keys %{$average_data{$fqdn}{HOURS}})<25){
					$average_data{$fqdn}{HOURS}{$hours}{$fs}{TOTAL}+=$pctfree;
					$average_data{$fqdn}{HOURS}{$hours}{$fs}{COUNT}++;
					#print "Hour $hours - FS - $fs - Total: $average_data{$fqdn}{HOURS}{$hours}{$fs}{TOTAL}\n";
				}
				if(scalar(keys %{$average_data{$fqdn}{MONTHS}})<30){
					$average_data{$fqdn}{MONTHS}{$months}{$fs}{TOTAL}+=$pctfree;
					$average_data{$fqdn}{MONTHS}{$months}{$fs}{COUNT}++;
				}
				if(scalar(keys %{$average_data{$fqdn}{THREEMONTHS}})<92){
					$average_data{$fqdn}{THREEMONTHS}{$months}{$fs}{TOTAL}+=$pctfree;
					$average_data{$fqdn}{THREEMONTHS}{$months}{$fs}{COUNT}++;
				}
				if(scalar(keys %{$average_data{$fqdn}{SIXMONTHS}})<126){
					$average_data{$fqdn}{SIXMONTHS}{$months}{$fs}{TOTAL}+=$pctfree;
					$average_data{$fqdn}{SIXMONTHS}{$months}{$fs}{COUNT}++;
				}
				if(scalar(keys %{$average_data{$fqdn}{TWELVEMONTHS}})<368){
					$average_data{$fqdn}{TWELVEMONTHS}{$months}{$fs}{TOTAL}+=$pctfree;
					$average_data{$fqdn}{TWELVEMONTHS}{$months}{$fs}{COUNT}++;
				}

			}
		}
	}


	foreach my $node (sort {$b <=> $a || $b cmp $a  }  keys %average_data){
		#print Dumper $average_data{$node}{MONTHS} if($node =~/ln17/);
		foreach my $hour (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{HOURS}}){
			foreach my $fs (sort keys %{$average_data{$node}{HOURS}{$hour}}){
				$average_data{$node}{HOURS}{$hour}{$fs}{AVERAGE}= sprintf "%.2f",$average_data{$node}{HOURS}{$hour}{$fs}{TOTAL}/$average_data{$node}{HOURS}{$hour}{$fs}{COUNT};
			}
		}
		foreach my $day (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{DAYS}}){
			foreach my $fs (sort keys %{$average_data{$node}{DAYS}{$day}}){
				$average_data{$node}{DAYS}{$day}{$fs}{AVERAGE}= sprintf "%.2f",$average_data{$node}{DAYS}{$day}{$fs}{TOTAL}/$average_data{$node}{DAYS}{$day}{$fs}{COUNT};
			}
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{MONTHS}}){
			foreach my $fs (sort keys %{$average_data{$node}{MONTHS}{$month}}){
				$average_data{$node}{MONTHS}{$month}{$fs}{AVERAGE}= sprintf "%.2f",$average_data{$node}{MONTHS}{$month}{$fs}{TOTAL}/$average_data{$node}{MONTHS}{$month}{$fs}{COUNT};
			}
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{THREEMONTHS}}){
			foreach my $fs (sort keys %{$average_data{$node}{THREEMONTHS}{$month}}){
				$average_data{$node}{THREEMONTHS}{$month}{$fs}{AVERAGE}= sprintf "%.2f",$average_data{$node}{THREEMONTHS}{$month}{$fs}{TOTAL}/$average_data{$node}{THREEMONTHS}{$month}{$fs}{COUNT};
			}
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{SIXMONTHS}}){
			foreach my $fs (sort keys %{$average_data{$node}{SIXMONTHS}{$month}}){
				$average_data{$node}{SIXMONTHS}{$month}{$fs}{AVERAGE}= sprintf "%.2f",$average_data{$node}{SIXMONTHS}{$month}{$fs}{TOTAL}/$average_data{$node}{SIXMONTHS}{$month}{$fs}{COUNT};
			}
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{TWELVEMONTHS}}){
			foreach my $fs (sort keys %{$average_data{$node}{TWELVEMONTHS}{$month}}){
				$average_data{$node}{TWELVEMONTHS}{$month}{$fs}{AVERAGE}= sprintf "%.2f",$average_data{$node}{TWELVEMONTHS}{$month}{$fs}{TOTAL}/$average_data{$node}{TWELVEMONTHS}{$month}{$fs}{COUNT};
			}
		}
	}

	my @colorcodes=("#ffd144","#666666", "#000000","#002b80","#476b6b","#336600","#993300","#614767","#b38600");
	my $colorcount;
	#print Dumper $average_data{$node}{HOURS};##

	foreach my $node (sort keys %average_data){
		foreach my $hour (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{HOURS}}){
			$colorcount=0;
			foreach my $fs (sort keys %{$average_data{$node}{HOURS}{$hour}}){
				my $fsname=$fs;

				$fsname=~s/\\+//g;
				push @{$chartdata{$node}{HOURS}{$fsname}{DATASET}}, $average_data{$node}{HOURS}{$hour}{$fs}{AVERAGE};
				$chartdata{$node}{HOURS}{$fsname}{LABLE}="$fs";
				$chartdata{$node}{HOURS}{$fsname}{COLOUR}=$colorcodes[$colorcount];
				push @{$chartdata{$node}{HOURS}{$fsname}{LABLES}},$hour;
				$colorcount++;
			}
		}
		foreach my $day (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{DAYS}}){
			$colorcount=0;
			foreach my $fs (sort keys %{$average_data{$node}{DAYS}{$day}}){
				my $fsname=$fs;
				$fsname=~s/\\+//g;
				push @{$chartdata{$node}{DAYS}{$fsname}{DATASET}}, $average_data{$node}{DAYS}{$day}{$fs}{AVERAGE};
				$chartdata{$node}{DAYS}{$fsname}{LABLE}="$fs";
				$chartdata{$node}{DAYS}{$fsname}{COLOUR}=$colorcodes[$colorcount];
				push @{$chartdata{$node}{DAYS}{$fsname}{LABLES}},$day;
				$colorcount++;
			}
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{MONTHS}}){
			$colorcount=0;
			foreach my $fs (sort keys %{$average_data{$node}{MONTHS}{$month}}){
				my $fsname=$fs;
				$fsname=~s/\\+//g;
				push @{$chartdata{$node}{MONTHS}{$fsname}{DATASET}}, $average_data{$node}{MONTHS}{$month}{$fs}{AVERAGE};
				$chartdata{$node}{MONTHS}{$fsname}{LABLE}="$fs";
				$chartdata{$node}{MONTHS}{$fsname}{COLOUR}=$colorcodes[$colorcount];
				push @{$chartdata{$node}{MONTHS}{$fsname}{LABLES}},$month;
				$colorcount++;
			}
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{THREEMONTHS}}){
			$colorcount=0;
			foreach my $fs (sort keys %{$average_data{$node}{THREEMONTHS}{$month}}){
				my $fsname=$fs;
				$fsname=~s/\\+//g;
				push @{$chartdata{$node}{THREEMONTHS}{$fsname}{DATASET}}, $average_data{$node}{THREEMONTHS}{$month}{$fs}{AVERAGE};
				$chartdata{$node}{THREEMONTHS}{$fsname}{LABLE}="$fs";
				$chartdata{$node}{THREEMONTHS}{$fsname}{COLOUR}=$colorcodes[$colorcount];
				push @{$chartdata{$node}{THREEMONTHS}{$fsname}{LABLES}},$month;
				$colorcount++;
			}
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{SIXMONTHS}}){
			$colorcount=0;
			foreach my $fs (sort keys %{$average_data{$node}{SIXMONTHS}{$month}}){
				my $fsname=$fs;
				$fsname=~s/\\+//g;
				push @{$chartdata{$node}{SIXMONTHS}{$fsname}{DATASET}}, $average_data{$node}{SIXMONTHS}{$month}{$fs}{AVERAGE};
				$chartdata{$node}{SIXMONTHS}{$fsname}{LABLE}="$fs";
				$chartdata{$node}{SIXMONTHS}{$fsname}{COLOUR}=$colorcodes[$colorcount];
				push @{$chartdata{$node}{SIXMONTHS}{$fsname}{LABLES}},$month;
				$colorcount++;
			}
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{TWELVEMONTHS}}){
			$colorcount=0;
			foreach my $fs (sort keys %{$average_data{$node}{TWELVEMONTHS}{$month}}){
				my $fsname=$fs;
				$fsname=~s/\\+//g;
				push @{$chartdata{$node}{TWELVEMONTHS}{$fsname}{DATASET}}, $average_data{$node}{TWELVEMONTHS}{$month}{$fs}{AVERAGE};
				$chartdata{$node}{TWELVEMONTHS}{$fsname}{LABLE}="$fs";
				$chartdata{$node}{TWELVEMONTHS}{$fsname}{COLOUR}=$colorcodes[$colorcount];
				push @{$chartdata{$node}{TWELVEMONTHS}{$fsname}{LABLES}},$month;
				$colorcount++;
			}
		}
	}

	$server_capacity{CHARTDATA}=\%chartdata;
	save_hash("$file_name", \%server_capacity,"$cache_dir/by_customer");

	my $file_name = "$account_reg{$customer}{sp_mapping_file}_server_capacity_30_DAYS";
	if(-r "$cache_dir/by_customer/$file_name"){
		my $sys =  load_cache_byFile("$cache_dir/by_customer/$file_name");
		my %server_capacity_30 = %{$sys};
		$server_capacity_30{CHARTDATA}=\%chartdata;
		save_hash("$file_name", \%server_capacity_30,"$cache_dir/by_customer");
	}

}


sub create_chartdata_memcpu
{

	my %chartdata;
	my $customer = shift;
	my %average_data;
	my $file_name = "$account_reg{$customer}{sp_mapping_file}_server_memcpu_all";
	#print "Opening $cache_dir/by_customer/$file_name<br>";

	my $sys =  load_cache_byFile("$cache_dir/by_customer/$file_name");
	my %server_memcpu = %{$sys};

	foreach my $fqdn (sort keys %{$server_memcpu{DATA}}) {
		next if( $fqdn =~/^\s*$/);
		##MEMORY
		foreach my $sample (sort {$b <=> $a || $b cmp $a  }  keys %{$server_memcpu{DATA}{$fqdn}{memory}}) {

				foreach my $metric ('system.memory.used.pct','system.memory.total', 'system.memory.swap.total','system.memory.swap.used.pct'){
					my ($metric_value);
					$metric_value= sprintf "%.2f", $server_memcpu{DATA}{$fqdn}{memory}{$sample}{$metric}*100 if($metric=~/\.pct/);
					$metric_value= sprintf "%.2f", $server_memcpu{DATA}{$fqdn}{memory}{$sample}{$metric}*0.000001 if($metric=~/\.total|\.bytes/);

					my ($day)=$sample=~m/(\d\d\d\d\-\d\d\-\d\d)\s/;
					my ($hours)=$sample=~m/(\d\d\d\d\-\d\d\-\d\d\s\d\d)/;
					#my ($hourcount)=scalar(keys %{$average_data{$fqdn}{HOURS}});
					#print "FQDN:$fqdn Hours:$hours Metric:$metric Value:$metric_value\n<br>" if ($fqdn=~/pxcmonpln17/ and $hours=~/2019-04-14/);
					my ($months)=$day;

					my $metric_name=$metric;

					if(scalar(keys %{$average_data{$fqdn}{DAYS}{MEMORY}})<8){
						$average_data{$fqdn}{DAYS}{MEMORY}{$day}{$metric_name}{TOTAL}+=$metric_value;
						$average_data{$fqdn}{DAYS}{MEMORY}{$day}{$metric_name}{COUNT}++;
						#print "Day $day - FS - $fs -Total: $average_data{$fqdn}{DAYS}{$day}{$fs}{TOTAL}\n";
					}

					if(scalar(keys %{$average_data{$fqdn}{HOURS}{MEMORY}})<24){
						$average_data{$fqdn}{HOURS}{MEMORY}{$hours}{$metric_name}{TOTAL}+=$metric_value;
						$average_data{$fqdn}{HOURS}{MEMORY}{$hours}{$metric_name}{COUNT}++;
						#print "Hour $hours - Metric $metric_name - Total: $average_data{$fqdn}{HOURS}{MEMORY}{$hours}{$metric_name}{TOTAL} Count: $average_data{$fqdn}{HOURS}{MEMORY}{$hours}{$metric_name}{COUNT}\n";
					}
					if(scalar(keys %{$average_data{$fqdn}{MONTHS}{MEMORY}})<30){
						$average_data{$fqdn}{MONTHS}{MEMORY}{$months}{$metric_name}{TOTAL}+=$metric_value;
						$average_data{$fqdn}{MONTHS}{MEMORY}{$months}{$metric_name}{COUNT}++;
					}
					if(scalar(keys %{$average_data{$fqdn}{THREEMONTHS}{MEMORY}})<92){
						$average_data{$fqdn}{THREEMONTHS}{MEMORY}{$months}{$metric_name}{TOTAL}+=$metric_value;
						$average_data{$fqdn}{THREEMONTHS}{MEMORY}{$months}{$metric_name}{COUNT}++;
					}
					if(scalar(keys %{$average_data{$fqdn}{SIXMONTHS}{MEMORY}})<126){
						$average_data{$fqdn}{SIXMONTHS}{MEMORY}{$months}{$metric_name}{TOTAL}+=$metric_value;
						$average_data{$fqdn}{SIXMONTHS}{MEMORY}{$months}{$metric_name}{COUNT}++;
					}
					if(scalar(keys %{$average_data{$fqdn}{TWELVEMONTHS}{MEMORY}})<368){
						$average_data{$fqdn}{TWELVEMONTHS}{MEMORY}{$months}{$metric_name}{TOTAL}+=$metric_value;
						$average_data{$fqdn}{TWELVEMONTHS}{MEMORY}{$months}{$metric_name}{COUNT}++;
					}
				}
		}
		#CPU
		foreach my $sample (sort {$b <=> $a || $b cmp $a  }  keys %{$server_memcpu{DATA}{$fqdn}{cpu}}) {
				foreach my $metric ('system.cpu.total.pct','system.cpu.system.pct', 'system.cpu.user.pct','system.cpu.iowait.pct','system.cpu.cores'){
					my ($metric_value);
					my $corecount = $server_memcpu{CORECOUNT}{$fqdn}{cpu};
					$metric_value= sprintf "%.2f", $server_memcpu{DATA}{$fqdn}{cpu}{$sample}{$metric}*100 if($metric=~/\.pct/);
					if($metric=~/\.pct/ and $corecount>0){
						#print "CPU CORE COUNT: $metric_value/$corecount Metric:$metric\n";
						$metric_value= sprintf "%.2f", $metric_value/$corecount ;
					}


					my ($day)=$sample=~m/(\d\d\d\d\-\d\d\-\d\d)\s/;
					my ($hours)=$sample=~m/(\d\d\d\d\-\d\d\-\d\d\s\d\d)/;
					#my ($hourcount)=scalar(keys %{$average_data{$fqdn}{HOURS}});
					#print "FQDN:$fqdn Hours:$day Metric:$metric Value:$metric_value\n<br>" if ($fqdn=~/pxcmonpln17/ and $hours=~/2019-04-14/);
					my ($months)=$day;

					my $metric_name=$metric;

					if(scalar(keys %{$average_data{$fqdn}{DAYS}{CPU}})<9){
						$average_data{$fqdn}{DAYS}{CPU}{$day}{$metric_name}{TOTAL}+=$metric_value;
						$average_data{$fqdn}{DAYS}{CPU}{$day}{$metric_name}{COUNT}++;
						#print "Day $day - FS - $fs -Total: $average_data{$fqdn}{DAYS}{$day}{$fs}{TOTAL}\n";
					}

					if(scalar(keys %{$average_data{$fqdn}{HOURS}{CPU}})<25){
						$average_data{$fqdn}{HOURS}{CPU}{$hours}{$metric_name}{TOTAL}+=$metric_value;
						$average_data{$fqdn}{HOURS}{CPU}{$hours}{$metric_name}{COUNT}++;
						#print "Hour $hours - FS - $fs - Total: $average_data{$fqdn}{HOURS}{$hours}{$fs}{TOTAL}\n";
					}
					if(scalar(keys %{$average_data{$fqdn}{MONTHS}{CPU}})<31){
						$average_data{$fqdn}{MONTHS}{CPU}{$months}{$metric_name}{TOTAL}+=$metric_value;
						$average_data{$fqdn}{MONTHS}{CPU}{$months}{$metric_name}{COUNT}++;
					}
					if(scalar(keys %{$average_data{$fqdn}{THREEMONTHS}{CPU}})<93){
						$average_data{$fqdn}{THREEMONTHS}{CPU}{$months}{$metric_name}{TOTAL}+=$metric_value;
						$average_data{$fqdn}{THREEMONTHS}{CPU}{$months}{$metric_name}{COUNT}++;
					}
					if(scalar(keys %{$average_data{$fqdn}{SIXMONTHS}{CPU}})<127){
						$average_data{$fqdn}{SIXMONTHS}{CPU}{$months}{$metric_name}{TOTAL}+=$metric_value;
						$average_data{$fqdn}{SIXMONTHS}{CPU}{$months}{$metric_name}{COUNT}++;
					}
					if(scalar(keys %{$average_data{$fqdn}{TWELVEMONTHS}{CPU}})<369){
						$average_data{$fqdn}{TWELVEMONTHS}{CPU}{$months}{$metric_name}{TOTAL}+=$metric_value;
						$average_data{$fqdn}{TWELVEMONTHS}{CPU}{$months}{$metric_name}{COUNT}++;
					}
				}

		}
	}


	foreach my $node (sort {$b <=> $a || $b cmp $a  }  keys %average_data){
		#print Dumper $average_data{$node}{DAYS} if($node =~/ln17/);
		foreach my $hour (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{HOURS}{MEMORY}}){
			foreach my $metric (sort keys %{$average_data{$node}{HOURS}{MEMORY}{$hour}}){
				$average_data{$node}{HOURS}{MEMORY}{$hour}{$metric}{AVERAGE}=sprintf "%.2f", $average_data{$node}{HOURS}{MEMORY}{$hour}{$metric}{TOTAL}/$average_data{$node}{HOURS}{MEMORY}{$hour}{$metric}{COUNT};
			}
		}
		foreach my $hour (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{HOURS}{CPU}}){
			foreach my $metric (sort keys %{$average_data{$node}{HOURS}{CPU}{$hour}}){
				$average_data{$node}{HOURS}{CPU}{$hour}{$metric}{AVERAGE}= sprintf "%.2f",$average_data{$node}{HOURS}{CPU}{$hour}{$metric}{TOTAL}/$average_data{$node}{HOURS}{CPU}{$hour}{$metric}{COUNT};
			}
		}
		foreach my $day (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{DAYS}{MEMORY}}){
			foreach my $metric (sort keys %{$average_data{$node}{DAYS}{MEMORY}{$day}}){
				$average_data{$node}{DAYS}{MEMORY}{$day}{$metric}{AVERAGE}= sprintf "%.2f",$average_data{$node}{DAYS}{MEMORY}{$day}{$metric}{TOTAL}/$average_data{$node}{DAYS}{MEMORY}{$day}{$metric}{COUNT};
			}
		}
		foreach my $day (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{DAYS}{CPU}}){
			foreach my $metric (sort keys %{$average_data{$node}{DAYS}{CPU}{$day}}){
				$average_data{$node}{DAYS}{CPU}{$day}{$metric}{AVERAGE}=sprintf "%.2f", $average_data{$node}{DAYS}{CPU}{$day}{$metric}{TOTAL}/$average_data{$node}{DAYS}{CPU}{$day}{$metric}{COUNT};
			}
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{MONTHS}{MEMORY}}){
			foreach my $metric (sort keys %{$average_data{$node}{MONTHS}{MEMORY}{$month}}){
				$average_data{$node}{MONTHS}{MEMORY}{$month}{$metric}{AVERAGE}= sprintf "%.2f",$average_data{$node}{MONTHS}{MEMORY}{$month}{$metric}{TOTAL}/$average_data{$node}{MONTHS}{MEMORY}{$month}{$metric}{COUNT};
			}
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{MONTHS}{CPU}}){
			foreach my $metric (sort keys %{$average_data{$node}{MONTHS}{CPU}{$month}}){
				$average_data{$node}{MONTHS}{CPU}{$month}{$metric}{AVERAGE}= sprintf "%.2f",$average_data{$node}{MONTHS}{CPU}{$month}{$metric}{TOTAL}/$average_data{$node}{MONTHS}{CPU}{$month}{$metric}{COUNT};
			}
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{THREEMONTHS}{MEMORY}}){
			foreach my $metric (sort keys %{$average_data{$node}{THREEMONTHS}{MEMORY}{$month}}){
				$average_data{$node}{THREEMONTHS}{MEMORY}{$month}{$metric}{AVERAGE}= sprintf "%.2f",$average_data{$node}{THREEMONTHS}{MEMORY}{$month}{$metric}{TOTAL}/$average_data{$node}{THREEMONTHS}{MEMORY}{$month}{$metric}{COUNT};
			}
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{THREEMONTHS}{CPU}}){
			foreach my $metric (sort keys %{$average_data{$node}{THREEMONTHS}{CPU}{$month}}){
				$average_data{$node}{THREEMONTHS}{CPU}{$month}{$metric}{AVERAGE}= sprintf "%.2f",$average_data{$node}{THREEMONTHS}{CPU}{$month}{$metric}{TOTAL}/$average_data{$node}{THREEMONTHS}{CPU}{$month}{$metric}{COUNT};
			}
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{SIXMONTHS}{MEMORY}}){
			foreach my $metric (sort keys %{$average_data{$node}{SIXMONTHS}{MEMORY}{$month}}){
				$average_data{$node}{SIXMONTHS}{MEMORY}{$month}{$metric}{AVERAGE}= sprintf "%.2f",$average_data{$node}{SIXMONTHS}{MEMORY}{$month}{$metric}{TOTAL}/$average_data{$node}{SIXMONTHS}{MEMORY}{$month}{$metric}{COUNT};
			}
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{SIXMONTHS}{CPU}}){
			foreach my $metric (sort keys %{$average_data{$node}{SIXMONTHS}{CPU}{$month}}){
				$average_data{$node}{SIXMONTHS}{CPU}{$month}{$metric}{AVERAGE}= sprintf "%.2f",$average_data{$node}{SIXMONTHS}{CPU}{$month}{$metric}{TOTAL}/$average_data{$node}{SIXMONTHS}{CPU}{$month}{$metric}{COUNT};
			}
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{TWELVEMONTHS}{MEMORY}}){
			foreach my $metric (sort keys %{$average_data{$node}{TWELVEMONTHS}{MEMORY}{$month}}){
				$average_data{$node}{TWELVEMONTHS}{MEMORY}{$month}{$metric}{AVERAGE}= sprintf "%.2f",$average_data{$node}{TWELVEMONTHS}{MEMORY}{$month}{$metric}{TOTAL}/$average_data{$node}{TWELVEMONTHS}{MEMORY}{$month}{$metric}{COUNT};
			}
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{TWELVEMONTHS}{CPU}}){
			foreach my $metric (sort keys %{$average_data{$node}{TWELVEMONTHS}{CPU}{$month}}){
				$average_data{$node}{TWELVEMONTHS}{CPU}{$month}{$metric}{AVERAGE}= sprintf "%.2f",$average_data{$node}{TWELVEMONTHS}{CPU}{$month}{$metric}{TOTAL}/$average_data{$node}{TWELVEMONTHS}{CPU}{$month}{$metric}{COUNT};
			}
		}
	}

	my @colorcodes=("#ffd144","#666666", "#000000","#002b80","#476b6b","#336600","#993300","#614767","#b38600");
	my $colorcount;


	foreach my $node (sort keys %average_data){
		#print Dumper $average_data{$node}{HOURS}if($node =~/ln17/);

		foreach my $hour (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{HOURS}{MEMORY}}){
			$colorcount=0;
			foreach my $metric (sort keys %{$average_data{$node}{HOURS}{MEMORY}{$hour}}){
				my $metric_lable=$metric;
				$metric_lable =~s/system\.cpu\.//g;
				$metric_lable =~s/\./ /g;
				$metric_lable =~s/pct/\%/g;
				$metric_lable=~ s/([\w\']+)/\u\L$1/g;
				$metric_lable=~s/System Memory//;
				push @{$chartdata{$node}{HOURS}{MEMORY}{$metric}{DATASET}}, $average_data{$node}{HOURS}{MEMORY}{$hour}{$metric}{AVERAGE};
				$chartdata{$node}{HOURS}{MEMORY}{$metric}{LABLE}="$metric_lable";
				$chartdata{$node}{HOURS}{MEMORY}{$metric}{COLOUR}=$colorcodes[$colorcount];
				push @{$chartdata{$node}{HOURS}{MEMORY}{$metric}{LABLES}},$hour;
				$colorcount++;
				$colorcount=0 if ($colorcount>8);
			}
		}
		$colorcount=0;
		foreach my $hour (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{HOURS}{CPU}}){
			$colorcount=0;
			foreach my $metric (sort keys %{$average_data{$node}{HOURS}{CPU}{$hour}}){
				my $metric_lable=$metric;
				$metric_lable =~s/system\.cpu\.//g;
				$metric_lable =~s/\./ /g;
				$metric_lable =~s/pct/\%/g;
				$metric_lable=~ s/([\w\']+)/\u\L$1/g;
				push @{$chartdata{$node}{HOURS}{CPU}{$metric}{DATASET}}, $average_data{$node}{HOURS}{CPU}{$hour}{$metric}{AVERAGE};
				$chartdata{$node}{HOURS}{CPU}{$metric}{LABLE}="$metric_lable";
				$chartdata{$node}{HOURS}{CPU}{$metric}{COLOUR}=$colorcodes[$colorcount];
				push @{$chartdata{$node}{HOURS}{CPU}{$metric}{LABLES}},$hour;
				$colorcount++;
				$colorcount=0 if ($colorcount>8);
			}
		}

		foreach my $day (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{DAYS}{MEMORY}}){
			$colorcount=0;
			foreach my $metric (sort keys %{$average_data{$node}{DAYS}{MEMORY}{$day}}){
				my $metric_lable=$metric;
				$metric_lable =~s/system\.cpu\.//g;
				$metric_lable =~s/\./ /g;
				$metric_lable =~s/pct/\%/g;
				$metric_lable=~ s/([\w\']+)/\u\L$1/g;
				$metric_lable=~s/System Memory//;
				push @{$chartdata{$node}{DAYS}{MEMORY}{$metric}{DATASET}}, $average_data{$node}{DAYS}{MEMORY}{$day}{$metric}{AVERAGE};
				$chartdata{$node}{DAYS}{MEMORY}{$metric}{LABLE}="$metric_lable";
				$chartdata{$node}{DAYS}{MEMORY}{$metric}{COLOUR}=$colorcodes[$colorcount];
				push @{$chartdata{$node}{DAYS}{MEMORY}{$metric}{LABLES}},$day;
				$colorcount++;
				$colorcount=0 if ($colorcount>8);
			}
		}

		foreach my $day (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{DAYS}{CPU}}){
			$colorcount=0;
			foreach my $metric (sort keys %{$average_data{$node}{DAYS}{CPU}{$day}}){
				my $metric_lable=$metric;
				$metric_lable =~s/system\.cpu\.//g;
				$metric_lable =~s/\./ /g;
				$metric_lable =~s/pct/\%/g;
				$metric_lable=~ s/([\w\']+)/\u\L$1/g;
				push @{$chartdata{$node}{DAYS}{CPU}{$metric}{DATASET}}, $average_data{$node}{DAYS}{CPU}{$day}{$metric}{AVERAGE};
				$chartdata{$node}{DAYS}{CPU}{$metric}{LABLE}="$metric_lable";
				$chartdata{$node}{DAYS}{CPU}{$metric}{COLOUR}=$colorcodes[$colorcount];
				push @{$chartdata{$node}{DAYS}{CPU}{$metric}{LABLES}},$day;
				$colorcount++;
				$colorcount=0 if ($colorcount>8);
			}
		}

		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{MONTHS}{MEMORY}}){
			$colorcount=0;
			foreach my $metric (sort keys %{$average_data{$node}{MONTHS}{MEMORY}{$month}}){
				my $metric_lable=$metric;
				$metric_lable =~s/system\.cpu\.//g;
				$metric_lable =~s/\./ /g;
				$metric_lable =~s/pct/\%/g;
				$metric_lable=~ s/([\w\']+)/\u\L$1/g;
				$metric_lable=~s/System Memory//;
				push @{$chartdata{$node}{MONTHS}{MEMORY}{$metric}{DATASET}}, $average_data{$node}{MONTHS}{MEMORY}{$month}{$metric}{AVERAGE};
				$chartdata{$node}{MONTHS}{MEMORY}{$metric}{LABLE}="$metric_lable";
				$chartdata{$node}{MONTHS}{MEMORY}{$metric}{COLOUR}=$colorcodes[$colorcount];
				push @{$chartdata{$node}{MONTHS}{MEMORY}{$metric}{LABLES}},$month;
				$colorcount++;
				$colorcount=0 if ($colorcount>8);
			}
		}

		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{MONTHS}{CPU}}){
			$colorcount=0;
			foreach my $metric (sort keys %{$average_data{$node}{MONTHS}{CPU}{$month}}){
				my $metric_lable=$metric;
				$metric_lable =~s/system\.cpu\.//g;
				$metric_lable =~s/\./ /g;
				$metric_lable =~s/pct/\%/g;
				$metric_lable=~ s/([\w\']+)/\u\L$1/g;
				push @{$chartdata{$node}{MONTHS}{CPU}{$metric}{DATASET}}, $average_data{$node}{MONTHS}{CPU}{$month}{$metric}{AVERAGE};
				$chartdata{$node}{MONTHS}{CPU}{$metric}{LABLE}="$metric_lable";
				$chartdata{$node}{MONTHS}{CPU}{$metric}{COLOUR}=$colorcodes[$colorcount];
				push @{$chartdata{$node}{MONTHS}{CPU}{$metric}{LABLES}},$month;
				$colorcount++;
				$colorcount=0 if ($colorcount>8);
			}
		}

		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{THREEMONTHS}{MEMORY}}){
			$colorcount=0;
			foreach my $metric (sort keys %{$average_data{$node}{THREEMONTHS}{MEMORY}{$month}}){
				my $metric_lable=$metric;
				$metric_lable =~s/system\.cpu\.//g;
				$metric_lable =~s/\./ /g;
				$metric_lable =~s/pct/\%/g;
				$metric_lable=~ s/([\w\']+)/\u\L$1/g;
				$metric_lable=~s/System Memory//;
				push @{$chartdata{$node}{THREEMONTHS}{MEMORY}{$metric}{DATASET}}, $average_data{$node}{THREEMONTHS}{MEMORY}{$month}{$metric}{AVERAGE};
				$chartdata{$node}{THREEMONTHS}{MEMORY}{$metric}{LABLE}="$metric_lable";
				$chartdata{$node}{THREEMONTHS}{MEMORY}{$metric}{COLOUR}=$colorcodes[$colorcount];
				push @{$chartdata{$node}{THREEMONTHS}{MEMORY}{$metric}{LABLES}},$month;
				$colorcount++;
				$colorcount=0 if ($colorcount>8);
			}
		}

		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{THREEMONTHS}{CPU}}){
			$colorcount=0;
			foreach my $metric (sort keys %{$average_data{$node}{THREEMONTHS}{CPU}{$month}}){
				my $metric_lable=$metric;
				$metric_lable =~s/system\.cpu\.//g;
				$metric_lable =~s/\./ /g;
				$metric_lable =~s/pct/\%/g;
				$metric_lable=~ s/([\w\']+)/\u\L$1/g;
				push @{$chartdata{$node}{THREEMONTHS}{CPU}{$metric}{DATASET}}, $average_data{$node}{THREEMONTHS}{CPU}{$month}{$metric}{AVERAGE};
				$chartdata{$node}{THREEMONTHS}{CPU}{$metric}{LABLE}="$metric_lable";
				$chartdata{$node}{THREEMONTHS}{CPU}{$metric}{COLOUR}=$colorcodes[$colorcount];
				push @{$chartdata{$node}{THREEMONTHS}{CPU}{$metric}{LABLES}},$month;
				$colorcount++;
				$colorcount=0 if ($colorcount>8);
			}
		}

		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{SIXMONTHS}{MEMORY}}){
			$colorcount=0;
			foreach my $metric (sort keys %{$average_data{$node}{SIXMONTHS}{MEMORY}{$month}}){
				my $metric_lable=$metric;
				$metric_lable =~s/system\.cpu\.//g;
				$metric_lable =~s/\./ /g;
				$metric_lable =~s/pct/\%/g;
				$metric_lable=~ s/([\w\']+)/\u\L$1/g;
				$metric_lable=~s/System Memory//;
				push @{$chartdata{$node}{SIXMONTHS}{MEMORY}{$metric}{DATASET}}, $average_data{$node}{SIXMONTHS}{MEMORY}{$month}{$metric}{AVERAGE};
				$chartdata{$node}{SIXMONTHS}{MEMORY}{$metric}{LABLE}="$metric_lable";
				$chartdata{$node}{SIXMONTHS}{MEMORY}{$metric}{COLOUR}=$colorcodes[$colorcount];
				push @{$chartdata{$node}{SIXMONTHS}{MEMORY}{$metric}{LABLES}},$month;
				$colorcount++;
				$colorcount=0 if ($colorcount>8);
			}
		}

		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{SIXMONTHS}{CPU}}){
			$colorcount=0;
			foreach my $metric (sort keys %{$average_data{$node}{SIXMONTHS}{CPU}{$month}}){
				my $metric_lable=$metric;
				$metric_lable =~s/system\.cpu\.//g;
				$metric_lable =~s/\./ /g;
				$metric_lable =~s/pct/\%/g;
				$metric_lable=~ s/([\w\']+)/\u\L$1/g;
				$metric_lable=~s/System Memory//;
				push @{$chartdata{$node}{SIXMONTHS}{CPU}{$metric}{DATASET}}, $average_data{$node}{SIXMONTHS}{CPU}{$month}{$metric}{AVERAGE};
				$chartdata{$node}{SIXMONTHS}{CPU}{$metric}{LABLE}="$metric_lable";
				$chartdata{$node}{SIXMONTHS}{CPU}{$metric}{COLOUR}=$colorcodes[$colorcount];
				push @{$chartdata{$node}{SIXMONTHS}{CPU}{$metric}{LABLES}},$month;
				$colorcount++;
				$colorcount=0 if ($colorcount>8);
			}
		}
		$colorcount=0;
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{TWELVEMONTHS}{MEMORY}}){

			foreach my $metric (sort keys %{$average_data{$node}{TWELVEMONTHS}{MEMORY}{$month}}){
				my $metric_lable=$metric;
				$metric_lable =~s/system\.cpu\.//g;
				$metric_lable =~s/\./ /g;
				$metric_lable =~s/pct/\%/g;
				$metric_lable=~ s/([\w\']+)/\u\L$1/g;
				$metric_lable=~s/System Memory//;
				push @{$chartdata{$node}{TWELVEMONTHS}{MEMORY}{$metric}{DATASET}}, $average_data{$node}{TWELVEMONTHS}{MEMORY}{$month}{$metric}{AVERAGE};
				$chartdata{$node}{TWELVEMONTHS}{MEMORY}{$metric}{LABLE}="$metric_lable";
				$chartdata{$node}{TWELVEMONTHS}{MEMORY}{$metric}{COLOUR}=$colorcodes[$colorcount];
				push @{$chartdata{$node}{TWELVEMONTHS}{MEMORY}{$metric}{LABLES}},$month;
				$colorcount++;
				$colorcount=0 if ($colorcount>8);
			}
		}
		$colorcount=0;
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{$node}{TWELVEMONTHS}{CPU}}){

			foreach my $metric (sort keys %{$average_data{$node}{TWELVEMONTHS}{CPU}{$month}}){
				my $metric_lable=$metric;
				$metric_lable =~s/system\.cpu\.//g;
				$metric_lable =~s/\./ /g;
				$metric_lable =~s/pct/\%/g;
				$metric_lable=~ s/([\w\']+)/\u\L$1/g;
				push @{$chartdata{$node}{TWELVEMONTHS}{CPU}{$metric}{DATASET}}, $average_data{$node}{TWELVEMONTHS}{CPU}{$month}{$metric}{AVERAGE};
				$chartdata{$node}{TWELVEMONTHS}{CPU}{$metric}{LABLE}="$metric_lable";
				$chartdata{$node}{TWELVEMONTHS}{CPU}{$metric}{COLOUR}=$colorcodes[$colorcount];
				push @{$chartdata{$node}{TWELVEMONTHS}{CPU}{$metric}{LABLES}},$month;
				$colorcount++;
				$colorcount=0 if ($colorcount>8);
			}
		}
	}


	#print Dumper \%chartdata;

	$server_memcpu{CHARTDATA}=\%chartdata;
	save_hash("$file_name", \%server_memcpu,"$cache_dir/by_customer");

	my $file_name = "$account_reg{$customer}{sp_mapping_file}_server_memcpu_30_DAYS";
	if(-r "$cache_dir/by_customer/$file_name"){
		my $sys =  load_cache_byFile("$cache_dir/by_customer/$file_name");
		my %server_memcpu_30 = %{$sys};
		$server_memcpu_30{CHARTDATA}=\%chartdata;
		save_hash("$file_name", \%server_memcpu_30,"$cache_dir/by_customer");
	}

}


sub get_incid_by_node
{
	my ($incid_by_node, $esl_system_ci, $incid_details, $customer) = @_;

	foreach my $incident (keys %{$incid_details}) {

		my $fqdn = $incid_details->{$incident}{FQDN};
		if (not defined($esl_system_ci->{$customer}{ALL}{$fqdn}) and defined($system_monitoring_names{$customer}{$fqdn}{ALIAS})) {
			$fqdn = $system_monitoring_names{$customer}{$fqdn}{ALIAS};
		}
		if(!defined($incid_by_node{$fqdn})) {
			$incid_by_node->{$fqdn}{PERF} = 0;
			$incid_by_node->{$fqdn}{FS} = 0;
		}
		if($incid_details->{$incident}{PERF} =~ /TRUE/i && $incid_details->{$incident}{ESEV} =~ /Critical/i) {
			$incid_by_node->{$fqdn}{PERF}++;
			$incid_totals{PERF}++;
		} elsif ($incid_details->{$incident}{FS} =~ /TRUE/i && $incid_details->{$incident}{ESEV} =~ /Critical/i) {
			$incid_by_node->{$fqdn}{FS}++;
			$incid_totals{FS}++;
		}
		if($incid_details->{$incident}{ESEV} =~ /Critical/i){
			$incid_by_node->{$fqdn}{ALL}++;
			$incid_totals{ALL}++;
		}
		if($incid_details->{$incident}{CAT_NAME} =~ /Customer/i){
			$incid_by_node->{$fqdn}{CUSTOMER}++;
			$incid_totals{CUSTOMER}++;
		}
		if($incid_details->{$incident}{CAT_NAME} =~ /Monitoring/i){
			$incid_by_node->{$fqdn}{MONITORING}++;
			$incid_totals{MONITORING}++;
		}
		if($incid_details->{$incident}{CAPACITY} =~ /TRUE/i){
			$incid_by_node->{$fqdn}{CAPACITY}++;
			$incid_totals{CAPACITY}++;
		}

	}
	#	}
	# debug
	if (0) {
		my $perf_count = 0;
		my $fs_count = 0;
		foreach my $fqdn (keys %{$incid_by_node}) {
			next if( $fqdn =~/^\s*$/);
			$perf_count+= ($incid_by_node{$fqdn}{PERF} > 0);
			$fs_count+= ($incid_by_node{$fqdn}{FS} > 0);
		}
		print STDERR "PERF NODES: $perf_count\n";
		print STDERR "FS NODES: $fs_count\n";
		print Dumper \%incid_totals;
	}

}
