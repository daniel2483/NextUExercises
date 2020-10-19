#!/usr/bin/perl
#@(#)Description: Sharepoint Extractor Script
#@(#)Operations Services, Hewlett Packard
#@(#)$Revision$
#@(#)$Header$
#@(#)$Date$
#@(#)$Name$
#@(#)$Author$
#
###############################################################################
##########################     MODIFICATION HISTORY     #######################
#
# ENGINEER NAME       DATE              DESCRIPTION
# ----------------    ----              -----------
# Ross Graham         1/01/2015       Initial release
# Srini Rao           10/02/2015      Multiple new lists added
#
###############################################################################
# Description
# Script extracts contents of multiple sharepoint lists into cache files

use strict;


use Data::Dumper;

use lib '/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/modules/pm';
use LoadCache;
use CommonFunctions;


use LoadCache;
use CommonFunctions;
use FileHandle;
use Sys::Hostname;
use File::Basename;
use File::Temp "tempfile";
use Time::Local;
use Getopt::Std;
use POSIX qw( mktime );

my %num2mon = qw(	01 JAN  02 FEB  03 MAR  04 APR  05 MAY  06 JUN
	07 JUL  08 AUG  09 SEP  10 OCT 11 NOV 12 DEC);
my %server_capacity;
my %server_memcpu;
my @proc_months;

use vars qw($rawdata_dir);
my $current_tick = time();

my @list = ('account_reg');
my %cache = load_cache(\@list);
my %account_reg = %{$cache{account_reg}};




