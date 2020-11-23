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
use vars qw($l2_report_dir);
use vars qw($green $red $amber $grey $orange $cyan $cgreen $lgrey $info $info2 $dgrey $voilet $lgolden $lblue $hpe);

# region=all owner=OWNER customer=cibc center='center:goc:philippines' capability=unix
#

my $start_time = time;

my $filter_region = param('region') || "ALL";
my $filter_customer = param('customer') || "ALL";
my $sort_filter = param('sort_filter') || "all_servers";
my $show_tracked = param('show_tracked') || "no";
my $filter_team = param('team') || "ALL";
my $filter_status = param('status') || "in production";
my $filter_capability = param('capability') || "ALL";
my $filter_center = param('center') || "ALL";
my $filter_eol = param('eol') || "ALL";
my $filter_owner = param('owner') || 'OWNER';
my $filter_xls = param('xls');

print "Content-type: text/html\n\n";

#--CGI CHECK
my $bad_parameters = validate_cgi_parameters(["region", "center", "customer", "team",  "capability","status","eol","owner","xls","show_tracked"]);
if (scalar(@{$bad_parameters}) > 0) {
	print "This report has been passed one or more invalid parameters<br>";
	my $bad_str = join(',', @{$bad_parameters});
	print "please check: $bad_str<br>";
	exit;
}

#$filter_xls =1;
my %xls_attr;
my $filter_api = param('api');
if ($filter_api eq 1)
{
	# API
	$xls_attr{API} = "YES";
}

my $workbook;

#my $filter_xls=1;

# Create a new Excel workbook
if ($filter_xls eq 1)
{

	binmode STDOUT;
	$workbook = Excel::Writer::XLSX->new( \*STDOUT );

	# Add a worksheet
	$xls_attr{WORKSHEET} = $workbook->add_worksheet();

	set_formats($workbook, \%xls_attr);


}

my %gots=();
my @customers=();
my %cache=();

my %account_reg = get_filtered_accounts();

# Declaration of global Variable
##--- NEW LOAD CACHE
my $m = load_cache_byFile("$cache_dir/l2_cache/by_filters/menu_filters-l2_server_memcpu");
my %menu_filters;
%menu_filters =%{$m};

my ($fc);

if ($filter_center =~ /^center\:(.*)$/) {
	$filter_center = $1;
} else {
	$filter_center = "ALL";
}
if ($filter_center =~ /^ALL$/i) {
	$filter_center = "ALL";
}
if ($filter_capability =~ /^ALL$/i) {
	$filter_capability = "ALL";
}
if ($filter_customer =~ /^ALL$/i) {
	$fc = "ALL";
} else {
	$fc = $filter_customer;
}

#print "<p>REGION = $filter_region Customer : $filter_customer Center: $filter_center : OS $filter_capability TEAM $filter_team</p>";

my $file = $menu_filters{CUSTOMER}{$fc}{CENTER}{$filter_center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team};

my %l2_server_memcpu;
my $d  =load_cache_byFile("$cache_dir/l2_cache/by_filters/$file");
%l2_server_memcpu = %{$d};


my %system_types;
my %teams;

########################################
# Build filter options TEAMS
########################################

foreach my $customer (keys %{$menu_filters{CUSTOMER}}) {

	next if (check_region_filter($customer, $filter_region, \%account_reg));

	next if ($filter_customer !~ /^ALL$/i and $filter_customer !~ /^\Q$customer\E$/i);

	foreach my $team (keys %{$menu_filters{CUSTOMER}{$customer}{CENTER}{$filter_center}{CAPABILITY}{$filter_capability}{TEAM}}) {

		$teams{$team} = 1;

	}
}

my $count =1;




