#!/usr/bin/perl

# Title: ReSolve Issues Tile
# Description:
# Presents all issues from the reSolve platform by acccount summarized
# Author: Daniel Arrieta Alfaro
# Last modified by: Daniel Arrieta 6 / November / 2019

use strict;
use Sys::Hostname;
use File::Basename;
use File::Temp "tempfile";
use CGI qw(:standard);
use FileHandle;
use Data::Dumper;
use Time::Local;
use Encode();
use POSIX qw(strftime);
use lib '/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/modules/pm';
use CommonHTML;
use LoadCache;
use CommonFunctions;
use CommonColor;

use vars qw($cache_dir);
use vars qw($rawdata_dir);
use vars qw($cfg_dir);
use vars qw($drilldown_dir);
use vars qw($green $red $amber $grey $orange $cyan $cgreen $lgrey $info $info2 $dgrey $voilet $lgolden $lblue $hpe);

my %opts;
getopts('t', \%opts) || usage("invalid arguments");

sub usage
{
	print "create_l1_resolve.pl [-t] ---->> Testing one account (bank of queensland)\n";
	print "create_l1_resolve.pl [-c] ---->> Print all counts for each account and summary counts\n";
}

my $start_time = time;

# IDEA add options for self testing, Test only one account (bank of queensland), check validity of values, no weird numbers or null.

# Load cache
my @list = ('raw_resolve_events', 'account_reg'); #'l2_incidents'
my %cache = load_cache(\@list);
my %account_reg = %{$cache{account_reg}};

my %l2_resolve;
my %l3_resolve;
my @multi_issues;

sub define_issue_state
{
  my $state = "";
  my ($status) = @_;

  if ($status =~ /open/i ) {
    $state = "active";
  } else {
    $state = "closed";
  }
  return $state;
}

