#!/usr/bin/perl
use strict;
use Data::Dumper;
use Getopt::Std;
use lib '/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/modules';
use lib '/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/modules/pm';
use JSON qw( decode_json );
use LoadCache;
use CommonFunctions;
use AWSFunctions;
use POSIX 'strftime';
use POSIX qw( mktime );
use File::Basename;
use Hash::Merge qw( merge );
use Net::Domain qw (hostname hostfqdn hostdomain); 
use vars qw($cache_dir $rawdata_dir $base_dir $cfg_dir);
my %opts;

my @filename = split(/\./,basename($0));
my $script = @filename[0];

my $current_tick = time();
my $month = POSIX::strftime("%b%Y", localtime time);

my $start_time = time();

my $run_log = "$base_dir/log/$script.log_$month";
my %aws_queries;

my $domain = hostdomain();
$ENV{HTTPS_PROXY} = 'http://proxy.houston.hpecorp.net:8080' if ($domain =~ /itcs.houston.dxccorp.net/i);
#print "$domain \n";
#print Dumper \%ENV;

my @months = qw(JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC);
my %month_dates;

my $cfg = read_config();

getopts('e:a:r:u:d:p:t:m:', \%opts) || usage("invalid arguments");

###############################################################
#
# Global Variable Definitions
#
###############################################################

my %s3_files;

my %cust_list_hash;
my %cached_company;

my @list = ('account_reg');

my %cache = load_cache(\@list);
my %account_reg = %{$cache{account_reg}};


###############################################################
#
# Extract DB and system name from parameters
#
###############################################################

my @aws_environments;
my %aws_accounts;
my %aws_regions;
my %aws_roles;
my %aws_dbs;

my $env_count = 0;

if (defined($opts{"e"})){
	my $environments = uc($opts{"e"});
	my (@env_list) = split(/\,/,$environments);
	foreach my $n (@env_list){
		$n=~s/^\s*//;
		$n=~s/\s*$//;
		push(@aws_environments, $n);
		$env_count++;
	}
} else {
		push(@aws_environments, 'GBL');
		$env_count++;
}


# Get AWS Accounts from parameter or config file
if (defined($opts{"a"})){
	my $accounts = $opts{"a"};
	my (@account_list) = split(/\,/,$accounts);
	my $count = 0;
	foreach my $n (@account_list){
		$n=~s/^\s*//;
		$n=~s/\s*$//;
		$aws_accounts{@aws_environments[$count]} = $n;
		$count++;
	}
} else {
	if (defined($opts{"e"})){
		foreach my $env (@aws_environments) {
			$aws_accounts{$env} = $cfg->{AWS_ACCOUNT} if ($env =~ /^PRD/i);
			$aws_accounts{$env} = $cfg->{AWS_ACCOUNT_GBL} if ($env =~ /GBL/i);
			$aws_accounts{$env} = $cfg->{AWS_ACCOUNT_US} if ($env =~ /US/i);
			$aws_accounts{$env} = $cfg->{AWS_ACCOUNT_AU} if ($env =~ /AU/i);
			$aws_accounts{$env} = $cfg->{AWS_ACCOUNT_SB} if ($env =~ /SB/i);
			$aws_accounts{$env} = $cfg->{AWS_ACCOUNT_SB2} if ($env =~ /SB2/i);
			$aws_accounts{$env} = $cfg->{AWS_ACCOUNT_TRF} if ($env =~ /TRANSFORMED/i);
		}
	} else {
		$aws_accounts{GBL} = $cfg->{AWS_ACCOUNT};
	}
}
my $account_count = scalar keys %aws_accounts;

# Get AWS Regions from parameter or config file
if (defined($opts{"r"})){
	my $regions = $opts{"r"};
	my (@region_list) = split(/\,/,$regions);
	my $count = 0;
	foreach my $n (@region_list){
		$n=~s/^\s*//;
		$n=~s/\s*$//;
		@aws_regions{@aws_environments[$count]} = $n;
		$count++;
	}
} else {
	if (defined($opts{"e"})){
		foreach my $env (@aws_environments) {
			$aws_regions{$env} = $cfg->{AWS_REGION} if ($env =~ /^PRD/i);
			$aws_regions{$env} = $cfg->{AWS_REGION_GBL} if ($env =~ /GBL/i);
			$aws_regions{$env} = $cfg->{AWS_REGION_US} if ($env =~ /US/i);
			$aws_regions{$env} = $cfg->{AWS_REGION_AU} if ($env =~ /AU/i);
			$aws_regions{$env} = $cfg->{AWS_REGION_SB} if ($env =~ /SB/i);
			$aws_regions{$env} = $cfg->{AWS_REGION_SB2} if ($env =~ /SB2/i);
			$aws_regions{$env} = $cfg->{AWS_REGION_TRF} if ($env =~ /TRANSFORMED/i);
		}
	} else {
		$aws_regions{GBL} = $cfg->{AWS_REGION};
	}
}
my $region_count = scalar keys %aws_regions;

# Get User Roles from parameter or config file
if (defined($opts{"u"})){
	my $users_roles = $opts{"u"};
	my (@role_list) = split(/\,/,$users_roles);
	my $count = 0;
	foreach my $n (@role_list){
		$n=~s/^\s*//;
		$n=~s/\s*$//;
		@aws_roles{@aws_environments[$count]} = $n;
		$count++;
	}
} else {
	if (defined($opts{"e"})){
		foreach my $env (@aws_environments) {
			$aws_roles{$env} = $cfg->{AWS_ROLE} if ($env =~ /^PRD/i);
			$aws_roles{$env} = $cfg->{AWS_ROLE_GBL} if ($env =~ /GBL/i);
			$aws_roles{$env} = $cfg->{AWS_ROLE_US} if ($env =~ /US/i);
			$aws_roles{$env} = $cfg->{AWS_ROLE_AU} if ($env =~ /AU/i);
			$aws_roles{$env} = $cfg->{AWS_ROLE_SB} if ($env =~ /SB/i);
			$aws_roles{$env} = $cfg->{AWS_ROLE_SB2} if ($env =~ /SB2/i);
			$aws_roles{$env} = $cfg->{AWS_ROLE_TRF} if ($env =~ /TRANSFORMED/i);
		}
	} else {
		$aws_roles{GBL} = $cfg->{AWS_ROLE};
	}
}
my $role_count = scalar keys %aws_roles;

