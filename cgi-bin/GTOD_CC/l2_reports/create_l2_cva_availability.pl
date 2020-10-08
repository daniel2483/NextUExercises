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
use List::Util qw(max min);


use lib '/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/modules/pm';
use LoadCache;
use CommonFunctions;
use CommonColor;

use vars qw($cache_dir);
use vars qw($base_dir);
use vars qw($rawdata_dir);
use vars qw($cfg_dir);
use vars qw($l2_report_dir);
use vars qw($drilldown_dir);
use vars qw($green $red $amber);
my @months = qw(START JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC);

my %var_keys;
$var_keys{c_month} = POSIX::strftime("%m", localtime time);
$var_keys{c_year} = POSIX::strftime("%Y", localtime time);
$var_keys{m_name} = POSIX::strftime("%m", localtime time);
$var_keys{c_month_name} = $months[$var_keys{c_month}];
if ($var_keys{m_name} =~ /jan/i) {
		$var_keys{p_name} = "DEC";
		$var_keys{c_year} = $var_keys{c_year}-1;
} else {
		$var_keys{p_name} = $months[$var_keys{c_month}-1];
		$var_keys{p_month} = $var_keys{c_month}-1;
}

my %l2_cva;
my %l3_cva;
my %dwn;
my %opts;

getopts(':p', \%opts);

my @list = ('account_reg');
my %cache = load_cache(\@list);
my %account_reg = %{$cache{account_reg}};

my %status;
my %status_l2;
my %status_l4;
my %da;
my %da_l4;
my %range;
my %l4_cva;
my %down_nodes;


