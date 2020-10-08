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


my $filter_region = param('region') || "All";
my $filter_customer = param('customer') || "ALL";
my $filter_team = param('team') || "ALL";
my $filter_capability = param('capability') || "ALL";
my $filter_center = param('center') || "ALL";
my $filter_eol = param('eol') || "ALL";
my $filter_owner = param('owner') || "ALL";
my $filter_xls = param('xls');
my $filter_aggregation = param('aggregation') || "L2";

print "Content-type: text/html\n\n";

#--CGI CHECK
my $bad_parameters = validate_cgi_parameters(["region", "center", "customer", "team", "capability","status","eol","owner","xls"]);
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


my %l2_cva;
my $d  =load_cache_byFile("$cache_dir/l2_cache/cache.l2_cva_availability");
%l2_cva = %{$d};

my %account_reg = get_filtered_accounts();

my $count =1;

###Main
print '<body>';
#FORM
print '<form>';

print '</form>';

	my @l2_graph;

	push @l2_graph, { 'div-id' => 'oc-l2-bar-graph1',
                                                'graph-type' => 'bar',
                                                'label' => 'CVA - Availability',
                                                'height' => 200,
                                                'width' => 600,
                                                'type' => 'sum',
                                                'columns' => "3::Servers,5::Outages,6::Downtime(Hrs)"};
  
  push @l2_graph, { 'div-id' => 'oc-l2-pie-graph2',
                                                'graph-type' => 'gauge',
                                                'label' => 'CVA - Availability',
                                                'height' => 185,
                                                'width' => 300,
                                                'type' => 'avg',
                                                'columns' => "7::Availability"};

		create_graph_elements(\@l2_graph);



print '<TABLE id="toolspen" class="tablesorter l2-table perl-xls">'."\n";
print '<THEAD>';
print '<TR>'."\n";
tableHeaderColumn_xls("CVA - Availability - $var_keys{p_name}-$var_keys{c_year} ",{COL_SPAN=>8, ROW_SPAN=>1}, \%xls_attr);
print '</TR>'."\n";

print '<TR>'."\n";
$xls_attr{XLS_X}=0;
$xls_attr{XLS_Y}++; 