# Get Databases from parameter or config file
if (defined($opts{"d"})){
	my $databases = $opts{"d"};
	my (@db_list) = split(/\,/,$databases);
	my $count = 0;
	foreach my $n (@db_list){
		$n=~s/^\s*//;
		$n=~s/\s*$//;
		@aws_dbs{@aws_environments[$count]} = $n;
		$count++;
	}
} else {
	if (defined($opts{"e"})){
		foreach my $env (@aws_environments) {
			if (not defined ($opts{"t"}) or (defined($opts{"t"}) and $opts{"t"} =~ /avcap/)){
				$aws_dbs{$env} = $cfg->{AWS_AVCAP_DB} if ($env =~ /^PRD/i);
				$aws_dbs{$env} = $cfg->{AWS_AVCAP_DB_GBL} if ($env =~ /GBL/i);
				$aws_dbs{$env} = $cfg->{AWS_AVCAP_DB_US} if ($env =~ /US/i);
				$aws_dbs{$env} = $cfg->{AWS_AVCAP_DB_AU} if ($env =~ /AU/i);
				$aws_dbs{$env} = $cfg->{AWS_AVCAP_DB_SB} if ($env =~ /SB/i);
				$aws_dbs{$env} = $cfg->{AWS_AVCAP_DB_SB2} if ($env =~ /SB2/i);
				$aws_dbs{$env} = $cfg->{AWS_AVCAP_DB_TRF} if ($env =~ /TRANSFORMED/i);
			}elsif(defined($opts{"t"}) and $opts{"t"} =~ /cva_enmt/){
				$aws_dbs{$env} = $cfg->{AWS_CVA_ENMT_DB} if ($env =~ /^PRD/i);
				$aws_dbs{$env} = $cfg->{AWS_CVA_ENMT_DB_GBL} if ($env =~ /GBL/i);
				$aws_dbs{$env} = $cfg->{AWS_CVA_ENMT_DB_US} if ($env =~ /US/i);
				$aws_dbs{$env} = $cfg->{AWS_CVA_ENMT_DB_AU} if ($env =~ /AU/i);
				$aws_dbs{$env} = $cfg->{AWS_CVA_ENMT_DB_SB} if ($env =~ /SB/i);
				$aws_dbs{$env} = $cfg->{AWS_CVA_ENMT_DB_SB2} if ($env =~ /SB2/i);
			}elsif(defined($opts{"t"}) and $opts{"t"} =~ /bigfix_comp/){
				$aws_dbs{$env} = $cfg->{AWS_BIGFIX_DB} if ($env =~ /^PRD/i);
				$aws_dbs{$env} = $cfg->{AWS_BIGFIX_DB_GBL} if ($env =~ /GBL/i);
				$aws_dbs{$env} = $cfg->{AWS_BIGFIX_DB_US} if ($env =~ /US/i);
				$aws_dbs{$env} = $cfg->{AWS_BIGFIX_DB_AU} if ($env =~ /AU/i);
				$aws_dbs{$env} = $cfg->{AWS_BIGFIX_DB_SB} if ($env =~ /SB/i);
				$aws_dbs{$env} = $cfg->{AWS_BIGFIX_DB_SB2} if ($env =~ /SB2/i);
				$aws_dbs{$env} = $cfg->{AWS_BIGFIX_DB_STG} if ($env =~ /STG/i);
			}
		}
	} else {
		if (not defined ($opts{"t"}) or (defined($opts{"t"}) and $opts{"t"} =~ /avcap/)){
			$aws_dbs{GBL} = $cfg->{AWS_AVCAP_DB};
		}elsif(defined($opts{"t"}) and $opts{"t"} =~ /cva_enmt/){
			$aws_dbs{GBL} = $cfg->{AWS_CVA_ENMT_DB};
		}elsif(defined($opts{"t"}) and $opts{"t"} =~ /bigfix_comp/){
			$aws_dbs{GBL} = $cfg->{AWS_BIGFIX_DB};
		}
	}
}
my $db_count = scalar keys %aws_dbs;

my $invalid_parameters = 0;
if ($account_count != $env_count) {
	print "Incorrect number of AWS accounts provide.  Expecting $env_count, received $account_count values\n"; 
	print "$account_count AWS Accounts Provided: ".$opts{"a"}."\n\n" if (defined($opts{"a"}));
	$invalid_parameters++;
}

if ($region_count != $env_count) {
	print "Incorrect number of AWS regions provide.  Expecting $env_count, received $region_count values\n"; 
	print "$region_count AWS Regions Provided: ".$opts{"r"}."\n\n" if (defined($opts{"r"}));
	$invalid_parameters++;
}

if ($role_count != $env_count) {
	print "Incorrect number of AWS User Roles provide.  Expecting $env_count, received $role_count values\n"; 
	print "$role_count AWS User Roles Provided: ".$opts{"u"}."\n\n" if (defined($opts{"u"}));
	$invalid_parameters++;
}

if ($db_count != $env_count) {
	print "Incorrect number of AWS Databases provide.  Expecting $env_count, received $db_count values\n"; 
	print "$db_count AWS Databases Provided: ".$opts{"d"}."\n\n" if (defined($opts{"d"}));
	$invalid_parameters++;
}

exit if ($invalid_parameters > 0);


