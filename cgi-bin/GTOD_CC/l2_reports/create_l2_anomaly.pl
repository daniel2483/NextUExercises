#!/usr/bin/perl
#
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
my $start_time = time();
my $current_tick = time();
my %opts;
getopts('sc:', \%opts) || usage("invalid arguments");

my @list = ( 'l2_system_baseline', 'account_reg','system_monitoring_names','anomaly_aggregates');
push @list, 'l2_anomaly' if (defined($opts{c}));
push @list, 'anomaly_details' if (defined($opts{c}));
my %cache = load_cache(\@list);

my %account_reg = %{$cache{account_reg}};
my %anomaly_aggregates = %{$cache{anomaly_aggregates}};
#my %anomaly = %{$cache{anomaly}};

my %l2_baseline = %{$cache{l2_system_baseline}};
#my %l2_incidents = %{$cache{l2_incidents}};
my %system_monitoring_names = %{$cache{system_monitoring_names}};

my %l2_anomaly;
my %anomaly_details;
my %anomaly;
%l2_anomaly =  %{$cache{l2_anomaly}} if (defined($opts{c}));
%anomaly_details =  %{$cache{anomaly_details}} if (defined($opts{c}));

my %system_monitoring_names;
my %incid_by_node = undef;
my %incid_by_node = undef;
my %counted_fqdn;
my %counted_fqdn_fs;
my %counted_fqdn_perf;
my %counted_fqdn_all;
my %counted_fqdn_mon;
my %counted_fqdn_cust;
my %incid_totals;
my @months = qw(JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC);
my %chartdata;

