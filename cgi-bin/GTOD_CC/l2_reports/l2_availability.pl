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
use lib '/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/modules/pm';
use CommonHTML;
use LoadCache;
use CommonFunctions;
use CommonColor;
use Excel::Writer::XLSX;

use vars qw($cache_dir);
use vars qw($rawdata_dir);
use vars qw($cfg_dir);
use vars qw($drilldown_dir);
use vars qw($green $red $amber $grey $orange $cyan $cgreen $lgrey $info $info2 $dgrey $voilet $lgolden $lblue $hpe);

my $start_time = time;

my @months = qw(JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC);
my @monthsfull = qw(January Feburary March April May June July August September October November December);

my $month_c = POSIX::strftime("%m", localtime time);
my $month_name_c = $months[$month_c - 1];


my $month_m1 = (($month_c == 1) ? 12 : $month_c-1);
my $month_name_m1 = $months[$month_m1 - 1];
my $month_fullname_m1=$monthsfull[$month_m1 - 1];


my $month_m2 = (($month_m1 == 1) ? 12 : $month_m1-1);
my $month_name_m2 = $months[$month_m2 - 1];
my $month_fullname_m2=$monthsfull[$month_m2 - 1];


my $month_m3 = (($month_m2 == 1) ? 12 : $month_m2-1);
my $month_name_m3 = $months[$month_m3 - 1];
my $month_fullname_m3=$monthsfull[$month_m3 - 1];


my $filter_region = param('region') || "All";
my $filter_customer = param('customer') || "ALL";
my $filter_team = param('team') || "ALL";
my $filter_status = param('status') || 'in production';
my $filter_capability = param('capability') || "ALL";
my $filter_center = param('center') || "ALL";
my $filter_eol = param('eol') || "ALL";
my $filter_month =param('month')|| "MONTH0";
my $filter_owner = param('owner') || "ALL";
my $filter_xls = param('xls');

print "Content-type: text/html\n\n";

#--CGI CHECK
my $bad_parameters = validate_cgi_parameters(["region", "center", "customer", "team", "capability","status","eol","owner","xls","month"]);
if (scalar(@{$bad_parameters}) > 0) {
	print "This report has been passed one or more invalid parameters<br>";
	my $bad_str = join(',', @{$bad_parameters});
	print "please check: $bad_str<br>";
	exit;
}
#-----

#$filter_xls =1;
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

#print "<p>FILTER CETNER = $filter_center</p>";
if ($filter_center =~ /^center\:(.*)$/) {
	$filter_center = $1;
} else {
	$filter_center = "ALL";
}

$filter_capability = "ALL" if ($filter_capability =~ /^all$/i);