# get the resolve data straight from the collector: RESOLVE_events.java
sub get_reSolve_data
{
 	print "Opening file $rawdata_dir/raw_resolve_events\n";
  open(BUA, "$rawdata_dir/raw_resolve_events");

  while (my $ln = <BUA>) {
 		chomp;
		my ($c, $resolve_id, $contact, $priority, $rtop, $rtop_type, $rtop_time,
		$init_impact, $current_impact, $alpha, $event_desc, $incident_start, $priority_start,
		$incident_end, $priority_end, $status, $incident_duration, $cm_engaged, $cm_notified,
		$ext_records, $kpe, $next_actions, $event_res, $event_root ) = split(/~~~/, $ln);

		#if it finds multiple customers in the $c field, pass it into a temp array to process later.
		if ($c =~ /\w*,/i){
			push @multi_issues, $ln;
			next;
		}

		# map customer to sp
		my ($customer, $resolve_client);
		if (defined($l2_resolve{CUSTOMER}{$c})) {
			$customer = $c;
		} else {
			$customer = map_customer_to_sp(\%account_reg,$c,"","ANY");
			$resolve_client = $c;
			next if ($customer =~ /not_mapped/i);
		}

		# remove double spaces in descriptions

		$init_impact=~s/\x{0023}//g;
		$init_impact=~s/\x{00A0}//g;
		$init_impact=~s/\x{00C2}//g;

		$current_impact=~s/\x{0023}//g;
		$current_impact=~s/\x{00A0}//g;
		$current_impact=~s/\x{00C2}//g;

		$event_res=~s/\x{0023}//g;
		$event_res=~s/\x{00A0}//g;
		$event_res=~s/\x{00C2}//g;

		$event_root=~s/\x{0023}//g;
		$event_root=~s/\x{00A0}//g;
		$event_root=~s/\x{00C2}//g;


		# incident example:
    # convatec inc~~~259984~~~ ~~~2~~~ ~~~ ~~~null~~~telephone lines are down at the amcare nottingham site.~~~null~~~no~~~2019-12-06 09:28:00.0~~~2019-12-06 09:28:00.0~~~2019-12-06 10:10:00.0~~~2019-12-06 10:10:00.0~~~42~~~

    # extract date values: month, year, days
    my $month_label = $incident_start;
    # Date example: 2019-12-06 09:28:00.0
    if ($incident_start =~ /^(\d{2})\-(\d{2})\-(\d{4})\s+(\d{2})\:(\d{2})\:(\d{2})/){
      # BUG don't know if months will come as individual digit or with a 0 infront...
      my $date_start_tick = POSIX::mktime($6,$5,$4,$3,$2,$1);
    }
    my $state = define_issue_state($status);
    # print "$incident_end = $state \n";

    # add to account summary
    $l2_resolve{CUSTOMER}{$customer}{COUNT}{VALUE}++;
    $l2_resolve{CUSTOMER}{$customer}{COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_resolve.pl?&customer=$customer\">".$l2_resolve{CUSTOMER}{$customer}{COUNT}{VALUE}."</a>" ;

    # TODO define color code for different numbers.
    $l2_resolve{CUSTOMER}{$customer}{COUNT}{COLOR} = $cgreen;

    # Set Priority
    my $priority_label = "P"."$priority";
    # Divide by STATE
    # State ALL
    $l2_resolve{CUSTOMER}{$customer}{PRIORITY}{"ALL_COUNT"}{STATE}{"ALL"}{COUNT}{VALUE}++;
    $l2_resolve{CUSTOMER}{$customer}{PRIORITY}{"ALL_COUNT"}{STATE}{"ALL"}{COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_resolve.pl?&customer=$customer\">".$l2_resolve{CUSTOMER}{$customer}{PRIORITY}{"ALL_COUNT"}{STATE}{"ALL"}{COUNT}{VALUE}."</a>";
    $l2_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{STATE}{"ALL"}{COUNT}{VALUE}++;
    $l2_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{STATE}{"ALL"}{COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_resolve.pl?&customer=$customer&priority=$priority_label\">".$l2_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{STATE}{"ALL"}{COUNT}{VALUE}."</a>";

    # State defined
    $l2_resolve{CUSTOMER}{$customer}{PRIORITY}{"ALL_COUNT"}{STATE}{$state}{COUNT}{VALUE}++;
    $l2_resolve{CUSTOMER}{$customer}{PRIORITY}{"ALL_COUNT"}{STATE}{$state}{COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_resolve.pl?&customer=$customer&state=$state\">".$l2_resolve{CUSTOMER}{$customer}{PRIORITY}{"ALL_COUNT"}{STATE}{$state}{COUNT}{VALUE}."</a>";
    $l2_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{STATE}{$state}{COUNT}{VALUE}++;
    $l2_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{STATE}{$state}{COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_resolve.pl?&customer=$customer&priority=$priority_label&state=$state\">".$l2_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{STATE}{$state}{COUNT}{VALUE}."</a>";


    # catch rtop assigned
    if (defined($rtop) && $rtop != ''){
      $l2_resolve{CUSTOMER}{$customer}{RTOP}{"ALL_COUNT"}{STATE}{"ALL"}{COUNT}{VALUE}++;
      $l2_resolve{CUSTOMER}{$customer}{RTOP}{"ALL_COUNT"}{STATE}{"ALL"}{COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_resolve.pl?&customer=$customer&rtop=1\">".$l2_resolve{CUSTOMER}{$customer}{RTOP}{"ALL_COUNT"}{STATE}{"ALL"}{COUNT}{VALUE}."</a>";
      $l2_resolve{CUSTOMER}{$customer}{RTOP}{$priority_label}{STATE}{"ALL"}{COUNT}{VALUE}++;
      $l2_resolve{CUSTOMER}{$customer}{RTOP}{$priority_label}{STATE}{"ALL"}{COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_resolve.pl?&customer=$customer&priority=$priority_label&rtop=1\">".$l2_resolve{CUSTOMER}{$customer}{RTOP}{$priority_label}{STATE}{"ALL"}{COUNT}{VALUE}."</a>";

      # Divide by state
      $l2_resolve{CUSTOMER}{$customer}{RTOP}{"ALL_COUNT"}{STATE}{$state}{COUNT}{VALUE}++;
      $l2_resolve{CUSTOMER}{$customer}{RTOP}{"ALL_COUNT"}{STATE}{$state}{COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_resolve.pl?&customer=$customer&rtop=1&state=$state\">".$l2_resolve{CUSTOMER}{$customer}{RTOP}{"ALL_COUNT"}{STATE}{$state}{COUNT}{VALUE}."</a>";
      $l2_resolve{CUSTOMER}{$customer}{RTOP}{$priority_label}{STATE}{$state}{COUNT}{VALUE}++;
      $l2_resolve{CUSTOMER}{$customer}{RTOP}{$priority_label}{STATE}{$state}{COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_resolve.pl?&customer=$customer&priority=$priority_label&rtop=1&state=$state\">".$l2_resolve{CUSTOMER}{$customer}{RTOP}{$priority_label}{STATE}{$state}{COUNT}{VALUE}."</a>";

    }
		else {
			$l2_resolve{CUSTOMER}{$customer}{No_RTOP}{"ALL_COUNT"}{STATE}{"ALL"}{COUNT}{VALUE}++;
      $l2_resolve{CUSTOMER}{$customer}{No_RTOP}{"ALL_COUNT"}{STATE}{"ALL"}{COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_resolve.pl?&customer=$customer&rtop=0\">".$l2_resolve{CUSTOMER}{$customer}{No_RTOP}{"ALL_COUNT"}{STATE}{"ALL"}{COUNT}{VALUE}."</a>";
      $l2_resolve{CUSTOMER}{$customer}{No_RTOP}{$priority_label}{STATE}{"ALL"}{COUNT}{VALUE}++;
      $l2_resolve{CUSTOMER}{$customer}{No_RTOP}{$priority_label}{STATE}{"ALL"}{COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_resolve.pl?&customer=$customer&priority=$priority_label&rtop=0\">".$l2_resolve{CUSTOMER}{$customer}{No_RTOP}{$priority_label}{STATE}{"ALL"}{COUNT}{VALUE}."</a>";

      # Divide by state
      $l2_resolve{CUSTOMER}{$customer}{No_RTOP}{"ALL_COUNT"}{STATE}{$state}{COUNT}{VALUE}++;
      $l2_resolve{CUSTOMER}{$customer}{No_RTOP}{"ALL_COUNT"}{STATE}{$state}{COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_resolve.pl?&customer=$customer&rtop=0&state=$state\">".$l2_resolve{CUSTOMER}{$customer}{No_RTOP}{"ALL_COUNT"}{STATE}{$state}{COUNT}{VALUE}."</a>";
      $l2_resolve{CUSTOMER}{$customer}{No_RTOP}{$priority_label}{STATE}{$state}{COUNT}{VALUE}++;
      $l2_resolve{CUSTOMER}{$customer}{No_RTOP}{$priority_label}{STATE}{$state}{COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_resolve.pl?&customer=$customer&priority=$priority_label&rtop=0&state=$state\">".$l2_resolve{CUSTOMER}{$customer}{No_RTOP}{$priority_label}{STATE}{$state}{COUNT}{VALUE}."</a>";

		}

    # TODO add values to l3 hash
    $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{CONTACT} = $contact;
    $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{PRIORITY} = $priority;
    if (defined($rtop) && $rtop != ''){
        $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{RTOP_ID} = "<a href=\"$drilldown_dir/l3_rtops.pl?id=$rtop\">$rtop";
        $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{RTOP_TYPE} = $rtop_type;
        $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{RTOP_TIME} = $rtop_time;
      }
    $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{INIT_IMPACT} = $init_impact;
    $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{CURRENT_IMPACT} = $current_impact;
    $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{EVENT_DESC} = $event_desc;
    $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{ALPHA} = $alpha;
    $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{START} = $incident_start;
    $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{PRIORITY_START} = $priority_start ;
    $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{PRIORITY_END} = $priority_end ;
    $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{STATUS} = $status || "null" ;
    $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{END} = $incident_end ;
    # TODO Set duration in sec, minutes, hours.
    $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{DURATION} = $incident_duration ;
    $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{CM_ENGAGED} = $cm_engaged ;
    $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{CM_NOTIFIED} = $cm_notified ;
    $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{EXT_RECORDS} = $ext_records ;
    $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{KPE} = $kpe ;
    $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{NEXT_ACTIONS} = $next_actions ;
    $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{EVENT_RES} = $event_res ;
    $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{EVENT_ROOT} = $event_root ;

	}
	close(BUA);
}

sub print_account_reg
{
  print Dumper keys(%account_reg);
}

sub print_l2_test
{
	#foreach my $temp_c (keys %{$l2_resolve{CUSTOMER}}) {
	#	print "CUSTOMER: $temp_c has: ";
	#	print $l2_resolve{CUSTOMER}{$temp_c}{PRIORITY}{"ALL_COUNT"}{STATE}{"ALL"}{COUNT}{VALUE};
	#	print "  incidents \n";
	#}

}

sub remove_duplicates
{
  my (@customers) = @_;
  my @filtered_array;
  my $found_duplicate;
  my $printing = 0;
  # what if we find more than one duplicate customer in the same list... just check if the customer is already in the list then..

  if (scalar(@customers) <= 1){
    # if array has one or less elements.
    return @customers;
  }
  else {

    foreach (@customers) {
      $found_duplicate = 0;
      my $control_account = $_;
      # print "Control Account: $control_account\n";
      if (scalar(@filtered_array < 1)) {
        push @filtered_array, $control_account;
      }
      else {
        foreach (@filtered_array) {
          my $test_account = $_;
          if ($control_account =~ /$test_account/i){
            $found_duplicate = 1;
            $printing = 1;
            # print("----------------- FOUND IT!!!!!!!!\n");
          }
          else {
            next;
          }
        }
        if ($found_duplicate == 0) {
          push @filtered_array, $control_account;
        }
      }
    }
  }

  # if ($printing == 1){
  #   print "\nOriginal array: @customers\n";
  #   print "\nFiltered array: @filtered_array\n";
  # }

  return @filtered_array;

}

sub multi_account_issues
{
  foreach ( @multi_issues ){
    my $multi_ln = $_;
    my ($customer, $resolve_id, $contact, $priority, $rtop, $rtop_type, $rtop_time,
        $init_impact, $current_impact, $alpha, $event_desc, $incident_start, $priority_start,
        $incident_end, $priority_end, $status, $incident_duration, $cm_engaged, $cm_notified,
        $ext_records, $kpe, $next_actions, $event_res, $event_root) = split(/~~~/, $multi_ln);

    my @customer_array = split(/,/, $customer);
    my @customer_array = remove_duplicates(@customer_array);

    # ------------- INCLUDE THE MULTIPLE ACCOUNTS OF EACH ISSUE
    # ------------- ADD COUNT TO CUSTOMER BUT ONLY ADD ONE TO THE SUMMARY COUNT
		my ($temp_customer, $resolve_client);
    foreach ( @customer_array ){
      my $c = $_;

			if (defined($l2_resolve{CUSTOMER}{$c})) {
				$temp_customer = $c;
			} else {
				$temp_customer = map_customer_to_sp(\%account_reg,$c,"","ANY");
				$resolve_client = $c;
				next if ($temp_customer =~ /not_mapped/i);
			}


			# remove double spaces in descriptions

			$init_impact=~s/\x{0023}//g;
			$init_impact=~s/\x{00A0}//g;
			$init_impact=~s/\x{00C2}//g;

			$current_impact=~s/\x{0023}//g;
			$current_impact=~s/\x{00A0}//g;
			$current_impact=~s/\x{00C2}//g;

			$event_res=~s/\x{0023}//g;
			$event_res=~s/\x{00A0}//g;
			$event_res=~s/\x{00C2}//g;

			$event_root=~s/\x{0023}//g;
			$event_root=~s/\x{00A0}//g;
			$event_root=~s/\x{00C2}//g;

			# extract date values: month, year, days
      my $month_label = $incident_start;
      # Date example: 2019-12-06 09:28:00.0
      if ($incident_start =~ /^(\d{2})\-(\d{2})\-(\d{4})\s+(\d{2})\:(\d{2})\:(\d{2})/){
        my $date_start_tick = POSIX::mktime($6,$5,$4,$3,$2,$1);
      }
      my $state = define_issue_state($status);
      # print "$incident_end = $state \n";

      # add to account summary
      $l2_resolve{CUSTOMER}{$temp_customer}{COUNT}{VALUE}++;
      $l2_resolve{CUSTOMER}{$temp_customer}{COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_resolve.pl?&customer=$temp_customer\">".$l2_resolve{CUSTOMER}{$temp_customer}{COUNT}{VALUE}."</a>" ;

      # TODO define color code for different numbers.
      $l2_resolve{CUSTOMER}{$temp_customer}{COUNT}{COLOR} = $cgreen;

      # Set Priority
      my $priority_label = "P"."$priority";
      # Divide by STATE
      # State ALL
      $l2_resolve{CUSTOMER}{$temp_customer}{PRIORITY}{"ALL_COUNT"}{STATE}{"ALL"}{COUNT}{VALUE}++;
      $l2_resolve{CUSTOMER}{$temp_customer}{PRIORITY}{"ALL_COUNT"}{STATE}{"ALL"}{COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_resolve.pl?&customer=$temp_customer\">".$l2_resolve{CUSTOMER}{$temp_customer}{PRIORITY}{"ALL_COUNT"}{STATE}{"ALL"}{COUNT}{VALUE}."</a>";
      $l2_resolve{CUSTOMER}{$temp_customer}{PRIORITY}{$priority_label}{STATE}{"ALL"}{COUNT}{VALUE}++;
      $l2_resolve{CUSTOMER}{$temp_customer}{PRIORITY}{$priority_label}{STATE}{"ALL"}{COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_resolve.pl?&customer=$temp_customer&priority=$priority_label\">".$l2_resolve{CUSTOMER}{$temp_customer}{PRIORITY}{$priority_label}{STATE}{"ALL"}{COUNT}{VALUE}."</a>";

      # State defined
      $l2_resolve{CUSTOMER}{$temp_customer}{PRIORITY}{"ALL_COUNT"}{STATE}{$state}{COUNT}{VALUE}++;
      $l2_resolve{CUSTOMER}{$temp_customer}{PRIORITY}{"ALL_COUNT"}{STATE}{$state}{COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_resolve.pl?&customer=$temp_customer&state=$state\">".$l2_resolve{CUSTOMER}{$temp_customer}{PRIORITY}{"ALL_COUNT"}{STATE}{$state}{COUNT}{VALUE}."</a>";
      $l2_resolve{CUSTOMER}{$temp_customer}{PRIORITY}{$priority_label}{STATE}{$state}{COUNT}{VALUE}++;
      $l2_resolve{CUSTOMER}{$temp_customer}{PRIORITY}{$priority_label}{STATE}{$state}{COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_resolve.pl?&customer=$temp_customer&priority=$priority_label&state=$state\">".$l2_resolve{CUSTOMER}{$temp_customer}{PRIORITY}{$priority_label}{STATE}{$state}{COUNT}{VALUE}."</a>";


      # catch rtop assigned
      if (defined($rtop) && $rtop != ''){
        $l2_resolve{CUSTOMER}{$temp_customer}{RTOP}{"ALL_COUNT"}{STATE}{"ALL"}{COUNT}{VALUE}++;
        $l2_resolve{CUSTOMER}{$temp_customer}{RTOP}{"ALL_COUNT"}{STATE}{"ALL"}{COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_resolve.pl?&customer=$temp_customer&rtop=1\">".$l2_resolve{CUSTOMER}{$temp_customer}{RTOP}{"ALL_COUNT"}{STATE}{"ALL"}{COUNT}{VALUE}."</a>";
        $l2_resolve{CUSTOMER}{$temp_customer}{RTOP}{$priority_label}{STATE}{"ALL"}{COUNT}{VALUE}++;
        $l2_resolve{CUSTOMER}{$temp_customer}{RTOP}{$priority_label}{STATE}{"ALL"}{COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_resolve.pl?&customer=$temp_customer&priority=$priority_label&rtop=1\">".$l2_resolve{CUSTOMER}{$temp_customer}{RTOP}{$priority_label}{STATE}{"ALL"}{COUNT}{VALUE}."</a>";

        # Divide by state
        $l2_resolve{CUSTOMER}{$temp_customer}{RTOP}{"ALL_COUNT"}{STATE}{$state}{COUNT}{VALUE}++;
        $l2_resolve{CUSTOMER}{$temp_customer}{RTOP}{"ALL_COUNT"}{STATE}{$state}{COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_resolve.pl?&customer=$temp_customer&rtop=1&state=$state\">".$l2_resolve{CUSTOMER}{$temp_customer}{RTOP}{"ALL_COUNT"}{STATE}{$state}{COUNT}{VALUE}."</a>";
        $l2_resolve{CUSTOMER}{$temp_customer}{RTOP}{$priority_label}{STATE}{$state}{COUNT}{VALUE}++;
        $l2_resolve{CUSTOMER}{$temp_customer}{RTOP}{$priority_label}{STATE}{$state}{COUNT}{HTML} = "<a href=\"$drilldown_dir/l3_resolve.pl?&customer=$temp_customer&priority=$priority_label&rtop=1&state=$state\">".$l2_resolve{CUSTOMER}{$temp_customer}{RTOP}{$priority_label}{STATE}{$state}{COUNT}{VALUE}."</a>";

      }

      $l3_resolve{CUSTOMER}{$temp_customer}{PRIORITY}{$priority_label}{$resolve_id}{CONTACT} = $contact;
      $l3_resolve{CUSTOMER}{$temp_customer}{PRIORITY}{$priority_label}{$resolve_id}{PRIORITY} = $priority;
      if (defined($rtop) && $rtop != ''){
          $l3_resolve{CUSTOMER}{$temp_customer}{PRIORITY}{$priority_label}{$resolve_id}{RTOP_ID} = "<a href=\"$drilldown_dir/l3_rtops.pl?id=$rtop\">$rtop";
          $l3_resolve{CUSTOMER}{$temp_customer}{PRIORITY}{$priority_label}{$resolve_id}{RTOP_TYPE} = $rtop_type;
          $l3_resolve{CUSTOMER}{$temp_customer}{PRIORITY}{$priority_label}{$resolve_id}{RTOP_TIME} = $rtop_time;
        }
      $l3_resolve{CUSTOMER}{$temp_customer}{PRIORITY}{$priority_label}{$resolve_id}{INIT_IMPACT} = $init_impact;
      $l3_resolve{CUSTOMER}{$temp_customer}{PRIORITY}{$priority_label}{$resolve_id}{CURRENT_IMPACT} = $current_impact;
      $l3_resolve{CUSTOMER}{$temp_customer}{PRIORITY}{$priority_label}{$resolve_id}{EVENT_DESC} = $event_desc;
      $l3_resolve{CUSTOMER}{$temp_customer}{PRIORITY}{$priority_label}{$resolve_id}{ALPHA} = $alpha;
      $l3_resolve{CUSTOMER}{$temp_customer}{PRIORITY}{$priority_label}{$resolve_id}{START} = $incident_start;
      $l3_resolve{CUSTOMER}{$temp_customer}{PRIORITY}{$priority_label}{$resolve_id}{PRIORITY_START} = $priority_start ;
      $l3_resolve{CUSTOMER}{$temp_customer}{PRIORITY}{$priority_label}{$resolve_id}{PRIORITY_END} = $priority_end ;
      $l3_resolve{CUSTOMER}{$temp_customer}{PRIORITY}{$priority_label}{$resolve_id}{STATUS} = $status || "null" ;
      $l3_resolve{CUSTOMER}{$temp_customer}{PRIORITY}{$priority_label}{$resolve_id}{END} = $incident_end ;
      # TODO Set duration in sec, minutes, hours.
      $l3_resolve{CUSTOMER}{$temp_customer}{PRIORITY}{$priority_label}{$resolve_id}{DURATION} = $incident_duration ;
      $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{DURATION} = $incident_duration ;
      $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{CM_ENGAGED} = $cm_engaged ;
      $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{CM_NOTIFIED} = $cm_notified ;
      $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{EXT_RECORDS} = $ext_records ;
      $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{KPE} = $kpe ;
      $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{NEXT_ACTIONS} = $next_actions ;
      $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{EVENT_RES} = $event_res ;
      $l3_resolve{CUSTOMER}{$customer}{PRIORITY}{$priority_label}{$resolve_id}{EVENT_ROOT} = $event_root ;
    }

  }

}

get_reSolve_data();
multi_account_issues();


print_l2_test();

# TODO print totals and count by each customer to match l2 and raw cache

save_hash("cache.l2_resolve", \%l2_resolve,"$cache_dir/l2_cache");
save_hash("cache.l3_resolve", \%l3_resolve,"$cache_dir/l3_cache");

my $end_time = time();
printf "Completed Processing after %0.1f Mins\n", ($end_time - $start_time) / 60;
