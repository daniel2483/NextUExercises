#!/usr/bin/perl
#
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
use POSIX qw(strftime);
use Excel::Writer::XLSX;

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

my $start_time = time;

my %opts = ();

getopts('d', \%opts);
print "Content-type: text/html\n\n";

my $filter_region = param('region') || "All";
my $filter_customer = param('customer') || "ALL";
my $filter_priority = param('priority') || 'ALL';
my $filter_rtop = param('rtop');
my $filter_state = param('state');
my $filter_type = param('type');
my $filter_xls = param('xls');
#
# print "<pre>";
# print "RTOP ".$filter_rtop."\n";
# print "Priority ".$filter_priority."\n";
# print "State ".$filter_state."\n";
# print "</pre>";


#--CGI CHECK
# my $bad_parameters = validate_cgi_parameters(["region", "customer", "type","xls"]);
# if (scalar(@{$bad_parameters}) > 0) {
# 	print "This report has been passed one or more invalid parameters<br>";
# 	my $bad_str = join(',', @{$bad_parameters});
# 	print "please check: $bad_str<br>";
# 	exit;
# }
#----

my %xls_attr;
my $filter_api = param('api');
if ($filter_api eq 1)
{
	# API
	$xls_attr{API} = "YES";
}
my $workbook;

# Create a new Excel workbook
if ($filter_xls eq 1)
{
     binmode STDOUT;
     $workbook = Excel::Writer::XLSX->new( \*STDOUT );
     # Add a worksheet
     $xls_attr{WORKSHEET} = $workbook->add_worksheet();
     set_formats($workbook, \%xls_attr);
}


# <title>RTOPS Report</title>
# <script src="../../../ui4/resources/depends/tablesorter/jquery.tablesorter.js"></script>
# <script src="../../../ui4/resources/depends/tablesorter/widgets/widget-filter.js"></script>
# <link rel="stylesheet" href="../../../ui4/resources/css/filter.formatter.css">

print <<END;
<!doctype html>
<html>
<head>
<script>jQuery(document).ready(function() {jQuery("#toolspen").tablesorter({
	widgets: ["filter"],
	headers: {
		'.count-name':{ filter: false },
		'.dmap':{filter: false }
	},
	widgetOptions : {
		filter_cssFilter   : '',
		filter_placeholder : { search : 'search'},
		filter_functions : {

		}
	}
}); }); </script>
<script>
function setDefaults()
{
	var region = getParameterByName('region');
	var capability = getParameterByName('capability');
	var customer = getParameterByName('customer');

	if(region != null)
	document.getElementById('region').value = region;
	if(capability != null)
	document.getElementById('capability').value = capability;
	if(customer != null)
	document.getElementById('customer').value = customer;
}

function getParameterByName(name)
{
	name = name.replace(/[\[]/, "\\[").replace(/[\]]/, "\\]");
	var regex = new RegExp("[\\?&]" + name + "=([^&#]*)"),
	results = regex.exec(location.search);
	var ret =  results === null ? "" : decodeURIComponent(results[1].replace(/\\+/g, " "));
	return ret === "" ? null : ret;
}
</script>
<style>
.tablesorter {
	width: auto;
}
.tablesorter .tablesorter-filter {
	width: 70px;
}
.tablesorter .filtered {
	display: none;
}

/* ajax error row */
.tablesorter .tablesorter-errorRow td {
	text-align: center;
	cursor: pointer;
	background-color: #e6bf99;
}
</style>
</head>
<body onload="setDefaults()">
END

my %account_reg = get_filtered_accounts();
my %l3_resolve;
my $d  = load_cache_byFile("$cache_dir/l3_cache/cache.l3_resolve");
%l3_resolve = %{$d};

my @priorities = ("P1", "P2", "P3");

# IDEA sub if user wants to display all PRIORITY
# IDEA sub if user wants to display all RTOPS

# TODO filter by state more comments