print <<END;
<!doctype html>
<html>
<head>
<title>Availability Monitoring Report</title>
<script src="resources/depends/tablesorter/jquery.tablesorter.js"></script>
<script src="resources/depends/tablesorter/widgets/widget-filter.js"></script>
<link rel="stylesheet" href="resources/css/filter.formatter.css">
<script>jQuery(document).ready(function() {jQuery("#toolspen").tablesorter({
	sortList: [[10,1]],
	widgets: ["filter"],
	headers: {
		'.count-name':{ filter: false },
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
	var region = getParameterByName('region');
	var customer = getParameterByName('customer');
	var team = getParameterByName('team');
	var status = getParameterByName('status');
	var os = getParameterByName('os');
	var eol = getParameterByName('eol');
	var owner = getParameterByName('owner');

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


# Declaration of global Variable
##--- NEW LOAD CACHE
my $m = load_cache_byFile("$cache_dir/l2_cache/by_filters/menu_filters-l2_ebi_availability");
my %menu_filters;
%menu_filters =%{$m};

my ($filter_center, $fc);


if ($filter_region =~ /^center\:(.*)$/) {
	$filter_center = $1;
} else {
	$filter_center = "ALL";
}

if ($filter_customer =~ /^ALL$/i) {
	$fc = "ALL";
} else {
	$fc = $filter_customer;
}

#print "<p>REGION = $filter_region Customer : $filter_customer Center: $filter_center : OS $filter_capability TEAM $filter_team</p>";

my $file = $menu_filters{CUSTOMER}{$fc}{CENTER}{$filter_center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team};

my %l2_ebi_availability;
my $d  =load_cache_byFile("$cache_dir/l2_cache/by_filters/$file");
%l2_ebi_availability = %{$d};

#print "<p>Using File $cache_dir/l2_cache/by_filters/$file</p>";
##---- END

my %account_reg = get_filtered_accounts();
#my %l2_ebi_availability = %{$cache{l2_ebi_availability}};
#my %l2_baseline = %{$cache{l2_system_baseline}};



my %system_types;
my %teams;
my %os_class;

##---NEW MENU
foreach my $customer (keys %{$menu_filters{CUSTOMER}}) {
	next if (check_region_filter($customer, $filter_region, \%account_reg));
#	next if ($filter_region =~ /^region\:/ and not account_in_scope($customer, \%account_reg, "oc_region", $filter_region));
#	next if ($filter_region =~ /^region_group\:/ and not account_in_scope($customer, \%account_reg, "oc_region_grp", $filter_region));
	#next if ($filter_region =~ /^center\:/ and not account_in_scope($customer, \%account_reg, "oc_center", $filter_region));
#	next if ($filter_region =~ /^run_unit\:/ and not account_in_scope($customer, \%account_reg, "oc_run_unit", $filter_region));
#	next if ($filter_region =~ /^onerun_leader\:/ and not account_in_scope($customer, \%account_reg, "oc_onerun_leader", $filter_region));
#	next if ($filter_region =~ /^location\:/ and not account_in_scope($customer, \%account_reg, "oc_delivery_location", $filter_region));
#	next if ($filter_region =~ /^mh_region_subregion\:/ and not account_in_scope($customer, \%account_reg, "mh_region_subregion", $filter_region));

	next if ($filter_customer !~ /^ALL$/i and $filter_customer !~ /^\Q$customer\E$/i);


	foreach my $center (keys %{$menu_filters{CUSTOMER}{$customer}{CENTER}}) {
		#next if ($filter_region !~ /^center/ and $center !~ /ALL/i);
		#next if ($filter_region =~ /^center\:/ and $filter_region !~ /$center/i);
		next if ($filter_center !~ /all/i and $filter_center !~ /$center/i);
		next if ($filter_center =~ /all/i and $center ne "ALL");

		foreach my $os (keys %{$menu_filters{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}}) {


			foreach my $team (keys %{$menu_filters{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$os}{TEAM}}) {
				next if ($team eq "");

				$teams{$team} = 1;
				next if ($filter_team !~ /ALL/i and $filter_team ne $team);
				$os_class{$os} = 1;


			}
		}
	}
}
##-------------

#foreach my $customer (keys %{$l2_ebi_availability{CUSTOMER}}) {
#	foreach my $center (keys %{$l2_ebi_availability{CUSTOMER}{$customer}{CENTER}}) {
#		foreach my $system_type (keys %{$l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}}) {
#
#			next if ($system_type !~ /cluster node|server/);
#			foreach my $os (keys %{$l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{$system_type}{CAPABILITY}}) {
#
#
#				next if ($filter_customer !~ /^ALL$/i and $filter_customer !~ /^\Q$customer\E$/i);
#				next if ($filter_region =~ /^region\:/ and not account_in_scope($customer, \%account_reg, "oc_region", $filter_region));
#				next if ($filter_region =~ /^region_group\:/ and not account_in_scope($customer, \%account_reg, "oc_region_grp", $filter_region));
#				#	next if ($filter_region =~ /^center\:/ and not account_in_scope($customer, \%account_reg, "oc_center", $filter_region));
#				next if ($filter_region =~ /^run_unit\:/ and not account_in_scope($customer, \%account_reg, "oc_run_unit", $filter_region));
#				next if ($filter_region =~ /^onerun_leader\:/ and not account_in_scope($customer, \%account_reg, "oc_onerun_leader", $filter_region));
#				next if ($filter_region =~ /^location\:/ and not account_in_scope($customer, \%account_reg, "oc_delivery_location", $filter_region));
#
#
#				next if ($filter_region !~ /^center/ and $center !~ /ALL/i);
#				next if ($filter_region =~ /^center\:/ and $filter_region !~ /$center/i);
#
#				foreach my $team (keys %{$l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{$system_type}{CAPABILITY}{$os}{TEAM}}) {
#
#					next if ($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{$system_type}{CAPABILITY}{$os}{TEAM}{$team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{COUNT}{VALUE} eq 0);
#					next if ($filter_team !~ /ALL/i and $filter_team !~ /^$team$/i);
#					next if ($filter_capability !~ /ALL/i and $filter_capability !~ /^$os$/i);
#
#
#					$teams{$team} = 1;
#					$os_class{$os} = 1;
#
#
#
#					$system_types{$system_type} = 1;
#				}
#
#			}
#		}
#	}
#}

my $count =1;

###Main
print '<body>';
#FORM
print '<form>';

print '&nbsp<b>Status</b>:';
print '<select name="status" id="status">'."\n";
$xls_attr{AIP_FORM}{status}{displayName}="Status";
print '<option value="in production">Production</option>'."\n";
$xls_attr{AIP_FORM}{status}{options}{"in production"}="Production";
$xls_attr{AIP_FORM}{status}{selected}="in production";
print '<option value="move to production">Move To Production</option>'."\n";
$xls_attr{AIP_FORM}{status}{options}{"move to production"}="Move To Production";
print '</select>'."\n";

print '&nbsp<b>Team</b>:';
print '<select name="team" id="team">'."\n";
$xls_attr{AIP_FORM}{team}{displayName}="Team";
print '<option selected="selected" value="ALL">ALL</option>'."\n";
$xls_attr{AIP_FORM}{team}{options}{ALL}="ALL";
$xls_attr{AIP_FORM}{team}{selected}="ALL";
foreach my $a (sort keys %teams) {
	next if ($a eq "ALL");
	print "<option value=\"$a\">$a</option>\n";
	$xls_attr{AIP_FORM}{team}{options}{"$a"}=$a;
}
print '</select>'."\n";

print '&nbsp<b>EOL</b>:';
print '<select name="eol" id="eol">'."\n";
$xls_attr{AIP_FORM}{eol}{displayName}="EOL";
print '<option value="ALL">EOL,Not EOL,Unknown</option>'."\n";
$xls_attr{AIP_FORM}{eol}{options}{"ALL"}="EOL,Not EOL,Unknown";
$xls_attr{AIP_FORM}{eol}{selected}="ALL";
print '<option value="is_eol">EOL</option>'."\n";
$xls_attr{AIP_FORM}{eol}{options}{is_eol}="EOL";
print '<option value="is_not_eol">Not EOL</option>'."\n";
$xls_attr{AIP_FORM}{eol}{options}{is_not_eol}="Not EOL";
print '<option value="unknown">Unknown EOL</option>'."\n";
$xls_attr{AIP_FORM}{eol}{options}{unknown}="Unknown EOL";
print '</select>'."\n";
\
print '&nbsp<b>Month</b>:';
print '<select name="month" id="month">'."\n";
$xls_attr{AIP_FORM}{month}{displayName}="Month";
print "<option value=\"MONTH0\">Month to Date</option>"."\n";
$xls_attr{AIP_FORM}{month}{options}{MONTH0}="Month to Date";
$xls_attr{AIP_FORM}{month}{selected}="MONTH0";
print "<option value=\"MONTH1\">$month_fullname_m1</option>"."\n";
$xls_attr{AIP_FORM}{month}{options}{MONTH1}=$month_fullname_m1;
print "<option value=\"MONTH2\">$month_fullname_m2</option>"."\n";
$xls_attr{AIP_FORM}{month}{options}{MONTH2}=$month_fullname_m2;
print '</select>'."\n";


print '&nbsp<input type="Submit">'."\n";
print '</form>';

print "<p>Note: This Tile includes only systems classified as cluster nodes or servers</p>";

my %totals;
my $count = 1;
my $rpt_month;

$rpt_month= "Month to Date" if($filter_month eq "MONTH0");
$rpt_month= "Month - $month_fullname_m1" if($filter_month eq "MONTH1");
$rpt_month= "Month - $month_fullname_m2" if($filter_month eq "MONTH2");


	my @l2_graph;

	push @l2_graph, { 'div-id' => 'oc-l2-bar-graph1',
                                                'graph-type' => 'bar',
                                                'label' => 'Baseline',
                                                'height' => 200,
                                                'width' => 430,
                                                'type' => 'sum',
                                                'columns' => "4::Cluster Nodes,5::Servers,6::Exclude,7::Eligible"};

	push @l2_graph, { 'div-id' => 'oc-l2-bar-graph2',
                                                'graph-type' => 'bar',
                                                'label' => 'Availability Metrics',
                                                'height' => 200,
                                                'width' => 430,
                                                'type' => 'sum',
                                                'columns' => "8::Enrolled,10::Not Enrolled,14::Up"};

	push @l2_graph, { 'div-id' => 'oc-l2-bar-graph3',
                                                'graph-type' => 'bar',
                                                'label' => 'Down',
                                                'height' => 200,
                                                'width' => 430,
                                                'type' => 'sum',
                                                'columns' => "11::Unscheduled,12::Missing SLA TGT,15::Down HI >7 Days,16::Down HI <7 Days,17::Down LI >7 Days,18::Down LI <7 Days,19::Scheduled"};

	create_graph_elements(\@l2_graph);



print '<TABLE id="toolspen" class="tablesorter l2-table perl-xls">'."\n";
print '<THEAD>';
print '<TR>'."\n";
if($filter_month=~/MONTH0/){
	tableHeaderColumn_xls("Availability $filter_month $rpt_month [Customer: $filter_customer : Region : $filter_region  : CAPABILITY : $filter_capability : Status : $filter_status : EOL : $filter_eol : Team : $filter_team : Owner Flag : $filter_owner]",{COL_SPAN=>19, ROW_SPAN=>1}, \%xls_attr);
} else {
	tableHeaderColumn_xls("Availability $filter_month $rpt_month [Customer: $filter_customer : Region : $filter_region  : CAPABILITY : $filter_capability : Status : $filter_status : EOL : $filter_eol : Team : $filter_team : Owner Flag : $filter_owner]",{COL_SPAN=>13, ROW_SPAN=>1}, \%xls_attr);
}
print '</TR>'."\n";

print '<TR>'."\n";
$xls_attr{XLS_X}=0;
$xls_attr{XLS_Y}++;

tableHeaderColumn_xls("Account List",{COL_SPAN=>3, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("Baseline",{COL_SPAN=>4, ROW_SPAN=>1}, \%xls_attr);
if($filter_month=~/MONTH0/){
	tableHeaderColumn_xls("Availability Metrics",{COL_SPAN=>12, ROW_SPAN=>1}, \%xls_attr);
}
else{
	tableHeaderColumn_xls("Availability Metrics",{COL_SPAN=>6, ROW_SPAN=>1}, \%xls_attr);
}
print '</TR>'."\n";


print '<TR>'."\n";
$xls_attr{XLS_X}=0;
$xls_attr{XLS_Y}++;

tableHeaderColumn_xls("Customer Name",{COL_SPAN=>1, ROW_SPAN=>2}, \%xls_attr);
tableHeaderColumn_xls("Delivery Map",{CLASS_NAME=>"table-hide", CLASS_NAME=>'dmap', COL_SPAN=>1, ROW_SPAN=>2}, \%xls_attr);
tableHeaderColumn_xls("HAN Ping",{CLASS_NAME=>'han "table-hide"', COL_SPAN=>1, ROW_SPAN=>2}, \%xls_attr);
tableHeaderColumn_xls("Cluster Nodes",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>2}, \%xls_attr);
tableHeaderColumn_xls("Servers",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>2}, \%xls_attr);
tableHeaderColumn_xls("Exclude",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>2}, \%xls_attr);
tableHeaderColumn_xls("Eligible",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>2}, \%xls_attr);
tableHeaderColumn_xls("Enrolled",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>2}, \%xls_attr);
tableHeaderColumn_xls("Enrolled %",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>2}, \%xls_attr);
tableHeaderColumn_xls("Not Enrolled",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>2}, \%xls_attr);
tableHeaderColumn_xls("$rpt_month",{CLASS_NAME=>'month',COL_SPAN=>3, ROW_SPAN=>1}, \%xls_attr);
if($filter_month=~/MONTH0/){
	tableHeaderColumn_xls("#Up",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>2}, \%xls_attr);
	tableHeaderColumn_xls("#Down - High Impact",{CLASS_NAME=>"table-hide", COL_SPAN=>2, ROW_SPAN=>1}, \%xls_attr);
	tableHeaderColumn_xls("#Down - Low Impact",{CLASS_NAME=>"table-hide", COL_SPAN=>2, ROW_SPAN=>1}, \%xls_attr);
	tableHeaderColumn_xls("#Down with<br>Scheduled Outage",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>2}, \%xls_attr);
}