sub get_server_capacity
{
	my %not_mapped;
	my $customer;
	my %cached_company;
	my %cached_fqdns;
	my @extra_months;

	foreach my $proc_month (@proc_months) {
		my $raw_file = "$rawdata_dir/aws.ci_res_metric_".$proc_month;
		if (-r $raw_file) {
			open(RAW,$raw_file) or die $!;

			print "Processing Server Capacity data from $raw_file\n";

			my @rows;
			my $count = 0;
			while (<RAW>)
			{
				my $ln = $_;
				chomp($ln);
				next if ($ln =~ /^\s*$/);
				push @rows, $ln;
			}

			my $total_count = scalar(@rows);

			foreach my $ln (@rows) {
				# Prevent reading the first line
				next if ($ln =~/\"ci_alias_nm\"\,\"ci_id\"\,\"data_domain_nm\"\,\"client_id\"\,/);
				#my $newln1 = $ln;
				#my $newln2 = $ln;
				#$newln1 =~s/2019\-04\-(\d\d)/2019-05-$1/;
				#$newln2 =~s/2019\-04\-(\d\d)/2019-03-$1/;
				#push @extra_months, $newln1;
				#push @extra_months, $newln2;
				#
				$count++;
				#print "$count of $total_count\n" if ($count % 1000 == 0);
				$ln=~s/\"//g;
				$ln=~s/\,/~/g;
				my @row = split '~~~', $ln;
				my ($source, $month, $ci_alias_nm, $ci_id, $data_domain_nm, $client_id, $client_alias_nm, $interval_utc_ts, $ci_alias_type, $metricset_nm, $resource_type,
			 			$resource_nm, $natv_mtrc_cd	, $natv_mtrc_valu, $metric_sample_ct, $metricset_module, $src_clnt_cd, $src_sys_nm)= @row;

				# To prevent reading CIs with empty space
				next if( $ci_alias_nm =~/^\s*$/);
				#$client_alias_nm=~s/Intermountain Health Care Inc/intermountain healthcare/;
				$client_alias_nm=lc($client_alias_nm);
				$natv_mtrc_cd=~s/_/./g;
				#2019-04-23 17:58:53.100
				my $last_30=0;
				my $sample_tick = date_to_tick($interval_utc_ts);
				my $date_dif = sprintf "%0.2f", ($current_tick - $sample_tick) / (24 * 60 * 60);
	      if ($date_dif < 30){
  	    	$last_30 =1;
    	  	#print "DateDiff: $date_dif $current_tick - $sample_tick) / (24 * 60 * 60)\n";
      	}
			my ($year,$mon,$day,$hour,$min) =$interval_utc_ts =~m/(\d\d\d\d)\-(\d\d)\-(\d\d)\s(\d\d)\:(\d\d):\d\d\.\d\d\d/;
				my $trim_time= $interval_utc_ts;
				$trim_time=~s/\.\d\d\d$//;
				my ($day_lable, $hour_lable,$month_lable);
				$month_lable= $num2mon{$mon}."_".$year;
				my $month_lable_hyphen= $num2mon{$mon}."-".$year;
				$month_lable_hyphen=~s/\-\d\d/-/;
				$day_lable= $day."_".$num2mon{$mon}."_".$year;
				$hour_lable = $hour."_".$day."_".$num2mon{$mon}."_".$year;

				if (defined($cached_company{$client_alias_nm})) {
					$customer = $cached_company{$client_alias_nm};
				} else {
					$customer = map_customer_to_sp(\%account_reg,$client_alias_nm,"","ANY");
					$cached_company{$client_alias_nm} = $customer;
				}

#				my %x = ('FQDN' => $fqdn, 'ASSIGNMENT'=>$assignment, 'USAGE'=>$usage, 'SYSTEM_ID'=>$id, 'SUB_BUSINESS' => $sub, 'STATUS' => $status, 'OS' => $os,


				$server_capacity{RESOURCE_TYPE}{$customer}{$ci_alias_nm}{$metricset_nm}{$resource_nm}{resource_type}= $resource_type;
				if($last_30==1){
					$server_capacity{DATA}{$customer}{$ci_alias_nm}{$metricset_nm}{MONTH}{'30_DAYS'}{$trim_time}{$resource_nm}{$natv_mtrc_cd} =  $natv_mtrc_valu;
				}
				$server_capacity{FQDNS}{$customer}{$ci_alias_nm}=1;
				$server_capacity{LATEST_RECORD}{$customer}=$sample_tick if ($sample_tick>$server_capacity{LATEST_RECORD}{$customer});
				$server_capacity{DATA}{$customer}{$ci_alias_nm}{$metricset_nm}{MONTH}{$month_lable}{$trim_time}{$resource_nm}{$natv_mtrc_cd} =  $natv_mtrc_valu;
				$server_capacity{DATA}{$customer}{$ci_alias_nm}{$metricset_nm}{DAY}{$day_lable}{$trim_time}{$resource_nm}{$natv_mtrc_cd} =  $natv_mtrc_valu;
				$server_capacity{DATA}{$customer}{$ci_alias_nm}{$metricset_nm}{HOUR}{$month_lable}{$trim_time}{$resource_nm}{$natv_mtrc_cd} =  $natv_mtrc_valu;

			}
			close (RAW);
		}
	}
}

sub map_fqdn{
	my ($host, $customer)=@_;
	my $matched_host;
	my $mapping = $account_reg{$customer}{sp_mapping_file};
	my $file_name = "$account_reg{$customer}{sp_mapping_file}"."_esl_system_ci_by_fqdn";
	my $sys =  load_cache_byFile("$cache_dir/by_customer/$file_name");
	my %esl_system_ci = %{$sys};
	foreach my $fqdn (sort keys %{$esl_system_ci{$customer}{ALL}}) {
		$matched_host=$fqdn if($fqdn =~/^\Q$host\E\./i or $fqdn eq "$host" or $host =~/^\Q$fqdn\E\./i );
	}
	return $matched_host if(defined($matched_host));


}

sub get_server_memcpu
{
	my %not_mapped;
	my $customer;
	my %cached_company;
	my %cached_fqdns;
	my @extra_months;

	foreach my $proc_month (@proc_months) {
		my $raw_file = "$rawdata_dir/aws.ci_metric_".$proc_month;
		if (-r $raw_file) {
			open(RAW,$raw_file) or die $!;

			print "Processing Server Memory and CPU data from $raw_file\n";

			my @rows;
			my $count = 0;
			while (<RAW>)
			{
				my $ln = $_;
				chomp($ln);
				next if ($ln =~ /^\s*$/);
				#next if ($ln !~ /boral/i);
				push @rows, $ln;
			}

			my $total_count = scalar(@rows);
			my $last_core_tick;
			foreach my $ln (@rows) {
				# This ignore the column name line
				next if ($ln =~/\"ci_alias_nm\"\,\"ci_id\"\,\"data_domain_nm\"\,\"company_id\"\,/);


				$count++;
				#print "$count of $total_count\n" if ($count % 1000 == 0);

				my @row = split '~~~', $ln;
				my ($source, $month, $ci_alias_nm, $ci_id, $data_domain, $client_id, $client_alias_nm, $interval_utc_ts, $ci_alias_type, $metricset_nm, $natv_mtrc_cd, $natv_mtrc_valu,
						$metric_sample_ct, $metricset_module, $src_clnt_cd, $src_sys)=@row;
				next if( $ci_alias_nm =~/^\s*$/);

				# For Testing
				next if( $client_alias_nm ne "Origin Energy");# && print "Is not the customer required...\n";
				#print "Company: ".$client_alias_nm."\n";

				$metricset_nm="io" if(not defined($metricset_nm) or $metricset_nm=~/^\s*$/);
				#$client_alias_nm=~s/Intermountain Health Care Inc/intermountain healthcare/;
				$client_alias_nm=lc($client_alias_nm);
				$natv_mtrc_cd=~s/_/./g;

				#2019-04-23 17:58:53.100
				my $last_30=0;
				my $sample_tick = date_to_tick($interval_utc_ts);

				my $date_dif = sprintf "%0.2f", ($current_tick - $sample_tick) / (24 * 60 * 60);
  	    $last_30 =1 if ($date_dif < 30);
    	  #print "Current Tick:$current_tick Sampletick:$sample_tick DateStamp:$interval_utc_ts\nSUM:($current_tick - $sample_tick) / (24 * 60 * 60) = $date_dif\n" if($last_30);

				my ($year,$mon,$day,$hour,$min) =$interval_utc_ts =~m/(\d\d\d\d)\-(\d\d)\-(\d\d)\s(\d\d)\:(\d\d):\d\d\.\d\d\d/;
				my $trim_time= $interval_utc_ts;
				$trim_time=~s/\.\d\d\d$//;
				my ($day_lable, $hour_lable,$month_lable);
				$month_lable= $num2mon{$mon}."_".$year;
				my $month_lable_hyphen= $num2mon{$mon}."-".$year;
				$month_lable_hyphen=~s/\-\d\d/-/;
				$day_lable= $day."_".$num2mon{$mon}."_".$year;
				$hour_lable = $hour."_".$day."_".$num2mon{$mon}."_".$year;

				if (defined($cached_company{$client_alias_nm})) {
					$customer = $cached_company{$client_alias_nm};
				} else {
					$customer = map_customer_to_sp(\%account_reg,$client_alias_nm,"","ANY");
					$cached_company{$client_alias_nm} = $customer;
				}
				if($natv_mtrc_cd eq "system_cpu_cores" and $natv_mtrc_valu >0 ){

					$server_memcpu{CORECOUNT}{$customer}{$ci_alias_nm}{$metricset_nm}= $natv_mtrc_valu;
					#print "CORECOUNT for $ci_alias_nm is $natv_mtrc_valu \n";
					#print "Keys: {CORECOUNT}{ $client_alias_nm }{ $ci_alias_nm }{ $metricset_nm }{ $sample_tick }\n";
					#print "Value:$server_memcpu{CORECOUNT}{$client_alias_nm}{$ci_alias_nm}{$metricset_nm}{$sample_tick}\n";

				}

				if($last_30==1){
					$server_memcpu{DATA}{$customer}{$ci_alias_nm}{$metricset_nm}{MONTH}{'30_DAYS'}{$trim_time}{$natv_mtrc_cd} =  $natv_mtrc_valu;
				}
				$server_memcpu{FQDNS}{$customer}{$ci_alias_nm}=1;
				$server_memcpu{LATEST_RECORD}{$customer}=$sample_tick if ($sample_tick>$server_memcpu{LATEST_RECORD}{$customer});
				$server_memcpu{DATA}{$customer}{$ci_alias_nm}{$metricset_nm}{MONTH}{$month_lable}{$trim_time}{$natv_mtrc_cd} =  $natv_mtrc_valu;
				$server_memcpu{DATA}{$customer}{$ci_alias_nm}{$metricset_nm}{DAY}{$day_lable}{$trim_time}{$natv_mtrc_cd} =  $natv_mtrc_valu;
				$server_memcpu{DATA}{$customer}{$ci_alias_nm}{$metricset_nm}{HOUR}{$month_lable}{$trim_time}{$natv_mtrc_cd} =  $natv_mtrc_valu;
			}
			close (RAW);
		}
	}
}

sub get_months
{
	push @proc_months, "30DAYS";

	foreach my $x (1..12) {
		my @curr_time = localtime ();
		$curr_time[4] -= $x; #set month
		my $month_tick = mktime @curr_time;
		my $month_label = uc(strftime("%h-%y",localtime($month_tick)));
		push @proc_months, $month_label;
	}
}


#Main

#Get last 12 months
get_months();

#get_capability_lookup();
print "Processing Filesystem data...\n";
#get_server_capacity();
print "Processing CPU and Memory data...\n";
get_server_memcpu();


foreach my $customer (keys %{$server_capacity{DATA}}){
	my %x;
	my %y;
	#delete the 30day cache file
 	my $file_name = "$account_reg{$customer}{sp_mapping_file}"."_server_capacity_30_DAYS";
	my $rmcmd ="rm -rf $cache_dir/by_customer/$file_name*";
	`$rmcmd`;
	print "Remove 30 day file - $rmcmd\n";

	foreach my $ci (keys %{$server_capacity{DATA}{$customer}}){
		foreach my $met (keys %{$server_capacity{DATA}{$customer}{$ci}}){
			foreach my $month (keys %{$server_capacity{DATA}{$customer}{$ci}{$met}{MONTH}}){
				$x{$month}{$customer}{DATA}{$ci}{$met}=$server_capacity{DATA}{$customer}{$ci}{$met}{MONTH}{$month};
				foreach my $sample (keys %{$server_capacity{DATA}{$customer}{$ci}{$met}{MONTH}{$month}}){
					$y{$customer}{DATA}{$ci}{$met}{$sample}=$server_capacity{DATA}{$customer}{$ci}{$met}{MONTH}{$month}{$sample};
				}
			}
		}
	}
	foreach my $m (keys %x){
		my $file_name = "$account_reg{$customer}{sp_mapping_file}"."_server_capacity_".$m;

		$file_name="NOT_MAPPED"."_server_capacity_".$m if($account_reg{$customer}{sp_mapping_file}=~/^\s*$/);
		$x{$m}{$customer}{RESOURCE_TYPE}= $server_capacity{RESOURCE_TYPE}{$customer};
		$x{$m}{$customer}{FQDNS}= $server_capacity{FQDNS}{$customer};
		$x{$m}{$customer}{LATEST_RECORD}= $server_capacity{LATEST_RECORD}{$customer};
		save_hash("$file_name", $x{$m}{$customer},"$cache_dir/by_customer");
	}
	my $file_name = "$account_reg{$customer}{sp_mapping_file}"."_server_capacity_all";
	$file_name="NOT_MAPPED"."_server_capacity_all" if($account_reg{$customer}{sp_mapping_file}=~/^\s*$/);
	save_hash("$file_name", $y{$customer},"$cache_dir/by_customer");

}


foreach my $customer (keys %{$server_memcpu{DATA}}){
	my %x;
	my %y;
	#delete the 30day cache file 	##
 	my $file_name = "$account_reg{$customer}{sp_mapping_file}"."_server_memcpu_30_DAYS";
	my $rmcmd ="rm -rf $cache_dir/by_customer/$file_name*";
	`$rmcmd`;
	print "Remove 30 day file - $rmcmd\n";
	foreach my $ci (keys %{$server_memcpu{DATA}{$customer}}){
		foreach my $met (keys %{$server_memcpu{DATA}{$customer}{$ci}}){
			foreach my $month (keys %{$server_memcpu{DATA}{$customer}{$ci}{$met}{MONTH}}){
				$x{$month}{$customer}{DATA}{$ci}{$met}=$server_memcpu{DATA}{$customer}{$ci}{$met}{MONTH}{$month};
				foreach my $sample (keys %{$server_memcpu{DATA}{$customer}{$ci}{$met}{MONTH}{$month}}){
					$y{$customer}{DATA}{$ci}{$met}{$sample}=$server_memcpu{DATA}{$customer}{$ci}{$met}{MONTH}{$month}{$sample};
				}

			}
		}
	}
	foreach my $m (keys %x){
		my $file_name = "$account_reg{$customer}{sp_mapping_file}"."_server_memcpu_".$m;
		$file_name="NOT_MAPPED"."_server_memcpu_".$m if($account_reg{$customer}{sp_mapping_file}=~/^\s*$/);
		$x{$m}{$customer}{CORECOUNT}= $server_memcpu{CORECOUNT}{$customer};
		$x{$m}{$customer}{FQDNS}= $server_memcpu{FQDNS}{$customer};
		$x{$m}{$customer}{LATEST_RECORD}= $server_memcpu{LATEST_RECORD}{$customer};
		save_hash("$file_name", $x{$m}{$customer},"$cache_dir/by_customer");
	}
	$y{$customer}{CORECOUNT}= $server_memcpu{CORECOUNT}{$customer};
	my $file_name = "$account_reg{$customer}{sp_mapping_file}"."_server_memcpu_all";
	$file_name="NOT_MAPPED"."_server_memcpu_all" if($account_reg{$customer}{sp_mapping_file}=~/^\s*$/);
	save_hash("$file_name", $y{$customer},"$cache_dir/by_customer");

}

#save_hash("cache.server_capacity", \%server_capacity);
save_hash("cache.server_memcpu", \%server_memcpu);