print '<TABLE id="toolspen" class="tablesorter l2-table perl-xls">'."\n";
print '<THEAD>';
  print '<TR>'."\n";
  $xls_attr{XLS_X}=0;

  my $temp_state = "ALL";
  if (defined($filter_state)){
    $temp_state = $filter_state;
  }
  tableHeaderColumn_xls("ReSolve - $filter_customer - PRIORITY=$filter_priority - STATE=$temp_state ",{COL_SPAN=>24, ROW_SPAN=>1}, \%xls_attr);
  print '</TR>'."\n";

  print '<TR>'."\n";
  $xls_attr{XLS_X}=0;
  $xls_attr{XLS_Y}++;
  tableHeaderColumn_xls("Customer Name",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("Log #",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  #tableHeaderColumn("RTOP Client","$lgrey",1,3,1);
  tableHeaderColumn_xls("Escalation Contact",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("Initial Priority",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("Status",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("RTOP ID",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("RTOP Type",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("RTOP Trigger Time",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("Initial Busines Impact",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("Current Busines Impact",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("Event Description",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("Alpha",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("Incident Start",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("Priority Start",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("Priority End",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("Incident End",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("Incident Duration",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("Crisis mgmt. Engaged ",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("Crisis mgmt. Notified",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("External Records",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("KPE",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("Next Actions",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("Event Resolution",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("Event Root Cause",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  print '</TR>'."\n";
print '</THEAD><TBODY>';


if ($filter_priority eq "ALL") {
	my $priority_temp;

  # Display Only RTOPs, All Priorities
	if (defined($filter_rtop) && $filter_rtop == 1){
		foreach my $p (@priorities){
			foreach my $incident (sort keys %{$l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$p}}) {
				next if !defined($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$p}{$incident}{RTOP_ID});
				next if ($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$p}{$incident}{END} =~ /null/i && $filter_state eq "closed");
        next if ($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$p}{$incident}{END} !~ /null/i && $filter_state eq "active");
				print '<TR>';

				$xls_attr{XLS_X}=0;
				$xls_attr{XLS_Y}++;
				$priority_temp = $p;


				tableDataMultipleRow_xls($filter_customer,{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls("<a href=\"http://resolve.svcs.entsvcs.net/DisplayEntryMagnifyModType.aspx?EntryID=$incident&CallMode=0&ReturnPage=/DisplaySummary.aspx?tb=0\">$incident",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{CONTACT},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{PRIORITY},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{STATUS},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{RTOP_ID},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{RTOP_TYPE},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{RTOP_TIME},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{INIT_IMPACT},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{CURRENT_IMPACT},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{EVENT_DESC},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{ALPHA},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{START},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{PRIORITY_START},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{PRIORITY_END},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{END},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{DURATION},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);

				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{CM_ENGAGED},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{CM_NOTIFIED},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{EXT_RECORDS},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{KPE},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{NEXT_ACTIONS},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{EVENT_RES},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{EVENT_ROOT},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				print '</TR>';
			}
		}
	}
  # Display only No RTOPs, All Priorities
	if (defined($filter_rtop) && $filter_rtop == 0){
		foreach my $p (@priorities){
			foreach my $incident (sort keys %{$l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$p}}) {
        # next if RTOP is defined
				next if defined($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$p}{$incident}{RTOP_ID});
				next if ($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$p}{$incident}{END} =~ /null/i && $filter_state eq "closed");
        next if ($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$p}{$incident}{END} !~ /null/i && $filter_state eq "active");
				print '<TR>';

				$xls_attr{XLS_X}=0;
				$xls_attr{XLS_Y}++;
				$priority_temp = $p;

				tableDataMultipleRow_xls($filter_customer,{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls("<a href=\"http://resolve.svcs.entsvcs.net/DisplayEntryMagnifyModType.aspx?EntryID=$incident&CallMode=0&ReturnPage=/DisplaySummary.aspx?tb=0\">$incident",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{CONTACT},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{PRIORITY},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{STATUS},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{RTOP_ID},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{RTOP_TYPE},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{RTOP_TIME},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{INIT_IMPACT},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{CURRENT_IMPACT},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{EVENT_DESC},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{ALPHA},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{START},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{PRIORITY_START},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{PRIORITY_END},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{END},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{DURATION},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);

				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{CM_ENGAGED},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{CM_NOTIFIED},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{EXT_RECORDS},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{KPE},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{NEXT_ACTIONS},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{EVENT_RES},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{EVENT_ROOT},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				print '</TR>';
			}
		}
	}	else {
		foreach my $p (@priorities){
			foreach my $incident (sort keys %{$l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$p}}) {
        next if ($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$p}{$incident}{END} =~ /null/i && $filter_state eq "closed");
        next if ($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$p}{$incident}{END} !~ /null/i && $filter_state eq "active");
				print '<TR>';

        # Display All issues, All Priorities

				$xls_attr{XLS_X}=0;
				$xls_attr{XLS_Y}++;
				$priority_temp = $p;

				tableDataMultipleRow_xls($filter_customer,{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls("<a href=\"http://resolve.svcs.entsvcs.net/DisplayEntryMagnifyModType.aspx?EntryID=$incident&CallMode=0&ReturnPage=/DisplaySummary.aspx?tb=0\">$incident",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{CONTACT},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{PRIORITY},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{STATUS},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{RTOP_ID},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{RTOP_TYPE},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{RTOP_TIME},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{INIT_IMPACT},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{CURRENT_IMPACT},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{EVENT_DESC},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{ALPHA},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{START},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{PRIORITY_START},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{PRIORITY_END},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{END},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{DURATION},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);

				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{CM_ENGAGED},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{CM_NOTIFIED},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{EXT_RECORDS},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{KPE},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{NEXT_ACTIONS},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{EVENT_RES},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$priority_temp}{$incident}{EVENT_ROOT},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				print '</TR>';
			}
		}
	}

} else {
  # Display Only RTOPs, Defined Priority
	if (defined($filter_rtop) && $filter_rtop == 1){
		foreach my $incident (sort keys %{$l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}}) {
			next if !defined($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{RTOP_ID});
      next if ($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{END} =~ /null/i && $filter_state eq "closed");
      next if ($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{END} !~ /null/i && $filter_state eq "active");
			print '<TR>';

      # Display RTOPs, Defined Priority

			$xls_attr{XLS_X}=0;
			$xls_attr{XLS_Y}++;

			tableDataMultipleRow_xls($filter_customer,{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls("<a href=\"http://resolve.svcs.entsvcs.net/DisplayEntryMagnifyModType.aspx?EntryID=$incident&CallMode=0&ReturnPage=/DisplaySummary.aspx?tb=0\">$incident",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{CONTACT},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{PRIORITY},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{STATUS},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{RTOP_ID},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{RTOP_TYPE},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{RTOP_TIME},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{INIT_IMPACT},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{CURRENT_IMPACT},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{EVENT_DESC},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{ALPHA},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{START},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{PRIORITY_START},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{PRIORITY_END},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{END},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{DURATION},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);

			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{CM_ENGAGED},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{CM_NOTIFIED},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{EXT_RECORDS},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{KPE},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{NEXT_ACTIONS},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{EVENT_RES},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{EVENT_ROOT},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			print '</TR>';
		}
	}
  # Display Only No RTOPs, Defined Priority
	if (defined($filter_rtop && $filter_rtop == 0)){
		foreach my $incident (sort keys %{$l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}}) {
			next if defined($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{RTOP_ID});
      next if ($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{END} =~ /null/i && $filter_state eq "closed");
      next if ($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{END} !~ /null/i && $filter_state eq "active");
			print '<TR>';

      # Display No RTOPs, Defined Priority

			$xls_attr{XLS_X}=0;
			$xls_attr{XLS_Y}++;

			tableDataMultipleRow_xls($filter_customer,{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls("<a href=\"http://resolve.svcs.entsvcs.net/DisplayEntryMagnifyModType.aspx?EntryID=$incident&CallMode=0&ReturnPage=/DisplaySummary.aspx?tb=0\">$incident",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{CONTACT},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{PRIORITY},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{STATUS},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{RTOP_ID},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{RTOP_TYPE},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{RTOP_TIME},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{INIT_IMPACT},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{CURRENT_IMPACT},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{EVENT_DESC},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{ALPHA},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{START},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{PRIORITY_START},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{PRIORITY_END},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{END},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{DURATION},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);

			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{CM_ENGAGED},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{CM_NOTIFIED},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{EXT_RECORDS},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{KPE},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{NEXT_ACTIONS},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{EVENT_RES},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{EVENT_ROOT},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			print '</TR>';
		}
	}	else {
		foreach my $incident (keys %{$l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}}) {
      next if ($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{END} =~ /null/i && $filter_state eq "closed");
      next if ($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{END} !~ /null/i && $filter_state eq "active");
			print '<TR>';

      # Display NO RTOPs, Defined Priority

			$xls_attr{XLS_X}=0;
			$xls_attr{XLS_Y}++;
			tableDataMultipleRow_xls($filter_customer,{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls("<a href=\"http://resolve.svcs.entsvcs.net/DisplayEntryMagnifyModType.aspx?EntryID=$incident&CallMode=0&ReturnPage=/DisplaySummary.aspx?tb=0\">$incident",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{CONTACT},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{PRIORITY},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{STATUS},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{RTOP_ID},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{RTOP_TYPE},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{RTOP_TIME},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{INIT_IMPACT},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{CURRENT_IMPACT},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{EVENT_DESC},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{ALPHA},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{START},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{PRIORITY_START},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{PRIORITY_END},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{END},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{DURATION},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);

			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{CM_ENGAGED},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{CM_NOTIFIED},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{EXT_RECORDS},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{KPE},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{NEXT_ACTIONS},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{EVENT_RES},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			tableDataMultipleRow_xls($l3_resolve{CUSTOMER}{$filter_customer}{PRIORITY}{$filter_priority}{$incident}{EVENT_ROOT},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			print '</TR>';
		}
	}
}

print '</TBODY>';
print '</TABLE>';

print '<div class="page-info">Page generated at <span id=localdt></span>' . "</div>";
print '<script> d = new Date(); document.getElementById("localdt").innerHTML = d;</script>';
print '	</body> </html>';


if ($filter_xls eq 1) {
		finish_formats($workbook, \%xls_attr);
}
if ($filter_api eq 1) {
	api_json(\%xls_attr);
}