print '</TR>'."\n";
print '<TR>'."\n";
$xls_attr{XLS_X}=0;
$xls_attr{XLS_Y}++;

tableHeaderColumn_xls("#Servers<br>with<br>UnScheduled Outages",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("#Servers<br>missing<br>sla tgt",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("%Servers<br>missing<br>sla tgt",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
if($filter_month=~/MONTH0/){
	tableHeaderColumn_xls("\> 7 days",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
	tableHeaderColumn_xls("\< 7 Days",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
	tableHeaderColumn_xls("\> 7 days",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
	tableHeaderColumn_xls("\< 7 days",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
}

print '</TR>'."\n";
print '</THEAD>';
print '<TBODY>';
$count=1;

foreach my $customer (sort keys %account_reg) {
	next if (check_region_filter($customer, $filter_region, \%account_reg));
	#account_in_scope($customer, \%account_reg, "oc_onerun_leader", $filter_region);

#	next if ($filter_region =~ /^region\:/ and not account_in_scope($customer, \%account_reg, "oc_region", $filter_region));
#	next if ($filter_region =~ /^region_group\:/ and not account_in_scope($customer, \%account_reg, "oc_region_grp", $filter_region));
	#next if ($filter_region =~ /^center\:/ and not account_in_scope($customer, \%account_reg, "oc_center", $filter_region));
#	next if ($filter_region =~ /^run_unit\:/ and not account_in_scope($customer, \%account_reg, "oc_run_unit", $filter_region));
#	next if ($filter_region =~ /^onerun_leader\:/ and not account_in_scope($customer, \%account_reg, "oc_onerun_leader", $filter_region));
#	next if ($filter_region =~ /^location\:/ and not account_in_scope($customer, \%account_reg, "oc_delivery_location", $filter_region));
#	next if ($filter_region =~ /^mh_region_subregion\:/ and not account_in_scope($customer, \%account_reg, "mh_region_subregion", $filter_region));



	#next if ($filter_region !~ /^ALL$/i and $account_reg{$customer}{sp_region} !~ /$filter_region/i);
	##Fix for Special Character Matching
	next if ($filter_customer !~ /^ALL$/i and $filter_customer !~ /^\Q$customer\E$/i);

	foreach my $center (keys %{$l2_ebi_availability{CUSTOMER}{$customer}{CENTER}}) {
		#next if ($filter_region !~ /^center/ and $center !~ /ALL/i);
		#next if ($filter_region =~ /^center\:/ and $filter_region !~ /$center/i);
		next if ($filter_center !~ /all/i and $filter_center !~ /$center/i);
		next if ($filter_center =~ /all/i and $center ne "ALL");
		#next if ($filter_team !~ /ALL/i and $filter_team !~ /^$team$/i);
		#next if (($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'cluster node'}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{COUNT}{VALUE} eq 0
		#				or not defined($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'cluster node'}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{COUNT}{VALUE}))
		#				and ($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{COUNT}{VALUE} eq 0
		#				or not defined($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{COUNT}{VALUE})));

		next if (($filter_owner eq "SSN" or $filter_owner =~ /ESO4SAP/i) and $l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'cluster node'}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{COUNT}{VALUE} eq "" and
						 																														 $l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'server'}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{COUNT}{VALUE} eq "");

		print '<TR>';
		$xls_attr{XLS_X}=0;
		$xls_attr{XLS_Y}++;

		tableDataMultipleRow_xls($account_reg{$customer}{dm_account_name_original},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);

		if ($account_reg{$customer}{in_delivery_map} =~ /yes/i) {
			tableDataMultipleRow_xls("<a target=\"_blank\" href=\"$drilldown_dir/custDetails.pl?cust=$customer\">contacts</a>",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		} else {
			tableDataMultipleRow_xls("Not NGDM",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		}

		my $t1_server = "$account_reg{$customer}{T1_SERVER}";

		if ($account_reg{$customer}{sp_in_esl} =~ /yes/i) {
			tableDataMultipleRow_xls("<a href=\"$drilldown_dir/hanConfig.pl?cust=$customer\">Config</a>",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		} else {
			tableDataMultipleRow_xls("N/A",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		}
		#CIs
		my $cluster_nodes=$l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'cluster node'}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{COUNT}{VALUE} || 0;
		my $servers=$l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{server}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{COUNT}{VALUE} ||0;
		if($cluster_nodes>0){
			tableDataMultipleRow_xls($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{'cluster node'}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{COUNT}{HTML},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		}else{
			tableDataMultipleRow_xls("0",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		}
		if($servers>0){
			tableDataMultipleRow_xls($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{SYSTEM_TYPE}{server}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{COUNT}{HTML},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		}else{
			tableDataMultipleRow_xls("0",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		}
		#Exempted
		if($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{MONTH0_MONITORING_ETP}{VALUE}>0){
			tableDataMultipleRow_xls($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{MONTH0_MONITORING_ETP}{HTML},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		}else{
			tableDataMultipleRow_xls("0",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		}

		#Eligible
		if($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{ELIGIBLE}{VALUE}>0){
			tableDataMultipleRow_xls("$l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{ELIGIBLE}{HTML}",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		}else{
			tableDataMultipleRow_xls("0",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		}

		#ENROLLED
		if($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{MONTH0_ENROLLED}{VALUE}>0){
			tableDataMultipleRow_xls($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{MONTH0_ENROLLED}{HTML},{COL_SPAN=>1, ROW_SPAN=>1, COLOR=>$l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{MONTH0_ENROLLED}{COLOR}}, \%xls_attr);
		}else{
			tableDataMultipleRow_xls("0",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		}
		if($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{MONTH0_ENROLLED_PCT}{VALUE}>0){
			tableDataMultipleRow_xls($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{MONTH0_ENROLLED_PCT}{HTML},{COL_SPAN=>1, ROW_SPAN=>1, COLOR=>$l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{MONTH0_ENROLLED_PCT}{COLOR}}, \%xls_attr);
		}else{
			tableDataMultipleRow_xls("0",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		}

		#Not ENROLLED
		if($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{MONTH0_UNMONITORED}{VALUE}>0){
			tableDataMultipleRow_xls($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{MONTH0_UNMONITORED}{HTML},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		}else{
			tableDataMultipleRow_xls("0",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		}


		#EBI-Unscheduled outages
		if($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{$filter_month . '_UNSCHEDULED_OUTAGE_CNT'}{VALUE}>0){
			tableDataMultipleRow_xls($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{$filter_month . '_UNSCHEDULED_OUTAGE_CNT'}{HTML},{COL_SPAN=>1, ROW_SPAN=>1, COLOR=>$l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{$filter_month . '_UNSCHEDULED_OUTAGE_CNT'}{COLOR}}, \%xls_attr);
		}else{
			tableDataMultipleRow_xls("0",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		}
		if($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{$filter_month . '_SLA_TARGET_EXCEEDED_CNT'}{VALUE} >0){
			tableDataMultipleRow_xls($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{$filter_month . '_SLA_TARGET_EXCEEDED_CNT'}{HTML},{COL_SPAN=>1, ROW_SPAN=>1, COLOR=>$l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{$filter_month . '_UNSCHEDULED_OUTAGE_CNT'}{COLOR}}, \%xls_attr);
		}else{
			tableDataMultipleRow_xls("0",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		}

		if($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{$filter_month . '_SLA_TARGET_EXCEEDED_PCT'}{VALUE} >0){
			tableDataMultipleRow_xls($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{$filter_month . '_SLA_TARGET_EXCEEDED_PCT'}{HTML},{COL_SPAN=>1, ROW_SPAN=>1, COLOR=>$l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{$filter_month . '_SLA_TARGET_EXCEEDED_PCT'}{COLOR}}, \%xls_attr);
		}else{
			tableDataMultipleRow_xls("0",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		}


		##IF THIS MONTH
		if($filter_month=~/MONTH0/){
			#UP
			if($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{MONTH0_PING_UP}{VALUE}>0){
				tableDataMultipleRow_xls($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{MONTH0_PING_UP}{HTML},{COL_SPAN=>1, ROW_SPAN=>1, COLOR=>$l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{MONTH0_PING_UP}{COLOR}}, \%xls_attr);
			}else{
				tableDataMultipleRow_xls("0",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			}


			#Down High Impact
			# >7 Days
			if($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{MONTH0_HIGH_PING_7DOWN}{VALUE}>0){
				tableDataMultipleRow_xls($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{MONTH0_HIGH_PING_7DOWN}{HTML},{COL_SPAN=>1, ROW_SPAN=>1, COLOR=>$l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{MONTH0_HIGH_PING_7DOWN}{COLOR}}, \%xls_attr);
			}else{
				tableDataMultipleRow_xls("0",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			}

			#Down High Impact
			#now
			if($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{MONTH0_HIGH_PING_DOWN}{VALUE}>0){
				tableDataMultipleRow_xls($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{MONTH0_HIGH_PING_DOWN}{HTML},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			}else{
				tableDataMultipleRow_xls("0",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			}

			#Down Low Impact
			# > 7days
			if($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{MONTH0_LOW_PING_7DOWN}{VALUE}>0){
				tableDataMultipleRow_xls($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{MONTH0_LOW_PING_7DOWN}{HTML},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			}else{
				tableDataMultipleRow_xls("0",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			}
			#Down Low Impact
			# now
			if($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{MONTH0_LOW_PING_DOWN}{VALUE}>0){
				tableDataMultipleRow_xls($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{MONTH0_LOW_PING_DOWN}{HTML},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			}else{
				tableDataMultipleRow_xls("0",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			}

			#Down with scheduled outage
			if($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{MONTH0_DOWN_WITH_OUTAGE}{VALUE}>0){
				tableDataMultipleRow_xls($l2_ebi_availability{CUSTOMER}{$customer}{CENTER}{$center}{CAPABILITY}{$filter_capability}{TEAM}{$filter_team}{STATUS}{$filter_status}{EOL_STATUS}{$filter_eol}{OWNER}{$filter_owner}{MONTH0_DOWN_WITH_OUTAGE}{HTML},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			}else{
				tableDataMultipleRow_xls("0",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			}
		}





		$count++;
		print '</TR>';
	}
}

print '</TBODY>';

   ##Table footer
   my %footer = (
   									'label_span' => 4,
   									'columns' => 'sum::cluster nodes[4],sum::servers[5],sum::exclude[6],sum::eligible[7],sum::enrolled[8],perc(enrolled[8]/eligible[7])::enrolled %[9],
									sum::not enrolled[10],sum::#servers with unscheduled outages[11],sum::#servers missing sla tgt[12],
									perc(#servers with unscheduled outages[11]/eligible[7])::%servers missing sla tgt[13],
									sum::#up[14],sum::> 7 days[15],sum::< 7 days[16],sum::> 7 days[17],sum::< 7 days[18],sum::#down with scheduled outage[19]
   									'
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
