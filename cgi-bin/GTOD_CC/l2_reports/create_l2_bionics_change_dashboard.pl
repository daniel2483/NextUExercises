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
use vars qw($drilldown_dir);
use vars qw($l2_report_dir);
use vars qw($green $red $amber $grey $orange $cyan $cgreen $lgrey $info $info2 $dgrey $voilet $lgolden $lblue $hpe);

my @months = qw(JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC);

my $start_time = time();

# Declaration of global Variable
my %cache=();
my %l2_bionics;

my @list = ('account_reg','ngdm_delivery_map');
%cache = load_cache(\@list);

my %account_reg = %{$cache{account_reg}};
my %ngdm_delivery_map = %{$cache{ngdm_delivery_map}};

my %l3_bionics_baseline_change;
my %l3_bionics_change;

sub get_start_end_ticks
{
	my ($month_str) = @_;

	# Find the Month Start and End Ticks....
	my $y = substr($month_str,0,4);
	my $m =  substr($month_str,4,2);
	my $date_str = sprintf "%s-%s-01", $y, $m;
	my $month_start_tick = date_to_tick("$date_str 00:00");

	print "MONTH $month_str($date_str) started at tick $month_start_tick\n";

	if ($m < 12) {
		$m++;
		$m = '0'.$m if ($m < 10);
	} else {
		$y++;
		$m = '01';
	}
	my $date_str = sprintf "%s-%s-01", $y, $m;
	my $month_end_tick = date_to_tick("$date_str 00:00");

	print "   and ended by ($date_str) on $month_end_tick\n";

	return ($month_start_tick, $month_end_tick);
}


my @month_ticks;

my $month_c = POSIX::strftime("%m", localtime time);
my $month_name_c = $months[$month_c - 1];
my $year_c = POSIX::strftime("%y", localtime time);
my $current_month = "$month_name_c-$year_c";

# Find the start/end ticks for the last 18 months				
foreach my $x (1..18) {
		
	$month_c--;
	if ($month_c == 0) { $month_c = 12; $year_c--;}
	$month_c = "0"."$month_c" if ($month_c < 10);
	
	$month_name_c = $months[$month_c - 1];
	$current_month = "$month_name_c-$year_c";
	
	my $year = $year_c + 2000;
	my ($start_tick, $end_tick) = get_start_end_ticks($year.$month_c);
	
	my $field_ext;
	$field_ext = "M".$x;
	
	my %z = ("START_TICK" => $start_tick, "END_TICK" => $end_tick, "MONTH_LABEL" => $current_month, "FIELD_EXT" => $field_ext, "FILE_EXT" => $current_month );
	push @month_ticks, \%z;
	
  #Month Labels
  $l2_bionics{"MONTH_${field_ext}"}{VALUE} = $months[$month_c - 1];

}


my $year = sprintf "%0.4d", POSIX::strftime("%Y", localtime time);
my $month = sprintf "%0.2d", POSIX::strftime("%m", localtime time);
my $day = sprintf "%0.2d", POSIX::strftime("%d", localtime time);

# Uncomment either of the following lines to test Financial Year date calculations
#$month = sprintf "%0.2d", 4;
#$month = sprintf "%0.2d", 3;

# Baseline is previous Financial Year
# Get start and end dates for previous Financial Year
# Next Financial Year starts on 1st April.
# So on 1st April 2017, we start FY18
my $baseline_start_year = $year - 1;
$baseline_start_year = $baseline_start_year - 1 if ($month < 4);  # If we are in Jan - March, previous FY started not last year but year before
my $baseline_end_year = $baseline_start_year + 1;

# Now get start and end dates for current Financial Year
my $cur_fy_year = $year;
$cur_fy_year = $year + 1 if ($month > 3);  # If we are in Jan - March, this FY started last year and would have been Year + 1 last year
my $cur_fy_start_year = $year;
$cur_fy_start_year = $cur_fy_year -1  if ($month < 4); # We start FY18 in 2017

my $baseline_start_date = "$baseline_start_year-04-01 00:00";
my $baseline_start_tick = date_to_tick($baseline_start_date);
my $baseline_end_date = "$baseline_end_year-$month-$day 00:00";
$baseline_end_date = "$baseline_start_year-$month-$day 00:00" if ($month > 3);
my $baseline_end_tick = date_to_tick($baseline_end_date);

my $baseline_start_date_disp = "$baseline_start_year-04-01";
my $baseline_end_date_disp = "$baseline_end_year-$month-$day";
$baseline_end_date_disp = "$baseline_start_year-$month-$day" if ($month > 3);

my $cur_fy_start_date = "$cur_fy_start_year-04-01 00:00";
my $cur_fy_start_tick = date_to_tick($cur_fy_start_date);

print "\nTodays Date is $year-$month-$day\n";
print "Current Financial Year Starts $cur_fy_start_date($cur_fy_start_tick)\n";
print "Baseline Starts - $baseline_start_date ($baseline_start_tick)\n";
print "Baseline Ends: $baseline_end_date ($baseline_end_tick)\n\n";


my %opts;
getopts('m:', \%opts) || usage("invalid arguments");