###############################################################
#
# Get CPU and Memory Capacity data SQL Query
#
###############################################################
my $ci_metric_cmd = qq( /usr/local/bin/aws athena start-query-execution --query-string "SELECT ci_alias_nm,
         ci_id,
         data_domain_nm,
         client_id,
         client_alias_nm,
         date_trunc('day',interval_utc_ts),
         ci_alias_type,
         metricset_nm,         
         natv_mtrc_cd,
         avg(natv_mtrc_valu),
         metric_sample_ct,
         metricset_module,
         src_clnt_cd,
         src_sys_nm         
FROM 'AVCAP_DB_GOES_HERE'.ci_metric
WHERE ingest_dt >= 'INGEST_START_DATE_GOES_HERE' AND ingest_dt < 'INGEST_END_DATE_GOES_HERE'
AND interval_utc_ts >= date_parse('START_DATE_GOES_HERE', '%Y-%m-%d %H:%i:%s') AND interval_utc_ts < date_parse('END_DATE_GOES_HERE', '%Y-%m-%d %H:%i:%s')
GROUP BY ci_alias_nm,
         ci_id,
         data_domain_nm,
         client_id,
         client_alias_nm,
         date_trunc('day',interval_utc_ts),
         ci_alias_type,
         metricset_nm,         
         natv_mtrc_cd,         
         metric_sample_ct,
         metricset_module,
         src_clnt_cd,
         src_sys_nm" --result-configuration "OutputLocation=s3://aws-athena-query-results-'ACCOUNT_GOES_HERE'-'REGION_GOES_HERE'/OCD2/" --region 'REGION_GOES_HERE' --profile 'ROLE_GOES_HERE');

###############################################################
#
# Get File System and Network Capacity data SQL Query
#
###############################################################
my $ci_resource_metric_cmd = qq( /usr/local/bin/aws athena start-query-execution --query-string "SELECT ci_alias_nm,
         ci_id,
         data_domain_nm,
         client_id,
         client_alias_nm,
         date_trunc('day',interval_utc_ts),
         ci_alias_type,
         metricset_nm,
         resource_type,
         resource_nm,         
         natv_mtrc_cd,
         avg(natv_mtrc_valu),
         metric_sample_ct,
         metricset_module,
         src_clnt_cd,
         src_sys_nm         
FROM 'AVCAP_DB_GOES_HERE'.ci_resource_metric
WHERE ingest_dt >= 'INGEST_START_DATE_GOES_HERE' AND ingest_dt < 'INGEST_END_DATE_GOES_HERE'
AND interval_utc_ts >= date_parse('START_DATE_GOES_HERE', '%Y-%m-%d %H:%i:%s') AND interval_utc_ts < date_parse('END_DATE_GOES_HERE', '%Y-%m-%d %H:%i:%s')
GROUP BY ci_alias_nm,
         ci_id,
         data_domain_nm,
         client_id,
         client_alias_nm,
         date_trunc('day',interval_utc_ts),
         ci_alias_type,
         metricset_nm,
         resource_type,
         resource_nm,         
         natv_mtrc_cd,         
         metric_sample_ct,
         metricset_module,
         src_clnt_cd,
         src_sys_nm " --result-configuration "OutputLocation=s3://aws-athena-query-results-'ACCOUNT_GOES_HERE'-'REGION_GOES_HERE'/OCD2/" --region 'REGION_GOES_HERE' --profile 'ROLE_GOES_HERE');

###############################################################
#
# Get Availability data SQL Query
#
###############################################################
#my $ci_status_metric_cmd = qq( /usr/local/bin/aws athena start-query-execution --query-string "SELECT ci_alias_nm,
#         ci_id,
#         data_domain_nm,
#         client_id,
#         client_alias_nm,
#         interval_utc_ts,
#         ci_alias_type,
#         metricset_nm,
#         request_time,
#         natv_mtrc_cd,
#         natv_mtrc_valu,
#         metric_sample_ct,
#         metricset_module,
#         src_clnt_cd,
#         src_sys_nm
#FROM 'AVCAP_DB_GOES_HERE'.ci_status_metric
#WHERE ingest_dt >= 'INGEST_START_DATE_GOES_HERE' AND ingest_dt < 'INGEST_END_DATE_GOES_HERE'
#AND interval_utc_ts >= date_parse('START_DATE_GOES_HERE', '%Y-%m-%d %H:%i:%s') AND interval_utc_ts < date_parse('END_DATE_GOES_HERE', '%Y-%m-%d %H:%i:%s')" --result-configuration "OutputLocation=s3://aws-athena-query-results-'ACCOUNT_GOES_HERE'-'REGION_GOES_HERE'/OCD2/" --region 'REGION_GOES_HERE' --profile 'ROLE_GOES_HERE');

my $ci_status_metric_cmd = qq( /usr/local/bin/aws athena start-query-execution --query-string "SELECT ci_alias_nm,
         ci_id,
         data_domain_nm,
         client_id,
         client_alias_nm,
         interval_utc_ts,
         ci_alias_type,
         metricset_nm,
         request_time,
         natv_mtrc_cd,
         natv_mtrc_valu,
         metric_sample_ct,
         metricset_module,
         src_clnt_cd,
         src_sys_nm         
FROM 'AVCAP_DB_GOES_HERE'.ci_status_metric
WHERE ingest_dt >= 'INGEST_START_DATE_GOES_HERE' AND ingest_dt < 'INGEST_END_DATE_GOES_HERE'
AND interval_utc_ts >= date_parse('START_DATE_GOES_HERE', '%Y-%m-%d %H:%i:%s') AND interval_utc_ts < date_parse('END_DATE_GOES_HERE', '%Y-%m-%d %H:%i:%s')
AND ci_alias_nm in (select ci_alias_nm from (SELECT 
											ci_alias_nm,         
										  MAX(natv_mtrc_valu) AS maxvalu, 
										  MIN(natv_mtrc_valu) AS minvalu   
									FROM 'AVCAP_DB_GOES_HERE'.ci_status_metric
									WHERE ingest_dt >= 'INGEST_START_DATE_GOES_HERE' AND ingest_dt < 'INGEST_END_DATE_GOES_HERE'
									AND interval_utc_ts >= date_parse('START_DATE_GOES_HERE', '%Y-%m-%d %H:%i:%s') AND interval_utc_ts < date_parse('END_DATE_GOES_HERE', '%Y-%m-%d %H:%i:%s')
									group by ci_alias_nm
									)               
WHERE ( maxvalu - minvalu) > ((cast(to_unixtime(CAST('START_DATE_GOES_HERE' AS timestamp))AS BIGINT)-cast(to_unixtime(CAST('END_DATE_GOES_HERE' AS timestamp))AS BIGINT))*1000)
)" --result-configuration "OutputLocation=s3://aws-athena-query-results-'ACCOUNT_GOES_HERE'-'REGION_GOES_HERE'/OCD2/" --region 'REGION_GOES_HERE' --profile 'ROLE_GOES_HERE');


###############################################################
#
# Get CVA_ENMT_PLAN data SQL Query
#
###############################################################
my $cva_enmt_plan_cmd = qq( /usr/local/bin/aws athena start-query-execution --query-string "SELECT account,
		hostname,
		REPLACE(ip_address, ',', '~') as ip_address,
		os_type,
		cva_id,
		inscope,
		comments,
		startdate,
		enddate 
	FROM 'DB_GOES_HERE'.ci_enroll_plan" --result-configuration "OutputLocation=s3://aws-athena-query-results-'ACCOUNT_GOES_HERE'-'REGION_GOES_HERE'/OCD2/" --region 'REGION_GOES_HERE' --profile 'ROLE_GOES_HERE');

###############################################################
#
# Get CVA_ENMT_STATUS data SQL Query
#
###############################################################
my $cva_enmt_status_cmd = qq( /usr/local/bin/aws athena start-query-execution --query-string "SELECT account,
		cva_id,
		hostname,
		REPLACE(ip_address, ',', '~') as ip_address,
		phase,
		status,
		module,
		action,
		date 
	FROM 'DB_GOES_HERE'.ci_enroll_status" --result-configuration "OutputLocation=s3://aws-athena-query-results-'ACCOUNT_GOES_HERE'-'REGION_GOES_HERE'/OCD2/" --region 'REGION_GOES_HERE' --profile 'ROLE_GOES_HERE');


###############################################################
#
# Get BIGFIX_COMP data SQL Query
#
###############################################################

my $bigfix_comp_cmd = qq( /usr/local/bin/aws athena start-query-execution --query-string "SELECT distinct(r.cmptr_nm), r.agnt_ver_nm, r.bes_relay_seltn_mthd_cd, r.bes_root_srvr_nm, r.clnt_cd, r.cmptr_id, r.cmptr_last_rpt_ts, r.dvc_type_nm, r.ip_addr_nm, r.os_nm, r.refresh_dt, c.ci_nm, c.fqdn_nm, c.co_nm, d.acct_nm FROM 'DB_GOES_HERE'."bigfix_cmptr_r" r,'DB_GOES_HERE'."ci_d" c,'DB_GOES_HERE'."dmar_clnt_d" d where r.cmptr_nm = c.fqdn_nm	and c.co_nm = d.acct_nm;" --result-configuration "OutputLocation=s3://aws-athena-query-results-'ACCOUNT_GOES_HERE'-'REGION_GOES_HERE'/OCD2/" --region 'REGION_GOES_HERE' --profile 'ROLE_GOES_HERE');

###################################
#
# SUBROUTINES
#
####################################


sub build_aws_queries {
	###############################################################
	#  Build CVA Metric queries for each environment
	###############################################################
	foreach my $env (@aws_environments){
		if (not defined ($opts{"t"}) or (defined($opts{"t"}) and $opts{"t"} =~ /avcap/)){

			##Update the date in the query for.  Only get 1 months data or from first of last month for 30Days
			##Default from 1st of last months
			##Otherwise get for specifgied month
			
			my $extract_month = uc($opts{"m"}) || '30DAYS';
			my $query_start_date = $month_dates{"$extract_month"}{QUERY_START_DATE};
			my $query_end_date = $month_dates{"$extract_month"}{QUERY_END_DATE};
			my $ingest_query_start_date = $month_dates{"$extract_month"}{INGEST_START_DATE};
			my $ingest_query_end_date = $month_dates{"$extract_month"}{INGEST_END_DATE};
			
			print "Querying Availability and Capacity data for $extract_month\n";
			print "Query Date: $query_start_date - $query_end_date\n";
			print "Ingest Query Date: $ingest_query_start_date - $ingest_query_end_date\n";

			# Memory and CPU Capacity
			my $query = $ci_metric_cmd;
			$query =~ s/\'START_DATE_GOES_HERE\'/'$query_start_date'/;
			$query =~ s/\'END_DATE_GOES_HERE\'/'$query_end_date'/;
			$query =~ s/\'INGEST_START_DATE_GOES_HERE\'/'$ingest_query_start_date'/;
			$query =~ s/\'INGEST_END_DATE_GOES_HERE\'/'$ingest_query_end_date'/;
			$query =~ s/\'AVCAP_DB_GOES_HERE\'/$aws_dbs{$env}/g;
			$query =~ s/\'ROLE_GOES_HERE\'/$aws_roles{$env}/g;
			$query =~ s/\'ACCOUNT_GOES_HERE\'/$aws_accounts{$env}/g;
			$query =~ s/\'REGION_GOES_HERE\'/$aws_regions{$env}/g;
			my $key =  $env . "_AWS_METRICS";
			$aws_queries{$key}{QUERY} = $query;	
			$aws_queries{$key}{REGION} = $aws_regions{$env};	
			$aws_queries{$key}{ROLE} = $aws_roles{$env};	
			$aws_queries{$key}{ACCOUNT} = $aws_accounts{$env};

			# Filesystem Capacity
			my $query = $ci_resource_metric_cmd;  
			$query =~ s/\'START_DATE_GOES_HERE\'/'$query_start_date'/;
			$query =~ s/\'END_DATE_GOES_HERE\'/'$query_end_date'/;
			$query =~ s/\'INGEST_START_DATE_GOES_HERE\'/'$ingest_query_start_date'/;
			$query =~ s/\'INGEST_END_DATE_GOES_HERE\'/'$ingest_query_end_date'/;
			$query =~ s/\'AVCAP_DB_GOES_HERE\'/$aws_dbs{$env}/g;
			$query =~ s/\'ROLE_GOES_HERE\'/$aws_roles{$env}/g;
			$query =~ s/\'ACCOUNT_GOES_HERE\'/$aws_accounts{$env}/g;
			$query =~ s/\'REGION_GOES_HERE\'/$aws_regions{$env}/g;
			my $key = $env . "_AWS_RES_METRICS";
			$aws_queries{$key}{QUERY} = $query;	
			$aws_queries{$key}{REGION} = $aws_regions{$env};	
			$aws_queries{$key}{ROLE} = $aws_roles{$env};	
			$aws_queries{$key}{ACCOUNT} = $aws_accounts{$env};

			# Availability
			my $query = $ci_status_metric_cmd;
			$query =~ s/\'START_DATE_GOES_HERE\'/'$query_start_date'/g;
			$query =~ s/\'END_DATE_GOES_HERE\'/'$query_end_date'/g;
			$query =~ s/\'INGEST_START_DATE_GOES_HERE\'/'$ingest_query_start_date'/g;
			$query =~ s/\'INGEST_END_DATE_GOES_HERE\'/'$ingest_query_end_date'/g;
			$query =~ s/\'AVCAP_DB_GOES_HERE\'/$aws_dbs{$env}/g;
			$query =~ s/\'ROLE_GOES_HERE\'/$aws_roles{$env}/g;
			$query =~ s/\'ACCOUNT_GOES_HERE\'/$aws_accounts{$env}/g;
			$query =~ s/\'REGION_GOES_HERE\'/$aws_regions{$env}/g;
			my $key = $env . "_AWS_STAT_METRICS";
			$aws_queries{$key}{QUERY} = $query;	
			$aws_queries{$key}{REGION} = $aws_regions{$env};	
			$aws_queries{$key}{ROLE} = $aws_roles{$env};	
			$aws_queries{$key}{ACCOUNT} = $aws_accounts{$env};

		}elsif(defined($opts{"t"}) and $opts{"t"} =~ /cva_enmt/){
			my $query = $cva_enmt_plan_cmd;
			$query =~ s/\'DB_GOES_HERE\'/$aws_dbs{$env}/g;
			$query =~ s/\'ROLE_GOES_HERE\'/$aws_roles{$env}/g;
			$query =~ s/\'ACCOUNT_GOES_HERE\'/$aws_accounts{$env}/g;
			$query =~ s/\'REGION_GOES_HERE\'/$aws_regions{$env}/g;
			#my $key = $env."_AWS_CVA_ENMT_".$exec_mode;
			my $key = $env."_AWS_CVA_ENMT_PLAN";
			$aws_queries{$key}{QUERY} = $query;	
			$aws_queries{$key}{REGION} = $aws_regions{$env};	
			$aws_queries{$key}{ROLE} = $aws_roles{$env};	
			$aws_queries{$key}{ACCOUNT} = $aws_accounts{$env};
			
			my $query = $cva_enmt_status_cmd;
			$query =~ s/\'DB_GOES_HERE\'/$aws_dbs{$env}/g;
			$query =~ s/\'ROLE_GOES_HERE\'/$aws_roles{$env}/g;
			$query =~ s/\'ACCOUNT_GOES_HERE\'/$aws_accounts{$env}/g;
			$query =~ s/\'REGION_GOES_HERE\'/$aws_regions{$env}/g;
			#my $key = $env."_AWS_CVA_ENMT_".$exec_mode;
			my $key = $env."_AWS_CVA_ENMT_STATUS";
			$aws_queries{$key}{QUERY} = $query;	
			$aws_queries{$key}{REGION} = $aws_regions{$env};	
			$aws_queries{$key}{ROLE} = $aws_roles{$env};	
			$aws_queries{$key}{ACCOUNT} = $aws_accounts{$env};
		}elsif(defined($opts{"t"}) and $opts{"t"} =~ /bigfix_comp/){
			my $query = $bigfix_comp_cmd;
			$query =~ s/\'DB_GOES_HERE\'/$aws_dbs{$env}/g;
			$query =~ s/\'ROLE_GOES_HERE\'/$aws_roles{$env}/g;
			$query =~ s/\'ACCOUNT_GOES_HERE\'/$aws_accounts{$env}/g;
			$query =~ s/\'REGION_GOES_HERE\'/$aws_regions{$env}/g;
			my $key = $env."_AWS_BIGFIX_COMP_CI_LIST";
			$aws_queries{$key}{QUERY} = $query;	
			$aws_queries{$key}{REGION} = $aws_regions{$env};	
			$aws_queries{$key}{ROLE} = $aws_roles{$env};	
			$aws_queries{$key}{ACCOUNT} = $aws_accounts{$env};
		}
	}
}


sub process_avcap{
	###########################################
	#
	# Process Availability and Capacity data
	#
	###########################################
	
	my %avcap_files;
	
	$avcap_files{CI_METRICS}{OUT_FILE} = "$rawdata_dir/aws.ci_metric";
	$avcap_files{CI_RES_METRICS}{OUT_FILE} = "$rawdata_dir/aws.ci_res_metric";
	$avcap_files{CI_STAT_METRICS}{OUT_FILE} = "$rawdata_dir/aws.ci_stat_metric";
	
	my $extract_month = uc($opts{"m"}) || "30DAYS";
	if ($extract_month !~ /30DAYS/i) {
		$avcap_files{CI_METRICS}{OUT_FILE} = $avcap_files{CI_METRICS}{OUT_FILE}."_".$extract_month;
		$avcap_files{CI_RES_METRICS}{OUT_FILE} = $avcap_files{CI_RES_METRICS}{OUT_FILE}."_".$extract_month;
		$avcap_files{CI_STAT_METRICS}{OUT_FILE} = $avcap_files{CI_STAT_METRICS}{OUT_FILE}."_".$extract_month;
	}
	
	foreach my $env (@aws_environments){
		$avcap_files{CI_METRICS}{IN_FILE}{$env} = "$rawdata_dir/aws/" . $env . "_AWS_METRICS.csv";
		$avcap_files{CI_RES_METRICS}{IN_FILE}{$env} = "$rawdata_dir/aws/" . $env . "_AWS_RES_METRICS.csv";
		$avcap_files{CI_STAT_METRICS}{IN_FILE}{$env} = "$rawdata_dir/aws/" . $env . "_AWS_STAT_METRICS.csv";
	}

	foreach my $avcap_type (keys %avcap_files) {
		my $prev_month;
		
		if ($extract_month !~ /30DAYS/i) {
			open (AWS_OUTFILE, ">$avcap_files{$avcap_type}{OUT_FILE}");
			print "Writing data to $avcap_files{$avcap_type}{OUT_FILE}\n";
		} else {
			# If processing 30DAYS, write previous month and 30DAYS file
			# get previous month name
			my @curr_time = localtime ();
			$curr_time[4] -= 1; #previous month
			my $prev_month_tick = mktime @curr_time;
			$prev_month = uc(strftime("%h-%y",localtime($prev_month_tick)));
		
			my $avcap_file_30days = $avcap_files{$avcap_type}{OUT_FILE}."_30DAYS";
			my $avcap_file_prev_month = $avcap_files{$avcap_type}{OUT_FILE}."_".$prev_month;
			open (AWS_OUTFILE_30DAYS, ">$avcap_file_30days");
			open (AWS_OUTFILE, ">$avcap_file_prev_month");
			print "Writing data to $avcap_file_30days\n";
			print "Writing data to $avcap_file_prev_month\n";	
			
		}
		
		
		foreach my $env (@aws_environments){
			print "Processing data from $avcap_files{$avcap_type}{IN_FILE}{$env}\n";

			open (AWS_INFILE, "<$avcap_files{$avcap_type}{IN_FILE}{$env}");
			my @file = <AWS_INFILE>;
			close(AWS_INFILE);

			my $line_cnt=0;
			my $joined = 0;
			my $joined_cnt = 0;
			my $join_str;
			my $headers_cnt;
			my $nofqdncnt=0;
			my $inccount=0;
			my $foundfqdncnt=0;

			foreach my $ln (@file){
				my @cols;

				chomp($ln);
				$line_cnt++;
				# Clense data of any paterns that will break call to parcse_csv
				$ln =~s/^(\x{feff})//; 			# Remove strange UTF-16 characters that excel adds at start of first row.
				$ln =~ s/\r//g; 						# Remove control M character
				$ln =~ s/\^M$//;						# Remove control M character (if has been copied and pasted is no longer special character)
				$ln =~ s/\(\"\"\"\"\,\"\"\"\"\,\"\"\"\"\,\"\"\"\"\)/\(\-\,\-\,\-\,\)/g;  # Found a desc containing the following!  unable to allocate bytes of shared memory ("""","""","""","""")",
				$ln =~s/\,\"\"\"/\,\"\'/g;	# Replace triple double quotes at start of field with ,"'
				$ln =~s/\"\"\"\,/\'\"\,/g;	# Replace triple double quotes at start of field with '",
				$ln =~ s/\,\"\"\,/\,\,/g;   # Replace quotes for empty fields in the middle of the line
				$ln =~ s/\,\"\"$/\,/g;   		# Replace quotes for empty fields in the middle of the line
				$ln =~ s/\"\"/\'/g;    			# Replace double double quotes with single quote
				$ln =~ s/\\\"/\"/g;    			# Replace \" from string with just dopuble quotes

				if ($line_cnt == 1){
					@cols = parse_csv($ln);
					$headers_cnt = scalar(@cols);

					print "AWS Input file $avcap_files{$avcap_type}{IN_FILE}{$env} contains $headers_cnt fields.\n\n";
				} else {

					if ($join_str eq ""){
						$join_str = $ln;
						$joined = 0;
						$joined_cnt = 0;
					} else {
						$join_str=$join_str . " " . $ln;
					}
					@cols = parse_csv($join_str);

					my $fields_cnt = scalar(@cols);

					if ($fields_cnt >= $headers_cnt){
						$ln = $join_str if ($line_cnt > 1);
						$join_str = "";
						#print "Line ($fields_cnt)= $ln\n\n" if ($joined == 1);
						$joined = 0;
						$joined_cnt = 0;
					} else {
						$joined = 1;
						$joined_cnt ++;
						#print "Joining line $joined_cnt ($fields_cnt): $ln\n";
						if ($joined_cnt >= 30){
							# Check that we have not joined a huge number of lines together.
							# 30 has been chosen as I have found some records containing a short description 25 lines long
							# Chances are if we join 30 lines we have had an issue identifying the end of one record
							print "\nExceeded joining 30 lines.  Is this incident really over 30 lines long or do we have an issue?\n";
							print "Check the first issue in the following line:\n\n";
							print "$join_str\n";
							exit;
						}
						next;
					}
					my @values = parse_csv($ln);
					#print "VALUES:@values\n";

					my $src = "CVA-AWS";

					if ($avcap_type eq 'CI_RES_METRICS') {
						##These are the Filesystem capacity comma seperated values we extract from AWS
						my ($fqdn, $ci_id, $data_domain, $client_id, $client_alias, $interval_ts, $ci_alias_type, $metricset, $resource_type, $resource, $natv_mtrc_cd,
						$natv_mtrc_val, $metric_sample_ct, $metricset_module, $src_clnt_cd, $src_sys)=@values;
						
						my $month = get_month($interval_ts);
						next if (not defined($month_dates{$extract_month}{PROCESS_MONTHS}{$month}));

						if ($extract_month =~ /30DAYS/i) {
							my $last_30=0;
							my $sample_tick = date_to_tick($interval_ts);      	
							my $date_dif = sprintf "%0.2f", ($current_tick - $sample_tick) / (24 * 60 * 60);			
      				if ($date_dif < 30){      	
      					$last_30 =1;
      					#print "DateDiff: $date_dif $current_tick - $sample_tick) / (24 * 60 * 60)\n";
      				}
      				
      				if ($last_30 == 1){
      					print AWS_OUTFILE_30DAYS $src."~~~".$month."~~~".$fqdn."~~~".$ci_id."~~~".$data_domain."~~~".$client_id."~~~".$client_alias."~~~".$interval_ts."~~~".$ci_alias_type."~~~".$metricset;
								print AWS_OUTFILE_30DAYS "~~~".$resource_type."~~~".$resource."~~~".$natv_mtrc_cd."~~~".$natv_mtrc_val."~~~".$metric_sample_ct."~~~".$metricset_module."~~~".$src_clnt_cd."~~~".$src_sys;
								print AWS_OUTFILE_DAYS "\n";
      				}
							
							if ($month eq $prev_month) {
								print AWS_OUTFILE $src."~~~".$month."~~~".$fqdn."~~~".$ci_id."~~~".$data_domain."~~~".$client_id."~~~".$client_alias."~~~".$interval_ts."~~~".$ci_alias_type."~~~".$metricset;
								print AWS_OUTFILE "~~~".$resource_type."~~~".$resource."~~~".$natv_mtrc_cd."~~~".$natv_mtrc_val."~~~".$metric_sample_ct."~~~".$metricset_module."~~~".$src_clnt_cd."~~~".$src_sys;
								print AWS_OUTFILE "\n";
							}
							
						} else {
							print AWS_OUTFILE $src."~~~".$month."~~~".$fqdn."~~~".$ci_id."~~~".$data_domain."~~~".$client_id."~~~".$client_alias."~~~".$interval_ts."~~~".$ci_alias_type."~~~".$metricset;
							print AWS_OUTFILE "~~~".$resource_type."~~~".$resource."~~~".$natv_mtrc_cd."~~~".$natv_mtrc_val."~~~".$metric_sample_ct."~~~".$metricset_module."~~~".$src_clnt_cd."~~~".$src_sys;
							print AWS_OUTFILE "\n";
						}
					} elsif($avcap_type eq 'CI_METRICS') {
						##These are the CPU and Memory capacity and system availability comma seperated values we extract from AWS
						my ($fqdn, $ci_id, $data_domain, $client_id, $client_alias, $interval_ts, $ci_alias_type, $metricset, $natv_mtrc_cd, $natv_mtrc_val,
						$metric_sample_ct, $metricset_module, $src_clnt_cd, $src_sys)=@values;
						
						my $month = get_month($interval_ts);
						next if (not defined($month_dates{$extract_month}{PROCESS_MONTHS}{$month}));

						if ($extract_month =~ /30DAYS/i) {
							my $last_30=0;
							my $sample_tick = date_to_tick($interval_ts);      	
							my $date_dif = sprintf "%0.2f", ($current_tick - $sample_tick) / (24 * 60 * 60);			
      				if ($date_dif < 30){      	
      					$last_30 =1;
      					#print "DateDiff: $date_dif $current_tick - $sample_tick) / (24 * 60 * 60)\n";
      				}
      				
      				if ($last_30 == 1){
      					print AWS_OUTFILE_30DAYS $src."~~~".$month."~~~".$fqdn."~~~".$ci_id."~~~".$data_domain."~~~".$client_id."~~~".$client_alias."~~~".$interval_ts."~~~".$ci_alias_type;
								print AWS_OUTFILE_30DAYS "~~~".$metricset."~~~".$natv_mtrc_cd."~~~".$natv_mtrc_val."~~~".$metric_sample_ct."~~~".$metricset_module."~~~".$src_clnt_cd."~~~".$src_sys;
								print AWS_OUTFILE_30DAYS "\n";
							}
							
							if ($month eq $prev_month) {
								print AWS_OUTFILE $src."~~~".$month."~~~".$fqdn."~~~".$ci_id."~~~".$data_domain."~~~".$client_id."~~~".$client_alias."~~~".$interval_ts."~~~".$ci_alias_type;
								print AWS_OUTFILE "~~~".$metricset."~~~".$natv_mtrc_cd."~~~".$natv_mtrc_val."~~~".$metric_sample_ct."~~~".$metricset_module."~~~".$src_clnt_cd."~~~".$src_sys;
								print AWS_OUTFILE "\n";
							}
						} else {
							print AWS_OUTFILE $src."~~~".$month."~~~".$fqdn."~~~".$ci_id."~~~".$data_domain."~~~".$client_id."~~~".$client_alias."~~~".$interval_ts."~~~".$ci_alias_type;
							print AWS_OUTFILE "~~~".$metricset."~~~".$natv_mtrc_cd."~~~".$natv_mtrc_val."~~~".$metric_sample_ct."~~~".$metricset_module."~~~".$src_clnt_cd."~~~".$src_sys;
							print AWS_OUTFILE "\n";
						}
					} else {
						##These are the CPU and Memory capacity and system availability comma seperated values we extract from AWS
						my ($fqdn, $ci_id, $data_domain, $client_id, $client_alias, $interval_ts, $ci_alias_type, $metricset,$request_time, $natv_mtrc_cd, $natv_mtrc_val,
						$metric_sample_ct, $metricset_module, $src_clnt_cd, $src_sys,$ingest_dt)=@values;

						my $month = get_month($interval_ts);
						next if (not defined($month_dates{$extract_month}{PROCESS_MONTHS}{$month}));
						
						if ($extract_month =~ /30DAYS/i) {
							my $last_30=0;
							my $sample_tick = date_to_tick($interval_ts);      	
							my $date_dif = sprintf "%0.2f", ($current_tick - $sample_tick) / (24 * 60 * 60);			
      				if ($date_dif < 30){      	
      					$last_30 =1;
      					#print "DateDiff: $date_dif $current_tick - $sample_tick) / (24 * 60 * 60)\n";
      				}
      				
      				if ($last_30 == 1){
      					print AWS_OUTFILE_30DAYS $src."~~~".$month."~~~".$fqdn."~~~".$ci_id."~~~".$data_domain."~~~".$client_id."~~~".$client_alias."~~~".$interval_ts."~~~".$ci_alias_type."~~~".$metricset;
								print AWS_OUTFILE_30DAYS "~~~".$request_time."~~~".$natv_mtrc_cd."~~~".$natv_mtrc_val."~~~".$metric_sample_ct."~~~".$metricset_module."~~~".$src_clnt_cd."~~~".$src_sys."~~~".$ingest_dt;
								print AWS_OUTFILE_30DAYS "\n";
							}
							
							if ($month eq $prev_month) {
								print AWS_OUTFILE $src."~~~".$month."~~~".$fqdn."~~~".$ci_id."~~~".$data_domain."~~~".$client_id."~~~".$client_alias."~~~".$interval_ts."~~~".$ci_alias_type."~~~".$metricset;
								print AWS_OUTFILE "~~~".$request_time."~~~".$natv_mtrc_cd."~~~".$natv_mtrc_val."~~~".$metric_sample_ct."~~~".$metricset_module."~~~".$src_clnt_cd."~~~".$src_sys."~~~".$ingest_dt;
								print AWS_OUTFILE "\n";
							}
						} else {
							print AWS_OUTFILE $src."~~~".$month."~~~".$fqdn."~~~".$ci_id."~~~".$data_domain."~~~".$client_id."~~~".$client_alias."~~~".$interval_ts."~~~".$ci_alias_type."~~~".$metricset;
							print AWS_OUTFILE "~~~".$request_time."~~~".$natv_mtrc_cd."~~~".$natv_mtrc_val."~~~".$metric_sample_ct."~~~".$metricset_module."~~~".$src_clnt_cd."~~~".$src_sys."~~~".$ingest_dt;
							print AWS_OUTFILE "\n";
						}
					}
				}
			}
		}
		close(AWS_OUTFILE);
		close(AWS_OUTFILE_30DAYS) if ($extract_month =~ /30DAYS/i);
	}
}


sub process_cva_enmt {
	#####################################
	#
	# Process the AWS CVA_ENMT record
	#
	#####################################


	my %cva_enmt_files;
	
	$cva_enmt_files{CVA_ENMT_PLAN}{OUT_FILE} = "$rawdata_dir/aws.cva_enmt_plan";
	$cva_enmt_files{CVA_ENMT_STATUS}{OUT_FILE} = "$rawdata_dir/aws.cva_enmt_status";
	
	foreach my $env (@aws_environments){
		$cva_enmt_files{CVA_ENMT_PLAN}{IN_FILE}{$env} = "$rawdata_dir/aws/" . $env . "_AWS_CVA_ENMT_PLAN.csv";
		$cva_enmt_files{CVA_ENMT_STATUS}{IN_FILE}{$env} = "$rawdata_dir/aws/" . $env . "_AWS_CVA_ENMT_STATUS.csv";
	}

	foreach my $cva_enmt_type (keys %cva_enmt_files) {
		open (AWS_OUTFILE, ">$cva_enmt_files{$cva_enmt_type}{OUT_FILE}");
		print "Writing data to $cva_enmt_files{$cva_enmt_type}{OUT_FILE}\n";

		
		foreach my $env (@aws_environments){
			print "Processing data from $cva_enmt_files{$cva_enmt_type}{IN_FILE}{$env}\n";

			open (AWS_INFILE, "<$cva_enmt_files{$cva_enmt_type}{IN_FILE}{$env}");
			my @file = <AWS_INFILE>;
			close(AWS_INFILE);

			my $line_cnt=0;
			my $joined = 0;
			my $joined_cnt = 0;
			my $join_str;
			my $headers_cnt;
			my $nofqdncnt=0;
			my $inccount=0;
			my $foundfqdncnt=0;

			

			foreach my $ln (@file){
				my @cols;

				chomp($ln);
				$line_cnt++;
				# Clense data of any paterns that will break call to parcse_csv
				$ln =~s/^(\x{feff})//; 			# Remove strange UTF-16 characters that excel adds at start of first row.
				$ln =~ s/\r//g; 						# Remove control M character
				$ln =~ s/\^M$//;						# Remove control M character (if has been copied and pasted is no longer special character)
				$ln =~ s/\(\"\"\"\"\,\"\"\"\"\,\"\"\"\"\,\"\"\"\"\)/\(\-\,\-\,\-\,\)/g;  # Found a desc containing the following!  unable to allocate bytes of shared memory ("""","""","""","""")",
				$ln =~s/\,\"\"\"/\,\"\'/g;	# Replace triple double quotes at start of field with ,"'
				$ln =~s/\"\"\"\,/\'\"\,/g;	# Replace triple double quotes at start of field with '",
				$ln =~ s/\,\"\"\,/\,\,/g;   # Replace quotes for empty fields in the middle of the line
				$ln =~ s/\,\"\"$/\,/g;   		# Replace quotes for empty fields in the middle of the line
				$ln =~ s/\"\"/\'/g;    			# Replace double double quotes with single quote
				$ln =~ s/\\\"/\"/g;    			# Replace \" from string with just dopuble quotes

				if ($line_cnt == 1){
					@cols = parse_csv($ln);
					$headers_cnt = scalar(@cols);

					print "AWS Input file $cva_enmt_files{$cva_enmt_type}{IN_FILE}{$env} contains $headers_cnt fields.\n\n";
				} else {
					if ($join_str eq ""){
						$join_str = $ln;
						$joined = 0;
						$joined_cnt = 0;
					} else {
						$join_str=$join_str . " " . $ln;
					}
					@cols = parse_csv($join_str);

					my $fields_cnt = scalar(@cols);

					if ($fields_cnt >= $headers_cnt){
						$ln = $join_str if ($line_cnt > 1);
						$join_str = "";
						#print "Line ($fields_cnt)= $ln\n\n" if ($joined == 1);
						$joined = 0;
						$joined_cnt = 0;
					} else {
						$joined = 1;
						$joined_cnt ++;
						#print "Joining line $joined_cnt ($fields_cnt): $ln\n";
						if ($joined_cnt >= 30){
							# Check that we have not joined a huge number of lines together.
							# 30 has been chosen as I have found some records containing a short description 25 lines long
							# Chances are if we join 30 lines we have had an issue identifying the end of one record
							print "\nExceeded joining 30 lines.  Is this incident really over 30 lines long or do we have an issue?\n";
							print "Check the first issue in the following line:\n\n";
							print "$join_str\n";
							exit;
						}
						next;
					}
					my @values = parse_csv($ln);
					#print "VALUES:@values\n";

					my $src = "CVA-AWS";
					if ($cva_enmt_type eq 'CVA_ENMT_PLAN') {
						##These are the cva enrollment plan comma seperated values we extract from AWS
						my ($account, $hostname, $ip_address, $os_type, $cva_id, $inscope, $comments, $startdate, $enddate) = @values;
						print AWS_OUTFILE $src."~~~".$account."~~~".$hostname."~~~".$ip_address."~~~".$os_type."~~~".$cva_id."~~~".$inscope."~~~".$comments."~~~".$startdate."~~~".$enddate;
						print AWS_OUTFILE "\n";
					} elsif($cva_enmt_type eq 'CVA_ENMT_STATUS') {
						##These are the cva enrollment plan comma seperated values we extract from AWS
						my ($account, $cva_id, $hostname, $ip_address, $phase, $status, $module, $action, $date) = @values;
						print AWS_OUTFILE $src."~~~".$account."~~~".$cva_id."~~~".$hostname."~~~".$ip_address."~~~".$phase."~~~".$status."~~~".$module."~~~".$action."~~~".$date;
						print AWS_OUTFILE "\n";

					}
				}
			}
		}		
		close(AWS_OUTFILE);
	}
}

sub process_bigfix_comp {
	#####################################
	#
	# Process the AWS BIGFIX_COMP record
	#
	#####################################
	#CI_LIST

	my %bigfix_comp_files;

	$bigfix_comp_files{BIGFIX_COMP_CI_LIST}{OUT_FILE} = "$rawdata_dir/aws.bigfix_comp_ci_list";
	
	foreach my $env (@aws_environments){
		$bigfix_comp_files{BIGFIX_COMP_CI_LIST}{IN_FILE}{$env} = "$rawdata_dir/aws/" . $env . "_AWS_BIGFIX_COMP_CI_LIST.csv";
	}

	foreach my $bigfix_comp_type (keys %bigfix_comp_files) {
		open (AWS_OUTFILE, ">$bigfix_comp_files{$bigfix_comp_type}{OUT_FILE}");
		print "Writing data to $bigfix_comp_files{$bigfix_comp_type}{OUT_FILE}\n";

		
		foreach my $env (@aws_environments){
			print "Processing data from $bigfix_comp_files{$bigfix_comp_type}{IN_FILE}{$env}\n";

			open (AWS_INFILE, "<$bigfix_comp_files{$bigfix_comp_type}{IN_FILE}{$env}");
			my @file = <AWS_INFILE>;
			close(AWS_INFILE);

			my $line_cnt=0;
			my $joined = 0;
			my $joined_cnt = 0;
			my $join_str;
			my $headers_cnt;
			my $nofqdncnt=0;
			my $inccount=0;
			my $foundfqdncnt=0;

			

			foreach my $ln (@file){
				my @cols;

				chomp($ln);
				$line_cnt++;
				# Clense data of any paterns that will break call to parcse_csv
				$ln =~s/^(\x{feff})//; 			# Remove strange UTF-16 characters that excel adds at start of first row.
				$ln =~ s/\r//g; 						# Remove control M character
				$ln =~ s/\^M$//;						# Remove control M character (if has been copied and pasted is no longer special character)
				$ln =~ s/\(\"\"\"\"\,\"\"\"\"\,\"\"\"\"\,\"\"\"\"\)/\(\-\,\-\,\-\,\)/g;  # Found a desc containing the following!  unable to allocate bytes of shared memory ("""","""","""","""")",
				$ln =~s/\,\"\"\"/\,\"\'/g;	# Replace triple double quotes at start of field with ,"'
				$ln =~s/\"\"\"\,/\'\"\,/g;	# Replace triple double quotes at start of field with '",
				$ln =~ s/\,\"\"\,/\,\,/g;   # Replace quotes for empty fields in the middle of the line
				$ln =~ s/\,\"\"$/\,/g;   		# Replace quotes for empty fields in the middle of the line
				$ln =~ s/\"\"/\'/g;    			# Replace double double quotes with single quote
				$ln =~ s/\\\"/\"/g;    			# Replace \" from string with just dopuble quotes

				if ($line_cnt == 1){
					@cols = parse_csv($ln);
					$headers_cnt = scalar(@cols);

					print "AWS Input file $bigfix_comp_files{$bigfix_comp_type}{IN_FILE}{$env} contains $headers_cnt fields.\n\n";
				} else {
					if ($join_str eq ""){
						$join_str = $ln;
						$joined = 0;
						$joined_cnt = 0;
					} else {
						$join_str=$join_str . " " . $ln;
					}
					@cols = parse_csv($join_str);

					my $fields_cnt = scalar(@cols);

					if ($fields_cnt >= $headers_cnt){
						$ln = $join_str if ($line_cnt > 1);
						$join_str = "";
						#print "Line ($fields_cnt)= $ln\n\n" if ($joined == 1);
						$joined = 0;
						$joined_cnt = 0;
					} else {
						$joined = 1;
						$joined_cnt ++;
						#print "Joining line $joined_cnt ($fields_cnt): $ln\n";
						if ($joined_cnt >= 30){
							# Check that we have not joined a huge number of lines together.
							# 30 has been chosen as I have found some records containing a short description 25 lines long
							# Chances are if we join 30 lines we have had an issue identifying the end of one record
							print "\nExceeded joining 30 lines.  Is this incident really over 30 lines long or do we have an issue?\n";
							print "Check the first issue in the following line:\n\n";
							print "$join_str\n";
							exit;
						}
						next;
					}
					my @values = parse_csv($ln);
					#print "VALUES:@values\n";

					my $src = "CVA-AWS";
					##These are the cva enrollment ci_list comma seperated values we extract from AWS
					my ($cmptr_nm, $agnt_ver_nm, $bes_relay_seltn_mthd_cd, $bes_root_srvr_nm, $clnt_cd, $cmptr_id, $cmptr_last_rpt_ts, $dvc_type_nm, $ip_addr_nm, $os_nm, $refresh_dt, $ci_nm, $fqdn_nm, $co_nm, $acct_nm) = @values;
					print AWS_OUTFILE $src."~~~".$cmptr_nm."~~~".$agnt_ver_nm."~~~".$bes_relay_seltn_mthd_cd."~~~".$bes_root_srvr_nm."~~~".$clnt_cd."~~~".$cmptr_id."~~~".$cmptr_last_rpt_ts."~~~".$dvc_type_nm."~~~".$ip_addr_nm."~~~".$os_nm."~~~".$refresh_dt."~~~".$ci_nm."~~~".$fqdn_nm."~~~".$co_nm."~~~".$acct_nm;
					print AWS_OUTFILE "\n";
				}
			}
		}		
		close(AWS_OUTFILE);
	}
}


sub get_months
{
	
	# First get start and end dates for 30days query.
	# Includes from 1st of last month until now
	my @start_time = localtime (time()-2592000);
	my @end_time = localtime ();
		
	#$start_time[3] = 1; #set start day to first day of month
	#$start_time[4] -= 1; #set start month to 1 months ago
	#$end_time[3] += 1; #set end day to tomorrow
	
	my $query_start_tick = mktime @start_time;
		
	my $query_start_date = strftime("%Y-%m-%d",localtime($query_start_tick));
	$query_start_date=$query_start_date." 00:00:00";
		
	my $ingest_start_date = strftime("%Y%m%d",localtime($query_start_tick));
	$ingest_start_date=$ingest_start_date."000000";
		
	my $query_end_tick = mktime @end_time;
		
	my $query_end_date = strftime("%Y-%m-%d",localtime($query_end_tick));
	$query_end_date=$query_end_date." 00:00:00";
		
	my $ingest_end_date = strftime("%Y%m%d",localtime($query_end_tick));
	$ingest_end_date=$ingest_end_date."000000";
	
	my $start_month_name = uc(strftime("%h-%y",localtime($query_start_tick)));
	my $end_month_name = uc(strftime("%h-%y",localtime($query_end_tick)));
			
	$month_dates{'30DAYS'}{QUERY_START_DATE} = $query_start_date;
	$month_dates{'30DAYS'}{QUERY_END_DATE} = $query_end_date;
	$month_dates{'30DAYS'}{INGEST_START_DATE} = $ingest_start_date;	
	$month_dates{'30DAYS'}{INGEST_END_DATE} = $ingest_end_date;	
	$month_dates{'30DAYS'}{PROCESS_MONTHS}{$start_month_name} = 1;
	$month_dates{'30DAYS'}{PROCESS_MONTHS}{$end_month_name} = 1;
  		
  # Find the start/end dates for the last 12 months				
  foreach my $x (1..12) {
  	# get from first of the month up to midnight on the first of following month
  	my @start_time = localtime ();
		my @end_time = localtime ();
  	
		my $start_extract_month = $x;
		$start_time[3] = 1; #set start day to first day of month
		$start_time[4] -= $start_extract_month; #set start month
				
		my $end_extract_month = $start_extract_month - 1;
		$end_time[4] -= $end_extract_month;  #set end month to -m + 1 months ago
		$end_time[3] = 1; #set end day to first day of following month
		
		my $query_start_tick = mktime @start_time;
		
		my $query_start_date = strftime("%Y-%m-%d",localtime($query_start_tick));
		$query_start_date=$query_start_date." 00:00:00";
		
		my $ingest_start_date = strftime("%Y%m%d",localtime($query_start_tick));
		$ingest_start_date=$ingest_start_date."000000";
		
		my $query_end_tick = mktime @end_time;
		
		my $query_end_date = strftime("%Y-%m-%d",localtime($query_end_tick));
		$query_end_date=$query_end_date." 00:00:00";
		
		my $ingest_end_date = strftime("%Y%m%d",localtime($query_end_tick));
		$ingest_end_date=$ingest_end_date."000000";
		
		my $month_name = uc(strftime("%h-%y",localtime($query_start_tick)));
		
		$month_dates{$month_name}{QUERY_START_DATE} = $query_start_date;
		$month_dates{$month_name}{QUERY_END_DATE} = $query_end_date;
		$month_dates{$month_name}{INGEST_START_DATE} = $ingest_start_date;	
		$month_dates{$month_name}{INGEST_END_DATE} = $ingest_end_date;	
		$month_dates{$month_name}{PROCESS_MONTHS}{$month_name} = 1;
  }
}


sub usage
{
	my ($err_str) = @_;

	print "get_aws_data.pl [-e <environment>] [-a <account>] [-r <region>] [-u <user role>] [-d <database>] [-p <r|w>] [-t <avcap>] [-m <MMM-YY>|30DAYS] \n\n";
	print "If no parameters provided, will process availabaility and capacity data for the past 12 months from the database specified in oc_master.cfg AWS_AVCAP_DB setting.\n\n";
	print "-e Optional.  AWS Environment to extract data from.  Not specified will do intelli prod.  e.g. -e gbl\n";
	print "-a Optional.  AWS Account to extract data from.  Not specified extract the account from the AWS_ACCOUNT parameter on the oc_master.cfg file. e.g. -a 12345678\n";
	print "-r Optional.  AWS Region to extract data from.  Not specified extract the account from the AWS_REGION parameter on the oc_master.cfg file. e.g. -r us-east-1\n";
	print "-u Optional.  AWS user role used to query Athena and download results file from S3 bucket.  e.g. -u ana-oc-data-access\n";
	print "-d Optional.  Database to extract data from.  e.g. -d ana_avcap_metricbeat_data1\n";
	print "-p Optional.  Processing function to be performed. Read data from AWS and create local CSV files or write data from local CSV Files to formatted file.  Not specified will do both. e.g.  -p r\n";	
	print "-t Optional.  Type of data to process.  Not specified will do all.  e.g. -t avcap\n";
	print "-m (with month in format MMM-YY or 30DAYS) Optional.  The months data to extract.  30DAYS will extract from 1st of previous month and create rawcache file for previous month and last 30 days.  Not specified will default to 30DAYS. e.g.  -m DEC-19\n";


}


########################################
#
# MAIN
#
########################################

get_months();

if (not defined($opts{"p"}) or (defined($opts{"p"}) and $opts{"p"} =~ /r/)){
	my $data_type = $opts{'t'} || 'avcap';
	print "Building SQL queries for ".$opts{'t'}."\n";
	build_aws_queries();

	print "Executing SQL queries on AWS...\n";
	run_aws_queries(\%aws_queries, \%s3_files);

	print "Waiting 60 seconds for AWS queries to move to s3 storage.\n";
	$| = 1;
	for (1 .. 60) {
		print "\r$_";
		sleep 1;
	}

	print "\n\nDownloading result data from S3 Storage...\n";
	download_aws_data(\%s3_files, $run_log);
}

if (not defined($opts{"p"}) or (defined($opts{"p"}) and $opts{"p"} =~ /w/)){
	
	if  (not defined($opts{"t"}) or (defined($opts{"t"}) and $opts{"t"} =~ /avcap/)){
		print "Processing CVA Availability and Capacity data\n";
		process_avcap();
	}elsif(defined($opts{"t"}) and $opts{"t"} =~ /cva_enmt/){
		print "Processing Athena CVA_ENMT data\n";
		process_cva_enmt();
	}elsif(defined($opts{"t"}) and $opts{"t"} =~ /bigfix_comp/){
		print "Processing Athena BIGFIX_COMP data\n";
		process_bigfix_comp();
	}
	
}

my $end_time = time();
printf "%0.1f Mins\n", ($end_time - $start_time) / 60;
exit 0;