if (!defined($opts{s})) {
	# Declaration of global Variable
	my (@cust_list) = split(/\,/,$opts{"c"});
	foreach my $n (@cust_list){
		$n=~s/^\s*//;
		$n=~s/\s*$//;
		undef ($l2_anomaly{CUSTOMER}{$n});
	}
	my %cust_list_hash = map { $_ => 1 } @cust_list;
	my $count=1;
	my $esl_system_ci = undef;
	my $incid_details_ref;
	my $class;

	foreach my $customer (sort keys %account_reg) {
		next if (not defined($anomaly_aggregates{DATA}{$customer}));
		undef($incid_details_ref);
		undef(%incid_by_node);
		#print "Customer $customer\n";
		my $mapping = $account_reg{$customer}{sp_mapping_file};
		my $file_name = "$account_reg{$customer}{sp_mapping_file}"."_esl_system_ci_by_fqdn";
		my $sys =  load_cache_byFile("$cache_dir/by_customer/$file_name");
		my %esl_system_ci = %{$sys};
		
		print STDERR "Processing: $customer - $count iterations\n";
		undef(%incid_by_node);		
		
#		if (not -r "$cache_dir/by_customer/$file_name" or $customer =~/intermountain healthcare|test client|acme/i){
#			print "No ESL CI Data for $customer, checking for anomaly data...\n";			
			create_chartdata($customer);
			nonesl_account_anomaly($customer);
			create_anomaly_detail_tables($customer);
#			next;
#		}							
	}
	


	$l2_anomaly{NODATA}=1 if(! %l2_anomaly);
	$anomaly_details{NODATA}=1 if(!%anomaly_details);
	save_hash("cache.l2_anomaly", \%l2_anomaly,"$cache_dir/l2_cache");
	#save_hash("cache.anomaly_details", \%anomaly_details,"$cache_dir/l2_cache");

} else {

	#---------------------------------------------------------------------------------------------------------
	#PERFORMANCE ENHANCEMENTS
	#
	##############
	#
	#
	# anomaly
	#
	##############
	my %menu_filters;
	my %tmp;

	my $ref = load_cache_byFile("$cache_dir/l2_cache/cache.l2_anomaly",1);
	my %l2_anomaly = %{$ref};

	foreach my $customer (keys %{$l2_anomaly{CUSTOMER}}) {
		#print "Customer:$customer\n";
		foreach my $center (keys %{$l2_anomaly{CUSTOMER}{$customer}{CENTER}}) {
			my $c_str = $center;
			$c_str =~ s/\:/\_/g;
			foreach my $cap (keys %{$l2_anomaly{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}}) {
				foreach my $team (keys %{$l2_anomaly{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}}) {
					my $t_str = $team;
					$t_str =~ s/\W//g;
					$t_str = substr($t_str,0,25);

					my $file = "l2_anomaly-$c_str-$t_str";
					#print "File:$file\n";
					$tmp{FILE}{$file}{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team} = $l2_anomaly{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team};

					$tmp{FILE}{$file}{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'cluster node'}{CAPABILITY}{$cap}{TEAM}{$team} = $l2_anomaly{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'cluster node'}{CAPABILITY}{$cap}{TEAM}{$team};
					$tmp{FILE}{$file}{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$cap}{TEAM}{$team} = $l2_anomaly{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$cap}{TEAM}{$team};

				}
			}
		}
	}

	foreach my $file (keys %{$tmp{FILE}}) {
		my %t2;
		foreach my $customer (keys %{$tmp{FILE}{$file}{CUSTOMER}}) {
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

	save_hash("menu_filters-l2_anomaly", \%menu_filters, "$cache_dir/l2_cache/by_filters");

	##############
	#
	#
	# anomaly_details
	#
	##############
	my %menu_filters;
	my %tmp;

	my $ref = load_cache_byFile("$cache_dir/l2_cache/cache.anomaly_details",1);
	my %anomaly_details = %{$ref};

	foreach my $customer (keys %{$anomaly_details{CUSTOMER}}) {
		foreach my $center (keys %{$anomaly_details{CUSTOMER}{$customer}{CENTER}}) {
			my $c_str = $center;
			$c_str =~ s/\:/\_/g;
			foreach my $cap (keys %{$anomaly_details{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}}) {
				foreach my $team (keys %{$anomaly_details{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}}) {
					my $t_str = $team;
					$t_str =~ s/\W//g;
					$t_str = substr($t_str,0,25);

					my $file = "anomaly_details-$c_str-$t_str";
					#print "File:$file\n";
					$tmp{FILE}{$file}{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team} = $anomaly_details{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{TEAM}{$team};

					$tmp{FILE}{$file}{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'cluster node'}{CAPABILITY}{$cap}{TEAM}{$team} = $anomaly_details{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'cluster node'}{CAPABILITY}{$cap}{TEAM}{$team};
					$tmp{FILE}{$file}{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$cap}{TEAM}{$team} = $anomaly_details{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$cap}{TEAM}{$team};

				}
			}
		}
	}

	foreach my $file (keys %{$tmp{FILE}}) {
		my %t2;
		foreach my $customer (keys %{$tmp{FILE}{$file}{CUSTOMER}}) {
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

	save_hash("menu_filters-anomaly_details", \%menu_filters, "$cache_dir/l2_cache/by_filters");
	
} 

my $end_time = time();
printf "Completed Processing after %0.1f Mins\n", ($end_time - $start_time) / 60;

# ---------------------------------------------------------------------------------------------------------------
sub create_chartdata{
		
	my $customer = shift;
	my %average_data=();
	my %counter;
	%chartdata=();
	my $file_name = "$account_reg{$customer}{sp_mapping_file}_anomaly_aggregates_all";
	#print "Opening $cache_dir/by_customer/$file_name<br>";
	my $sys =  load_cache_byFile("$cache_dir/by_customer/$file_name");
	my %anomaly = %{$sys};
	my $file_name_details = "$account_reg{$customer}{sp_mapping_file}"."_anomaly_details_all";	
	my $sys_details =  load_cache_byFile("$cache_dir/by_customer/$file_name_details");	
	my %anomaly_details = %{$sys_details};
	
	my @colorcodes=("#ffd144","#666666", "#ff8d6d","#2ad2c9","#476b6b","#b38600","#993300","#614767","#b38600");
	my $colorcount;
	
	foreach my $fqdn (sort keys %{$anomaly_details{DATA}}) {		
		
		foreach my $met (sort keys %{$anomaly_details{DATA}{$fqdn}}) {		
			foreach my $hour (sort {$b <=> $a || $b cmp $a  }  keys %{$anomaly_details{DATA}{$fqdn}{$met}}) {
				my ($hour_of_day, $day_of_week);				
				my ($hournum)=$hour=~m/^\d\d\d\d\-\d\d\-\d\d\s(\d\d)\:/;				
				my ($hour_date)=$hour=~m/^(\d\d\d\d\-\d\d\-\d\d\s\d\d)\:/;	
				($hour_of_day)=$hournum.":00";				
				my $tick = date_to_tick($hour);				
				($day_of_week)=POSIX::strftime("%a", localtime $tick); 								
				my ($year,$mon)=$hour=~m/^(\d\d\d\d)\-(\d\d)\-\d\d\s\d\d\:/;
				my $month = $months[$mon-1]."-".$year;					
				my ($day)=$hour=~m/^(\d\d\d\d\-\d\d\-\d\d)\s\d\d\:/;
				#print "Hour:$hour\n"if ($fqdn eq "493913179520_i-029911f4402ae64ac");
				my ($last_30,$last_24,$last_7)=0,0,0;
				my $date_dif = sprintf "%0.2f", ($current_tick - $tick) / (24 * 60 * 60);			
	      if ($date_dif <= 30){      	
	      	$last_30 =1;      	
	      }
	      my $date_dif = sprintf "%0.2f", ($current_tick - $tick) / (60 * 60);			
	      if ($date_dif <= 24){      	
	      	$last_24 =1;   
	      	#print "LAST 24 hours found diff: $date_dif FQDN:$fqdn\n"   	;
	      }
	      my $date_dif = sprintf "%0.2f", ($current_tick - $tick) / (24 * 60 * 60);			
	      if ($date_dif <= 7){      	
	      	$last_7 =1;      	
	      }
	      
				my $value;
				#$value = $anomaly{DATA}{$fqdn}{$met}{$hour}{AVG_VALUE}*0.000001 if ($met=~/^system\.memory/);
				#$value = $anomaly{DATA}{$fqdn}{$met}{$hour}{AVG_VALUE}*100 if ($met=~/^system\.cpu/);
				$value = $anomaly_details{DATA}{$fqdn}{$met}{$hour}{METRIC_VALUE};
				$value = $value*100 if ($met=~/system\-cpu\-m\d\-CPUUtilization/);
				my $score;
				$score = $anomaly_details{DATA}{$fqdn}{$met}{$hour}{SCORE};
				
				$average_data{HOST}{$fqdn}{HOUR_OF_DAY}{$hour_of_day}{$met}{TOTAL}+=$value;						
				$average_data{HOST}{$fqdn}{HOUR_OF_DAY}{$hour_of_day}{$met}{TOTAL_SCORE}+=$score;
				$average_data{HOST}{$fqdn}{HOUR_OF_DAY}{$hour_of_day}{$met}{COUNT}++;
				$average_data{HOST}{$fqdn}{HOUR_OF_DAY}{$hour_of_day}{$met}{ANOM_COUNT}+=$anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT} if($anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT}>0);				
				$average_data{METRIC}{$met}{HOUR_OF_DAY}{$hour_of_day}{TOTAL}+=$value;
				$average_data{METRIC}{$met}{HOUR_OF_DAY}{$hour_of_day}{TOTAL_SCORE}+=$score;
				$average_data{METRIC}{$met}{HOUR_OF_DAY}{$hour_of_day}{COUNT}++;
				$average_data{METRIC}{$met}{HOUR_OF_DAY}{$hour_of_day}{ANOM_COUNT}+=$anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT} if($anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT}>0);
				
				push @{$average_data{METRIC}{$met}{HOUR_OF_DAY}{$hour_of_day}{HOSTS}}, $fqdn;
				
				$average_data{HOST}{$fqdn}{DAY_OF_WEEK}{$day_of_week}{$met}{TOTAL}+=$value; 					
				$average_data{HOST}{$fqdn}{DAY_OF_WEEK}{$day_of_week}{$met}{TOTAL_SCORE}+=$score; 
				$average_data{HOST}{$fqdn}{DAY_OF_WEEK}{$day_of_week}{$met}{COUNT}++;
				$average_data{HOST}{$fqdn}{DAY_OF_WEEK}{$day_of_week}{$met}{ANOM_COUNT}+=$anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT} if($anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT}>0);
				
				
				$average_data{METRIC}{$met}{DAY_OF_WEEK}{$day_of_week}{TOTAL}+=$value; 					
				$average_data{METRIC}{$met}{DAY_OF_WEEK}{$day_of_week}{TOTAL_SCORE}+=$score; 
				$average_data{METRIC}{$met}{DAY_OF_WEEK}{$day_of_week}{COUNT}++;
				$average_data{METRIC}{$met}{DAY_OF_WEEK}{$day_of_week}{ANOM_COUNT}+=$anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT} if($anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT}>0);
				push @{$average_data{METRIC}{$met}{DAY_OF_WEEK}{$day_of_week}{HOSTS}}, $fqdn;
				
				$average_data{HOST}{$fqdn}{MONTH_OF_YEAR}{$day}{$met}{TOTAL}+=$value;
				$average_data{HOST}{$fqdn}{MONTH_OF_YEAR}{$day}{$met}{TOTAL_SCORE}+=$score;
				$average_data{HOST}{$fqdn}{MONTH_OF_YEAR}{$day}{$met}{COUNT}++;
				$average_data{HOST}{$fqdn}{MONTH_OF_YEAR}{$day}{$met}{ANOM_COUNT}+=$anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT} if($anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT}>0);
				
				$average_data{METRIC}{$met}{MONTH_OF_YEAR}{$day}{TOTAL}+=$value; 									
				$average_data{METRIC}{$met}{MONTH_OF_YEAR}{$day}{SCORE}+=$score;
				$average_data{METRIC}{$met}{MONTH_OF_YEAR}{$day}{COUNT}++;
				$average_data{METRIC}{$met}{MONTH_OF_YEAR}{$day}{ANOM_COUNT}+=$anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT} if ($anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT}>0);
				push @{$average_data{METRIC}{$met}{MONTH_OF_YEAR}{$day}{HOSTS}}, $fqdn;
				
				
				### Get recent Time period data for HOSTS
				if($last_24){		
					#print "24HR FQDN Fqdn:$fqdn Met:$met Hour:$hour\n"	;			
					$average_data{HOST}{$fqdn}{HOURS}{$hour_date}{$met}{TOTAL}+=$value;
					$average_data{HOST}{$fqdn}{HOURS}{$hour_date}{$met}{TOTAL_SCORE}+=$score;
					$average_data{HOST}{$fqdn}{HOURS}{$hour_date}{$met}{COUNT}++;
					$average_data{HOST}{$fqdn}{HOURS}{$hour_date}{$met}{ANOM_COUNT}+=$anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT} if($anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT}>0);					
					$counter{HOURS}{$fqdn}{$met}{$hour_date}=1;		
				}															
				
				if($last_7){	
					#print "7D FQDN Fqdn:$fqdn Met:$met Day:$day\n"	;									
					$average_data{HOST}{$fqdn}{DAYS}{$day}{$met}{TOTAL}+=$value;
					$average_data{HOST}{$fqdn}{DAYS}{$day}{$met}{TOTAL_SCORE}+=$score;
					$average_data{HOST}{$fqdn}{DAYS}{$day}{$met}{COUNT}++;
					$average_data{HOST}{$fqdn}{DAYS}{$day}{$met}{ANOM_COUNT}+=$anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT} if($anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT}>0);
					$counter{DAYS}{$fqdn}{$met}{$day}=1;					
				}
				
				if($last_30){				
					#print "30D FQDN Fqdn:$fqdn Met:$met Day:$day\n"	;				
					$average_data{HOST}{$fqdn}{MONTHS}{$day}{$met}{TOTAL}+=$value;
					$average_data{HOST}{$fqdn}{MONTHS}{$day}{$met}{TOTAL_SCORE}+=$score;
					$average_data{HOST}{$fqdn}{MONTHS}{$day}{$met}{COUNT}++;		
					$average_data{HOST}{$fqdn}{MONTHS}{$day}{$met}{ANOM_COUNT}+=$anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT}  if($anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT}>0);
					$counter{MONTHS}{$fqdn}{$met}{$day}=1;
				}
				if(scalar(keys %{$counter{THREEMONTHS}{$fqdn}{$met}})<92){					
					$average_data{HOST}{$fqdn}{THREEMONTHS}{$day}{$met}{TOTAL}+=$value;
					$average_data{HOST}{$fqdn}{THREEMONTHS}{$day}{$met}{TOTAL_SCORE}+=$score;
					$average_data{HOST}{$fqdn}{THREEMONTHS}{$day}{$met}{COUNT}++;		
					$average_data{HOST}{$fqdn}{THREEMONTHS}{$day}{$met}{ANOM_COUNT}+=$anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT}  if($anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT}>0);
					$counter{THREEMONTHS}{$fqdn}{$met}{$day}=1;
				}
				if(scalar(keys %{$counter{SIXMONTHS}{$fqdn}{$met}})<126){					
					$average_data{HOST}{$fqdn}{SIXMONTHS}{$day}{$met}{TOTAL}+=$value; 			
					$average_data{HOST}{$fqdn}{SIXMONTHS}{$day}{$met}{TOTAL_SCORE}+=$score;
					$average_data{HOST}{$fqdn}{SIXMONTHS}{$day}{$met}{COUNT}++;		
					$average_data{HOST}{$fqdn}{SIXMONTHS}{$day}{$met}{ANOM_COUNT}+=$anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT}  if($anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT}>0);
					$counter{SIXMONTHS}{$fqdn}{$met}{$day}=1;
				}
				if(scalar(keys %{$counter{TWELVEMONTHS}{$fqdn}{$met}})<368){					
					$average_data{HOST}{$fqdn}{TWELVEMONTHS}{$day}{$met}{TOTAL}+=$value; 		
					$average_data{HOST}{$fqdn}{TWELVEMONTHS}{$day}{$met}{TOTAL_SCORE}+=$score;
					$average_data{HOST}{$fqdn}{TWELVEMONTHS}{$day}{$met}{COUNT}++;		
					$average_data{HOST}{$fqdn}{TWELVEMONTHS}{$day}{$met}{ANOM_COUNT}+=$anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT}  if($anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT}>0);
					$counter{TWELVEMONTHS}{$fqdn}{$met}{$day}=1;
				}
				
				### Get recent Time period data for METRICS
				if($last_24){					
					#print "24HR MET Met:$met Hour:$hour\n"	;			
					$average_data{METRIC}{$met}{HOURS}{$hour_date}{TOTAL}+=$value;												
					$average_data{METRIC}{$met}{HOURS}{$hour_date}{TOTAL_SCORE}+=$score;
					$average_data{METRIC}{$met}{HOURS}{$hour_date}{COUNT}++;
					$average_data{METRIC}{$met}{HOURS}{$hour_date}{ANOM_COUNT}+=$anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT}  if($anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT}>0);
					$counter{HOURS}{$met}{$hour_date}=1;
				}																			
				if($last_7){					
					#print "7D MET Met:$met Day:$day Hour:$hour\n"	;	
					$average_data{METRIC}{$met}{DAYS}{$day}{TOTAL}+=$value;
					$average_data{METRIC}{$met}{DAYS}{$day}{TOTAL_SCORE}+=$score;
					$average_data{METRIC}{$met}{DAYS}{$day}{COUNT}++;
					$average_data{METRIC}{$met}{DAYS}{$day}{ANOM_COUNT}+=$anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT}  if($anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT}>0);
					$counter{DAYS}{$met}{$day}=1;
				}
				
				if($last_30){					
					#print "30D MET Met:$met Hour:$day\n"	;	
					$average_data{METRIC}{$met}{MONTHS}{$day}{TOTAL}+=$value;
					$average_data{METRIC}{$met}{MONTHS}{$day}{TOTAL_SCORE}+=$score;
					$average_data{METRIC}{$met}{MONTHS}{$day}{COUNT}++;		
					$average_data{METRIC}{$met}{MONTHS}{$day}{ANOM_COUNT}+=$anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT}  if($anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT}>0);
					$counter{MONTHS}{$met}{$day}=1;
				}
				if(scalar(keys %{$counter{THREEMONTHS}{$met}})<92){					
					$average_data{METRIC}{$met}{THREEMONTHS}{$day}{TOTAL}+=$value; 
					$average_data{METRIC}{$met}{THREEMONTHS}{$day}{TOTAL_SCORE}+=$score; 
					$average_data{METRIC}{$met}{THREEMONTHS}{$day}{COUNT}++;		
					$average_data{METRIC}{$met}{THREEMONTHS}{$day}{ANOM_COUNT}+=$anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT}  if($anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT}>0);
					$counter{THREEMONTHS}{$met}{$day}=1;
				}
				if(scalar(keys %{$counter{SIXMONTHS}{$met}})<126){					
					$average_data{METRIC}{$met}{SIXMONTHS}{$day}{TOTAL}+=$value;
					$average_data{METRIC}{$met}{SIXMONTHS}{$day}{TOTAL_SCORE}+=$score;
					$average_data{METRIC}{$met}{SIXMONTHS}{$day}{COUNT}++;		
					$average_data{METRIC}{$met}{SIXMONTHS}{$day}{ANOM_COUNT}+=$anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT}  if($anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT}>0);
					$counter{SIXMONTHS}{$met}{$day}=1;
				}
				if(scalar(keys %{$counter{TWELVEMONTHS}{$met}})<368){					
					$average_data{METRIC}{$met}{TWELVEMONTHS}{$day}{TOTAL}+=$value; 		
					$average_data{METRIC}{$met}{TWELVEMONTHS}{$day}{TOTAL_SCORE}+=$score;
					$average_data{METRIC}{$met}{TWELVEMONTHS}{$day}{COUNT}++;		
					$average_data{METRIC}{$met}{TWELVEMONTHS}{$day}{ANOM_COUNT}+=$anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT}  if($anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT}>0);
					$counter{TWELVEMONTHS}{$met}{$day}=1;
				}
			}
		}
	}
	
	## Calculate Averages for Chart Data for HOSTS
	foreach my $node (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{HOST}}){	
		#print Dumper $average_data{HOST}{$node}{MONTHS} if($node =~/ln17/);
		foreach my $hour (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{HOST}{$node}{HOUR_OF_DAY}}){		
			foreach my $met (sort keys %{$average_data{HOST}{$node}{HOUR_OF_DAY}{$hour}}){									
				$average_data{HOST}{$node}{HOUR_OF_DAY}{$hour}{$met}{AVERAGE}= sprintf "%.2f",$average_data{HOST}{$node}{HOUR_OF_DAY}{$hour}{$met}{TOTAL}/$average_data{HOST}{$node}{HOUR_OF_DAY}{$hour}{$met}{COUNT};				
				$average_data{HOST}{$node}{HOUR_OF_DAY}{$hour}{$met}{AVERAGE_SCORE}= sprintf "%.3f",$average_data{HOST}{$node}{HOUR_OF_DAY}{$hour}{$met}{TOTAL_SCORE}/$average_data{HOST}{$node}{HOUR_OF_DAY}{$hour}{$met}{COUNT};
			}
		}
		foreach my $day (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{HOST}{$node}{DAY_OF_WEEK}}){		
			foreach my $met (sort keys %{$average_data{HOST}{$node}{DAY_OF_WEEK}{$day}}){									
				$average_data{HOST}{$node}{DAY_OF_WEEK}{$day}{$met}{AVERAGE}= sprintf "%.2f",$average_data{HOST}{$node}{DAY_OF_WEEK}{$day}{$met}{TOTAL}/$average_data{HOST}{$node}{DAY_OF_WEEK}{$day}{$met}{COUNT};				
				$average_data{HOST}{$node}{DAY_OF_WEEK}{$day}{$met}{AVERAGE_SCORE}= sprintf "%.3f",$average_data{HOST}{$node}{DAY_OF_WEEK}{$day}{$met}{TOTAL_SCORE}/$average_data{HOST}{$node}{DAY_OF_WEEK}{$day}{$met}{COUNT};	
			}
		}
		foreach my $day (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{HOST}{$node}{MONTH_OF_YEAR}}){		
			foreach my $met (sort keys %{$average_data{HOST}{$node}{MONTH_OF_YEAR}{$day}}){									
				$average_data{HOST}{$node}{MONTH_OF_YEAR}{$day}{$met}{AVERAGE}= sprintf "%.2f",$average_data{HOST}{$node}{MONTH_OF_YEAR}{$day}{$met}{TOTAL}/$average_data{HOST}{$node}{MONTH_OF_YEAR}{$day}{$met}{COUNT};				
				$average_data{HOST}{$node}{MONTH_OF_YEAR}{$day}{$met}{AVERAGE_SCORE}= sprintf "%.3f",$average_data{HOST}{$node}{MONTH_OF_YEAR}{$day}{$met}{TOTAL_SCORE}/$average_data{HOST}{$node}{MONTH_OF_YEAR}{$day}{$met}{COUNT};				
			}
		}
		foreach my $hour (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{HOST}{$node}{HOURS}}){		
			foreach my $met (sort keys %{$average_data{HOST}{$node}{HOURS}{$hour}}){									
				$average_data{HOST}{$node}{HOURS}{$hour}{$met}{AVERAGE}= sprintf "%.2f",$average_data{HOST}{$node}{HOURS}{$hour}{$met}{TOTAL}/$average_data{HOST}{$node}{HOURS}{$hour}{$met}{COUNT};				
				$average_data{HOST}{$node}{HOURS}{$hour}{$met}{AVERAGE_SCORE}= sprintf "%.3f",$average_data{HOST}{$node}{HOURS}{$hour}{$met}{TOTAL_SCORE}/$average_data{HOST}{$node}{HOURS}{$hour}{$met}{COUNT};				
				#print "AVERAGE:Node:$node Met:$met Hour:$hour is in the last 24hrs\n"	;			
			}
		}
		foreach my $day (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{HOST}{$node}{DAYS}}){		
			foreach my $met (sort keys %{$average_data{HOST}{$node}{DAYS}{$day}}){									
				$average_data{HOST}{$node}{DAYS}{$day}{$met}{AVERAGE}= sprintf "%.2f",$average_data{HOST}{$node}{DAYS}{$day}{$met}{TOTAL}/$average_data{HOST}{$node}{DAYS}{$day}{$met}{COUNT};				
				$average_data{HOST}{$node}{DAYS}{$day}{$met}{AVERAGE_SCORE}= sprintf "%.3f",$average_data{HOST}{$node}{DAYS}{$day}{$met}{TOTAL_SCORE}/$average_data{HOST}{$node}{DAYS}{$day}{$met}{COUNT};				
			}
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{HOST}{$node}{MONTHS}}){		
			foreach my $met (sort keys %{$average_data{HOST}{$node}{MONTHS}{$month}}){					
				$average_data{HOST}{$node}{MONTHS}{$month}{$met}{AVERAGE}= sprintf "%.2f",$average_data{HOST}{$node}{MONTHS}{$month}{$met}{TOTAL}/$average_data{HOST}{$node}{MONTHS}{$month}{$met}{COUNT};
				$average_data{HOST}{$node}{MONTHS}{$month}{$met}{AVERAGE_SCORE}= sprintf "%.3f",$average_data{HOST}{$node}{MONTHS}{$month}{$met}{TOTAL_SCORE}/$average_data{HOST}{$node}{MONTHS}{$month}{$met}{COUNT};
			}
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{HOST}{$node}{THREEMONTHS}}){		
			foreach my $met (sort keys %{$average_data{HOST}{$node}{THREEMONTHS}{$month}}){					
				$average_data{HOST}{$node}{THREEMONTHS}{$month}{$met}{AVERAGE}= sprintf "%.2f",$average_data{HOST}{$node}{THREEMONTHS}{$month}{$met}{TOTAL}/$average_data{HOST}{$node}{THREEMONTHS}{$month}{$met}{COUNT};
				$average_data{HOST}{$node}{THREEMONTHS}{$month}{$met}{AVERAGE_SCORE}= sprintf "%.3f",$average_data{HOST}{$node}{THREEMONTHS}{$month}{$met}{TOTAL_SCORE}/$average_data{HOST}{$node}{THREEMONTHS}{$month}{$met}{COUNT};
			}
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{HOST}{$node}{SIXMONTHS}}){		
			foreach my $met (sort keys %{$average_data{HOST}{$node}{SIXMONTHS}{$month}}){					
				$average_data{HOST}{$node}{SIXMONTHS}{$month}{$met}{AVERAGE}= sprintf "%.2f",$average_data{HOST}{$node}{SIXMONTHS}{$month}{$met}{TOTAL}/$average_data{HOST}{$node}{SIXMONTHS}{$month}{$met}{COUNT};
				$average_data{HOST}{$node}{SIXMONTHS}{$month}{$met}{AVERAGE_SCORE}= sprintf "%.3f",$average_data{HOST}{$node}{SIXMONTHS}{$month}{$met}{TOTAL_SCORE}/$average_data{HOST}{$node}{SIXMONTHS}{$month}{$met}{COUNT};
			}
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{HOST}{$node}{TWELVEMONTHS}}){		
			foreach my $met (sort keys %{$average_data{HOST}{$node}{TWELVEMONTHS}{$month}}){					
				$average_data{HOST}{$node}{TWELVEMONTHS}{$month}{$met}{AVERAGE}= sprintf "%.2f",$average_data{HOST}{$node}{TWELVEMONTHS}{$month}{$met}{TOTAL}/$average_data{HOST}{$node}{TWELVEMONTHS}{$month}{$met}{COUNT};
				$average_data{HOST}{$node}{TWELVEMONTHS}{$month}{$met}{AVERAGE_SCORE}= sprintf "%.3f",$average_data{HOST}{$node}{TWELVEMONTHS}{$month}{$met}{TOTAL_SCORE}/$average_data{HOST}{$node}{TWELVEMONTHS}{$month}{$met}{COUNT};
			}
		}
	}
	
	## Calculate Averages for Chart Data for METRICS
	foreach my $met (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{METRIC}}){	
		#print Dumper $average_data{METRIC}{$met}{MONTHS} if($met =~/ln17/);
		foreach my $hour (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{METRIC}{$met}{HOUR_OF_DAY}}){					
			$average_data{METRIC}{$met}{HOUR_OF_DAY}{$hour}{AVERAGE}= sprintf "%.2f",$average_data{METRIC}{$met}{HOUR_OF_DAY}{$hour}{TOTAL}/$average_data{METRIC}{$met}{HOUR_OF_DAY}{$hour}{COUNT};							
			$average_data{METRIC}{$met}{HOUR_OF_DAY}{$hour}{AVERAGE_SCORE}= sprintf "%.3f",$average_data{METRIC}{$met}{HOUR_OF_DAY}{$hour}{TOTAL_SCORE}/$average_data{METRIC}{$met}{HOUR_OF_DAY}{$hour}{COUNT};							
		}
		foreach my $day (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{METRIC}{$met}{DAY_OF_WEEK}}){					
			$average_data{METRIC}{$met}{DAY_OF_WEEK}{$day}{AVERAGE}= sprintf "%.2f",$average_data{METRIC}{$met}{DAY_OF_WEEK}{$day}{TOTAL}/$average_data{METRIC}{$met}{DAY_OF_WEEK}{$day}{COUNT};							
			$average_data{METRIC}{$met}{DAY_OF_WEEK}{$day}{AVERAGE_SCORE}= sprintf "%.3f",$average_data{METRIC}{$met}{DAY_OF_WEEK}{$day}{TOTAL_SCORE}/$average_data{METRIC}{$met}{DAY_OF_WEEK}{$day}{COUNT};							
		}
		foreach my $day (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{METRIC}{$met}{MONTH_OF_YEAR}}){					
			$average_data{METRIC}{$met}{MONTH_OF_YEAR}{$day}{AVERAGE}= sprintf "%.2f",$average_data{METRIC}{$met}{MONTH_OF_YEAR}{$day}{TOTAL}/$average_data{METRIC}{$met}{MONTH_OF_YEAR}{$day}{COUNT};							
			$average_data{METRIC}{$met}{MONTH_OF_YEAR}{$day}{AVERAGE_SCORE}= sprintf "%.3f",$average_data{METRIC}{$met}{MONTH_OF_YEAR}{$day}{TOTAL_SCORE}/$average_data{METRIC}{$met}{MONTH_OF_YEAR}{$day}{COUNT};							
		}
		foreach my $hour (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{METRIC}{$met}{HOURS}}){					
			$average_data{METRIC}{$met}{HOURS}{$hour}{AVERAGE}= sprintf "%.2f",$average_data{METRIC}{$met}{HOURS}{$hour}{TOTAL}/$average_data{METRIC}{$met}{HOURS}{$hour}{COUNT};							
			$average_data{METRIC}{$met}{HOURS}{$hour}{AVERAGE_SCORE}= sprintf "%.3f",$average_data{METRIC}{$met}{HOURS}{$hour}{TOTAL_SCORE}/$average_data{METRIC}{$met}{HOURS}{$hour}{COUNT};							
		}
		foreach my $day (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{METRIC}{$met}{DAYS}}){					
			$average_data{METRIC}{$met}{DAYS}{$day}{AVERAGE}= sprintf "%.2f",$average_data{METRIC}{$met}{DAYS}{$day}{TOTAL}/$average_data{METRIC}{$met}{DAYS}{$day}{COUNT};				
			$average_data{METRIC}{$met}{DAYS}{$day}{AVERAGE_SCORE}= sprintf "%.3f",$average_data{METRIC}{$met}{DAYS}{$day}{TOTAL_SCORE}/$average_data{METRIC}{$met}{DAYS}{$day}{COUNT};				
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{METRIC}{$met}{MONTHS}}){					
			$average_data{METRIC}{$met}{MONTHS}{$month}{AVERAGE}= sprintf "%.2f",$average_data{METRIC}{$met}{MONTHS}{$month}{TOTAL}/$average_data{METRIC}{$met}{MONTHS}{$month}{COUNT};			
			$average_data{METRIC}{$met}{MONTHS}{$month}{AVERAGE_SCORE}= sprintf "%.3f",$average_data{METRIC}{$met}{MONTHS}{$month}{TOTAL_SCORE}/$average_data{METRIC}{$met}{MONTHS}{$month}{COUNT};			
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{METRIC}{$met}{THREEMONTHS}}){					
			$average_data{METRIC}{$met}{THREEMONTHS}{$month}{AVERAGE}= sprintf "%.2f",$average_data{METRIC}{$met}{THREEMONTHS}{$month}{TOTAL}/$average_data{METRIC}{$met}{THREEMONTHS}{$month}{COUNT};			
			$average_data{METRIC}{$met}{THREEMONTHS}{$month}{AVERAGE_SCORE}= sprintf "%.3f",$average_data{METRIC}{$met}{THREEMONTHS}{$month}{TOTAL_SCORE}/$average_data{METRIC}{$met}{THREEMONTHS}{$month}{COUNT};			
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{METRIC}{$met}{SIXMONTHS}}){					
			$average_data{METRIC}{$met}{SIXMONTHS}{$month}{AVERAGE}= sprintf "%.2f",$average_data{METRIC}{$met}{SIXMONTHS}{$month}{TOTAL}/$average_data{METRIC}{$met}{SIXMONTHS}{$month}{COUNT};			
			$average_data{METRIC}{$met}{SIXMONTHS}{$month}{AVERAGE_SCORE}= sprintf "%.3f",$average_data{METRIC}{$met}{SIXMONTHS}{$month}{TOTAL_SCORE}/$average_data{METRIC}{$met}{SIXMONTHS}{$month}{COUNT};			
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{METRIC}{$met}{TWELVEMONTHS}}){					
			$average_data{METRIC}{$met}{TWELVEMONTHS}{$month}{AVERAGE}= sprintf "%.2f",$average_data{METRIC}{$met}{TWELVEMONTHS}{$month}{TOTAL}/$average_data{METRIC}{$met}{TWELVEMONTHS}{$month}{COUNT};			
			$average_data{METRIC}{$met}{TWELVEMONTHS}{$month}{AVERAGE_SCORE}= sprintf "%.3f",$average_data{METRIC}{$met}{TWELVEMONTHS}{$month}{TOTAL_SCORE}/$average_data{METRIC}{$met}{TWELVEMONTHS}{$month}{COUNT};			
		}
	}
	
	
	### Add Averages for Chart data Arrays for HOSTS
	foreach my $node (sort keys %{$average_data{HOST}}){	
		#print Dumper $average_data{HOST}{$node}{MONTHS} if ($node eq "aws-ec2");
		foreach my $hour (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{HOST}{$node}{HOUR_OF_DAY}}){					
			foreach my $met (sort keys %{$average_data{HOST}{$node}{HOUR_OF_DAY}{$hour}}){		
				my $metname=$met;
				$colorcount=0;
				$metname=~s/\\+//g;
				#$metname=~s/system\-cpu\///g;
				push @{$chartdata{HOST}{$node}{HOUR_OF_DAY}{$metname}{DATASET}}, $average_data{HOST}{$node}{HOUR_OF_DAY}{$hour}{$met}{AVERAGE};			
				push @{$chartdata{HOST}{$node}{HOUR_OF_DAY}{$metname}{DATASET_ANOM}},$average_data{HOST}{$node}{HOUR_OF_DAY}{$hour}{$met}{ANOM_COUNT};
				push @{$chartdata{HOST}{$node}{HOUR_OF_DAY}{$metname}{DATASET_SCORE}},$average_data{HOST}{$node}{HOUR_OF_DAY}{$hour}{$met}{AVERAGE_SCORE};
				$chartdata{HOST}{$node}{HOUR_OF_DAY}{$metname}{LABLE}="$met";
				$chartdata{HOST}{$node}{HOUR_OF_DAY}{$metname}{COLOUR}=$colorcodes[$colorcount];				
				push @{$chartdata{HOST}{$node}{HOUR_OF_DAY}{$metname}{LABLES}},$hour;							
				#print "ANOM:$average_data{HOST}{$node}{HOUR_OF_DAY}{$hour}{$met}{ANOM_COUNT} Hour:$hour Met:$met Node:$node\n" if($average_data{HOST}{$node}{HOUR_OF_DAY}{$hour}{$met}{ANOM_COUNT}>0);
				
				$colorcount++;
			}
		}
		### Day of Week
		foreach my $day (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{HOST}{$node}{DAY_OF_WEEK}}){				
			foreach my $met (sort keys %{$average_data{HOST}{$node}{DAY_OF_WEEK}{$day}}){		
				$colorcount=0;	
				my $metname=$met;				
				$metname=~s/\\+//g;
				#$metname=~s/system\-cpu\///g;
				push @{$chartdata{HOST}{$node}{DAY_OF_WEEK}{$metname}{DATASET}}, $average_data{HOST}{$node}{DAY_OF_WEEK}{$day}{$met}{AVERAGE};			
				push @{$chartdata{HOST}{$node}{DAY_OF_WEEK}{$metname}{DATASET_ANOM}}, $average_data{HOST}{$node}{DAY_OF_WEEK}{$day}{$met}{ANOM_COUNT};			
				push @{$chartdata{HOST}{$node}{DAY_OF_WEEK}{$metname}{DATASET_SCORE}}, $average_data{HOST}{$node}{DAY_OF_WEEK}{$day}{$met}{AVERAGE_SCORE};			
				$chartdata{HOST}{$node}{DAY_OF_WEEK}{$metname}{LABLE}="$met";
				$chartdata{HOST}{$node}{DAY_OF_WEEK}{$metname}{COLOUR}=$colorcodes[$colorcount];				
				push @{$chartdata{HOST}{$node}{DAY_OF_WEEK}{$metname}{LABLES}},$day;			
				$colorcount++;
			}
		}
		### Month Of the Year
		foreach my $day (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{HOST}{$node}{MONTH_OF_YEAR}}){					
			foreach my $met (sort keys %{$average_data{HOST}{$node}{MONTH_OF_YEAR}{$day}}){		
				$colorcount=0;
				my $metname=$met;								
				$metname=~s/\\+//g;
				my ($month) = $day=~m/^\d\d\d\d\-(\d\d)\-\d\d/;				
				my ($year) = $day=~m/^(\d\d\d\d)\-\d\d\-\d\d/;								
				my $month_c =$months[$month - 1]."_" .$year;								
				#$metname=~s/system\-cpu\///g;
				push @{$chartdata{HOST}{$node}{MONTH_OF_YEAR}{$metname}{$month_c}{DATASET}}, $average_data{HOST}{$node}{MONTH_OF_YEAR}{$day}{$met}{AVERAGE};			
				push @{$chartdata{HOST}{$node}{MONTH_OF_YEAR}{$metname}{$month_c}{DATASET_ANOM}}, $average_data{HOST}{$node}{MONTH_OF_YEAR}{$day}{$met}{ANOM_COUNT};			
				push @{$chartdata{HOST}{$node}{MONTH_OF_YEAR}{$metname}{$month_c}{DATASET_SCORE}}, $average_data{HOST}{$node}{MONTH_OF_YEAR}{$day}{$met}{AVERAGE_SCORE};			
				$chartdata{HOST}{$node}{MONTH_OF_YEAR}{$metname}{$month_c}{LABLE}="$met";
				$chartdata{HOST}{$node}{MONTH_OF_YEAR}{$metname}{$month_c}{COLOUR}=$colorcodes[$colorcount];				
				push @{$chartdata{HOST}{$node}{MONTH_OF_YEAR}{$metname}{$month_c}{LABLES}},$day;			
				$colorcount++;
			}
		}
		foreach my $hour (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{HOST}{$node}{HOURS}}){					
			my $metcolorcount=0;
			foreach my $met (sort keys %{$average_data{HOST}{$node}{HOURS}{$hour}}){		
				$colorcount=0 if($met !~/disk|file/);
				my $metname=$met;				
				$colorcount=0;
				$metname=~s/\\+//g;
				#$metname=~s/system\-cpu\///g;
				#print "CHART:Node:$node Met:$metname Hour:$hour is in the last 24hrs Average:$average_data{HOST}{$node}{HOURS}{$hour}{$met}{AVERAGE}\n"	;	
				push @{$chartdata{HOST}{$node}{HOURS}{$metname}{DATASET}}, $average_data{HOST}{$node}{HOURS}{$hour}{$met}{AVERAGE};			
				push @{$chartdata{HOST}{$node}{HOURS}{$metname}{DATASET_ANOM}}, $average_data{HOST}{$node}{HOURS}{$hour}{$met}{ANOM_COUNT};			
				push @{$chartdata{HOST}{$node}{HOURS}{$metname}{DATASET_SCORE}}, $average_data{HOST}{$node}{HOURS}{$hour}{$met}{AVERAGE_SCORE};			
				$chartdata{HOST}{$node}{HOURS}{$metname}{LABLE}="$met";
				$chartdata{HOST}{$node}{HOURS}{$metname}{COLOUR}=$colorcodes[$colorcount];				
				$chartdata{HOST}{$node}{HOURS}{$metname}{MET_COLOUR}=$colorcodes[$metcolorcount];		
				my ($hour_label)=$hour=~m/\d\d\d\d\-\d\d\-\d\d\s(\d\d)/;
				$hour_label.=":00";
				#my ($hour_label)=$hour=~m/\d\d\d\d\-\d\d\-\d\d\s(\d\d\:\d\d)\:\d\d/;				
				push @{$chartdata{HOST}{$node}{HOURS}{$metname}{LABLES}},$hour_label;			
				$colorcount++;
				$metcolorcount++;
			}
		}
		foreach my $day (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{HOST}{$node}{DAYS}}){					
			my $metcolorcount=0;
			foreach my $met (sort keys %{$average_data{HOST}{$node}{DAYS}{$day}}){		
				$colorcount=0 if($met !~/disk|file/);
				my $metname=$met;				
				$colorcount=0;
				$metname=~s/\\+//g;
				#$metname=~s/system\-cpu\///g;
				push @{$chartdata{HOST}{$node}{DAYS}{$metname}{DATASET}}, $average_data{HOST}{$node}{DAYS}{$day}{$met}{AVERAGE};			
				push @{$chartdata{HOST}{$node}{DAYS}{$metname}{DATASET_ANOM}}, $average_data{HOST}{$node}{DAYS}{$day}{$met}{ANOM_COUNT};	
				push @{$chartdata{HOST}{$node}{DAYS}{$metname}{DATASET_SCORE}}, $average_data{HOST}{$node}{DAYS}{$day}{$met}{AVERAGE_SCORE};	
				$chartdata{HOST}{$node}{DAYS}{$metname}{LABLE}="$met";
				$chartdata{HOST}{$node}{DAYS}{$metname}{COLOUR}=$colorcodes[$colorcount];		
				$chartdata{HOST}{$node}{DAYS}{$metname}{MET_COLOUR}=$colorcodes[$metcolorcount];		
				push @{$chartdata{HOST}{$node}{DAYS}{$metname}{LABLES}},$day;			
				$colorcount++;
				$metcolorcount++;
			}
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{HOST}{$node}{MONTHS}}){					
			my $metcolorcount=0;
			foreach my $met (sort keys %{$average_data{HOST}{$node}{MONTHS}{$month}}){		
				$colorcount=0 if($met !~/disk|file/);
				my $metname=$met;				
				$metname=~s/\\+//g;
				push @{$chartdata{HOST}{$node}{MONTHS}{$metname}{DATASET}}, $average_data{HOST}{$node}{MONTHS}{$month}{$met}{AVERAGE};			
				push @{$chartdata{HOST}{$node}{MONTHS}{$metname}{DATASET_ANOM}}, $average_data{HOST}{$node}{MONTHS}{$month}{$met}{ANOM_COUNT};	
				push @{$chartdata{HOST}{$node}{MONTHS}{$metname}{DATASET_SCORE}}, $average_data{HOST}{$node}{MONTHS}{$month}{$met}{AVERAGE_SCORE};	
				$chartdata{HOST}{$node}{MONTHS}{$metname}{LABLE}="$met";
				$chartdata{HOST}{$node}{MONTHS}{$metname}{COLOUR}=$colorcodes[$colorcount];				
				$chartdata{HOST}{$node}{MONTHS}{$metname}{MET_COLOUR}=$colorcodes[$metcolorcount];
				push @{$chartdata{HOST}{$node}{MONTHS}{$metname}{LABLES}},$month;			
				$colorcount++;
				$metcolorcount++;
			}
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{HOST}{$node}{THREEMONTHS}}){					
			foreach my $met (sort keys %{$average_data{HOST}{$node}{THREEMONTHS}{$month}}){		
				$colorcount=0;
				my $metname=$met;				
				$metname=~s/\\+//g;
				#$metname=~s/system\-cpu\///g;
				push @{$chartdata{HOST}{$node}{THREEMONTHS}{$metname}{DATASET}}, $average_data{HOST}{$node}{THREEMONTHS}{$month}{$met}{AVERAGE};			
				push @{$chartdata{HOST}{$node}{THREEMONTHS}{$metname}{DATASET_ANOM}}, $average_data{HOST}{$node}{THREEMONTHS}{$month}{$met}{ANOM_COUNT};			
				push @{$chartdata{HOST}{$node}{THREEMONTHS}{$metname}{DATASET_SCORE}}, $average_data{HOST}{$node}{THREEMONTHS}{$month}{$met}{AVERAGE_SCORE};			
				$chartdata{HOST}{$node}{THREEMONTHS}{$metname}{LABLE}="$met";
				$chartdata{HOST}{$node}{THREEMONTHS}{$metname}{COLOUR}=$colorcodes[$colorcount];				
				push @{$chartdata{HOST}{$node}{THREEMONTHS}{$metname}{LABLES}},$month;			
				$colorcount++;
			}
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{HOST}{$node}{SIXMONTHS}}){					
			foreach my $met (sort keys %{$average_data{HOST}{$node}{SIXMONTHS}{$month}}){		
				$colorcount=0;
				my $metname=$met;				
				$metname=~s/\\+//g;
				#$metname=~s/system\-cpu\///g;
				push @{$chartdata{HOST}{$node}{SIXMONTHS}{$metname}{DATASET}}, $average_data{HOST}{$node}{SIXMONTHS}{$month}{$met}{AVERAGE};			
				push @{$chartdata{HOST}{$node}{SIXMONTHS}{$metname}{DATASET_ANOM}}, $average_data{HOST}{$node}{SIXMONTHS}{$month}{$met}{ANOM_COUNT};			
				push @{$chartdata{HOST}{$node}{SIXMONTHS}{$metname}{DATASET_SCORE}}, $average_data{HOST}{$node}{SIXMONTHS}{$month}{$met}{AVERAGE_SCORE};			
				$chartdata{HOST}{$node}{SIXMONTHS}{$metname}{LABLE}="$met";
				$chartdata{HOST}{$node}{SIXMONTHS}{$metname}{COLOUR}=$colorcodes[$colorcount];				
				push @{$chartdata{HOST}{$node}{SIXMONTHS}{$metname}{LABLES}},$month;			
				$colorcount++;
			}
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{HOST}{$node}{TWELVEMONTHS}}){					
			foreach my $met (sort keys %{$average_data{HOST}{$node}{TWELVEMONTHS}{$month}}){		
				$colorcount=0;
				my $metname=$met;				
				$metname=~s/\\+//g;
				#$metname=~s/system\-cpu\///g;
				push @{$chartdata{HOST}{$node}{TWELVEMONTHS}{$metname}{DATASET}}, $average_data{HOST}{$node}{TWELVEMONTHS}{$month}{$met}{AVERAGE};			
				push @{$chartdata{HOST}{$node}{TWELVEMONTHS}{$metname}{DATASET_ANOM}}, $average_data{HOST}{$node}{TWELVEMONTHS}{$month}{$met}{ANOM_COUNT};	
				push @{$chartdata{HOST}{$node}{TWELVEMONTHS}{$metname}{DATASET_SCORE}}, $average_data{HOST}{$node}{TWELVEMONTHS}{$month}{$met}{AVERAGE_SCORE};	
				$chartdata{HOST}{$node}{TWELVEMONTHS}{$metname}{LABLE}="$met";
				$chartdata{HOST}{$node}{TWELVEMONTHS}{$metname}{COLOUR}=$colorcodes[$colorcount];				
				push @{$chartdata{HOST}{$node}{TWELVEMONTHS}{$metname}{LABLES}},$month;			
				$colorcount++;
			}
		}
	}
	
	
	### Add Averages for Chart data Arrays for METRICS
	foreach my $met (sort keys %{$average_data{METRIC}}){	
		foreach my $hour (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{METRIC}{$met}{HOUR_OF_DAY}}){		
			$colorcount=0;			
			my $metname=$met;			
			$metname=~s/\\+//g;
			#$metname=~s/system\-cpu\///g;
			push @{$chartdata{METRIC}{$metname}{HOUR_OF_DAY}{DATASET}}, $average_data{METRIC}{$met}{HOUR_OF_DAY}{$hour}{AVERAGE};			
			push @{$chartdata{METRIC}{$metname}{HOUR_OF_DAY}{DATASET_ANOM}}, $average_data{METRIC}{$met}{HOUR_OF_DAY}{$hour}{ANOM_COUNT};	
			push @{$chartdata{METRIC}{$metname}{HOUR_OF_DAY}{DATASET_SCORE}}, $average_data{METRIC}{$met}{HOUR_OF_DAY}{$hour}{AVERAGE_SCORE};	
			$chartdata{METRIC}{$metname}{HOUR_OF_DAY}{LABLE}="$met";
			$chartdata{METRIC}{$metname}{HOUR_OF_DAY}{COLOUR}=$colorcodes[$colorcount];				
			push @{$chartdata{METRIC}{$metname}{HOUR_OF_DAY}{LABLES}},$hour;			
			$colorcount++;
			
		}
		### Day of Week
		foreach my $day (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{METRIC}{$met}{DAY_OF_WEEK}}){
			$colorcount=0;				
			my $metname=$met;				
			$metname=~s/\\+//g;
			#$metname=~s/system\-cpu\///g;
			push @{$chartdata{METRIC}{$metname}{DAY_OF_WEEK}{DATASET}}, $average_data{METRIC}{$met}{DAY_OF_WEEK}{$day}{AVERAGE};			
			push @{$chartdata{METRIC}{$metname}{DAY_OF_WEEK}{DATASET_ANOM}}, $average_data{METRIC}{$met}{DAY_OF_WEEK}{$day}{ANOM_COUNT};		
			push @{$chartdata{METRIC}{$metname}{DAY_OF_WEEK}{DATASET_SCORE}}, $average_data{METRIC}{$met}{DAY_OF_WEEK}{$day}{AVERAGE_SCORE};
			$chartdata{METRIC}{$metname}{DAY_OF_WEEK}{LABLE}="$met";
			$chartdata{METRIC}{$metname}{DAY_OF_WEEK}{COLOUR}=$colorcodes[$colorcount];				
			push @{$chartdata{METRIC}{$metname}{DAY_OF_WEEK}{LABLES}},$day;			
			$colorcount++;			
		}
		### Month Of the Year
		foreach my $day (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{METRIC}{$met}{MONTH_OF_YEAR}}){		
			$colorcount=0;			
			my $metname=$met;				
			$metname=~s/\\+//g;
			my ($month) = $day=~m/^\d\d\d\d\-(\d\d)\-\d\d/;				
			my ($year) = $day=~m/^(\d\d\d\d)\-\d\d\-\d\d/;							
			my $month_c =$months[$month - 1]."_" .$year;
			#$metname=~s/system\-cpu\///g;
			push @{$chartdata{METRIC}{$metname}{MONTH_OF_YEAR}{$month_c}{DATASET}}, $average_data{METRIC}{$met}{MONTH_OF_YEAR}{$day}{AVERAGE};			
			push @{$chartdata{METRIC}{$metname}{MONTH_OF_YEAR}{$month_c}{DATASET_ANOM}}, $average_data{METRIC}{$met}{MONTH_OF_YEAR}{$day}{ANOM_COUNT};			
			push @{$chartdata{METRIC}{$metname}{MONTH_OF_YEAR}{$month_c}{DATASET_SCORE}}, $average_data{METRIC}{$met}{MONTH_OF_YEAR}{$day}{AVERAGE_SCORE};			
			$chartdata{METRIC}{$metname}{MONTH_OF_YEAR}{$month_c}{LABLE}="$met";
			$chartdata{METRIC}{$metname}{MONTH_OF_YEAR}{$month_c}{COLOUR}=$colorcodes[$colorcount];				
			push @{$chartdata{METRIC}{$metname}{MONTH_OF_YEAR}{$month_c}{LABLES}},$day;			
			$colorcount++;
			
		}
		foreach my $hour (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{METRIC}{$met}{HOURS}}){		
			$colorcount=0;			
			my $metname=$met;				
			$metname=~s/\\+//g;
			#$metname=~s/system\-cpu\///g;
			push @{$chartdata{METRIC}{$met}{HOURS}{DATASET}}, $average_data{METRIC}{$met}{HOURS}{$hour}{AVERAGE};			
			push @{$chartdata{METRIC}{$met}{HOURS}{DATASET_ANOM}}, $average_data{METRIC}{$met}{HOURS}{$hour}{ANOM_COUNT};			
			push @{$chartdata{METRIC}{$met}{HOURS}{DATASET_SCORE}}, $average_data{METRIC}{$met}{HOURS}{$hour}{AVERAGE_SCORE};			
			$chartdata{METRIC}{$met}{HOURS}{LABLE}="$met";
			$chartdata{METRIC}{$met}{HOURS}{COLOUR}=$colorcodes[$colorcount];				
			my ($hour_label)=$hour=~m/\d\d\d\d\-\d\d\-\d\d\s(\d\d)/;
			$hour_label.=":00";
			push @{$chartdata{METRIC}{$met}{HOURS}{LABLES}},$hour_label;			
			$colorcount++;			
		}
		foreach my $day (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{METRIC}{$met}{DAYS}}){
			$colorcount=0;					
			my $metname=$met;				
			$metname=~s/\\+//g;
			#$metname=~s/system\-cpu\///g;
			push @{$chartdata{METRIC}{$metname}{DAYS}{DATASET}}, $average_data{METRIC}{$met}{DAYS}{$day}{AVERAGE};			
			push @{$chartdata{METRIC}{$metname}{DAYS}{DATASET_ANOM}}, $average_data{METRIC}{$met}{DAYS}{$day}{ANOM_COUNT};			
			push @{$chartdata{METRIC}{$metname}{DAYS}{DATASET_SCORE}}, $average_data{METRIC}{$met}{DAYS}{$day}{AVERAGE_SCORE};			
			$chartdata{METRIC}{$metname}{DAYS}{LABLE}="$met";
			$chartdata{METRIC}{$metname}{DAYS}{COLOUR}=$colorcodes[$colorcount];				
			push @{$chartdata{METRIC}{$metname}{DAYS}{LABLES}},$day;			
			$colorcount++;
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{METRIC}{$met}{MONTHS}}){		
			$colorcount=0;		
			my $metname=$met;				
			$metname=~s/\\+//g;
			#$metname=~s/system\-cpu\///g;
			push @{$chartdata{METRIC}{$metname}{MONTHS}{DATASET}}, $average_data{METRIC}{$met}{MONTHS}{$month}{AVERAGE};			
			push @{$chartdata{METRIC}{$metname}{MONTHS}{DATASET_ANOM}}, $average_data{METRIC}{$met}{MONTHS}{$month}{ANOM_COUNT};
			push @{$chartdata{METRIC}{$metname}{MONTHS}{DATASET_SCORE}}, $average_data{METRIC}{$met}{MONTHS}{$month}{AVERAGE_SCORE};
			$chartdata{METRIC}{$metname}{MONTHS}{LABLE}="$met";
			$chartdata{METRIC}{$metname}{MONTHS}{COLOUR}=$colorcodes[$colorcount];				
			push @{$chartdata{METRIC}{$metname}{MONTHS}{LABLES}},$month;			
			$colorcount++;		
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{METRIC}{$met}{THREEMONTHS}}){		
			$colorcount=0;
			foreach my $met (sort keys %{$average_data{METRIC}{$met}{THREEMONTHS}{$month}}){		
				my $metname=$met;				
				$metname=~s/\\+//g;
				#$metname=~s/system\-cpu\///g;
				push @{$chartdata{METRIC}{$met}{THREEMONTHS}{$metname}{DATASET}}, $average_data{METRIC}{$met}{THREEMONTHS}{$month}{$met}{AVERAGE};			
				push @{$chartdata{METRIC}{$met}{THREEMONTHS}{$metname}{DATASET_ANOM}}, $average_data{METRIC}{$met}{THREEMONTHS}{$month}{$met}{ANOM_COUNT};	
				push @{$chartdata{METRIC}{$met}{THREEMONTHS}{$metname}{DATASET_SCORE}}, $average_data{METRIC}{$met}{THREEMONTHS}{$month}{$met}{AVERAGE_SCORE};
				$chartdata{METRIC}{$met}{THREEMONTHS}{$metname}{LABLE}="$met";
				$chartdata{METRIC}{$met}{THREEMONTHS}{$metname}{COLOUR}=$colorcodes[$colorcount];				
				push @{$chartdata{METRIC}{$met}{THREEMONTHS}{$metname}{LABLES}},$month;			
				$colorcount++;
			}
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{METRIC}{$met}{SIXMONTHS}}){		
			$colorcount=0;		
			my $metname=$met;				
			$metname=~s/\\+//g;
			#$metname=~s/system\-cpu\///g;
			push @{$chartdata{METRIC}{$metname}{SIXMONTHS}{DATASET}}, $average_data{METRIC}{$met}{SIXMONTHS}{$month}{AVERAGE};			
			push @{$chartdata{METRIC}{$metname}{SIXMONTHS}{DATASET_ANOM}}, $average_data{METRIC}{$met}{SIXMONTHS}{$month}{ANOM_COUNT};	
			push @{$chartdata{METRIC}{$metname}{SIXMONTHS}{DATASET_SCORE}}, $average_data{METRIC}{$met}{SIXMONTHS}{$month}{AVERAGE_SCORE};	
			$chartdata{METRIC}{$metname}{SIXMONTHS}{LABLE}="$met";
			$chartdata{METRIC}{$metname}{SIXMONTHS}{COLOUR}=$colorcodes[$colorcount];				
			push @{$chartdata{METRIC}{$metname}{SIXMONTHS}{LABLES}},$month;			
			$colorcount++;			
		}
		foreach my $month (sort {$b <=> $a || $b cmp $a  }  keys %{$average_data{METRIC}{$met}{TWELVEMONTHS}}){		
			$colorcount=0;		
			my $metname=$met;				
			$metname=~s/\\+//g;
			#$metname=~s/system\-cpu\///g;
			push @{$chartdata{METRIC}{$metname}{TWELVEMONTHS}{DATASET}}, $average_data{METRIC}{$met}{TWELVEMONTHS}{$month}{AVERAGE};			
			push @{$chartdata{METRIC}{$metname}{TWELVEMONTHS}{DATASET_ANOM}}, $average_data{METRIC}{$met}{TWELVEMONTHS}{$month}{ANOM_COUNT};	
			push @{$chartdata{METRIC}{$metname}{TWELVEMONTHS}{DATASET_SCORE}}, $average_data{METRIC}{$met}{TWELVEMONTHS}{$month}{AVERAGE_SCORE};
			$chartdata{METRIC}{$metname}{TWELVEMONTHS}{LABLE}="$met";
			$chartdata{METRIC}{$metname}{TWELVEMONTHS}{COLOUR}=$colorcodes[$colorcount];				
			push @{$chartdata{METRIC}{$metname}{TWELVEMONTHS}{LABLES}},$month;			
			$colorcount++;			
		}
	}
	$anomaly{CHARTDATA}=\%chartdata;	
	save_hash("$file_name", \%anomaly,"$cache_dir/by_customer");									
	
	my $file_name = "$account_reg{$customer}{sp_mapping_file}_anomaly_aggregates_30_DAYS";	
	my $sys =  load_cache_byFile("$cache_dir/by_customer/$file_name");
	my %anomaly_30 = %{$sys};
	$anomaly_30{CHARTDATA}=\%chartdata;	
	save_hash("$file_name", \%anomaly_30,"$cache_dir/by_customer");									

}