foreach my $customer (sort keys %account_reg) {

	#next if ($customer !~ /adecco|origin|queens|downer|boral/i);
	#next if ($customer !~ /boral/i);
	#next if ($customer !~ /queensland/i);
	
	my $file_name = "$account_reg{$customer}{sp_mapping_file}"."_ebi_change";
	my $change = load_cache_byFile("$cache_dir/by_customer/$file_name");
	my %ebi_change = %{$change};

	my $region = $account_reg{$customer}{oc_region} || "unknown";

	my $found = 0;
	my $orl = "not set";

	foreach my $employee (@{$ngdm_delivery_map{DD_IDMContacts}{$customer}}) {
		if ($employee->{ROLE} eq 'ito cluster leader') {
			$found =1;
  			$orl = $employee->{EMPLOYEE_NAME};
			last;

	}
		  			
	}

	# Changing to IDM Contacts
	#foreach my $r (@{$ngdm_delivery_map{'DD_ACCOUNT_CONTACTS'}{$customer}}) {
	#	if ($r->{'ITO_ONERUN_LEADER'} !~ /null/i) {
	#		$found = 1;
	#		$orl = $r->{'ITO_ONERUN_LEADER'};
	#		last;
	#	}
	#}

	$l2_bionics{CUSTOMER}{$customer}{ONERUN_LEADER} = $orl;
	$l2_bionics{CUSTOMER}{$customer}{DXC_REGION} = $region;
	
	my $ctr_cnt = 0;
	if (not exists $account_reg{$customer}{oc_center}){
		my $center = "not defined";
		push @{$l2_bionics{CUSTOMER}{$customer}{CENTERS}{VALUE}}, $center;
		$l2_bionics{CUSTOMER}{$customer}{CENTERS}{HTML} = $center;
	} else {
		foreach my $center (sort @{$account_reg{$customer}{oc_center}}){
			#next if ($center !~ /goc/i);
			push @{$l2_bionics{CUSTOMER}{$customer}{CENTERS}{VALUE}}, $center;
			$l2_bionics{CUSTOMER}{$customer}{CENTERS}{HTML} = $center if ($ctr_cnt == 0);
			$l2_bionics{CUSTOMER}{$customer}{CENTERS}{HTML} .= '<br>'.$center if ($ctr_cnt > 0);
			$ctr_cnt++ ;
		}
	}

  ######################
	# Get Change Counts
	######################
	print "Calculating change dashboard for $customer.  Its ITO Cluster Leader is $orl\n";
	
	foreach my $center (keys %{$ebi_change{CUSTOMER}{$customer}{CENTER}}) {
		#next if ($center !~ /ALL/i);
		foreach my $change_key (keys %{$ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}}) {

			my $open_flag = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{OPEN_FLAG};
			my $success_flag = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{SUCCESS_FLAG};
			my $closure_code = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{CLOSURE_CODE};
			my $phase_status =  $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{PHASE_STATUS};
			my $change_model = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{CHANGE_MODEL};
			my $category = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{CATEGORY};
			my $cap = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{CAP};
			
			$l2_bionics{CUSTOMER}{$customer}{CAPABILITIES}{$cap} = 1;
			
			my $close_date = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{CLOSE_DATE};
			my $close_date_tick = date_to_tick("$close_date 00:00");
			
			next if ($phase_status !~ /closed/i);
			next if ($closure_code =~ /cancelled|withdrawn/i);
			
			####################################################
			# Calculate graph metric counts for last 18 months 
			####################################################
			foreach my $m (@month_ticks){
				my $month_start_tick = $m->{START_TICK};
				my $month_end_tick = $m->{END_TICK};
				if ($close_date_tick >= $month_start_tick and $close_date_tick < $month_end_tick){
					my $field_ext = $m->{FIELD_EXT};
					
					$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"CLOSED_COUNT_${field_ext}"}{VALUE}++;
					$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"SUCCESS_COUNT_${field_ext}"}{VALUE}++ if ($closure_code !~ /cancelled|client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented|not solved|out of scope|unsolved|void|withdrawn/i);
					$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"FAILED_COUNT_${field_ext}"}{VALUE}++ if ($closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
					$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"STD_FAILED_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /standard/i and $closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
					$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"STD_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /standard/i);
					$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"STD_MINOR_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /standard/i or $change_model =~ /normal minor/i);
					$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"NORMAL_COUNT_${field_ext}"}{VALUE}++ if (lc($change_model) eq "normal" or $change_model =~ /normal major/i);
					$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"NORMAL_MINOR_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /normal minor/i);
					$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"CLOSED_COUNT_${field_ext}"}{VALUE}++;
					$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"SUCCESS_COUNT_${field_ext}"}{VALUE}++ if ($closure_code !~ /cancelled|client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented|not solved|out of scope|unsolved|void|withdrawn/i);
					$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"FAILED_COUNT_${field_ext}"}{VALUE}++ if ($closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
					$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"STD_FAILED_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /standard/i and $closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
					$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"STD_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /standard/i);
					$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"STD_MINOR_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /standard/i or $change_model =~ /normal minor/i);
					$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"NORMAL_COUNT_${field_ext}"}{VALUE}++ if (lc($change_model) eq "normal" or $change_model =~ /normal major/i);
					$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"NORMAL_MINOR_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /normal minor/i);
					
					if ($center =~ /ALL/i) {
						$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"CLOSED_COUNT_${field_ext}"}{VALUE}++;
						$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"SUCCESS_COUNT_${field_ext}"}{VALUE}++ if ($closure_code !~ /cancelled|client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented|not solved|out of scope|unsolved|void|withdrawn/i);
						$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"FAILED_COUNT_${field_ext}"}{VALUE}++ if ($closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
						$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"STD_FAILED_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /standard/i and $closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
						$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"STD_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /standard/i);
						$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"STD_MINOR_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /standard/i or $change_model =~ /normal minor/i);
						$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"NORMAL_COUNT_${field_ext}"}{VALUE}++ if (lc($change_model) eq "normal" or $change_model =~ /normal major/i);
						$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"NORMAL_MINOR_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /normal minor/i);
						$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"CLOSED_COUNT_${field_ext}"}{VALUE}++;
						$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"SUCCESS_COUNT_${field_ext}"}{VALUE}++ if ($closure_code !~ /cancelled|client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented|not solved|out of scope|unsolved|void|withdrawn/i);
						$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"FAILED_COUNT_${field_ext}"}{VALUE}++ if ($closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
						$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"STD_FAILED_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /standard/i and $closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
						$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"STD_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /standard/i);
						$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"STD_MINOR_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /standard/i or $change_model =~ /normal minor/i);
						$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"NORMAL_COUNT_${field_ext}"}{VALUE}++ if (lc($change_model) eq "normal" or $change_model =~ /normal major/i);
						$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"NORMAL_MINOR_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /normal minor/i);
					
						$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"CLOSED_COUNT_${field_ext}"}{VALUE}++;
						$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"SUCCESS_COUNT_${field_ext}"}{VALUE}++ if ($closure_code !~ /cancelled|client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented|not solved|out of scope|unsolved|void|withdrawn/i);
						$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"FAILED_COUNT_${field_ext}"}{VALUE}++ if ($closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
						$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"STD_FAILED_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /standard/i and $closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
						$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"STD_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /standard/i);
						$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"STD_MINOR_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /standard/i or $change_model =~ /normal minor/i);
						$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"NORMAL_COUNT_${field_ext}"}{VALUE}++ if (lc($change_model) eq "normal" or $change_model =~ /normal major/i);
						$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"NORMAL_MINOR_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /normal minor/i);
						$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"CLOSED_COUNT_${field_ext}"}{VALUE}++;
						$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"SUCCESS_COUNT_${field_ext}"}{VALUE}++ if ($closure_code !~ /cancelled|client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented|not solved|out of scope|unsolved|void|withdrawn/i);
						$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"FAILED_COUNT_${field_ext}"}{VALUE}++ if ($closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
						$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"STD_FAILED_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /standard/i and $closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
						$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"STD_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /standard/i);
						$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"STD_MINOR_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /standard/i or $change_model =~ /normal minor/i);
						$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"NORMAL_COUNT_${field_ext}"}{VALUE}++ if (lc($change_model) eq "normal" or $change_model =~ /normal major/i);
						$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"NORMAL_MINOR_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /normal minor/i);
					
						$l2_bionics{CAPABILITY}{$cap}{"CLOSED_COUNT_${field_ext}"}{VALUE}++;
						$l2_bionics{CAPABILITY}{$cap}{"SUCCESS_COUNT_${field_ext}"}{VALUE}++ if ($closure_code !~ /cancelled|client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented|not solved|out of scope|unsolved|void|withdrawn/i);
						$l2_bionics{CAPABILITY}{$cap}{"FAILED_COUNT_${field_ext}"}{VALUE}++ if ($closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
						$l2_bionics{CAPABILITY}{$cap}{"STD_FAILED_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /standard/i and $closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
						$l2_bionics{CAPABILITY}{$cap}{"STD_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /standard/i);
						$l2_bionics{CAPABILITY}{$cap}{"STD_MINOR_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /standard/i or $change_model =~ /normal minor/i);
						$l2_bionics{CAPABILITY}{$cap}{"NORMAL_COUNT_${field_ext}"}{VALUE}++ if (lc($change_model) eq "normal" or $change_model =~ /normal major/i);
						$l2_bionics{CAPABILITY}{$cap}{"NORMAL_MINOR_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /normal minor/i);
						$l2_bionics{CAPABILITY}{ALL}{"CLOSED_COUNT_${field_ext}"}{VALUE}++;
						$l2_bionics{CAPABILITY}{ALL}{"SUCCESS_COUNT_${field_ext}"}{VALUE}++ if ($closure_code !~ /cancelled|client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented|not solved|out of scope|unsolved|void|withdrawn/i);
						$l2_bionics{CAPABILITY}{ALL}{"FAILED_COUNT_${field_ext}"}{VALUE}++ if ($closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
						$l2_bionics{CAPABILITY}{ALL}{"STD_FAILED_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /standard/i and $closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
						$l2_bionics{CAPABILITY}{ALL}{"STD_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /standard/i);
						$l2_bionics{CAPABILITY}{ALL}{"STD_MINOR_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /standard/i or $change_model =~ /normal minor/i);
						$l2_bionics{CAPABILITY}{ALL}{"NORMAL_COUNT_${field_ext}"}{VALUE}++ if (lc($change_model) eq "normal" or $change_model =~ /normal major/i);
						$l2_bionics{CAPABILITY}{ALL}{"NORMAL_MINOR_COUNT_${field_ext}"}{VALUE}++ if ($change_model =~ /normal minor/i);
					}
				}
			} # Monthly Counts for Graphs
			
			if ($close_date_tick >= $cur_fy_start_tick){
				# Calculate stats for this financial year 1st April - 31st March
				
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{CLOSED_COUNT_CUR}{VALUE}++;
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{SUCCESS_COUNT_CUR}{VALUE}++ if ($closure_code !~ /cancelled|client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented|not solved|out of scope|unsolved|void|withdrawn/i);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{FAILED_COUNT_CUR}{VALUE}++ if ($closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_COUNT_CUR}{VALUE}++ if ($change_model =~ /standard/i);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_MINOR_COUNT_CUR}{VALUE}++ if ($change_model =~ /standard/i or $change_model =~ /normal minor/i);				
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_FAILED_COUNT_CUR}{VALUE}++ if ($change_model =~ /standard/i and $closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_COUNT_CUR}{VALUE}++ if (lc($change_model) eq "normal" or $change_model =~ /normal major/i);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_MINOR_COUNT_CUR}{VALUE}++ if ($change_model =~ /normal minor/i);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{CLOSED_COUNT_CUR}{VALUE}++;
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{SUCCESS_COUNT_CUR}{VALUE}++ if ($closure_code !~ /cancelled|client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented|not solved|out of scope|unsolved|void|withdrawn/i);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{FAILED_COUNT_CUR}{VALUE}++ if ($closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{STD_COUNT_CUR}{VALUE}++ if ($change_model =~ /standard/i);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{STD_MINOR_COUNT_CUR}{VALUE}++ if ($change_model =~ /standard/i or $change_model =~ /normal minor/i);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{STD_FAILED_COUNT_CUR}{VALUE}++ if ($change_model =~ /standard/i and $closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{NORMAL_COUNT_CUR}{VALUE}++ if (lc($change_model) eq "normal" or $change_model =~ /normal major/i);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{NORMAL_MINOR_COUNT_CUR}{VALUE}++ if ($change_model =~ /normal minor/i);
				
				if ($center =~ /ALL/i) {
					
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{CLOSED_COUNT_CUR}{VALUE}++;
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{SUCCESS_COUNT_CUR}{VALUE}++ if ($closure_code !~ /cancelled|client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented|not solved|out of scope|unsolved|void|withdrawn/i);
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{FAILED_COUNT_CUR}{VALUE}++ if ($closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_COUNT_CUR}{VALUE}++ if ($change_model =~ /standard/i);
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_MINOR_COUNT_CUR}{VALUE}++ if ($change_model =~ /standard/i or $change_model =~ /normal minor/i);
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_FAILED_COUNT_CUR}{VALUE}++ if ($change_model =~ /standard/i and $closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_COUNT_CUR}{VALUE}++ if (lc($change_model) eq "normal" or $change_model =~ /normal major/i);
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_MINOR_COUNT_CUR}{VALUE}++ if ($change_model =~ /normal minor/i);
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{CLOSED_COUNT_CUR}{VALUE}++;
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{SUCCESS_COUNT_CUR}{VALUE}++ if ($closure_code !~ /cancelled|client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented|not solved|out of scope|unsolved|void|withdrawn/i);
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{FAILED_COUNT_CUR}{VALUE}++ if ($closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{STD_COUNT_CUR}{VALUE}++ if ($change_model =~ /standard/i);
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{STD_MINOR_COUNT_CUR}{VALUE}++ if ($change_model =~ /standard/i or $change_model =~ /normal minor/i);
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{STD_FAILED_COUNT_CUR}{VALUE}++ if ($change_model =~ /standard/i and $closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{NORMAL_COUNT_CUR}{VALUE}++ if (lc($change_model) eq "normal" or $change_model =~ /normal major/i);
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{NORMAL_MINOR_COUNT_CUR}{VALUE}++ if ($change_model =~ /normal minor/i);
				
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{CLOSED_COUNT_CUR}{VALUE}++;
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{SUCCESS_COUNT_CUR}{VALUE}++ if ($closure_code !~ /cancelled|client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented|not solved|out of scope|unsolved|void|withdrawn/i);
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{FAILED_COUNT_CUR}{VALUE}++ if ($closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_COUNT_CUR}{VALUE}++ if ($change_model =~ /standard/i);
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_MINOR_COUNT_CUR}{VALUE}++ if ($change_model =~ /standard/i or $change_model =~ /normal minor/i);
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_FAILED_COUNT_CUR}{VALUE}++ if ($change_model =~ /standard/i and $closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_COUNT_CUR}{VALUE}++ if (lc($change_model) eq "normal" or $change_model =~ /normal major/i);
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_MINOR_COUNT_CUR}{VALUE}++ if ($change_model =~ /normal minor/i);
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{CLOSED_COUNT_CUR}{VALUE}++;
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{SUCCESS_COUNT_CUR}{VALUE}++ if ($closure_code !~ /cancelled|client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented|not solved|out of scope|unsolved|void|withdrawn/i);
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{FAILED_COUNT_CUR}{VALUE}++ if ($closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{STD_COUNT_CUR}{VALUE}++ if ($change_model =~ /standard/i);
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{STD_MINOR_COUNT_CUR}{VALUE}++ if ($change_model =~ /standard/i or $change_model =~ /normal minor/i);
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{STD_FAILED_COUNT_CUR}{VALUE}++ if ($change_model =~ /standard/i and $closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{NORMAL_COUNT_CUR}{VALUE}++ if (lc($change_model) eq "normal" or $change_model =~ /normal major/i);
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{NORMAL_MINOR_COUNT_CUR}{VALUE}++ if ($change_model =~ /normal minor/i);
				
					$l2_bionics{CAPABILITY}{$cap}{CLOSED_COUNT_CUR}{VALUE}++;
					$l2_bionics{CAPABILITY}{$cap}{SUCCESS_COUNT_CUR}{VALUE}++ if ($closure_code !~ /cancelled|client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented|not solved|out of scope|unsolved|void|withdrawn/i);
					$l2_bionics{CAPABILITY}{$cap}{FAILED_COUNT_CUR}{VALUE}++ if ($closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
					$l2_bionics{CAPABILITY}{$cap}{STD_COUNT_CUR}{VALUE}++ if ($change_model =~ /standard/i);
					$l2_bionics{CAPABILITY}{$cap}{STD_MINOR_COUNT_CUR}{VALUE}++ if ($change_model =~ /standard/i or $change_model =~ /normal minor/i);
					$l2_bionics{CAPABILITY}{$cap}{STD_FAILED_COUNT_CUR}{VALUE}++ if ($change_model =~ /standard/i and $closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
					$l2_bionics{CAPABILITY}{$cap}{NORMAL_COUNT_CUR}{VALUE}++ if (lc($change_model) eq "normal" or $change_model =~ /normal major/i);
					$l2_bionics{CAPABILITY}{$cap}{NORMAL_MINOR_COUNT_CUR}{VALUE}++ if ($change_model =~ /normal minor/i);
					$l2_bionics{CAPABILITY}{ALL}{CLOSED_COUNT_CUR}{VALUE}++;
					$l2_bionics{CAPABILITY}{ALL}{SUCCESS_COUNT_CUR}{VALUE}++ if ($closure_code !~ /cancelled|client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented|not solved|out of scope|unsolved|void|withdrawn/i);
					$l2_bionics{CAPABILITY}{ALL}{FAILED_COUNT_CUR}{VALUE}++ if ($closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
					$l2_bionics{CAPABILITY}{ALL}{STD_COUNT_CUR}{VALUE}++ if ($change_model =~ /standard/i);
					$l2_bionics{CAPABILITY}{ALL}{STD_MINOR_COUNT_CUR}{VALUE}++ if ($change_model =~ /standard/i or $change_model =~ /normal minor/i);
					$l2_bionics{CAPABILITY}{ALL}{STD_FAILED_COUNT_CUR}{VALUE}++ if ($change_model =~ /standard/i and $closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
					$l2_bionics{CAPABILITY}{ALL}{NORMAL_COUNT_CUR}{VALUE}++ if (lc($change_model) eq "normal" or $change_model =~ /normal major/i);
					$l2_bionics{CAPABILITY}{ALL}{NORMAL_MINOR_COUNT_CUR}{VALUE}++ if ($change_model =~ /normal minor/i);
				
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{CUSTOMER}{$customer} = 1;
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{CUSTOMER}{$customer} = 1;
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{CUSTOMER}{$customer} = 1;
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{CUSTOMER}{$customer} = 1;
					$l2_bionics{CAPABILITY}{$cap}{CUSTOMER}{$customer} = 1;
					$l2_bionics{CAPABILITY}{ALL}{CUSTOMER}{$customer} = 1;
					
				}
				
				$l3_bionics_change{CHANGE_KEY}{$change_key}{CUSTOMER} = $customer;
				$l3_bionics_change{CHANGE_KEY}{$change_key}{ONERUN_LEADER} = $orl;
				$l3_bionics_change{CHANGE_KEY}{$change_key}{DXC_REGION} = $region;
				$l3_bionics_change{CHANGE_KEY}{$change_key}{CAPABILITY} = $cap;
				push @{$l3_bionics_change{CHANGE_KEY}{$change_key}{CENTERS}}, $center if ($center !~ /ALL/i);
   			
	   		$l3_bionics_change{CHANGE_KEY}{$change_key}{CHANGE_ID} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{CHANGE_ID};
   			$l3_bionics_change{CHANGE_KEY}{$change_key}{PHASE} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{PHASE};
   			$l3_bionics_change{CHANGE_KEY}{$change_key}{PHASE_STATUS} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{PHASE_STATUS};
   			$l3_bionics_change{CHANGE_KEY}{$change_key}{SRC} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{SRC};
   			$l3_bionics_change{CHANGE_KEY}{$change_key}{WORKFLOW_TOOL} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{WORKFLOW_TOOL};
  	 		$l3_bionics_change{CHANGE_KEY}{$change_key}{CUR_WRKGRP} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{CUR_WRKGRP};
	   		$l3_bionics_change{CHANGE_KEY}{$change_key}{CHANGE_MODEL} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{CHANGE_MODEL};
   			$l3_bionics_change{CHANGE_KEY}{$change_key}{STATUS} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{STATUS};
   			$l3_bionics_change{CHANGE_KEY}{$change_key}{OPEN_FLAG} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{OPEN_FLAG};
   			$l3_bionics_change{CHANGE_KEY}{$change_key}{CLOSURE_CODE} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{CLOSURE_CODE};
  	 		$l3_bionics_change{CHANGE_KEY}{$change_key}{CATEGORY} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{CATEGORY};
	   		$l3_bionics_change{CHANGE_KEY}{$change_key}{OPEN_DATE} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{OPEN_DATE};
   			$l3_bionics_change{CHANGE_KEY}{$change_key}{SCHEDULED_START} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{SCHEDULED_START};
   			$l3_bionics_change{CHANGE_KEY}{$change_key}{SCHEDULED_END} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{SCHEDULED_END};
   			$l3_bionics_change{CHANGE_KEY}{$change_key}{ACTUAL_START} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{ACTUAL_START};
  	 		$l3_bionics_change{CHANGE_KEY}{$change_key}{ACTUAL_END} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{ACTUAL_END};
	   		$l3_bionics_change{CHANGE_KEY}{$change_key}{CLOSE_DATE} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{CLOSE_DATE};
   			$l3_bionics_change{CHANGE_KEY}{$change_key}{SUCCESS_FLAG} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{SUCCESS_FLAG};
   			$l3_bionics_change{CHANGE_KEY}{$change_key}{UNAUTHORIZED_FLAG} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{UNAUTHORIZED_FLAG};
   			$l3_bionics_change{CHANGE_KEY}{$change_key}{FORWARD_FLAG} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{FORWARD_FLAG};
  	 		$l3_bionics_change{CHANGE_KEY}{$change_key}{BACKLOG_FLAG} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{BACKLOG_FLAG};
   			
	   		$l3_bionics_change{CHANGE_KEY}{$change_key}{BIONICS_CLOSED} = ($phase_status =~ /closed/i and $closure_code !~ /cancelled|withdrawn/i) ? 'yes' : 'no';  			
   			$l3_bionics_change{CHANGE_KEY}{$change_key}{BIONICS_STD} = ($change_model =~ /standard/i) ? 'yes' : 'no';
   			$l3_bionics_change{CHANGE_KEY}{$change_key}{BIONICS_STD_MINOR} = ($change_model =~ /standard/i or $change_model =~ /normal minor/i) ? 'yes' : 'no';
   			$l3_bionics_change{CHANGE_KEY}{$change_key}{BIONICS_NORMAL} = (lc($change_model) eq "normal" or $change_model =~ /normal major/i) ? 'yes' : 'no';
  	 		$l3_bionics_change{CHANGE_KEY}{$change_key}{BIONICS_NORMAL_MINOR} = ($change_model =~ /normal minor/i) ? 'yes' : 'no';
	   		$l3_bionics_change{CHANGE_KEY}{$change_key}{BIONICS_SUCCESS} = ($closure_code !~ /cancelled|client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented|not solved|out of scope|unsolved|void|withdrawn/i) ? 'yes' : 'no';
   			$l3_bionics_change{CHANGE_KEY}{$change_key}{BIONICS_FAILED} = ($closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i) ? 'yes' : 'no';
   			$l3_bionics_change{CHANGE_KEY}{$change_key}{BIONICS_STD_FAILED} = ($change_model =~ /standard/i and $closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i) ? 'yes' : 'no';
   			
			} elsif ($close_date_tick >= $baseline_start_tick and $close_date_tick < $baseline_end_tick) {
				# Calculate baseline stats for equivalent period in FY17 (1 April 2016 - 31 March 2017)
				
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{CLOSED_COUNT_BASELINE}{VALUE}++;
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{SUCCESS_COUNT_BASELINE}{VALUE}++ if ($closure_code !~ /cancelled|client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented|not solved|out of scope|unsolved|void|withdrawn/i);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{FAILED_COUNT_BASELINE}{VALUE}++ if ($closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /standard/i);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_MINOR_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /standard/i or $change_model =~ /normal minor/i);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_FAILED_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /standard/i and $closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_COUNT_BASELINE}{VALUE}++ if (lc($change_model) eq "normal" or $change_model =~ /normal major/i);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_MINOR_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /normal minor/i);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{CLOSED_COUNT_BASELINE}{VALUE}++;
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{SUCCESS_COUNT_BASELINE}{VALUE}++ if ($closure_code !~ /cancelled|client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented|not solved|out of scope|unsolved|void|withdrawn/i);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{FAILED_COUNT_BASELINE}{VALUE}++ if ($closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{STD_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /standard/i);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{STD_MINOR_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /standard/i or $change_model =~ /normal minor/i);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{STD_FAILED_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /standard/i and $closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{NORMAL_COUNT_BASELINE}{VALUE}++ if (lc($change_model) eq "normal" or $change_model =~ /normal major/i);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{NORMAL_MINOR_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /normal minor/i);
				
				if ($center =~ /ALL/i){
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{CLOSED_COUNT_BASELINE}{VALUE}++;
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{SUCCESS_COUNT_BASELINE}{VALUE}++ if ($closure_code !~ /cancelled|client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented|not solved|out of scope|unsolved|void|withdrawn/i);
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{FAILED_COUNT_BASELINE}{VALUE}++ if ($closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /standard/i);
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_MINOR_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /standard/i or $change_model =~ /normal minor/i);
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_FAILED_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /standard/i and $closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_COUNT_BASELINE}{VALUE}++ if (lc($change_model) eq "normal" or $change_model =~ /normal major/i);
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_MINOR_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /normal minor/i);
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{CLOSED_COUNT_BASELINE}{VALUE}++;
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{SUCCESS_COUNT_BASELINE}{VALUE}++ if ($closure_code !~ /cancelled|client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented|not solved|out of scope|unsolved|void|withdrawn/i);
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{FAILED_COUNT_BASELINE}{VALUE}++ if ($closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{STD_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /standard/i);
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{STD_MINOR_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /standard/i or $change_model =~ /normal minor/i);
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{STD_FAILED_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /standard/i and $closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{NORMAL_COUNT_BASELINE}{VALUE}++ if (lc($change_model) eq "normal" or $change_model =~ /normal major/i);
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{NORMAL_MINOR_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /normal minor/i);
				
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{CLOSED_COUNT_BASELINE}{VALUE}++;
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{SUCCESS_COUNT_BASELINE}{VALUE}++ if ($closure_code !~ /cancelled|client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented|not solved|out of scope|unsolved|void|withdrawn/i);
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{FAILED_COUNT_BASELINE}{VALUE}++ if ($closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /standard/i);
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_MINOR_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /standard/i or $change_model =~ /normal minor/i);
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_FAILED_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /standard/i and $closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_COUNT_BASELINE}{VALUE}++ if (lc($change_model) eq "normal" or $change_model =~ /normal major/i);
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_MINOR_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /normal minor/i);
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{CLOSED_COUNT_BASELINE}{VALUE}++;
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{SUCCESS_COUNT_BASELINE}{VALUE}++ if ($closure_code !~ /cancelled|client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented|not solved|out of scope|unsolved|void|withdrawn/i);
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{FAILED_COUNT_BASELINE}{VALUE}++ if ($closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{STD_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /standard/i);
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{STD_MINOR_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /standard/i or $change_model =~ /normal minor/i);
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{STD_FAILED_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /standard/i and $closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{NORMAL_COUNT_BASELINE}{VALUE}++ if (lc($change_model) eq "normal" or $change_model =~ /normal major/i);
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{NORMAL_MINOR_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /normal minor/i);
				
					$l2_bionics{CAPABILITY}{$cap}{CLOSED_COUNT_BASELINE}{VALUE}++;
					$l2_bionics{CAPABILITY}{$cap}{SUCCESS_COUNT_BASELINE}{VALUE}++ if ($closure_code !~ /cancelled|client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented|not solved|out of scope|unsolved|void|withdrawn/i);
					$l2_bionics{CAPABILITY}{$cap}{FAILED_COUNT_BASELINE}{VALUE}++ if ($closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
					$l2_bionics{CAPABILITY}{$cap}{STD_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /standard/i);
					$l2_bionics{CAPABILITY}{$cap}{STD_MINOR_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /standard/i or $change_model =~ /normal minor/i);
					$l2_bionics{CAPABILITY}{$cap}{STD_FAILED_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /standard/i and $closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
					$l2_bionics{CAPABILITY}{$cap}{NORMAL_COUNT_BASELINE}{VALUE}++ if (lc($change_model) eq "normal" or $change_model =~ /normal major/i);
					$l2_bionics{CAPABILITY}{$cap}{NORMAL_MINOR_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /normal minor/i);
				
					$l2_bionics{CAPABILITY}{ALL}{CLOSED_COUNT_BASELINE}{VALUE}++;
					$l2_bionics{CAPABILITY}{ALL}{SUCCESS_COUNT_BASELINE}{VALUE}++ if ($closure_code !~ /cancelled|client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented|not solved|out of scope|unsolved|void|withdrawn/i);
					$l2_bionics{CAPABILITY}{ALL}{FAILED_COUNT_BASELINE}{VALUE}++ if ($closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
					$l2_bionics{CAPABILITY}{ALL}{STD_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /standard/i);
					$l2_bionics{CAPABILITY}{ALL}{STD_MINOR_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /standard/i or $change_model =~ /normal minor/i);
					$l2_bionics{CAPABILITY}{ALL}{STD_FAILED_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /standard/i and $closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i);
					$l2_bionics{CAPABILITY}{ALL}{NORMAL_COUNT_BASELINE}{VALUE}++ if (lc($change_model) eq "normal" or $change_model =~ /normal major/i);
					$l2_bionics{CAPABILITY}{ALL}{NORMAL_MINOR_COUNT_BASELINE}{VALUE}++ if ($change_model =~ /normal minor/i);
				
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{CUSTOMER}{$customer} = 1;
					$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{CUSTOMER}{$customer} = 1;
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{CUSTOMER}{$customer} = 1;
					$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{CUSTOMER}{$customer} = 1;
					$l2_bionics{CAPABILITY}{$cap}{CUSTOMER}{$customer} = 1;
					$l2_bionics{CAPABILITY}{ALL}{CUSTOMER}{$customer} = 1;
					
				} 
					
				$l3_bionics_baseline_change{PERIOD} = "$baseline_start_date_disp - $baseline_end_date_disp";
				$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{CUSTOMER} = $customer;
				$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{ONERUN_LEADER} = $orl;
				$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{DXC_REGION} = $region;
				$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{CAPABILITY} = $cap;
				push @{$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{CENTERS}}, $center if ($center !~ /ALL/i);
   			
   			$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{CHANGE_ID} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{CHANGE_ID};
	   		$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{PHASE} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{PHASE};
  	 		$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{PHASE_STATUS} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{PHASE_STATUS};
   			$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{SRC} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{SRC};
   			$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{WORKFLOW_TOOL} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{WORKFLOW_TOOL};
   			$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{CUR_WRKGRP} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{CUR_WRKGRP};
   			$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{CHANGE_MODEL} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{CHANGE_MODEL};
	   		$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{STATUS} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{STATUS};
  	 		$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{OPEN_FLAG} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{OPEN_FLAG};
   			$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{CLOSURE_CODE} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{CLOSURE_CODE};
   			$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{CATEGORY} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{CATEGORY};
   			$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{OPEN_DATE} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{OPEN_DATE};
	   		$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{SCHEDULED_START} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{SCHEDULED_START};
  	 		$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{SCHEDULED_END} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{SCHEDULED_END};
   			$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{ACTUAL_START} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{ACTUAL_START};
   			$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{ACTUAL_END} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{ACTUAL_END};
  			$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{CLOSE_DATE} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{CLOSE_DATE};
	  		$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{SUCCESS_FLAG} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{SUCCESS_FLAG};
 	 			$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{UNAUTHORIZED_FLAG} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{UNAUTHORIZED_FLAG};
  			$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{FORWARD_FLAG} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{FORWARD_FLAG};
 				$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{BACKLOG_FLAG} = $ebi_change{CUSTOMER}{$customer}{CENTER}{$center}{CHANGE_KEY}{$change_key}{BACKLOG_FLAG};
   			
   			$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{BIONICS_CLOSED} = ($phase_status =~ /closed/i and $closure_code !~ /cancelled|withdrawn/i) ? 'yes' : 'no';
	   		$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{BIONICS_STD} = ($change_model =~ /standard/i) ? 'yes' : 'no';
  	 		$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{BIONICS_STD_MINOR} = ($change_model =~ /standard/i or $change_model =~ /normal minor/i) ? 'yes' : 'no';
   			$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{BIONICS_NORMAL} = (lc($change_model) eq "normal" or $change_model =~ /normal major/i) ? 'yes' : 'no';
   			$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{BIONICS_NORMAL_MINOR} = ($change_model =~ /normal minor/i) ? 'yes' : 'no';
   			$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{BIONICS_SUCCESS} = ($closure_code !~ /cancelled|client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented|not solved|out of scope|unsolved|void|withdrawn/i) ? 'yes' : 'no';
	   		$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{BIONICS_FAILED} = ($closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i) ? 'yes' : 'no';
	   		$l3_bionics_baseline_change{CHANGE_KEY}{$change_key}{BIONICS_STD_FAILED} = ($change_model =~ /standard/i and $closure_code =~ /client impact-backed out|client impact-not backed out|failed|no client impact-backed out|not implemented-client impact/i) ? 'yes' : 'no';
			}
		}
	}
	undef %ebi_change;
}

save_hash("cache.l3_bionics_change", \%l3_bionics_change, "$cache_dir/l3_cache");
save_hash("cache.l3_bionics_baseline_change", \%l3_bionics_baseline_change, "$cache_dir/l3_cache");

undef(%l3_bionics_change);
undef(%l3_bionics_baseline_change);

###############################################################
# Calculate percentages and changes for One Run Leader metrics
###############################################################
foreach my $orl (keys %{$l2_bionics{ONERUN_LEADER}}) {
	foreach my $cap (keys %{$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}}) {
		##########################
		# Current Metrics
		##########################
		my $cur_closed = $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{CLOSED_COUNT_CUR}{VALUE} || 0;
		my $cur_std = $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_COUNT_CUR}{VALUE} || 0;
		my $cur_std_minor = $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_MINOR_COUNT_CUR}{VALUE} || 0;
		my $cur_normal = $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_COUNT_CUR}{VALUE} || 0;
		my $cur_normal_minor = $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_MINOR_COUNT_CUR}{VALUE} || 0;
		my $cur_success= $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{SUCCESS_COUNT_CUR}{VALUE} || 0;
		my $cur_failed= $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{FAILED_COUNT_CUR}{VALUE} || 0;
		my $cur_std_failed= $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_FAILED_COUNT_CUR}{VALUE} || 0;
	
		# Closed
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{CLOSED_COUNT_CUR}{HTML} = ($cur_closed > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&onerun_leader=$orl&cap=$cap&type=CLOSED\">$cur_closed</a>" : 0;
	
		# Standard
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_COUNT_CUR}{HTML} = ($cur_std > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&onerun_leader=$orl&cap=$cap&type=STD\">$cur_std</a>" : 0;
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_PCT_CUR}{VALUE} = sprintf "%0.2f", ($cur_std / $cur_closed) * 100 if ($cur_closed > 0);
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_PCT_CUR}{HTML} = ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_PCT_CUR}{VALUE} ne "") ? $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_PCT_CUR}{VALUE} ."\%" : "-";
	
		# Standard Minor
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_MINOR_COUNT_CUR}{HTML} = ($cur_std_minor > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&onerun_leader=$orl&cap=$cap&type=STD_MINOR\">$cur_std_minor</a>" : 0;
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{VALUE} = sprintf "%0.2f", ($cur_std_minor / $cur_closed) * 100 if ($cur_closed > 0);
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{HTML} = ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{VALUE} ne "") ? $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{VALUE} ."\%" : "-";
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{COLOR} = $green if ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{VALUE} > 35);
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{COLOR} = $amber if ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{VALUE} > 0 and $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{VALUE} <= 35);
	
		# Normal
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_COUNT_CUR}{HTML} = ($cur_normal > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&onerun_leader=$orl&cap=$cap&type=NORMAL\">$cur_normal</a>" : 0;
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_PCT_CUR}{VALUE} = sprintf "%0.2f", ($cur_normal / $cur_closed) * 100 if ($cur_closed > 0);
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_PCT_CUR}{HTML} = ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_PCT_CUR}{VALUE} ne "") ? $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_PCT_CUR}{VALUE} ."\%" : "-";
	
		# Normal Minor
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_MINOR_COUNT_CUR}{HTML} = ($cur_normal_minor > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&onerun_leader=$orl&cap=$cap&type=NORMAL_MINOR\">$cur_normal_minor</a>" : 0;
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_CUR}{VALUE} = sprintf "%0.2f", ($cur_normal_minor / $cur_closed) * 100 if ($cur_closed > 0);
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_CUR}{HTML} = ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_CUR}{VALUE} ne "") ? $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_CUR}{VALUE} ."\%" : "-";
	
		# Success
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{SUCCESS_COUNT_CUR}{HTML} = ($cur_success > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&onerun_leader=$orl&cap=$cap&type=SUCCESS\">$cur_success</a>" : 0;
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{SUCCESS_PCT_CUR}{VALUE} = sprintf "%0.2f", ($cur_success / $cur_closed) * 100 if ($cur_closed > 0);
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{SUCCESS_PCT_CUR}{HTML} = ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{SUCCESS_PCT_CUR}{VALUE} ne "") ? $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{SUCCESS_PCT_CUR}{VALUE} ."\%" : "-";
		
		# Failed
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{FAILED_COUNT_CUR}{HTML} = ($cur_failed > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&onerun_leader=$orl&cap=$cap&type=FAILED\">$cur_failed</a>" : 0;
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{FAILED_PCT_CUR}{VALUE} = sprintf "%0.2f", ($cur_failed / $cur_closed) * 100 if ($cur_closed > 0);
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{FAILED_PCT_CUR}{HTML} = ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{FAILED_PCT_CUR}{VALUE} ne "") ? $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{FAILED_PCT_CUR}{VALUE} ."\%" : "-";
		
		# Failed Standard
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_FAILED_COUNT_CUR}{HTML} = ($cur_std_failed > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&onerun_leader=$orl&cap=$cap&type=STD_FAILED\">$cur_std_failed</a>" : 0;
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_FAILED_PCT_CUR}{VALUE} = sprintf "%0.2f", ($cur_std_failed / $cur_closed) * 100 if ($cur_closed > 0);
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_FAILED_PCT_CUR}{HTML} = ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_FAILED_PCT_CUR}{VALUE} ne "") ? $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_FAILED_PCT_CUR}{VALUE} ."\%" : "-";
	
		##########################
		# Baseline Metrics
		##########################
		my $baseline_closed = $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{CLOSED_COUNT_BASELINE}{VALUE} || 0;
		my $baseline_std = $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_COUNT_BASELINE}{VALUE} || 0;
		my $baseline_std_minor = $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_MINOR_COUNT_BASELINE}{VALUE} || 0;
		my $baseline_normal = $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_COUNT_BASELINE}{VALUE} || 0;
		my $baseline_normal_minor = $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_MINOR_COUNT_BASELINE}{VALUE} || 0;
		my $baseline_success= $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{SUCCESS_COUNT_BASELINE}{VALUE} || 0;
		my $baseline_failed= $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{FAILED_COUNT_BASELINE}{VALUE} || 0;
		my $baseline_std_failed= $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_FAILED_COUNT_BASELINE}{VALUE} || 0;
	
		# Closed
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{CLOSED_COUNT_BASELINE}{HTML} = ($baseline_closed > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&onerun_leader=$orl&cap=$cap&type=CLOSED\">$baseline_closed</a>" : 0;
	
		# Standard
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_COUNT_BASELINE}{HTML} = ($baseline_std > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&onerun_leader=$orl&cap=$cap&type=STD\">$baseline_std</a>" : 0;
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_PCT_BASELINE}{VALUE} = sprintf "%0.2f", ($baseline_std / $baseline_closed) * 100 if ($baseline_closed > 0);
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_PCT_BASELINE}{HTML} = ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_PCT_BASELINE}{VALUE} ne "") ? $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_PCT_BASELINE}{VALUE} ."\%" : "-";
		
		my $baseline_pct = $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_PCT_BASELINE}{VALUE} || 0;
		my $cur_pct = $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_PCT_CUR}{VALUE} || 0;
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_PCT_DIF}{VALUE} = ($cur_closed > 0 and $baseline_closed > 0) ? sprintf "%0.2f", ($cur_pct - $baseline_pct) : 0;
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_PCT_DIF}{HTML} = ($cur_closed > 0 and $baseline_closed > 0) ? $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_PCT_DIF}{VALUE} ."%" : "-";
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_PCT_DIF}{COLOR} = $red if($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_PCT_DIF}{VALUE} < 0);
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_PCT_DIF}{COLOR} = $green if($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_PCT_DIF}{VALUE} > 0);
	
		# Standard Minor
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_MINOR_COUNT_BASELINE}{HTML} = ($baseline_std_minor > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&onerun_leader=$orl&cap=$cap&type=STD_MINOR\">$baseline_std_minor</a>" : 0;
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_MINOR_PCT_BASELINE}{VALUE} = sprintf "%0.2f", ($baseline_std_minor / $baseline_closed) * 100 if ($baseline_closed > 0);
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_MINOR_PCT_BASELINE}{HTML} = ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_MINOR_PCT_BASELINE}{VALUE} ne "") ? $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_MINOR_PCT_BASELINE}{VALUE} ."\%" : "-";
		
		$baseline_pct = $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_MINOR_PCT_BASELINE}{VALUE} || 0;
		$cur_pct = $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{VALUE} || 0;
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_MINOR_PCT_DIF}{VALUE} = ($cur_closed > 0 and $baseline_closed > 0) ? sprintf "%0.2f", ($cur_pct - $baseline_pct) : 0;
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_MINOR_PCT_DIF}{HTML} = ($cur_closed > 0 and $baseline_closed > 0) ? $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_MINOR_PCT_DIF}{VALUE} ."%" : "-";
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_MINOR_PCT_DIF}{COLOR} = $red if($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_MINOR_PCT_DIF}{VALUE} < 0);
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_MINOR_PCT_DIF}{COLOR} = $green if($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_MINOR_PCT_DIF}{VALUE} > 0);
	
		# Normal
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_COUNT_BASELINE}{HTML} = ($baseline_std > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&onerun_leader=$orl&cap=$cap&type=NORMAL\">$baseline_normal</a>" : 0;
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_PCT_BASELINE}{VALUE} = sprintf "%0.2f", ($baseline_normal / $baseline_closed) * 100 if ($baseline_closed > 0);
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_PCT_BASELINE}{HTML} = ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_PCT_BASELINE}{VALUE} ne "") ? $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_PCT_BASELINE}{VALUE} ."\%" : "-";
	
		$baseline_pct = $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_PCT_BASELINE}{VALUE} || 0;
		$cur_pct = $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_PCT_CUR}{VALUE} || 0;
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_PCT_DIF}{VALUE} = ($cur_closed > 0 and $baseline_closed > 0) ? sprintf "%0.2f", ($cur_pct - $baseline_pct) : 0;
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_PCT_DIF}{HTML} = ($cur_closed > 0 and $baseline_closed > 0) ? $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_PCT_DIF}{VALUE} ."%" : "-";
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_PCT_DIF}{COLOR} = $green if($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_PCT_DIF}{VALUE} < 0);
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_PCT_DIF}{COLOR} = $red if($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_PCT_DIF}{VALUE} > 0);
	
		# Normal Minor
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_MINOR_COUNT_BASELINE}{HTML} = ($baseline_normal_minor > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&onerun_leader=$orl&cap=$cap&type=NORMAL_MINOR\">$baseline_normal_minor</a>" : 0;
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_BASELINE}{VALUE} = sprintf "%0.2f", ($baseline_normal_minor / $baseline_closed) * 100 if ($baseline_closed > 0);
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_BASELINE}{HTML} = ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_BASELINE}{VALUE} ne "") ? $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_BASELINE}{VALUE} ."\%" : "-";
	
		$baseline_pct = $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_BASELINE}{VALUE} || 0;
		$cur_pct = $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_CUR}{VALUE} || 0;
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_DIF}{VALUE} = ($cur_closed > 0 and $baseline_closed > 0) ? sprintf "%0.2f", ($cur_pct - $baseline_pct) : 0;
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_DIF}{HTML} = ($cur_closed > 0 and $baseline_closed > 0) ? $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_DIF}{VALUE} ."%" : "-";
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_DIF}{COLOR} = $red if($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_DIF}{VALUE} < 0);
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_DIF}{COLOR} = $green if($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_DIF}{VALUE} > 0);
	
		# Success
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{SUCCESS_COUNT_BASELINE}{HTML} = ($baseline_success > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&onerun_leader=$orl&cap=$cap&type=SUCCESS\">$baseline_success</a>" : 0;
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{SUCCESS_PCT_BASELINE}{VALUE} = sprintf "%0.2f", ($baseline_success / $baseline_closed) * 100 if ($baseline_closed > 0);
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{SUCCESS_PCT_BASELINE}{HTML} = ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{SUCCESS_PCT_BASELINE}{VALUE} ne "") ? $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{SUCCESS_PCT_BASELINE}{VALUE} ."\%" : "-";
	
		$baseline_pct = $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{SUCCESS_PCT_BASELINE}{VALUE} || 0;
		$cur_pct = $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{SUCCESS_PCT_CUR}{VALUE} || 0;
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{SUCCESS_PCT_DIF}{VALUE} = ($cur_closed > 0 and $baseline_closed > 0) ? sprintf "%0.2f", ($cur_pct - $baseline_pct) : 0;
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{SUCCESS_PCT_DIF}{HTML} = ($cur_closed > 0 and $baseline_closed > 0) ? $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{SUCCESS_PCT_DIF}{VALUE} ."%" : "-";
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{SUCCESS_PCT_DIF}{COLOR} = $red if($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{SUCCESS_PCT_DIF}{VALUE} < 0);
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{SUCCESS_PCT_DIF}{COLOR} = $green if($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{SUCCESS_PCT_DIF}{VALUE} > 0);
		
		# Failed
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{FAILED_COUNT_BASELINE}{HTML} = ($baseline_failed > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&onerun_leader=$orl&cap=$cap&type=FAILED\">$baseline_failed</a>" : 0;
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{FAILED_PCT_BASELINE}{VALUE} = sprintf "%0.2f", ($baseline_failed / $baseline_closed) * 100 if ($baseline_closed > 0);
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{FAILED_PCT_BASELINE}{HTML} = ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{FAILED_PCT_BASELINE}{VALUE} ne "") ? $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{FAILED_PCT_BASELINE}{VALUE} ."\%" : "-";
	
		$baseline_pct = $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{FAILED_PCT_BASELINE}{VALUE} || 0;
		$cur_pct = $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{FAILED_PCT_CUR}{VALUE} || 0;
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{FAILED_PCT_DIF}{VALUE} = ($cur_closed > 0 and $baseline_closed > 0) ? sprintf "%0.2f", ($cur_pct - $baseline_pct) : 0;
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{FAILED_PCT_DIF}{HTML} = ($cur_closed > 0 and $baseline_closed > 0) ? $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{FAILED_PCT_DIF}{VALUE} ."%" : "";
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{FAILED_PCT_DIF}{COLOR} = $green if($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{FAILED_PCT_DIF}{VALUE} < 0);
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{FAILED_PCT_DIF}{COLOR} = $red if($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{FAILED_PCT_DIF}{VALUE} > 0);
		
		# Failed Standard
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_FAILED_COUNT_BASELINE}{HTML} = ($baseline_std_failed > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&onerun_leader=$orl&cap=$cap&type=STD_FAILED\">$baseline_std_failed</a>" : 0;
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_FAILED_PCT_BASELINE}{VALUE} = sprintf "%0.2f", ($baseline_std_failed / $baseline_closed) * 100 if ($baseline_closed > 0);
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_FAILED_PCT_BASELINE}{HTML} = ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_FAILED_PCT_BASELINE}{VALUE} ne "") ? $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_FAILED_PCT_BASELINE}{VALUE} ."\%" : "-";
	
		$baseline_pct = $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_FAILED_PCT_BASELINE}{VALUE} || 0;
		$cur_pct = $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_FAILED_PCT_CUR}{VALUE} || 0;
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_FAILED_PCT_DIF}{VALUE} = ($cur_closed > 0 and $baseline_closed > 0) ? sprintf "%0.2f", ($cur_pct - $baseline_pct) : 0;
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_FAILED_PCT_DIF}{HTML} = ($cur_closed > 0 and $baseline_closed > 0) ? $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_FAILED_PCT_DIF}{VALUE} ."%" : "";
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_FAILED_PCT_DIF}{COLOR} = $green if($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_FAILED_PCT_DIF}{VALUE} < 0);
		$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_FAILED_PCT_DIF}{COLOR} = $red if($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{STD_FAILED_PCT_DIF}{VALUE} > 0);
		
		#########################################################
		# Calculate graph metric percentages for last 18 months 
		#########################################################
		for my $x (1..18) {
			
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"CLOSED_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"CLOSED_COUNT_M${x}"}{VALUE});
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE});
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"FAILED_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE});
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"STD_FAILED_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE});
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"STD_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE});
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"STD_MINOR_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE});
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"NORMAL_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE});
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"NORMAL_MINOR_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE});
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"CLOSED_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"CLOSED_COUNT_M${x}"}{VALUE});
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"SUCCESS_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"SUCCESS_COUNT_M${x}"}{VALUE});
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"FAILED_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"SUCCESS_COUNT_M${x}"}{VALUE});
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"STD_FAILED_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"SUCCESS_COUNT_M${x}"}{VALUE});
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"STD_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"SUCCESS_COUNT_M${x}"}{VALUE});
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"STD_MINOR_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"SUCCESS_COUNT_M${x}"}{VALUE});
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"NORMAL_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"SUCCESS_COUNT_M${x}"}{VALUE});
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"NORMAL_MINOR_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"SUCCESS_COUNT_M${x}"}{VALUE});
			
			my $cap_closed_cnt = $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"CLOSED_COUNT_M${x}"}{VALUE} || 0;
			my $all_closed_cnt = $l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"CLOSED_COUNT_M${x}"}{VALUE} || 0;
				
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"SUCCESS_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE} / $cap_closed_cnt) * 100 if ($cap_closed_cnt > 0);
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"SUCCESS_PCT_M${x}"}{VALUE} = '0.00' if ($cap_closed_cnt == 0);
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"FAILED_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"FAILED_COUNT_M${x}"}{VALUE} / $cap_closed_cnt) * 100 if ($cap_closed_cnt > 0);
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"FAILED_PCT_M${x}"}{VALUE} = '0.00' if ($cap_closed_cnt == 0);
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"STD_FAILED_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"STD_FAILED_COUNT_M${x}"}{VALUE} / $cap_closed_cnt) * 100 if ($cap_closed_cnt > 0);
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"STD_FAILED_PCT_M${x}"}{VALUE} = '0.00' if ($cap_closed_cnt == 0);
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"STD_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"STD_COUNT_M${x}"}{VALUE} / $cap_closed_cnt) * 100 if ($cap_closed_cnt > 0);
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"STD_PCT_M${x}"}{VALUE} = '0.00' if ($cap_closed_cnt == 0);
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"STD_MINOR_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"STD_MINOR_COUNT_M${x}"}{VALUE} / $cap_closed_cnt) * 100 if ($cap_closed_cnt > 0);
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"STD_MINOR_PCT_M${x}"}{VALUE} = '0.00' if ($cap_closed_cnt == 0);
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"NORMAL_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"NORMAL_COUNT_M${x}"}{VALUE} / $cap_closed_cnt) * 100 if ($cap_closed_cnt > 0);
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"NORMAL_PCT_M${x}"}{VALUE} = '0.00' if ($cap_closed_cnt == 0);
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"NORMAL_MINOR_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"NORMAL_MINOR_COUNT_M${x}"}{VALUE} / $cap_closed_cnt) * 100 if ($cap_closed_cnt > 0);
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{$cap}{"NORMAL_MINOR_PCT_M${x}"}{VALUE} = '0.00' if ($cap_closed_cnt == 0);
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"SUCCESS_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"SUCCESS_COUNT_M${x}"}{VALUE} / $all_closed_cnt) * 100 if ($all_closed_cnt > 0);
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"SUCCESS_PCT_M${x}"}{VALUE} = '0.00' if ($all_closed_cnt == 0);
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"FAILED_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"FAILED_COUNT_M${x}"}{VALUE} / $all_closed_cnt) * 100 if ($all_closed_cnt > 0);
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"FAILED_PCT_M${x}"}{VALUE} = '0.00' if ($all_closed_cnt == 0);
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"STD_FAILED_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"STD_FAILED_COUNT_M${x}"}{VALUE} / $all_closed_cnt) * 100 if ($all_closed_cnt > 0);
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"STD_FAILED_PCT_M${x}"}{VALUE} = '0.00' if ($all_closed_cnt == 0);
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"STD_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"STD_COUNT_M${x}"}{VALUE} / $all_closed_cnt) * 100 if ($all_closed_cnt > 0);
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"STD_PCT_M${x}"}{VALUE} = '0.00' if ($all_closed_cnt == 0);
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"STD_MINOR_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"STD_MINOR_COUNT_M${x}"}{VALUE} / $all_closed_cnt) * 100 if ($all_closed_cnt > 0);
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"STD_MINOR_PCT_M${x}"}{VALUE} = '0.00' if ($all_closed_cnt == 0);
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"NORMAL_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"NORMAL_COUNT_M${x}"}{VALUE} / $all_closed_cnt) * 100 if ($all_closed_cnt > 0);
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"NORMAL_PCT_M${x}"}{VALUE} = '0.00' if ($all_closed_cnt == 0);
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"NORMAL_MINOR_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"NORMAL_MINOR_COUNT_M${x}"}{VALUE} / $all_closed_cnt) * 100 if ($all_closed_cnt > 0);
			$l2_bionics{ONERUN_LEADER}{$orl}{CAPABILITY}{ALL}{"NORMAL_MINOR_PCT_M${x}"}{VALUE} = '0.00' if ($all_closed_cnt == 0);
			
		} # Monthly Percntages for Graphs
	}
}

