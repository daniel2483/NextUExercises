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

my $filter_region = param('region') || "All";
my $filter_state = param('state') || "ALL";
my $filter_customer = param('customer') || "ALL";
my $filter_capability = param('capability') || "ALL";
my $filter_center = param('center') || "ALL";
my $filter_type = param('type');
my $filter_xls = param('xls');
#
print "Content-type: text/html\n\n";

my @resolve_states = ('active', 'closed', 'month'. 'year');

# --CGI CHECK
# my $bad_parameters = validate_cgi_parameters(["region", "customer", "type","xls"]);
# if (scalar(@{$bad_parameters}) > 0) {
# 	print "This report has been passed one or more invalid parameters<br>";
# 	my $bad_str = join(',', @{$bad_parameters});
# 	print "please check: $bad_str<br>";
# 	exit;
# }
# #-----

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

# <script src="/ui5/resources/depends/tablesorter/jquery.tablesorter.js"></script>
# <script src="/ui5/resources/depends/tablesorter/widgets/widget-filter.js"></script>
# <link rel="stylesheet" href="/ui5/resources/css/filter.formatter.css">

print <<END;
<!doctype html>
<html>
<head>
<title>ReSolve</title>
<script>jQuery(document).ready(function() {jQuery("#toolspen").tablesorter({
	sortList: [[10,1]],
	widgets: ["filter"],
	headers: {
		'.count-name':{ filter: false },
		'.aad':{ filter: false },
		'.han':{ filter: false },
		'.dmap':{filter: false },
		'.month':{filter: false }

	},
	textExtraction: function (node) {
		var txt = \$(node).text();
		txt = txt.replace('No Data', '');
		return txt;
	},
	emptyTo: 'bottom',
	widgetOptions : {
		filter_cssFilter   : '',
		filter_placeholder : { search : 'Search'}
	}
}); }); </script>
<script>
function setDefaults()
{
  var state = getParameterByName('state');
	var region = getParameterByName('region');
	var customer = getParameterByName('customer');
	var team = getParameterByName('team');
	var status = getParameterByName('status');
	var os = getParameterByName('os');
	var eol = getParameterByName('eol');
	var owner = getParameterByName('owner');

  if(state != null)
	document.getElementById('state').value = state;

	if(region != null)
	document.getElementById('region').value = region;
	if(customer != null)
	document.getElementById('customer').value = customer;
	if(team != null)
	document.getElementById('team').value = team;
	if(status != null)
	document.getElementById('status').value = status;
	if(os != null)
	document.getElementById('os').value = os;
	if(eol != null)
	document.getElementById('eol').value = eol;
	if(owner != null)
	document.getElementById('owner').value = owner;

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
	width: 50px;
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

my %l2_resolve;
my $list = load_cache_byFile("$cache_dir/l2_cache/cache.l2_resolve");
%l2_resolve = %{$list};

my %account_reg = get_filtered_accounts();

# TODO add graphs for total incidents and RTOP incidents

# Add filters for Incidents

my $sel_all  = '';
my $sel_active = '';
my $sel_closed = '';
if ($filter_state){
  if ($filter_state eq "active"){
    $sel_active = 'selected="selected"';
  }
  if ($filter_state eq "closed"){
    $sel_closed = 'selected="selected"';
  }
  if ($filter_state eq "ALL"){
    $sel_all = 'selected="selected"';
  }
}


print '<form>';
print '<b>Type</b>:';
print '<select name="state" id="state">'."\n";
$xls_attr{AIP_FORM}{state}{displayName}="Type";
print '<option value="ALL" '. $sel_all .' >All</option>'."\n";
$xls_attr{AIP_FORM}{state}{selected}="ALL" if $filter_state eq "ALL";
$xls_attr{AIP_FORM}{state}{options}{"ALL"}="All";
print '<option value="active" '. $sel_active .'>Active</option>'."\n";
$xls_attr{AIP_FORM}{state}{options}{"active"}="Active";
$xls_attr{AIP_FORM}{state}{selected}="active" if $filter_state eq "active";
print '<option value="closed" '. $sel_closed .'>Closed</option>'."\n";
$xls_attr{AIP_FORM}{state}{options}{"closed"}="Closed";
$xls_attr{AIP_FORM}{state}{selected}="closed" if $filter_state eq "closed";
# print '<option value="month">Month to Date</option>'."\n";
# print '<option value="year">Year to Date</option>'."\n";
print '</select>'."\n";
print '</form>';

print '<form>';

print '</form>';

my @l2_graph;

push @l2_graph, { 'div-id' => 'oc-l2-bar-graph1',
                                              'graph-type' => 'bar',
                                              'label' => 'P1 Incidents Count',
                                              'height' => 200,
                                              'width' => 600,
                                              'type' => 'sum',
                                              'columns' => "3::P1,7::RTOP P1,12::NoRTOP P1"};

push @l2_graph, { 'div-id' => 'oc-l2-pie-graph2',
                                              'graph-type' => 'pie',
                                              'label' => 'ALL HPIM',
                                              'height' => 200,
                                              'width' => 600,
                                              'type' => 'sum',
                                              'columns' => "3::P1,4::P2,5::P3"};

    create_graph_elements(\@l2_graph);



# Print headers for the table
print '<TABLE id="toolspen" class="tablesorter l2-table perl-xls">'."\n";
print '<THEAD>';
  print '<TR>'."\n";
  $xls_attr{XLS_X}=0;

  tableHeaderColumn_xls("ReSolve - Customer = $filter_customer - Status = $filter_state    Last 30 Days",{COL_SPAN=>17, ROW_SPAN=>1}, \%xls_attr);
  print '</TR>'."\n";

  print '<TR>'."\n";
  $xls_attr{XLS_X}=0;
  $xls_attr{XLS_Y}++;
  tableHeaderColumn_xls("Customer Name",{COL_SPAN=>1, ROW_SPAN=>2}, \%xls_attr);
  tableHeaderColumn_xls("Delivery Map",{CLASS_NAME=>'dmap table-hide', COL_SPAN=>1, ROW_SPAN=>2}, \%xls_attr);
  tableHeaderColumn_xls("Region",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>2}, \%xls_attr);
  tableHeaderColumn_xls("HPIM",{CLASS_NAME=>"table-hide", COL_SPAN=>4, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("RTOPS",{CLASS_NAME=>"table-hide", COL_SPAN=>5, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("No RTOPS",{CLASS_NAME=>"table-hide", COL_SPAN=>5, ROW_SPAN=>1}, \%xls_attr);
  print '</TR>'."\n";
  print '<TR>'."\n";
  $xls_attr{XLS_X}=0;
  $xls_attr{XLS_Y}++;
  # HPIM columns
  tableHeaderColumn_xls("P1",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("P2",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("P3",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("ALL",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  # RTOP columns
  tableHeaderColumn_xls("P1",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("P1 %",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("P2",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("P3",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("ALL",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  # No RTOP columns
  tableHeaderColumn_xls("P1",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("P1 %",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("P2",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("P3",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  tableHeaderColumn_xls("ALL",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
  print '</TR>'."\n";
print '</THEAD><TBODY>';

# print data for tables
foreach my $customer (sort keys %account_reg) {
	my $c = $customer;
	$c =~ s/\b(\w)/\U$1/g; # To capitalize first letter of each string separated by blank space
	next if (!defined($l2_resolve{CUSTOMER}{$customer}));
	next if (check_region_filter($customer, $filter_region, \%account_reg));
	next if ($filter_customer !~ /^ALL$/i and $filter_customer !~ /^\Q$customer\E$/i);
  next if ($filter_region !~ /all/i and $filter_region !~ /$account_reg{$customer}{sp_region}/i);

  my $rtop_percentage = do_percentage($l2_resolve{CUSTOMER}{$customer}{PRIORITY}{"P1"}{STATE}{$filter_state}{COUNT}{VALUE}, $l2_resolve{CUSTOMER}{$customer}{RTOP}{"P1"}{STATE}{$filter_state}{COUNT}{VALUE});
  my $no_rtop_percentage = do_percentage($l2_resolve{CUSTOMER}{$customer}{PRIORITY}{"P1"}{STATE}{$filter_state}{COUNT}{VALUE}, $l2_resolve{CUSTOMER}{$customer}{No_RTOP}{"P1"}{STATE}{$filter_state}{COUNT}{VALUE});
  my $rtop_percentage_color = ($rtop_percentage <= 80 ) ? "RED" : "GREEN";
  my $no_rtop_percentage_color = ($no_rtop_percentage >= 20 ) ? "RED" : "GREEN";

	my $region = $account_reg{$customer}{sp_region};
	$region =~ s/\b(\w)/\U$1/g; # To capitalize first letter of each string separated by blank space

	print '<TR>';
	$xls_attr{XLS_X}=0;
	$xls_attr{XLS_Y}++;
   	tableDataMultipleRow_xls("$c", {COL_SPAN=>1, ROW_SPAN=>1},  \%xls_attr);
   	tableDataMultipleRow_xls("<a target=\"_blank\" href=\"$drilldown_dir/custDetails.pl?cust=$customer\">contacts</a>", {COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
   	tableDataMultipleRow_xls($region, {COL_SPAN=>1, ROW_SPAN=>1},  \%xls_attr);
    # HPIM
   	tableDataMultipleRow_xls($l2_resolve{CUSTOMER}{$customer}{PRIORITY}{"P1"}{STATE}{$filter_state}{COUNT}{HTML} || 0, {COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
   	tableDataMultipleRow_xls($l2_resolve{CUSTOMER}{$customer}{PRIORITY}{"P2"}{STATE}{$filter_state}{COUNT}{HTML} || 0, {COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
   	tableDataMultipleRow_xls($l2_resolve{CUSTOMER}{$customer}{PRIORITY}{"P3"}{STATE}{$filter_state}{COUNT}{HTML} || 0, {COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
   	tableDataMultipleRow_xls($l2_resolve{CUSTOMER}{$customer}{PRIORITY}{"ALL_COUNT"}{STATE}{$filter_state}{COUNT}{HTML} || 0, {COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
    # RTOP
   	tableDataMultipleRow_xls($l2_resolve{CUSTOMER}{$customer}{RTOP}{"P1"}{STATE}{$filter_state}{COUNT}{HTML} || 0, {COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
   	tableDataMultipleRow_xls($rtop_percentage || 0, {COL_SPAN=>1, ROW_SPAN=>1, COLOR=>$no_rtop_percentage_color}, \%xls_attr);
   	tableDataMultipleRow_xls($l2_resolve{CUSTOMER}{$customer}{RTOP}{"P2"}{STATE}{$filter_state}{COUNT}{HTML} || 0, {COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
   	tableDataMultipleRow_xls($l2_resolve{CUSTOMER}{$customer}{RTOP}{"P3"}{STATE}{$filter_state}{COUNT}{HTML} || 0, {COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		tableDataMultipleRow_xls($l2_resolve{CUSTOMER}{$customer}{RTOP}{"ALL_COUNT"}{STATE}{$filter_state}{COUNT}{HTML} || 0, {COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
    # No RTOP
   	tableDataMultipleRow_xls($l2_resolve{CUSTOMER}{$customer}{No_RTOP}{"P1"}{STATE}{$filter_state}{COUNT}{HTML} || 0, {COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
    tableDataMultipleRow_xls($no_rtop_percentage || 0, {COL_SPAN=>1, ROW_SPAN=>1, COLOR=>$no_rtop_percentage_color}, \%xls_attr);
   	tableDataMultipleRow_xls($l2_resolve{CUSTOMER}{$customer}{No_RTOP}{"P2"}{STATE}{$filter_state}{COUNT}{HTML} || 0, {COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
   	tableDataMultipleRow_xls($l2_resolve{CUSTOMER}{$customer}{No_RTOP}{"P3"}{STATE}{$filter_state}{COUNT}{HTML} || 0, {COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		tableDataMultipleRow_xls($l2_resolve{CUSTOMER}{$customer}{No_RTOP}{"ALL_COUNT"}{STATE}{$filter_state}{COUNT}{HTML} || 0, {COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
	print '</TR>';
}

print '</TBODY>' ;

##Table footer
my %footer = (
                 'label_span' => 3,
                 'columns' => 'sum::All_P1[3],sum::All_P2[4],sum::All_P3[5],sum::ALL_count[6],sum::P1_RTOP[7],avg::P1_RTOP[8],sum::P2_RTOP[9],sum::P3_RTOP[10],sum::ALL_RTOP[11],
								 sum::P1_noRTOP[12],avg::P1_noRTOP[13],sum::P2_noRTOP[14],sum::P3_noRTOP[15],sum::ALL_P1_noRTOP[16]'
             );

create_footer(\%footer);

print '</TABLE>';

my $end_time = time;
my $load_time = $end_time - $start_time;

print "<div id=\"server-load-time\" data-load-time=\"$load_time\" style=\"display:none\"></div>\n";

print '<div class="page-info">Page generated at <span id=localdt></span></div>';
print '<script> d = new Date(); document.getElementById("localdt").innerHTML = d;</script>';
print '</body> </html>';

if ($filter_xls eq 1) {
		finish_formats($workbook, \%xls_attr);
}

if ($filter_api eq 1) {
	api_json(\%xls_attr);
}
sub check_state {

  my $temp_hash = $_;

  if (defined($filter_state)){
    if ($filter_state eq 'active') {

    }
  }
}

sub do_percentage {
  # get both values as parameters
  my @params = @_;
  # $_[0] -> total over percentage
  # $_[1] -> value over percentage

  # check for 0 in total
  if ($_[0] == 0) {
    return "";
  }
  else {
    # calculate percentage
    my $percentage = ($_[1] / $_[0]) * 100;
    if (defined($percentage)) {
      $percentage = sprintf("%.2f", $percentage);
      return $percentage;
    }
    else {
      return "";
    }
  }

}