sub create_anomaly_detail_tables {
	my $customer = shift;
	my %anom_details;
	my $file_name_details = "$account_reg{$customer}{sp_mapping_file}_anomaly_details";
	my $sys =  load_cache_byFile("$cache_dir/l3_cache/by_customer/$file_name_details");
	my %anomaly_details = %{$sys};
	
	my $file_name = "$account_reg{$customer}{sp_mapping_file}_anomaly";
	my $sys =  load_cache_byFile("$cache_dir/l3_cache/by_customer/$file_name");
	my %anomalys = %{$sys};
	
	my @bgcolors=('#ffcccc','#ff9999','#ff6666');
	foreach my $met (sort keys %{$anomaly_details{METRIC}}) {			
		foreach my $fqdn (sort keys %{$anomaly_details{METRIC}{$met}}) {	
			if(scalar(keys %{$anomaly_details{COUNTS}{HOST}{$fqdn}{$met}{TIMES}})>0){
				foreach my $period (keys %{$anomaly_details{COUNTS}{HOST}{$fqdn}{$met}{TIMES}}){					
					next if ($period !~/LAST_30_DAYS|LAST_24_TOTAL/);
					$anom_details{$fqdn}{$met}{$period}= '<table class="anomalyDetailData l3-table" id="anomalyDetailData" >'."\n";
					$anom_details{$fqdn}{$met}{$period}.= '<tr><th colspan=22>Anomaly Detail - '.$met.' on '.$fqdn.'</th></tr>'."\n";
					$anom_details{$fqdn}{$met}{$period}.= '<tr><th rowspan=3>Count</th><th colspan=9>Before</th><th colspan=3>Anomaly</th><th colspan=9>After</th></tr>'."\n";
					
					#$anom_details{$fqdn}{$met}.= '<tr><th colspan=3>1</th><th colspan=3>2</th><th colspan=3>3</th><th colspan=3>4</th><th colspan=3>5</th>'."\n";
					$anom_details{$fqdn}{$met}{$period}.= '<tr><th colspan=3>1</th><th colspan=3>2</th><th colspan=3>3</th>'."\n";
					$anom_details{$fqdn}{$met}{$period}.= '	<th rowspan=2>Score</th><th rowspan=2>Value</th><th rowspan=2>Time</th>'."\n";
					#$anom_details{$fqdn}{$met}.= '<th colspan=3>1</th><th colspan=3>2</th><th colspan=3>3</th><th colspan=3>4</th><th colspan=3>5</th></tr>'."\n";
					$anom_details{$fqdn}{$met}{$period}.= '<th colspan=3>1</th><th colspan=3>2</th><th colspan=3>3</th></tr>'."\n";
					
					$anom_details{$fqdn}{$met}{$period}.= '<tr><th>Score</th><th>Value</th><th>Time</th>'."\n";
					$anom_details{$fqdn}{$met}{$period}.= ' 	 <th>Score</th><th>Value</th><th>Time</th>'."\n";
					$anom_details{$fqdn}{$met}{$period}.= ' 	 <th>Score</th><th>Value</th><th>Time</th>'."\n";
					#$anom_details{$fqdn}{$met}.= ' 	 <th>Score</th><th>Value</th><th>Time</th>'."\n";
					#$anom_details{$fqdn}{$met}.= ' 	 <th>Score</th><th>Value</th><th>Time</th>'."\n";
					$anom_details{$fqdn}{$met}{$period}.= '<th>Score</th><th>Value</th><th>Time</th>'."\n";
					$anom_details{$fqdn}{$met}{$period}.= ' 	 <th>Score</th><th>Value</th><th>Time</th>'."\n";
					$anom_details{$fqdn}{$met}{$period}.= ' 	 <th>Score</th><th>Value</th><th>Time</th>'."\n";
					#$anom_details{$fqdn}{$met}.= ' 	 <th>Score</th><th>Value</th><th>Time</th>'."\n";					
					#$anom_details{$fqdn}{$met}.= ' 	 <th>Score</th><th>Value</th><th>Time</th></tr>'."\n";										
					my $count=1;
					foreach my $anom (@{$anomaly_details{COUNTS}{HOST}{$fqdn}{$met}{TIMES}{$period}}){
						$anom_details{$fqdn}{$met}{$period}.= '<tr><td>'.$count.'</td>';
						my $clr=0;
						foreach my $before_anom (sort {$a<=>$b} keys %{$anom->{FIVE_BEFORE}}){
							$anom_details{$fqdn}{$met}{$period}.= '<td style="background-color:'.$bgcolors[$clr].'">'.sprintf "%.3f",$anom->{FIVE_BEFORE}{$before_anom}{SCORE}.'</td>'."\n";
							$anom_details{$fqdn}{$met}{$period}.= '<td style="background-color:'.$bgcolors[$clr].'">'.sprintf "%.3f",$anom->{FIVE_BEFORE}{$before_anom}{METRIC_VALUE}.'</td>'."\n";
							my $tstamp=$anom->{FIVE_BEFORE}{$before_anom}{TIMESTAMP};
							$tstamp=~s/\.\d\d\d$//;
							$anom_details{$fqdn}{$met}{$period}.= '<td style="background-color:'.$bgcolors[$clr].'">'.$tstamp.'</td>'."\n";
							$clr++;
						}
						$anom_details{$fqdn}{$met}{$period}.= '<td style="background-color:#ff3333">'.sprintf "%.3f",$anom->{SCORE}.'</td>'."\n";
						$anom_details{$fqdn}{$met}{$period}.= '<td style="background-color:#ff3333">'.sprintf "%.3f",$anom->{METRIC_VALUE}.'</td>'."\n";
						my $tstamp=$anom->{TIMESTAMP};
						$tstamp=~s/\.\d\d\d$//;
						$anom_details{$fqdn}{$met}{$period}.= '<td style="background-color:#ff3333">'.$tstamp.'</td>'."\n";					
						($clr)= scalar(@bgcolors)-1;
						foreach my $after_anom (sort {$a<=>$b} keys %{$anom->{FIVE_AFTER}}){
							$anom_details{$fqdn}{$met}{$period}.= '<td style="background-color:'.$bgcolors[$clr].'">'.sprintf "%.3f",$anom->{FIVE_AFTER}{$after_anom}{SCORE}.'</td>'."\n";
							$anom_details{$fqdn}{$met}{$period}.= '<td style="background-color:'.$bgcolors[$clr].'">'.sprintf "%.3f",$anom->{FIVE_AFTER}{$after_anom}{METRIC_VALUE}.'</td>'."\n";
							my $tstamp=$anom->{FIVE_AFTER}{$after_anom}{TIMESTAMP};
							$tstamp=~s/\.\d\d\d$//;
							$anom_details{$fqdn}{$met}{$period}.= '<td style="background-color:'.$bgcolors[$clr].'">'.$tstamp.'</td>'."\n";
							$clr--;
						}
						$anom_details{$fqdn}{$met}{$period}.= '</tr>'."\n";					
						$count++;
					}					
				}
			}
		}
	}
	$anomaly_details{DETAIL_TABLE}=\%anom_details;
	#$anomalys{DETAIL_TABLE}=\%anom_details;
	save_hash("$file_name_details", \%anomaly_details, "$cache_dir/l3_cache/by_customer");
	#save_hash("$file_name", \%anomalys, "$cache_dir/l3_cache/by_customer");
	
}
sub nonesl_account_anomaly {

	my $customer = shift;	
	my %totals_hash;
	my (@cust_list) = split(/\,/,$opts{"c"});
	foreach my $n (@cust_list){
		$n=~s/^\s*//;
		$n=~s/\s*$//;
		undef ($l2_anomaly{CUSTOMER}{$n});
	}
	my %cust_list_hash = map { $_ => 1 } @cust_list;
	my %counted_fqdn;
	my %counted_fqdn_fs;
	my %counted_fqdn_perf;
	my $count=1;
	
	my $file_name = "$account_reg{$customer}{sp_mapping_file}"."_anomaly_aggregates_all";
	#print "Loading $file_name\n";
	my $file_name_details = "$account_reg{$customer}{sp_mapping_file}"."_anomaly_details_all";
	my $sys =  load_cache_byFile("$cache_dir/by_customer/$file_name");
	my $sys_details =  load_cache_byFile("$cache_dir/by_customer/$file_name_details");
	my %anomaly = %{$sys};
	my %anomaly_details = %{$sys_details};
	my $c = 0;		

	my $month_c = POSIX::strftime("%m", localtime time);
	my $month_name_c = $months[$month_c - 1];	
	my $year_c = POSIX::strftime("%Y", localtime time);
	my $current_month_label = sprintf "%s_%s", $month_name_c, $year_c;
	if($month_c - 1==0){
		$month_c=13;
		$year_c--;
	}
	$month_name_c = $months[$month_c - 2];
	my $one_month_ago_label = sprintf "%s_%s", $month_name_c, $year_c;
	if($month_c - 1==0){
		$month_c=13;
		$year_c--;
	}
	$month_name_c = $months[$month_c - 3];
	my $two_month_ago_label = sprintf "%s_%s", $month_name_c, $year_c;
	if($month_c - 1==0){
		$month_c=13;
		$year_c--;
	}
	$month_name_c = $months[$month_c - 4];
	my $three_month_ago_label = sprintf "%s_%s", $month_name_c, $year_c;
	#print "Last Month:$one_month_ago_label Two Months Ago:$two_month_ago_label, Three:$three_month_ago_label\n";	
	my $server_count;
	my $anomserver_count;
	($server_count) = scalar (keys %{$anomaly{DATA}});	
	$totals_hash{device_count}=$server_count;
	($anomserver_count) = scalar (keys %{$anomaly_details{DATA}});	
	
	my $current_tick = time();
	
	my %l3_anomaly;
	my %l3_anomaly_details;
	
	foreach my $fqdn (sort keys %{$anomaly{DATA}}) {
		foreach my $met (keys %{$anomaly{DATA}{$fqdn}}){
			$totals_hash{metric_types}{$met}=1;
			##Count Non Anomalous
			foreach my $hour (sort {$b <=> $a || $b cmp $a  }keys %{$anomaly{DATA}{$fqdn}{$met}}){
				my $last_30=0;
				my $sample_tick = date_to_tick($hour);
				my $date_dif = sprintf "%0.2f", ($current_tick - $sample_tick) / (24 * 60 * 60);
				if ($date_dif <= 30){
					$last_30 =1;
				}
				#print "$hour is $date_dif days ago\n";
				my $last_24=0;
				my $sample_tick = date_to_tick($hour);
				my $date_dif = sprintf "%0.2f", ($current_tick - $sample_tick) / (60 * 60);
				if ($date_dif <= 24){
					$last_24 =1;
				}
				my ($year,$month) = $hour=~m/^(\d\d\d\d)\-(\d\d)\-/;
				my $month_label = $months[$month-1]."_".$year;
				my ($hour_label)	= $hour=~m/^(\d\d\d\d\-\d\d\-\d\d\s\d\d)\:/;
				my ($day_label) 	= $hour=~m/^(\d\d\d\d\-\d\d\-\d\d)\s/;
				#print "LABEL:$month_label for Date:$hour\n";
				my $value;
				$value = $anomaly{DATA}{$fqdn}{$met}{$hour}{COUNT};
				$value = $anomaly{DATA}{$fqdn}{$met}{$hour}{COUNT};
				$totals_hash{NORMAL}{MONTH_COUNT}{$month_label}{$met}++;
				$totals_hash{NORMAL}{MONTH_COUNT}{$month_label}{TOTAL}++;
				$l3_anomaly{COUNTS}{HOST}{$fqdn}{$met}{$month_label}++;
				$l3_anomaly{COUNTS}{HOST_MONTH}{$month_label}{$fqdn}{$met}=1;
				$l3_anomaly{COUNTS}{METRIC}{$met}{$fqdn}{$month_label}++;
				$l3_anomaly{COUNTS}{METRIC_MONTH}{$month_label}{$met}{$fqdn}=1;
				$l3_anomaly{COUNTS}{METRIC}{$met}{TOTAL}{$month_label}++;
				$l3_anomaly{COUNTS}{HOST}{$fqdn}{$met}{$day_label}++;
				$l3_anomaly{COUNTS}{METRIC}{$met}{$fqdn}{$day_label}++;
				$l3_anomaly{COUNTS}{METRIC}{$met}{TOTAL}{$day_label}++;
				#$l3_anomaly{HOST}{$fqdn}{$met}{$hour_label}+=$value;
				#$l3_anomaly{METRIC}{$met}{$fqdn}{$hour_label}+=$value;
				if($last_24==1){
					$totals_hash{NORMAL}{LAST_24_TOTAL}++;
					$totals_hash{NORMAL}{"LAST_24_".$met}++;
					$l3_anomaly{COUNTS}{HOST}{$fqdn}{$met}{LAST_24_TOTAL}++;
					$l3_anomaly{COUNTS}{HOST_MONTH}{LAST_24_TOTAL}{$fqdn}{$met}++;
					$l3_anomaly{COUNTS}{METRIC}{$met}{$fqdn}{LAST_24_TOTAL}++;
					$l3_anomaly{COUNTS}{METRIC_MONTH}{LAST_24_TOTAL}{$met}{$fqdn}=1;
					$l3_anomaly{COUNTS}{METRIC}{$met}{TOTAL}{LAST_24_TOTAL}++;					
				}			
				if($last_30==1){					
					$totals_hash{NORMAL}{LAST_30_DAYS_TOTAL}++;
					$totals_hash{NORMAL}{"LAST_30_DAYS_".$met}++;
					$l3_anomaly{COUNTS}{HOST}{$fqdn}{$met}{LAST_30_DAYS_TOTAL}++;
					$l3_anomaly{COUNTS}{HOST_MONTH}{LAST_30_DAYS_TOTAL}{$fqdn}{$met}++;
					$l3_anomaly{COUNTS}{METRIC}{$met}{$fqdn}{LAST_30_DAYS_TOTAL}++;
					$l3_anomaly{COUNTS}{METRIC_MONTH}{LAST_30_DAYS_TOTAL}{$met}{$fqdn}=1;
					$l3_anomaly{COUNTS}{METRIC}{$met}{TOTAL}{LAST_30_DAYS_TOTAL}++;
				}
				$l3_anomaly{HOST}{$fqdn}{$met}{$hour}=$anomaly{DATA}{$fqdn}{$met}{$hour};			
				$l3_anomaly{METRIC}{$met}{$fqdn}{$hour}=$anomaly{DATA}{$fqdn}{$met}{$hour};			
				$l3_anomaly{METRIC}{$met}{TOTAL}{$hour}=$anomaly{DATA}{$fqdn}{$met}{$hour};			
			}
		}
	}
	
	$l3_anomaly{TOTALS}=\%totals_hash;	
	$l3_anomaly{CHARTDATA}=\%chartdata;	
	my $l3_cache_file=$account_reg{$customer}{sp_mapping_file}."_anomaly";
	save_hash("$l3_cache_file", \%l3_anomaly, "$cache_dir/l3_cache/by_customer");
	
	
	##Count Anomalous
	foreach my $fqdn (sort keys %{$anomaly_details{DATA}}) {
		foreach my $met (keys %{$anomaly_details{DATA}{$fqdn}}){			
			my (@ordered_keys) =sort {$a <=> $b || $a cmp $b  } keys %{$anomaly_details{DATA}{$fqdn}{$met}}; 
			#print Dumper @ordered_keys;
			my %ordered_hours;
			my $hour_count;
			foreach my $x (@ordered_keys){
				$hour_count++;
				$ordered_hours{HOUR}{$x}=$hour_count;
				$ordered_hours{COUNT}{$hour_count}=$x;
			}
			foreach my $hour (sort {$b <=> $a || $b cmp $a  }keys %{$anomaly_details{DATA}{$fqdn}{$met}}){							
				next if($anomaly_details{DATA}{$fqdn}{$met}{$hour}{ANOMALY_FLAG}!=1);
				my %x;								
				$x{TIMESTAMP}=$anomaly_details{DATA}{$fqdn}{$met}{$hour}{TIMESTAMP};
				$x{TIMESTAMP}=~s/\.\d\d\d$//;
				$x{METRIC_VALUE}=sprintf "%0.3f",$anomaly_details{DATA}{$fqdn}{$met}{$hour}{METRIC_VALUE};
				$x{SCORE}=sprintf "%0.3f",$anomaly_details{DATA}{$fqdn}{$met}{$hour}{SCORE};									
				my $five_after=$ordered_hours{HOUR}{$hour}+4;
				my $five_before=($ordered_hours{HOUR}{$hour}-3);
				my $five_count=1;
				for( $a =$five_before; $a < $ordered_hours{HOUR}{$hour}; $a++ ) {	
					if($fqdn eq "927690066914_i-0ada696cf43339ece" and $met eq "system-cpu-m3-CPUUtilization-avg"){				
						#print "ANOMALY:$ordered_hours{HOUR}{$hour} $anomaly_details{DATA}{$fqdn}{$met}{$hour}{TIMESTAMP}  NUMBER $five_count BEFORE($five_before) $a is:".$anomaly_details{DATA}{$fqdn}{$met}{$ordered_hours{COUNT}{$a}}{TIMESTAMP}."\n";
					}
					$x{FIVE_BEFORE}{$five_count}= $anomaly_details{DATA}{$fqdn}{$met}{$ordered_hours{COUNT}{$a}};						
					$five_count++;
				}		
				$five_count=1;			
				for( $a = $ordered_hours{HOUR}{$hour}+1; $a < $five_after; $a++ ) {					
					#print "AFTER($five_after) $a ".$anomaly_details{DATA}{$fqdn}{$met}{$ordered_hours{COUNT}{$a}}."\n";
					if($fqdn eq "927690066914_i-0ada696cf43339ece" and $met eq "system-cpu-m3-CPUUtilization-avg"){				
						#print "ANOMALY:$ordered_hours{HOUR}{$hour} $anomaly_details{DATA}{$fqdn}{$met}{$hour}{TIMESTAMP} NUMBER $five_count AFTER($five_after) $a is:".$anomaly_details{DATA}{$fqdn}{$met}{$ordered_hours{COUNT}{$a}}{TIMESTAMP}."\n";
					}
					$x{FIVE_AFTER}{$five_count}= $anomaly_details{DATA}{$fqdn}{$met}{$ordered_hours{COUNT}{$a}};						
					$five_count++;
				}
								
				my $last_30=0;
				my $sample_tick = date_to_tick($hour);
				my $date_dif = sprintf "%0.2f", ($current_tick - $sample_tick) / (24 * 60 * 60);
				if ($date_dif <= 30){
					$last_30 =1;
					#print "$hour is $date_dif days ago\n";
				}
				my $last_24=0;
				my $sample_tick = date_to_tick($hour);
				my $date_dif = sprintf "%0.2f", ($current_tick - $sample_tick) / (60 * 60);
				if ($date_dif <= 24){
					$last_24 =1;
				}
				my ($year,$month) = $hour=~m/^(\d\d\d\d)\-(\d\d)\-/;				
				#my $year="2019";
				#my $month=9;
				my $month_label = $months[$month-1]."_".$year;
				my ($hour_label)	= $hour=~m/^(\d\d\d\d\-\d\d\-\d\d\s\d\d)\:/;
				my ($day_label) 	= $hour=~m/^(\d\d\d\d\-\d\d\-\d\d)\s/;
				my $value= $anomaly_details{DATA}{$fqdn}{$met}{$hour}{COUNT};
				#$last_30=1;
				#print "ANOMALY TOTAL: $totals_hash{ANOMALY}{MONTH_COUNT}{$month_label}{$met} Lable:$month_label Met:$met FQDN:$fqdn Hour:$hour\n";
				$totals_hash{ANOMALY}{MONTH_COUNT}{$month_label}{$met}+=$value;
				$totals_hash{ANOMALY}{MONTH_COUNT}{$month_label}{TOTAL}+=$value;
				$totals_hash{anom_metric_types}{$month_label}{$met}=1;
				
				$l3_anomaly_details{COUNTS}{HOST}{$fqdn}{$met}{$month_label}+=$value;				
				$l3_anomaly_details{COUNTS}{HOST_MONTH}{$month_label}{$fqdn}{$met}+=$value;				
				
				push @{$l3_anomaly_details{COUNTS}{HOST}{$fqdn}{$met}{TIMES}{$month_label}}, \%x;	
				$l3_anomaly_details{COUNTS}{METRIC}{$met}{$fqdn}{$month_label}+=$value;	
				$l3_anomaly_details{COUNTS}{METRIC_MONTH}{$month_label}{$met}{$fqdn}+=$value;	
				$l3_anomaly_details{COUNTS}{METRIC}{$met}{TOTAL}{$month_label}+=$value;	
				$l3_anomaly_details{COUNTS}{METRIC_MONTH}{$month_label}{$met}{TOTAL}+=$value;	
				push @{$l3_anomaly_details{COUNTS}{METRIC}{$met}{TIMES}{$month_label}}, \%x;		
				$l3_anomaly_details{COUNTS}{HOST}{$fqdn}{$met}{$day_label}+=$value;				
				push @{$l3_anomaly_details{COUNTS}{HOST}{$fqdn}{$met}{TIMES}{$day_label}}, \%x;		
				$l3_anomaly_details{COUNTS}{METRIC}{$met}{$fqdn}{$day_label}+=$value;	
				$l3_anomaly_details{COUNTS}{METRIC}{$met}{TOTAL}{$day_label}+=$value;					
				push @{$l3_anomaly_details{COUNTS}{METRIC}{$met}{TIMES}{$day_label}}, \%x;		
				#$l3_anomaly_details{HOST}{$fqdn}{$met}{$hour_label}++;				
				#$l3_anomaly_details{METRIC}{$met}{$fqdn}{$hour_label}++;	
				if($last_24==1){
					$totals_hash{ANOMALY}{"LAST_24_".$met}+=$value;
					$totals_hash{ANOMALY}{LAST_24_TOTAL}++;
					$totals_hash{anom_metric_types}{LAST_24_HOURS}{$met}=1;
					$l3_anomaly_details{COUNTS}{HOST}{$fqdn}{$met}{LAST_24_TOTAL}+=$value;
					$l3_anomaly_details{COUNTS}{HOST_MONTH}{LAST_24_TOTAL}{$fqdn}{$met}+=$value;
					push @{$l3_anomaly_details{COUNTS}{HOST}{$fqdn}{$met}{TIMES}{LAST_24_TOTAL}}, \%x;		
					$l3_anomaly_details{COUNTS}{METRIC}{$met}{$fqdn}{LAST_24_TOTAL}+=$value;			
					$l3_anomaly_details{COUNTS}{METRIC_MONTH}{LAST_24_TOTAL}{$met}{$fqdn}+=$value;			
					$l3_anomaly_details{COUNTS}{METRIC}{$met}{TOTAL}{LAST_24_TOTAL}+=$value;			
					$l3_anomaly_details{COUNTS}{METRIC_MONTH}{LAST_24_TOTAL}{$met}{TOTAL}+=$value;
					push @{$l3_anomaly_details{COUNTS}{METRIC}{$met}{TIMES}{LAST_24_TOTAL}}, \%x;		
				}
				if($last_30==1){
					$totals_hash{ANOMALY}{"LAST_30_DAYS_".$met}+=$value;
					$totals_hash{ANOMALY}{LAST_30_DAYS_TOTAL}+=$value;	
					$totals_hash{anom_metric_types}{LAST_30_DAYS}{$met}=1;
					$totals_hash{anom_device_count}{LAST_30_DAYS}{$fqdn}=1;
					$l3_anomaly_details{COUNTS}{HOST}{$fqdn}{$met}{LAST_30_DAYS_TOTAL}+=$value;			
					$l3_anomaly_details{COUNTS}{HOST_MONTH}{LAST_30_DAYS_TOTAL}{$fqdn}{$met}+=$value;	
					print "Pushing $x{TIMESTAMP}\n"		if($fqdn eq "927690066914_i-0ada696cf43339ece" and $met eq "system-network-m1-NetworkIn-avg");
					push @{$l3_anomaly_details{COUNTS}{HOST}{$fqdn}{$met}{TIMES}{LAST_30_DAYS_TOTAL}}, \%x;		
					$l3_anomaly_details{COUNTS}{METRIC}{$met}{$fqdn}{LAST_30_DAYS_TOTAL}+=$value;			
					$l3_anomaly_details{COUNTS}{METRIC_MONTH}{LAST_30_DAYS_TOTAL}{$met}{$fqdn}+=$value;			
					$l3_anomaly_details{COUNTS}{METRIC}{$met}{TOTAL}{LAST_30_DAYS_TOTAL}+=$value;			
					$l3_anomaly_details{COUNTS}{METRIC_MONTH}{LAST_30_DAYS_TOTAL}{$met}{TOTAL}+=$value;			
					push @{$l3_anomaly_details{COUNTS}{METRIC}{$met}{TIMES}{LAST_30_DAYS_TOTAL}}, \%x;		
				}
				#print "LAST30ANOM: $totals_hash{ANOMALY}{LAST_30_DAYS_TOTAL}\n";
				$l3_anomaly_details{HOST}{$fqdn}{$met}{$hour}=$anomaly_details{DATA}{$fqdn}{$met}{$hour};			
				push @{$l3_anomaly_details{COUNTS}{HOST}{$fqdn}{$met}{TIMES}{$hour}}, \%x;		
				$l3_anomaly_details{METRIC}{$met}{$fqdn}{$hour}=$anomaly_details{DATA}{$fqdn}{$met}{$hour};			
				$l3_anomaly_details{METRIC}{$met}{TOTAL}{$hour}=$anomaly_details{DATA}{$fqdn}{$met}{$hour};			
				push @{$l3_anomaly_details{COUNTS}{METRIC}{$met}{TIMES}{$hour}}, \%x;		
								
			}
		}
	}	
	$l3_anomaly_details{TOTALS}=\%totals_hash;	
	$l3_anomaly_details{CHARTDATA}=\%chartdata;		
	my $l3_cache_file=$account_reg{$customer}{sp_mapping_file}."_anomaly_details";
	save_hash("$l3_cache_file", \%l3_anomaly_details, "$cache_dir/l3_cache/by_customer");
	
	foreach my $owner ('ALL','OWNER','SSN','ESO4SAP_OWNED','ESO4SAP_USES') {		
		my $system_type = "server";
		my $status = "in production";
		my $impact = "";
		my $eol_status = "";
		my $owner_flag = "1";
		my $ssn_flag = "1";
		my $eso_flag = "1";						
		my $kpe_name = "";		
		my $service_level = "";
		my %kpe_list;								
		next if ($system_type !~ /server|cluster node/i);
		next if ($owner eq "OWNER" and $owner_flag == 0);
		next if ($owner eq "SSN" and ($owner_flag == 0 or $ssn_flag == 0));
		next if ($owner eq "ESO4SAP_OWNED" and ($owner_flag == 0 or $eso_flag == 0));
		next if ($owner eq "ESO4SAP_USES" and ($owner_flag == 1 or $eso_flag == 0));
		my $tax_cap = "windows";
		my $mapping;
		my %teams;
		my %capability;
		$capability{ALL}=1;
		$capability{$tax_cap} = 1;
		$teams{ALL} = 1;																		
			
			foreach my $cap (keys %capability) {
				foreach my $team (keys %teams) {
					# Save Baseline
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{COUNT} = $server_count;
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{COUNT} = $server_count;
					#Calculate the ETP
					if ($service_level =~ /hosting only|not supported/i ) {
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOMALY_ETP}{VALUE}++;
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOMALY_ETP}{HTML} = "<a href=\"$drilldown_dir/eslSystemCI.pl?customer=$customer&status=$status&system_type=server_and_node&capability=$cap&center=ALL&owner_flag=$owner&team=$team&eol_status=$eol_status&etp=all\">$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{PERC_INC_ETP}{VALUE}</a>";
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOMALY_ETP}{VALUE}++;
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOMALY_ETP}{HTML} = "<a href=\"$drilldown_dir/eslSystemCI.pl?customer=$customer&status=$status&system_type=server_and_node&capability=$cap&center=ALL&owner_flag=$owner&team=$team&eol_status=ALL&etp=all\">$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOMALY_ETP}{VALUE}</a>";
						next;
					}
					#Eligible CI
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOMALY_ELIGIBLE}{VALUE}++;
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOMALY_ELIGIBLE}{HTML} = $totals_hash{device_count};
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOMALY_ELIGIBLE}{VALUE}++;
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOMALY_ELIGIBLE}{HTML} = $totals_hash{device_count};
					
					##Create L2 Values										
					($l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{METRIC_TYPES}{VALUE})=scalar(keys %{$totals_hash{metric_types}});
					($l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOM_METRIC_TYPES}{VALUE})=scalar(keys %{$totals_hash{anom_metric_types}{LAST_30_DAYS}});
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{DEVICES}{VALUE}=$totals_hash{device_count};
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOM_DEVICES}{VALUE}=scalar(keys %{$totals_hash{anom_device_count}{LAST_30_DAYS}});
					($l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{METRIC_TYPES}{VALUE})=scalar(keys %{$totals_hash{metric_types}});
					($l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOM_METRIC_TYPES}{VALUE})=scalar(keys %{$totals_hash{anom_metric_types}{LAST_30_DAYS}});
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{DEVICES}{VALUE}=$totals_hash{device_count};
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOM_DEVICES}{VALUE}=scalar(keys %{$totals_hash{anom_device_count}{LAST_30_DAYS}});
					
					($l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{METRIC_TYPES}{HTML})="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=METRIC&month=TOTAL\">".scalar(keys %{$totals_hash{metric_types}})."</a>";
					($l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOM_METRIC_TYPES}{HTML})="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=METRIC&month=TOTAL\">".scalar(keys %{$totals_hash{anom_metric_types}{LAST_30_DAYS}})."</a>";
					($l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOM_METRIC_TYPES}{HTML})=0 if(scalar(keys %{$totals_hash{anom_metric_types}{LAST_30_DAYS}})<1) ;
					($l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOM_METRIC_TYPES}{COLOR})="red" if(scalar(keys %{$totals_hash{anom_metric_types}{LAST_30_DAYS}})>0) ;
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{DEVICES}{HTML}=$totals_hash{device_count};
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOM_DEVICES}{HTML}="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=HOST&month=TOTAL&report_view=DEVICE\">".scalar(keys %{$totals_hash{anom_device_count}{LAST_30_DAYS}})."</a>";
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOM_DEVICES}{HTML}=0 if(scalar(keys %{$totals_hash{anom_device_count}{LAST_30_DAYS}})<1) ;
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOM_DEVICES}{COLOR}="red" if(scalar(keys %{$totals_hash{anom_device_count}{LAST_30_DAYS}})>0) ;
					($l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{METRIC_TYPES}{HTML})="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=METRIC&month=TOTAL\">".scalar(keys %{$totals_hash{metric_types}})."</a>";
					($l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOM_METRIC_TYPES}{HTML})="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=METRIC&month=TOTAL\">".scalar(keys %{$totals_hash{anom_metric_types}{LAST_30_DAYS}})."</a>";
					($l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOM_METRIC_TYPES}{HTML})=0 if(scalar(keys %{$totals_hash{anom_metric_types}{LAST_30_DAYS}})<1) ;
					($l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOM_METRIC_TYPES}{COLOR})="red" if(scalar(keys %{$totals_hash{anom_metric_types}{LAST_30_DAYS}})>0) ;
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{DEVICES}{HTML}=$totals_hash{device_count};
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOM_DEVICES}{HTML}="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=HOST&month=TOTAL&report_view=DEVICE\">".scalar(keys %{$totals_hash{anom_device_count}{LAST_30_DAYS}})."</a>";
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOM_DEVICES}{HTML}=0 if(scalar(keys %{$totals_hash{anom_device_count}{LAST_30_DAYS}})<1) ;
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOM_DEVICES}{COLOR}="red" if(scalar(keys %{$totals_hash{anom_device_count}{LAST_30_DAYS}})>0) ;
					
					foreach my $mon (keys %{$totals_hash{NORMAL}{MONTH_COUNT}}){												
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{"NORMAL_".$mon}{VALUE}=$totals_hash{NORMAL}{MONTH_COUNT}{$mon}{TOTAL};						
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NORMAL_LAST_MONTH}{VALUE}=$totals_hash{NORMAL}{MONTH_COUNT}{$mon}{TOTAL} if ($mon eq "$one_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NORMAL_TWO_MONTH_AGO}{VALUE}=$totals_hash{NORMAL}{MONTH_COUNT}{$mon}{TOTAL} if ($mon eq "$two_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NORMAL_THREE_MONTH_AGO}{VALUE}=$totals_hash{NORMAL}{MONTH_COUNT}{$mon}{TOTAL} if ($mon eq "$three_month_ago_label");
						
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{"NORMAL_".$mon}{HTML}=int($totals_hash{NORMAL}{MONTH_COUNT}{$mon}{TOTAL}+0.5);						
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NORMAL_LAST_MONTH}{HTML}=int($totals_hash{NORMAL}{MONTH_COUNT}{$mon}{TOTAL}+0.5) if ($mon eq "$one_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NORMAL_TWO_MONTH_AGO}{HTML}=int($totals_hash{NORMAL}{MONTH_COUNT}{$mon}{TOTAL}+0.5) if ($mon eq "$two_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NORMAL_THREE_MONTH_AGO}{HTML}=int($totals_hash{NORMAL}{MONTH_COUNT}{$mon}{TOTAL}+0.5) if ($mon eq "$three_month_ago_label");
						
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{"NORMAL_".$mon}{VALUE}=$totals_hash{NORMAL}{MONTH_COUNT}{$mon}{TOTAL};						
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NORMAL_LAST_MONTH}{VALUE}=$totals_hash{NORMAL}{MONTH_COUNT}{$mon}{TOTAL} if ($mon eq "$one_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NORMAL_TWO_MONTH_AGO}{VALUE}=$totals_hash{NORMAL}{MONTH_COUNT}{$mon}{TOTAL} if ($mon eq "$two_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NORMAL_THREE_MONTH_AGO}{VALUE}=$totals_hash{NORMAL}{MONTH_COUNT}{$mon}{TOTAL} if ($mon eq "$three_month_ago_label");
						
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{"NORMAL_".$mon}{HTML}=int($totals_hash{NORMAL}{MONTH_COUNT}{$mon}{TOTAL}+0.5);						
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NORMAL_LAST_MONTH}{HTML}=int($totals_hash{NORMAL}{MONTH_COUNT}{$mon}{TOTAL}+0.5) if ($mon eq "$one_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NORMAL_TWO_MONTH_AGO}{HTML}=int($totals_hash{NORMAL}{MONTH_COUNT}{$mon}{TOTAL}+0.5) if ($mon eq "$two_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NORMAL_THREE_MONTH_AGO}{HTML}=int($totals_hash{NORMAL}{MONTH_COUNT}{$mon}{TOTAL} +0.5)if ($mon eq "$three_month_ago_label");
					}					
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NORMAL_LAST24_HOURS}{VALUE}=$totals_hash{NORMAL}{LAST_24_TOTAL};
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NORMAL_LAST24_HOURS}{VALUE}=$totals_hash{NORMAL}{LAST_24_TOTAL};
					
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NORMAL_LAST_30_DAYS}{VALUE}=$totals_hash{NORMAL}{LAST_30_DAYS_TOTAL};
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NORMAL_LAST_30_DAYS}{VALUE}=$totals_hash{NORMAL}{LAST_30_DAYS_TOTAL};
					
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NORMAL_LAST24_HOURS}{HTML}=int($totals_hash{NORMAL}{LAST_24_TOTAL}+0.5);
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NORMAL_LAST24_HOURS}{HTML}=int($totals_hash{NORMAL}{LAST_24_TOTAL}+0.5);
					
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{NORMAL_LAST_30_DAYS}{HTML}=int($totals_hash{NORMAL}{LAST_30_DAYS_TOTAL}+0.5);
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{NORMAL_LAST_30_DAYS}{HTML}=int($totals_hash{NORMAL}{LAST_30_DAYS_TOTAL}+0.5);
					
					foreach my $mon (keys %{$totals_hash{ANOMALY}{MONTH_COUNT}}){
						my $ratio = sprintf "%.3f",$totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL}/$totals_hash{device_count}if($totals_hash{device_count}>0);
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{"RATIO_".$mon}{VALUE}=$ratio;
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{"ANOMALY_".$mon}{VALUE}=$totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL};
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOMALY_LAST_MONTH}{VALUE}=$totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL} if ($mon eq "$one_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOMALY_TWO_MONTH_AGO}{VALUE}=$totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL}  if ($mon eq "$two_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOMALY_THREE_MONTH_AGO}{VALUE}=$totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL}  if ($mon eq "$three_month_ago_label");
						
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{"RATIO_".$mon}{HTML}="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=HOST&month=$mon&report_view=ANOMALY\">".$ratio."</a>";
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{"RATIO_".$mon}{HTML}=0 if (!$ratio);
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{"RATIO_".$mon}{COLOR}="green";
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{"RATIO_".$mon}{COLOR}="amber" if ($ratio>2.5);
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{"RATIO_".$mon}{COLOR}="red" if ($ratio>5);
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{"ANOMALY_".$mon}{HTML}="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=HOST&month=$mon&report_view=ANOMALY\">".$totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL}."</a>";
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{"ANOMALY_".$mon}{HTML}=0 if ($totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL}<1);
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{"ANOMALY_".$mon}{COLOR}="red" if ($totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL}>0);
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{RATIO_LAST_MONTH}{HTML}="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=HOST&month=$one_month_ago_label&report_view=ANOMALY\">".$ratio."</a>" if ($mon eq "$one_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{RATIO_LAST_MONTH}{HTML}="No Data" if (!$ratio and $mon eq "$one_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{RATIO_LAST_MONTH}{COLOR}="green" if ($mon eq "$one_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{RATIO_LAST_MONTH}{COLOR}="amber" if ($ratio>2.5 and $mon eq "$one_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{RATIO_LAST_MONTH}{COLOR}="red" if ($ratio>5 and $mon eq "$one_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{RATIO_TWO_MONTH_AGO}{HTML}="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=HOST&month=$two_month_ago_label&report_view=ANOMALY\">".$ratio."</a>" if ($mon eq "$two_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{RATIO_TWO_MONTH_AGO}{HTML}=0 if (!$ratio and $mon eq "$two_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{RATIO_TWO_MONTH_AGO}{COLOR}="green" if ($mon eq "$two_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{RATIO_TWO_MONTH_AGO}{COLOR}="amber" if ($ratio>2.5 and $mon eq "$two_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{RATIO_TWO_MONTH_AGO}{COLOR}="red" if ($ratio>5 and $mon eq "$two_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{RATIO_THREE_MONTH_AGO}{HTML}="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=HOST&month=$three_month_ago_label&report_view=ANOMALY\">".$ratio."</a>" if ($mon eq "$three_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{RATIO_THREE_MONTH_AGO}{HTML}=0 if (!$ratio and $mon eq "$three_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{RATIO_THREE_MONTH_AGO}{COLOR}="green" if ( $mon eq "$three_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{RATIO_THREE_MONTH_AGO}{COLOR}="amber" if ($ratio>2.5 and $mon eq "$three_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{RATIO_THREE_MONTH_AGO}{COLOR}="red" if ($ratio>5 and $mon eq "$three_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOMALY_LAST_MONTH}{HTML}="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=HOST&month=$one_month_ago_label&report_view=ANOMALY\">".$totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL}."</a>" if ($mon eq "$one_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOMALY_LAST_MONTH}{HTML}=0 if ($totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL}<1 and $mon eq "$one_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOMALY_LAST_MONTH}{COLOR}="red" if ($totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL}>0 and $mon eq "$one_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOMALY_TWO_MONTH_AGO}{HTML}="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=HOST&month=$two_month_ago_label&report_view=ANOMALY\">".$totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL}."</a>" if ($mon eq "$two_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOMALY_TWO_MONTH_AGO}{HTML}=0 if ($totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL}<1 and $mon eq "$two_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOMALY_TWO_MONTH_AGO}{COLOR}="red" if ($totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL}>0 and $mon eq "$two_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOMALY_THREE_MONTH_AGO}{HTML}="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=HOST&month=$three_month_ago_label&report_view=ANOMALY\">".$totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL}."</a>" if ($mon eq "$three_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOMALY_THREE_MONTH_AGO}{HTML}=0 if ($totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL}<1 and $mon eq "$three_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOMALY_THREE_MONTH_AGO}{COLOR}="red" if ($totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL}>0 and $mon eq "$three_month_ago_label");
						
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{"RATIO_".$mon}{VALUE}=$ratio;
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{"ANOMALY_".$mon}{VALUE}=$totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL};
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_LAST_MONTH}{VALUE}=$ratio if ($mon eq "$one_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_TWO_MONTH_AGO}{VALUE}=$ratio if ($mon eq "$two_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_THREE_MONTH_AGO}{VALUE}=$ratio if ($mon eq "$three_month_ago_label");						
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOMALY_LAST_MONTH}{VALUE}=$totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL} if ($mon eq "$one_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOMALY_TWO_MONTH_AGO}{VALUE}=$totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL} if ($mon eq "$two_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOMALY_THREE_MONTH_AGO}{VALUE}=$totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL} if ($mon eq "$three_month_ago_label");						
						
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{"RATIO_".$mon}{HTML}="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=HOST&month=$mon&report_view=ANOMALY\">".$ratio."</a>";
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{"RATIO_".$mon}{HTML}=0 if (!$ratio);
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{"RATIO_".$mon}{COLOR}="green";
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{"RATIO_".$mon}{COLOR}="amber" if ($ratio>2.5);
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{"RATIO_".$mon}{COLOR}="red" if ($ratio>5);
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{"ANOMALY_".$mon}{HTML}="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=HOST&month=$mon&report_view=ANOMALY\">".$totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL}."</a>";
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{"ANOMALY_".$mon}{COLOR}="red" if ($totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL}>0);
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_LAST_MONTH}{HTML}="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=HOST&month=$one_month_ago_label&report_view=ANOMALY\">".$ratio."</a>" if ($mon eq "$one_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_LAST_MONTH}{HTML}="No Data" if (!$ratio and $mon eq "$one_month_ago_label");
						#print "Mpnths: Two:$two_month_ago_label Three:$three_month_ago_label MON:$mon\n";
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_LAST_MONTH}{COLOR}="green" if ($mon eq "$one_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_LAST_MONTH}{COLOR}="amber" if ($ratio>2.5 and $mon eq "$one_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_LAST_MONTH}{COLOR}="red" if ($ratio>5 and $mon eq "$one_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_TWO_MONTH_AGO}{HTML}="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=HOST&month=$two_month_ago_label&report_view=ANOMALY\">".$ratio."</a>" if ($mon eq "$two_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_TWO_MONTH_AGO}{HTML}=0 if (!$ratio and $mon eq "$two_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_TWO_MONTH_AGO}{COLOR}="green" if ($mon eq "$two_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_TWO_MONTH_AGO}{COLOR}="amber" if ($ratio>2.5 and $mon eq "$two_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_TWO_MONTH_AGO}{COLOR}="red" if ($ratio>5 and $mon eq "$two_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_THREE_MONTH_AGO}{HTML}="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=HOST&month=$three_month_ago_label&report_view=ANOMALY\">".$ratio."</a>" if ($mon eq "$three_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_THREE_MONTH_AGO}{HTML}=0 if (!$ratio and $mon eq "$three_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_THREE_MONTH_AGO}{COLOR}="green" if ( $mon eq "$three_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_THREE_MONTH_AGO}{COLOR}="amber" if ($ratio>2.5 and $mon eq "$three_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_THREE_MONTH_AGO}{COLOR}="red" if ($ratio>5 and $mon eq "$three_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOMALY_LAST_MONTH}{HTML}="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=HOST&month=$one_month_ago_label&report_view=ANOMALY\">".$totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL}."</a>" if ($mon eq "$one_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOMALY_LAST_MONTH}{HTML}=0 if ($totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL}<1 and $mon eq "$one_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOMALY_LAST_MONTH}{COLOR}="red" if ($totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL}>0 and $mon eq "$one_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOMALY_TWO_MONTH_AGO}{HTML}="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=HOST&month=$two_month_ago_label&report_view=ANOMALY\">".$totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL}."</a>" if ($mon eq "$two_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOMALY_TWO_MONTH_AGO}{HTML}=0 if ($totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL}<1 and $mon eq "$two_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOMALY_TWO_MONTH_AGO}{COLOR}="red" if ($totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL}>0 and $mon eq "$two_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOMALY_THREE_MONTH_AGO}{HTML}="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=HOST&month=$three_month_ago_label&report_view=ANOMALY\">".$totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL}."</a>" if ($mon eq "$three_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOMALY_THREE_MONTH_AGO}{HTML}=0 if ($totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL}<1 and $mon eq "$three_month_ago_label");
						$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOMALY_THREE_MONTH_AGO}{COLOR}="red" if ($totals_hash{ANOMALY}{MONTH_COUNT}{$mon}{TOTAL}>0 and $mon eq "$three_month_ago_label");
					}
					my $ratio = sprintf "%.3f",$totals_hash{ANOMALY}{LAST_24_TOTAL}/$totals_hash{device_count}if ($totals_hash{device_count}>0);
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{RATIO_LAST24_HOURS}{VALUE}=$ratio;
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_LAST24_HOURS}{VALUE}=$ratio;
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOMALY_LAST24_HOURS}{VALUE}=$totals_hash{ANOMALY}{LAST_24_TOTAL};
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOMALY_LAST24_HOURS}{VALUE}=$totals_hash{ANOMALY}{LAST_24_TOTAL};
					
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{RATIO_LAST24_HOURS}{HTML}="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=HOST&month=LAST_24_TOTAL&report_view=ANOMALY\">".$ratio."</a>";
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{RATIO_LAST24_HOURS}{HTML}=0 if (!$ratio);
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{RATIO_LAST24_HOURS}{COLOR}="green";
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{RATIO_LAST24_HOURS}{COLOR}="amber" if ($ratio>2.5);
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{RATIO_LAST24_HOURS}{COLOR}="red" if ($ratio>5);
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_LAST24_HOURS}{HTML}="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=HOST&month=LAST_24_TOTAL&report_view=ANOMALY\">".$ratio."</a>";
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_LAST24_HOURS}{HTML}=0 if (!$ratio);
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_LAST24_HOURS}{COLOR}="green";
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_LAST24_HOURS}{COLOR}="amber" if ($ratio>2.5);
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_LAST24_HOURS}{COLOR}="red" if ($ratio>5);
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOMALY_LAST24_HOURS}{HTML}="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=HOST&month=LAST_24_TOTAL&report_view=ANOMALY\">".int($totals_hash{ANOMALY}{LAST_24_TOTAL}+0.5)."</a>";
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOMALY_LAST24_HOURS}{HTML}=0 if ($totals_hash{ANOMALY}{LAST_24_TOTAL}<1);
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOMALY_LAST24_HOURS}{COLOR}="red" if ($totals_hash{ANOMALY}{LAST_24_TOTAL}>0);
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOMALY_LAST24_HOURS}{HTML}="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=HOST&month=LAST_24_TOTAL&report_view=ANOMALY\">".int($totals_hash{ANOMALY}{LAST_24_TOTAL}+0.5)."</a>";
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOMALY_LAST24_HOURS}{HTML}=0  if ($totals_hash{ANOMALY}{LAST_24_TOTAL}<1);
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOMALY_LAST24_HOURS}{COLOR}="red" if ($totals_hash{ANOMALY}{LAST_24_TOTAL}>0);															
					
					my $ratio = sprintf "%.3f",$totals_hash{ANOMALY}{LAST_30_DAYS_TOTAL}/$totals_hash{device_count} if($totals_hash{device_count}>0);
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{RATIO_LAST_30_DAYS}{VALUE}=$ratio;
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_LAST_30_DAYS}{VALUE}=$ratio;
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOMALY_LAST_30_DAYS}{VALUE}=$totals_hash{ANOMALY}{LAST_30_DAYS_TOTAL};
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOMALY_LAST_30_DAYS}{VALUE}=$totals_hash{ANOMALY}{LAST_30_DAYS_TOTAL};										
					
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{RATIO_LAST_30_DAYS}{HTML}="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=HOST&month=LAST_30_DAYS_TOTAL&report_view=ANOMALY\">".$ratio."</a>";
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{RATIO_LAST_30_DAYS}{HTML}=0 if (!$ratio);
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{RATIO_LAST_30_DAYS}{COLOR}="green";
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{RATIO_LAST_30_DAYS}{COLOR}="amber" if ($ratio>2.5);
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{RATIO_LAST_30_DAYS}{COLOR}="red" if ($ratio>5);					
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_LAST_30_DAYS}{HTML}="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=HOST&month=LAST_30_DAYS_TOTAL&report_view=ANOMALY\">".$ratio."</a>";
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_LAST_30_DAYS}{HTML}=0 if (!$ratio);
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_LAST_30_DAYS}{COLOR}="green";
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_LAST_30_DAYS}{COLOR}="amber" if ($ratio>2.5);
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{RATIO_LAST_30_DAYS}{COLOR}="red" if ($ratio>5);					
					#print "BEFOREINT:$totals_hash{ANOMALY}{LAST_30_DAYS_TOTAL}\n";
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOMALY_LAST_30_DAYS}{HTML}="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=HOST&month=LAST_30_DAYS_TOTAL&report_view=ANOMALY\">".int($totals_hash{ANOMALY}{LAST_30_DAYS_TOTAL}+0.5)."</a>";					
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOMALY_LAST_30_DAYS}{HTML}=0 if ($totals_hash{ANOMALY}{LAST_30_DAYS_TOTAL}<1);
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOMALY_LAST_30_DAYS}{COLOR}="red" if ($totals_hash{ANOMALY}{LAST_30_DAYS_TOTAL}>0);
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOMALY_LAST_30_DAYS}{HTML}="<a href=\"$drilldown_dir/l3_anomaly.pl?customer=$customer&report_type=HOST&month=LAST_30_DAYS_TOTAL&report_view=ANOMALY\">".int($totals_hash{ANOMALY}{LAST_30_DAYS_TOTAL}+0.5)."</a>";
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOMALY_LAST_30_DAYS}{HTML}=0 if ($totals_hash{ANOMALY}{LAST_30_DAYS_TOTAL}<1);
					$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{ALL}{OWNER}{$owner}{ANOMALY_LAST_30_DAYS}{COLOR}="red" if ($totals_hash{ANOMALY}{LAST_30_DAYS_TOTAL}>0);
					#print "ANOMALY LAST 30 DAYS:$totals_hash{ANOMALY}{LAST_30_DAYS_TOTAL}\nHTML:$l2_anomaly{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{TEAM}{$team}{STATUS}{$status}{EOL_STATUS}{$eol_status}{OWNER}{$owner}{ANOMALY_LAST_30_DAYS}{HTML}\n";					
					$count++;
				}
			}
		}
}