###############################################################
# Calculate percentages and changes for Customer metrics				
###############################################################
foreach my $customer (keys %{$l2_bionics{CUSTOMER}}) {
	foreach my $center (keys %{$l2_bionics{CUSTOMER}{$customer}{CENTER}}) {
		foreach my $cap (keys %{$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}}) {
			##########################
			# Current Metrics
			##########################
			my $cur_closed = $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{CLOSED_COUNT_CUR}{VALUE} || 0;
			my $cur_std = $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_COUNT_CUR}{VALUE} || 0;
			my $cur_std_minor = $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_MINOR_COUNT_CUR}{VALUE} || 0;
			my $cur_normal = $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_COUNT_CUR}{VALUE} || 0;
			my $cur_normal_minor = $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_MINOR_COUNT_CUR}{VALUE} || 0;
			my $cur_success= $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{SUCCESS_COUNT_CUR}{VALUE} || 0;
			my $cur_failed= $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{FAILED_COUNT_CUR}{VALUE} || 0;
			my $cur_std_failed= $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_FAILED_COUNT_CUR}{VALUE} || 0;
	
			# Closed
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{CLOSED_COUNT_CUR}{HTML} = ($cur_closed > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&customer=$customer&center=$center&cap=$cap&type=CLOSED\">$cur_closed</a>" : 0;
	
			# Standard
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_COUNT_CUR}{HTML} = ($cur_std > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&customer=$customer&center=$center&cap=$cap&type=STD\">$cur_std</a>" : 0;
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_PCT_CUR}{VALUE} = sprintf "%0.2f", ($cur_std / $cur_closed) * 100 if ($cur_closed > 0);
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_PCT_CUR}{HTML} = ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_PCT_CUR}{VALUE} ne "") ? $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_PCT_CUR}{VALUE} ."\%" : "-";
	
			# Standard Minor
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_MINOR_COUNT_CUR}{HTML} = ($cur_std_minor > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&customer=$customer&center=$center&cap=$cap&type=STD_MINOR\">$cur_std_minor</a>" : 0;
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{VALUE} = sprintf "%0.2f", ($cur_std_minor / $cur_closed) * 100 if ($cur_closed > 0);
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{HTML} = ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{VALUE} ne "") ? $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{VALUE} ."\%" : "-";
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{COLOR} = $green if ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{VALUE} > 35);
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{COLOR} = $amber if ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{VALUE} > 0 and $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{VALUE} <= 35);
	
			# Normal
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_COUNT_CUR}{HTML} = ($cur_normal > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&customer=$customer&center=$center&cap=$cap&type=NORMAL\">$cur_normal</a>" : 0;
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_PCT_CUR}{VALUE} = sprintf "%0.2f", ($cur_normal / $cur_closed) * 100 if ($cur_closed > 0);
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_PCT_CUR}{HTML} = ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_PCT_CUR}{VALUE} ne "") ? $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_PCT_CUR}{VALUE} ."\%" : "-";
	
			# Normal Minor
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_MINOR_COUNT_CUR}{HTML} = ($cur_normal_minor > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&customer=$customer&center=$center&cap=$cap&type=NORMAL_MINOR\">$cur_normal_minor</a>" : 0;
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_CUR}{VALUE} = sprintf "%0.2f", ($cur_normal_minor / $cur_closed) * 100 if ($cur_closed > 0);
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_CUR}{HTML} = ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_CUR}{VALUE} ne "") ? $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_CUR}{VALUE} ."\%" : "-";
	
			# Success
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{SUCCESS_COUNT_CUR}{HTML} = ($cur_success > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&customer=$customer&center=$center&cap=$cap&type=SUCCESS\">$cur_success</a>" : 0;
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{SUCCESS_PCT_CUR}{VALUE} = sprintf "%0.2f", ($cur_success / $cur_closed) * 100 if ($cur_closed > 0);
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{SUCCESS_PCT_CUR}{HTML} = ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{SUCCESS_PCT_CUR}{VALUE} ne "") ? $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{SUCCESS_PCT_CUR}{VALUE} ."\%" : "-";
	
			# Failed
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{FAILED_COUNT_CUR}{HTML} = ($cur_failed > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&customer=$customer&center=$center&cap=$cap&type=FAILED\">$cur_failed</a>" : 0;
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{FAILED_PCT_CUR}{VALUE} = sprintf "%0.2f", ($cur_failed / $cur_closed) * 100 if ($cur_closed > 0);
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{FAILED_PCT_CUR}{HTML} = ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{FAILED_PCT_CUR}{VALUE} ne "") ? $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{FAILED_PCT_CUR}{VALUE} ."\%" : "-";
	
			# Failed Standard
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_FAILED_COUNT_CUR}{HTML} = ($cur_std_failed > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&customer=$customer&center=$center&cap=$cap&type=STD_FAILED\">$cur_std_failed</a>" : 0;
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_FAILED_PCT_CUR}{VALUE} = sprintf "%0.2f", ($cur_std_failed / $cur_closed) * 100 if ($cur_closed > 0);
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_FAILED_PCT_CUR}{HTML} = ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_FAILED_PCT_CUR}{VALUE} ne "") ? $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_FAILED_PCT_CUR}{VALUE} ."\%" : "-";
	
			##########################
			# Baseline Metrics
			##########################
			my $baseline_closed = $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{CLOSED_COUNT_BASELINE}{VALUE} || 0;
			my $baseline_std = $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_COUNT_BASELINE}{VALUE} || 0;
			my $baseline_std_minor = $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_MINOR_COUNT_BASELINE}{VALUE} || 0;
			my $baseline_normal = $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_COUNT_BASELINE}{VALUE} || 0;
			my $baseline_normal_minor = $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_MINOR_COUNT_BASELINE}{VALUE} || 0;
			my $baseline_success= $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{SUCCESS_COUNT_BASELINE}{VALUE} || 0;
			my $baseline_failed= $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{FAILED_COUNT_BASELINE}{VALUE} || 0;
			my $baseline_std_failed= $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_FAILED_COUNT_BASELINE}{VALUE} || 0;
	
			# Closed
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{CLOSED_COUNT_BASELINE}{HTML} = ($baseline_closed > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&customer=$customer&center=$center&cap=$cap&type=CLOSED\">$baseline_closed</a>" : 0;
	
			# Standard
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_COUNT_BASELINE}{HTML} = ($baseline_std > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&customer=$customer&center=$center&cap=$cap&type=STD\">$baseline_std</a>" : 0;
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_PCT_BASELINE}{VALUE} = sprintf "%0.2f", ($baseline_std / $baseline_closed) * 100 if ($baseline_closed > 0);
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_PCT_BASELINE}{HTML} = ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_PCT_BASELINE}{VALUE} ne "") ? $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_PCT_BASELINE}{VALUE} ."\%" : "-";
	
			my $baseline_pct = $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_PCT_BASELINE}{VALUE} || 0;
			my $cur_pct = $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_PCT_CUR}{VALUE} || 0;
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_PCT_DIF}{VALUE} = ($cur_closed > 0 and $baseline_closed > 0) ? sprintf "%0.2f", ($cur_pct - $baseline_pct) : 0;
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_PCT_DIF}{HTML} = ($cur_closed > 0 and $baseline_closed > 0) ? $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_PCT_DIF}{VALUE} ."%" : "-";
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_PCT_DIF}{COLOR} = $red if($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_PCT_DIF}{VALUE} < 0);
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_PCT_DIF}{COLOR} = $green if($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_PCT_DIF}{VALUE} > 0);
	
			# Standard Minor
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_MINOR_COUNT_BASELINE}{HTML} = ($baseline_std_minor > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&customer=$customer&center=$center&cap=$cap&type=STD_MINOR\">$baseline_std_minor</a>" : 0;
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_MINOR_PCT_BASELINE}{VALUE} = sprintf "%0.2f", ($baseline_std_minor / $baseline_closed) * 100 if ($baseline_closed > 0);
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_MINOR_PCT_BASELINE}{HTML} = ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_MINOR_PCT_BASELINE}{VALUE} ne "") ? $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_MINOR_PCT_BASELINE}{VALUE} ."\%" : "-";
	
			$baseline_pct = $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_MINOR_PCT_BASELINE}{VALUE} || 0;
			$cur_pct = $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{VALUE} || 0;
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_MINOR_PCT_DIF}{VALUE} = ($cur_closed > 0 and $baseline_closed > 0) ? sprintf "%0.2f", ($cur_pct - $baseline_pct) : 0;
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_MINOR_PCT_DIF}{HTML} = ($cur_closed > 0 and $baseline_closed > 0) ? $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_MINOR_PCT_DIF}{VALUE} ."%" : "-";
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_MINOR_PCT_DIF}{COLOR} = $red if($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_MINOR_PCT_DIF}{VALUE} < 0);
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_MINOR_PCT_DIF}{COLOR} = $green if($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_MINOR_PCT_DIF}{VALUE} > 0);
	
			# Normal
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_COUNT_BASELINE}{HTML} = ($baseline_std > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&customer=$customer&center=$center&cap=$cap&type=NORMAL\">$baseline_normal</a>" : 0;
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_PCT_BASELINE}{VALUE} = sprintf "%0.2f", ($baseline_normal / $baseline_closed) * 100 if ($baseline_closed > 0);
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_PCT_BASELINE}{HTML} = ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_PCT_BASELINE}{VALUE} ne "") ? $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_PCT_BASELINE}{VALUE} ."\%" : "-";
	
			$baseline_pct = $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_PCT_BASELINE}{VALUE} || 0;
			$cur_pct = $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_PCT_CUR}{VALUE} || 0;
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_PCT_DIF}{VALUE} = ($cur_closed > 0 and $baseline_closed > 0) ? sprintf "%0.2f", ($cur_pct - $baseline_pct) : 0;
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_PCT_DIF}{HTML} = ($cur_closed > 0 and $baseline_closed > 0) ? $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_PCT_DIF}{VALUE} ."%" : "-";
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_PCT_DIF}{COLOR} = $green if($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_PCT_DIF}{VALUE} < 0);
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_PCT_DIF}{COLOR} = $red if($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_PCT_DIF}{VALUE} > 0);
	
			# Normal Minor
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_MINOR_COUNT_BASELINE}{HTML} = ($baseline_normal_minor > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&customer=$customer&center=$center&cap=$cap&type=NORMAL_MINOR\">$baseline_normal_minor</a>" : 0;
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_BASELINE}{VALUE} = sprintf "%0.2f", ($baseline_normal_minor / $baseline_closed) * 100 if ($baseline_closed > 0);
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_BASELINE}{HTML} = ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_BASELINE}{VALUE} ne "") ? $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_BASELINE}{VALUE} ."\%" : "-";
	
			$baseline_pct = $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_BASELINE}{VALUE} || 0;
			$cur_pct = $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_CUR}{VALUE} || 0;
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_DIF}{VALUE} = ($cur_closed > 0 and $baseline_closed > 0) ? sprintf "%0.2f", ($cur_pct - $baseline_pct) : 0;
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_DIF}{HTML} = ($cur_closed > 0 and $baseline_closed > 0) ? $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_DIF}{VALUE} ."%" : "-";
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_DIF}{COLOR} = $red if($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_DIF}{VALUE} < 0);
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_DIF}{COLOR} = $green if($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_DIF}{VALUE} > 0);
	
			# Success
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{SUCCESS_COUNT_BASELINE}{HTML} = ($baseline_success > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&customer=$customer&center=$center&cap=$cap&type=SUCCESS\">$baseline_success</a>" : 0;
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{SUCCESS_PCT_BASELINE}{VALUE} = sprintf "%0.2f", ($baseline_success / $baseline_closed) * 100 if ($baseline_closed > 0);
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{SUCCESS_PCT_BASELINE}{HTML} = ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{SUCCESS_PCT_BASELINE}{VALUE} ne "") ? $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{SUCCESS_PCT_BASELINE}{VALUE} ."\%" : "-";
	
			$baseline_pct = $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{SUCCESS_PCT_BASELINE}{VALUE} || 0;
			$cur_pct = $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{SUCCESS_PCT_CUR}{VALUE} || 0;
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{SUCCESS_PCT_DIF}{VALUE} = ($cur_closed > 0 and $baseline_closed > 0) ? sprintf "%0.2f", ($cur_pct - $baseline_pct) : 0;
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{SUCCESS_PCT_DIF}{HTML} = ($cur_closed > 0 and $baseline_closed > 0) ? $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{SUCCESS_PCT_DIF}{VALUE} ."%" : "-";
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{SUCCESS_PCT_DIF}{COLOR} = $red if($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{SUCCESS_PCT_DIF}{VALUE} < 0);
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{SUCCESS_PCT_DIF}{COLOR} = $green if($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{SUCCESS_PCT_DIF}{VALUE} > 0);
			
			# Failed
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{FAILED_COUNT_BASELINE}{HTML} = ($baseline_failed > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&customer=$customer&center=$center&cap=$cap&type=FAILED\">$baseline_failed</a>" : 0;
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{FAILED_PCT_BASELINE}{VALUE} = sprintf "%0.2f", ($baseline_failed / $baseline_closed) * 100 if ($baseline_closed > 0);
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{FAILED_PCT_BASELINE}{HTML} = ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{FAILED_PCT_BASELINE}{VALUE} ne "") ? $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{FAILED_PCT_BASELINE}{VALUE} ."\%" : "-";
	
			$baseline_pct = $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{FAILED_PCT_BASELINE}{VALUE} || 0;
			$cur_pct = $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{FAILED_PCT_CUR}{VALUE} || 0;
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{FAILED_PCT_DIF}{VALUE} = ($cur_closed > 0 and $baseline_closed > 0) ? sprintf "%0.2f", ($cur_pct - $baseline_pct) : 0;
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{FAILED_PCT_DIF}{HTML} = ($cur_closed > 0 and $baseline_closed > 0) ? $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{FAILED_PCT_DIF}{VALUE} ."%" : "-";
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{FAILED_PCT_DIF}{COLOR} = $green if($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{FAILED_PCT_DIF}{VALUE} < 0);
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{FAILED_PCT_DIF}{COLOR} = $red if($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{FAILED_PCT_DIF}{VALUE} > 0);
			
			# Failed Standard
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_FAILED_COUNT_BASELINE}{HTML} = ($baseline_std_failed > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&customer=$customer&center=$center&cap=$cap&type=STD_FAILED\">$baseline_std_failed</a>" : 0;
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_FAILED_PCT_BASELINE}{VALUE} = sprintf "%0.2f", ($baseline_std_failed / $baseline_closed) * 100 if ($baseline_closed > 0);
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_FAILED_PCT_BASELINE}{HTML} = ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_FAILED_PCT_BASELINE}{VALUE} ne "") ? $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_FAILED_PCT_BASELINE}{VALUE} ."\%" : "-";
	
			$baseline_pct = $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_FAILED_PCT_BASELINE}{VALUE} || 0;
			$cur_pct = $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_FAILED_PCT_CUR}{VALUE} || 0;
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_FAILED_PCT_DIF}{VALUE} = ($cur_closed > 0 and $baseline_closed > 0) ? sprintf "%0.2f", ($cur_pct - $baseline_pct) : 0;
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_FAILED_PCT_DIF}{HTML} = ($cur_closed > 0 and $baseline_closed > 0) ? $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_FAILED_PCT_DIF}{VALUE} ."%" : "-";
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_FAILED_PCT_DIF}{COLOR} = $green if($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_FAILED_PCT_DIF}{VALUE} < 0);
			$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_FAILED_PCT_DIF}{COLOR} = $red if($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{STD_FAILED_PCT_DIF}{VALUE} > 0);
		
			#########################################################
			# Calculate graph metric percentages for last 18 months 
			#########################################################
			for my $x (1..18) {
			
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"CLOSED_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"CLOSED_COUNT_M${x}"}{VALUE});
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE});
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"FAILED_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE});
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"STD_FAILED_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE});
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"STD_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE});
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"STD_MINOR_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE});
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"NORMAL_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE});
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"NORMAL_MINOR_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE});
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"CLOSED_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"CLOSED_COUNT_M${x}"}{VALUE});
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"SUCCESS_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"SUCCESS_COUNT_M${x}"}{VALUE});
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"FAILED_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"SUCCESS_COUNT_M${x}"}{VALUE});
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"STD_FAILED_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"SUCCESS_COUNT_M${x}"}{VALUE});
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"STD_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"SUCCESS_COUNT_M${x}"}{VALUE});
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"STD_MINOR_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"SUCCESS_COUNT_M${x}"}{VALUE});
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"NORMAL_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"SUCCESS_COUNT_M${x}"}{VALUE});
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"NORMAL_MINOR_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"SUCCESS_COUNT_M${x}"}{VALUE});
			
				my $cap_closed_cnt = $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"CLOSED_COUNT_M${x}"}{VALUE} || 0;
				my $all_closed_cnt = $l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"CLOSED_COUNT_M${x}"}{VALUE} || 0;
				
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"SUCCESS_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE} / $cap_closed_cnt) * 100 if ($cap_closed_cnt > 0);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"SUCCESS_PCT_M${x}"}{VALUE} = '0.00' if ($cap_closed_cnt == 0);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"FAILED_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"FAILED_COUNT_M${x}"}{VALUE} / $cap_closed_cnt) * 100 if ($cap_closed_cnt > 0);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"FAILED_PCT_M${x}"}{VALUE} = '0.00' if ($cap_closed_cnt == 0);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"STD_FAILED_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"STD_FAILED_COUNT_M${x}"}{VALUE} / $cap_closed_cnt) * 100 if ($cap_closed_cnt > 0);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"STD_FAILED_PCT_M${x}"}{VALUE} = '0.00' if ($cap_closed_cnt == 0);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"STD_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"STD_COUNT_M${x}"}{VALUE} / $cap_closed_cnt) * 100 if ($cap_closed_cnt > 0);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"STD_PCT_M${x}"}{VALUE} = '0.00' if ($cap_closed_cnt == 0);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"STD_MINOR_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"STD_MINOR_COUNT_M${x}"}{VALUE} / $cap_closed_cnt) * 100 if ($cap_closed_cnt > 0);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"STD_MINOR_PCT_M${x}"}{VALUE} = '0.00' if ($cap_closed_cnt == 0);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"NORMAL_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"NORMAL_COUNT_M${x}"}{VALUE} / $cap_closed_cnt) * 100 if ($cap_closed_cnt > 0);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"NORMAL_PCT_M${x}"}{VALUE} = '0.00' if ($cap_closed_cnt == 0);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"NORMAL_MINOR_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"NORMAL_MINOR_COUNT_M${x}"}{VALUE} / $cap_closed_cnt) * 100 if ($cap_closed_cnt > 0);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$cap}{"NORMAL_MINOR_PCT_M${x}"}{VALUE} = '0.00' if ($cap_closed_cnt == 0);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"SUCCESS_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"SUCCESS_COUNT_M${x}"}{VALUE} / $all_closed_cnt) * 100 if ($all_closed_cnt > 0);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"SUCCESS_PCT_M${x}"}{VALUE} = '0.00' if ($all_closed_cnt == 0);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"FAILED_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"FAILED_COUNT_M${x}"}{VALUE} / $all_closed_cnt) * 100 if ($all_closed_cnt > 0);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"FAILED_PCT_M${x}"}{VALUE} = '0.00' if ($all_closed_cnt == 0);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"STD_FAILED_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"STD_FAILED_COUNT_M${x}"}{VALUE} / $all_closed_cnt) * 100 if ($all_closed_cnt > 0);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"STD_FAILED_PCT_M${x}"}{VALUE} = '0.00' if ($all_closed_cnt == 0);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"STD_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"STD_COUNT_M${x}"}{VALUE} / $all_closed_cnt) * 100 if ($all_closed_cnt > 0);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"STD_PCT_M${x}"}{VALUE} = '0.00' if ($all_closed_cnt == 0);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"STD_MINOR_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"STD_MINOR_COUNT_M${x}"}{VALUE} / $all_closed_cnt) * 100 if ($all_closed_cnt > 0);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"STD_MINOR_PCT_M${x}"}{VALUE} = '0.00' if ($all_closed_cnt == 0);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"NORMAL_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"NORMAL_COUNT_M${x}"}{VALUE} / $all_closed_cnt) * 100 if ($all_closed_cnt > 0);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"NORMAL_PCT_M${x}"}{VALUE} = '0.00' if ($all_closed_cnt == 0);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"NORMAL_MINOR_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"NORMAL_MINOR_COUNT_M${x}"}{VALUE} / $all_closed_cnt) * 100 if ($all_closed_cnt > 0);
				$l2_bionics{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{ALL}{"NORMAL_MINOR_PCT_M${x}"}{VALUE} = '0.00' if ($all_closed_cnt == 0);
			
			} # Monthly Percntages for Graphs
		}
	}
}