sub split_status_metrics {
	open(RAW_DATA, "$rawdata_dir/aws.ci_stat_metric_30DAYS");
	my @data = <RAW_DATA>;
	close(RAW_DATA);
	my $i;

	my $avcap_file_trimmed_30days = "$rawdata_dir/aws.ci_stat_metric_normalized_30DAYS";
	open (AWS_OUTFILE_30DAYS, ">$avcap_file_trimmed_30days");
	#print "Writing data to $avcap_file_trimmed_30days\n";

	foreach my $row (@data) {
		chomp $row;
		$row =~ s/\"//g;
		next if ($row =~ /^\"ci_alias_nm/);
		next if ($row =~ /^\s*$/);
		my ($source,$month,$ci_alias_nm,$ci_id,$data_domain_nm,$client_id,$client_alias_nm,$interval_utc_ts,$ci_alias_type,$metricset_nm,$request_time,
		     $natv_mtrc_cd,$natv_mtrc_value,$metric_sample_ct,$metric_module,$src_clnt_cd,$src_sys_nm,$ingest_dt) = split('~~~',$row);
		print AWS_OUTFILE_30DAYS $source."~~~".$month."~~~".$ci_alias_nm."~~~".$client_alias_nm."~~~".$interval_utc_ts."~~~".$ci_alias_type."~~~".$request_time."~~~".$natv_mtrc_value."\n";
	}
	undef @data;
	close(AWS_OUTFILE_30DAYS);
}

sub get_status_metrics {
	
	my %cached_company;
	my $cust;
	open(RAW_DATA, "$rawdata_dir/aws.ci_stat_metric_normalized_30DAYS");
	my @data = <RAW_DATA>;
	close(RAW_DATA);
	my $i;
	foreach my $row (@data) {
		chomp $row;
		$row =~ s/\"//g;
		next if ($row =~ /^\"ci_alias_nm/);
		next if ($row =~ /^\s*$/);
		my ($source,$month,$ci_alias_nm,$client_alias_nm,$interval_utc_ts,$ci_alias_type,$request_time,$natv_mtrc_value) = split('~~~',$row);
		#next if($ci_alias_nm !~ /afv-tbase01.co.ihc.com/i);
		#print $source."~".$month."~".$ci_alias_nm."~".$client_alias_nm."~".$interval_utc_ts."~".$ci_alias_type."~".$request_time."~".$natv_mtrc_value."\n";

		my %cva_key;
		if ($interval_utc_ts =~ /^(\d*)-(\d*)-(\d*) (\d*):(\d*):(\d*)\.(\d*)$/) {
			$cva_key{year} = $1;
			$cva_key{year_t} = $1-1900;
			$cva_key{month} = $2-1;
			$cva_key{day} = $3;
			
			$cva_key{hour} = $4;
			$cva_key{min} = $5;
			$cva_key{sec} = $6;
			$cva_key{month_name} = $months[$2]
		}
		
		
		my $tick = POSIX::mktime($cva_key{sec}, $cva_key{min}, $cva_key{hour}, $cva_key{day}, $cva_key{month}, $cva_key{year_t});
		#my $c_tick = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime $tick);
		#print $ci_alias_nm .  ',' . $interval_utc_ts . ',' . $tick . ',' . $c_tick . "\n";$natv_mtrc_value
		#next if ($cva_key{month_name} ne $var_keys{p_name});
		#my %x = ('duration' => $natv_mtrc_value, 'interval' => $interval_utc_ts, 'ci_type' => $ci_alias_type, 'fqdn' => $client_alias_nm);
			
		if (defined($cached_company{$client_alias_nm})) {
			$cust = $cached_company{$client_alias_nm};
		} else {
			$cust = map_customer_to_sp(\%account_reg,$client_alias_nm,"","ANY");
			$cached_company{$client_alias_nm} = $cust;
		}
		
		my $dt = POSIX::strftime("%d-%m-%Y", localtime $tick);

		$status_l2{"$cached_company{$client_alias_nm}"}{lc($ci_alias_nm)}{$tick}{'duration'}= sprintf "%d", $natv_mtrc_value;
		$status_l2{"$cached_company{$client_alias_nm}"}{lc($ci_alias_nm)}{$tick}{'interval'}= $interval_utc_ts;
		$status_l2{"$cached_company{$client_alias_nm}"}{lc($ci_alias_nm)}{$tick}{'ci_type'}= $ci_alias_type;
		$status_l2{"$cached_company{$client_alias_nm}"}{lc($ci_alias_nm)}{$tick}{'fqdn'}= $client_alias_nm;
		$status_l2{"$cached_company{$client_alias_nm}"}{lc($ci_alias_nm)}{$tick}{'request_time'}= $request_time;
		
		$status_l4{"$cached_company{$client_alias_nm}"}{lc($ci_alias_nm)}{$dt}{$tick}{'duration'}= sprintf "%d", $natv_mtrc_value;
		$status_l4{"$cached_company{$client_alias_nm}"}{lc($ci_alias_nm)}{$dt}{$tick}{'interval'}= $interval_utc_ts;
		$status_l4{"$cached_company{$client_alias_nm}"}{lc($ci_alias_nm)}{$dt}{$tick}{'ci_type'}= $ci_alias_type;
		$status_l4{"$cached_company{$client_alias_nm}"}{lc($ci_alias_nm)}{$dt}{$tick}{'fqdn'}= $client_alias_nm;
		$status_l4{"$cached_company{$client_alias_nm}"}{lc($ci_alias_nm)}{$dt}{$tick}{'request_time'}= $request_time;
	
	}
	undef @data;
	
	#print Dumper(\%status);
	

}

sub l2_cva {
	
	my %pdxc_customers;
	my $pdxc_list;
	if (defined($opts{'p'})) { 
		      $pdxc_list = get_pdxc_instance('cva_availability');
		  		foreach my $pdxc_instance (@{$pdxc_list}) {
		  			print "PDXC Instance found -- $pdxc_instance\n";
			  		my $pdxc_cfg = get_pdxc_cache_files($pdxc_instance,'cva_availability');
			  		my $ssz_dir = $pdxc_cfg->{$pdxc_instance}{'ssz_instance_dir'} . '/core_receiver';
					  my $instance_url = $pdxc_cfg->{$pdxc_instance}{'instance_url'};
			  		my $mapping = update_pdxc_cache("$ssz_dir/l2_cache",'cache.l2_cva_availability',$pdxc_instance,$instance_url);			  		
			  		my $pdxc_inc = load_cache_byFile("$ssz_dir/l2_cache/cache.l2_cva_availability");
			  		 foreach my $customer (keys %{$pdxc_inc->{CUSTOMER}}) {
			  		 	$l2_cva{CUSTOMER}{$customer} = \%{$pdxc_inc->{CUSTOMER}{$customer}}; 
			  		 }	
			  		foreach my $customer_pdxc (keys %{$mapping}) {
			  			$pdxc_customers{$customer_pdxc}{INSTANCE} = $mapping->{$customer_pdxc}{INSTANCE};
			  			$pdxc_customers{$customer_pdxc}{INSTANCE_URL} = $mapping->{$customer_pdxc}{INSTANCE_URL};
			  		}			  		
		  		}   				
	}

	foreach my $customer (keys %status_l2) {
		print "L2_CVA_Customer : $customer\n";
		foreach my $fqdn (keys %{$status_l2{$customer}}) {
			my ($min_tick, $max_tick, $down_time);
			#####foreach my $month (keys %{$status_l2{$customer}{$fqdn}}) {
				#####my @d = keys %{$status_l2{$customer}{$fqdn}{$month}};
				my @d = keys %{$status_l2{$customer}{$fqdn}};
				my @d = sort @d;
				my $i=0;
				$min_tick = $d[0];
				foreach my $element (@d) {
					#if(($status_l2{$customer}{$fqdn}{$element}{'request_time'} ne "") and ($i gt 0)){
					if(($status_l2{$customer}{$fqdn}{$d[$i]}{'duration'} < $status_l2{$customer}{$fqdn}{$d[$i-1]}{'duration'}) and ($i gt 0)){
						#print $i.":".$customer.":".$fqdn.":".$element.":".$status_l2{$customer}{$fqdn}{$d[$i]}{'duration'}.":".$status_l2{$customer}{$fqdn}{$d[$i-1]}{'duration'}."\n";
						$max_tick = $d[$i-1];
						#print $i.":".$customer.":".$fqdn.":".$min_tick.":".$max_tick.":".$status_l2{$customer}{$fqdn}{$min_tick}{'duration'}.":".$status_l2{$customer}{$fqdn}{$max_tick}{'duration'}."\n";
						$down_time = sprintf "%0.2f", $down_time + sprintf "%0.2f", ( ($status_l2{$customer}{$fqdn}{$max_tick}{'duration'} - $status_l2{$customer}{$fqdn}{$min_tick}{'duration'}) / (1000 * 60 * 60));
						$min_tick = $d[$i];
						#print "$i:up_time : $down_time\n";
					}
					$i++;
				}
				$max_tick = $d[$#d];
				#print $i.":".$customer.":".$fqdn.":".$min_tick.":".$max_tick.":".$status_l2{$customer}{$fqdn}{$min_tick}{'duration'}.":".$status_l2{$customer}{$fqdn}{$max_tick}{'duration'}.":".$status_l2{$customer}{$fqdn}{$min_tick}{'interval'}.":".$status_l2{$customer}{$fqdn}{$max_tick}{'interval'}."\n";
				#my $j = 
				$down_time = sprintf "%0.2f", ($down_time + ( ($status_l2{$customer}{$fqdn}{$max_tick}{'duration'} - $status_l2{$customer}{$fqdn}{$min_tick}{'duration'}) / (1000 * 60 * 60)));
				#print "$i:Final up_time : $down_time\n";
				######################## downtime calc fix finish #################################

				my $total_days = 30;
				#####print "Final total_days $fqdn : $total_days\n";
				my $total_hours = sprintf "%d", $total_days * 24;
				#####print "Final total_hours $fqdn : $total_hours\n";
				$down_time = sprintf "%0.2f", $total_hours-$down_time;
				#####print "Final down_time $fqdn : $down_time\n";
				my $avail;
				

				if ($down_time > 0.5) {
					$avail = sprintf "%d", ( ($total_hours-$down_time) / $total_hours) * 100;
					$l2_cva{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{SERVER_OUTAGES}{VALUE}++;
					$l2_cva{CUSTOMER}{ALL}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{SERVER_OUTAGES}{VALUE}++;
					$l3_cva{CUSTOMER}{$customer}{$fqdn}{SERVER_OUTAGES}=1;
				} else {
					$avail = 100;
					$down_time=0;
					$l3_cva{CUSTOMER}{$customer}{$fqdn}{SERVER_OUTAGES}=0;
				}
				$l2_cva{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{SERVER_OUTAGES}{HTML} = "<a href=\"$drilldown_dir/l3_cva_availability.pl?customer=$customer&type=outage\">$l2_cva{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{SERVER_OUTAGES}{VALUE}</a>";
				$l2_cva{CUSTOMER}{ALL}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{SERVER_OUTAGES}{HTML} = "<a href=\"$drilldown_dir/l3_cva_availability.pl?customer=$customer&type=outage\">$l2_cva{CUSTOMER}{ALL}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{SERVER_OUTAGES}{VALUE}</a>";
				
				$l3_cva{CUSTOMER}{$customer}{$fqdn}{DOWNTIME_HOURS}= $down_time;
				$l2_cva{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{TOTAL_SERVERS}{VALUE}++;
				$l2_cva{CUSTOMER}{ALL}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{TOTAL_SERVERS}{VALUE}++;
				
				$l2_cva{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{TOTAL_SERVERS}{HTML} = "<a href=\"$drilldown_dir/l3_cva_availability.pl?customer=$customer&type=baseline\">$l2_cva{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{TOTAL_SERVERS}{VALUE}</a>";
				$l2_cva{CUSTOMER}{ALL}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{TOTAL_SERVERS}{HTML} = "<a href=\"$drilldown_dir/l3_cva_availability.pl?customer=$customer&type=baseline\">$l2_cva{CUSTOMER}{ALL}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{TOTAL_SERVERS}{VALUE}</a>";
				
				$l2_cva{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{OUTAGE_DURATION_HOURS}{VALUE} += sprintf "%0.2f", $down_time;
				$l2_cva{CUSTOMER}{ALL}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{OUTAGE_DURATION_HOURS}{VALUE} += sprintf "%0.2f", $down_time;
				#$l2_cva{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{OUTAGE_DURATION_HOURS}{VALUE} += sprintf "%d", $down_time;
				#$l2_cva{CUSTOMER}{ALL}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{OUTAGE_DURATION_HOURS}{VALUE} += sprintf "%d", $down_time;
				
				$l2_cva{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{OUTAGE_DURATION_HOURS}{HTML} = "<a href=\"$drilldown_dir/l3_cva_availability.pl?customer=$customer&type=outage_hours\">".sprintf "%0.2f", $l2_cva{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{OUTAGE_DURATION_HOURS}{VALUE}."</a>";
				$l2_cva{CUSTOMER}{ALL}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{OUTAGE_DURATION_HOURS}{HTML} = "<a href=\"$drilldown_dir/l3_cva_availability.pl?customer=$customer&type=outage_hours\">".sprintf "%0.2f", $l2_cva{CUSTOMER}{ALL}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{OUTAGE_DURATION_HOURS}{VALUE}."</a>";
				
				
				$l3_cva{CUSTOMER}{$customer}{$fqdn}{TOTAL_HOURS}= $total_hours;
				$l2_cva{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{TOTAL_HOURS}{VALUE} += $total_hours;
				$l2_cva{CUSTOMER}{ALL}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{TOTAL_HOURS}{VALUE} += $total_hours;
			
		  #####}
	  }
  }
  if (defined($opts{'p'})) { 
      #PDXC_Updates
      foreach my $customer (keys %pdxc_customers) {
	      my $pdxc_instance = $pdxc_customers{$customer}{INSTANCE};
	      $l2_cva{CUSTOMER}{$customer}{PDXC_INSTANCE_LIST}{$pdxc_instance} = $pdxc_customers{$customer}{INSTANCE_URL};	      
	   	}
	   	update_pdxc_ssz(\%l2_cva,\%pdxc_customers, "l2_cva_availability.pl?aggregation=L2.5");	
   }	

 
	 
# Save the master L2 cache
save_hash("cache.l2_cva_availability", \%l2_cva,"$cache_dir/l2_cache");
save_hash("cache.l3_cva_availability", \%l3_cva,"$cache_dir/l3_cache");
}

sub get_downtime {
	my %tmp;
	foreach my $customer (keys %status_l4) {
		print "L4_CVA_Customer : $customer\n";
		foreach my $fqdn (keys %{$status_l4{$customer}}) {
			#next if ($fqdn !~ /pxcmonpln11.teamvee.net/i);
			foreach my $dt (keys %{$status_l4{$customer}{$fqdn}}) {
				#next if($dt !~ /01-06-2020/);
				my @d = keys %{$status_l4{$customer}{$fqdn}{$dt}};
				my @d = sort @d;
				#print "Array Size : $#d\n";
				my $max_tick = max(@d);
				my $min_tick = min(@d);		
				my $down_time;


				my $i=0;
				$min_tick = $d[0];
				my $i;
				my $ci_down_dt = 0;
				foreach my $element (@d) {
					#print $i.":".$fqdn.":".$dt.":".$d[$i].":".POSIX::strftime("%d_%m_%Y", localtime $d[$i]).":".POSIX::strftime("%H_%M_%S", localtime $d[$i]).":".$status_l4{$customer}{$fqdn}{$dt}{$d[$i]}{'duration'}.":".$status_l4{$customer}{$fqdn}{$dt}{$d[$i]}{'request_time'}."\n";
					if(($status_l4{$customer}{$fqdn}{$dt}{$element}{'request_time'} ne "") and ($i gt 0)){
						#print $i.":".$customer.":".$fqdn.":".$element.":".$status_l4{$customer}{$fqdn}{$dt}{$d[$i]}{'duration'}.":".$status_l4{$customer}{$fqdn}{$dt}{$d[$i-1]}{'duration'}."\n";
						$max_tick = $d[$i-1];
						#print $i.":".$customer.":".$fqdn.":".$min_tick.":".$max_tick.":".$status_l4{$customer}{$fqdn}{$dt}{$min_tick}{'duration'}.":".$status_l4{$customer}{$fqdn}{$dt}{$max_tick}{'duration'}."\n";
						$down_time = $down_time + sprintf "%0.2f", ( ($status_l4{$customer}{$fqdn}{$dt}{$max_tick}{'duration'} - $status_l4{$customer}{$fqdn}{$dt}{$min_tick}{'duration'}) / (1000 * 60 * 60));
						$min_tick = $d[$i];
						#print "$i:up_time $fqdn $dt : $down_time\n";
						$ci_down_dt = 1;
					}
					$i++;
				}
				$max_tick = $d[$#d];

				$down_time = $down_time + sprintf "%0.2f", ( ($status_l4{$customer}{$fqdn}{$dt}{$max_tick}{'duration'} - $status_l4{$customer}{$fqdn}{$dt}{$min_tick}{'duration'}) / (1000 * 60 * 60));
				#print "$i:Final up_time $fqdn $dt : $down_time\n";

				#my $total_hours = 24;
				my $total_hours = ($d[$#d] - $d[0])/60/60;
				#####print "Final total_hours $fqdn $dt : $total_hours\n";
				$down_time = sprintf "%0.2f", $total_hours-$down_time;
				#####print "Final down_time $fqdn $dt : $down_time\n";
				
			
				if($down_time < 0.2){ #$ci_down_dt eq 0 and 
					$l4_cva{$fqdn}{$max_tick} = 100
				}else {
					my $avail = sprintf "%d", ( ($total_hours-$down_time) / $total_hours) * 100;
					$l4_cva{$fqdn}{$max_tick} = $avail;
				}
			}
		}

	}
	
	save_hash("cache.l4_cva_availability", \%l4_cva,"$cache_dir/l3_cache");
}


###Main
my $start_time = time();
split_status_metrics();
printf "split_status_metrics : %0.2f Mins\n", (time() - $start_time) / 60;
get_status_metrics();
printf "get_status_metrics : %0.2f Mins\n", (time() - $start_time) / 60;
l2_cva();
undef %status_l2;
printf "l2_cva : %0.2f Mins\n", (time() - $start_time) / 60;
get_downtime();
printf "get_downtime : %0.2f Mins\n", (time() - $start_time) / 60;
