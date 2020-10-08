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
my %l2_asset;

my @list = ('account_reg', 'ucms_automation');
%cache = load_cache(\@list);

my %account_reg = %{$cache{account_reg}};
my %ucms_auto = %{$cache{ucms_automation}};

############################################################################
# Start generating metrics
############################################################################

if (not defined($opts{"s"})) {
	foreach my $customer (sort keys %account_reg) {
		next if (defined($opts{"c"}) and not defined($cust_list_hash{$customer}));

		####################################################
		# Get UCMS Data
		####################################################
		if (defined ($ucms_auto{CUSTOMER}{$customer})) {
			print "Loading UCMS Data for $customer\n";
			foreach my $project ('RBA', 'ARES', 'RPA', 'TA', 'EVA', 'IAF') {
				# should we check for status completed and implemented only?
				foreach my $asset (keys %{$ucms_auto{CUSTOMER}{$customer}{PROJECT}{$project}{ASSET}}) {
					$l2_asset{CUSTOMER}{$customer}{PROJECT}{$project}{TOTAL_UC_COUNT}{VALUE}++;
					$l2_asset{CUSTOMER}{$customer}{PROJECT}{$project}{'30_DAYS_COUNT'}{VALUE}++ if (defined($ucms_auto{CUSTOMER}{$customer}{PROJECT}{$project}{ASSET}{$asset}{'IN_30_DAYS'}));
					$l2_asset{CUSTOMER}{$customer}{PROJECT}{$project}{'18_MONTHS_COUNT'}{VALUE}++ if (defined($ucms_auto{CUSTOMER}{$customer}{PROJECT}{$project}{ASSET}{$asset}{'IN_18_MONTHS'}));
					$l2_asset{CUSTOMER}{$customer}{PROJECT}{$project}{'12_MONTHS_COUNT'}{VALUE}++ if (defined($ucms_auto{CUSTOMER}{$customer}{PROJECT}{$project}{ASSET}{$asset}{'IN_12_MONTHS'}));
					$l2_asset{CUSTOMER}{$customer}{PROJECT}{$project}{'6_MONTHS_COUNT'}{VALUE}++ if (defined($ucms_auto{CUSTOMER}{$customer}{PROJECT}{$project}{ASSET}{$asset}{'IN_6_MONTHS'}));

					$l2_asset{CUSTOMER}{$customer}{PROJECT}{ALL}{TOTAL_UC_COUNT}{VALUE}++;
					$l2_asset{CUSTOMER}{$customer}{PROJECT}{ALL}{'30_DAYS_COUNT'}{VALUE}++ if (defined($ucms_auto{CUSTOMER}{$customer}{PROJECT}{$project}{ASSET}{$asset}{'IN_30_DAYS'}));
					$l2_asset{CUSTOMER}{$customer}{PROJECT}{ALL}{'18_MONTHS_COUNT'}{VALUE}++ if (defined($ucms_auto{CUSTOMER}{$customer}{PROJECT}{$project}{ASSET}{$asset}{'IN_18_MONTHS'}));
					$l2_asset{CUSTOMER}{$customer}{PROJECT}{ALL}{'12_MONTHS_COUNT'}{VALUE}++ if (defined($ucms_auto{CUSTOMER}{$customer}{PROJECT}{$project}{ASSET}{$asset}{'IN_12_MONTHS'}));
					$l2_asset{CUSTOMER}{$customer}{PROJECT}{ALL}{'6_MONTHS_COUNT'}{VALUE}++ if (defined($ucms_auto{CUSTOMER}{$customer}{PROJECT}{$project}{ASSET}{$asset}{'IN_6_MONTHS'}));
				}

				my $uc_count =  $l2_asset{CUSTOMER}{$customer}{PROJECT}{$project}{TOTAL_UC_COUNT}{VALUE} || 0;
				my $type = lc($project);
				if ($uc_count > 0) {
					$l2_asset{CUSTOMER}{$customer}{PROJECT}{$project}{TOTAL_UC_COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_ucms_assets.pl?customer=$customer&type=$type\">".$uc_count."</a>";
				}	else {
					$l2_asset{CUSTOMER}{$customer}{PROJECT}{$project}{TOTAL_UC_COUNT}{HTML} = 0;
				}

				my $all_uc_count =  $l2_asset{CUSTOMER}{$customer}{PROJECT}{ALL}{TOTAL_UC_COUNT}{VALUE} || 0;
				if ($all_uc_count > 0) {
					$l2_asset{CUSTOMER}{$customer}{PROJECT}{ALL}{TOTAL_UC_COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_ucms_assets.pl?customer=$customer&type=ALL\">".$all_uc_count."</a>";
				} else {
					$l2_asset{CUSTOMER}{$customer}{PROJECT}{ALL}{TOTAL_UC_COUNT}{HTML} = 0;
				}

				my $in_30_day_uc_count =  $l2_asset{CUSTOMER}{$customer}{PROJECT}{ALL}{'30_DAYS_COUNT'}{VALUE} || 0;
				if ($in_30_day_uc_count > 0) {
					$l2_asset{CUSTOMER}{$customer}{PROJECT}{ALL}{'30_DAYS_COUNT'}{HTML} = "<a href=\"$drilldown_dir/l3_ucms_assets.pl?customer=$customer&type=ALL&period=30_DAYS\">".$in_30_day_uc_count."</a>";
				}	else {
					$l2_asset{CUSTOMER}{$customer}{PROJECT}{ALL}{'30_DAYS_COUNT'}{HTML} = 0;
				}

				my $in_18_months_uc_count =  $l2_asset{CUSTOMER}{$customer}{PROJECT}{ALL}{'18_MONTHS_COUNT'}{VALUE} || 0;
				if ($in_18_months_uc_count > 0) {
					$l2_asset{CUSTOMER}{$customer}{PROJECT}{ALL}{'18_MONTHS_COUNT'}{HTML} = "<a href=\"$drilldown_dir/l3_ucms_assets.pl?customer=$customer&type=ALL&period=18_MONTHS\">".$in_18_months_uc_count."</a>";
				}	else {
					$l2_asset{CUSTOMER}{$customer}{PROJECT}{ALL}{'18_MONTHS_COUNT'}{HTML} = 0;
				}

				my $in_12_months_uc_count =  $l2_asset{CUSTOMER}{$customer}{PROJECT}{ALL}{'12_MONTHS_COUNT'}{VALUE} || 0;
				if ($in_12_months_uc_count > 0) {
					$l2_asset{CUSTOMER}{$customer}{PROJECT}{ALL}{'12_MONTHS_COUNT'}{HTML} = "<a href=\"$drilldown_dir/l3_ucms_assets.pl?customer=$customer&type=ALL&period=12_MONTHS\">".$in_12_months_uc_count."</a>";
				}	else {
					$l2_asset{CUSTOMER}{$customer}{PROJECT}{ALL}{'12_MONTHS_COUNT'}{HTML} = 0;
				}

				my $in_6_months_uc_count =  $l2_asset{CUSTOMER}{$customer}{PROJECT}{ALL}{'6_MONTHS_COUNT'}{VALUE} || 0;
				if ($in_6_months_uc_count > 0) {
					$l2_asset{CUSTOMER}{$customer}{PROJECT}{ALL}{'6_MONTHS_COUNT'}{HTML} = "<a href=\"$drilldown_dir/l3_ucms_assets.pl?customer=$customer&type=ALL&period=6_MONTHS\">".$in_6_months_uc_count."</a>";
				}	else {
					$l2_asset{CUSTOMER}{$customer}{PROJECT}{ALL}{'6_MONTHS_COUNT'}{HTML} = 0;
				}
			}
		}
	}

	save_hash("cache.l2_auto_asset", \%l2_asset,"$cache_dir/l2_cache");
	undef %l2_asset;
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