###############################################################
# Calculate percentages and changes for Region metrics
###############################################################
foreach my $region (keys %{$l2_bionics{DXC_REGION}}) {
	foreach my $cap (keys %{$l2_bionics{DXC_REGION}{$region}{CAPABILITY}}) {
		##########################
		# Current Metrics
		##########################
		my $cur_closed = $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{CLOSED_COUNT_CUR}{VALUE} || 0;
		my $cur_std = $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_COUNT_CUR}{VALUE} || 0;
		my $cur_std_minor = $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_MINOR_COUNT_CUR}{VALUE} || 0;
		my $cur_normal = $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_COUNT_CUR}{VALUE} || 0;
		my $cur_normal_minor = $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_MINOR_COUNT_CUR}{VALUE} || 0;
		my $cur_success= $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{SUCCESS_COUNT_CUR}{VALUE} || 0;
		my $cur_failed= $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{FAILED_COUNT_CUR}{VALUE} || 0;
		my $cur_std_failed= $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_FAILED_COUNT_CUR}{VALUE} || 0;
	
		# Closed
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{CLOSED_COUNT_CUR}{HTML} = ($cur_closed > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&dxc_region=$region&cap=$cap&type=CLOSED\">$cur_closed</a>" : 0;
	
		# Standard
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_COUNT_CUR}{HTML} = ($cur_std > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&dxc_region=$region&cap=$cap&type=STD\">$cur_std</a>" : 0;
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_PCT_CUR}{VALUE} = sprintf "%0.2f", ($cur_std / $cur_closed) * 100 if ($cur_closed > 0);
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_PCT_CUR}{HTML} = ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_PCT_CUR}{VALUE} ne "") ? $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_PCT_CUR}{VALUE} ."\%" : "-";
	
		# Standard Minor
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_MINOR_COUNT_CUR}{HTML} = ($cur_std_minor > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&dxc_region=$region&cap=$cap&type=STD_MINOR\">$cur_std_minor</a>" : 0;
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{VALUE} = sprintf "%0.2f", ($cur_std_minor / $cur_closed) * 100 if ($cur_closed > 0);
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{HTML} = ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{VALUE} ne "") ? $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{VALUE} ."\%" : "-";
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{COLOR} = $green if ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{VALUE} > 35);
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{COLOR} = $amber if ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{VALUE} > 0 and $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{VALUE} <= 35);
	
		# Normal
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_COUNT_CUR}{HTML} = ($cur_normal > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&dxc_region=$region&cap=$cap&type=NORMAL\">$cur_normal</a>" : 0;
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_PCT_CUR}{VALUE} = sprintf "%0.2f", ($cur_normal / $cur_closed) * 100 if ($cur_closed > 0);
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_PCT_CUR}{HTML} = ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_PCT_CUR}{VALUE} ne "") ? $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_PCT_CUR}{VALUE} ."\%" : "-";
	
		# Normal Minor
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_MINOR_COUNT_CUR}{HTML} = ($cur_normal_minor > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&dxc_region=$region&cap=$cap&type=NORMAL_MINOR\">$cur_normal_minor</a>" : 0;
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_CUR}{VALUE} = sprintf "%0.2f", ($cur_normal_minor / $cur_closed) * 100 if ($cur_closed > 0);
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_CUR}{HTML} = ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_CUR}{VALUE} ne "") ? $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_CUR}{VALUE} ."\%" : "-";
	
		# Success
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{SUCCESS_COUNT_CUR}{HTML} = ($cur_success > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&dxc_region=$region&cap=$cap&type=SUCCESS\">$cur_success</a>" : 0;
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{SUCCESS_PCT_CUR}{VALUE} = sprintf "%0.2f", ($cur_success / $cur_closed) * 100 if ($cur_closed > 0);
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{SUCCESS_PCT_CUR}{HTML} = ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{SUCCESS_PCT_CUR}{VALUE} ne "") ? $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{SUCCESS_PCT_CUR}{VALUE} ."\%" : "-";
	
		# Failed Standard
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{FAILED_COUNT_CUR}{HTML} = ($cur_failed > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&dxc_region=$region&cap=$cap&type=FAILED\">$cur_failed</a>" : 0;
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{FAILED_PCT_CUR}{VALUE} = sprintf "%0.2f", ($cur_failed / $cur_closed) * 100 if ($cur_closed > 0);
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{FAILED_PCT_CUR}{HTML} = ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{FAILED_PCT_CUR}{VALUE} ne "") ? $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{FAILED_PCT_CUR}{VALUE} ."\%" : "-";
	
		# Failed Standard
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_FAILED_COUNT_CUR}{HTML} = ($cur_std_failed > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&dxc_region=$region&cap=$cap&type=STD_FAILED\">$cur_std_failed</a>" : 0;
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_FAILED_PCT_CUR}{VALUE} = sprintf "%0.2f", ($cur_std_failed / $cur_closed) * 100 if ($cur_closed > 0);
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_FAILED_PCT_CUR}{HTML} = ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_FAILED_PCT_CUR}{VALUE} ne "") ? $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_FAILED_PCT_CUR}{VALUE} ."\%" : "-";
	
		##########################
		# Baseline Metrics
		##########################
		my $baseline_closed = $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{CLOSED_COUNT_BASELINE}{VALUE} || 0;
		my $baseline_std = $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_COUNT_BASELINE}{VALUE} || 0;
		my $baseline_std_minor = $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_MINOR_COUNT_BASELINE}{VALUE} || 0;
		my $baseline_normal = $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_COUNT_BASELINE}{VALUE} || 0;
		my $baseline_normal_minor = $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_MINOR_COUNT_BASELINE}{VALUE} || 0;
		my $baseline_success= $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{SUCCESS_COUNT_BASELINE}{VALUE} || 0;
		my $baseline_failed= $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{FAILED_COUNT_BASELINE}{VALUE} || 0;
		my $baseline_std_failed= $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_FAILED_COUNT_BASELINE}{VALUE} || 0;
	
		# Closed
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{CLOSED_COUNT_BASELINE}{HTML} = ($baseline_closed > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&dxc_region=$region&cap=$cap&type=CLOSED\">$baseline_closed</a>" : 0;
	
		# Standard
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_COUNT_BASELINE}{HTML} = ($baseline_std > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&dxc_region=$region&cap=$cap&type=STD\">$baseline_std</a>" : 0;
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_PCT_BASELINE}{VALUE} = sprintf "%0.2f", ($baseline_std / $baseline_closed) * 100 if ($baseline_closed > 0);
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_PCT_BASELINE}{HTML} = ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_PCT_BASELINE}{VALUE} ne "") ? $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_PCT_BASELINE}{VALUE} ."\%" : "-";
	
		my $baseline_pct = $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_PCT_BASELINE}{VALUE} || 0;
		my $cur_pct = $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_PCT_CUR}{VALUE} || 0;
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_PCT_DIF}{VALUE} = ($cur_closed > 0 and $baseline_closed > 0) ? sprintf "%0.2f", ($cur_pct - $baseline_pct) : 0;
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_PCT_DIF}{HTML} = ($cur_closed > 0 and $baseline_closed > 0) ? $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_PCT_DIF}{VALUE} ."%" : "-";
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_PCT_DIF}{COLOR} = $red if($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_PCT_DIF}{VALUE} < 0);
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_PCT_DIF}{COLOR} = $green if($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_PCT_DIF}{VALUE} > 0);
	
		# Standard Minor
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_MINOR_COUNT_BASELINE}{HTML} = ($baseline_std_minor > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&dxc_region=$region&cap=$cap&type=STD_MINOR\">$baseline_std_minor</a>" : 0;
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_MINOR_PCT_BASELINE}{VALUE} = sprintf "%0.2f", ($baseline_std_minor / $baseline_closed) * 100 if ($baseline_closed > 0);
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_MINOR_PCT_BASELINE}{HTML} = ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_MINOR_PCT_BASELINE}{VALUE} ne "") ? $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_MINOR_PCT_BASELINE}{VALUE} ."\%" : "-";
	
		$baseline_pct = $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_MINOR_PCT_BASELINE}{VALUE} || 0;
		$cur_pct = $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{VALUE} || 0;
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_MINOR_PCT_DIF}{VALUE} = ($cur_closed > 0 and $baseline_closed > 0) ? sprintf "%0.2f", ($cur_pct - $baseline_pct) : 0;
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_MINOR_PCT_DIF}{HTML} = ($cur_closed > 0 and $baseline_closed > 0) ? $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_MINOR_PCT_DIF}{VALUE} ."%" : "-";
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_MINOR_PCT_DIF}{COLOR} = $red if($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_MINOR_PCT_DIF}{VALUE} < 0);
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_MINOR_PCT_DIF}{COLOR} = $green if($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_MINOR_PCT_DIF}{VALUE} > 0);
	
		# Normal
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_COUNT_BASELINE}{HTML} = ($baseline_std > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&dxc_region=$region&cap=$cap&type=NORMAL\">$baseline_normal</a>" : 0;
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_PCT_BASELINE}{VALUE} = sprintf "%0.2f", ($baseline_normal / $baseline_closed) * 100 if ($baseline_closed > 0);
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_PCT_BASELINE}{HTML} = ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_PCT_BASELINE}{VALUE} ne "") ? $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_PCT_BASELINE}{VALUE} ."\%" : "-";
	
		$baseline_pct = $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_PCT_BASELINE}{VALUE} || 0;
		$cur_pct = $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_PCT_CUR}{VALUE} || 0;
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_PCT_DIF}{VALUE} = ($cur_closed > 0 and $baseline_closed > 0) ? sprintf "%0.2f", ($cur_pct - $baseline_pct) : 0;
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_PCT_DIF}{HTML} = ($cur_closed > 0 and $baseline_closed > 0) ? $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_PCT_DIF}{VALUE} ."%" : "-";
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_PCT_DIF}{COLOR} = $green if($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_PCT_DIF}{VALUE} < 0);
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_PCT_DIF}{COLOR} = $red if($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_PCT_DIF}{VALUE} > 0);
	
		# Normal Minor
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_MINOR_COUNT_BASELINE}{HTML} = ($baseline_normal_minor > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&dxc_region=$region&cap=$cap&type=NORMAL_MINOR\">$baseline_normal_minor</a>" : 0;
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_BASELINE}{VALUE} = sprintf "%0.2f", ($baseline_normal_minor / $baseline_closed) * 100 if ($baseline_closed > 0);
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_BASELINE}{HTML} = ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_BASELINE}{VALUE} ne "") ? $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_BASELINE}{VALUE} ."\%" : "-";
	
		$baseline_pct = $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_BASELINE}{VALUE} || 0;
		$cur_pct = $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_CUR}{VALUE} || 0;
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_DIF}{VALUE} = ($cur_closed > 0 and $baseline_closed > 0) ? sprintf "%0.2f", ($cur_pct - $baseline_pct) : 0;
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_DIF}{HTML} = ($cur_closed > 0 and $baseline_closed > 0) ? $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_DIF}{VALUE} ."%" : "-";
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_DIF}{COLOR} = $red if($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_DIF}{VALUE} < 0);
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_DIF}{COLOR} = $green if($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_DIF}{VALUE} > 0);
	
		# Success
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{SUCCESS_COUNT_BASELINE}{HTML} = ($baseline_success > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&dxc_region=$region&cap=$cap&type=SUCCESS\">$baseline_success</a>" : 0;
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{SUCCESS_PCT_BASELINE}{VALUE} = sprintf "%0.2f", ($baseline_success / $baseline_closed) * 100 if ($baseline_closed > 0);
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{SUCCESS_PCT_BASELINE}{HTML} = ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{SUCCESS_PCT_BASELINE}{VALUE} ne "") ? $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{SUCCESS_PCT_BASELINE}{VALUE} ."\%" : "-";
	
		$baseline_pct = $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{SUCCESS_PCT_BASELINE}{VALUE} || 0;
		$cur_pct = $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{SUCCESS_PCT_CUR}{VALUE} || 0;
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{SUCCESS_PCT_DIF}{VALUE} = ($cur_closed > 0 and $baseline_closed > 0) ? sprintf "%0.2f", ($cur_pct - $baseline_pct) : 0;
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{SUCCESS_PCT_DIF}{HTML} = ($cur_closed > 0 and $baseline_closed > 0) ? $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{SUCCESS_PCT_DIF}{VALUE} ."%" : "-";
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{SUCCESS_PCT_DIF}{COLOR} = $red if($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{SUCCESS_PCT_DIF}{VALUE} < 0);
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{SUCCESS_PCT_DIF}{COLOR} = $green if($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{SUCCESS_PCT_DIF}{VALUE} > 0);
	
		# Failed
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{FAILED_COUNT_BASELINE}{HTML} = ($baseline_failed > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&dxc_region=$region&cap=$cap&type=FAILED\">$baseline_failed</a>" : 0;
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{FAILED_PCT_BASELINE}{VALUE} = sprintf "%0.2f", ($baseline_failed / $baseline_closed) * 100 if ($baseline_closed > 0);
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{FAILED_PCT_BASELINE}{HTML} = ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{FAILED_PCT_BASELINE}{VALUE} ne "") ? $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{FAILED_PCT_BASELINE}{VALUE} ."\%" : "-";
	
		$baseline_pct = $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{FAILED_PCT_BASELINE}{VALUE} || 0;
		$cur_pct = $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{FAILED_PCT_CUR}{VALUE} || 0;
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{FAILED_PCT_DIF}{VALUE} = ($cur_closed > 0 and $baseline_closed > 0) ? sprintf "%0.2f", ($cur_pct - $baseline_pct) : 0;
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{FAILED_PCT_DIF}{HTML} = ($cur_closed > 0 and $baseline_closed > 0) ? $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{FAILED_PCT_DIF}{VALUE} ."%" : "-";
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{FAILED_PCT_DIF}{COLOR} = $green if($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{FAILED_PCT_DIF}{VALUE} < 0);
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{FAILED_PCT_DIF}{COLOR} = $red if($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{FAILED_PCT_DIF}{VALUE} > 0);
		
		# Failed Standard
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_FAILED_COUNT_BASELINE}{HTML} = ($baseline_std_failed > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&dxc_region=$region&cap=$cap&type=STD_FAILED\">$baseline_std_failed</a>" : 0;
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_FAILED_PCT_BASELINE}{VALUE} = sprintf "%0.2f", ($baseline_std_failed / $baseline_closed) * 100 if ($baseline_closed > 0);
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_FAILED_PCT_BASELINE}{HTML} = ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_FAILED_PCT_BASELINE}{VALUE} ne "") ? $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_FAILED_PCT_BASELINE}{VALUE} ."\%" : "-";
	
		$baseline_pct = $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_FAILED_PCT_BASELINE}{VALUE} || 0;
		$cur_pct = $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_FAILED_PCT_CUR}{VALUE} || 0;
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_FAILED_PCT_DIF}{VALUE} = ($cur_closed > 0 and $baseline_closed > 0) ? sprintf "%0.2f", ($cur_pct - $baseline_pct) : 0;
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_FAILED_PCT_DIF}{HTML} = ($cur_closed > 0 and $baseline_closed > 0) ? $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_FAILED_PCT_DIF}{VALUE} ."%" : "-";
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_FAILED_PCT_DIF}{COLOR} = $green if($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_FAILED_PCT_DIF}{VALUE} < 0);
		$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_FAILED_PCT_DIF}{COLOR} = $red if($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{STD_FAILED_PCT_DIF}{VALUE} > 0);
		
		#########################################################
		# Calculate graph metric percentages for last 18 months 
		#########################################################
		for my $x (1..18) {
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"CLOSED_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"CLOSED_COUNT_M${x}"}{VALUE});
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE});
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"FAILED_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE});
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"STD_FAILED_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE});
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"STD_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE});
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"STD_MINOR_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE});
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"NORMAL_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE});
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"NORMAL_MINOR_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE});
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"CLOSED_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"CLOSED_COUNT_M${x}"}{VALUE});
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"SUCCESS_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"SUCCESS_COUNT_M${x}"}{VALUE});
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"FAILED_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"SUCCESS_COUNT_M${x}"}{VALUE});
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"STD_FAILED_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"SUCCESS_COUNT_M${x}"}{VALUE});
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"STD_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"SUCCESS_COUNT_M${x}"}{VALUE});
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"STD_MINOR_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"SUCCESS_COUNT_M${x}"}{VALUE});
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"NORMAL_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"SUCCESS_COUNT_M${x}"}{VALUE});
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"NORMAL_MINOR_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"SUCCESS_COUNT_M${x}"}{VALUE});
			
			my $cap_closed_cnt = $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"CLOSED_COUNT_M${x}"}{VALUE} || 0;
			my $all_closed_cnt = $l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"CLOSED_COUNT_M${x}"}{VALUE} || 0;
				
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"SUCCESS_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE} / $cap_closed_cnt) * 100 if ($cap_closed_cnt > 0);
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"SUCCESS_PCT_M${x}"}{VALUE} = '0.00' if ($cap_closed_cnt == 0);
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"FAILED_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"FAILED_COUNT_M${x}"}{VALUE} / $cap_closed_cnt) * 100 if ($cap_closed_cnt > 0);
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"FAILED_PCT_M${x}"}{VALUE} = '0.00' if ($cap_closed_cnt == 0);
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"STD_FAILED_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"STD_FAILED_COUNT_M${x}"}{VALUE} / $cap_closed_cnt) * 100 if ($cap_closed_cnt > 0);
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"STD_FAILED_PCT_M${x}"}{VALUE} = '0.00' if ($cap_closed_cnt == 0);
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"STD_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"STD_COUNT_M${x}"}{VALUE} / $cap_closed_cnt) * 100 if ($cap_closed_cnt > 0);
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"STD_PCT_M${x}"}{VALUE} = 			'0.00' if ($cap_closed_cnt == 0);
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"STD_MINOR_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"STD_MINOR_COUNT_M${x}"}{VALUE} / $cap_closed_cnt) * 100 if ($cap_closed_cnt > 0);
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"STD_MINOR_PCT_M${x}"}{VALUE} = '0.00' if ($cap_closed_cnt == 0);
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"NORMAL_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"NORMAL_COUNT_M${x}"}{VALUE} / $cap_closed_cnt) * 100 if ($cap_closed_cnt > 0);
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"NORMAL_PCT_M${x}"}{VALUE} = '0.00' if ($cap_closed_cnt == 0);
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"NORMAL_MINOR_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"NORMAL_MINOR_COUNT_M${x}"}{VALUE} / $cap_closed_cnt) * 100 if ($cap_closed_cnt > 0);
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{$cap}{"NORMAL_MINOR_PCT_M${x}"}{VALUE} = '0.00' if ($cap_closed_cnt == 0);
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"SUCCESS_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"SUCCESS_COUNT_M${x}"}{VALUE} / $all_closed_cnt) * 100 if ($all_closed_cnt > 0);
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"SUCCESS_PCT_M${x}"}{VALUE} = '0.00' if ($all_closed_cnt == 0);
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"FAILED_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"FAILED_COUNT_M${x}"}{VALUE} / $all_closed_cnt) * 100 if ($all_closed_cnt > 0);
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"FAILED_PCT_M${x}"}{VALUE} = '0.00' if ($all_closed_cnt == 0);
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"STD_FAILED_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"STD_FAILED_COUNT_M${x}"}{VALUE} / $all_closed_cnt) * 100 if ($all_closed_cnt > 0);
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"STD_FAILED_PCT_M${x}"}{VALUE} = '0.00' if ($all_closed_cnt == 0);
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"STD_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"STD_COUNT_M${x}"}{VALUE} / $all_closed_cnt) * 100 if ($all_closed_cnt > 0);
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"STD_PCT_M${x}"}{VALUE} = '0.00' if ($all_closed_cnt == 0);
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"STD_MINOR_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"STD_MINOR_COUNT_M${x}"}{VALUE} / $all_closed_cnt) * 100 if ($all_closed_cnt > 0);
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"STD_MINOR_PCT_M${x}"}{VALUE} = '0.00' if ($all_closed_cnt == 0);
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"NORMAL_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"NORMAL_COUNT_M${x}"}{VALUE} / $all_closed_cnt) * 100 if ($all_closed_cnt > 0);
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"NORMAL_PCT_M${x}"}{VALUE} = 			'0.00' if ($all_closed_cnt == 0);
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"NORMAL_MINOR_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"NORMAL_MINOR_COUNT_M${x}"}{VALUE} / $all_closed_cnt) * 100 if ($all_closed_cnt > 0);
			$l2_bionics{DXC_REGION}{$region}{CAPABILITY}{ALL}{"NORMAL_MINOR_PCT_M${x}"}{VALUE} = '0.00' if ($all_closed_cnt == 0);
				
		} # Monthly Percntages for Graphs
	}
}