print <<END;
<!doctype html>
<html>
<head>
<title>Server Capacity and Incident Report</title>
<script src="resources/depends/tablesorter/jquery.tablesorter.js"></script>
<script src="resources/depends/tablesorter/widgets/widget-filter.js"></script>
<link rel="stylesheet" href="resources/css/filter.formatter.css">
<script>

	jQuery(document).ready(function() {



		jQuery("#toolspen").tablesorter({
			sortList: [[5,1]],
			widgets: ["filter"],
			headers: {
				'.count-name':{ filter: false },
				'.aad':{ filter: false },
				'.dmap':{filter: false }
			},
			textExtraction: function (node) {
				var txt = \$(node).text();
				txt = txt.replace('No Data', '');
				return txt;
			},
			emptyTo: 'bottom',
			widgetOptions : {
				filter_cssFilter   : '',
				filter_placeholder : { search : ''},
				filter_functions : {

				}
			}
		});
});




</script>
<script>
function setDefaults()
{
	var region = getParameterByName('region');
	var capability = getParameterByName('capability');
	var customer = getParameterByName('customer');
	var show_tracked = getParameterByName('show_tracked');


	if(region != null)
	document.getElementById('region').value = region;
	if(capability != null)
	document.getElementById('capability').value = capability;
	if(customer != null)
	document.getElementById('customer').value = customer;
	if(show_tracked != null)
	document.getElementById('show_tracked').value = show_tracked;
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
	width: 60px;
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
}
</style>
</head>
<body>
<form>
END
;

#print '<b>Status</b>'."\n";
#print '<select name="status" id="status">'."\n";
#print '<option value="in production">Production</option>'."\n";
#print '<option value="move to production">Move to Production</option>'."\n";
#print '</select>'."\n";

print '&nbsp<b>Team</b>:';
print '<select name="team" id="team">'."\n";
$xls_attr{AIP_FORM}{team}{displayName}="Team";
print '<option selected="selected" value="ALL">ALL</option>'."\n";
$xls_attr{AIP_FORM}{team}{options}{ALL}="ALL";
$xls_attr{AIP_FORM}{team}{selected}="ALL";

# Drawing TEAMS names in filter
foreach my $a (sort keys %teams) {
	next if ($a eq "ALL");
	print "<option value=\"$a\">$a</option>\n";
	$xls_attr{AIP_FORM}{team}{options}{"$a"}=$a;
}
print '</select>'."\n";

#print '<b>Having an OS Instance like</b>:';
#print '<select name="os" id="os">'."\n";
#print '<option selected="selected" value="ALL">ALL</option>'."\n";
#foreach my $a (sort keys %os_class) {
#	next if ($a eq "ALL");
#	print "<option value=\"$a\">$a</option>\n";
#}
#print '</select>'."\n";

#print '<b>EOL</b>:';
#print '<select name="eol" id="eol">'."\n";
#print '<option value="ALL">EOL, Not EOL, Unknown</option>'."\n";
#print '<option value="is_eol">EOL</option>'."\n";
#print '<option value="is_not_eol">Not EOL</option>'."\n";
#print '<option value="unknown">Unknown EOL</option>'."\n";
#print '</select>'."\n";



print '<input type="Submit">'."\n";
print '</form>';



my $DEBUG = 0;  #Off


#my $cache_dir="/opt/OV/www/cgi-bin/KMM/cache";

my $weekNumber = POSIX::strftime("%V", localtime time);

# Declaration of global Variable

my ($customer,$sub,$display,$reg,$country,$esl,$mon,$esl_sub);

my %totals;
my $count =1;

my @l2_graph;

push @l2_graph, { 'div-id' => 'oc-l2-bar-graph1',
             			'graph-type' => 'bar',
             			'label' => 'Baseline',
             			'height' => 200,
             			'width' => 430,
             			'type' => 'sum',
             			'columns' => "3::cluster nodes,4::servers,5::Exclude,6::Eligible"};

push @l2_graph, { 'div-id' => 'oc-l2-bar-graph2',
             			'graph-type' => 'bar',
             			'label' => '% of Incidents',
             			'height' => 200,
             			'width' => 430,
             			'type' => 'sum',
           	 			'columns' => '7::Capacity'};

push @l2_graph, { 'div-id' => 'oc-l2-bar-graph3',
             			'graph-type' => 'bar',
             			'label' => '# Filesystems < 3M to Fill',
             			'height' => 200,
             			'width' => 430,
             			'type' => 'avg',
           	 			'columns' => '8::ALL,9::KPE'};