tableHeaderColumn_xls("Account List",{COL_SPAN=>3, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("Baseline",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("30 Days",{COL_SPAN=>4, ROW_SPAN=>1}, \%xls_attr);
print '</TR>'."\n";


print '<TR>'."\n";
$xls_attr{XLS_X}=0;
$xls_attr{XLS_Y}++; 
tableHeaderColumn_xls("Customer Name",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("Delivery Map",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("Source",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("Servers",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("#Scheduled Outages",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("#Un-Scheduled Outages",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("Downtime(Hrs)",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
tableHeaderColumn_xls("Availability(%)",{CLASS_NAME=>"table-hide", COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
print '</TR>'."\n";
print '</THEAD>';
print '<TBODY>';
$count=1;

foreach my $customer (sort keys %account_reg) {
	my $c = uc($customer);
	next if (!defined($l2_cva{CUSTOMER}{$customer}));
	next if (check_region_filter($customer, $filter_region, \%account_reg));
	next if ($filter_customer !~ /^ALL$/i and $filter_customer !~ /^\Q$customer\E$/i);
	foreach my $center (keys %{$l2_cva{CUSTOMER}{$customer}{CENTER}}) {
		next if ($filter_center !~ /all/i and $filter_center !~ /$center/i);
		next if ($filter_center =~ /all/i and $center ne "ALL");
		
		if ($filter_aggregation eq "L2.5") {		
			my @pdxc_ins = keys %{$l2_cva{CUSTOMER}{$customer}{PDXC_INSTANCE_LIST}};
			foreach my $ins (@pdxc_ins) {
    			my $i_value = $ins . '_VALUE';
    			my $i_html = $ins . '_HTML';
    			print '<TR>';
					$xls_attr{XLS_X}=0;
					$xls_attr{XLS_Y}++; 
			    tableDataMultipleRow_xls("$c($ins)",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			    tableDataMultipleRow_xls("<a target=\"_blank\" href=\"$drilldown_dir/custDetails.pl?cust=$customer\">contacts</a>",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			    tableDataMultipleRow_xls("CVA-AWS",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
					tableDataMultipleRow_xls($l2_cva{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{TOTAL_SERVERS}{$i_html},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			    tableDataMultipleRow_xls("0",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
			    my $color;
					if ($l2_cva{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{SERVER_OUTAGES}{$i_value} > 0) {
						$color="$red";
					} else {
						$color="$green";
					}
			    tableDataMultipleRow_xls($l2_cva{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{SERVER_OUTAGES}{$i_html},{COL_SPAN=>1, ROW_SPAN=>1, COLOR=> $color}, \%xls_attr);
			    
			    if ($l2_cva{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{OUTAGE_DURATION_HOURS}{$i_value} > 0) {
						$color="$red";
					} else {
						$color="$green";
					}
			    
			    tableDataMultipleRow_xls($l2_cva{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{OUTAGE_DURATION_HOURS}{$i_html},{COL_SPAN=>1, ROW_SPAN=>1, COLOR=> $color}, \%xls_attr);
			    
			    my $avail = sprintf "%d", ( ($l2_cva{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{TOTAL_HOURS}{$i_value} - 
			                                 $l2_cva{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{OUTAGE_DURATION_HOURS}{$i_value}) /
			                                 ($l2_cva{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{TOTAL_HOURS}{$i_value}) * 100);
					
					my $color;
					if ($avail > 95) {
						$color="$green";
					} else {
						$color="$red";
					}

					my $instance_url = $l2_cva{CUSTOMER}{$customer}{PDXC_INSTANCE_LIST}{$ins};
					my $cva_url = $instance_url . "/?url=$drilldown_dir/l3_cva_availability.pl?customer=$customer&type=avail_perc";
				  tableDataMultipleRow_xls("<a target='_self' href=\"$cva_url\">$avail\%</a>",{COL_SPAN=>1, ROW_SPAN=>1, COLOR=>$color}, \%xls_attr);
					$count++;
					print '</TR>';
    			
    	}
		} else {
			  print '<TR>';
				$xls_attr{XLS_X}=0;
				$xls_attr{XLS_Y}++; 
		    tableDataMultipleRow_xls($account_reg{$customer}{dm_account_name_original},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		    tableDataMultipleRow_xls("<a target=\"_blank\" href=\"$drilldown_dir/custDetails.pl?cust=$customer\">contacts</a>",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		    tableDataMultipleRow_xls("CVA-AWS",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
				tableDataMultipleRow_xls($l2_cva{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{TOTAL_SERVERS}{HTML},{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		    tableDataMultipleRow_xls("0",{COL_SPAN=>1, ROW_SPAN=>1}, \%xls_attr);
		    my $color;
				if ($l2_cva{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{SERVER_OUTAGES}{VALUE} > 0) {
					$color="$red";
				} else {
					$color="$green";
				}
		    tableDataMultipleRow_xls($l2_cva{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{SERVER_OUTAGES}{HTML},{COL_SPAN=>1, ROW_SPAN=>1, COLOR=> $color}, \%xls_attr);
		    
		    if ($l2_cva{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{OUTAGE_DURATION_HOURS}{VALUE} > 0) {
					$color="$red";
				} else {
					$color="$green";
				}
		    
		    tableDataMultipleRow_xls($l2_cva{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{OUTAGE_DURATION_HOURS}{HTML},{COL_SPAN=>1, ROW_SPAN=>1, COLOR=> $color}, \%xls_attr);
		    
		    my $avail = sprintf "%d", ( ($l2_cva{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{TOTAL_HOURS}{VALUE} - 
		                                 $l2_cva{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{OUTAGE_DURATION_HOURS}{VALUE}) /
		                                 ($l2_cva{CUSTOMER}{$customer}{CENTER}{ALL}{CAPABILITY}{ALL}{TEAM}{ALL}{EOL_STATUS}{ALL}{OWNER}{ALL}{TOTAL_HOURS}{VALUE}) * 100);
				
				my $color;
				if ($avail > 95) {
					$color="$green";
				} else {
					$color="$red";
				}
			  tableDataMultipleRow_xls("<a href=\"$drilldown_dir/l3_cva_availability.pl?customer=$customer&type=avail_perc\">$avail\%</a>",{COL_SPAN=>1, ROW_SPAN=>1, COLOR=>$color}, \%xls_attr);
				$count++;
				print '</TR>';
		}
	}
}

print '</TBODY>';

   ##Table footer
   my %footer = (
   									'label_span' => 3,
   									'columns' => 'sum::servers[3],sum::#outages[4],sum::#servers with outages[5],sum::downtime[6],avg::availability[7]'
   							);
   							
   create_footer(\%footer);

print '</TABLE>';

my $end_time = time;
my $load_time = $end_time - $start_time;
print "<div id=\"server-load-time\" data-load-time=\"$load_time\" style=\"display:none\"></div>\n";

print '<div class="page-info">Page generated at <span id=localdt></span>' . "</div>";
print '<script> d = new Date(); document.getElementById("localdt").innerHTML = d;</script>';
print '	</body> </html>';

if ($filter_xls eq 1) { 
		finish_formats($workbook, \%xls_attr);
}

if ($filter_api eq 1) { 	
	api_json(\%xls_attr);		
}