###############################################################
# Calculate percentages and changes for Capability metrics
###############################################################
foreach my $cap (keys %{$l2_bionics{CAPABILITY}}) {
	##########################
	# Current Metrics
	##########################
	my $cur_closed = $l2_bionics{CAPABILITY}{$cap}{CLOSED_COUNT_CUR}{VALUE} || 0;
	my $cur_std = $l2_bionics{CAPABILITY}{$cap}{STD_COUNT_CUR}{VALUE} || 0;
	my $cur_std_minor = $l2_bionics{CAPABILITY}{$cap}{STD_MINOR_COUNT_CUR}{VALUE} || 0;
	my $cur_normal = $l2_bionics{CAPABILITY}{$cap}{NORMAL_COUNT_CUR}{VALUE} || 0;
	my $cur_normal_minor = $l2_bionics{CAPABILITY}{$cap}{NORMAL_MINOR_COUNT_CUR}{VALUE} || 0;
	my $cur_success= $l2_bionics{CAPABILITY}{$cap}{SUCCESS_COUNT_CUR}{VALUE} || 0;
	my $cur_failed= $l2_bionics{CAPABILITY}{$cap}{FAILED_COUNT_CUR}{VALUE} || 0;
	my $cur_std_failed= $l2_bionics{CAPABILITY}{$cap}{STD_FAILED_COUNT_CUR}{VALUE} || 0;
	
	# Closed
	$l2_bionics{CAPABILITY}{$cap}{CLOSED_COUNT_CUR}{HTML} = ($cur_closed > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&cap=$cap&type=CLOSED\">$cur_closed</a>" : 0;
	
	# Standard
	$l2_bionics{CAPABILITY}{$cap}{STD_COUNT_CUR}{HTML} = ($cur_std > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&cap=$cap&type=STD\">$cur_std</a>" : 0;
	$l2_bionics{CAPABILITY}{$cap}{STD_PCT_CUR}{VALUE} = sprintf "%0.2f", ($cur_std / $cur_closed) * 100 if ($cur_closed > 0);
	$l2_bionics{CAPABILITY}{$cap}{STD_PCT_CUR}{HTML} = ($l2_bionics{CAPABILITY}{$cap}{STD_PCT_CUR}{VALUE} ne "") ? $l2_bionics{CAPABILITY}{$cap}{STD_PCT_CUR}{VALUE} ."\%" : "-";
	
	# Standard Minor
	$l2_bionics{CAPABILITY}{$cap}{STD_MINOR_COUNT_CUR}{HTML} = ($cur_std_minor > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&cap=$cap&type=STD_MINOR\">$cur_std_minor</a>" : 0;
	$l2_bionics{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{VALUE} = sprintf "%0.2f", ($cur_std_minor / $cur_closed) * 100 if ($cur_closed > 0);
	$l2_bionics{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{HTML} = ($l2_bionics{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{VALUE} ne "") ? $l2_bionics{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{VALUE} ."\%" : "-";
	$l2_bionics{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{COLOR} = $green if ($l2_bionics{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{VALUE} > 35);
	$l2_bionics{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{COLOR} = $amber if ($l2_bionics{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{VALUE} > 0 and $l2_bionics{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{VALUE} <= 35);
	
	# Normal
	$l2_bionics{CAPABILITY}{$cap}{NORMAL_COUNT_CUR}{HTML} = ($cur_normal > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&cap=$cap&type=NORMAL\">$cur_normal</a>" : 0;
	$l2_bionics{CAPABILITY}{$cap}{NORMAL_PCT_CUR}{VALUE} = sprintf "%0.2f", ($cur_normal / $cur_closed) * 100 if ($cur_closed > 0);
	$l2_bionics{CAPABILITY}{$cap}{NORMAL_PCT_CUR}{HTML} = ($l2_bionics{CAPABILITY}{$cap}{NORMAL_PCT_CUR}{VALUE} ne "") ? $l2_bionics{CAPABILITY}{$cap}{NORMAL_PCT_CUR}{VALUE} ."\%" : "-";
	
	# Normal Minor
	$l2_bionics{CAPABILITY}{$cap}{NORMAL_MINOR_COUNT_CUR}{HTML} = ($cur_normal_minor > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&cap=$cap&type=NORMAL_MINOR\">$cur_normal_minor</a>" : 0;
	$l2_bionics{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_CUR}{VALUE} = sprintf "%0.2f", ($cur_normal_minor / $cur_closed) * 100 if ($cur_closed > 0);
	$l2_bionics{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_CUR}{HTML} = ($l2_bionics{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_CUR}{VALUE} ne "") ? $l2_bionics{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_CUR}{VALUE} ."\%" : "-";
	
	# Success
	$l2_bionics{CAPABILITY}{$cap}{SUCCESS_COUNT_CUR}{HTML} = ($cur_success > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&cap=$cap&type=SUCCESS\">$cur_success</a>" : 0;
	$l2_bionics{CAPABILITY}{$cap}{SUCCESS_PCT_CUR}{VALUE} = sprintf "%0.2f", ($cur_success / $cur_closed) * 100 if ($cur_closed > 0);
	$l2_bionics{CAPABILITY}{$cap}{SUCCESS_PCT_CUR}{HTML} = ($l2_bionics{CAPABILITY}{$cap}{SUCCESS_PCT_CUR}{VALUE} ne "") ? $l2_bionics{CAPABILITY}{$cap}{SUCCESS_PCT_CUR}{VALUE} ."\%" : "-";
	
	# Failed
	$l2_bionics{CAPABILITY}{$cap}{FAILED_COUNT_CUR}{HTML} = ($cur_std_failed > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&cap=$cap&type=FAILED\">$cur_failed</a>" : 0;
	$l2_bionics{CAPABILITY}{$cap}{FAILED_PCT_CUR}{VALUE} = sprintf "%0.2f", ($cur_failed / $cur_closed) * 100 if ($cur_closed > 0);
	$l2_bionics{CAPABILITY}{$cap}{FAILED_PCT_CUR}{HTML} = ($l2_bionics{CAPABILITY}{$cap}{FAILED_PCT_CUR}{VALUE} ne "") ? $l2_bionics{CAPABILITY}{$cap}{FAILED_PCT_CUR}{VALUE} ."\%" : "-";
	
	# Failed Standard
	$l2_bionics{CAPABILITY}{$cap}{STD_FAILED_COUNT_CUR}{HTML} = ($cur_std_failed > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=CURRENT&cap=$cap&type=STD_FAILED\">$cur_std_failed</a>" : 0;
	$l2_bionics{CAPABILITY}{$cap}{STD_FAILED_PCT_CUR}{VALUE} = sprintf "%0.2f", ($cur_std_failed / $cur_closed) * 100 if ($cur_closed > 0);
	$l2_bionics{CAPABILITY}{$cap}{STD_FAILED_PCT_CUR}{HTML} = ($l2_bionics{CAPABILITY}{$cap}{STD_FAILED_PCT_CUR}{VALUE} ne "") ? $l2_bionics{CAPABILITY}{$cap}{STD_FAILED_PCT_CUR}{VALUE} ."\%" : "-";
	
	##########################
	# Baseline Metrics
	##########################
	my $baseline_closed = $l2_bionics{CAPABILITY}{$cap}{CLOSED_COUNT_BASELINE}{VALUE} || 0;
	my $baseline_std = $l2_bionics{CAPABILITY}{$cap}{STD_COUNT_BASELINE}{VALUE} || 0;
	my $baseline_std_minor = $l2_bionics{CAPABILITY}{$cap}{STD_MINOR_COUNT_BASELINE}{VALUE} || 0;
	my $baseline_normal = $l2_bionics{CAPABILITY}{$cap}{NORMAL_COUNT_BASELINE}{VALUE} || 0;
	my $baseline_normal_minor = $l2_bionics{CAPABILITY}{$cap}{NORMAL_MINOR_COUNT_BASELINE}{VALUE} || 0;
	my $baseline_success= $l2_bionics{CAPABILITY}{$cap}{SUCCESS_COUNT_BASELINE}{VALUE} || 0;
	my $baseline_failed= $l2_bionics{CAPABILITY}{$cap}{FAILED_COUNT_BASELINE}{VALUE} || 0;
	my $baseline_std_failed= $l2_bionics{CAPABILITY}{$cap}{STD_FAILED_COUNT_BASELINE}{VALUE} || 0;
	
	# Closed
	$l2_bionics{CAPABILITY}{$cap}{CLOSED_COUNT_BASELINE}{HTML} = ($baseline_closed > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&cap=$cap&type=CLOSED\">$baseline_closed</a>" : 0;
	
	# Standard
	$l2_bionics{CAPABILITY}{$cap}{STD_COUNT_BASELINE}{HTML} = ($baseline_std > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&cap=$cap&type=STD\">$baseline_std</a>" : 0;
	$l2_bionics{CAPABILITY}{$cap}{STD_PCT_BASELINE}{VALUE} = sprintf "%0.2f", ($baseline_std / $baseline_closed) * 100 if ($baseline_closed > 0);
	$l2_bionics{CAPABILITY}{$cap}{STD_PCT_BASELINE}{HTML} = ($l2_bionics{CAPABILITY}{$cap}{STD_PCT_BASELINE}{VALUE} ne "") ? $l2_bionics{CAPABILITY}{$cap}{STD_PCT_BASELINE}{VALUE} ."\%" : "-";
	
	my $baseline_pct = $l2_bionics{CAPABILITY}{$cap}{STD_PCT_BASELINE}{VALUE} || 0;
	my $cur_pct = $l2_bionics{CAPABILITY}{$cap}{STD_PCT_CUR}{VALUE} || 0;
	$l2_bionics{CAPABILITY}{$cap}{STD_PCT_DIF}{VALUE} = ($cur_closed > 0 and $baseline_closed > 0) ? sprintf "%0.2f", ($cur_pct - $baseline_pct) : 0;
	$l2_bionics{CAPABILITY}{$cap}{STD_PCT_DIF}{HTML} = ($cur_closed > 0 and $baseline_closed > 0) ? $l2_bionics{CAPABILITY}{$cap}{STD_PCT_DIF}{VALUE} ."%" : "-";
	$l2_bionics{CAPABILITY}{$cap}{STD_PCT_DIF}{COLOR} = $red if($l2_bionics{CAPABILITY}{$cap}{STD_PCT_DIF}{VALUE} < 0);
	$l2_bionics{CAPABILITY}{$cap}{STD_PCT_DIF}{COLOR} = $green if($l2_bionics{CAPABILITY}{$cap}{STD_PCT_DIF}{VALUE} > 0);
	
	# Standard Minor
	$l2_bionics{CAPABILITY}{$cap}{STD_MINOR_COUNT_BASELINE}{HTML} = ($baseline_std_minor > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&cap=$cap&type=STD_MINOR\">$baseline_std_minor</a>" : 0;
	$l2_bionics{CAPABILITY}{$cap}{STD_MINOR_PCT_BASELINE}{VALUE} = sprintf "%0.2f", ($baseline_std_minor / $baseline_closed) * 100 if ($baseline_closed > 0);
	$l2_bionics{CAPABILITY}{$cap}{STD_MINOR_PCT_BASELINE}{HTML} = ($l2_bionics{CAPABILITY}{$cap}{STD_MINOR_PCT_BASELINE}{VALUE} ne "") ? $l2_bionics{CAPABILITY}{$cap}{STD_MINOR_PCT_BASELINE}{VALUE} ."\%" : "-";
	
	$baseline_pct = $l2_bionics{CAPABILITY}{$cap}{STD_MINOR_PCT_BASELINE}{VALUE} || 0;
	$cur_pct = $l2_bionics{CAPABILITY}{$cap}{STD_MINOR_PCT_CUR}{VALUE} || 0;
	$l2_bionics{CAPABILITY}{$cap}{STD_MINOR_PCT_DIF}{VALUE} = ($cur_closed > 0 and $baseline_closed > 0) ? sprintf "%0.2f", ($cur_pct - $baseline_pct) : 0;
	$l2_bionics{CAPABILITY}{$cap}{STD_MINOR_PCT_DIF}{HTML} = ($cur_closed > 0 and $baseline_closed > 0) ? $l2_bionics{CAPABILITY}{$cap}{STD_MINOR_PCT_DIF}{VALUE} ."%" : "-";
	$l2_bionics{CAPABILITY}{$cap}{STD_MINOR_PCT_DIF}{COLOR} = $red if($l2_bionics{CAPABILITY}{$cap}{STD_MINOR_PCT_DIF}{VALUE} < 0);
	$l2_bionics{CAPABILITY}{$cap}{STD_MINOR_PCT_DIF}{COLOR} = $green if($l2_bionics{CAPABILITY}{$cap}{STD_MINOR_PCT_DIF}{VALUE} > 0);
	
	# Normal
	$l2_bionics{CAPABILITY}{$cap}{NORMAL_COUNT_BASELINE}{HTML} = ($baseline_std > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&cap=$cap&type=NORMAL\">$baseline_normal</a>" : 0;
	$l2_bionics{CAPABILITY}{$cap}{NORMAL_PCT_BASELINE}{VALUE} = sprintf "%0.2f", ($baseline_normal / $baseline_closed) * 100 if ($baseline_closed > 0);
	$l2_bionics{CAPABILITY}{$cap}{NORMAL_PCT_BASELINE}{HTML} = ($l2_bionics{CAPABILITY}{$cap}{NORMAL_PCT_BASELINE}{VALUE} ne "") ? $l2_bionics{CAPABILITY}{$cap}{NORMAL_PCT_BASELINE}{VALUE} ."\%" : "-";
	
	$baseline_pct = $l2_bionics{CAPABILITY}{$cap}{NORMAL_PCT_BASELINE}{VALUE} || 0;
	$cur_pct = $l2_bionics{CAPABILITY}{$cap}{NORMAL_PCT_CUR}{VALUE} || 0;
	$l2_bionics{CAPABILITY}{$cap}{NORMAL_PCT_DIF}{VALUE} = ($cur_closed > 0 and $baseline_closed > 0) ? sprintf "%0.2f", ($cur_pct - $baseline_pct) : 0;
	$l2_bionics{CAPABILITY}{$cap}{NORMAL_PCT_DIF}{HTML} = ($cur_closed > 0 and $baseline_closed > 0) ? $l2_bionics{CAPABILITY}{$cap}{NORMAL_PCT_DIF}{VALUE} ."%" : "-";
	$l2_bionics{CAPABILITY}{$cap}{NORMAL_PCT_DIF}{COLOR} = $green if($l2_bionics{CAPABILITY}{$cap}{NORMAL_PCT_DIF}{VALUE} < 0);
	$l2_bionics{CAPABILITY}{$cap}{NORMAL_PCT_DIF}{COLOR} = $red if($l2_bionics{CAPABILITY}{$cap}{NORMAL_PCT_DIF}{VALUE} > 0);
	
	# Normal Minor
	$l2_bionics{CAPABILITY}{$cap}{NORMAL_MINOR_COUNT_BASELINE}{HTML} = ($baseline_normal_minor > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&cap=$cap&type=NORMAL_MINOR\">$baseline_normal_minor</a>" : 0;
	$l2_bionics{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_BASELINE}{VALUE} = sprintf "%0.2f", ($baseline_normal_minor / $baseline_closed) * 100 if ($baseline_closed > 0);
	$l2_bionics{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_BASELINE}{HTML} = ($l2_bionics{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_BASELINE}{VALUE} ne "") ? $l2_bionics{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_BASELINE}{VALUE} ."\%" : "-";
	
	$baseline_pct = $l2_bionics{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_BASELINE}{VALUE} || 0;
	$cur_pct = $l2_bionics{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_CUR}{VALUE} || 0;
	$l2_bionics{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_DIF}{VALUE} = ($cur_closed > 0 and $baseline_closed > 0) ? sprintf "%0.2f", ($cur_pct - $baseline_pct) : 0;
	$l2_bionics{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_DIF}{HTML} = ($cur_closed > 0 and $baseline_closed > 0) ? $l2_bionics{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_DIF}{VALUE} ."%" : "-";
	$l2_bionics{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_DIF}{COLOR} = $red if($l2_bionics{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_DIF}{VALUE} < 0);
	$l2_bionics{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_DIF}{COLOR} = $green if($l2_bionics{CAPABILITY}{$cap}{NORMAL_MINOR_PCT_DIF}{VALUE} > 0);
	
	# Success
	$l2_bionics{CAPABILITY}{$cap}{SUCCESS_COUNT_BASELINE}{HTML} = ($baseline_success > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&cap=$cap&type=SUCCESS\">$baseline_success</a>" : 0;
	$l2_bionics{CAPABILITY}{$cap}{SUCCESS_PCT_BASELINE}{VALUE} = sprintf "%0.2f", ($baseline_success / $baseline_closed) * 100 if ($baseline_closed > 0);
	$l2_bionics{CAPABILITY}{$cap}{SUCCESS_PCT_BASELINE}{HTML} = ($l2_bionics{CAPABILITY}{$cap}{SUCCESS_PCT_BASELINE}{VALUE} ne "") ? $l2_bionics{CAPABILITY}{$cap}{SUCCESS_PCT_BASELINE}{VALUE} ."\%" : "-";
	
	$baseline_pct = $l2_bionics{CAPABILITY}{$cap}{SUCCESS_PCT_BASELINE}{VALUE} || 0;
	$cur_pct = $l2_bionics{CAPABILITY}{$cap}{SUCCESS_PCT_CUR}{VALUE} || 0;
	$l2_bionics{CAPABILITY}{$cap}{SUCCESS_PCT_DIF}{VALUE} = ($cur_closed > 0 and $baseline_closed > 0) ? sprintf "%0.2f", ($cur_pct - $baseline_pct) : 0;
	$l2_bionics{CAPABILITY}{$cap}{SUCCESS_PCT_DIF}{HTML} = ($cur_closed > 0 and $baseline_closed > 0) ? $l2_bionics{CAPABILITY}{$cap}{SUCCESS_PCT_DIF}{VALUE} ."%" : "-";
	$l2_bionics{CAPABILITY}{$cap}{SUCCESS_PCT_DIF}{COLOR} = $red if($l2_bionics{CAPABILITY}{$cap}{SUCCESS_PCT_DIF}{VALUE} < 0);
	$l2_bionics{CAPABILITY}{$cap}{SUCCESS_PCT_DIF}{COLOR} = $green if($l2_bionics{CAPABILITY}{$cap}{SUCCESS_PCT_DIF}{VALUE} > 0);
	
	# Failed
	$l2_bionics{CAPABILITY}{$cap}{FAILED_COUNT_BASELINE}{HTML} = ($baseline_std_failed > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&cap=$cap&type=FAILED\">$baseline_failed</a>" : 0;
	$l2_bionics{CAPABILITY}{$cap}{FAILED_PCT_BASELINE}{VALUE} = sprintf "%0.2f", ($baseline_failed / $baseline_closed) * 100 if ($baseline_closed > 0);
	$l2_bionics{CAPABILITY}{$cap}{FAILED_PCT_BASELINE}{HTML} = ($l2_bionics{CAPABILITY}{$cap}{FAILED_PCT_BASELINE}{VALUE} ne "") ? $l2_bionics{CAPABILITY}{$cap}{FAILED_PCT_BASELINE}{VALUE} ."\%" : "-";
	
	$baseline_pct = $l2_bionics{CAPABILITY}{$cap}{FAILED_PCT_BASELINE}{VALUE} || 0;
	$cur_pct = $l2_bionics{CAPABILITY}{$cap}{FAILED_PCT_CUR}{VALUE} || 0;
	$l2_bionics{CAPABILITY}{$cap}{FAILED_PCT_DIF}{VALUE} = ($cur_closed > 0 and $baseline_closed > 0) ? sprintf "%0.2f", ($cur_pct - $baseline_pct) : 0;
	$l2_bionics{CAPABILITY}{$cap}{FAILED_PCT_DIF}{HTML} = ($cur_closed > 0 and $baseline_closed > 0) ? $l2_bionics{CAPABILITY}{$cap}{FAILED_PCT_DIF}{VALUE} ."%" : "-";
	$l2_bionics{CAPABILITY}{$cap}{FAILED_PCT_DIF}{COLOR} = $green if($l2_bionics{CAPABILITY}{$cap}{FAILED_PCT_DIF}{VALUE} < 0);
	$l2_bionics{CAPABILITY}{$cap}{FAILED_PCT_DIF}{COLOR} = $red if($l2_bionics{CAPABILITY}{$cap}{FAILED_PCT_DIF}{VALUE} > 0);
	
	# Failed Standard
	$l2_bionics{CAPABILITY}{$cap}{STD_FAILED_COUNT_BASELINE}{HTML} = ($baseline_std_failed > 0) ? "<a href=\"$drilldown_dir/l3_bionics_change.pl?period=BASELINE&cap=$cap&type=STD_FAILED\">$baseline_std_failed</a>" : 0;
	$l2_bionics{CAPABILITY}{$cap}{STD_FAILED_PCT_BASELINE}{VALUE} = sprintf "%0.2f", ($baseline_std_failed / $baseline_closed) * 100 if ($baseline_closed > 0);
	$l2_bionics{CAPABILITY}{$cap}{STD_FAILED_PCT_BASELINE}{HTML} = ($l2_bionics{CAPABILITY}{$cap}{STD_FAILED_PCT_BASELINE}{VALUE} ne "") ? $l2_bionics{CAPABILITY}{$cap}{STD_FAILED_PCT_BASELINE}{VALUE} ."\%" : "-";
	
	$baseline_pct = $l2_bionics{CAPABILITY}{$cap}{STD_FAILED_PCT_BASELINE}{VALUE} || 0;
	$cur_pct = $l2_bionics{CAPABILITY}{$cap}{STD_FAILED_PCT_CUR}{VALUE} || 0;
	$l2_bionics{CAPABILITY}{$cap}{STD_FAILED_PCT_DIF}{VALUE} = ($cur_closed > 0 and $baseline_closed > 0) ? sprintf "%0.2f", ($cur_pct - $baseline_pct) : 0;
	$l2_bionics{CAPABILITY}{$cap}{STD_FAILED_PCT_DIF}{HTML} = ($cur_closed > 0 and $baseline_closed > 0) ? $l2_bionics{CAPABILITY}{$cap}{STD_FAILED_PCT_DIF}{VALUE} ."%" : "-";
	$l2_bionics{CAPABILITY}{$cap}{STD_FAILED_PCT_DIF}{COLOR} = $green if($l2_bionics{CAPABILITY}{$cap}{STD_FAILED_PCT_DIF}{VALUE} < 0);
	$l2_bionics{CAPABILITY}{$cap}{STD_FAILED_PCT_DIF}{COLOR} = $red if($l2_bionics{CAPABILITY}{$cap}{STD_FAILED_PCT_DIF}{VALUE} > 0);
	
	#########################################################
	# Calculate graph metric percentages for last 18 months 
	#########################################################
	for my $x (1..18) {
		
		$l2_bionics{CAPABILITY}{$cap}{"CLOSED_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{CAPABILITY}{$cap}{"CLOSED_COUNT_M${x}"}{VALUE});
		$l2_bionics{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE});
		$l2_bionics{CAPABILITY}{$cap}{"FAILED_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE});
		$l2_bionics{CAPABILITY}{$cap}{"STD_FAILED_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE});
		$l2_bionics{CAPABILITY}{$cap}{"STD_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE});
		$l2_bionics{CAPABILITY}{$cap}{"STD_MINOR_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE});
		$l2_bionics{CAPABILITY}{$cap}{"NORMAL_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE});
		$l2_bionics{CAPABILITY}{$cap}{"NORMAL_MINOR_COUNT_M${x}"}{VALUE} = 0 if (not defined $l2_bionics{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE});
			
		my $cap_closed_cnt = $l2_bionics{CAPABILITY}{$cap}{"CLOSED_COUNT_M${x}"}{VALUE} || 0;
				
		$l2_bionics{CAPABILITY}{$cap}{"SUCCESS_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{CAPABILITY}{$cap}{"SUCCESS_COUNT_M${x}"}{VALUE} / $cap_closed_cnt) * 100 if ($cap_closed_cnt > 0);
		$l2_bionics{CAPABILITY}{$cap}{"SUCCESS_PCT_M${x}"}{VALUE} = '0.00' if ($cap_closed_cnt == 0);
		$l2_bionics{CAPABILITY}{$cap}{"FAILED_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{CAPABILITY}{$cap}{"FAILED_COUNT_M${x}"}{VALUE} / $cap_closed_cnt) * 100 if ($cap_closed_cnt > 0);
		$l2_bionics{CAPABILITY}{$cap}{"FAILED_PCT_M${x}"}{VALUE} = '0.00' if ($cap_closed_cnt == 0);
		$l2_bionics{CAPABILITY}{$cap}{"STD_FAILED_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{CAPABILITY}{$cap}{"STD_FAILED_COUNT_M${x}"}{VALUE} / $cap_closed_cnt) * 100 if ($cap_closed_cnt > 0);
		$l2_bionics{CAPABILITY}{$cap}{"STD_FAILED_PCT_M${x}"}{VALUE} = '0.00' if ($cap_closed_cnt == 0);
		$l2_bionics{CAPABILITY}{$cap}{"STD_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{CAPABILITY}{$cap}{"STD_COUNT_M${x}"}{VALUE} / $cap_closed_cnt) * 100 if ($cap_closed_cnt > 0);
		$l2_bionics{CAPABILITY}{$cap}{"STD_PCT_M${x}"}{VALUE} = '0.00' if ($cap_closed_cnt == 0);
		$l2_bionics{CAPABILITY}{$cap}{"STD_MINOR_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{CAPABILITY}{$cap}{"STD_MINOR_COUNT_M${x}"}{VALUE} / $cap_closed_cnt) * 100 if ($cap_closed_cnt > 0);
		$l2_bionics{CAPABILITY}{$cap}{"STD_MINOR_PCT_M${x}"}{VALUE} = '0.00' if ($cap_closed_cnt == 0);
		$l2_bionics{CAPABILITY}{$cap}{"NORMAL_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{CAPABILITY}{$cap}{"NORMAL_COUNT_M${x}"}{VALUE} / $cap_closed_cnt) * 100 if ($cap_closed_cnt > 0);
		$l2_bionics{CAPABILITY}{$cap}{"NORMAL_PCT_M${x}"}{VALUE} = '0.00' if ($cap_closed_cnt == 0);
		$l2_bionics{CAPABILITY}{$cap}{"NORMAL_MINOR_PCT_M${x}"}{VALUE} = sprintf "%0.2f", ($l2_bionics{CAPABILITY}{$cap}{"NORMAL_MINOR_COUNT_M${x}"}{VALUE} / $cap_closed_cnt) * 100 if ($cap_closed_cnt > 0);
		$l2_bionics{CAPABILITY}{$cap}{"NORMAL_MINOR_PCT_M${x}"}{VALUE} = '0.00' if ($cap_closed_cnt == 0);
	} # Monthly Percntages for Graphs
}

# Calculate the 25/50/75th Customer Percentiles
print "\nCalculating Monthly Global Capability Percentiles\n";
foreach my $m (@month_ticks) {
	
	my $month_label = $m->{MONTH_LABEL};
	my $field_ext = $m->{FIELD_EXT};
	
	print "Processing $month_label \n";
	
	my (%c, %d, %e, %f, %g, %h);
	foreach my $customer (keys %{$l2_bionics{CUSTOMER}}) {
		foreach my $cap (keys %{$l2_bionics{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}}) {
			if ($l2_bionics{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{"CLOSED_COUNT_${field_ext}"}{VALUE} > 0) {	
				push @{$c{$cap}{VALUE}},  $l2_bionics{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{"CLOSED_COUNT_${field_ext}"}{VALUE} || 0;
				push @{$d{$cap}{VALUE}},  $l2_bionics{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{"SUCCESS_PCT_${field_ext}"}{VALUE} || 0;
				push @{$e{$cap}{VALUE}},  $l2_bionics{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{"STD_FAILED_PCT_${field_ext}"}{VALUE} || 0;
				push @{$f{$cap}{VALUE}},  $l2_bionics{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{"STD_MINOR_PCT_${field_ext}"}{VALUE} || 0;
				push @{$g{$cap}{VALUE}},  $l2_bionics{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{"NORMAL_PCT_${field_ext}"}{VALUE} || 0;
				push @{$h{$cap}{VALUE}},  $l2_bionics{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{$cap}{"FAILED_PCT_${field_ext}"}{VALUE} || 0;
			}
		}		
	}	
		
	foreach my $cap (keys %c) {	
		my @c2 = sort { $a <=> $b } @{$c{$cap}{VALUE}};
		my $len10 = sprintf "%d", scalar(@c2) * 0.10;
		my $len25 = sprintf "%d", scalar(@c2) * 0.25;
		my $len50 = sprintf "%d", scalar(@c2) * 0.5;
		my $len75 = sprintf "%d", scalar(@c2) * 0.75;
		
		$l2_bionics{CAPABILITY}{$cap}{"10PERC_CLOSED_COUNT_${field_ext}"}{VALUE} = $c2[$len10];
		$l2_bionics{CAPABILITY}{$cap}{"25PERC_CLOSED_COUNT_${field_ext}"}{VALUE} = $c2[$len25];
		$l2_bionics{CAPABILITY}{$cap}{"50PERC_CLOSED_COUNT_${field_ext}"}{VALUE} = $c2[$len50];
		$l2_bionics{CAPABILITY}{$cap}{"75PERC_CLOSED_COUNT_${field_ext}"}{VALUE} = $c2[$len75];
		
		#print "   CAP $cap 10PERC = ". $l2_bionics{CAPABILITY}{$cap}{"10PERC_CLOSED_COUNT_${field_ext}"}{VALUE} . "\n";
		#print "   CAP $cap 25PERC = ". $l2_bionics{CAPABILITY}{$cap}{"25PERC_CLOSED_COUNT_${field_ext}"}{VALUE} . "\n";
		#print "   CAP $cap 50PERC = ". $l2_bionics{CAPABILITY}{$cap}{"50PERC_CLOSED_COUNT_${field_ext}"}{VALUE} . "\n";
		#print "   CAP $cap 75PERC = ". $l2_bionics{CAPABILITY}{$cap}{"75PERC_CLOSED_COUNT_${field_ext}"}{VALUE} . "\n";

		my @d2 = sort { $a <=> $b } @{$d{$cap}{VALUE}};
		my $len10 = sprintf "%d", scalar(@d2) * 0.10;
		my $len25 = sprintf "%d", scalar(@d2) * 0.25;
		my $len50 = sprintf "%d", scalar(@d2) * 0.5;
		my $len75 = sprintf "%d", scalar(@d2) * 0.75;
		
		$l2_bionics{CAPABILITY}{$cap}{"10PERC_SUCCESS_${field_ext}"}{VALUE} = $d2[$len10];
		$l2_bionics{CAPABILITY}{$cap}{"25PERC_SUCCESS_${field_ext}"}{VALUE} = $d2[$len25];
		$l2_bionics{CAPABILITY}{$cap}{"50PERC_SUCCESS_${field_ext}"}{VALUE} = $d2[$len50];
		$l2_bionics{CAPABILITY}{$cap}{"75PERC_SUCCESS_${field_ext}"}{VALUE} = $d2[$len75];

		my @e2 = sort { $a <=> $b } @{$e{$cap}{VALUE}};
		my $len10 = sprintf "%d", scalar(@e2) * 0.10;
		my $len25 = sprintf "%d", scalar(@e2) * 0.25;
		my $len50 = sprintf "%d", scalar(@e2) * 0.5;
		my $len75 = sprintf "%d", scalar(@e2) * 0.75;
		
		$l2_bionics{CAPABILITY}{$cap}{"10PERC_STD_FAILED_${field_ext}"}{VALUE} = $e2[$len10];
		$l2_bionics{CAPABILITY}{$cap}{"25PERC_STD_FAILED_${field_ext}"}{VALUE} = $e2[$len25];
		$l2_bionics{CAPABILITY}{$cap}{"50PERC_STD_FAILED_${field_ext}"}{VALUE} = $e2[$len50];
		$l2_bionics{CAPABILITY}{$cap}{"75PERC_STD_FAILED_${field_ext}"}{VALUE} = $e2[$len75];
		
		my @f2 = sort { $a <=> $b } @{$f{$cap}{VALUE}};
		my $len10 = sprintf "%d", scalar(@f2) * 0.10;
		my $len25 = sprintf "%d", scalar(@f2) * 0.25;
		my $len50 = sprintf "%d", scalar(@f2) * 0.5;
		my $len75 = sprintf "%d", scalar(@f2) * 0.75;
		
		$l2_bionics{CAPABILITY}{$cap}{"10PERC_STD_MINOR_${field_ext}"}{VALUE} = $f2[$len10];
		$l2_bionics{CAPABILITY}{$cap}{"25PERC_STD_MINOR_${field_ext}"}{VALUE} = $f2[$len25];
		$l2_bionics{CAPABILITY}{$cap}{"50PERC_STD_MINOR_${field_ext}"}{VALUE} = $f2[$len50];
		$l2_bionics{CAPABILITY}{$cap}{"75PERC_STD_MINOR_${field_ext}"}{VALUE} = $f2[$len75];
		
		my @g2 = sort { $a <=> $b } @{$g{$cap}{VALUE}};
		my $len10 = sprintf "%d", scalar(@g2) * 0.10;
		my $len25 = sprintf "%d", scalar(@g2) * 0.25;
		my $len50 = sprintf "%d", scalar(@g2) * 0.5;
		my $len75 = sprintf "%d", scalar(@g2) * 0.75;
		
		$l2_bionics{CAPABILITY}{$cap}{"10PERC_NORMAL_${field_ext}"}{VALUE} = $g2[$len10];
		$l2_bionics{CAPABILITY}{$cap}{"25PERC_NORMAL_${field_ext}"}{VALUE} = $g2[$len25];
		$l2_bionics{CAPABILITY}{$cap}{"50PERC_NORMAL_${field_ext}"}{VALUE} = $g2[$len50];
		$l2_bionics{CAPABILITY}{$cap}{"75PERC_NORMAL_${field_ext}"}{VALUE} = $g2[$len75];
		
		my @h2 = sort { $a <=> $b } @{$h{$cap}{VALUE}};
		my $len10 = sprintf "%d", scalar(@h2) * 0.10;
		my $len25 = sprintf "%d", scalar(@h2) * 0.25;
		my $len50 = sprintf "%d", scalar(@h2) * 0.5;
		my $len75 = sprintf "%d", scalar(@h2) * 0.75;
		
		$l2_bionics{CAPABILITY}{$cap}{"10PERC_NORMAL_${field_ext}"}{VALUE} = $h2[$len10];
		$l2_bionics{CAPABILITY}{$cap}{"25PERC_NORMAL_${field_ext}"}{VALUE} = $h2[$len25];
		$l2_bionics{CAPABILITY}{$cap}{"50PERC_NORMAL_${field_ext}"}{VALUE} = $h2[$len50];
		$l2_bionics{CAPABILITY}{$cap}{"75PERC_NORMAL_${field_ext}"}{VALUE} = $h2[$len75];
	}
}


save_hash("cache.l2_bionics_change_dashboard", \%l2_bionics,"$cache_dir/l2_cache");

my $end_time = time();
printf "Completed Processing after %0.1f Mins\n", ($end_time - $start_time) / 60;