push @l2_graph, { 'div-id' => 'oc-l2-bar-graph4',
             			'graph-type' => 'bar',
             			'label' => '# servers with Critical Incidents',
             			'height' => 200,
             			'width' => 430,
             			'type' => 'avg',
           	 			'columns' => '9::Filesystem,10::CPU/MEM'};

create_graph_elements(\@l2_graph);

print '<TABLE id="toolspen" class="tablesorter l2-table perl-xls">'."\n";
print '<THEAD>';
print '<TR>'."\n";
my $month_name_label = $l2_server_memcpu{MONTH};

tableHeaderColumn_xls("Performance/Capacity - $filter_region", {COL_SPAN=>21, ROW_SPAN=>1}, \%xls_attr);

print '</TR>'."\n";


print '<TR>'."\n";
$xls_attr{XLS_X}=0;
$xls_attr{XLS_Y}++;


tableHeaderColumn_xls("Account List",{COL_SPAN=>2, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("Baseline(CMDB)",{CLASS_NAME=>"table-hide", COL_SPAN=>2, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("Reported by CVA(Servers)",{CLASS_NAME=>"table-hide", COL_SPAN=>3, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("CVA Mismatch(Servers)",{CLASS_NAME=>"table-hide", COL_SPAN=>2, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("CVA Data Health",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);

tableHeaderColumn_xls("capacity<br>% of all incidents",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>2}, \%xls_attr);
tableHeaderColumn_xls("Memory",{CLASS_NAME=>"table-hide", COL_SPAN=>3, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("CPU",{CLASS_NAME=>"table-hide", COL_SPAN=>3, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("#Servers with<br>critical incidents",{CLASS_NAME=>"table-hide", COL_SPAN=>4, ROW_SPAN=>1}, \%xls_attr);
print '</TR>'."\n";


print '<TR>'."\n";
$xls_attr{XLS_X}=0;
$xls_attr{XLS_Y}++;


#tableHeaderColumn_Class('count-name',"\#Count",{COL_SPAN=>1, ROW_SPAN=>2}, \%xls_attr);
tableHeaderColumn_xls("Customer Name",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("Delivery Map",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("Servers",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("ETPs",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);

tableHeaderColumn_xls("Servers",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("Memory",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("CPU",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("Not in CMDB",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("In CMDB",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("Days since last record",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);

tableHeaderColumn_xls("#Systems with<br> Less Than 5% Free",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("#Systems with<br> Less Than 10% Free",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("#Systems with<br> Less Than 20% Free",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);

tableHeaderColumn_xls("#Systems with<br> Less Than 5% Free",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("#Systems with<br> Less Than 10% Free",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("#Systems with<br> Less Than 20% Free",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);




tableHeaderColumn_xls("CPU/Mem",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("Monitoring",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("Customer",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("All",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
#tableHeaderColumn_xls("Source",{COL_SPAN=>1, ROW_SPAN=>2}, \%xls_attr);

print '</TR>';
print '<TR>';
$xls_attr{XLS_X}=0;
$xls_attr{XLS_Y}++;


print '</TR>'."\n";
print '</THEAD><TBODY>';

my $count=1;

foreach my $customer (sort keys %account_reg) {
	#next if ($customer !~ /origin/i);
	next if (check_region_filter($customer, $filter_region, \%account_reg));

	#account_in_scope($customer, \%account_reg, "oc_onerun_leader", $filter_region);

#	next if ($filter_region =~ /^region\:/ and not account_in_scope($customer, \%account_reg, "oc_region", $filter_region));
#	next if ($filter_region =~ /^region_group\:/ and not account_in_scope($customer, \%account_reg, "oc_region_grp", $filter_region));
	#next if ($filter_region =~ /^center\:/ and not account_in_scope($customer, \%account_reg, "oc_center", $filter_region));
#	next if ($filter_region =~ /^run_unit\:/ and not account_in_scope($customer, \%account_reg, "oc_run_unit", $filter_region));
#	next if ($filter_region =~ /^onerun_leader\:/ and not account_in_scope($customer, \%account_reg, "oc_onerun_leader", $filter_region));
#	next if ($filter_region =~ /^location\:/ and not account_in_scope($customer, \%account_reg, "oc_delivery_location", $filter_region));
#	next if ($filter_region =~ /^mh_region_subregion\:/ and not account_in_scope($customer, \%account_reg, "mh_region_subregion", $filter_region));

	##Fix for Special Character Matching
	next if ($filter_customer !~ /^ALL$/i and $filter_customer !~ /^\Q$customer\E$/i);

	#Internal Tracker
	#	my ($wintel_tracker_review, $wintel_tracker_review_color, $wintel_tracker) = get_tracker_details(\%internal_tracker,$customer,'prodops - wintel','capacity: servers');
	#	my ($midrange_tracker_review, $midrange_tracker_review_color, $midrange_tracker)  = get_tracker_details(\%internal_tracker,$customer,'prodops - midrange','capacity: servers');

	#	next if ($show_tracked=~/open/i and ($wintel_tracker!~/open/i and $midrange_tracker!~/open/i));

	#my $aad_hyp = 'https://eu-i.svcs.hp.com/QvAJAXZfc/opendoc.htm?document=eBI%2FCapacity_Dashboard.qvw&host=QVS%40EUPRO&select=LB1035,'.$customer.'&select=LB971,in production&sheet=SH23';
	my $aad_hyp = 'https://eu.svcs.entsvcs.net/QvAJAXZfc/opendoc.htm?document=eBI%2FCapacity_Dashboard.qvw&host=QVS%40EUPRO&select=LB1035,'.$customer.'&select=LB971,in production&sheet=SH23';

	foreach my $center (keys %{$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}}) {
		next if ($filter_center !~ /^all/i and $filter_center !~ /$center/i);
		next if ($filter_center =~ /^all/i and $center !~ /^all$/i);

		next if ($l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'cluster node'}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{COUNT} eq "" and
						 $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{COUNT} eq "");
		my $monitored_servers = $l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{COUNT}+
														$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'cluster node'}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{COUNT};
		print '<TR>';
		$xls_attr{XLS_X}=0;
		$xls_attr{XLS_Y}++;

		my $capacity_pct=sprintf "%.2f",$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{EOL_STATUS}{$filter_eol}{'CAPACITY_PERC'}{HTML} ||0;
		my $logo = $account_reg{$customer}{sp_account_logo};
		if ($logo eq "") {$logo='/ITO_OP/Images/noimage.png'; }
		#tableDataMultipleRow_xls("$count");
		tableDataMultipleRow_xls($account_reg{$customer}{dm_account_name_original},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);

		if ($account_reg{$customer}{in_delivery_map} =~ /yes/i) {
			tableDataMultipleRow_xls("<a target=\"_blank\" href=\"$drilldown_dir/custDetails.pl?cust=$customer\">contacts</a>",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		} else {
			tableDataMultipleRow_xls("Not NGDM",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		}
		##
		tableDataMultipleRow_xls($l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{SERVER_CAPACITY_ELIGIBLE}{HTML},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		tableDataMultipleRow_xls($l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{SERVER_CAPACITY_ETP}{HTML},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);

		tableDataMultipleRow_xls($l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{COUNT},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		tableDataMultipleRow_xls($l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{TOTALMEMMONSYS}{HTML},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		tableDataMultipleRow_xls($l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{TOTALCPUMONSYS}{HTML},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);

		tableDataMultipleRow_xls($l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{NOT_IN_CMDB}{HTML},{COL_SPAN=>1, ROW_SPAN=>1,
														COLOR=>$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{NOT_IN_CMDB}{COLOR}}, \%xls_attr);
		tableDataMultipleRow_xls($l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{NOT_IN_CVA}{HTML},{COL_SPAN=>1, ROW_SPAN=>1,
														COLOR=>$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{NOT_IN_CVA}{COLOR}}, \%xls_attr);
		tableDataMultipleRow_xls($l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{LATEST_RECORD}{HTML},{COL_SPAN=>1, ROW_SPAN=>1,
														COLOR=>$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{LATEST_RECORD}{COLOR}}, \%xls_attr);

		my $class = 'ALL';

		tableDataMultipleRow_xls($capacity_pct."%",{COL_SPAN=>1, ROW_SPAN=>1, COLOR=>$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{'CAPACITY_PERC'}{COLOR}}, \%xls_attr);
		tableDataMultipleRow_xls("$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{'LT5PCTFREE'}{HTML}",{COL_SPAN=>1, ROW_SPAN=>1, COLOR=>$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{'LT5PCTFREE'}{COLOR}}, \%xls_attr);
		tableDataMultipleRow_xls("$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{'LT10PCTFREE'}{HTML}",{COL_SPAN=>1, ROW_SPAN=>1, COLOR=>$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{'LT10PCTFREE'}{COLOR}}, \%xls_attr);
		tableDataMultipleRow_xls("$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{'LT20PCTFREE'}{HTML}",{COL_SPAN=>1, ROW_SPAN=>1, COLOR=>$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{'LT20PCTFREE'}{COLOR}}, \%xls_attr);

		tableDataMultipleRow_xls("$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{'CPULT5PCTFREE'}{HTML}",{COL_SPAN=>1, ROW_SPAN=>1, COLOR=>$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{'CPULT5PCTFREE'}{COLOR}}, \%xls_attr);
		tableDataMultipleRow_xls("$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{'CPULT10PCTFREE'}{HTML}",{COL_SPAN=>1, ROW_SPAN=>1, COLOR=>$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{'CPULT10PCTFREE'}{COLOR}}, \%xls_attr);
		tableDataMultipleRow_xls("$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{'CPULT20PCTFREE'}{HTML}",{COL_SPAN=>1, ROW_SPAN=>1, COLOR=>$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{'CPULT20PCTFREE'}{COLOR}}, \%xls_attr);


		#Internal Tracker
		#tableDataMultipleRow_xls($wintel_tracker);
		#tableDataMultipleRow_xls($wintel_tracker_review,1,$wintel_tracker_review_color);


		#Filesystem

		tableDataMultipleRow_xls($l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{PERF}{HTML},{COL_SPAN=>1, ROW_SPAN=>1, COLOR=>$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{PERF}{COLOR}}, \%xls_attr);
		tableDataMultipleRow_xls($l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{MONITORING}{HTML},{COL_SPAN=>1, ROW_SPAN=>1, COLOR=>$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{MONITORING}{COLOR}}, \%xls_attr);
		tableDataMultipleRow_xls($l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{CUSTOMER}{HTML},{COL_SPAN=>1, ROW_SPAN=>1, COLOR=>$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{CUSTOMER}{COLOR}}, \%xls_attr);
		tableDataMultipleRow_xls($l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{ALL}{HTML},{COL_SPAN=>1, ROW_SPAN=>1, COLOR=>$l2_server_memcpu{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{ALL}{COLOR}}, \%xls_attr);

		$count++;
		print '</TR>';
	}
}
print '</TBODY>';

##Table footer
my %footer = (
   								'label_span' => 2,
   								'columns' => 'sum::servers[2],sum::ETPs[3],sum::Memory[4],avg::CPU[5],avg::Cpacity %[6],sum::< 5%[7],sum::< 10%[8],sum::< 20%[9],sum::< 5%[10],sum::< 10%[11],
   								sum::< 20%[12]sum::CPU/Memory[13],sum::monitoring[14],sum::customer[15],sum::all[16]'
   						);

create_footer(\%footer);

print '</TABLE>';

my $end_time = time;
my $load_time = $end_time - $start_time;
print "<div id=\"server-load-time\" data-load-time=\"$load_time\" style=\"display:none\"></div>\n";

print '<div class="page-info">Page generated at <span id=localdt></span> - Using File ' . "$cache_dir/l2_cache/by_filters/$file</div>";
print '<script> d = new Date(); document.getElementById("localdt").innerHTML = d;</script>';
print '	</body> </html>';

if ($filter_xls eq 1) {
		finish_formats($workbook, \%xls_attr);
}

if ($filter_api eq 1) {
	api_json(\%xls_attr);
}
